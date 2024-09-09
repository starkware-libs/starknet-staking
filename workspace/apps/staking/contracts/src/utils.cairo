use contracts::constants::{BASE_VALUE, SECONDS_IN_DAY};
use contracts::errors::{Error, OptionAuxTrait, assert_with_err};
use starknet::{ContractAddress, ClassHash, SyscallResultTrait, get_contract_address};
use starknet::syscalls::deploy_syscall;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use contracts::staking::Staking::{COMMISSION_DENOMINATOR};
use core::num::traits::zero::Zero;
use core::num::traits::WideMul;
use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
pub const MAX_U64: u64 = 18446744073709551615;
pub const MAX_U128: u128 = 340282366920938463463374607431768211455;

pub fn u64_mul_wide_and_div_unsafe(lhs: u64, rhs: u64, div: u64, error: Error) -> u64 {
    (lhs.wide_mul(other: rhs) / div.into()).try_into().expect_with_err(error)
}

pub fn u64_mul_wide_and_ceil_div_unsafe(lhs: u64, rhs: u64, div: u64, error: Error) -> u64 {
    ceil_of_division(lhs.wide_mul(other: rhs), div.into()).try_into().expect_with_err(error)
}

pub fn u128_mul_wide_and_div_unsafe(lhs: u128, rhs: u128, div: u128, error: Error) -> u128 {
    let x = lhs.wide_mul(other: rhs);
    (x / div.into()).try_into().expect_with_err(error)
}

pub fn u128_mul_wide_and_ceil_div_unsafe(lhs: u128, rhs: u128, div: u128, error: Error) -> u128 {
    let x = lhs.wide_mul(other: rhs);
    u256_ceil_of_division(x, div.into()).try_into().expect_with_err(error)
}

pub fn deploy_delegation_pool_contract(
    class_hash: ClassHash,
    contract_address_salt: felt252,
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    token_address: ContractAddress,
    commission: u16,
    admin: ContractAddress,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    staker_address.serialize(ref calldata);
    staking_contract.serialize(ref calldata);
    token_address.serialize(ref calldata);
    commission.serialize(ref calldata);
    let (pool_address, _) = deploy_syscall(
        :class_hash, :contract_address_salt, calldata: calldata.span(), deploy_from_zero: false
    )
        .unwrap_syscall();
    let roles_dispatcher = IRolesDispatcher { contract_address: pool_address };
    roles_dispatcher.register_governance_admin(account: admin);
    pool_address
}

// Compute the commission amount of the staker from the pool rewards.
//
// $$ commission_amount = rewards_including_commission * commission / COMMISSION_DENOMINATOR $$
pub fn compute_commission_amount_rounded_down(
    rewards_including_commission: u128, commission: u16
) -> u128 {
    u128_mul_wide_and_div_unsafe(
        lhs: rewards_including_commission,
        rhs: commission.into(),
        div: COMMISSION_DENOMINATOR.into(),
        error: Error::COMMISSION_ISNT_U128
    )
}

// Compute the commission amount of the staker from the pool rewards.
//
// $$ commission_amount = ceil_of_division(rewards_including_commission * commission,
// COMMISSION_DENOMINATOR) $$
pub fn compute_commission_amount_rounded_up(
    rewards_including_commission: u128, commission: u16
) -> u128 {
    u128_mul_wide_and_ceil_div_unsafe(
        lhs: rewards_including_commission,
        rhs: commission.into(),
        div: COMMISSION_DENOMINATOR.into(),
        error: Error::COMMISSION_ISNT_U128
    )
}

pub fn compute_global_index_diff(staking_rewards: u128, total_stake: u128) -> u64 {
    if total_stake.is_zero() {
        return 0;
    }
    let diff = u128_mul_wide_and_div_unsafe(
        lhs: staking_rewards,
        rhs: BASE_VALUE.into(),
        div: total_stake,
        error: Error::GLOBAL_INDEX_DIFF_COMPUTATION_OVERFLOW,
    );
    diff.try_into().expect_with_err(Error::GLOBAL_INDEX_DIFF_NOT_U64)
}

