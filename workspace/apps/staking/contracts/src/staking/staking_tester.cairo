use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IStakingTester<TContractState> {
    fn token_address(self: @TContractState) -> ContractAddress;
    fn pool_admin(self: @TContractState) -> ContractAddress;
    fn pool_class_hash(self: @TContractState) -> ClassHash;
}

#[starknet::contract]
pub mod StakingTester {
    use core::option::OptionTrait;
    use core::num::traits::zero::Zero;
    use contracts::constants::DEFAULT_EXIT_WAIT_WINDOW;
    use contracts::constants::MIN_TIME_BETWEEN_INDEX_UPDATES;
    use contracts::errors::{Error, assert_with_err, OptionAuxTrait};
    use contracts::staking::interface::{StakerInfo, StakerPoolInfo, StakingContractInfo};
    use contracts::staking::interface::{IStakingPool, IStakingPause, IStaking, IStakingConfig};
    use contracts::staking::staking_tester::IStakingTester;
    use contracts::utils::{deploy_delegation_pool_contract, compute_commission_amount_rounded_down};
    use contracts::utils::{compute_rewards_rounded_down, compute_rewards_rounded_up};
    use contracts::utils::compute_global_index_diff;
    use contracts::staking::objects::{UndelegateIntentKey, UndelegateIntentValue};
    use contracts::staking::objects::UndelegateIntentValueTrait;
    use contracts::staking::objects::UndelegateIntentValueZero;
    use contracts::staking::objects::{InternalStakerInfo, InternalStakerInfoTrait};
    use contracts::staking::interface::{Events, PauseEvents, ConfigEvents};
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use contracts::utils::CheckedIERC20DispatcherTrait;
    use starknet::class_hash::ClassHash;
    use contracts::pool::interface::{IPoolDispatcherTrait, IPoolDispatcher};
    use contracts::reward_supplier::interface::IRewardSupplierDispatcherTrait;
    use contracts::reward_supplier::interface::IRewardSupplierDispatcher;
    use starknet::storage::Map;
    use contracts_commons::components::roles::RolesComponent;
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use contracts::types::{Commission, Index, Amount};
    use contracts_commons::types::time::{TimeDelta, Time, TimeStamp};

