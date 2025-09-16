/// An External Initializer Contract to upgrade a staking contract.
/// This EIC is used to upgrade the staking contract from V1 to V2 (BTC).
#[starknet::contract]
mod StakingEICV1toV2 {
    use core::cmp::min;
    use core::num::traits::Zero;
    use staking::constants::STRK_TOKEN_ADDRESS;
    use staking::errors::GenericError;
    use staking::staking::staking::Staking::{MAX_MIGRATION_TRACE_ENTRIES, V2_PREV_CONTRACT_VERSION};
    use staking::types::Version;
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;
    use starknet::storage::{
        Map, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starkware_utils::components::replaceability::interface::IEICInitializable;
    use starkware_utils::trace::trace::{MutableTraceTrait, Trace};

    #[storage]
    struct Storage {
        // --- New fields ---
        /// Map token address to checkpoints tracking total stake changes over time, with each
        /// checkpoint mapping an epoch to the updated stake. Stakers that performed unstake_intent
        /// are not included.
        tokens_total_stake_trace: Map<ContractAddress, Trace>,
        /// Map token address to its decimals.
        token_decimals: Map<ContractAddress, u8>,
        // --- Existing fields ---
        /// Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        /// The class hash of the delegation pool contract.
        pool_contract_class_hash: ClassHash,
        /// Deprecated field of the total stake.
        total_stake_trace: Trace,
        /// Storage of the `pause` flag state.
        is_paused: bool,
    }

    /// Expected data : [prev_class_hash, pool_contract_class_hash]
    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(self.is_paused.read(), 'CONTRACT_IS_NOT_PAUSED');
            assert(eic_init_data.len() == 2, 'EXPECTED_DATA_LENGTH_2');
            let prev_class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            let pool_contract_class_hash: ClassHash = (*eic_init_data[1]).try_into().unwrap();

            // 1. Set previous class hash.
            assert!(prev_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.prev_class_hash.write(V2_PREV_CONTRACT_VERSION, prev_class_hash);

            // 2. Replace pool contract class hash.
            assert!(pool_contract_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.pool_contract_class_hash.write(pool_contract_class_hash);

            // 3. Set STRK token decimals.
            self.token_decimals.write(STRK_TOKEN_ADDRESS, 18);

            // 4. Migrate total_stake_trace.
            self.migrate_total_stake_trace();
        }
    }

    #[generate_trait]
    impl EICHelper of IEICHelper {
        /// Migrate the deprecated total stake trace to tokens_total_stake_trace.
        /// Migrate up to MAX_MIGRATION_TRACE_ENTRIES last checkpoints.
        fn migrate_total_stake_trace(ref self: ContractState) {
            let deprecated_trace = self.total_stake_trace;
            assert!(!deprecated_trace.is_empty(), "EMPTY_TRACE");
            let len = deprecated_trace.length();
            let entries_to_migrate = min(len, MAX_MIGRATION_TRACE_ENTRIES);
            let strk_total_stake_trace = self.tokens_total_stake_trace.entry(STRK_TOKEN_ADDRESS);
            for i in (len - entries_to_migrate)..len {
                let (key, value) = deprecated_trace.at(i);
                strk_total_stake_trace.insert(:key, :value);
            }
        }
    }
}
