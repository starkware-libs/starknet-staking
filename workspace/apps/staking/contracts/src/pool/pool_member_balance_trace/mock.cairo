use staking::pool::pool_member_balance_trace::trace::PoolMemberBalance;
use staking::types::Epoch;

#[starknet::interface]
pub trait IMockTrace<TContractState> {
    fn insert(
        ref self: TContractState, key: Epoch, value: PoolMemberBalance,
    ) -> (PoolMemberBalance, PoolMemberBalance);
    fn latest(self: @TContractState) -> (Epoch, PoolMemberBalance);
    fn length(self: @TContractState) -> u64;
    fn upper_lookup(self: @TContractState, key: Epoch) -> PoolMemberBalance;
    fn latest_mutable(ref self: TContractState) -> PoolMemberBalance;
}

#[starknet::contract]
pub mod MockTrace {
    use staking::pool::pool_member_balance_trace::trace::{
        MutablePoolMemberBalanceTraceTrait, PoolMemberBalanceTrace, PoolMemberBalanceTraceTrait,
    };
    use super::{Epoch, PoolMemberBalance};

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

        fn upper_lookup(self: @ContractState, key: Epoch) -> PoolMemberBalance {
            self.trace.deref().upper_lookup(:key)
        }

        fn latest_mutable(ref self: ContractState) -> PoolMemberBalance {
            self.trace.deref().latest()
        }
    }
}

