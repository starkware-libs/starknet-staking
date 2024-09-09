#[starknet::contract]
pub mod Staking {
    use core::option::OptionTrait;
    use core::num::traits::zero::Zero;
    use contracts::constants::{BASE_VALUE, DEFAULT_EXIT_WAIT_WINDOW};
    use contracts::constants::MIN_DAYS_BETWEEN_INDEX_UPDATES;
    use contracts::errors::{Error, assert_with_err, OptionAuxTrait};
    use contracts::staking::{StakerInfo, StakerPoolInfo, StakerInfoTrait, StakingContractInfo};
    use contracts::staking::{IStakingPool, IStakingPause, IStaking, IStakingConfig};
    use contracts::utils::{deploy_delegation_pool_contract, compute_commission_amount_rounded_down};
    use contracts::utils::{compute_rewards_rounded_down, compute_rewards_rounded_up, day_of};
    use contracts::utils::compute_global_index_diff;
    use contracts::staking::objects::{UndelegateIntentKey, UndelegateIntentValue};
    use contracts::staking::objects::UndelegateIntentValueZero;
    use contracts::staking::{Events, PauseEvents};
    use starknet::{ContractAddress, get_contract_address, get_caller_address, get_tx_info};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use contracts::utils::CheckedIERC20DispatcherTrait;
    use starknet::get_block_timestamp;
    use starknet::class_hash::ClassHash;
    use contracts::pool::interface::{IPoolDispatcherTrait, IPoolDispatcher};
    use contracts::reward_supplier::interface::IRewardSupplierDispatcherTrait;
    use contracts::reward_supplier::interface::IRewardSupplierDispatcher;
    use starknet::storage::Map;
    use contracts_commons::components::roles::RolesComponent;
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use contracts_commons::components::roles::interface::{OPERATOR, SECURITY_ADMIN};
    use contracts_commons::components::roles::interface::{APP_GOVERNOR, GOVERNANCE_ADMIN};

    pub const COMMISSION_DENOMINATOR: u16 = 10000;

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ReplaceabilityImpl =
        ReplaceabilityComponent::ReplaceabilityImpl<ContractState>;

