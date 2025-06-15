// An External Initializer Contract to upgrade a staking contract.
// This EIC is used to upgrade the staking contract from V1 to V2 (BTC).
#[starknet::contract]
mod StakingEICV1toV2 {
    use core::num::traits::Zero;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use staking::constants::STAKING_V2_PREV_CONTRACT_VERSION;
    use staking::errors::GenericError;
    use staking::types::Version;
    use starknet::ContractAddress;
    use starknet::class_hash::ClassHash;
    use starknet::storage::{Map, Mutable, StorageBase, StoragePathEntry, StoragePointerReadAccess};
    use starkware_utils::components::replaceability::interface::IEICInitializable;
    use starkware_utils::trace::errors::TraceErrors;
    use starkware_utils::trace::trace::{MutableTraceTrait, Trace};

    #[storage]
    struct Storage {
        // --- New fields ---
        /// Map token address to checkpoints tracking total stake changes over time, with each
        /// checkpoint mapping an epoch to the updated stake. Stakers that performed unstake_intent
        /// are not included.
        tokens_total_stake_trace: Map<ContractAddress, Trace>,
        // --- Existing fields ---
        /// Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        // The class hash of the delegation pool contract.
        pool_contract_class_hash: ClassHash,
        /// Deprecated field of the total stake.
        total_stake_trace: Trace,
        /// A dispatcher of the token contract.
        token_dispatcher: IERC20Dispatcher,
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

            // 3. Migrate total_stake_trace.
            // Note: This part assumes that self.total_stake_trace.length >= 3.
            self.migrate_total_stake_trace();
        }
    }

    #[generate_trait]
    impl EICHelper of IEICHelper {
        /// Migrate the deprecated total stake trace to tokens_total_stake_trace.
        /// Precondition: total_stake_trace.length() >= 3.
        fn migrate_total_stake_trace(ref self: ContractState) {
            let deprecated_trace = self.total_stake_trace;
            let len = deprecated_trace.length();
            let n = 3;
            assert!(len >= n, "{}", TraceErrors::INDEX_OUT_OF_BOUNDS);
            let strk_token_address = self.token_dispatcher.read().contract_address;
            let strk_total_stake_trace = self.tokens_total_stake_trace.entry(strk_token_address);
            for i in len - n..len {
                let (key, value) = deprecated_trace.at(i);
                strk_total_stake_trace.insert(:key, :value);
            }
        }
    }
}
