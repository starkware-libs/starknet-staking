#[starknet::contract]
pub mod Pool {
    use core::serde::Serde;
    use core::num::traits::zero::Zero;
    use contracts::errors::{Error, assert_with_err, OptionAuxTrait};
    use contracts::pool::{interface::PoolContractInfo, IPool, PoolMemberInfo, Events};
    use contracts::utils::{compute_rewards_rounded_down, compute_commission_amount_rounded_up};
    use core::option::OptionTrait;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use contracts::staking::interface::{IStakingPoolDispatcher, IStakingPoolDispatcherTrait};
    use starknet::storage::Map;
    use contracts_commons::components::roles::RolesComponent;
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use contracts::utils::CheckedIERC20DispatcherTrait;

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ReplaceabilityImpl =
        ReplaceabilityComponent::ReplaceabilityImpl<ContractState>;

    #[abi(embed_v0)]
    impl RolesImpl = RolesComponent::RolesImpl<ContractState>;

    #[derive(Debug, Drop, Serde, Copy)]
    pub struct SwitchPoolData {
        pub pool_member: ContractAddress,
        pub reward_address: ContractAddress,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        replaceability: ReplaceabilityComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        roles: RolesComponent::Storage,
        staker_address: ContractAddress,
        pool_member_info: Map<ContractAddress, Option<PoolMemberInfo>>,
        final_staker_index: Option<u64>,
        staking_pool_dispatcher: IStakingPoolDispatcher,
        erc20_dispatcher: IERC20Dispatcher,
        commission: u16,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        PoolMemberExitIntent: Events::PoolMemberExitIntent,
        DelegationPoolMemberBalanceChanged: Events::DelegationPoolMemberBalanceChanged,
        PoolMemberRewardAddressChanged: Events::PoolMemberRewardAddressChanged,
        FinalIndexSet: Events::FinalIndexSet,
        PoolMemberRewardClaimed: Events::PoolMemberRewardClaimed,
        DeletePoolMember: Events::DeletePoolMember,
        NewPoolMember: Events::NewPoolMember,
    }


    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        staker_address: ContractAddress,
        staking_contract: ContractAddress,
        token_address: ContractAddress,
        commission: u16
    ) {
        self.accesscontrol.initializer();
        self.roles.initializer();
        self.replaceability.upgrade_delay.write(Zero::zero());
        self.staker_address.write(staker_address);
        self
            .staking_pool_dispatcher
            .write(IStakingPoolDispatcher { contract_address: staking_contract });
        self.erc20_dispatcher.write(IERC20Dispatcher { contract_address: token_address });
        self.commission.write(commission);
    }

    #[abi(embed_v0)]
    impl PoolImpl of IPool<ContractState> {
        fn enter_delegation_pool(
            ref self: ContractState, reward_address: ContractAddress, amount: u128
        ) -> bool {
            // This line was added to prevent the compiler from doing certain optimizations.
            core::internal::revoke_ap_tracking();
            self.assert_staker_is_active();
            let pool_member = get_caller_address();
            assert_with_err(
                self.pool_member_info.read(pool_member).is_none(), Error::POOL_MEMBER_EXISTS
            );
            assert_with_err(amount.is_non_zero(), Error::AMOUNT_IS_ZERO);
            let staker_address = self.staker_address.read();
            let staking_pool_dispatcher = self.staking_pool_dispatcher.read();
            let erc20_dispatcher = self.erc20_dispatcher.read();
            let self_contract = get_contract_address();
            erc20_dispatcher
                .checked_transfer_from(
                    sender: pool_member, recipient: self_contract, amount: amount.into()
                );
            erc20_dispatcher
                .approve(spender: staking_pool_dispatcher.contract_address, amount: amount.into());
            let (_, updated_index) = staking_pool_dispatcher
                .add_stake_from_pool(:staker_address, :amount);
            self
                .pool_member_info
                .write(
                    pool_member,
                    Option::Some(
                        PoolMemberInfo {
                            reward_address: reward_address,
                            amount: amount,
                            index: updated_index,
                            unclaimed_rewards: Zero::zero(),
                            unpool_time: Option::None,
                            unpool_amount: Zero::zero(),
                        }
                    )
                );
            self
                .emit(
                    Events::NewPoolMember { pool_member, staker_address, reward_address, amount }
                );
            self
                .emit(
                    Events::DelegationPoolMemberBalanceChanged {
                        pool_member, old_delegated_stake: Zero::zero(), new_delegated_stake: amount
                    }
                );
            true
        }

        fn add_to_delegation_pool(
            ref self: ContractState, pool_member: ContractAddress, amount: u128
        ) -> u128 {
            self.assert_staker_is_active();
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            // This line was added to prevent the compiler from doing certain optimizations.
            core::internal::revoke_ap_tracking();
            let caller_address = get_caller_address();
            assert_with_err(
                caller_address == pool_member || caller_address == pool_member_info.reward_address,
                Error::CALLER_CANNOT_ADD_TO_POOL
            );
            let staking_pool_dispatcher = self.staking_pool_dispatcher.read();
            let erc20_dispatcher = self.erc20_dispatcher.read();
            let self_contract = get_contract_address();
            erc20_dispatcher
                .checked_transfer_from(
                    sender: pool_member, recipient: self_contract, amount: amount.into()
                );
            erc20_dispatcher
                .approve(spender: staking_pool_dispatcher.contract_address, amount: amount.into());
            let (_, updated_index) = staking_pool_dispatcher
                .add_stake_from_pool(staker_address: self.staker_address.read(), :amount);
            self.calculate_rewards(ref :pool_member_info, :updated_index);
            let old_delegated_stake = pool_member_info.amount;
            pool_member_info.amount += amount;
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            self
                .emit(
                    Events::DelegationPoolMemberBalanceChanged {
                        pool_member,
                        old_delegated_stake,
                        new_delegated_stake: pool_member_info.amount
                    }
                );
            pool_member_info.amount
        }

        fn exit_delegation_pool_intent(ref self: ContractState, amount: u128) {
            let pool_member = get_caller_address();
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            self.update_index_and_calculate_rewards(ref :pool_member_info);
            let total_amount = pool_member_info.amount + pool_member_info.unpool_amount;
            assert_with_err(amount <= total_amount, Error::AMOUNT_TOO_HIGH);
            let unpool_time = self.undelegate_from_staking_contract_intent(:pool_member, :amount);
            if amount.is_zero() {
                pool_member_info.unpool_time = Option::None;
            } else {
                pool_member_info.unpool_time = Option::Some(unpool_time);
            }
            pool_member_info.unpool_amount = amount;
            pool_member_info.amount = total_amount - amount;
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            self
                .emit(
                    Events::PoolMemberExitIntent {
                        pool_member, exit_timestamp: unpool_time, amount
                    }
                );
        }

        fn exit_delegation_pool_action(
            ref self: ContractState, pool_member: ContractAddress
        ) -> u128 {
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            let unpool_time = pool_member_info
                .unpool_time
                .expect_with_err(Error::MISSING_UNDELEGATE_INTENT);
            assert_with_err(
                get_block_timestamp() >= unpool_time, Error::INTENT_WINDOW_NOT_FINISHED
            );
            // Clear intent and receive funds from staking contract if needed.
            let staking_pool_dispatcher = self.staking_pool_dispatcher.read();
            staking_pool_dispatcher
                .remove_from_delegation_pool_action(identifier: pool_member.into());

            let erc20_dispatcher = self.erc20_dispatcher.read();
            // Claim rewards.
            self
                .send_rewards_to_pool_member(
                    :pool_member,
                    reward_address: pool_member_info.reward_address,
                    amount: pool_member_info.unclaimed_rewards,
                    :erc20_dispatcher
                );
            // Transfer delegated amount to the pool member.
            let unpool_amount = pool_member_info.unpool_amount;
            pool_member_info.unpool_amount = Zero::zero();
            erc20_dispatcher.checked_transfer(recipient: pool_member, amount: unpool_amount.into());
            if pool_member_info.amount.is_zero() {
                self.remove_pool_member(:pool_member);
            } else {
                pool_member_info.unpool_time = Option::None;
                self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            }
            unpool_amount
        }

        fn claim_rewards(ref self: ContractState, pool_member: ContractAddress) -> u128 {
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            let caller_address = get_caller_address();
            let reward_address = pool_member_info.reward_address;
            assert_with_err(
                caller_address == pool_member || caller_address == reward_address,
                Error::POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
            );
            self.update_index_and_calculate_rewards(ref :pool_member_info);
            let rewards = pool_member_info.unclaimed_rewards;
            let erc20_dispatcher = self.erc20_dispatcher.read();
            self
                .send_rewards_to_pool_member(
                    :pool_member, :reward_address, amount: rewards, :erc20_dispatcher
                );
            pool_member_info.unclaimed_rewards = Zero::zero();
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            rewards
        }

        fn switch_delegation_pool(
            ref self: ContractState,
            to_staker: ContractAddress,
            to_pool: ContractAddress,
            amount: u128
        ) -> u128 {
            assert_with_err(amount.is_non_zero(), Error::AMOUNT_IS_ZERO);
            let pool_member = get_caller_address();
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            assert_with_err(
                pool_member_info.unpool_time.is_some(), Error::MISSING_UNDELEGATE_INTENT
            );
            assert_with_err(pool_member_info.unpool_amount >= amount, Error::AMOUNT_TOO_HIGH);
            let switch_pool_data = SwitchPoolData {
                pool_member, reward_address: pool_member_info.reward_address
            };
            let mut serialized_data = array![];
            switch_pool_data.serialize(ref output: serialized_data);
            pool_member_info.unpool_amount -= amount;
            if pool_member_info.unpool_amount.is_zero() && pool_member_info.amount.is_zero() {
                // Claim rewards.
                let erc20_dispatcher = self.erc20_dispatcher.read();
                erc20_dispatcher
                    .checked_transfer(
                        recipient: pool_member_info.reward_address,
                        amount: pool_member_info.unclaimed_rewards.into()
                    );
                self.remove_pool_member(:pool_member);
            } else {
                // One of pool_member_info.unpool_amount or pool_member_info.amount is non-zero.
                if pool_member_info.unpool_amount.is_zero() {
                    pool_member_info.unpool_time = Option::None;
                }
                self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            }
            // TODO: emit event
            self
                .staking_pool_dispatcher
                .read()
                .switch_staking_delegation_pool(
                    :to_staker,
                    :to_pool,
                    switched_amount: amount,
                    data: serialized_data.span(),
                    identifier: pool_member.into()
                );
            pool_member_info.unpool_amount
        }

        fn enter_delegation_pool_from_staking_contract(
            ref self: ContractState, amount: u128, index: u64, data: Span<felt252>
        ) -> bool {
            assert_with_err(amount.is_non_zero(), Error::AMOUNT_IS_ZERO);
            assert_with_err(
                get_caller_address() == self.staking_pool_dispatcher.read().contract_address,
                Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            let mut serialized = data;
            let switch_pool_data: SwitchPoolData = Serde::deserialize(ref :serialized)
                .expect_with_err(Error::SWITCH_POOL_DATA_DESERIALIZATION_FAILED);
            let pool_member = switch_pool_data.pool_member;
            let pool_member_info = match self.pool_member_info.read(pool_member) {
                Option::Some(mut pool_member_info) => {
                    assert_with_err(
                        pool_member_info.reward_address == switch_pool_data.reward_address,
                        Error::REWARD_ADDRESS_MISMATCH
                    );
                    self.calculate_rewards(ref :pool_member_info, updated_index: index);
                    pool_member_info.amount += amount;
                    pool_member_info
                },
                Option::None => {
                    PoolMemberInfo {
                        reward_address: switch_pool_data.reward_address,
                        amount,
                        index,
                        unclaimed_rewards: Zero::zero(),
                        unpool_time: Option::None,
                        unpool_amount: Zero::zero(),
                    }
                }
            };
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            self
                .emit(
                    Events::DelegationPoolMemberBalanceChanged {
                        pool_member,
                        old_delegated_stake: pool_member_info.amount - amount,
                        new_delegated_stake: pool_member_info.amount
                    }
                );
            true
        }

        fn set_final_staker_index(ref self: ContractState, final_staker_index: u64) {
            let staking_contract = get_caller_address();
            assert_with_err(
                staking_contract == self.staking_pool_dispatcher.read().contract_address,
                Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            assert_with_err(
                self.final_staker_index.read().is_none(), Error::FINAL_STAKER_INDEX_ALREADY_SET
            );
            self.final_staker_index.write(Option::Some(final_staker_index));
            self
                .emit(
                    Events::FinalIndexSet {
                        staker_address: self.staker_address.read(), final_staker_index
                    }
                );
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            let pool_member = get_caller_address();
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            let old_address = pool_member_info.reward_address;
            pool_member_info.reward_address = reward_address;
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            self
                .emit(
                    Events::PoolMemberRewardAddressChanged {
                        pool_member, new_address: reward_address, old_address
                    }
                );
            true
        }

        fn state_of(self: @ContractState, pool_member: ContractAddress) -> PoolMemberInfo {
            self.get_pool_member_info(:pool_member)
        }

        fn contract_parameters(self: @ContractState) -> PoolContractInfo {
            PoolContractInfo {
                staker_address: self.staker_address.read(),
                final_staker_index: self.final_staker_index.read(),
                staking_contract: self.staking_pool_dispatcher.read().contract_address,
                token_address: self.erc20_dispatcher.read().contract_address,
                commission: self.commission.read(),
            }
        }

        fn update_commission(ref self: ContractState, commission: u16) -> bool {
            assert_with_err(
                get_caller_address() == self.staking_pool_dispatcher.read().contract_address,
                Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            assert_with_err(
                commission <= self.commission.read(), Error::CANNOT_INCREASE_COMMISSION
            );
            self.commission.write(commission);
            true
        }
    }

    #[generate_trait]
    pub(crate) impl InternalPoolFunctions of InternalPoolFunctionsTrait {
        fn get_pool_member_info(
            self: @ContractState, pool_member: ContractAddress
        ) -> PoolMemberInfo {
            self
                .pool_member_info
                .read(pool_member)
                .expect_with_err(Error::POOL_MEMBER_DOES_NOT_EXIST)
        }

        fn remove_pool_member(ref self: ContractState, pool_member: ContractAddress) {
            let pool_member_info = self.get_pool_member_info(:pool_member);
            self.pool_member_info.write(pool_member, Option::None);
            self
                .emit(
                    Events::DeletePoolMember {
                        pool_member, reward_address: pool_member_info.reward_address
                    }
                );
        }

        fn receive_index_and_funds_from_staker(self: @ContractState) -> u64 {
            if let Option::Some(final_index) = self.final_staker_index.read() {
                // If the staker is inactive, the staker already pushed index and funds.
                return final_index;
            }
            let staking_pool_dispatcher = self.staking_pool_dispatcher.read();
            staking_pool_dispatcher.claim_delegation_pool_rewards(self.staker_address.read())
        }

        /// Calculates the rewards for a pool member.
        ///
        /// The caller for this function should validate that the pool member exists.
        ///
        /// rewards formula:
        /// $$ rewards = (staker\_index-pooler\_index) * pooler\_amount $$
        ///
        /// Fields that are changed in pool_member_info:
        /// - unclaimed_rewards
        /// - index
        fn calculate_rewards(
            ref self: ContractState, ref pool_member_info: PoolMemberInfo, updated_index: u64
        ) -> bool {
            let interest: u64 = updated_index - pool_member_info.index;
            pool_member_info.index = updated_index;
            let rewards_including_commission = compute_rewards_rounded_down(
                amount: pool_member_info.amount, :interest
            );
            let commission_amount = compute_commission_amount_rounded_up(
                :rewards_including_commission, commission: self.commission.read()
            );
            let rewards = rewards_including_commission - commission_amount;
            pool_member_info.unclaimed_rewards += rewards;
            true
        }

        fn update_index_and_calculate_rewards(
            ref self: ContractState, ref pool_member_info: PoolMemberInfo
        ) -> bool {
            let updated_index = self.receive_index_and_funds_from_staker();
            self.calculate_rewards(ref :pool_member_info, :updated_index)
        }

        fn assert_staker_is_active(self: @ContractState) {
            assert_with_err(self.final_staker_index.read().is_none(), Error::STAKER_INACTIVE);
        }

        fn is_staker_active(self: @ContractState) -> bool {
            self.final_staker_index.read().is_none()
        }

        fn undelegate_from_staking_contract_intent(
            self: @ContractState, pool_member: ContractAddress, amount: u128
        ) -> u64 {
            if !self.is_staker_active() {
                // Don't allow intent if an intent is already in progress and the staker is erased.
                assert_with_err(
                    self.get_pool_member_info(:pool_member).unpool_time.is_none(),
                    Error::UNDELEGATE_IN_PROGRESS
                );
                return get_block_timestamp();
            }
            let staking_pool_dispatcher = self.staking_pool_dispatcher.read();
            let staker_address = self.staker_address.read();
            staking_pool_dispatcher
                .remove_from_delegation_pool_intent(
                    :staker_address, identifier: pool_member.into(), :amount
                )
        }

        fn send_rewards_to_pool_member(
            ref self: ContractState,
            pool_member: ContractAddress,
            reward_address: ContractAddress,
            amount: u128,
            erc20_dispatcher: IERC20Dispatcher
        ) {
            erc20_dispatcher.checked_transfer(recipient: reward_address, amount: amount.into());
            self.emit(Events::PoolMemberRewardClaimed { pool_member, reward_address, amount });
        }
    }
}
