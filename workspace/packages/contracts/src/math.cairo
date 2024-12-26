use core::num::traits::WideMul;
use core::num::traits::one::One;
use core::num::traits::zero::Zero;
pub const MAX_U64: u64 = 18446744073709551615;
pub const MAX_U128: u128 = 340282366920938463463374607431768211455;


pub fn have_same_sign(a: i128, b: i128) -> bool {
    (a < 0) == (b < 0)
}

pub fn mul_wide_and_div<
    T,
    impl TWide: WideMul<T, T>,
    +Into<T, TWide::Target>,
    +Zero<T>,
    +Div<TWide::Target>,
    +TryInto<TWide::Target, T>,
    +Drop<T>,
    +Drop<TWide::Target>,
>(
    lhs: T, rhs: T, div: T,
) -> Option<T> {
    let x: TWide::Target = lhs.wide_mul(other: rhs);
    let y: TWide::Target = (x / div.into());
    y.try_into()
}

pub fn mul_wide_and_ceil_div<
    T,
    impl TWide: WideMul<T, T>,
    +Into<T, TWide::Target>,
    +Zero<T>,
    +Div<TWide::Target>,
    +Sub<TWide::Target>,
    +Add<TWide::Target>,
    +One<TWide::Target>,
    +Copy<TWide::Target>,
    +TryInto<TWide::Target, T>,
    +Drop<T>,
    +Drop<TWide::Target>,
>(
    lhs: T, rhs: T, div: T,
) -> Option<T> {
    ceil_of_division(lhs.wide_mul(other: rhs), div.into()).try_into()
}

pub fn ceil_of_division<T, +Sub<T>, +Add<T>, +One<T>, +Div<T>, +Copy<T>, +Drop<T>>(
    dividend: T, divisor: T,
) -> T {
    (dividend + divisor - One::one()) / divisor
}

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

pub(crate) impl AbsImplI8 of Abs<i8, u8> {
    fn abs(self: i8) -> u8 {
        abs(self)
    }
}

pub(crate) impl AbsImplI16 of Abs<i16, u16> {
    fn abs(self: i16) -> u16 {
        abs(self)
    }
}

pub(crate) impl AbsImplI32 of Abs<i32, u32> {
    fn abs(self: i32) -> u32 {
        abs(self)
    }
}

pub impl AbsImplI64 of Abs<i64, u64> {
    fn abs(self: i64) -> u64 {
        abs(self)
    }
}

pub(crate) impl AbsImplI128 of Abs<i128, u128> {
    fn abs(self: i128) -> u128 {
        abs(self)
    }
}

#[derive(Copy, Debug, Drop, Hash, Serde)]
pub struct Fraction {
    numerator: i128,
    denominator: u128,
}

pub trait FractionTrait<N, D> {
    fn new(numerator: N, denominator: D) -> Fraction;
}

pub impl FractionlImpl<
    N, +Into<N, i128>, +Drop<N>, D, +Into<D, u128>, +Drop<D>,
> of FractionTrait<N, D> {
    fn new(numerator: N, denominator: D) -> Fraction {
        /// TODO : consider  reducing a fraction to its simplest form.
        let numerator: i128 = numerator.into();
        let denominator: u128 = denominator.into();
        assert(denominator != 0, 'Denominator must be non-zero');
        Fraction { numerator, denominator }
    }
}

impl FractionNeg of Neg<Fraction> {
    fn neg(a: Fraction) -> Fraction {
        Fraction { numerator: -a.numerator, denominator: a.denominator }
    }
}

impl FractionZero of Zero<Fraction> {
    fn zero() -> Fraction {
        Fraction { numerator: 0, denominator: 1 }
    }

    fn is_zero(self: @Fraction) -> bool {
        *self.numerator == 0
    }

    fn is_non_zero(self: @Fraction) -> bool {
        !self.is_zero()
    }
}

impl FractionOne of One<Fraction> {
    fn one() -> Fraction {
        Fraction { numerator: 1, denominator: 1 }
    }

    fn is_one(self: @Fraction) -> bool {
        let numerator: i128 = *self.numerator;
        let denominator: u128 = *self.denominator;
        if numerator < 0 {
            return false;
        }
        numerator.abs() == denominator
    }
    /// Returns `false` if `self` is equal to the multiplicative identity.
    fn is_non_one(self: @Fraction) -> bool {
        !self.is_one()
    }
}

impl FractionPartialEq of PartialEq<Fraction> {
    fn eq(lhs: @Fraction, rhs: @Fraction) -> bool {
        (lhs <= rhs) && (lhs >= rhs)
    }
}

