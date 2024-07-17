use core::{traits::Destruct, integer::{u64_wide_mul, u128_wide_mul}};
use contracts::errors::{panic_by_err, Error};

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
    #[should_panic(expected: ("Staker rewards is too large, expected to fit in u128.",))]
    fn u128_mul_wide_and_div_unsafe_test_panic() {
        u128_mul_wide_and_div_unsafe(MAX_U128, MAX_U128, 1, Error::REWARDS_ISNT_U128);
    }
}

