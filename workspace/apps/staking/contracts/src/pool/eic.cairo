// An External Initializer Contract to upgrade a pool contract.
#[starknet::contract]
mod PoolEIC {
    use staking::staking::interface::{IStakingPoolDispatcher, IStakingPoolDispatcherTrait};
    use staking::types::{Index, Version};
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;
    use starknet::storage::Map;
    use starkware_utils::components::replaceability::interface::IEICInitializable;
    use starkware_utils::trace::trace::{MutableTraceTrait, Trace};


    #[storage]
    struct Storage {
        // Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        // Stores the final global index of staking contract, used for updating pending rewards
        // during PoolMemberInfo migration.
        final_staker_index: Option<Index>,
        // Dispatcher for the staking contract's pool functions, used for the final index and the
        // StakerInfo migration.
        staking_pool_dispatcher: IStakingPoolDispatcher,
        // The staker address, used for the final index and the StakerInfo migration.
        staker_address: ContractAddress,
        // Maintains a cumulative sum of pool_rewards/pool_balance per epoch for member rewards
        // calculation.
        rewards_info: Trace,
    }

    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 1, 'EXPECTED_DATA_LENGTH_1');
            let class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            self.prev_class_hash.write(0, class_hash);

            // Get the final index.
            // Note: The StakerInfo migration happens in this call if haven't happen before.
            let final_index = self
                .staking_pool_dispatcher
                .read()
                .pool_migration(staker_address: self.staker_address.read());
            self.final_staker_index.write(Option::Some(final_index));

            // Initialize the rewards info trace.
            self.rewards_info.deref().insert(key: 0, value: 0);
        }
    }
}
