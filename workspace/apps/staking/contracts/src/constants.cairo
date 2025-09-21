use staking::types::{Amount, Epoch};
use starknet::ContractAddress;

pub(crate) const STRK_IN_FRIS: Amount = 1_000_000_000_000_000_000; // 10**18

pub(crate) const STARTING_EPOCH: Epoch = 0;
pub(crate) const STRK_TOKEN_ADDRESS: ContractAddress =
    0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
    .try_into()
    .unwrap();

/// Epoch delay before consensus-related changes (e.g. balances, token activations) take effect.
pub(crate) const K: u8 = 2;
