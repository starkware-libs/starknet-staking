#[starknet::contract]
pub mod Pooling {
    use core::num::traits::zero::Zero;
    use contracts::{
        BASE_VALUE, errors::{Error, panic_by_err, assert_with_err, expect_with_err},
        pooling::{IPooling, PoolMemberInfo},
        utils::{u128_mul_wide_and_div_unsafe, compute_rewards, compute_commission}
    };
    use core::option::OptionTrait;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::{
        access::accesscontrol::AccessControlComponent, introspection::src5::SRC5Component
    };
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use contracts::staking::interface::{IStakingDispatcherTrait, IStakingDispatcher};

    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        staker_address: ContractAddress,
        pool_member_address_to_info: LegacyMap::<ContractAddress, PoolMemberInfo>,
        final_staker_index: Option<u64>,
        staking_contract: ContractAddress,
        token_address: ContractAddress,
        rev_share: u16,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event
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
                self.pool_member_address_to_info.read(pool_member).amount.is_zero(),
                Error::POOL_MEMBER_EXISTS
            );
            assert_with_err(amount > 0, Error::AMOUNT_IS_ZERO);
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
                .pool_member_address_to_info
                .write(
                    pool_member,
                    PoolMemberInfo {
                        reward_address: reward_address,
                        amount: amount,
                        index: updated_index,
                        unclaimed_rewards: 0,
                        unpool_time: Option::None,
                    }
                );
            true
        }

        fn add_to_delegation_pool(ref self: ContractState, amount: u128) -> u128 {
            0
        }

        fn exit_delegation_pool_intent(ref self: ContractState) -> u128 {
            0
        }

        fn exit_delegation_pool_action(ref self: ContractState) -> u128 {
            0
        }

        fn claim_rewards(ref self: ContractState, pool_member: ContractAddress) -> u128 {
            let mut pool_member_info = self.pool_member_address_to_info.read(pool_member);
            assert_with_err(
                pool_member_info.amount.is_non_zero(), Error::POOL_MEMBER_DOES_NOT_EXIST
            );
            let caller_address = get_caller_address();
            assert_with_err(
                caller_address == pool_member || caller_address == pool_member_info.reward_address,
                Error::POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
            );
            let updated_index = self.receive_index_and_funds_from_staker();
            self.calculate_rewards(ref :pool_member_info, :updated_index);

            let rewards = pool_member_info.unclaimed_rewards;
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer(recipient: pool_member_info.reward_address, amount: rewards.into());

            pool_member_info.unclaimed_rewards = 0;
            self.pool_member_address_to_info.write(pool_member, pool_member_info);
            rewards
        }

        fn switch_delegation_pool(
            ref self: ContractState,
            to_staker_address: ContractAddress,
            to_pool_address: ContractAddress,
            amount: u128
        ) -> u128 {
            0
        }

        fn enter_from_staking_contract(
            ref self: ContractState, amount: u128, index: u64, data: Span<felt252>
        ) -> bool {
            true
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            let pool_member = get_caller_address();
            let mut pool_member_info = self.pool_member_address_to_info.read(pool_member);
            assert_with_err(
                pool_member_info.amount.is_non_zero(), Error::POOL_MEMBER_DOES_NOT_EXIST
            );
            pool_member_info.reward_address = reward_address;
            self.pool_member_address_to_info.write(pool_member, pool_member_info);
            true
        }

        fn state_of(self: @ContractState, pool_member: ContractAddress) -> PoolMemberInfo {
            let pool_member_info = self.get_pool_member(pool_member);
            expect_with_err(pool_member_info, Error::POOL_MEMBER_DOES_NOT_EXIST)
        }
    }

    #[generate_trait]
    pub(crate) impl InternalPoolingFunctions of InternalPoolingFunctionsTrait {
        fn get_pool_member(
            self: @ContractState, pool_member: ContractAddress
        ) -> Option<PoolMemberInfo> {
            let pool_member_info = self.pool_member_address_to_info.read(pool_member);
            // Reward address isn't zero if staker is initialized.
            if pool_member_info.amount.is_zero() {
                Option::None
            } else {
                Option::Some(pool_member_info)
            }
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

        fn assert_staker_is_active(self: @ContractState) {
            if self.final_staker_index.read().is_some() {
                panic_by_err(Error::STAKER_INACTIVE);
            }
        }
    }
}
