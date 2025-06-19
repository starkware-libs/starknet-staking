// An External Initializer Contract to upgrade a pool contract.
#[cfg(test)]
#[starknet::contract]
mod PoolEIC {
    use core::num::traits::Zero;
    use staking::constants::V1_PREV_CONTRACT_VERSION;
    use staking::errors::GenericError;
    use staking::staking::interface_v1::{
        IStakingPoolV1ForTestsDispatcher, IStakingPoolV1ForTestsDispatcherTrait,
    };
    use staking::types::{Index, Version};
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;
    use starknet::storage::Map;
    use starkware_utils::components::replaceability::interface::IEICInitializable;
    use starkware_utils::trace::trace::{MutableTraceTrait, Trace};

    #[storage]
    struct Storage {
        // --- New fields ---
        // Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        // Maintains a cumulative sum of pool_rewards/pool_balance per epoch for member rewards
        // calculation.
        cumulative_rewards_trace: Trace,
        // Indicates whether the staker has been removed from the staking contract.
        staker_removed: bool,
        // --- Existing fields ---
        // Stores the final global index of staking contract, used for updating pending rewards
        // during PoolMemberInfo migration.
        final_staker_index: Option<Index>,
        // Dispatcher for the staking contract's pool functions, used for the final index and the
        // StakerInfo migration.
        staking_pool_dispatcher: IStakingPoolV1ForTestsDispatcher,
        // The staker address, used for the final index and the StakerInfo migration.
        staker_address: ContractAddress,
    }

    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 1, 'EXPECTED_DATA_LENGTH_1');
            let class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            assert!(class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.prev_class_hash.write(V1_PREV_CONTRACT_VERSION, class_hash);

            // Get the final index.
            // Note: The StakerInfo migration happens in this call if haven't happen before.
            let final_index = self
                .staking_pool_dispatcher
                .read()
                .pool_migration(staker_address: self.staker_address.read());
            assert!(self.final_staker_index.read().is_none(), "INDEX_ALREADY_SET");
            assert!(!self.staker_removed.read(), "STAKER_ALREADY_REMOVED");
            self.final_staker_index.write(Option::Some(final_index));

            // Initialize the cumulative rewards trace.
            self.cumulative_rewards_trace.insert(key: Zero::zero(), value: Zero::zero());
        }
    }
}
