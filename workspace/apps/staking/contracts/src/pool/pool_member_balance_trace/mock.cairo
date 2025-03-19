use staking::pool::pool_member_balance_trace::trace::{PoolMemberBalance, PoolMemberCheckpoint};
use staking::types::{Epoch, VecIndex};

#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn insert(
        ref self: TContractState, key: Epoch, value: PoolMemberBalance,
    ) -> (PoolMemberBalance, PoolMemberBalance);
    fn latest(self: @TContractState) -> (Epoch, PoolMemberBalance);
    fn length(self: @TContractState) -> u64;
    fn latest_mutable(ref self: TContractState) -> (Epoch, PoolMemberBalance);
    fn length_mutable(ref self: TContractState) -> u64;
    fn is_initialized(self: @TContractState) -> bool;
    fn is_initialized_mutable(ref self: TContractState) -> bool;
    fn at(self: @TContractState, pos: u64) -> PoolMemberCheckpoint;
    fn insert_before_latest(ref self: TContractState, key: Epoch, rewards_info_idx: VecIndex);
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
            self.trace.deref().insert(:key, :value)
        }

        fn latest(self: @ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.deref().latest()
        }

        fn length(self: @ContractState) -> u64 {
            self.trace.deref().length()
        }

        fn latest_mutable(ref self: ContractState) -> (Epoch, PoolMemberBalance) {
            self.trace.deref().latest()
        }

        fn length_mutable(ref self: ContractState) -> u64 {
            self.trace.deref().length()
        }

        fn is_initialized(self: @ContractState) -> bool {
            self.trace.deref().is_initialized()
        }

        fn is_initialized_mutable(ref self: ContractState) -> bool {
            self.trace.deref().is_initialized()
        }

        fn at(self: @ContractState, pos: u64) -> PoolMemberCheckpoint {
            self.trace.deref().at(:pos)
        }

        fn insert_before_latest(ref self: ContractState, key: Epoch, rewards_info_idx: VecIndex) {
            self.trace.deref().insert_before_latest(:key, :rewards_info_idx)
        }
    }
}

