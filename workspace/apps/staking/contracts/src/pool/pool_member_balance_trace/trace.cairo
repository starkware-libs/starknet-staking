use core::num::traits::Zero;
use staking::types::{Amount, Epoch, VecIndex};
use starknet::storage::{
    Mutable, MutableVecTrait, StoragePath, StoragePathMutableConversion, StoragePointerReadAccess,
    StoragePointerWriteAccess, Vec, VecTrait,
};
use starkware_utils::trace::errors::TraceErrors;

/// `Trace` struct, for checkpointing values as they change at different points in
/// time, and later looking up past values by block timestamp.
#[starknet::storage_node]
pub struct PoolMemberBalanceTrace {
    checkpoints: Vec<PoolMemberBalanceCheckpoint>,
}

#[derive(Copy, Drop, Serde, starknet::Store, Debug, PartialEq)]
pub(crate) struct PoolMemberBalance {
    balance: Amount,
    /// Index of the first non-existent entry in the cumulative rewards trace at the time of the
    /// balance change.
    /// Used in `calculate_rewards`.
    ///
    /// Points to an entry in the rewards_info trace that is either:
    /// 1. The last entry whose epoch is < the epoch of this checkpoint
    /// 2. The first entry whose epoch is >= the epoch of this checkpoint
    cumulative_rewards_trace_idx: VecIndex,
}

pub(crate) impl PoolMemberBalanceZero of core::num::traits::Zero<PoolMemberBalance> {
    fn zero() -> PoolMemberBalance {
        PoolMemberBalance { balance: Zero::zero(), cumulative_rewards_trace_idx: Zero::zero() }
    }

    fn is_zero(self: @PoolMemberBalance) -> bool {
        *self == Self::zero()
    }

    fn is_non_zero(self: @PoolMemberBalance) -> bool {
        !self.is_zero()
    }
}

#[generate_trait]
pub(crate) impl PoolMemberBalanceImpl of PoolMemberBalanceTrait {
    fn new(balance: Amount, cumulative_rewards_trace_idx: VecIndex) -> PoolMemberBalance {
        PoolMemberBalance { balance, cumulative_rewards_trace_idx }
    }

    fn balance(self: @PoolMemberBalance) -> Amount {
        *self.balance
    }

    fn cumulative_rewards_trace_idx(self: @PoolMemberBalance) -> VecIndex {
        *self.cumulative_rewards_trace_idx
    }
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct PoolMemberBalanceCheckpoint {
    key: Epoch,
    value: PoolMemberBalance,
}

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub(crate) struct PoolMemberCheckpoint {
    epoch: Epoch,
    balance: Amount,
    cumulative_rewards_trace_idx: VecIndex,
}

#[generate_trait]
pub(crate) impl PoolMemberCheckpointImpl of PoolMemberCheckpointTrait {
    fn new(
        epoch: Epoch, balance: Amount, cumulative_rewards_trace_idx: VecIndex,
    ) -> PoolMemberCheckpoint {
        PoolMemberCheckpoint { epoch, balance, cumulative_rewards_trace_idx }
    }

    fn epoch(self: @PoolMemberCheckpoint) -> Epoch {
        *self.epoch
    }

    fn balance(self: @PoolMemberCheckpoint) -> Amount {
        *self.balance
    }

    fn cumulative_rewards_trace_idx(self: @PoolMemberCheckpoint) -> VecIndex {
        *self.cumulative_rewards_trace_idx
    }
}

#[generate_trait]
pub impl PoolMemberBalanceTraceImpl of PoolMemberBalanceTraceTrait {
    /// Retrieves the most recent checkpoint from the trace structure.
    ///
    /// # Returns
    /// A tuple containing:
    /// - `Epoch`: Timestamp/key of the latest checkpoint
    /// - `PoolMemberBalance`: Value stored in the latest checkpoint
    ///
    /// # Panics
    /// If the trace structure is empty (no checkpoints exist)
    ///
    /// # Note
    /// This will return the last inserted checkpoint that maintains the structure's
    /// invariant of non-decreasing keys.
    fn latest(self: StoragePath<PoolMemberBalanceTrace>) -> (Epoch, PoolMemberBalance) {
        self._nth_back(0)
    }

