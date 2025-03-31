// An External Initializer Contract to upgrade a staking contract.
#[starknet::contract]
mod StakingEIC {
    use core::num::traits::Zero;
    use staking::constants::FIRST_VALID_EPOCH;
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
        // Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        // Epoch info.
        epoch_info: EpochInfo,
        // Stores checkpoints tracking total stake changes over time, with each checkpoint mapping
        // an epoch to the updated stake. Stakers that performed unstake_intent are not included.
        total_stake_trace: Trace,
        // The contract that staker sends attestation transaction to.
        attestation_contract: ContractAddress,
        // --- Existing fields ---
        // Deprecated field of the total stake.
        total_stake: Amount,
        // The class hash of the delegation pool contract.
        pool_contract_class_hash: ClassHash,
    }

    // TODO: Test all if's.
    // Expected data : [prev_class_hash, block_duration, epoch_length, starting_offset,
    // pool_contract_class_hash, attestation_contract]
    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 6, 'EXPECTED_DATA_LENGTH_6');
            // TODO: Can prev_class_hash be hard coded?
            let prev_class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            let epoch_duration: u32 = (*eic_init_data[1]).try_into().unwrap();
            let epoch_length: u32 = (*eic_init_data[2]).try_into().unwrap();
            let starting_offset: u64 = (*eic_init_data[3]).try_into().unwrap();
            let pool_contract_class_hash: ClassHash = (*eic_init_data[4]).try_into().unwrap();
            let attestation_contract: ContractAddress = (*eic_init_data[5]).try_into().unwrap();

            // 1. Set previous class hash.
            // If prev_class_hash is not empty we assume it's already set correctly.
            // in this case, we must not replace it.
            // TODO: Check that prev_class_hash is empty.
            self.prev_class_hash.write(0, prev_class_hash);

            // TODO: What can i check in epoch info? Impl zero for the struct?
            // 2. Initialize the epoch info.
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
            // TODO: Check that trace is empty, we can't check it now, because eic test deploy
            // the new contract and trace is initialized in new constructor.
            self.total_stake_trace.insert(key: FIRST_VALID_EPOCH, value: total_stake);

            // 4. Replace pool contract class hash (if supplied).
            if pool_contract_class_hash.is_non_zero() {
                self.pool_contract_class_hash.write(pool_contract_class_hash);
            }

            // 5. Set attestation contract address.
            let current_attestation_contract = self.attestation_contract.read();
            // If attestation_contract is not empty we assume it's already set correctly.
            // in this case, we must not replace it.
            if current_attestation_contract.is_zero() {
                self.attestation_contract.write(attestation_contract);
            }
        }
    }
}
