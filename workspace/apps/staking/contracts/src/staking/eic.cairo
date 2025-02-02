// An External Initializer Contract to upgrade a staking contract.
#[starknet::contract]
mod StakingEIC {
    use contracts_commons::components::replaceability::interface::IEICInitializable;
    use starknet::class_hash::ClassHash;

    #[storage]
    struct Storage {
        // Class hash of the previous version of the contract.
        prev_class_hash: ClassHash,
    }

    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 1, 'EXPECTED_DATA_LENGTH_1');
            let class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            self.prev_class_hash.write(class_hash);
        }
    }
}