    #[abi(embed_v0)]
    impl RolesImpl = RolesComponent::RolesImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        replaceability: ReplaceabilityComponent::Storage,
        #[substorage(v0)]
        roles: RolesComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        global_index: u64,
        global_index_last_update_timestamp: u64,
        min_stake: u128,
        staker_info: Map<ContractAddress, Option<StakerInfo>>,
        operational_address_to_staker_address: Map<ContractAddress, ContractAddress>,
        erc20_dispatcher: IERC20Dispatcher,
        total_stake: u128,
        pool_contract_class_hash: ClassHash,
        pool_exit_intents: Map<UndelegateIntentKey, UndelegateIntentValue>,
        reward_supplier_dispatcher: IRewardSupplierDispatcher,
        pool_contract_admin: ContractAddress,
        is_paused: bool,
        exit_wait_window: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        StakeBalanceChanged: Events::StakeBalanceChanged,
        NewDelegationPool: Events::NewDelegationPool,
        StakerExitIntent: Events::StakerExitIntent,
        StakerRewardAddressChanged: Events::StakerRewardAddressChanged,
        OperationalAddressChanged: Events::OperationalAddressChanged,
        GlobalIndexUpdated: Events::GlobalIndexUpdated,
        NewStaker: Events::NewStaker,
        CommissionChanged: Events::CommissionChanged,
        StakerRewardClaimed: Events::StakerRewardClaimed,
        DeleteStaker: Events::DeleteStaker,
        RewardsSuppliedToDelegationPool: Events::RewardsSuppliedToDelegationPool,
        Paused: PauseEvents::Paused,
        Unpaused: PauseEvents::Unpaused
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        min_stake: u128,
        pool_contract_class_hash: ClassHash,
        reward_supplier: ContractAddress,
        pool_contract_admin: ContractAddress,
        security_admin: ContractAddress,
    ) {
        self.accesscontrol.initializer();
        self.roles.initializer();
        // Override default role admins.
        self.accesscontrol.set_role_admin(role: OPERATOR, admin_role: SECURITY_ADMIN);
        self.accesscontrol.set_role_admin(role: APP_GOVERNOR, admin_role: GOVERNANCE_ADMIN);
        self.replaceability.upgrade_delay.write(Zero::zero());
        self.erc20_dispatcher.write(IERC20Dispatcher { contract_address: token_address });
        self.min_stake.write(min_stake);
        self.pool_contract_class_hash.write(pool_contract_class_hash);
        self
            .reward_supplier_dispatcher
            .write(IRewardSupplierDispatcher { contract_address: reward_supplier });
        self.pool_contract_admin.write(pool_contract_admin);
        self.global_index.write(BASE_VALUE);
        self.global_index_last_update_timestamp.write(get_block_timestamp());
        self.exit_wait_window.write(DEFAULT_EXIT_WAIT_WINDOW);
        self.roles.register_security_admin(account: security_admin);
        self.is_paused.write(false);
    }

    #[abi(embed_v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u128,
            pool_enabled: bool,
            commission: u16,
        ) -> bool {
            self.assert_is_unpaused();
            self.roles.only_operator();
            self.update_global_index_if_needed();
            // TODO: consider calling get_execution_info() and pass it to the role test for better
            // performance (remove the additional syscall for get_caller_address()).
            let staker_address = get_tx_info().account_contract_address;
            assert_with_err(self.staker_info.read(staker_address).is_none(), Error::STAKER_EXISTS);
            assert_with_err(
                self.operational_address_to_staker_address.read(operational_address).is_zero(),
                Error::OPERATIONAL_EXISTS
            );
            assert_with_err(amount >= self.min_stake.read(), Error::AMOUNT_LESS_THAN_MIN_STAKE);
            assert_with_err(commission <= COMMISSION_DENOMINATOR, Error::COMMISSION_OUT_OF_RANGE);
            let staking_contract = get_contract_address();
            let erc20_dispatcher = self.erc20_dispatcher.read();
            erc20_dispatcher
                .checked_transfer_from(
                    sender: staker_address, recipient: staking_contract, amount: amount.into()
                );
            let pool_info = if pool_enabled {
                let pool_contract = self
                    .deploy_delegation_pool_contract(
                        :staker_address,
                        :staking_contract,
                        token_address: erc20_dispatcher.contract_address,
                        :commission
                    );
                Option::Some(
                    StakerPoolInfo {
                        pool_contract,
                        amount: Zero::zero(),
                        unclaimed_rewards: Zero::zero(),
                        commission,
                    }
                )
            } else {
                Option::None
            };
            self
                .staker_info
                .write(
                    staker_address,
                    Option::Some(
                        StakerInfo {
                            reward_address,
                            operational_address,
                            unstake_time: Option::None,
                            amount_own: amount,
                            index: self.global_index.read(),
                            unclaimed_rewards_own: 0,
                            pool_info,
                        }
                    )
                );
            self.operational_address_to_staker_address.write(operational_address, staker_address);
            self.add_to_total_stake(:amount);
            self
                .emit(
                    Events::StakeBalanceChanged {
                        staker_address,
                        old_self_stake: Zero::zero(),
                        old_delegated_stake: Zero::zero(),
                        new_self_stake: amount,
                        new_delegated_stake: Zero::zero()
                    }
                );
            self
                .emit(
                    Events::NewStaker {
                        staker_address, reward_address, operational_address, self_stake: amount
                    }
                );
            true
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            self.assert_is_unpaused();
            self.roles.only_operator();
            self.update_global_index_if_needed();
            let caller_address = get_tx_info().account_contract_address;
            let mut staker_info = self.get_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            assert_with_err(
                caller_address == staker_address || caller_address == staker_info.reward_address,
                Error::CALLER_CANNOT_INCREASE_STAKE
            );
            let old_self_stake = staker_info.amount_own;
            let staking_contract_address = get_contract_address();
            let erc20_dispatcher = self.erc20_dispatcher.read();
            erc20_dispatcher
                .checked_transfer_from(
                    sender: caller_address,
                    recipient: staking_contract_address,
                    amount: amount.into()
                );
            self.calculate_rewards(ref :staker_info);
            staker_info.amount_own += amount;
            let mut staker_total_stake = staker_info.amount_own;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            self.add_to_total_stake(:amount);
            let mut old_delegated_stake = Zero::zero();
            let mut new_delegated_stake = Zero::zero();
            if let Option::Some(pool_info) = staker_info.pool_info {
                old_delegated_stake = pool_info.amount;
                new_delegated_stake = pool_info.amount;
                staker_total_stake += pool_info.amount;
            }
            self
                .emit(
                    Events::StakeBalanceChanged {
                        staker_address,
                        old_self_stake,
                        old_delegated_stake,
                        new_self_stake: staker_info.amount_own,
                        new_delegated_stake
                    }
                );
            staker_total_stake
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            self.assert_is_unpaused();
            self.roles.only_operator();
            self.update_global_index_if_needed();
            let mut staker_info = self.get_staker_info(:staker_address);
            let caller_address = get_tx_info().account_contract_address;
            let reward_address = staker_info.reward_address;
            assert_with_err(
                caller_address == staker_address || caller_address == reward_address,
                Error::CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
            );
            self.calculate_rewards(ref :staker_info);
            let amount = staker_info.unclaimed_rewards_own;
            let erc20_dispatcher = self.erc20_dispatcher.read();
            self
                .send_rewards_to_staker(
                    :staker_address, :reward_address, :amount, :erc20_dispatcher
                );
            staker_info.unclaimed_rewards_own = Zero::zero();
            self.staker_info.write(staker_address, Option::Some(staker_info));
            amount
        }

        fn unstake_intent(ref self: ContractState) -> u64 {
            self.assert_is_unpaused();
            self.roles.only_operator();
            self.update_global_index_if_needed();
            let staker_address = get_tx_info().account_contract_address;
            let mut staker_info = self.get_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            self.calculate_rewards(ref :staker_info);
            let current_time = get_block_timestamp();
            let unstake_time = current_time + self.exit_wait_window.read();
            staker_info.unstake_time = Option::Some(unstake_time);
            self.staker_info.write(staker_address, Option::Some(staker_info));
            let mut amount_pool = Zero::zero();
            if let Option::Some(pool_info) = staker_info.pool_info {
                amount_pool = pool_info.amount;
            }
            let amount = staker_info.amount_own + amount_pool;
            self.remove_from_total_stake(:amount);
            self
                .emit(
                    Events::StakerExitIntent {
                        staker_address, exit_timestamp: unstake_time, amount
                    }
                );
            self
                .emit(
                    Events::StakeBalanceChanged {
                        staker_address,
                        old_self_stake: staker_info.amount_own,
                        old_delegated_stake: amount_pool,
                        new_self_stake: Zero::zero(),
                        new_delegated_stake: Zero::zero()
                    }
                );
            unstake_time
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            self.assert_is_unpaused();
            self.roles.only_operator();
            self.update_global_index_if_needed();
            let staker_info = self.get_staker_info(:staker_address);
            let unstake_time = staker_info
                .unstake_time
                .expect_with_err(Error::MISSING_UNSTAKE_INTENT);
            assert_with_err(
                get_block_timestamp() >= unstake_time, Error::INTENT_WINDOW_NOT_FINISHED
            );
            let erc20_dispatcher = self.erc20_dispatcher.read();
            self
                .send_rewards_to_staker(
                    :staker_address,
                    reward_address: staker_info.reward_address,
                    amount: staker_info.unclaimed_rewards_own,
                    :erc20_dispatcher
                );
            // Transfer stake to staker.
            let staker_amount = staker_info.amount_own;
            erc20_dispatcher
                .checked_transfer(recipient: staker_address, amount: staker_amount.into());

            self.transfer_to_pool_when_unstake(:staker_address, :staker_info);
            self.remove_staker(:staker_address, :staker_info);
            staker_amount
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            self.assert_is_unpaused();
            self.roles.only_operator();
            self.update_global_index_if_needed();
            let staker_address = get_tx_info().account_contract_address;
            let mut staker_info = self.get_staker_info(:staker_address);
            let old_address = staker_info.reward_address;
            staker_info.reward_address = reward_address;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            self
                .emit(
                    Events::StakerRewardAddressChanged {
                        staker_address, new_address: reward_address, old_address
                    }
                );
            true
        }

        fn set_open_for_delegation(ref self: ContractState, commission: u16) -> ContractAddress {
            self.assert_is_unpaused();
            self.roles.only_operator();
            self.update_global_index_if_needed();
            let staker_address = get_tx_info().account_contract_address;
            let mut staker_info = self.get_staker_info(:staker_address);
            assert_with_err(commission <= COMMISSION_DENOMINATOR, Error::COMMISSION_OUT_OF_RANGE);
            assert_with_err(staker_info.pool_info.is_none(), Error::STAKER_ALREADY_HAS_POOL);
            let pool_contract = self
                .deploy_delegation_pool_contract(
                    :staker_address,
                    staking_contract: get_contract_address(),
                    token_address: self.erc20_dispatcher.read().contract_address,
                    :commission
                );
            staker_info
                .pool_info =
                    Option::Some(
                        StakerPoolInfo {
                            pool_contract,
                            amount: Zero::zero(),
                            unclaimed_rewards: Zero::zero(),
                            commission
                        }
                    );
            self.staker_info.write(staker_address, Option::Some(staker_info));
            pool_contract
        }

        fn state_of(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            self.get_staker_info(:staker_address)
        }

        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            StakingContractInfo {
                min_stake: self.min_stake.read(),
                token_address: self.erc20_dispatcher.read().contract_address,
                global_index: self.global_index.read(),
                pool_contract_class_hash: self.pool_contract_class_hash.read(),
                reward_supplier: self.reward_supplier_dispatcher.read().contract_address,
                exit_wait_window: self.exit_wait_window.read()
            }
        }

        fn get_total_stake(self: @ContractState) -> u128 {
            self.total_stake.read()
        }

        fn update_global_index_if_needed(ref self: ContractState) -> bool {
            self.assert_is_unpaused();
            self.roles.only_operator();
            let current_timestmap = get_block_timestamp();
            if day_of(current_timestmap)
                - day_of(
                    self.global_index_last_update_timestamp.read()
                ) > MIN_DAYS_BETWEEN_INDEX_UPDATES {
                self.update_global_index();
                return true;
            }
            false
        }

        fn change_operational_address(
            ref self: ContractState, operational_address: ContractAddress
        ) -> bool {
            self.assert_is_unpaused();
            self.roles.only_operator();
            self.update_global_index_if_needed();
            let staker_address = get_tx_info().account_contract_address;
            let mut staker_info = self.get_staker_info(:staker_address);
            self
                .operational_address_to_staker_address
                .write(staker_info.operational_address, Zero::zero());
            let old_address = staker_info.operational_address;
            staker_info.operational_address = operational_address;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            self.operational_address_to_staker_address.write(operational_address, staker_address);
            self
                .emit(
                    Events::OperationalAddressChanged {
                        staker_address, new_address: operational_address, old_address
                    }
                );
            true
        }

        // fn update_commission(ref self: ContractState, commission: u16) -> bool {
        //     self.assert_is_unpaused();
        //     self.roles.only_operator();
        //     let staker_address = get_tx_info().account_contract_address;
        //     let mut staker_info = self.get_staker_info(:staker_address);
        //     let pool_info = staker_info.get_pool_info_unchecked();
        //     let pool_contract = pool_info.pool_contract;
        //     let old_commission = pool_info.commission;
        //     assert_with_err(commission <= old_commission, Error::CANNOT_INCREASE_COMMISSION);
        //     self.calculate_rewards(ref :staker_info);
        //     let mut pool_info = staker_info.get_pool_info_unchecked();
        //     pool_info.commission = commission;
        //     staker_info.pool_info = Option::Some(pool_info);
        //     self.staker_info.write(staker_address, Option::Some(staker_info));
        //     let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
        //     pool_dispatcher.update_commission(:commission);
        //     self
        //         .emit(
        //             Events::CommissionChanged {
        //                 staker_address, pool_contract, old_commission, new_commission: commission
        //             }
        //         );
        //     true
        // }

        fn is_paused(self: @ContractState) -> bool {
            self.is_paused.read()
        }
    }

    #[abi(embed_v0)]
    impl StakingPoolImpl of IStakingPool<ContractState> {
        fn add_stake_from_pool(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> (u128, u64) {
            self.assert_is_unpaused();
            self.update_global_index_if_needed();
            let mut staker_info = self.get_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            let pool_contract = staker_info.get_pool_info_unchecked().pool_contract;
            assert_with_err(
                pool_contract == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );

            self.calculate_rewards(ref :staker_info);
            let erc20_dispatcher = self.erc20_dispatcher.read();
            erc20_dispatcher
                .checked_transfer_from(
                    sender: pool_contract, recipient: get_contract_address(), amount: amount.into()
                );
            let mut pool_info = staker_info.get_pool_info_unchecked();
            let old_delegated_stake = pool_info.amount;
            pool_info.amount += amount;
            staker_info.pool_info = Option::Some(pool_info);
            self.staker_info.write(staker_address, Option::Some(staker_info));
            self.add_to_total_stake(:amount);
            self
                .emit(
                    Events::StakeBalanceChanged {
                        staker_address,
                        old_self_stake: staker_info.amount_own,
                        old_delegated_stake,
                        new_self_stake: staker_info.amount_own,
                        new_delegated_stake: pool_info.amount
                    }
                );
            (pool_info.amount, staker_info.index)
        }

        fn remove_from_delegation_pool_intent(
            ref self: ContractState,
            staker_address: ContractAddress,
            identifier: felt252,
            amount: u128,
        ) -> u64 {
            self.assert_is_unpaused();
            self.update_global_index_if_needed();
            let mut staker_info = self.get_staker_info(:staker_address);
            let mut pool_info = staker_info.get_pool_info_unchecked();
            assert_with_err(
                pool_info.pool_contract == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );
            self.calculate_rewards(ref :staker_info);
            let unpool_time = staker_info
                .compute_unpool_time(exit_wait_window: self.exit_wait_window.read());
            let undelegate_intent_key = UndelegateIntentKey {
                pool_contract: pool_info.pool_contract, identifier
            };
            let undelegate_intent_value = self.pool_exit_intents.read(undelegate_intent_key);
            let old_delegated_stake = pool_info.amount;
            let old_intent_amount = undelegate_intent_value.amount;
            let total_amount = old_intent_amount + old_delegated_stake;
            assert_with_err(amount <= total_amount, Error::AMOUNT_TOO_HIGH);
            let new_delegated_stake = total_amount - amount;
            pool_info.amount = new_delegated_stake;
            if (staker_info.unstake_time.is_none()) {
                // Change total stake only if the staker is not in the unstake process.
                if new_delegated_stake < old_delegated_stake {
                    self.remove_from_total_stake(amount: old_delegated_stake - new_delegated_stake);
                } else {
                    self.add_to_total_stake(amount: new_delegated_stake - old_delegated_stake);
                }
            }
            staker_info.pool_info = Option::Some(pool_info);
            self.staker_info.write(staker_address, Option::Some(staker_info));
            if amount.is_zero() {
                self.clear_undelegate_intent(:undelegate_intent_key);
            } else {
                self
                    .pool_exit_intents
                    .write(undelegate_intent_key, UndelegateIntentValue { amount, unpool_time });
            }
            self
                .emit(
                    Events::StakeBalanceChanged {
                        staker_address,
                        old_self_stake: staker_info.amount_own,
                        old_delegated_stake,
                        new_self_stake: staker_info.amount_own,
                        new_delegated_stake: pool_info.amount
                    }
                );
            unpool_time
        }

        fn remove_from_delegation_pool_action(
            ref self: ContractState, identifier: felt252
        ) -> u128 {
            self.assert_is_unpaused();
            self.update_global_index_if_needed();
            let pool_contract = get_caller_address();
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let undelegate_intent = self.pool_exit_intents.read(undelegate_intent_key);
            assert_with_err(
                get_block_timestamp() >= undelegate_intent.unpool_time,
                Error::INTENT_WINDOW_NOT_FINISHED
            );
            let erc20_dispatcher = self.erc20_dispatcher.read();
            erc20_dispatcher
                .checked_transfer(
                    recipient: pool_contract, amount: undelegate_intent.amount.into()
                );
            // TODO: Emit event.
            self.clear_undelegate_intent(:undelegate_intent_key);
            undelegate_intent.amount
        }

        fn switch_staking_delegation_pool(
            ref self: ContractState,
            to_staker: ContractAddress,
            to_pool: ContractAddress,
            switched_amount: u128,
            data: Span<felt252>,
            identifier: felt252
        ) -> bool {
            self.assert_is_unpaused();
            self.update_global_index_if_needed();
            if switched_amount.is_zero() {
                return false;
            }
            let pool_contract = get_caller_address();
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let mut undelegate_intent_value = self.pool_exit_intents.read(undelegate_intent_key);
            assert_with_err(
                undelegate_intent_value.is_non_zero(), Error::MISSING_UNDELEGATE_INTENT
            );
            assert_with_err(
                undelegate_intent_value.amount >= switched_amount, Error::AMOUNT_TOO_HIGH
            );
            let mut to_staker_info = self.get_staker_info(staker_address: to_staker);
            assert_with_err(to_staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            let mut to_staker_pool_info = to_staker_info.get_pool_info_unchecked();
            let to_staker_pool_contract = to_staker_pool_info.pool_contract;
            assert_with_err(to_pool == to_staker_pool_contract, Error::DELEGATION_POOL_MISMATCH);

            self.calculate_rewards(ref staker_info: to_staker_info);
            to_staker_pool_info.amount += switched_amount;
            self.staker_info.write(to_staker, Option::Some(to_staker_info));
            self.add_to_total_stake(amount: switched_amount);

            undelegate_intent_value.amount -= switched_amount;
            if undelegate_intent_value.amount.is_zero() {
                self.clear_undelegate_intent(:undelegate_intent_key);
            } else {
                self.pool_exit_intents.write(undelegate_intent_key, undelegate_intent_value);
            }
            let to_pool_dispatcher = IPoolDispatcher { contract_address: to_pool };
            to_pool_dispatcher
                .enter_delegation_pool_from_staking_contract(
                    amount: switched_amount, index: to_staker_info.index, :data
                );
            true
        }

        fn claim_delegation_pool_rewards(
            ref self: ContractState, staker_address: ContractAddress
        ) -> u64 {
            self.assert_is_unpaused();
            self.update_global_index_if_needed();
            let mut staker_info = self.get_staker_info(:staker_address);
            let pool_address = staker_info.get_pool_info_unchecked().pool_contract;
            assert_with_err(
                pool_address == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );
            self.calculate_rewards(ref :staker_info);
            let mut updated_pool_info = staker_info.get_pool_info_unchecked();
            // Calculate rewards updated the index in staker_info.
            let updated_index = staker_info.index;
            let erc20_dispatcher = self.erc20_dispatcher.read();
            self
                .send_rewards_to_delegation_pool(
                    :staker_address,
                    :pool_address,
                    amount: updated_pool_info.unclaimed_rewards,
                    :erc20_dispatcher
                );
            updated_pool_info.unclaimed_rewards = Zero::zero();
            staker_info.pool_info = Option::Some(updated_pool_info);
            self.staker_info.write(staker_address, Option::Some(staker_info));
            updated_index
        }
    }

    #[abi(embed_v0)]
    impl StakingPauseImpl of IStakingPause<ContractState> {
        fn pause(ref self: ContractState) {
            self.roles.only_security_agent();
            self.is_paused.write(true);
            self.emit(PauseEvents::Paused { account: get_caller_address() });
        }

        fn unpause(ref self: ContractState) {
            self.roles.only_security_admin();
            self.is_paused.write(false);
            self.emit(PauseEvents::Unpaused { account: get_caller_address() });
        }
    }

    #[abi(embed_v0)]
    impl StakingConfigImpl of IStakingConfig<ContractState> {
        fn set_min_stake(ref self: ContractState, min_stake: u128) {
            if self.is_paused() {
                self.roles.only_security_admin();
            } else {
                self.roles.only_app_governor();
            }
            self.min_stake.write(min_stake);
        }

        fn set_exit_wait_window(ref self: ContractState, exit_wait_window: u64) {
            if self.is_paused() {
                self.roles.only_security_admin();
            } else {
                self.roles.only_app_governor();
            }
            self.exit_wait_window.write(exit_wait_window);
        }
    }

    #[generate_trait]
    pub impl InternalStakingFunctions of InternalStakingFunctionsTrait {
        fn send_rewards(
            self: @ContractState,
            reward_address: ContractAddress,
            amount: u128,
            erc20_dispatcher: IERC20Dispatcher
        ) {
            let reward_supplier_dispatcher = self.reward_supplier_dispatcher.read();
            let balance_before = erc20_dispatcher.balance_of(account: get_contract_address());
            reward_supplier_dispatcher.claim_rewards(:amount);
            let balance_after = erc20_dispatcher.balance_of(account: get_contract_address());
            assert_with_err(
                balance_after - balance_before == amount.into(), Error::UNEXPECTED_BALANCE
            );
            erc20_dispatcher.checked_transfer(recipient: reward_address, amount: amount.into());
        }

        fn send_rewards_to_staker(
            ref self: ContractState,
            staker_address: ContractAddress,
            reward_address: ContractAddress,
            amount: u128,
            erc20_dispatcher: IERC20Dispatcher
        ) {
            self.send_rewards(:reward_address, :amount, :erc20_dispatcher);
            self.emit(Events::StakerRewardClaimed { staker_address, reward_address, amount });
        }

        fn send_rewards_to_delegation_pool(
            ref self: ContractState,
            staker_address: ContractAddress,
            pool_address: ContractAddress,
            amount: u128,
            erc20_dispatcher: IERC20Dispatcher
        ) {
            self.send_rewards(reward_address: pool_address, :amount, :erc20_dispatcher);
            self
                .emit(
                    Events::RewardsSuppliedToDelegationPool { staker_address, pool_address, amount }
                );
        }

        fn clear_undelegate_intent(
            ref self: ContractState, undelegate_intent_key: UndelegateIntentKey
        ) {
            self.pool_exit_intents.write(undelegate_intent_key, Zero::zero());
        }

        fn assert_is_unpaused(self: @ContractState) {
            assert_with_err(!self.is_paused(), Error::CONTRACT_IS_PAUSED);
        }

        fn get_staker_info(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            self.staker_info.read(staker_address).expect_with_err(Error::STAKER_NOT_EXISTS)
        }

        fn calculate_and_update_pool_rewards(
            ref self: ContractState, interest: u64, ref staker_info: StakerInfo
        ) {
            if let Option::Some(mut pool_info) = staker_info.pool_info {
                if (pool_info.amount.is_non_zero()) {
                    let rewards_including_commission = compute_rewards_rounded_up(
                        amount: pool_info.amount, :interest
                    );
                    let commission_amount = compute_commission_amount_rounded_down(
                        :rewards_including_commission, commission: pool_info.commission
                    );
                    staker_info.unclaimed_rewards_own += commission_amount;
                    let rewards = rewards_including_commission - commission_amount;
                    pool_info.unclaimed_rewards += rewards;
                    staker_info.pool_info = Option::Some(pool_info);
                }
            }
        }

        fn transfer_to_pool_when_unstake(
            ref self: ContractState, staker_address: ContractAddress, staker_info: StakerInfo
        ) {
            if let Option::Some(pool_info) = staker_info.pool_info {
                let erc20_dispatcher = self.erc20_dispatcher.read();
                self
                    .send_rewards_to_delegation_pool(
                        :staker_address,
                        pool_address: pool_info.pool_contract,
                        amount: pool_info.unclaimed_rewards,
                        :erc20_dispatcher
                    );
                erc20_dispatcher
                    .checked_transfer(
                        recipient: pool_info.pool_contract, amount: pool_info.amount.into()
                    );
                let pool_dispatcher = IPoolDispatcher { contract_address: pool_info.pool_contract };
                pool_dispatcher.set_final_staker_index(final_staker_index: staker_info.index);
            }
        }

        fn remove_staker(
            ref self: ContractState, staker_address: ContractAddress, staker_info: StakerInfo
        ) {
            self.staker_info.write(staker_address, Option::None);
            self
                .operational_address_to_staker_address
                .write(staker_info.operational_address, Zero::zero());
            self
                .emit(
                    Events::DeleteStaker {
                        staker_address,
                        reward_address: staker_info.reward_address,
                        operational_address: staker_info.operational_address,
                        pool_contract: match staker_info.pool_info {
                            Option::Some(pool_info) => Option::Some(pool_info.pool_contract),
                            Option::None => Option::None
                        }
                    }
                );
        }

        /// Calculates the rewards for a given staker.
        ///
        /// The caller for this function should validate that the staker exists.
        ///
        /// rewards formula:
        /// $$ interest = (global\_index-self\_index) $$
        ///
        /// single staker:
        /// $$ rewards = staker\_amount\_own * interest $$
        ///
        /// staker with pool:
        /// $$ rewards = interest * (staker\_amount\_own + staker\_amount\_pool * rev\_share) $$
        ///
        /// Fields that are changed in staker_info:
        /// - unclaimed_rewards_own
        /// - unclaimed_rewards
        /// - index
        fn calculate_rewards(ref self: ContractState, ref staker_info: StakerInfo) -> bool {
            if (staker_info.unstake_time.is_some()) {
                return false;
            }
            let global_index = self.global_index.read();
            let interest = global_index - staker_info.index;
            staker_info.index = global_index;

            let staker_rewards = compute_rewards_rounded_down(
                amount: staker_info.amount_own, :interest
            );
            staker_info.unclaimed_rewards_own += staker_rewards;
            self.calculate_and_update_pool_rewards(:interest, ref :staker_info);
            true
        }

        fn deploy_delegation_pool_contract(
            ref self: ContractState,
            staker_address: ContractAddress,
            staking_contract: ContractAddress,
            token_address: ContractAddress,
            commission: u16,
        ) -> ContractAddress {
            let class_hash = self.pool_contract_class_hash.read();
            let contract_address_salt: felt252 = get_block_timestamp().into();
            let admin = self.pool_contract_admin.read();
            let pool_contract = deploy_delegation_pool_contract(
                :class_hash,
                :contract_address_salt,
                :staker_address,
                :staking_contract,
                :token_address,
                :commission,
                :admin
            );
            self.emit(Events::NewDelegationPool { staker_address, pool_contract, commission });
            pool_contract
        }

        fn add_to_total_stake(ref self: ContractState, amount: u128) {
            self.total_stake.write(self.total_stake.read() + amount);
        }

        fn remove_from_total_stake(ref self: ContractState, amount: u128) {
            self.total_stake.write(self.total_stake.read() - amount);
        }

        fn update_global_index(ref self: ContractState) {
            let reward_supplier_dispatcher = self.reward_supplier_dispatcher.read();
            let staking_rewards = reward_supplier_dispatcher.calculate_staking_rewards();
            let total_stake = self.get_total_stake();
            let global_index_diff = compute_global_index_diff(:staking_rewards, :total_stake);
            let old_index = self.global_index.read();
            let new_index = old_index + global_index_diff;
            self.global_index.write(new_index);
            let global_index_last_update_timestamp = self.global_index_last_update_timestamp.read();
            let global_index_current_update_timestamp = get_block_timestamp();
            self.global_index_last_update_timestamp.write(global_index_current_update_timestamp);
            self
                .emit(
                    Events::GlobalIndexUpdated {
                        old_index,
                        new_index,
                        global_index_last_update_timestamp,
                        global_index_current_update_timestamp
                    }
                );
        }
    }
}
