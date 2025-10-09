/// An External Initializer Contract to upgrade a reward supplier contract.
/// This EIC is used to upgrade the reward supplier contract from V2 (BTC) to V3.
#[starknet::contract]
mod RewardSupplierEIC {
    use staking::reward_supplier::errors::Error;
    use staking::reward_supplier::interface::BlockDurationConfig;
    use starknet::storage::StoragePointerWriteAccess;
    use starkware_utils::components::replaceability::interface::IEICInitializable;

    #[storage]
    struct Storage {
        // --- New fields ---
        /// Average block duration in units of 1 / BLOCK_DURATION_SCALE seconds.
        avg_block_duration: u64,
        /// Configuration for block duration calculation.
        block_duration_config: BlockDurationConfig,
    }

    /// Expected data : [avg_block_duration, min_block_duration, max_block_duration]
    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 3, 'EXPECTED_DATA_LENGTH_3');
            let avg_block_duration: u64 = (*eic_init_data[0]).try_into().unwrap();
            let min_block_duration: u64 = (*eic_init_data[1]).try_into().unwrap();
            let max_block_duration: u64 = (*eic_init_data[2]).try_into().unwrap();

            // Validate values.
            assert!(
                min_block_duration <= avg_block_duration
                    && avg_block_duration <= max_block_duration,
                "{}",
                Error::INVALID_AVG_BLOCK_DURATION,
            );
            assert!(min_block_duration > 0, "{}", Error::INVALID_MIN_MAX_BLOCK_DURATION);
            assert!(
                min_block_duration <= max_block_duration,
                "{}",
                Error::INVALID_MIN_MAX_BLOCK_DURATION,
            );

            // Set values.
            self.avg_block_duration.write(avg_block_duration);
            self
                .block_duration_config
                .write(BlockDurationConfig { min_block_duration, max_block_duration });
        }
    }
}
