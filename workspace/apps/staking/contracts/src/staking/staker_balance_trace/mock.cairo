use staking::staking::staker_balance_trace::trace::StakerBalance;
use staking::types::Epoch;

#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn insert(ref self: TContractState, key: Epoch, value: StakerBalance);
    fn latest(self: @TContractState) -> (Epoch, StakerBalance);
    fn penultimate(self: @TContractState) -> (Epoch, StakerBalance);
    fn length(self: @TContractState) -> u64;
    fn latest_mutable(ref self: TContractState) -> (Epoch, StakerBalance);
    fn is_non_empty(self: @TContractState) -> bool;
    fn is_non_empty_mutable(ref self: TContractState) -> bool;
    fn is_empty(self: @TContractState) -> bool;
    fn is_empty_mutable(ref self: TContractState) -> bool;
    fn length_mutable(ref self: TContractState) -> u64;
    fn at_mutable(ref self: TContractState, index: u64) -> (Epoch, StakerBalance);
}

#[starknet::contract]
pub mod MockTrace {
    use staking::staking::staker_balance_trace::trace::{
        MutableStakerBalanceTraceTrait, StakerBalanceTrace, StakerBalanceTraceTrait,
    };
    use super::{Epoch, StakerBalance};

    #[storage]
    struct Storage {
        trace: StakerBalanceTrace,
    }

    #[abi(embed_v0)]
    impl MockTraceImpl of super::IMockTrace<ContractState> {
        fn insert(ref self: ContractState, key: Epoch, value: StakerBalance) {
            self.trace.insert(:key, :value);
        }

        fn latest(self: @ContractState) -> (Epoch, StakerBalance) {
            self.trace.latest()
        }

        fn penultimate(self: @ContractState) -> (Epoch, StakerBalance) {
            self.trace.penultimate()
        }

        fn length(self: @ContractState) -> u64 {
            self.trace.length()
        }

        fn latest_mutable(ref self: ContractState) -> (Epoch, StakerBalance) {
            self.trace.latest()
        }

        fn is_non_empty(self: @ContractState) -> bool {
            self.trace.is_non_empty()
        }

        fn is_non_empty_mutable(ref self: ContractState) -> bool {
            self.trace.is_non_empty()
        }

        fn is_empty(self: @ContractState) -> bool {
            self.trace.is_empty()
        }

        fn is_empty_mutable(ref self: ContractState) -> bool {
            self.trace.is_empty()
        }

        fn length_mutable(ref self: ContractState) -> u64 {
            self.trace.length()
        }

        fn at_mutable(ref self: ContractState, index: u64) -> (Epoch, StakerBalance) {
            self.trace.at(index)
        }
    }
}