    /// Retrieves the penultimate checkpoint from the trace structure.
    /// Penultimate checkpoint is the second last checkpoint in the trace.
    fn penultimate(self: StoragePath<PoolMemberBalanceTrace>) -> (Epoch, PoolMemberBalance) {
        self._nth_back(1)
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<PoolMemberBalanceTrace>) -> u64 {
        self.checkpoints.len()
    }

    /// Returns whether the trace is non empty.
    fn is_non_empty(self: StoragePath<PoolMemberBalanceTrace>) -> bool {
        self.checkpoints.len().is_non_zero()
    }

    /// Returns the checkpoint at the given position.
    ///
    /// # Panics
    /// If the position is out of bounds.
    fn at(self: StoragePath<PoolMemberBalanceTrace>, pos: VecIndex) -> PoolMemberCheckpoint {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(pos < len, "{}", TraceErrors::INDEX_OUT_OF_BOUNDS);
        let checkpoint = checkpoints[pos].read();
        PoolMemberCheckpointTrait::new(
            epoch: checkpoint.key,
            balance: checkpoint.value.balance,
            cumulative_rewards_trace_idx: checkpoint.value.cumulative_rewards_trace_idx,
        )
    }
}

#[generate_trait]
pub impl MutablePoolMemberBalanceTraceImpl of MutablePoolMemberBalanceTraceTrait {
    /// Inserts a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint.
    /// This is done by either inserting a new checkpoint, or updating the last one.
    fn insert(
        self: StoragePath<Mutable<PoolMemberBalanceTrace>>, key: Epoch, value: PoolMemberBalance,
    ) -> (PoolMemberBalance, PoolMemberBalance) {
        let checkpoints = self.checkpoints;

        let len = checkpoints.len();
        if len == Zero::zero() {
            checkpoints.push(PoolMemberBalanceCheckpoint { key, value });
            return (Zero::zero(), value);
        }

        // Update or append new checkpoint.
        let mut last = checkpoints[len - 1].read();
        let prev = last.value;
        if last.key == key {
            last.value = value;
            checkpoints[len - 1].write(last);
        } else {
            // Checkpoint keys must be non-decreasing.
            assert!(last.key < key, "{}", TraceErrors::UNORDERED_INSERTION);
            checkpoints.push(PoolMemberBalanceCheckpoint { key, value });
        }
        (prev, value)
    }

    /// Retrieves the most recent checkpoint from the trace structure.
    ///
    /// # Returns
    /// A tuple containing:
    /// - `Epoch`: Timestamp/key of the latest checkpoint
    /// - `PoolMemberBalance`: Value stored in the latest checkpoint
    ///
    /// # Panics
    /// If the trace structure is empty (no checkpoints exist)
    ///
    /// # Note
    /// This will return the last inserted checkpoint that maintains the structure's
    /// invariant of non-decreasing keys.
    fn latest(self: StoragePath<Mutable<PoolMemberBalanceTrace>>) -> (Epoch, PoolMemberBalance) {
        self.as_non_mut().latest()
    }

    /// Returns whether the trace is non empty.
    fn is_non_empty(self: StoragePath<Mutable<PoolMemberBalanceTrace>>) -> bool {
        self.as_non_mut().is_non_empty()
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<Mutable<PoolMemberBalanceTrace>>) -> u64 {
        self.as_non_mut().length()
    }
}

#[generate_trait]
impl TraceHelperImpl of TraceHelperTrait {
    /// Returns the `n`th element from the end of the trace.
    fn _nth_back(self: StoragePath<PoolMemberBalanceTrace>, n: u64) -> (Epoch, PoolMemberBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(n < len, "{}", TraceErrors::INDEX_OUT_OF_BOUNDS);
        let checkpoint = checkpoints[len - n - 1].read();
        (checkpoint.key, checkpoint.value)
    }
}
