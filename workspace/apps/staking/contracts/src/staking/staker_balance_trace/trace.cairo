use core::num::traits::Zero;
use openzeppelin::utils::math::average;
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

#[derive(Copy, Drop, Serde, starknet::Store, Debug, PartialEq)]
pub(crate) struct StakerBalance {
    amount_own: Amount,
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
    fn new(amount: Amount) -> StakerBalance {
        StakerBalance { amount_own: amount, total_amount: amount }
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

    fn update_pool_amount(ref self: StakerBalance, amount: Amount) {
        let pool_amount = self.pool_amount();
        if amount > pool_amount {
            let diff = amount - pool_amount;
            self.total_amount += diff;
        } else {
            let diff = pool_amount - amount;
            self.total_amount -= diff;
        }
    }
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct StakerBalanceCheckpoint {
    key: Epoch,
    value: StakerBalance,
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
        let pos = checkpoints.len();
        assert!(pos > 0, "{}", TraceErrors::EMPTY_TRACE);
        let checkpoint = checkpoints[pos - 1].read();
        (checkpoint.key, checkpoint.value)
    }

    fn penultimate(self: StoragePath<StakerBalanceTrace>) -> (Epoch, StakerBalance) {
        let checkpoints = self.checkpoints;
        let pos = checkpoints.len();
        // TODO: consider move this error to trace errors.
        assert!(pos > 1, "{}", Error::PENULTIMATE_NOT_EXIST);
        let checkpoint = checkpoints[pos - 2].read();
        (checkpoint.key, checkpoint.value)
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<StakerBalanceTrace>) -> u64 {
        self.checkpoints.len()
    }

    /// Returns whether the trace is initialized.
    fn is_initialized(self: StoragePath<StakerBalanceTrace>) -> bool {
        self.checkpoints.len().is_non_zero()
    }

    /// Returns the value in the last (most recent) checkpoint with the key lower than or equal to
    /// the search key, or zero if there is none.
    fn upper_lookup(self: StoragePath<StakerBalanceTrace>, key: Epoch) -> StakerBalance {
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
pub impl MutableStakerBalanceTraceImpl of MutableStakerBalanceTraceTrait {
    /// Inserts a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint
    fn insert(self: StoragePath<Mutable<StakerBalanceTrace>>, key: Epoch, value: StakerBalance) {
        self.checkpoints.as_path()._insert(key, value);
    }

    /// Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
    fn latest(self: StoragePath<Mutable<StakerBalanceTrace>>) -> StakerBalance {
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
impl MutableStakerBalanceCheckpointImpl of MutableStakerBalanceCheckpointTrait {
    /// Pushes a (`key`, `value`) pair into an ordered list of checkpoints, either by inserting a
    /// new checkpoint, or by updating the last one.
    fn _insert(
        self: StoragePath<Mutable<Vec<StakerBalanceCheckpoint>>>, key: Epoch, value: StakerBalance,
    ) {
        let pos = self.len();

        if pos > 0 {
            let mut last = self[pos - 1].read();

            // Update or append new checkpoint
            if last.key == key {
                last.value = value;
                self[pos - 1].write(last);
            } else {
                // Checkpoint keys must be non-decreasing
                assert!(last.key < key, "{}", TraceErrors::UNORDERED_INSERTION);
                self.push(StakerBalanceCheckpoint { key, value });
            }
        } else {
            self.push(StakerBalanceCheckpoint { key, value });
        };
    }

    /// Returns the index of the last (most recent) checkpoint with the key lower than or equal to
    /// the search key, or `high` if there is none. `low` and `high` define a section where to do
    /// the search, with inclusive `low` and exclusive `high`.
    fn _upper_binary_lookup(
        self: StoragePath<Vec<StakerBalanceCheckpoint>>, key: Epoch, low: u64, high: u64,
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