impl FractionPartialOrd of PartialOrd<Fraction> {
    fn lt(lhs: Fraction, rhs: Fraction) -> bool {
        /// denote lhs as a/b and rhs as c/d
        /// case a <= 0 and c > 0
        if lhs.numerator <= 0 && rhs.numerator > 0 {
            return true;
        }
        /// case a >= 0 and c <= 0
        if lhs.numerator >= 0 && rhs.numerator <= 0 {
            return false;
        }

        // case a < 0 and c = 0
        if lhs.numerator < 0 && rhs.numerator == 0 {
            return true;
        }

        /// from now c != 0 and a != 0, a and c have the same sign.
        /// left = |a| * d
        let mut left: u256 = lhs.numerator.abs().into();
        left = left * rhs.denominator.into();

        /// right = |c| * b
        let mut right: u256 = rhs.numerator.abs().into();
        right = right * lhs.denominator.into();

        /// case a > 0 and c > 0
        if lhs.numerator > 0 && rhs.numerator > 0 {
            return left < right;
        }
        /// The remaining case is a < 0 and c < 0
        left > right
    }
}


#[cfg(test)]
mod tests {
    use core::num::traits::one::One;
    use core::num::traits::zero::Zero;
    use super::Abs;
    use super::{Fraction, FractionTrait};


    use super::{MAX_U128, MAX_U64};
    use super::{mul_wide_and_ceil_div, mul_wide_and_div, wide_abs_diff};
    const TEST_NUM: u64 = 100000000000;

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


    #[test]
    fn u64_mul_wide_and_div_test() {
        let num = mul_wide_and_div(lhs: MAX_U64, rhs: MAX_U64, div: MAX_U64).unwrap();
        assert!(num == MAX_U64, "MAX_U64*MAX_U64/MAX_U64 calcaulated wrong");
        let max_u33: u64 = 0x1_FFFF_FFFF; // 2**33 -1
        // The following calculation is (2**33-1)*(2**33+1)/4 == (2**66-1)/4,
        // Which is MAX_U64 (== 2**64-1) when rounded down.
        let num = mul_wide_and_div(lhs: max_u33, rhs: (max_u33 + 2), div: 4).unwrap();
        assert!(num == MAX_U64, "MAX_U33*(MAX_U33+2)/4 calcaulated wrong");
    }

    #[test]
    #[should_panic(expected: 'Option::unwrap failed.')]
    fn u64_mul_wide_and_div_test_panic() {
        mul_wide_and_div(lhs: MAX_U64, rhs: MAX_U64, div: 1).unwrap();
    }

    #[test]
    fn u64_mul_wide_and_ceil_div_test() {
        let num = mul_wide_and_ceil_div(lhs: MAX_U64, rhs: MAX_U64, div: MAX_U64).unwrap();
        assert!(num == MAX_U64, "ceil_of_div(MAX_U64*MAX_U64, MAX_U64) calcaulated wrong");
        let num: u64 = mul_wide_and_ceil_div(lhs: TEST_NUM.into() + 1, rhs: 1, div: TEST_NUM.into())
            .unwrap();
        assert!(num == 2, "ceil_of_division((TEST_NUM+1)*1, TEST_NUM) calcaulated wrong");
    }

    #[test]
    #[should_panic(expected: 'Option::unwrap failed.')]
    fn u64_mul_wide_and_ceil_div_test_panic() {
        let max_u33: u64 = 0x1_FFFF_FFFF; // 2**33 -1
        // The following calculation is ceil((2**33-1)*(2**33+1)/4) == ceil((2**66-1)/4),
        // Which is MAX_U64+1 (== 2**64) when rounded up.
        mul_wide_and_ceil_div(lhs: max_u33, rhs: (max_u33 + 2), div: 4).unwrap();
    }

    #[test]
    fn u128_mul_wide_and_div_test() {
        let num = mul_wide_and_div(lhs: MAX_U128, rhs: MAX_U128, div: MAX_U128).unwrap();
        assert!(num == MAX_U128, "MAX_U128*MAX_U128/MAX_U128 calcaulated wrong");
        let max_u65: u128 = 0x1_FFFF_FFFF_FFFF_FFFF;
        let num = mul_wide_and_div(lhs: max_u65, rhs: (max_u65 + 2), div: 4).unwrap();
        assert!(num == MAX_U128, "MAX_U65*(MAX_U65+2)/4 calcaulated wrong");
    }

    #[test]
    #[should_panic(expected: 'Option::unwrap failed.')]
    fn u128_mul_wide_and_div_test_panic() {
        mul_wide_and_div(lhs: MAX_U128, rhs: MAX_U128, div: 1).unwrap();
    }

