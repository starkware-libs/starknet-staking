use core::num::traits::ops::pow::Pow;
use core::num::traits::zero::Zero;
use core::option::OptionTrait;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use staking::constants::{ALPHA, ALPHA_DENOMINATOR, STRK_TOKEN_ADDRESS};
use staking::errors::{GenericError, InternalError};
use staking::reward_supplier::interface::{
    IRewardSupplierDispatcher, IRewardSupplierDispatcherTrait,
};
use staking::staking::errors::Error;
use staking::staking::objects::{NormalizedAmount, NormalizedAmountTrait, UndelegateIntentValue};
use staking::staking::staking::Staking::COMMISSION_DENOMINATOR;
use staking::types::{Amount, Commission, Epoch, StakingPower};
use starknet::storage::StoragePath;
use starknet::syscalls::deploy_syscall;
use starknet::{
    ClassHash, ContractAddress, SyscallResultTrait, get_caller_address, get_contract_address,
};
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::math::utils::mul_wide_and_div;
use starkware_utils::storage::iterable_map::{
    IterableMapIntoIterImpl, IterableMapReadAccessImpl, IterableMapWriteAccessImpl,
};
use starkware_utils::trace::trace::{Trace, TraceTrait};

pub(crate) const STAKING_POWER_BASE_VALUE: u128 = 10_u128.pow(10);
pub(crate) const STRK_WEIGHT_FACTOR: u128 = STAKING_POWER_BASE_VALUE
    * (ALPHA_DENOMINATOR - ALPHA)
    / ALPHA_DENOMINATOR;
pub(crate) const BTC_WEIGHT_FACTOR: u128 = STAKING_POWER_BASE_VALUE * ALPHA / ALPHA_DENOMINATOR;

/// Return the token dispatcher for STRK.
pub(crate) fn strk_token_dispatcher() -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: STRK_TOKEN_ADDRESS }
}

/// Returns the token address for the given `undelegate_intent`.
pub(crate) fn get_undelegate_intent_token(
    undelegate_intent: UndelegateIntentValue,
) -> ContractAddress {
    // If undelegate_intent.token_address is zero, it means the intent is for the STRK
    // token (it was created before the BTC version).
    if undelegate_intent.token_address.is_zero() {
        STRK_TOKEN_ADDRESS
    } else {
        undelegate_intent.token_address
    }
}

pub(crate) fn claim_from_reward_supplier(
    reward_supplier_dispatcher: IRewardSupplierDispatcher,
    amount: Amount,
    token_dispatcher: IERC20Dispatcher,
) {
    let staking_contract = get_contract_address();
    let balance_before = token_dispatcher.balance_of(account: staking_contract);
    reward_supplier_dispatcher.claim_rewards(:amount);
    let balance_after = token_dispatcher.balance_of(account: staking_contract);
    assert!(balance_after - balance_before == amount.into(), "{}", Error::UNEXPECTED_BALANCE);
}

pub(crate) fn assert_caller_is_not_zero() {
    assert!(get_caller_address().is_non_zero(), "{}", Error::CALLER_IS_ZERO_ADDRESS);
}

/// Split rewards into pool's rewards and commission rewards.
/// Return a tuple of (commission_rewards, pool_rewards).
pub(crate) fn split_rewards_with_commission(
    rewards_including_commission: Amount, commission: Commission,
) -> (Amount, Amount) {
    let commission_rewards = compute_commission_amount_rounded_down(
        :rewards_including_commission, :commission,
    );
    let pool_rewards = rewards_including_commission - commission_rewards;
    (commission_rewards, pool_rewards)
}

/// Compute the commission amount of the staker from the pool rewards.
///
/// $$ commission_amount = rewards_including_commission * commission / COMMISSION_DENOMINATOR $$
pub(crate) fn compute_commission_amount_rounded_down(
    rewards_including_commission: Amount, commission: Commission,
) -> Amount {
    mul_wide_and_div(
        lhs: rewards_including_commission,
        rhs: commission.into(),
        div: COMMISSION_DENOMINATOR.into(),
    )
        .expect_with_err(err: InternalError::COMMISSION_ISNT_AMOUNT_TYPE)
}

