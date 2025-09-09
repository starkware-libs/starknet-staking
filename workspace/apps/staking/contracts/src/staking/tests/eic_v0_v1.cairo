/// An External Initializer Contract to upgrade a staking contract.
/// This EIC was used to upgrade the staking contract from V0 to V1.
/// This eic is now deprecated. Used only for flow tests.
#[cfg(test)]
#[starknet::contract]
mod StakingEICV0toV1 {
    use core::num::traits::Zero;
    use staking::constants::{STARTING_EPOCH, V1_PREV_CONTRACT_VERSION};
    use staking::errors::GenericError;
    use staking::staking::objects::{EpochInfo, EpochInfoTrait};
    use staking::types::{Amount, Version};
    use starknet::class_hash::ClassHash;
    use starknet::storage::Map;
    use starknet::{ContractAddress, get_block_number};
    use starkware_utils::components::replaceability::interface::IEICInitializable;
    use starkware_utils::trace::trace::{MutableTraceTrait, Trace};

    #[storage]
    struct Storage {
        // --- New fields ---
        /// Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        /// Epoch info.
        epoch_info: EpochInfo,
        /// Stores checkpoints tracking total stake changes over time, with each checkpoint mapping
        /// an epoch to the updated stake. Stakers that performed unstake_intent are not included.
        total_stake_trace: Trace,
        /// The contract that staker sends attestation transaction to.
        attestation_contract: ContractAddress,
        // --- Existing fields ---
        /// Deprecated field of the total stake.
        total_stake: Amount,
        /// The class hash of the delegation pool contract.
        pool_contract_class_hash: ClassHash,
        /// Governance admin of the delegation pool contract.
        pool_contract_admin: ContractAddress,
    }

    /// Expected data : [prev_class_hash, epoch_duration, epoch_length, starting_offset,
    /// pool_contract_class_hash, attestation_contract]
    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 7, 'EXPECTED_DATA_LENGTH_7');
            let prev_class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            let epoch_duration: u32 = (*eic_init_data[1]).try_into().unwrap();
            let epoch_length: u32 = (*eic_init_data[2]).try_into().unwrap();
            let starting_offset: u64 = (*eic_init_data[3]).try_into().unwrap();
            let pool_contract_class_hash: ClassHash = (*eic_init_data[4]).try_into().unwrap();
            let attestation_contract: ContractAddress = (*eic_init_data[5]).try_into().unwrap();
            let pool_contract_admin: ContractAddress = (*eic_init_data[6]).try_into().unwrap();

            // 1. Set previous class hash.
            assert!(prev_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.prev_class_hash.write(V1_PREV_CONTRACT_VERSION, prev_class_hash);

            // 2. Set epoch info.
            let epoch_info = EpochInfoTrait::new(
                :epoch_duration,
                :epoch_length,
                starting_block: get_block_number() + starting_offset,
            );
            self.epoch_info.write(epoch_info);

            // 3. Initalize total stake trace.
            let total_stake = self.total_stake.read();
            // If trace is not empty we assume it's already set correctly.
            // in this case, we must not replace it.
            self.total_stake_trace.insert(key: STARTING_EPOCH, value: total_stake);

            // 4. Replace pool contract class hash (if supplied).
            assert!(pool_contract_class_hash.is_non_zero(), "{}", GenericError::ZERO_CLASS_HASH);
            self.pool_contract_class_hash.write(pool_contract_class_hash);

            // 5. Set attestation contract address.
            assert!(attestation_contract.is_non_zero(), "{}", GenericError::ZERO_ADDRESS);
            self.attestation_contract.write(attestation_contract);

            // 6. Set pool contract admin address (SC).
            assert!(pool_contract_admin.is_non_zero(), "{}", GenericError::ZERO_ADDRESS);
            self.pool_contract_admin.write(pool_contract_admin);
        }
    }
}
