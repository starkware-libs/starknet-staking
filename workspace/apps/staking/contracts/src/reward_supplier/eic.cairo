/// An External Initializer Contract to upgrade a reward supplier contract.
/// This EIC is used to upgrade the reward supplier contract from V2 (BTC) to V3.
#[starknet::contract]
mod RewardSupplierEIC {
    use staking::reward_supplier::errors::Error;
    use staking::reward_supplier::interface::BlockTimeConfig;
    use starknet::storage::StoragePointerWriteAccess;
    use starkware_utils::components::replaceability::interface::IEICInitializable;

    #[storage]
    struct Storage {
        // --- New fields ---
        /// Average block time in units of 1 / BLOCK_TIME_SCALE seconds.
        avg_block_time: u64,
        /// Configuration for block time calculation.
        block_time_config: BlockTimeConfig,
    }

    /// Expected data : [avg_block_duration, min_block_time, max_block_time, weighted_avg_factor]
    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 4, 'EXPECTED_DATA_LENGTH_4');
            let avg_block_duration: u64 = (*eic_init_data[0]).try_into().unwrap();
            let min_block_time: u64 = (*eic_init_data[1]).try_into().unwrap();
            let max_block_time: u64 = (*eic_init_data[2]).try_into().unwrap();
            let weighted_avg_factor: u8 = (*eic_init_data[3]).try_into().unwrap();

            // Validate values.
            assert!(
                avg_block_duration >= min_block_time && avg_block_duration <= max_block_time,
                "{}",
                Error::INVALID_AVG_BLOCK_DURATION,
            );
            assert!(min_block_time > 0, "{}", Error::INVALID_MIN_MAX_BLOCK_TIME);
            assert!(max_block_time >= min_block_time, "{}", Error::INVALID_MIN_MAX_BLOCK_TIME);
            assert!(
                weighted_avg_factor > 0 && weighted_avg_factor <= 100,
                "{}",
                Error::INVALID_WEIGHTED_AVG_FACTOR,
            );

            // Set values.
            self.avg_block_time.write(avg_block_duration);
            self
                .block_time_config
                .write(BlockTimeConfig { min_block_time, max_block_time, weighted_avg_factor });
        }
    }
}
