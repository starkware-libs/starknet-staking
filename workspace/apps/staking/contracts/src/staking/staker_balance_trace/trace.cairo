use core::num::traits::Zero;
use staking::staking::errors::Error;
use staking::types::{Amount, Epoch};
use starknet::storage::{
    Mutable, MutableVecTrait, StorageAsPath, StoragePath, StoragePointerReadAccess,
    StoragePointerWriteAccess, Vec, VecTrait,
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
    // The amount staked by the staker.
    amount_own: Amount,
    // Amount own + delegated amount.
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
    /// - `Epoch`: Timestamp/key of the latest checkpoint
    /// - `StakerBalance`: Value stored in the latest checkpoint
    ///
    /// # Panics
    /// If the trace structure is empty (no checkpoints exist)
    ///
    /// # Note
    /// This will return the last inserted checkpoint that maintains the structure's
    /// invariant of non-decreasing keys.
    fn latest(self: StoragePath<StakerBalanceTrace>) -> (Epoch, StakerBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(len > 0, "{}", TraceErrors::EMPTY_TRACE);
        let checkpoint = checkpoints[len - 1].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Retrieves the penultimate checkpoint from the trace structure.
    /// Penultimate checkpoint is the second last checkpoint in the trace.
    fn penultimate(self: StoragePath<StakerBalanceTrace>) -> (Epoch, StakerBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        // TODO: consider move this error to trace errors.
        assert!(len > 1, "{}", Error::PENULTIMATE_NOT_EXIST);
        let checkpoint = checkpoints[len - 2].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<StakerBalanceTrace>) -> u64 {
        self.checkpoints.len()
    }

    /// Returns whether the trace is non empty.
    fn is_non_empty(self: StoragePath<StakerBalanceTrace>) -> bool {
        self.checkpoints.len().is_non_zero()
    }
}

#[generate_trait]
pub impl MutableStakerBalanceTraceImpl of MutableStakerBalanceTraceTrait {
    /// Inserts a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint
    fn insert(self: StoragePath<Mutable<StakerBalanceTrace>>, key: Epoch, value: StakerBalance) {
        self.checkpoints.as_path()._insert(key, value);
    }

    /// Retrieves the most recent checkpoint from the trace structure.
    ///
    /// # Returns
    /// A tuple containing:
    /// - `Epoch`: Timestamp/key of the latest checkpoint
    /// - `StakerBalance`: Value stored in the latest checkpoint
    ///
    /// # Panics
    /// If the trace structure is empty (no checkpoints exist)
    ///
    /// # Note
    /// This will return the last inserted checkpoint that maintains the structure's
    /// invariant of non-decreasing keys.
    fn latest(self: StoragePath<Mutable<StakerBalanceTrace>>) -> (Epoch, StakerBalance) {
        let checkpoints = self.checkpoints;
        let len = checkpoints.len();
        assert!(len > 0, "{}", TraceErrors::EMPTY_TRACE);
        let checkpoint = checkpoints[len - 1].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Returns whether the trace is non empty.
    fn is_non_empty(self: StoragePath<Mutable<StakerBalanceTrace>>) -> bool {
        self.checkpoints.len().is_non_zero()
    }
}

#[generate_trait]
impl MutableStakerBalanceCheckpointImpl of MutableStakerBalanceCheckpointTrait {
    /// Pushes a (`key`, `value`) pair into an ordered list of checkpoints, either by inserting a
    /// new checkpoint, or by updating the last one.
    fn _insert(
        self: StoragePath<Mutable<Vec<StakerBalanceCheckpoint>>>, key: Epoch, value: StakerBalance,
    ) {
        let len = self.len();
        if len == Zero::zero() {
            self.push(StakerBalanceCheckpoint { key, value });
            return;
        }

        // Update or append new checkpoint
        let mut last = self[len - 1].read();
        if last.key == key {
            last.value = value;
            self[len - 1].write(last);
        } else {
            // Checkpoint keys must be non-decreasing
            assert!(last.key < key, "{}", TraceErrors::UNORDERED_INSERTION);
            self.push(StakerBalanceCheckpoint { key, value });
        }
    }
}
