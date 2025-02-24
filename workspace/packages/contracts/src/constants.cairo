use core::num::traits::Bounded;

pub const MAX_U8: u8 = Bounded::<u8>::MAX;
pub const MAX_U16: u16 = Bounded::<u16>::MAX;
pub const MAX_U32: u32 = Bounded::<u32>::MAX;
pub const MAX_U64: u64 = Bounded::<u64>::MAX;
pub const MAX_U128: u128 = Bounded::<u128>::MAX;
pub const MAX_U256: u256 = Bounded::<u256>::MAX;

pub const TWO_POW_8: u16 = 0x100;
pub const TWO_POW_16: u32 = 0x10000;
pub const TWO_POW_32: u64 = 0x100000000;
pub const TWO_POW_40: u64 = 0x10000000000;
pub const TWO_POW_64: u128 = 0x10000000000000000;
pub const TWO_POW_128: u256 = 0x100000000000000000000000000000000;

pub const TEN_POW_3: u16 = 1_000;
pub const TEN_POW_6: u32 = 1_000_000;
pub const TEN_POW_9: u32 = 1_000_000_000;
pub const TEN_POW_12: u64 = 1_000_000_000_000;
pub const TEN_POW_15: u64 = 1_000_000_000_000_000;
pub const TEN_POW_18: u64 = 1_000_000_000_000_000_000;

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
