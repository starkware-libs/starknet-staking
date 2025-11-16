use staking::constants::{ALPHA, ALPHA_DENOMINATOR};
use staking::errors::InternalError;
use staking::types::Amount;
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::math::utils::mul_wide_and_div;

pub(crate) fn calculate_btc_rewards(total_rewards: Amount) -> Amount {
    mul_wide_and_div(lhs: total_rewards, rhs: ALPHA, div: ALPHA_DENOMINATOR)
        .expect_with_err(err: InternalError::REWARDS_COMPUTATION_OVERFLOW)
}

/// Compute the threshold for requesting funds from L1 Reward Supplier.
pub(crate) fn compute_threshold(base_mint_amount: Amount) -> Amount {
    base_mint_amount / 2
}
