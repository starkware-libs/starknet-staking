use super::errors::{panic_by_err, Error};
use core::integer::u64_wide_mul;

pub fn u64_mul_wide_and_div_unsafe(lhs: u64, rhs: u64, div: u64, error: Error) -> u64 {
    if let Option::Some(res) = (u64_wide_mul(lhs, rhs) / div.into()).try_into() {
        return res;
    }
    panic_by_err(error);
    0
}
