use staking::pool::pool_member_balance_trace::trace::{PoolMemberBalance, PoolMemberCheckpoint};
use staking::types::Epoch;

#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn insert(
        ref self: TContractState, key: Epoch, value: PoolMemberBalance,
    ) -> (PoolMemberBalance, PoolMemberBalance);
    fn last(self: @TContractState) -> (Epoch, PoolMemberBalance);
    fn second_last(self: @TContractState) -> (Epoch, PoolMemberBalance);
    fn length(self: @TContractState) -> u64;
    fn last_mutable(ref self: TContractState) -> (Epoch, PoolMemberBalance);
    fn is_non_empty(self: @TContractState) -> bool;
    fn is_non_empty_mutable(ref self: TContractState) -> bool;
    fn length_mutable(ref self: TContractState) -> u64;
    fn at(self: @TContractState, pos: u64) -> PoolMemberCheckpoint;
    fn third_last(self: @TContractState) -> (Epoch, PoolMemberBalance);
}

#[starknet::contract]
pub mod MockTrace {
    use staking::pool::pool_member_balance_trace::trace::{
        MutablePoolMemberBalanceTraceTrait, PoolMemberBalanceTrace, PoolMemberBalanceTraceTrait,
    };
    use super::{Epoch, PoolMemberBalance, PoolMemberCheckpoint};

    #[storage]
    struct Storage {
        trace: PoolMemberBalanceTrace,
    }

    #[abi(embed_v0)]
    impl MockTraceImpl of super::IMockTrace<ContractState> {
        fn insert(
            ref self: ContractState, key: Epoch, value: PoolMemberBalance,
        ) -> (PoolMemberBalance, PoolMemberBalance) {
            self.trace.insert(:key, :value)
        }

        fn last(self: @ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.last()
        }

        fn second_last(self: @ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.second_last()
        }

        fn length(self: @ContractState) -> u64 {
            self.trace.length()
        }

        fn last_mutable(ref self: ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.last()
        }

        fn length_mutable(ref self: ContractState) -> u64 {
            self.trace.length()
        }

        fn is_non_empty(self: @ContractState) -> bool {
            self.trace.is_non_empty()
        }

        fn is_non_empty_mutable(ref self: ContractState) -> bool {
            self.trace.is_non_empty()
        }

        fn at(self: @ContractState, pos: u64) -> PoolMemberCheckpoint {
            self.trace.at(:pos)
        }

        fn third_last(self: @ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.third_last()
        }
    }
}

