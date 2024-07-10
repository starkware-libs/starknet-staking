use core::traits::Destruct;
use super::errors::{panic_by_err, Error};
use core::integer::{u64_wide_mul, u128_wide_mul};

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
