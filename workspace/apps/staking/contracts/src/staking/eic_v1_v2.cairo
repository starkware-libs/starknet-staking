// An External Initializer Contract to upgrade a staking contract.
// This EIC is used to upgrade the staking contract from V1 to V2 (BTC).
#[starknet::contract]
mod StakingEICV1toV2 {
    use core::num::traits::Zero;
    use staking::constants::STAKING_V2_PREV_CONTRACT_VERSION;
    use staking::errors::GenericError;
    use staking::types::Version;
    use starknet::class_hash::ClassHash;
    use starknet::storage::Map;
    use starkware_utils::components::replaceability::interface::IEICInitializable;

    #[storage]
    struct Storage {
        // --- New fields ---
        // --- Existing fields ---
        // Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        // The class hash of the delegation pool contract.
        pool_contract_class_hash: ClassHash,
    }

    /// Expected data : [prev_class_hash]
    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 2, 'EXPECTED_DATA_LENGTH_2');
            // TODO: Can prev_class_hash be hard coded?
            let prev_class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            let pool_contract_class_hash: ClassHash = (*eic_init_data[1]).try_into().unwrap();

            // 1. Set previous class hash.
            assert!(prev_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.prev_class_hash.write(STAKING_V2_PREV_CONTRACT_VERSION, prev_class_hash);

            // 2. Replace pool contract class hash.
            assert!(pool_contract_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.pool_contract_class_hash.write(pool_contract_class_hash);
        }
    }
}