/// Returns the balance at the specified epoch.
///
/// Precondition: `get_current_epoch() <= epoch_id < get_current_epoch() + K`.
pub(crate) fn balance_at_epoch(trace: StoragePath<Trace>, epoch_id: Epoch) -> NormalizedAmount {
    let (epoch, balance) = trace.last().unwrap_or_else(|err| panic!("{err}"));
    let current_balance = if epoch <= epoch_id {
        balance
    } else {
        let (epoch, balance) = trace.second_last().unwrap_or_else(|err| panic!("{err}"));
        if epoch <= epoch_id {
            balance
        } else {
            let (epoch, balance) = trace.third_last().unwrap_or_else(|err| panic!("{err}"));
            assert!(epoch <= epoch_id, "{}", InternalError::INVALID_THIRD_LAST);
            balance
        }
    };
    NormalizedAmountTrait::from_amount_18_decimals(amount: current_balance)
}

/// Returns true if the BTC token is active in the given `epoch_id`.
///
/// Precondition: `get_current_epoch() <= epoch_id < get_current_epoch() + K`.
pub(crate) fn is_btc_active(active_status: (Epoch, bool), epoch_id: Epoch) -> bool {
    let (epoch, is_active) = active_status;
    (epoch_id >= epoch) == is_active
}

/// Returns the staking power for the given staker.
/// The staking power is calculated by:
/// ((staker_strk_total_amount / strk_total_amount) * (1 - ALPHA) +
/// (staker_btc_total_amount / btc_total_amount) * ALPHA) * STAKING_POWER_BASE_VALUE
pub(crate) fn calculate_staker_total_staking_power(
    staker_strk_total_amount: NormalizedAmount,
    staker_btc_total_amount: NormalizedAmount,
    strk_total_stake: NormalizedAmount,
    btc_total_stake: NormalizedAmount,
) -> StakingPower {
    let strk_staking_power = mul_wide_and_div(
        lhs: staker_strk_total_amount.to_amount_18_decimals(),
        rhs: STRK_WEIGHT_FACTOR,
        div: strk_total_stake.to_amount_18_decimals(),
    )
        .unwrap();
    let btc_staking_power = if btc_total_stake.is_zero() {
        Zero::zero()
    } else {
        mul_wide_and_div(
            lhs: staker_btc_total_amount.to_amount_18_decimals(),
            rhs: BTC_WEIGHT_FACTOR,
            div: btc_total_stake.to_amount_18_decimals(),
        )
            .unwrap()
    };
    strk_staking_power + btc_staking_power
}

/// Computes the new delegated stake based on changing in the intent amount.
pub(crate) fn compute_new_delegated_stake(
    old_delegated_stake: NormalizedAmount,
    old_intent_amount: NormalizedAmount,
    new_intent_amount: NormalizedAmount,
) -> NormalizedAmount {
    let total_amount = old_intent_amount + old_delegated_stake;
    assert!(new_intent_amount <= total_amount, "{}", GenericError::AMOUNT_TOO_HIGH);
    total_amount - new_intent_amount
}

pub(crate) fn deploy_delegation_pool_contract(
    class_hash: ClassHash,
    contract_address_salt: felt252,
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    token_address: ContractAddress,
    governance_admin: ContractAddress,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    staker_address.serialize(ref calldata);
    staking_contract.serialize(ref calldata);
    token_address.serialize(ref calldata);
    governance_admin.serialize(ref calldata);
    let (pool_address, _) = deploy_syscall(
        :class_hash, :contract_address_salt, calldata: calldata.span(), deploy_from_zero: false,
    )
        .unwrap_syscall();
    pool_address
}
