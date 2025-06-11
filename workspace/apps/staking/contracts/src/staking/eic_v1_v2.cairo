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
    }

    /// Expected data : [prev_class_hash]
    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 1, 'EXPECTED_DATA_LENGTH_1');
            // TODO: Can prev_class_hash be hard coded?
            let prev_class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();

            // 1. Set previous class hash.
            assert!(prev_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.prev_class_hash.write(STAKING_V2_PREV_CONTRACT_VERSION, prev_class_hash);
        }
    }
}
