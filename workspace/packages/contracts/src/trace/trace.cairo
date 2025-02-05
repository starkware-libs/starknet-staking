use contracts_commons::trace::errors::TraceErrors;
use openzeppelin::utils::math::average;
use starknet::storage::{Mutable, MutableVecTrait, StorageAsPath, StoragePath, Vec, VecTrait};
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

/// `Trace` struct, for checkpointing values as they change at different points in
/// time, and later looking up past values by block timestamp.
#[starknet::storage_node]
pub struct Trace {
    checkpoints: Vec<Checkpoint>,
}

// TODO: Implement StorePacking trait for Checkpoint.
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Checkpoint {
    key: u64,
    value: u128,
}

#[generate_trait]
pub impl TraceImpl of TraceTrait {
    /// Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
    fn latest(self: StoragePath<Trace>) -> u128 {
        let checkpoints = self.checkpoints;
        let pos = checkpoints.len();

        if pos == 0 {
            0
        } else {
            checkpoints[pos - 1].read().value
        }
    }

    /// Returns whether there is a checkpoint in the structure (i.e. it is not empty),
    /// and if so the key and value in the most recent checkpoint.
    fn latest_checkpoint(self: StoragePath<Trace>) -> (bool, u64, u128) {
        let checkpoints = self.checkpoints;
        let pos = checkpoints.len();

        if pos == 0 {
            (false, 0, 0)
        } else {
            let checkpoint = checkpoints[pos - 1].read();
            (true, checkpoint.key, checkpoint.value)
        }
    }

    /// Returns the total number of checkpoints.
    fn length(self: StoragePath<Trace>) -> u64 {
        self.checkpoints.len()
    }

    /// Returns the value in the last (most recent) checkpoint with the key lower than or equal to
    /// the search key, or zero if there is none.
    fn upper_lookup(self: StoragePath<Trace>, key: u64) -> u128 {
        let checkpoints = self.checkpoints.as_path();
        let len = checkpoints.len();
        let pos = checkpoints._upper_binary_lookup(key, 0, len).into();

        if pos == 0 {
            0
        } else {
            checkpoints[pos - 1].read().value
        }
    }
}

#[generate_trait]
pub impl MutableTraceImpl of MutableTraceTrait {
    /// Pushes a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint
    /// and returns both the previous and the new value.
    fn push(self: StoragePath<Mutable<Trace>>, key: u64, value: u128) -> (u128, u128) {
        self.checkpoints.as_path()._insert(key, value)
    }

    /// Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
    fn latest(self: StoragePath<Mutable<Trace>>) -> u128 {
        let checkpoints = self.checkpoints;
        let pos = checkpoints.len();

        if pos == 0 {
            0
        } else {
            checkpoints[pos - 1].read().value
        }
    }
}

#[generate_trait]
impl MutableCheckpointImpl of MutableCheckpointTrait {
    /// Pushes a (`key`, `value`) pair into an ordered list of checkpoints, either by inserting a
    /// new checkpoint, or by updating the last one.
    fn _insert(self: StoragePath<Mutable<Vec<Checkpoint>>>, key: u64, value: u128) -> (u128, u128) {
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
                self.append().write(Checkpoint { key, value });
            }
            (prev, value)
        } else {
            self.append().write(Checkpoint { key, value });
            (0, value)
        }
    }

    /// Returns the index of the last (most recent) checkpoint with the key lower than or equal to
    /// the search key, or `high` if there is none. `low` and `high` define a section where to do
    /// the search, with inclusive `low` and exclusive `high`.
    fn _upper_binary_lookup(
        self: StoragePath<Vec<Checkpoint>>, key: u64, low: u64, high: u64,
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
        };
        _high
    }
}
