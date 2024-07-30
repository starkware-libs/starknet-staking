pub mod utils;

#[cfg(test)]
pub mod test_utils;
#[cfg(test)]
pub mod event_test_utils;

pub const BASE_VALUE: u64 = 100000000000;
// Contracts
pub mod staking;
pub mod pooling;
pub mod minting_curve;

// Consts and other non-component utilities
pub mod errors;
