use core::num::traits::Zero;
use staking::types::{Amount, Epoch, VecIndex};
use starknet::storage::{
    Mutable, MutableVecTrait, StorageAsPath, StoragePath, StoragePointerReadAccess,
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

#[derive(Copy, Drop, Serde)]
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
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(len > 0, "{}", TraceErrors::EMPTY_TRACE);
        let checkpoint = checkpoints[len - 1].read();
        (checkpoint.key, checkpoint.value)
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
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(len > 0, "{}", TraceErrors::EMPTY_TRACE);
        let checkpoint = checkpoints[len - 1].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Inserts a (`key`, `value`) pair into the trace one position before the latest checkpoint.
    ///
    /// Precondition: trace is not empty and `key` must be exactly one less than the latest
    /// checkpoint key.
    /// Insert the same balance as the checkpoint before the latest.
    fn insert_before_latest(
        self: StoragePath<Mutable<PoolMemberBalanceTrace>>,
        key: Epoch,
        cumulative_rewards_trace_idx: VecIndex,
    ) {
        let checkpoints = self.checkpoints;

        // Empty trace.
        let len = checkpoints.len();
        assert!(len > 0, "{}", TraceErrors::EMPTY_TRACE);

        // The key must be exactly one less than the latest key.
        let latest = checkpoints[len - 1].read();
        assert!(latest.key - 1 == key, "Given key must be exactly one less than the latest key.");

        // Trace with only one checkpoint.
        // TODO: this happend only when enter and in the same epoch claim rewards - i.e should get
        // 0 rewards. do we need this case? or return something else?
        if len == 1 {
            let value = PoolMemberBalance { balance: 0, cumulative_rewards_trace_idx };
            checkpoints[len - 1].write(PoolMemberBalanceCheckpoint { key, value });
            checkpoints.push(latest);
            // Trace with two or more checkpoints.
        } else {
            let before_latest = checkpoints[len - 2].read();
            let pool_member_balance_checkpoint = PoolMemberBalanceCheckpoint {
                key,
                value: PoolMemberBalance {
                    balance: before_latest.value.balance, cumulative_rewards_trace_idx,
                },
            };
            // TODO: do we need to edit checkpoints[len-2] if we have the same key there.
            if before_latest.key == key {
                checkpoints[len - 2].write(pool_member_balance_checkpoint);
            } else {
                checkpoints[len - 1].write(pool_member_balance_checkpoint);
                checkpoints.push(latest);
            }
        }
    }

    /// Returns whether the trace is non empty.
    fn is_non_empty(self: StoragePath<Mutable<PoolMemberBalanceTrace>>) -> bool {
        self.checkpoints.len().is_non_zero()
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<Mutable<PoolMemberBalanceTrace>>) -> u64 {
        self.checkpoints.len()
    }
}
