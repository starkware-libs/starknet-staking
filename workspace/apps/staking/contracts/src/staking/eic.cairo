/// An External Initializer Contract to upgrade a staking contract.
/// This EIC is used to upgrade the staking contract from V2 (BTC) to V3.
#[starknet::contract]
mod StakingEIC {
    use core::num::traits::Zero;
    use staking::errors::GenericError;
    use staking::staking::staking::Staking::V3_PREV_CONTRACT_VERSION;
    use staking::types::Version;
    use starknet::class_hash::ClassHash;
    use starknet::get_contract_address;
    use starknet::storage::{
        Map, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::syscalls::get_class_hash_at_syscall;
    use starkware_utils::components::replaceability::interface::IEICInitializable;

    #[storage]
    struct Storage {
        // --- Existing fields ---
        /// Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        /// The class hash of the delegation pool contract.
        pool_contract_class_hash: ClassHash,
        /// Storage of the `pause` flag state.
        is_paused: bool,
    }

    /// Expected data : [pool_contract_class_hash]
    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(self.is_paused.read(), 'CONTRACT_IS_NOT_PAUSED');
            assert(eic_init_data.len() == 1, 'EXPECTED_DATA_LENGTH_1');
            let pool_contract_class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();

            // 1. Set previous class hash.
            let prev_class_hash: ClassHash = get_class_hash_at_syscall(
                contract_address: get_contract_address(),
            )
                .expect('FAILED_TO_GET_CLASS_HASH');
            assert!(prev_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.prev_class_hash.write(V3_PREV_CONTRACT_VERSION, prev_class_hash);

            // 2. Replace pool contract class hash.
            assert!(pool_contract_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.pool_contract_class_hash.write(pool_contract_class_hash);
        }
    }
}
