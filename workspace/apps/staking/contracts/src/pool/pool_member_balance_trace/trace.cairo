use core::num::traits::Zero;
use openzeppelin::utils::math::average;
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

    /// Returns the value in the last (most recent) checkpoint with the key lower than or equal to
    /// the search key, or zero if there is none.
    fn upper_lookup(self: StoragePath<PoolMemberBalanceTrace>, key: Epoch) -> PoolMemberBalance {
        let checkpoints = self.checkpoints.as_path();
        let len = checkpoints.len();
        let pos = checkpoints._upper_binary_lookup(key, 0, len).into();

        if pos == 0 {
            Zero::zero()
        } else {
            checkpoints[pos - 1].read().value
        }
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

    /// Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
    fn latest(self: StoragePath<Mutable<PoolMemberBalanceTrace>>) -> PoolMemberBalance {
        let checkpoints = self.checkpoints;
        let pos = checkpoints.len();

        if pos == 0 {
            Zero::zero()
        } else {
            checkpoints[pos - 1].read().value
        }
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

        if pos > 0 {
            let mut last = self[pos - 1].read();

            // Update or append new checkpoint
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
        } else {
            self.push(PoolMemberBalanceCheckpoint { key, value });
            (Zero::zero(), value)
        }
    }

    /// Returns the index of the last (most recent) checkpoint with the key lower than or equal to
    /// the search key, or `high` if there is none. `low` and `high` define a section where to do
    /// the search, with inclusive `low` and exclusive `high`.
    fn _upper_binary_lookup(
        self: StoragePath<Vec<PoolMemberBalanceCheckpoint>>, key: Epoch, low: u64, high: u64,
    ) -> u64 {
        let mut _low = low;
        let mut _high = high;
        loop {
            if _low >= _high {
                break;
            }
            let mid = average(_low, _high);
            if (self[mid].read().key > key) {
                _high = mid;
            } else {
                _low = mid + 1;
            };
        }
        _high
    }
}
