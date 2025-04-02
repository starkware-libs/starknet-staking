use staking::pool::pool_member_balance_trace::trace::{PoolMemberBalance, PoolMemberCheckpoint};
use staking::types::{Epoch, VecIndex};

#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn insert(
        ref self: TContractState, key: Epoch, value: PoolMemberBalance,
    ) -> (PoolMemberBalance, PoolMemberBalance);
    fn latest(self: @TContractState) -> (Epoch, PoolMemberBalance);
    fn penultimate(self: @TContractState) -> (Epoch, PoolMemberBalance);
    fn length(self: @TContractState) -> u64;
    fn latest_mutable(ref self: TContractState) -> (Epoch, PoolMemberBalance);
    fn is_non_empty(self: @TContractState) -> bool;
    fn is_non_empty_mutable(ref self: TContractState) -> bool;
    fn length_mutable(ref self: TContractState) -> u64;
    fn at(self: @TContractState, pos: u64) -> PoolMemberCheckpoint;
}

#[starknet::contract]
pub mod MockTrace {
    use staking::pool::pool_member_balance_trace::trace::{
        MutablePoolMemberBalanceTraceTrait, PoolMemberBalanceTrace, PoolMemberBalanceTraceTrait,
    };
    use super::{Epoch, PoolMemberBalance, PoolMemberCheckpoint, VecIndex};

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

        fn latest(self: @ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.latest()
        }

        fn penultimate(self: @ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.penultimate()
        }

        fn length(self: @ContractState) -> u64 {
            self.trace.length()
        }

        fn latest_mutable(ref self: ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.latest()
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
    }
}