    #[test]
    fn u128_mul_wide_and_ceil_div_test() {
        let num = mul_wide_and_ceil_div(lhs: MAX_U128, rhs: MAX_U128, div: MAX_U128).unwrap();
        assert!(num == MAX_U128, "ceil_of_div(MAX_U128*MAX_U128, MAX_U128) calcaulated wrong");
        let num: u128 = mul_wide_and_ceil_div(
            lhs: TEST_NUM.into() + 1, rhs: 1, div: TEST_NUM.into(),
        )
            .unwrap();
        assert!(num == 2, "ceil_of_division((TEST_NUM+1)*1, TEST_NUM) calcaulated wrong");
    }

    #[test]
    #[should_panic(expected: 'Option::unwrap failed.')]
    fn u128_mul_wide_and_ceil_div_test_panic() {
        let max_u65: u128 = 0x1_FFFF_FFFF_FFFF_FFFF;
        mul_wide_and_ceil_div(lhs: max_u65, rhs: (max_u65 + 2), div: 4).unwrap();
    }


    #[test]
    // This test verifies that the constructor functions correctly with various types of numerators
    // and denominators.
    // It ensures that the constructor does not panic when provided with valid arguments.
    fn fraction_constructor_test() {
        // Signed numerator and unsigned denominator.
        assert_eq!(
            FractionTrait::new(numerator: (-317_i32), denominator: 54_u128),
            FractionTrait::new(numerator: (-634_i32), denominator: 108_u128),
            "Fraction equality failed",
        );
        // Both are unsigned, from different types.
        assert_eq!(
            FractionTrait::new(numerator: 1_i8, denominator: 32_u64),
            FractionTrait::new(numerator: 4_i16, denominator: 128_u128),
            "Fraction equality failed",
        );
        assert_eq!(
            FractionTrait::new(numerator: 5_u8, denominator: 2_u8),
            FractionTrait::new(numerator: 10_u64, denominator: 4_u8),
            "Fraction equality failed",
        );
    }

    #[test]
    fn fraction_neg_test() {
        let f1 = FractionTrait::new(numerator: 1_u8, denominator: 2_u8);
        let f2 = -f1;
        assert!(f2.numerator == -1 && f2.denominator == 2, "Fraction negation failed");
    }


    #[test]
    fn fraction_eq_test() {
        let f1 = FractionTrait::new(numerator: 1_u8, denominator: 2_u8);
        let f2 = FractionTrait::new(numerator: 6_u8, denominator: 12_u8);
        assert!(f1 == f2, "Fraction equality failed");
    }

    #[test]
    fn fraction_zero_test() {
        let f1 = Zero::<Fraction>::zero();
        assert!(f1.numerator == 0 && f1.denominator == 1, "Fraction zero failed");
        assert!(f1.is_zero(), "Fraction is_zero failed");
        let f2 = FractionTrait::new(numerator: 1_u8, denominator: 2_u8);
        assert!(f2.is_non_zero(), "Fraction is_non_zero failed");
    }

    #[test]
    fn fraction_one_test() {
        let f1 = One::<Fraction>::one();
        assert!(f1.numerator == 1 && f1.denominator == 1, "Fraction one failed");
        assert!(f1.is_one(), "Fraction is_one failed");
        let f2 = FractionTrait::new(numerator: 1_u8, denominator: 2_u8);
        assert!(f2.is_non_one(), "Fraction is_non_one failed");
        let f3 = FractionTrait::new(numerator: 30_u8, denominator: 30_u8);
        assert!(f3.is_one(), "Fraction is_one failed");
    }

    #[test]
    #[should_panic(expected: 'Denominator must be non-zero')]
    fn fraction_new_test_panic() {
        FractionTrait::new(numerator: 1_u8, denominator: 0_u8);
    }

    #[test]
    fn fraction_parial_ord_test() {
        let f1 = FractionTrait::new(numerator: 1_u8, denominator: 2_u8);
        let f2 = FractionTrait::new(numerator: 1_u8, denominator: 3_u8);
        assert!(f1 > f2, "Fraction partial ord failed");
        assert!(-f2 > -f1, "Fraction partial ord failed");
        assert!(f1 >= f2, "Fraction partial ord failed");
        assert!(-f2 >= -f1, "Fraction partial ord failed");
        assert!(f2 < f1, "Fraction partial ord failed");
        assert!(-f1 < -f2, "Fraction partial ord failed");
        assert!(f2 <= f1, "Fraction partial ord failed");
        assert!(-f1 <= -f2, "Fraction partial ord failed");
    }
}
