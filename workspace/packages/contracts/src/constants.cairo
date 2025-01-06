use core::num::traits::Bounded;

pub const MAX_U8: u8 = Bounded::<u8>::MAX;
pub const MAX_U16: u16 = Bounded::<u16>::MAX;
pub const MAX_U32: u32 = Bounded::<u32>::MAX;
pub const MAX_U64: u64 = Bounded::<u64>::MAX;
pub const MAX_U128: u128 = Bounded::<u128>::MAX;
pub const MAX_U256: u256 = Bounded::<u256>::MAX;

pub const TWO_POW_8: u16 = 256;
pub const TWO_POW_16: u32 = 65536;
pub const TWO_POW_32: u64 = 4294967296;
pub const TWO_POW_64: u128 = 18446744073709551616;
pub const TWO_POW_128: u256 = 340282366920938463463374607431768211456;

pub const MINUTE: u64 = 60;
pub const HOUR: u64 = 60 * MINUTE;
pub const DAY: u64 = 24 * HOUR;
pub const WEEK: u64 = 7 * DAY;

pub fn NAME() -> ByteArray {
    "NAME"
}
pub fn SYMBOL() -> ByteArray {
    "SYMBOL"
}
