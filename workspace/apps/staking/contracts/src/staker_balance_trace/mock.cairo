use staking::staker_balance_trace::trace::StakerBalance;
use staking::types::Epoch;

#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn insert(ref self: TContractState, key: Epoch, value: StakerBalance);
    fn latest(self: @TContractState) -> (Epoch, StakerBalance);
    fn length(self: @TContractState) -> u64;
    fn upper_lookup(self: @TContractState, key: Epoch) -> StakerBalance;
    fn latest_mutable(ref self: TContractState) -> StakerBalance;
    fn is_initialized(self: @TContractState) -> bool;
}

#[starknet::contract]
pub mod MockTrace {
    use staking::staker_balance_trace::trace::{
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
            self.trace.deref().insert(:key, :value);
        }

        fn latest(self: @ContractState) -> (Epoch, StakerBalance) {
            self.trace.deref().latest()
        }

        fn length(self: @ContractState) -> u64 {
            self.trace.deref().length()
        }

        fn upper_lookup(self: @ContractState, key: Epoch) -> StakerBalance {
            self.trace.deref().upper_lookup(:key)
        }

        fn latest_mutable(ref self: ContractState) -> StakerBalance {
            self.trace.deref().latest()
        }

        fn is_initialized(self: @ContractState) -> bool {
            self.trace.deref().is_initialized()
        }
    }
}

