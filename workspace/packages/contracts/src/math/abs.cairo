use core::num::traits::zero::Zero;

/// Returns `|a - b|`.
pub fn wide_abs_diff<
    T,
    impl TAbs: AbsDiff<T>,
    +PartialOrd<T>,
    +Drop<T>,
    +Drop<TAbs::Mid>,
    +Copy<T>,
    +Into<T, TAbs::Mid>,
    +Sub<TAbs::Mid>,
    +TryInto<TAbs::Mid, TAbs::Target>,
>(
    a: T, b: T,
) -> TAbs::Target {
    if a > b {
        let mid: TAbs::Mid = (a.into() - b.into());
        mid.try_into().unwrap()
    } else {
        let mid: TAbs::Mid = (b.into() - a.into());
        mid.try_into().unwrap()
    }
}

pub trait AbsDiff<T> {
    /// The type of the result of subtraction.
    type Mid;
    type Target;
}

impl AbsDiffI8 of AbsDiff<i8> {
    type Mid = i16;
    type Target = u16;
}

impl AbsDiffI16 of AbsDiff<i16> {
    type Mid = i32;
    type Target = u32;
}

impl AbsDiffI32 of AbsDiff<i32> {
    type Mid = i64;
    type Target = u64;
}

impl AbsDiffI64 of AbsDiff<i64> {
    type Mid = i128;
    type Target = u128;
}

impl AbsDiffU8 of AbsDiff<u8> {
    type Mid = u16;
    type Target = u16;
}

impl AbsDiffU16 of AbsDiff<u16> {
    type Mid = u32;
    type Target = u32;
}

impl AbsDiffU32 of AbsDiff<u32> {
    type Mid = u64;
    type Target = u64;
}

impl AbsDiffU64 of AbsDiff<u64> {
    type Mid = u128;
    type Target = u128;
}

impl AbsDiffU128 of AbsDiff<u128> {
    type Mid = u256;
    type Target = u256;
}


/// Returns the absolute value of a number.
fn abs<T, +PartialOrd<T>, +Neg<T>, +Drop<T>, +Copy<T>, +Zero<T>, S, +TryInto<T, S>>(a: T) -> S {
    let res = if a > Zero::<T>::zero() {
        a
    } else {
        -a
    };
    res.try_into().unwrap()
}

pub trait Abs<T, S> {
    /// Returns the absolute value of a number.
    fn abs(self: T) -> S;
}

impl AbsImplI8 of Abs<i8, u8> {
    fn abs(self: i8) -> u8 {
        abs(self)
    }
}

impl AbsImplI16 of Abs<i16, u16> {
    fn abs(self: i16) -> u16 {
        abs(self)
    }
}

impl AbsImplI32 of Abs<i32, u32> {
    fn abs(self: i32) -> u32 {
        abs(self)
    }
}

impl AbsImplI64 of Abs<i64, u64> {
    fn abs(self: i64) -> u64 {
        abs(self)
    }
}

impl AbsImplI128 of Abs<i128, u128> {
    fn abs(self: i128) -> u128 {
        abs(self)
    }
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_abs_i8() {
        assert_eq!(1_i8.abs(), 1_u8);
        assert_eq!((-1_i8).abs(), 1_u8);
    }

    #[test]
    fn test_abs_i16() {
        assert_eq!(1_i16.abs(), 1_u16);
        assert_eq!((-1_i16).abs(), 1_u16);
    }

    #[test]
    fn test_abs_i32() {
        assert_eq!((1_i32).abs(), 1_u32);
        assert_eq!((-1_i32).abs(), 1_u32);
    }

    #[test]
    fn test_abs_i64() {
        assert_eq!((1_i64).abs(), 1_u64);
        assert_eq!((-1_i64).abs(), 1_u64);
    }

    #[test]
    fn test_abs_i128() {
        assert_eq!(1_i128.abs(), 1_u128);
        assert_eq!((-1_i128).abs(), 1_u128);
    }

    #[test]
    fn test_wide_abs_diff_i8() {
        assert_eq!(wide_abs_diff(-1_i8, 1_i8), 2_u16);
        assert_eq!(wide_abs_diff(-1_i8, -1_i8), 0_u16);
        assert_eq!(wide_abs_diff(1_i8, 1_i8), 0_u16);
    }

    #[test]
    fn test_wide_abs_diff_i16() {
        assert_eq!(wide_abs_diff(-1_i16, 1_i16), 2_u32);
        assert_eq!(wide_abs_diff(-1_i16, -1_i16), 0_u32);
        assert_eq!(wide_abs_diff(1_i16, 1_i16), 0_u32);
    }

    #[test]
    fn test_wide_abs_diff_i32() {
        assert_eq!(wide_abs_diff(-1_i32, 1_i32), 2_u64);
        assert_eq!(wide_abs_diff(-1_i32, -1_i32), 0_u64);
        assert_eq!(wide_abs_diff(1_i32, 1_i32), 0_u64);
    }

    #[test]
    fn test_wide_abs_diff_i64() {
        assert_eq!(wide_abs_diff(-1_i64, 1_i64), 2_u128);
        assert_eq!(wide_abs_diff(-1_i64, -1_i64), 0_u128);
        assert_eq!(wide_abs_diff(1_i64, 1_i64), 0_u128);
    }

    #[test]
    fn test_wide_abs_diff_u8() {
        assert_eq!(wide_abs_diff(1_u8, 1_u8), 0_u16);
        assert_eq!(wide_abs_diff(2_u8, 1_u8), 1_u16);
    }

    #[test]
    fn test_wide_abs_diff_u16() {
        assert_eq!(wide_abs_diff(1_u16, 1_u16), 0_u32);
        assert_eq!(wide_abs_diff(2_u16, 1_u16), 1_u32);
    }

    #[test]
    fn test_wide_abs_diff_u32() {
        assert_eq!(wide_abs_diff(1_u32, 1_u32), 0_u64);
        assert_eq!(wide_abs_diff(2_u32, 1_u32), 1_u64);
    }

    #[test]
    fn test_wide_abs_diff_u64() {
        assert_eq!(wide_abs_diff(1_u64, 1_u64), 0_u128);
        assert_eq!(wide_abs_diff(2_u64, 1_u64), 1_u128);
    }

    #[test]
    fn test_wide_abs_diff_u128() {
        assert_eq!(wide_abs_diff(1_u128, 1_u128), 0_u256);
        assert_eq!(wide_abs_diff(2_u128, 1_u128), 1_u256);
    }
}