    pub const COMMISSION_DENOMINATOR: Commission = 10000;

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
        global_index: Index,
        global_index_last_update_timestamp: TimeStamp,
        min_stake: Amount,
        staker_info: Map<ContractAddress, Option<InternalStakerInfo>>,
        operational_address_to_staker_address: Map<ContractAddress, ContractAddress>,
        eligible_operational_addresses: Map<ContractAddress, ContractAddress>,
        token_dispatcher: IERC20Dispatcher,
        total_stake: Amount,
        pool_contract_class_hash: ClassHash,
        pool_exit_intents: Map<UndelegateIntentKey, UndelegateIntentValue>,
        reward_supplier_dispatcher: IRewardSupplierDispatcher,
        pool_contract_admin: ContractAddress,
        is_paused: bool,
        exit_wait_window: TimeDelta,
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
        Unpaused: PauseEvents::Unpaused,
        MinimumStakeChanged: ConfigEvents::MinimumStakeChanged,
        ExitWaitWindowChanged: ConfigEvents::ExitWaitWindowChanged,
        RewardSupplierChanged: ConfigEvents::RewardSupplierChanged,
        OperationalAddressDeclared: Events::OperationalAddressDeclared,
        RemoveFromDelegationPoolAction: Events::RemoveFromDelegationPoolAction
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        min_stake: Amount,
        pool_contract_class_hash: ClassHash,
        reward_supplier: ContractAddress,
        pool_contract_admin: ContractAddress,
        governance_admin: ContractAddress
    ) {
        self.roles.initialize(:governance_admin);
        self.replaceability.upgrade_delay.write(Zero::zero());
        self.token_dispatcher.write(IERC20Dispatcher { contract_address: token_address });
        self.min_stake.write(min_stake);
        self.pool_contract_class_hash.write(pool_contract_class_hash);
        self
            .reward_supplier_dispatcher
            .write(IRewardSupplierDispatcher { contract_address: reward_supplier });
        self.pool_contract_admin.write(pool_contract_admin);
        self.global_index.write(Zero::zero());
        self.global_index_last_update_timestamp.write(Time::now());
        self.exit_wait_window.write(DEFAULT_EXIT_WAIT_WINDOW);
        self.is_paused.write(false);
    }

    #[abi(embed_v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: Amount,
            pool_enabled: bool,
            commission: Commission,
        ) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let staker_address = get_caller_address();
            assert_with_err(self.staker_info.read(staker_address).is_none(), Error::STAKER_EXISTS);
            assert_with_err(
                self.operational_address_to_staker_address.read(operational_address).is_zero(),
                Error::OPERATIONAL_EXISTS
            );
            assert_with_err(amount >= self.min_stake.read(), Error::AMOUNT_LESS_THAN_MIN_STAKE);
            assert_with_err(commission <= COMMISSION_DENOMINATOR, Error::COMMISSION_OUT_OF_RANGE);
            // Transfer funds from staker.
            let staking_contract = get_contract_address();
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher
                .checked_transfer_from(
                    sender: staker_address, recipient: staking_contract, amount: amount.into()
                );
            // If pool is enabled, deploy a pool contract.
            let pool_info = if pool_enabled {
                let pool_contract = self
                    .deploy_delegation_pool_from_staking_contract(
                        :staker_address,
                        :staking_contract,
                        token_address: token_dispatcher.contract_address,
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
            // Create the record for the staker.
            self
                .staker_info
                .write(
                    staker_address,
                    Option::Some(
                        InternalStakerInfo {
                            reward_address,
                            operational_address,
                            unstake_time: Option::None,
                            amount_own: amount,
                            index: self.global_index.read(),
                            unclaimed_rewards_own: Zero::zero(),
                            pool_info,
                        }
                    )
                );
            // Update the operational address mapping, which is a 1 to 1 mapping.
            self.operational_address_to_staker_address.write(operational_address, staker_address);
            // Update total stake.
            self.add_to_total_stake(:amount);
            // Emit events.
            self
                .emit(
                    Events::NewStaker {
                        staker_address, reward_address, operational_address, self_stake: amount
                    }
                );
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
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: Amount
        ) -> Amount {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let caller_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            assert_with_err(
                caller_address == staker_address || caller_address == staker_info.reward_address,
                Error::CALLER_CANNOT_INCREASE_STAKE
            );
            let old_self_stake = staker_info.amount_own;
            // Transfer funds from caller (which is either the staker or their reward address).
            let staking_contract_address = get_contract_address();
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher
                .checked_transfer_from(
                    sender: caller_address,
                    recipient: staking_contract_address,
                    amount: amount.into()
                );
            // Update the the staker info before updating their staked amount.
            self.update_rewards(ref :staker_info);
            // Update the staker's staked amount, and add to total_stake.
            staker_info.amount_own += amount;
            let mut staker_total_stake = staker_info.amount_own;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            self.add_to_total_stake(:amount);
            // Emit events.
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

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> Amount {
            self.general_prerequisites();
            let mut staker_info = self.internal_staker_info(:staker_address);
            let caller_address = get_caller_address();
            let reward_address = staker_info.reward_address;
            assert_with_err(
                caller_address == staker_address || caller_address == reward_address,
                Error::CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
            );
            self.update_rewards(ref :staker_info);
            let amount = staker_info.unclaimed_rewards_own;
            let token_dispatcher = self.token_dispatcher.read();
            self.send_rewards_to_staker(:staker_address, ref :staker_info, :token_dispatcher);
            self.staker_info.write(staker_address, Option::Some(staker_info));
            amount
        }

        fn unstake_intent(ref self: ContractState) -> TimeStamp {
            self.general_prerequisites();
            let staker_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            self.update_rewards(ref :staker_info);
            let unstake_time = Time::now().add(self.exit_wait_window.read());
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

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> Amount {
            self.general_prerequisites();
            let mut staker_info = self.internal_staker_info(:staker_address);
            let unstake_time = staker_info
                .unstake_time
                .expect_with_err(Error::MISSING_UNSTAKE_INTENT);
            assert_with_err(Time::now() >= unstake_time, Error::INTENT_WINDOW_NOT_FINISHED);
            let token_dispatcher = self.token_dispatcher.read();
            self.send_rewards_to_staker(:staker_address, ref :staker_info, :token_dispatcher);
            // Transfer stake to staker.
            let staker_amount = staker_info.amount_own;
            token_dispatcher
                .checked_transfer(recipient: staker_address, amount: staker_amount.into());

            self.transfer_to_pool_when_unstake(:staker_address, ref :staker_info);
            self.remove_staker(:staker_address, :staker_info);
            staker_amount
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) {
            self.general_prerequisites();
            let staker_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            let old_address = staker_info.reward_address;
            staker_info.reward_address = reward_address;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            self
                .emit(
                    Events::StakerRewardAddressChanged {
                        staker_address, new_address: reward_address, old_address
                    }
                );
        }

        fn set_open_for_delegation(
            ref self: ContractState, commission: Commission
        ) -> ContractAddress {
            self.general_prerequisites();
            let staker_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert_with_err(commission <= COMMISSION_DENOMINATOR, Error::COMMISSION_OUT_OF_RANGE);
            assert_with_err(staker_info.pool_info.is_none(), Error::STAKER_ALREADY_HAS_POOL);
            let pool_contract = self
                .deploy_delegation_pool_from_staking_contract(
                    :staker_address,
                    staking_contract: get_contract_address(),
                    token_address: self.token_dispatcher.read().contract_address,
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

        fn staker_info(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            let mut staker_info = self.internal_staker_info(:staker_address);
            self.update_rewards(ref :staker_info);
            staker_info.into()
        }

        fn get_staker_info(
            self: @ContractState, staker_address: ContractAddress
        ) -> Option<StakerInfo> {
            if self.staker_info.read(staker_address).is_none() {
                return Option::None;
            }
            Option::Some(self.staker_info(:staker_address))
        }

        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            StakingContractInfo {
                min_stake: self.min_stake.read(),
                token_address: self.token_dispatcher.read().contract_address,
                global_index: self.global_index.read(),
                pool_contract_class_hash: self.pool_contract_class_hash.read(),
                reward_supplier: self.reward_supplier_dispatcher.read().contract_address,
                exit_wait_window: self.exit_wait_window.read()
            }
        }

        fn get_total_stake(self: @ContractState) -> Amount {
            self.total_stake.read()
        }

        fn get_pool_exit_intent(
            self: @ContractState, undelegate_intent_key: UndelegateIntentKey
        ) -> UndelegateIntentValue {
            let undelegate_intent_value = self.pool_exit_intents.read(undelegate_intent_key);
            // The following assertion serves as a sanity check.
            undelegate_intent_value.assert_valid();
            undelegate_intent_value
        }

        fn update_global_index_if_needed(ref self: ContractState) -> bool {
            self.assert_is_unpaused();
            if self.is_index_update_needed() {
                self.update_global_index();
                return true;
            }
            false
        }

        fn change_operational_address(
            ref self: ContractState, operational_address: ContractAddress
        ) {
            self.general_prerequisites();
            assert_with_err(
                self.operational_address_to_staker_address.read(operational_address).is_zero(),
                Error::OPERATIONAL_EXISTS
            );
            let staker_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert_with_err(
                self.eligible_operational_addresses.read(operational_address) == staker_address,
                Error::OPERATIONAL_NOT_ELIGIBLE
            );
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
        }

        fn declare_operational_address(ref self: ContractState, staker_address: ContractAddress) {
            self.general_prerequisites();
            let operational_address = get_caller_address();
            if self.eligible_operational_addresses.read(operational_address) == staker_address {
                return;
            }
            self.eligible_operational_addresses.write(operational_address, staker_address);
            self.emit(Events::OperationalAddressDeclared { operational_address, staker_address });
        }

        fn update_commission(ref self: ContractState, commission: Commission) {
            self.general_prerequisites();
            let staker_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            let pool_info = staker_info.get_pool_info_unchecked();
            let pool_contract = pool_info.pool_contract;
            let old_commission = pool_info.commission;
            if commission == old_commission {
                return;
            }
            assert_with_err(commission < old_commission, Error::INVALID_COMMISSION);
            self.update_rewards(ref :staker_info);
            let mut pool_info = staker_info.get_pool_info_unchecked();
            pool_info.commission = commission;
            staker_info.pool_info = Option::Some(pool_info);
            self.staker_info.write(staker_address, Option::Some(staker_info));
            let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
            pool_dispatcher.update_commission_from_staking_contract(:commission);
            self
                .emit(
                    Events::CommissionChanged {
                        staker_address, pool_contract, old_commission, new_commission: commission
                    }
                );
        }

        fn is_paused(self: @ContractState) -> bool {
            self.is_paused.read()
        }
    }

    #[abi(embed_v0)]
    impl IStakingTesterImpl of IStakingTester<ContractState> {
        fn token_address(self: @ContractState) -> ContractAddress {
            self.token_dispatcher.read().contract_address
        }
        fn pool_admin(self: @ContractState) -> ContractAddress {
            self.pool_contract_admin.read()
        }
        fn pool_class_hash(self: @ContractState) -> ClassHash {
            self.pool_contract_class_hash.read()
        }
    }

    #[abi(embed_v0)]
    impl StakingPoolImpl of IStakingPool<ContractState> {
        fn add_stake_from_pool(
            ref self: ContractState, staker_address: ContractAddress, amount: Amount
        ) -> Index {
            self.general_prerequisites();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            self.update_rewards(ref :staker_info);
            let mut pool_info = staker_info.get_pool_info_unchecked();
            let pool_contract = pool_info.pool_contract;
            assert_with_err(
                pool_contract == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );

            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher
                .checked_transfer_from(
                    sender: pool_contract, recipient: get_contract_address(), amount: amount.into()
                );
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
            staker_info.index
        }

        fn remove_from_delegation_pool_intent(
            ref self: ContractState,
            staker_address: ContractAddress,
            identifier: felt252,
            amount: Amount,
        ) -> TimeStamp {
            self.general_prerequisites();
            let mut staker_info = self.internal_staker_info(:staker_address);
            let mut pool_info = staker_info.get_pool_info_unchecked();
            assert_with_err(
                pool_info.pool_contract == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );
            let undelegate_intent_key = UndelegateIntentKey {
                pool_contract: pool_info.pool_contract, identifier
            };
            let undelegate_intent_value = self.get_pool_exit_intent(:undelegate_intent_key);
            let old_intent_amount = undelegate_intent_value.amount;
            let old_delegated_stake = pool_info.amount;
            let total_amount = old_intent_amount + old_delegated_stake;
            assert_with_err(amount <= total_amount, Error::AMOUNT_TOO_HIGH);
            let new_delegated_stake = total_amount - amount;
            pool_info.amount = new_delegated_stake;
            self.update_rewards(ref :staker_info);
            let unpool_time = staker_info
                .compute_unpool_time(exit_wait_window: self.exit_wait_window.read());
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

        fn remove_from_delegation_pool_action(ref self: ContractState, identifier: felt252) {
            self.general_prerequisites();
            let pool_contract = get_caller_address();
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let undelegate_intent = self.get_pool_exit_intent(:undelegate_intent_key);
            if undelegate_intent.amount.is_zero() {
                return;
            }
            assert_with_err(
                Time::now() >= undelegate_intent.unpool_time, Error::INTENT_WINDOW_NOT_FINISHED
            );
            self.clear_undelegate_intent(:undelegate_intent_key);
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher
                .checked_transfer(
                    recipient: pool_contract, amount: undelegate_intent.amount.into()
                );
            self
                .emit(
                    Events::RemoveFromDelegationPoolAction {
                        pool_contract, identifier, amount: undelegate_intent.amount
                    }
                );
        }

        fn switch_staking_delegation_pool(
            ref self: ContractState,
            to_staker: ContractAddress,
            to_pool: ContractAddress,
            switched_amount: Amount,
            data: Span<felt252>,
            identifier: felt252
        ) {
            self.general_prerequisites();
            if switched_amount.is_zero() {
                return;
            }
            let pool_contract = get_caller_address();
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let mut undelegate_intent_value = self.get_pool_exit_intent(:undelegate_intent_key);
            assert_with_err(
                undelegate_intent_value.is_non_zero(), Error::MISSING_UNDELEGATE_INTENT
            );
            assert_with_err(
                undelegate_intent_value.amount >= switched_amount, Error::AMOUNT_TOO_HIGH
            );
            let mut to_staker_info = self.internal_staker_info(staker_address: to_staker);
            self.update_rewards(ref staker_info: to_staker_info);
            assert_with_err(to_staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            let mut to_staker_pool_info = to_staker_info.get_pool_info_unchecked();
            let to_staker_pool_contract = to_staker_pool_info.pool_contract;
            assert_with_err(to_pool == to_staker_pool_contract, Error::DELEGATION_POOL_MISMATCH);

            let old_delegated_stake = to_staker_pool_info.amount;
            to_staker_pool_info.amount += switched_amount;
            to_staker_info.pool_info = Option::Some(to_staker_pool_info);
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
            self
                .emit(
                    Events::StakeBalanceChanged {
                        staker_address: to_staker,
                        old_self_stake: to_staker_info.amount_own,
                        old_delegated_stake,
                        new_self_stake: to_staker_info.amount_own,
                        new_delegated_stake: to_staker_pool_info.amount
                    }
                );
        }

        fn claim_delegation_pool_rewards(
            ref self: ContractState, staker_address: ContractAddress
        ) -> Index {
            self.general_prerequisites();
            let mut staker_info = self.internal_staker_info(:staker_address);
            let pool_address = staker_info.get_pool_info_unchecked().pool_contract;
            assert_with_err(
                pool_address == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );
            self.update_rewards(ref :staker_info);
            // The function update_rewards updated the index in staker_info.
            let updated_index = staker_info.index;
            let token_dispatcher = self.token_dispatcher.read();
            self
                .send_rewards_to_delegation_pool(
                    :staker_address, ref :staker_info, :token_dispatcher
                );
            self.staker_info.write(staker_address, Option::Some(staker_info));
            updated_index
        }
    }

    #[abi(embed_v0)]
    impl StakingPauseImpl of IStakingPause<ContractState> {
        fn pause(ref self: ContractState) {
            self.roles.only_security_agent();
            if self.is_paused() {
                return;
            }
            self.is_paused.write(true);
            self.emit(PauseEvents::Paused { account: get_caller_address() });
        }

        fn unpause(ref self: ContractState) {
            self.roles.only_security_admin();
            if !self.is_paused() {
                return;
            }
            self.is_paused.write(false);
            self.emit(PauseEvents::Unpaused { account: get_caller_address() });
        }
    }

    #[abi(embed_v0)]
    impl StakingConfigImpl of IStakingConfig<ContractState> {
        fn set_min_stake(ref self: ContractState, min_stake: Amount) {
            self.roles.only_token_admin();
            let old_min_stake = self.min_stake.read();
            self.min_stake.write(min_stake);
            self
                .emit(
                    ConfigEvents::MinimumStakeChanged { old_min_stake, new_min_stake: min_stake }
                );
        }

        fn set_exit_wait_window(ref self: ContractState, exit_wait_window: TimeDelta) {
            self.roles.only_token_admin();
            let old_exit_window = self.exit_wait_window.read();
            self.exit_wait_window.write(exit_wait_window);
            self
                .emit(
                    ConfigEvents::ExitWaitWindowChanged {
                        old_exit_window, new_exit_window: exit_wait_window
                    }
                );
        }

        fn set_reward_supplier(ref self: ContractState, reward_supplier: ContractAddress) {
            self.roles.only_token_admin();
            let old_reward_supplier = self.reward_supplier_dispatcher.read().contract_address;
            self
                .reward_supplier_dispatcher
                .write(IRewardSupplierDispatcher { contract_address: reward_supplier });
            self
                .emit(
                    ConfigEvents::RewardSupplierChanged {
                        old_reward_supplier, new_reward_supplier: reward_supplier
                    }
                );
        }
    }

    #[generate_trait]
    pub impl InternalStakingFunctions of InternalStakingFunctionsTrait {
        fn send_rewards(
            self: @ContractState,
            reward_address: ContractAddress,
            amount: Amount,
            token_dispatcher: IERC20Dispatcher
        ) {
            let reward_supplier_dispatcher = self.reward_supplier_dispatcher.read();
            let balance_before = token_dispatcher.balance_of(account: get_contract_address());
            reward_supplier_dispatcher.claim_rewards(:amount);
            let balance_after = token_dispatcher.balance_of(account: get_contract_address());
            assert_with_err(
                balance_after - balance_before == amount.into(), Error::UNEXPECTED_BALANCE
            );
            token_dispatcher.checked_transfer(recipient: reward_address, amount: amount.into());
        }

        /// Sends the rewards to `staker_address`'s reward address.
        /// Important note:
        /// After calling this function, one must write the updated staker_info to the storage.
        fn send_rewards_to_staker(
            ref self: ContractState,
            staker_address: ContractAddress,
            ref staker_info: InternalStakerInfo,
            token_dispatcher: IERC20Dispatcher
        ) {
            let reward_address = staker_info.reward_address;
            let amount = staker_info.unclaimed_rewards_own;

            self.send_rewards(:reward_address, :amount, :token_dispatcher);
            staker_info.unclaimed_rewards_own = Zero::zero();

            self.emit(Events::StakerRewardClaimed { staker_address, reward_address, amount });
        }
        /// Sends the rewards to `staker_address`'s pool contract.
        /// Important note:
        /// After calling this function, one must write the updated staker_info to the storage.
        fn send_rewards_to_delegation_pool(
            ref self: ContractState,
            staker_address: ContractAddress,
            ref staker_info: InternalStakerInfo,
            token_dispatcher: IERC20Dispatcher
        ) {
            let mut pool_info = staker_info.get_pool_info_unchecked();
            let pool_address = pool_info.pool_contract;
            let amount = pool_info.unclaimed_rewards;

            self.send_rewards(reward_address: pool_address, :amount, :token_dispatcher);
            pool_info.unclaimed_rewards = Zero::zero();
            staker_info.pool_info = Option::Some(pool_info);

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

        fn assert_caller_is_not_zero(self: @ContractState) {
            assert_with_err(get_caller_address().is_non_zero(), Error::CALLER_IS_ZERO_ADDRESS);
        }

        fn internal_staker_info(
            self: @ContractState, staker_address: ContractAddress
        ) -> InternalStakerInfo {
            self.staker_info.read(staker_address).expect_with_err(Error::STAKER_NOT_EXISTS)
        }

        fn calculate_and_update_pool_rewards(
            self: @ContractState, interest: Index, ref staker_info: InternalStakerInfo
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
            ref self: ContractState,
            staker_address: ContractAddress,
            ref staker_info: InternalStakerInfo
        ) {
            if let Option::Some(pool_info) = staker_info.pool_info {
                let token_dispatcher = self.token_dispatcher.read();
                self
                    .send_rewards_to_delegation_pool(
                        :staker_address, ref :staker_info, :token_dispatcher
                    );
                token_dispatcher
                    .checked_transfer(
                        recipient: pool_info.pool_contract, amount: pool_info.amount.into()
                    );
                let pool_dispatcher = IPoolDispatcher { contract_address: pool_info.pool_contract };
                pool_dispatcher.set_final_staker_index(final_staker_index: staker_info.index);
            }
        }

        fn remove_staker(
            ref self: ContractState,
            staker_address: ContractAddress,
            staker_info: InternalStakerInfo
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
        fn update_rewards(self: @ContractState, ref staker_info: InternalStakerInfo) {
            if (staker_info.unstake_time.is_some()) {
                return;
            }
            let global_index = self.global_index.read();
            let interest = global_index - staker_info.index;
            staker_info.index = global_index;

            let staker_rewards = compute_rewards_rounded_down(
                amount: staker_info.amount_own, :interest
            );
            staker_info.unclaimed_rewards_own += staker_rewards;
            self.calculate_and_update_pool_rewards(:interest, ref :staker_info);
        }

        fn deploy_delegation_pool_from_staking_contract(
            ref self: ContractState,
            staker_address: ContractAddress,
            staking_contract: ContractAddress,
            token_address: ContractAddress,
            commission: Commission,
        ) -> ContractAddress {
            let class_hash = self.pool_contract_class_hash.read();
            let contract_address_salt: felt252 = Time::now().seconds.into();
            let governance_admin = self.pool_contract_admin.read();
            let pool_contract = deploy_delegation_pool_contract(
                :class_hash,
                :contract_address_salt,
                :staker_address,
                :staking_contract,
                :token_address,
                :commission,
                :governance_admin
            );
            self.emit(Events::NewDelegationPool { staker_address, pool_contract, commission });
            pool_contract
        }

        fn add_to_total_stake(ref self: ContractState, amount: Amount) {
            self.total_stake.write(self.total_stake.read() + amount);
        }

        fn remove_from_total_stake(ref self: ContractState, amount: Amount) {
            self.total_stake.write(self.total_stake.read() - amount);
        }

        fn is_index_update_needed(self: @ContractState) -> bool {
            let time_diff = Time::now().sub(self.global_index_last_update_timestamp.read());
            time_diff >= MIN_TIME_BETWEEN_INDEX_UPDATES
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
            let global_index_current_update_timestamp = Time::now();
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

        /// Wrap initial operations required in any public staking function.
        fn general_prerequisites(ref self: ContractState) {
            self.assert_is_unpaused();
            self.assert_caller_is_not_zero();
            self.update_global_index_if_needed();
        }
    }
}
