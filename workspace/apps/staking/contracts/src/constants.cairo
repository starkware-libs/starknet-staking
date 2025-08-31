use core::num::traits::Pow;
use staking_test::pool::objects::TokenRewardsConfig;
use staking_test::types::{Amount, Epoch, Inflation, Version, Index};
use starknet::ContractAddress;
use starkware_utils::constants::WEEK;
use starkware_utils::time::time::TimeDelta;

pub const DEFAULT_EXIT_WAIT_WINDOW: TimeDelta = TimeDelta { seconds: 3 * WEEK };
pub const MAX_EXIT_WAIT_WINDOW: TimeDelta = TimeDelta { seconds: 12 * WEEK };
pub const STRK_IN_FRIS: Amount = 1_000_000_000_000_000_000; // 10**18

pub const BTC_BASE_VALUE: Amount = 10_u128.pow(13);
pub const BTC_DECIMALS: u8 = 8;
pub const MIN_BTC_FOR_REWARDS: Amount = 10_u128.pow(3);
pub const STRK_BASE_VALUE: Index = 10_000_000_000_000_000_000_000_000_000; // 10**28
pub const STRK_DECIMALS: u8 = 18;

/// Token configuration for rewards calculation.
///
/// - STRK: Token with 18 decimals
/// - BTC_8D: Bitcoin with native 8 decimals
/// - BTC_18D: Wrapped Bitcoin with 18 decimals
///
/// The `min_for_rewards` is the minimum delegated stake required to earn rewards.
/// The `base_value` is used for precision in reward calculations.
pub const STRK_CONFIG: TokenRewardsConfig = TokenRewardsConfig {
    decimals: 18, min_for_rewards: 10_u128.pow(18), base_value: 10_u128.pow(28),
};

pub const BTC_8D_CONFIG: TokenRewardsConfig = TokenRewardsConfig {
    decimals: 8, min_for_rewards: 10_u128.pow(3), base_value: 10_u128.pow(13),
};

pub const BTC_18D_CONFIG: TokenRewardsConfig = TokenRewardsConfig {
    decimals: 18, min_for_rewards: 10_u128.pow(13), base_value: 10_u128.pow(23),
};
// === Reward Distribution - Important Note ===
//
// Previous version:
// - Minting coefficient C = 1.60 (160 / 10,000).
// - 100% of minted rewards allocated to STRK stakers.
//
// Current version:
// - Rewards split: 75% to STRK stakers, 25% to BTC stakers, using alpha = 0.25 (25 / 100).
// - To keep STRK rewards nearly unchanged, minting increased to C = 2.13 (213 / 10,000)
//   — slightly less than 2.13333... for an exact match.
//
// Implications:
// - STRK stakers receive ~1/40,000 (0.00333...% * 0.75) less rewards than before.
// - Additional minor rounding differences may occur in reward calculations.
pub const DEFAULT_C_NUM: Inflation = 213;
pub const MAX_C_NUM: Inflation = 500;
pub const C_DENOM: Inflation = 10_000;
pub const MIN_ATTESTATION_WINDOW: u16 = 11;
pub const STARTING_EPOCH: Epoch = 0;
/// This var was used as the prev contract version in V1.
/// This is the key for `prev_class_hash` (class hash of V0) in both staking and pool contracts.
pub const V1_PREV_CONTRACT_VERSION: Version = '0';
/// Prev contract version for V2 (BTC) staking contract.
/// This is the key for `prev_class_hash` (class hash of V1) in staking contract.
pub const STAKING_V2_PREV_CONTRACT_VERSION: Version = '1';
pub const STRK_TOKEN_ADDRESS: ContractAddress =
    0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
    .try_into()
    .unwrap();
