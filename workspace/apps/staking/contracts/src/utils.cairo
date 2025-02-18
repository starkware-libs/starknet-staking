use contracts_commons::errors::OptionAuxTrait;
use contracts_commons::math::utils::{mul_wide_and_ceil_div, mul_wide_and_div};
use core::num::traits::zero::Zero;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use staking::constants::{BASE_VALUE, STRK_IN_FRIS};
use staking::errors::{Erc20Error, GenericError};
use staking::staking::errors::Error as StakingError;
use staking::staking::staking::Staking::COMMISSION_DENOMINATOR;
use staking::types::{Amount, Commission, Index};
use starknet::syscalls::deploy_syscall;
use starknet::{ClassHash, ContractAddress, SyscallResultTrait, get_contract_address};

/// Computes the new delegated stake based on changing in the intent amount.
pub(crate) fn compute_new_delegated_stake(
    old_delegated_stake: Amount, old_intent_amount: Amount, new_intent_amount: Amount,
) -> Amount {
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
    commission: Commission,
    governance_admin: ContractAddress,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    staker_address.serialize(ref calldata);
    staking_contract.serialize(ref calldata);
    token_address.serialize(ref calldata);
    commission.serialize(ref calldata);
    governance_admin.serialize(ref calldata);
    let (pool_address, _) = deploy_syscall(
        :class_hash, :contract_address_salt, calldata: calldata.span(), deploy_from_zero: false,
    )
        .unwrap_syscall();
    pool_address
}

// Compute the commission amount of the staker from the pool rewards.
//
// $$ commission_amount = rewards_including_commission * commission / COMMISSION_DENOMINATOR $$
pub(crate) fn compute_commission_amount_rounded_down(
    rewards_including_commission: Amount, commission: Commission,
) -> Amount {
    mul_wide_and_div(
        lhs: rewards_including_commission,
        rhs: commission.into(),
        div: COMMISSION_DENOMINATOR.into(),
    )
        .expect_with_err(err: GenericError::COMMISSION_ISNT_AMOUNT_TYPE)
}

// Compute the commission amount of the staker from the pool rewards.
//
// $$ commission_amount = ceil_of_division(rewards_including_commission * commission,
// COMMISSION_DENOMINATOR) $$
pub(crate) fn compute_commission_amount_rounded_up(
    rewards_including_commission: Amount, commission: Commission,
) -> Amount {
    mul_wide_and_ceil_div(
        lhs: rewards_including_commission,
        rhs: commission.into(),
        div: COMMISSION_DENOMINATOR.into(),
    )
        .expect_with_err(err: GenericError::COMMISSION_ISNT_AMOUNT_TYPE)
}

pub(crate) fn compute_global_index_diff(staking_rewards: Amount, total_stake: Amount) -> Index {
    // Return zero if the total stake is too small, to avoid overflow below.
    if total_stake < STRK_IN_FRIS {
        return Zero::zero();
    }
    mul_wide_and_div(lhs: staking_rewards, rhs: BASE_VALUE, div: total_stake)
        .expect_with_err(err: StakingError::GLOBAL_INDEX_DIFF_COMPUTATION_OVERFLOW)
}

// Compute the rewards from the amount and interest.
//
// $$ rewards = amount * interest / BASE_VALUE $$
pub(crate) fn compute_rewards_rounded_down(amount: Amount, interest: Index) -> Amount {
    mul_wide_and_div(lhs: amount, rhs: interest, div: BASE_VALUE)
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
}

// Compute the rewards from the amount and interest.
//
// $$ rewards = ceil_of_division(amount * interest, BASE_VALUE) $$
pub(crate) fn compute_rewards_rounded_up(amount: Amount, interest: Index) -> Amount {
    mul_wide_and_ceil_div(lhs: amount, rhs: interest, div: BASE_VALUE)
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
}

// Compute the threshold for requesting funds from L1 Reward Supplier.
pub(crate) fn compute_threshold(base_mint_amount: Amount) -> Amount {
    base_mint_amount / 2
}

#[generate_trait]
pub(crate) impl CheckedIERC20DispatcherImpl of CheckedIERC20DispatcherTrait {
    fn checked_transfer_from(
        self: IERC20Dispatcher, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool {
        assert!(amount <= self.balance_of(account: sender), "{}", Erc20Error::INSUFFICIENT_BALANCE);
        assert!(
            amount <= self.allowance(owner: sender, spender: get_contract_address()),
            "{}",
            Erc20Error::INSUFFICIENT_ALLOWANCE,
        );
        self.transfer_from(:sender, :recipient, :amount)
    }

    fn checked_transfer(self: IERC20Dispatcher, recipient: ContractAddress, amount: u256) -> bool {
        assert!(
            amount <= self.balance_of(account: get_contract_address()),
            "{}",
            Erc20Error::INSUFFICIENT_BALANCE,
        );
        self.transfer(:recipient, :amount)
    }
}

#[cfg(test)]
mod tests {
    use core::num::traits::zero::Zero;
    use super::{BASE_VALUE, STRK_IN_FRIS, compute_global_index_diff};

    #[test]
    fn test_compute_global_index_diff() {
        assert!(compute_global_index_diff(STRK_IN_FRIS, STRK_IN_FRIS) == BASE_VALUE);
        assert!(compute_global_index_diff(STRK_IN_FRIS, STRK_IN_FRIS - 1) == Zero::zero());
    }
}

