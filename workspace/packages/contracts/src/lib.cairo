pub(crate) mod bit_mask;
pub mod bit_set;

pub mod components;

pub mod constants;

// Make the module be available in the starknet-contract target.
#[cfg(target: 'test')]
pub(crate) mod erc20_mocks;

// Consts and other non-component utilities
pub mod errors;
pub mod interfaces;
pub mod math;
pub mod message_hash;

// Make the module be available in a test target.
// Simple #cfg(test) won't work because the module is not
// in the same crate with the actual tests using it.
#[cfg(target: 'test')]
pub mod test_utils;

#[cfg(test)]
mod tests;
pub mod types;
