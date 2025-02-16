// An External Initializer Contract to upgrade a pool contract.
#[starknet::contract]
mod PoolEIC {
    use contracts_commons::components::replaceability::interface::IEICInitializable;
    use staking::types::{Index, Version};
    use starknet::class_hash::ClassHash;
    use starknet::storage::Map;

    #[storage]
    struct Storage {
        // Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        // Stores the final global index of staking contract, used for updating pending rewards
        // during PoolMemberInfo migration.
        final_staker_index: Option<Index>,
    }

    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 2, 'EXPECTED_DATA_LENGTH_2');
            let class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            self.prev_class_hash.write(0, class_hash);

            let final_index: Index = (*eic_init_data[1]).try_into().unwrap();
            self.final_staker_index.write(Option::Some(final_index));
        }
    }
}
