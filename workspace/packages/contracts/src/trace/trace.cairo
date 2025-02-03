use contracts_commons::trace::errors::TraceErrors;
use starknet::storage::{Mutable, MutableVecTrait, StorageAsPath, StoragePath, Vec, VecTrait};
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

/// `Trace` struct, for checkpointing values as they change at different points in
/// time, and later looking up past values by block timestamp.
#[starknet::storage_node]
pub(crate) struct Trace {
    checkpoints: Vec<Checkpoint>,
}

// TODO: Implement StorePacking trait for Checkpoint.
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Checkpoint {
    key: u64,
    value: u128,
}

#[generate_trait]
pub(crate) impl TraceImpl of TraceTrait {
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
}

#[generate_trait]
pub(crate) impl MutableTraceImpl of MutableTraceTrait {
    /// Pushes a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint
    /// and returns both the previous and the new value.
    fn push(self: StoragePath<Mutable<Trace>>, key: u64, value: u128) -> (u128, u128) {
        self.checkpoints.as_path()._insert(key, value)
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
}
