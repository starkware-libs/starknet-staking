#[starknet::contract]
pub mod Pooling {
    use contracts::BASE_VALUE;
    use core::option::OptionTrait;
    use starknet::ContractAddress;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use contracts::pooling::{IPooling, PoolMemberInfo};
    use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use contracts::errors::{Error, panic_by_err};
    use contracts::utils::{u128_mul_wide_and_div_unsafe};


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
        final_staker_index: Option<u128>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, staker_address: ContractAddress) {
        self.staker_address.write(staker_address);
    }

    #[abi(embed_v0)]
    impl PoolingImpl of IPooling<ContractState> {
        fn pool(ref self: ContractState, amount: u128, reward_address: ContractAddress) -> bool {
            true
        }
        fn increase_pool(ref self: ContractState, amount: u128) -> u128 {
            0
        }
        fn unpool_intent(ref self: ContractState) -> u128 {
            0
        }
        fn unpool_action(ref self: ContractState) -> u128 {
            0
        }
        fn claim_rewards(ref self: ContractState, pool_member_address: ContractAddress) -> u128 {
            0
        }
    }

    #[generate_trait]
    impl InternalPoolingFunctions of InternalPoolingFunctionsTrait {
        /// Calculates the rewards for a pool member
        /// 
        /// The caller for this function should validate that the staker exists in the storage.
        /// 
        /// rewards formula:
        /// $$ rewards = (staker\_index-pooler\_index) * pooler\_amount $$
        /// 
        // TODO(Ishay, 14/07/2024): add test for calculate_rewards function
        fn calculate_rewards(
            ref self: ContractState,
            pool_member_address: ContractAddress,
            ref pool_member_info: PoolMemberInfo,
            updated_index: u64
        ) -> () {
            let interest: u64 = updated_index - pool_member_info.index;
            //todo: see if we can do without the special mul
            pool_member_info
                .unclaimed_rewards +=
                    u128_mul_wide_and_div_unsafe(
                        pool_member_info.amount,
                        interest.into(),
                        BASE_VALUE.into(),
                        Error::REWARDS_ISNT_U128
                    );
            pool_member_info.index = updated_index;
            self.pool_member_address_to_info.write(pool_member_address, pool_member_info);
        }
    }
}
