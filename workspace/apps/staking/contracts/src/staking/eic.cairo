// An External Initializer Contract to upgrade a staking contract.
#[starknet::contract]
mod StakingEIC {
    use contracts_commons::components::replaceability::interface::IEICInitializable;
    use contracts_commons::trace::trace::{MutableTraceTrait, Trace};
    use core::num::traits::Zero;
    use staking::staking::objects::{EpochInfo, EpochInfoTrait};
    use staking::types::{Amount, Version};
    use starknet::class_hash::ClassHash;
    use starknet::get_block_number;
    use starknet::storage::Map;

    #[storage]
    struct Storage {
        // Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        // Epoch info.
        epoch_info: EpochInfo,
        // Stores checkpoints tracking total stake changes over time, with each checkpoint mapping
        // an epoch to the updated stake.
        total_stake_trace: Trace,
        // The class hash of the delegation pool contract.
        pool_contract_class_hash: ClassHash,
    }

    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 5, 'EXPECTED_DATA_LENGTH_5');
            let class_hash: ClassHash = (*eic_init_data[0]).try_into().unwrap();
            self.prev_class_hash.write(0, class_hash);

            let block_duration: u16 = (*eic_init_data[1]).try_into().unwrap();
            let length: u16 = (*eic_init_data[2]).try_into().unwrap();
            let epoch_info = EpochInfoTrait::new(
                :block_duration, :length, starting_block: get_block_number(),
            );
            self.epoch_info.write(epoch_info);

            let total_stake: Amount = (*eic_init_data[3]).try_into().unwrap();
            self.total_stake_trace.deref().insert(key: Zero::zero(), value: total_stake);

            let pool_contract_class_hash: ClassHash = (*eic_init_data[4]).try_into().unwrap();
            self.pool_contract_class_hash.write(pool_contract_class_hash);
        }
    }
}
