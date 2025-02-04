#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn push(ref self: TContractState, key: u64, value: u128) -> (u128, u128);
    fn latest(self: @TContractState) -> u128;
    fn latest_checkpoint(self: @TContractState) -> (bool, u64, u128);
    fn length(self: @TContractState) -> u64;
    fn upper_lookup(self: @TContractState, key: u64) -> u128;
}

#[starknet::contract]
pub mod MockTrace {
    use contracts_commons::trace::trace::{MutableTraceTrait, Trace, TraceTrait};

    #[storage]
    struct Storage {
        trace: Trace,
    }

    #[abi(embed_v0)]
    impl MockTraceImpl of super::IMockTrace<ContractState> {
        fn push(ref self: ContractState, key: u64, value: u128) -> (u128, u128) {
            self.trace.deref().push(:key, :value)
        }

        fn latest(self: @ContractState) -> u128 {
            self.trace.deref().latest()
        }

        fn latest_checkpoint(self: @ContractState) -> (bool, u64, u128) {
            self.trace.deref().latest_checkpoint()
        }

        fn length(self: @ContractState) -> u64 {
            self.trace.deref().length()
        }

        fn upper_lookup(self: @ContractState, key: u64) -> u128 {
            self.trace.deref().upper_lookup(:key)
        }
    }
}