// Compute the rewards from the amount and interest.
//
// $$ rewards = amount * interest / BASE_VALUE $$
pub fn compute_rewards_rounded_down(amount: u128, interest: u64) -> u128 {
    u128_mul_wide_and_div_unsafe(
        lhs: amount, rhs: interest.into(), div: BASE_VALUE.into(), error: Error::REWARDS_ISNT_U128
    )
}

// Compute the rewards from the amount and interest.
//
// $$ rewards = ceil_of_division(amount * interest, BASE_VALUE) $$
pub fn compute_rewards_rounded_up(amount: u128, interest: u64) -> u128 {
    u128_mul_wide_and_ceil_div_unsafe(
        lhs: amount, rhs: interest.into(), div: BASE_VALUE.into(), error: Error::REWARDS_ISNT_U128
    )
}

pub fn ceil_of_division(dividend: u128, divisor: u128) -> u128 {
    (dividend + divisor - 1) / divisor
}

pub fn u256_ceil_of_division(dividend: u256, divisor: u256) -> u256 {
    (dividend + divisor - 1) / divisor
}

// Compute the threshold for requesting funds from L1 Staking Minter.
pub fn compute_threshold(base_mint_amount: u128) -> u128 {
    base_mint_amount / 2
}

pub fn day_of(timestamp: u64) -> u64 {
    timestamp / SECONDS_IN_DAY
}

#[generate_trait]
pub(crate) impl CheckedIERC20DispatcherImpl of CheckedIERC20DispatcherTrait {
    fn checked_transfer_from(
        self: IERC20Dispatcher, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool {
        assert_with_err(amount <= self.balance_of(account: sender), Error::INSUFFICIENT_BALANCE);
        assert_with_err(
            amount <= self.allowance(owner: sender, spender: get_contract_address()),
            Error::INSUFFICIENT_ALLOWANCE
        );
        self.transfer_from(:sender, :recipient, :amount)
    }

    fn checked_transfer(self: IERC20Dispatcher, recipient: ContractAddress, amount: u256) -> bool {
        assert_with_err(
            amount <= self.balance_of(account: get_contract_address()), Error::INSUFFICIENT_BALANCE
        );
        self.transfer(:recipient, :amount)
    }
}

#[cfg(test)]
mod tests {
    use super::{Error, MAX_U64, MAX_U128, BASE_VALUE};
    use super::{
        u64_mul_wide_and_div_unsafe, u64_mul_wide_and_ceil_div_unsafe, u128_mul_wide_and_div_unsafe,
        u128_mul_wide_and_ceil_div_unsafe
    };

    #[test]
    fn u64_mul_wide_and_div_unsafe_test() {
        let num = u64_mul_wide_and_div_unsafe(
            lhs: MAX_U64, rhs: MAX_U64, div: MAX_U64, error: Error::INTEREST_ISNT_U64
        );
        assert!(num == MAX_U64, "MAX_U64*MAX_U64/MAX_U64 calcaulated wrong");
        let max_u33: u64 = 0x1_FFFF_FFFF; // 2**33 -1 
        // The following calculation is (2**33-1)*(2**33+1)/4 == (2**66-1)/4,
        // Which is MAX_U64 (== 2**64-1) when rounded down.
        let num = u64_mul_wide_and_div_unsafe(
            lhs: max_u33, rhs: (max_u33 + 2), div: 4, error: Error::INTEREST_ISNT_U64
        );
        assert!(num == MAX_U64, "MAX_U33*(MAX_U33+2)/4 calcaulated wrong");
    }

    #[test]
    #[should_panic(expected: ("Interest is too large, expected to fit in u64.",))]
    fn u64_mul_wide_and_div_unsafe_test_panic() {
        u64_mul_wide_and_div_unsafe(
            lhs: MAX_U64, rhs: MAX_U64, div: 1, error: Error::INTEREST_ISNT_U64
        );
    }

