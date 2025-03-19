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
    rewards_info_idx: VecIndex,
}

pub(crate) impl PoolMemberBalanceZero of core::num::traits::Zero<PoolMemberBalance> {
    fn zero() -> PoolMemberBalance {
        PoolMemberBalance { balance: Zero::zero(), rewards_info_idx: Zero::zero() }
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
    fn new(balance: Amount, rewards_info_idx: VecIndex) -> PoolMemberBalance {
        PoolMemberBalance { balance, rewards_info_idx }
    }

    fn balance(self: @PoolMemberBalance) -> Amount {
        *self.balance
    }

    fn rewards_info_idx(self: @PoolMemberBalance) -> VecIndex {
        *self.rewards_info_idx
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
    rewards_info_idx: VecIndex,
}

#[generate_trait]
pub(crate) impl PoolMemberCheckpointImpl of PoolMemberCheckpointTrait {
    fn new(epoch: Epoch, balance: Amount, rewards_info_idx: VecIndex) -> PoolMemberCheckpoint {
        PoolMemberCheckpoint { epoch, balance, rewards_info_idx }
    }

    fn epoch(self: @PoolMemberCheckpoint) -> Epoch {
        *self.epoch
    }

    fn balance(self: @PoolMemberCheckpoint) -> Amount {
        *self.balance
    }

    fn rewards_info_idx(self: @PoolMemberCheckpoint) -> VecIndex {
        *self.rewards_info_idx
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
        let pos = checkpoints.len();
        assert!(pos > 0, "{}", TraceErrors::EMPTY_TRACE);
        let checkpoint = checkpoints[pos - 1].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<PoolMemberBalanceTrace>) -> u64 {
        self.checkpoints.len()
    }

    /// Returns whether the trace is initialized.
    fn is_initialized(self: StoragePath<PoolMemberBalanceTrace>) -> bool {
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
            rewards_info_idx: checkpoint.value.rewards_info_idx,
        )
    }
}

#[generate_trait]
pub impl MutablePoolMemberBalanceTraceImpl of MutablePoolMemberBalanceTraceTrait {
    /// Inserts a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint
    /// and returns both the previous and the new value.
    fn insert(
        self: StoragePath<Mutable<PoolMemberBalanceTrace>>, key: Epoch, value: PoolMemberBalance,
    ) -> (PoolMemberBalance, PoolMemberBalance) {
        self.checkpoints.as_path()._insert(key, value)
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
        let pos = checkpoints.len();
        assert!(pos > 0, "{}", TraceErrors::EMPTY_TRACE);
        let checkpoint = checkpoints[pos - 1].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Inserts a (`key`, `value`) pair into the trace one position before the latest checkpoint.
    ///
    /// Precondition: trace is not empty and `key` must be exactly one less than the latest
    /// checkpoint key.
    fn insert_before_latest(
        self: StoragePath<Mutable<PoolMemberBalanceTrace>>, key: Epoch, rewards_info_idx: VecIndex,
    ) {
        self.checkpoints.as_path()._insert_before_latest(:key, :rewards_info_idx)
    }

    /// Returns whether the trace is initialized.
    fn is_initialized(self: StoragePath<Mutable<PoolMemberBalanceTrace>>) -> bool {
        self.checkpoints.len().is_non_zero()
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<Mutable<PoolMemberBalanceTrace>>) -> u64 {
        self.checkpoints.len()
    }
}

#[generate_trait]
impl MutablePoolMemberBalanceCheckpointImpl of MutablePoolMemberBalanceCheckpointTrait {
    /// Pushes a (`key`, `value`) pair into an ordered list of checkpoints, either by inserting a
    /// new checkpoint, or by updating the last one.
    fn _insert(
        self: StoragePath<Mutable<Vec<PoolMemberBalanceCheckpoint>>>,
        key: Epoch,
        value: PoolMemberBalance,
    ) -> (PoolMemberBalance, PoolMemberBalance) {
        let pos = self.len();
        if pos == Zero::zero() {
            self.push(PoolMemberBalanceCheckpoint { key, value });
            return (Zero::zero(), value);
        }

        // Update or append new checkpoint
        let mut last = self[pos - 1].read();
        let prev = last.value;
        if last.key == key {
            last.value = value;
            self[pos - 1].write(last);
        } else {
            // Checkpoint keys must be non-decreasing
            assert!(last.key < key, "{}", TraceErrors::UNORDERED_INSERTION);
            self.push(PoolMemberBalanceCheckpoint { key, value });
        }
        (prev, value)
    }

    /// Inserts a (`key`, `value`) pair into the trace one position before the latest checkpoint.
    /// Precondition: trace is not empty and `key` must be exactly one less than the latest.
    /// Insert the same balance as the checkpoint before the latest.
    fn _insert_before_latest(
        self: StoragePath<Mutable<Vec<PoolMemberBalanceCheckpoint>>>,
        key: Epoch,
        rewards_info_idx: VecIndex,
    ) {
        // Empty trace.
        let len = self.len();
        assert!(len > 0, "{}", TraceErrors::EMPTY_TRACE);

        // The key must be exactly one less than the latest key.
        let latest = self[len - 1].read();
        assert!(latest.key - 1 == key, "Given key must be exactly one less than the latest key.");

        // Trace with only one checkpoint.
        // TODO: this happend only when enter and in the same epoch claim rewards - i.e should get
        // 0 rewards. do we need this case? or return something else?
        if len == 1 {
            let value = PoolMemberBalance { balance: 0, rewards_info_idx };
            self[len - 1].write(PoolMemberBalanceCheckpoint { key, value });
            self.push(latest);
            // Trace with two or more checkpoints.
        } else {
            let before_latest = self[len - 2].read();
            let pool_member_balance_checkpoint = PoolMemberBalanceCheckpoint {
                key,
                value: PoolMemberBalance { balance: before_latest.value.balance, rewards_info_idx },
            };
            // TODO: do we need to edit self[len-2] if we have the same key there.
            if before_latest.key == key {
                self[len - 2].write(pool_member_balance_checkpoint);
            } else {
                self[len - 1].write(pool_member_balance_checkpoint);
                self.push(latest);
            }
        }
    }
}
