use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use staking::errors::{Erc20Error, GenericError};
use staking::staking::objects::NormalizedAmount;
use staking::staking::staking::Staking::COMMISSION_DENOMINATOR;
use staking::types::{Amount, Commission, Index};
use starknet::syscalls::deploy_syscall;
use starknet::{ClassHash, ContractAddress, SyscallResultTrait, get_contract_address};
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::math::utils::{mul_wide_and_ceil_div, mul_wide_and_div};

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
        .expect_with_err(err: GenericError::COMMISSION_ISNT_AMOUNT_TYPE)
}

/// Compute the commission amount of the staker from the pool rewards.
///
/// $$ commission_amount = ceil_of_division(rewards_including_commission * commission,
/// COMMISSION_DENOMINATOR) $$
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

/// Compute the rewards from the amount and interest.
///
/// $$ rewards = amount * interest / base_value $$
/// **Note**: The Pool contract’s reward calculation logic uses integer division, discarding
/// small rounding remainders (dust) without tracking or redistributing them.
/// This results in negligible reward losses for delegators, as the total distributed rewards
/// are slightly less than the allocated amount.
pub(crate) fn compute_rewards_rounded_down(
    amount: Amount, interest: Index, base_value: Index,
) -> Amount {
    mul_wide_and_div(lhs: amount, rhs: interest, div: base_value)
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
}

/// Compute the threshold for requesting funds from L1 Reward Supplier.
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
        let success = self.transfer_from(:sender, :recipient, :amount);
        assert!(success, "{}", Erc20Error::TRANSFER_FAILED);
        success
    }

    fn checked_transfer(self: IERC20Dispatcher, recipient: ContractAddress, amount: u256) -> bool {
        assert!(
            amount <= self.balance_of(account: get_contract_address()),
            "{}",
            Erc20Error::INSUFFICIENT_BALANCE,
        );
        let success = self.transfer(:recipient, :amount);
        assert!(success, "{}", Erc20Error::TRANSFER_FAILED);
        success
    }
}