    #[test]
    fn u64_mul_wide_and_ceil_div_unsafe_test() {
        let num = u64_mul_wide_and_ceil_div_unsafe(
            lhs: MAX_U64, rhs: MAX_U64, div: MAX_U64, error: Error::INTEREST_ISNT_U64
        );
        assert!(num == MAX_U64, "ceil_of_div(MAX_U64*MAX_U64, MAX_U64) calcaulated wrong");
        let num = u64_mul_wide_and_ceil_div_unsafe(
            lhs: BASE_VALUE.into() + 1,
            rhs: 1,
            div: BASE_VALUE.into(),
            error: Error::INTEREST_ISNT_U64
        );
        assert!(num == 2, "ceil_of_division((BASE_VALUE+1)*1, BASE_VALUE) calcaulated wrong");
    }

    #[test]
    #[should_panic(expected: ("Interest is too large, expected to fit in u64.",))]
    fn u64_mul_wide_and_ceil_div_unsafe_test_panic() {
        let max_u33: u64 = 0x1_FFFF_FFFF; // 2**33 -1 
        // The following calculation is ceil((2**33-1)*(2**33+1)/4) == ceil((2**66-1)/4),
        // Which is MAX_U64+1 (== 2**64) when rounded up.
        u64_mul_wide_and_ceil_div_unsafe(
            lhs: max_u33, rhs: (max_u33 + 2), div: 4, error: Error::INTEREST_ISNT_U64
        );
    }

    #[test]
    fn u128_mul_wide_and_div_unsafe_test() {
        let num = u128_mul_wide_and_div_unsafe(
            lhs: MAX_U128, rhs: MAX_U128, div: MAX_U128, error: Error::INTEREST_ISNT_U64
        );
        assert!(num == MAX_U128, "MAX_U128*MAX_U128/MAX_U128 calcaulated wrong");
        let max_u65: u128 = 0x1_FFFF_FFFF_FFFF_FFFF;
        let num = u128_mul_wide_and_div_unsafe(
            lhs: max_u65, rhs: (max_u65 + 2), div: 4, error: Error::INTEREST_ISNT_U64
        );
        assert!(num == MAX_U128, "MAX_U65*(MAX_U65+2)/4 calcaulated wrong");
    }

    #[test]
    #[should_panic(expected: ("Rewards is too large, expected to fit in u128.",))]
    fn u128_mul_wide_and_div_unsafe_test_panic() {
        u128_mul_wide_and_div_unsafe(MAX_U128, MAX_U128, 1, Error::REWARDS_ISNT_U128);
    }

    #[test]
    fn u128_mul_wide_and_ceil_div_unsafe_test() {
        let num = u128_mul_wide_and_ceil_div_unsafe(
            lhs: MAX_U128, rhs: MAX_U128, div: MAX_U128, error: Error::INTEREST_ISNT_U64
        );
        assert!(num == MAX_U128, "ceil_of_div(MAX_U128*MAX_U128, MAX_U128) calcaulated wrong");
        let num = u128_mul_wide_and_ceil_div_unsafe(
            lhs: BASE_VALUE.into() + 1,
            rhs: 1,
            div: BASE_VALUE.into(),
            error: Error::INTEREST_ISNT_U64
        );
        assert!(num == 2, "ceil_of_division((BASE_VALUE+1)*1, BASE_VALUE) calcaulated wrong");
    }

    #[test]
    #[should_panic(expected: ("Interest is too large, expected to fit in u64.",))]
    fn u128_mul_wide_and_ceil_div_unsafe_test_panic() {
        let max_u65: u128 = 0x1_FFFF_FFFF_FFFF_FFFF;
        u128_mul_wide_and_ceil_div_unsafe(
            lhs: max_u65, rhs: (max_u65 + 2), div: 4, error: Error::INTEREST_ISNT_U64
        );
    }
}

