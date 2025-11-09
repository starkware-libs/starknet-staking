use core::num::traits::Pow;
use core::num::traits::zero::Zero;
use openzeppelin::token::erc20::interface::{
    IERC20Dispatcher, IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait,
};
use staking::constants::STRK_TOKEN_ADDRESS;
use staking::errors::{GenericError, InternalError};
use staking::pool::objects::TokenRewardsConfig;
use staking::pool::pool::Pool::STRK_CONFIG;
use staking::types::{Amount, Epoch, VecIndex};
use staking::utils::CheckedIERC20DispatcherTrait;
use starknet::storage::StorageBase;
use starknet::{ContractAddress, get_contract_address};
use starkware_utils::trace::trace::{Trace, TraceTrait};

/// Transfer funds of the specified amount from the given delegator to the pool.
///
/// Sufficient approvals of transfer is a pre-condition.
pub(crate) fn transfer_from_delegator(
    pool_member: ContractAddress, amount: Amount, token_dispatcher: IERC20Dispatcher,
) {
    let self_contract = get_contract_address();
    token_dispatcher
        .checked_transfer_from(
            sender: pool_member, recipient: self_contract, amount: amount.into(),
        );
}

/// Handles edge cases for `find_sigma`.
///
/// For edge cases, returns the `sigma` of the latest checkpoint whose `epoch` <
/// `target_epoch`. Otherwise, returns `None`.
pub(crate) fn find_sigma_edge_cases(
    cumulative_rewards_trace_vec: StorageBase<Trace>,
    cumulative_rewards_trace_idx: VecIndex,
    target_epoch: Epoch,
) -> Option<Amount> {
    // Edge case 1: Pool member enter delegation before any rewards given to the pool.
    if cumulative_rewards_trace_idx == 0 {
        return Some(Zero::zero());
    }

    let cumulative_rewards_trace_len = cumulative_rewards_trace_vec.length();

    // Edge case 2: `idx = len`.
    // In this version: `len + 1` was written, and rewards given to pool from that moment
    // only once.
    // In old version: `len` was written, and no rewards given to pool from that moment.
    if cumulative_rewards_trace_idx == cumulative_rewards_trace_len {
        // Two entries in the cumulative rewards trace are relevant (`idx - 1`, `idx - 2`).
        let (epoch, sigma) = cumulative_rewards_trace_vec.at(cumulative_rewards_trace_idx - 1);
        // In case `idx == 1`, `(epoch, sigma)` at `idx - 1` is `(0,0)` (the first trace
        // entry), so always return here.
        // This case only occurs in old-version checkpoints. In the current version, `idx =
        // 1` implies `len - 1` was written, so `len > idx` and we never reach this point.
        if epoch < target_epoch {
            return Some(sigma);
        }
        // Note: When handling a checkpoint from the old version, it never reaches here.
        assert!(cumulative_rewards_trace_idx > 1, "{}", InternalError::INVALID_REWARDS_TRACE_IDX);
        let (epoch, sigma) = cumulative_rewards_trace_vec.at(cumulative_rewards_trace_idx - 2);
        assert!(epoch < target_epoch, "{}", InternalError::INVALID_EPOCH_IN_TRACE);
        return Some(sigma);
    }

    // Edge case 3: `idx = 1`.
    // In this version: `len - 1` was written for the current checkpoint. (`len + 1` wasn't
    // written since `len >= 1`).
    // In old version: `len` was written, or `len - 1` was written for the current
    // checkpoint.
    // TODO: Use helper function that gets index and looks at two entries in the cumulative
    // rewards trace here and in edge case 2.
    if cumulative_rewards_trace_idx == 1 && cumulative_rewards_trace_len > 1 {
        // Two entries in the cumulative rewards trace are relevant (`idx`, `idx - 1`).
        let (epoch, sigma) = cumulative_rewards_trace_vec.at(cumulative_rewards_trace_idx);
        if epoch < target_epoch {
            return Some(sigma);
        }
        let (epoch, sigma) = cumulative_rewards_trace_vec.at(cumulative_rewards_trace_idx - 1);
        assert!(epoch < target_epoch, "{}", InternalError::INVALID_EPOCH_IN_TRACE);
        return Some(sigma);
    }

    // Edge case 4: `idx = len + 1`.
    // In this version: `len + 1` was written, and no rewards given to pool from that
    // moment.
    // In old version: never reached here (`len` or `len - 1` was written).
    if cumulative_rewards_trace_idx == cumulative_rewards_trace_len + 1 {
        // Only one entry in the cumulative rewards trace is relevant (`idx - 2`).
        let (epoch, sigma) = cumulative_rewards_trace_vec.at(cumulative_rewards_trace_len - 1);
        assert!(epoch < target_epoch, "{}", InternalError::INVALID_EPOCH_IN_TRACE);
        return Some(sigma);
    }

    None
}

/// Returns the sigma for the standard case of `find_sigma`.
/// Looks at up to 3 checkpoints in `cumulative_rewards_trace_vec`,
/// `cumulative_rewards_trace_idx`, `cumulative_rewards_trace_idx - 1` and
/// `cumulative_rewards_trace_idx - 2`, and takes the latest one (among these checkpoints)
/// whose `epoch` < `target_epoch`.
pub(crate) fn find_sigma_standard_case(
    cumulative_rewards_trace_vec: StorageBase<Trace>,
    cumulative_rewards_trace_idx: VecIndex,
    target_epoch: Epoch,
) -> Amount {
    // Three entries in the cumulative rewards trace are relevant (idx, idx - 1, idx - 2).
    let (epoch, sigma) = cumulative_rewards_trace_vec.at(cumulative_rewards_trace_idx);
    if epoch < target_epoch {
        return sigma;
    }
    let (epoch, sigma) = cumulative_rewards_trace_vec.at(cumulative_rewards_trace_idx - 1);
    if epoch < target_epoch {
        return sigma;
    }
    // Note: When handling a checkpoint from the old version, it never reaches here.
    let (epoch, sigma) = cumulative_rewards_trace_vec.at(cumulative_rewards_trace_idx - 2);
    assert!(epoch < target_epoch, "{}", InternalError::INVALID_EPOCH_IN_TRACE);
    sigma
}

/// Get token rewards configuration based on address and decimals.
pub(crate) fn get_token_rewards_config(token_address: ContractAddress) -> TokenRewardsConfig {
    if token_address == STRK_TOKEN_ADDRESS {
        STRK_CONFIG
    } else {
        // BTC token.
        let token_dispatcher = IERC20MetadataDispatcher { contract_address: token_address };
        let decimals = token_dispatcher.decimals();
        assert!(decimals >= 5 && decimals <= 18, "{}", GenericError::INVALID_TOKEN_DECIMALS);
        TokenRewardsConfig {
            decimals,
            min_for_rewards: 10_u128.pow(decimals.into() - 5),
            base_value: 10_u128.pow(decimals.into() + 5),
        }
    }
}
