use core::num::traits::Zero;
use staking::types::{Amount, Epoch};
use starknet::storage::{
    Mutable, MutableVecTrait, StoragePath, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
    VecTrait,
};
use starkware_utils::trace::errors::TraceErrors;

/// `Trace` struct, for checkpointing values as they change at different points in
/// time, and later looking up past values by block timestamp.
#[starknet::storage_node]
pub struct StakerBalanceTrace {
    checkpoints: Vec<StakerBalanceCheckpoint>,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct StakerBalanceCheckpoint {
    key: Epoch,
    value: StakerBalance,
}

#[derive(Copy, Drop, Serde, starknet::Store, Debug, PartialEq)]
pub(crate) struct StakerBalance {
    /// The amount staked by the staker.
    amount_own: Amount,
    /// Amount own + delegated amount.
    total_amount: Amount,
}

pub(crate) impl StakerBalanceZero of core::num::traits::Zero<StakerBalance> {
    fn zero() -> StakerBalance {
        StakerBalance { amount_own: Zero::zero(), total_amount: Zero::zero() }
    }

    fn is_zero(self: @StakerBalance) -> bool {
        *self == Self::zero()
    }

    fn is_non_zero(self: @StakerBalance) -> bool {
        !self.is_zero()
    }
}

#[generate_trait]
pub(crate) impl StakerBalanceImpl of StakerBalanceTrait {
    fn new(amount_own: Amount) -> StakerBalance {
        StakerBalance { amount_own, total_amount: amount_own }
    }

    fn amount_own(self: @StakerBalance) -> Amount {
        *self.amount_own
    }

    fn total_amount(self: @StakerBalance) -> Amount {
        *self.total_amount
    }

    fn pool_amount(self: @StakerBalance) -> Amount {
        *self.total_amount - *self.amount_own
    }

    fn increase_own_amount(ref self: StakerBalance, amount: Amount) {
        self.amount_own += amount;
        self.total_amount += amount;
    }

    fn update_pool_amount(ref self: StakerBalance, new_amount: Amount) {
        self.total_amount = self.amount_own + new_amount;
    }
}

#[generate_trait]
pub impl StakerBalanceTraceImpl of StakerBalanceTraceTrait {
    /// Retrieves the most recent checkpoint from the trace structure.
    ///
    /// # Returns
    /// A tuple containing:
    /// - `Epoch`: Timestamp/key of the last checkpoint
    /// - `StakerBalance`: Value stored in the last checkpoint
    ///
    /// # Panics
    /// If the trace structure is empty (no checkpoints exist)
    ///
    /// # Note
    /// This will return the last inserted checkpoint that maintains the structure's
    /// invariant of non-decreasing keys.
    fn last(self: StoragePath<StakerBalanceTrace>) -> (Epoch, StakerBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(len > 0, "{}", TraceErrors::INDEX_OUT_OF_BOUNDS);
        let checkpoint = checkpoints[len - 1].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Retrieves the second last checkpoint from the trace structure.
    fn second_last(self: StoragePath<StakerBalanceTrace>) -> (Epoch, StakerBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(len > 1, "{}", TraceErrors::INDEX_OUT_OF_BOUNDS);
        let checkpoint = checkpoints[len - 2].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<StakerBalanceTrace>) -> u64 {
        self.checkpoints.len()
    }

    /// Returns whether the trace is non empty.
    fn is_non_empty(self: StoragePath<StakerBalanceTrace>) -> bool {
        !self.is_empty()
    }

    /// Returns whether the trace is empty.
    fn is_empty(self: StoragePath<StakerBalanceTrace>) -> bool {
        self.checkpoints.len().is_zero()
    }
}

#[generate_trait]
pub impl MutableStakerBalanceTraceImpl of MutableStakerBalanceTraceTrait {
    /// Inserts a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint.
    /// This is done by either inserting a new checkpoint, or updating the last one.
    fn insert(self: StoragePath<Mutable<StakerBalanceTrace>>, key: Epoch, value: StakerBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        if len == Zero::zero() {
            checkpoints.push(StakerBalanceCheckpoint { key, value });
            return;
        }

        // Update or append new checkpoint.
        let mut last = checkpoints[len - 1].read();
        if last.key == key {
            last.value = value;
            checkpoints[len - 1].write(last);
        } else {
            // Checkpoint keys must be non-decreasing.
            assert!(last.key < key, "{}", TraceErrors::UNORDERED_INSERTION);
            checkpoints.push(StakerBalanceCheckpoint { key, value });
        }
    }

    /// Retrieves the most recent checkpoint from the trace structure.
    ///
    /// # Returns
    /// A tuple containing:
    /// - `Epoch`: Timestamp/key of the last checkpoint
    /// - `StakerBalance`: Value stored in the last checkpoint
    ///
    /// # Panics
    /// If the trace structure is empty (no checkpoints exist)
    ///
    /// # Note
    /// This will return the last inserted checkpoint that maintains the structure's
    /// invariant of non-decreasing keys.
    fn last(self: StoragePath<Mutable<StakerBalanceTrace>>) -> (Epoch, StakerBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(len > 0, "{}", TraceErrors::INDEX_OUT_OF_BOUNDS);
        let checkpoint = checkpoints[len - 1].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Returns whether the trace is non empty.
    fn is_non_empty(self: StoragePath<Mutable<StakerBalanceTrace>>) -> bool {
        !self.is_empty()
    }

    /// Returns whether the trace is empty.
    fn is_empty(self: StoragePath<Mutable<StakerBalanceTrace>>) -> bool {
        self.checkpoints.len().is_zero()
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<Mutable<StakerBalanceTrace>>) -> u64 {
        self.checkpoints.len()
    }

    /// Returns the checkpoint at the given index.
    fn at(self: StoragePath<Mutable<StakerBalanceTrace>>, index: u64) -> (Epoch, StakerBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(index < len, "{}", TraceErrors::INDEX_OUT_OF_BOUNDS);
        let checkpoint = checkpoints[index].read();
        (checkpoint.key, checkpoint.value)
    }
}
