#[starknet::contract]
pub mod Pooling {
    use core::serde::Serde;
    use core::num::traits::zero::Zero;
    use contracts::{
        constants::{BASE_VALUE}, errors::{Error, panic_by_err, assert_with_err, OptionAuxTrait},
        pooling::{IPooling, PoolMemberInfo, Events},
        utils::{u128_mul_wide_and_div_unsafe, compute_rewards, compute_commission}
    };
    use core::option::OptionTrait;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use openzeppelin::{
        access::accesscontrol::AccessControlComponent, introspection::src5::SRC5Component
    };
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use contracts::staking::interface::{IStakingDispatcherTrait, IStakingDispatcher};

    // TODO: Decide if MIN_DELEGATION_AMOUNT is needed (if needed then decide on a value). 
    // Right now, there is no minimum delegation amount.
    pub const MIN_DELEGATION_AMOUNT: u128 = 1;

    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[derive(Debug, Drop, Serde, Copy)]
    pub struct SwitchPoolData {
        pub pool_member: ContractAddress,
        pub reward_address: ContractAddress,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        staker_address: ContractAddress,
        pool_member_info: LegacyMap::<ContractAddress, Option<PoolMemberInfo>>,
        final_staker_index: Option<u64>,
        staking_contract: ContractAddress,
        token_address: ContractAddress,
        rev_share: u16,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event,
        pool_member_exit_intent: Events::PoolMemberExitIntent,
    }


    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        staker_address: ContractAddress,
        staking_contract: ContractAddress,
        token_address: ContractAddress,
        rev_share: u16
    ) {
        self.staker_address.write(staker_address);
        self.staking_contract.write(staking_contract);
        self.token_address.write(token_address);
        self.rev_share.write(rev_share);
    }

    #[abi(embed_v0)]
    impl PoolingImpl of IPooling<ContractState> {
        fn enter_delegation_pool(
            ref self: ContractState, amount: u128, reward_address: ContractAddress
        ) -> bool {
            self.assert_staker_is_active();
            let pool_member = get_caller_address();
            assert_with_err(
                self.pool_member_info.read(pool_member).is_none(), Error::POOL_MEMBER_EXISTS
            );
            assert_with_err(amount >= MIN_DELEGATION_AMOUNT, Error::MIN_DELEGATION_AMOUNT);
            let pooled_staker = self.staker_address.read();
            let staking_contract = self.staking_contract.read();
            let staking_contract_dispatcher = IStakingDispatcher {
                contract_address: staking_contract,
            };
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            let self_contract = get_contract_address();
            erc20_dispatcher
                .transfer_from(
                    sender: pool_member, recipient: self_contract, amount: amount.into()
                );
            erc20_dispatcher.approve(spender: staking_contract, amount: amount.into());
            let (_, updated_index) = staking_contract_dispatcher
                .add_to_delegation_pool(:pooled_staker, :amount);
            self
                .pool_member_info
                .write(
                    pool_member,
                    Option::Some(
                        PoolMemberInfo {
                            reward_address: reward_address,
                            amount: amount,
                            index: updated_index,
                            unclaimed_rewards: 0,
                            unpool_time: Option::None,
                        }
                    )
                );
            true
        }

        fn add_to_delegation_pool(
            ref self: ContractState, pool_member: ContractAddress, amount: u128
        ) -> u128 {
            self.assert_staker_is_active();
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            assert_with_err(pool_member_info.unpool_time.is_none(), Error::UNDELEGATE_IN_PROGRESS);
            assert_with_err(amount >= MIN_DELEGATION_AMOUNT, Error::MIN_DELEGATION_AMOUNT);
            let caller_address = get_caller_address();
            assert_with_err(
                caller_address == pool_member || caller_address == pool_member_info.reward_address,
                Error::CALLER_CANNOT_ADD_TO_POOL
            );
            let staking_contract = self.staking_contract.read();
            let staking_contract_dispatcher = IStakingDispatcher {
                contract_address: staking_contract,
            };
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            let self_contract = get_contract_address();
            erc20_dispatcher
                .transfer_from(
                    sender: pool_member, recipient: self_contract, amount: amount.into()
                );
            erc20_dispatcher.approve(spender: staking_contract, amount: amount.into());
            let (_, updated_index) = staking_contract_dispatcher
                .add_to_delegation_pool(pooled_staker: self.staker_address.read(), :amount);
            self.calculate_rewards(ref :pool_member_info, :updated_index);
            pool_member_info.amount += amount;
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            // TODO: emit event
            pool_member_info.amount
        }

        fn exit_delegation_pool_intent(ref self: ContractState) {
            let pool_member = get_caller_address();
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            assert_with_err(pool_member_info.unpool_time.is_none(), Error::UNDELEGATE_IN_PROGRESS);
            self.update_index_and_calculate_rewards(ref :pool_member_info);
            let unpool_time = self
                .undelegate_from_staking_contract_intent(
                    :pool_member, amount: pool_member_info.amount
                );
            pool_member_info.unpool_time = Option::Some(unpool_time);
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            self.emit(Events::PoolMemberExitIntent { pool_member, exit_at: unpool_time });
        }

        fn exit_delegation_pool_action(ref self: ContractState) -> u128 {
            0
        }

        fn claim_rewards(ref self: ContractState, pool_member: ContractAddress) -> u128 {
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            let caller_address = get_caller_address();
            assert_with_err(
                caller_address == pool_member || caller_address == pool_member_info.reward_address,
                Error::POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
            );
            self.update_index_and_calculate_rewards(ref :pool_member_info);

            let rewards = pool_member_info.unclaimed_rewards;
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer(recipient: pool_member_info.reward_address, amount: rewards.into());

            pool_member_info.unclaimed_rewards = 0;
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            rewards
        }

        fn switch_delegation_pool(
            ref self: ContractState,
            to_staker: ContractAddress,
            to_pool: ContractAddress,
            amount: u128
        ) -> u128 {
            assert_with_err(amount >= MIN_DELEGATION_AMOUNT, Error::MIN_DELEGATION_AMOUNT);
            let pool_member = get_caller_address();
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            assert_with_err(
                pool_member_info.unpool_time.is_some(), Error::MISSING_UNDELEGATE_INTENT
            );
            assert_with_err(pool_member_info.amount >= amount, Error::AMOUNT_TOO_HIGH);
            let span_data = self.get_serialized_switch_pool_data(:pool_member, :pool_member_info);
            let staking_dispatcher = IStakingDispatcher {
                contract_address: self.staking_contract.read()
            };
            let amount_left = pool_member_info.amount - amount;
            if amount_left == 0 {
                self.remove_pool_member(:pool_member);
            } else {
                pool_member_info.amount = amount_left;
                self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            };
            // TODO: emit event
            staking_dispatcher
                .switch_staking_delegation_pool(
                    from_staker: self.staker_address.read(),
                    :to_staker,
                    :to_pool,
                    :amount,
                    data: span_data
                );
            amount_left
        }

        fn enter_from_staking_contract(
            ref self: ContractState, amount: u128, index: u64, data: Span<felt252>
        ) -> bool {
            true
        }

        fn set_final_staker_index(ref self: ContractState, final_staker_index: u64) {
            let staking_contract = get_caller_address();
            assert_with_err(
                staking_contract == self.staking_contract.read(),
                Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            assert_with_err(
                self.final_staker_index.read().is_none(), Error::FINAL_STAKER_INDEX_ALREADY_SET
            );
            self.final_staker_index.write(Option::Some(final_staker_index));
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            let pool_member = get_caller_address();
            let mut pool_member_info = self.get_pool_member_info(:pool_member);
            pool_member_info.reward_address = reward_address;
            self.pool_member_info.write(pool_member, Option::Some(pool_member_info));
            true
        }

        fn state_of(self: @ContractState, pool_member: ContractAddress) -> PoolMemberInfo {
            self.get_pool_member_info(:pool_member)
        }
    }

    #[generate_trait]
    pub(crate) impl InternalPoolingFunctions of InternalPoolingFunctionsTrait {
        fn get_pool_member_info(
            self: @ContractState, pool_member: ContractAddress
        ) -> PoolMemberInfo {
            self
                .pool_member_info
                .read(pool_member)
                .expect_with_err(Error::POOL_MEMBER_DOES_NOT_EXIST)
        }

        fn remove_pool_member(ref self: ContractState, pool_member: ContractAddress) {
            self.pool_member_info.write(pool_member, Option::None);
        }

        fn receive_index_and_funds_from_staker(self: @ContractState) -> u64 {
            if let Option::Some(final_index) = self.final_staker_index.read() {
                // If the staker is inactive, the staker already pushed index and funds.
                return final_index;
            }
            let staking_dispatcher = IStakingDispatcher {
                contract_address: self.staking_contract.read()
            };
            staking_dispatcher.claim_delegation_pool_rewards(self.staker_address.read())
        }

        fn get_serialized_switch_pool_data(
            self: @ContractState, pool_member: ContractAddress, pool_member_info: PoolMemberInfo
        ) -> Span<felt252> {
            let reward_address = pool_member_info.reward_address;
            let switch_pool_data = SwitchPoolData { pool_member, reward_address };
            let mut data = array![];
            switch_pool_data.serialize(ref data);
            data.span()
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
            if (pool_member_info.unpool_time.is_some()) {
                return false;
            }
            let interest: u64 = updated_index - pool_member_info.index;
            pool_member_info.index = updated_index;
            let mut rewards = compute_rewards(amount: pool_member_info.amount, :interest);
            let commission = compute_commission(:rewards, rev_share: self.rev_share.read());
            rewards -= commission;
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
                return get_block_timestamp();
            }
            let staking_dispatcher = IStakingDispatcher {
                contract_address: self.staking_contract.read()
            };
            let staker_address = self.staker_address.read();
            staking_dispatcher
                .remove_from_delegation_pool_intent(
                    :staker_address, identifier: pool_member.into(), :amount
                )
        }
    }
}
