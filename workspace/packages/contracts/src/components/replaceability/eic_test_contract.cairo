// A dummy contract used for testing EIC.
#[starknet::contract]
pub(crate) mod EICTestContract {
    use contracts_commons::components::replaceability::interface::IEICInitializable;

    #[storage]
    struct Storage {
        // Arbitrary storage variable from TokenBridge to be modified by the tests.
        upgrade_delay: u64,
    }

    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        // Adds the value in eic_init_data to the storage variable.
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 1, 'EIC_INIT_DATA_LEN_MISMATCH');
            let upgrade_delay = self.upgrade_delay.read();
            self.upgrade_delay.write(upgrade_delay + (*eic_init_data[0]).try_into().unwrap());
        }
    }
}
