use contracts::BASE_VALUE;
use core::{traits::Destruct, integer::{u64_wide_mul, u128_wide_mul}};
use contracts::errors::{panic_by_err, Error};
use starknet::{ContractAddress, ClassHash, SyscallResultTrait};
use starknet::syscalls::deploy_syscall;
use contracts::staking::Staking::REV_SHARE_DENOMINATOR;

pub const MAX_U64: u64 = 18446744073709551615;
pub const MAX_U128: u128 = 340282366920938463463374607431768211455;

pub fn u64_mul_wide_and_div_unsafe(lhs: u64, rhs: u64, div: u64, error: Error) -> u64 {
    if let Option::Some(res) = (u64_wide_mul(lhs, rhs) / div.into()).try_into() {
        return res;
    }
    panic_by_err(error);
    0
}

pub fn u128_mul_wide_and_div_unsafe(lhs: u128, rhs: u128, div: u128, error: Error) -> u128 {
    let (high, low) = u128_wide_mul(lhs, rhs);
    let x = u256 { low, high };
    if let Option::Some(res) = (x / div.into()).try_into() {
        return res;
    }
    panic_by_err(error);
    0
}

pub fn deploy_delegation_pool_contract(
    class_hash: ClassHash,
    contract_address_salt: felt252,
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    token_address: ContractAddress,
    rev_share: u16
) -> Option<ContractAddress> {
    let mut calldata = ArrayTrait::new();
    staker_address.serialize(ref calldata);
    staking_contract.serialize(ref calldata);
    token_address.serialize(ref calldata);
    rev_share.serialize(ref calldata);
    let (pool_address, _) = deploy_syscall(
        :class_hash, :contract_address_salt, calldata: calldata.span(), deploy_from_zero: false
    )
        .unwrap_syscall();
    Option::Some(pool_address)
}

// Compute the commission of the staker from the pool rewards.
//
// $$ commission = rewards * rev_share / REV_SHARE_DENOMINATOR $$
pub fn compute_commission(rewards: u128, rev_share: u16) -> u128 {
    u128_mul_wide_and_div_unsafe(
        lhs: rewards,
        rhs: rev_share.into(),
        div: REV_SHARE_DENOMINATOR.into(),
        error: Error::COMMISSION_ISNT_U128
    )
}

// Compute the rewards from the amount and interest.
//
// $$ rewards = amount * interest / BASE_VALUE $$
pub fn compute_rewards(amount: u128, interest: u64) -> u128 {
    u128_mul_wide_and_div_unsafe(
        lhs: amount, rhs: interest.into(), div: BASE_VALUE.into(), error: Error::REWARDS_ISNT_U128
    )
}


#[cfg(test)]
mod tests {
    use super::{Error, MAX_U64, MAX_U128};
    use super::{u64_mul_wide_and_div_unsafe, u128_mul_wide_and_div_unsafe};


    #[test]
    fn u64_mul_wide_and_div_unsafe_test() {
        let num = u64_mul_wide_and_div_unsafe(MAX_U64, MAX_U64, MAX_U64, Error::INTEREST_ISNT_U64);
        assert!(num == MAX_U64, "MAX_U64*MAX_U64/MAX_U64 calcaulated wrong")
    }

    #[test]
    #[should_panic(expected: ("Interest is too large, expected to fit in u64.",))]
    fn u64_mul_wide_and_div_unsafe_test_panic() {
        u64_mul_wide_and_div_unsafe(MAX_U64, MAX_U64, 1, Error::INTEREST_ISNT_U64);
    }

    #[test]
    fn u128_mul_wide_and_div_unsafe_test() {
        let num = u128_mul_wide_and_div_unsafe(
            MAX_U128, MAX_U128, MAX_U128, Error::INTEREST_ISNT_U64
        );
        assert!(num == MAX_U128, "MAX_U128*MAX_U128/MAX_U128 calcaulated wrong")
    }

    #[test]
    #[should_panic(expected: ("Rewards is too large, expected to fit in u128.",))]
    fn u128_mul_wide_and_div_unsafe_test_panic() {
        u128_mul_wide_and_div_unsafe(MAX_U128, MAX_U128, 1, Error::REWARDS_ISNT_U128);
    }
}

