#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn insert(ref self: TContractState, key: u64, value: u128);
    fn latest(self: @TContractState) -> (u64, u128);
    fn length(self: @TContractState) -> u64;
    fn upper_lookup(self: @TContractState, key: u64) -> u128;
    fn latest_mutable(ref self: TContractState) -> u128;
    fn length_mutable(ref self: TContractState) -> u64;
    fn is_empty(ref self: TContractState) -> bool;
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
        fn insert(ref self: ContractState, key: u64, value: u128) {
            self.trace.deref().insert(:key, :value)
        }

        fn latest(self: @ContractState) -> (u64, u128) {
            self.trace.deref().latest()
        }

        fn length(self: @ContractState) -> u64 {
            self.trace.deref().length()
        }

        fn upper_lookup(self: @ContractState, key: u64) -> u128 {
            self.trace.deref().upper_lookup(:key)
        }

        fn latest_mutable(ref self: ContractState) -> u128 {
            self.trace.deref().latest()
        }

        fn length_mutable(ref self: ContractState) -> u64 {
            self.trace.deref().length()
        }

        fn is_empty(ref self: ContractState) -> bool {
            self.trace.deref().is_empty()
        }
    }
}
