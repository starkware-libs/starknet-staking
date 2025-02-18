use core::num::traits::WideMul;
use core::num::traits::one::One;
use core::num::traits::zero::Zero;

pub fn have_same_sign<T, +Zero<T>, +PartialOrd<T>, S, +Zero<S>, +PartialOrd<S>, +Drop<T>, +Drop<S>>(
    a: T, b: S,
) -> bool {
    (a < Zero::<T>::zero()) == (b < Zero::<S>::zero())
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

#[cfg(test)]
mod tests {
    use contracts_commons::constants::{MAX_U128, MAX_U64};
    use super::*;
    const TEST_NUM: u64 = 100000000000;

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
    fn have_same_sign_test() {
        /// Case 1: Both are positive.
        assert!(have_same_sign(1_i64, 2_i64), "both are positive failed");

        /// Case 2: Both are negative.
        assert!(have_same_sign(-1_i64, -2_i64), "both are negative failed");

        /// Case 3: Both are zero.
        assert!(have_same_sign(0_i64, 0_i64), "both are zero failed");

        /// Case 4: One is positive and the other is negative.
        assert!(
            have_same_sign(1_i64, -2_i64) == false,
            "One is positive and the other is negative failed",
        );
        assert!(
            have_same_sign(-2_i64, 1_i64) == false,
            "One is positive and the other is negative failed",
        );

        /// Case 5: One is positive and the other is zero.
        assert!(have_same_sign(1_i64, 0_i64), "One is positive and the other is zero failed");
        assert!(have_same_sign(0_i64, 1_i64), "One is positive and the other is zero failed");

        /// Case 6: One is negative and the other is zero.
        assert!(
            have_same_sign(-1_i64, 0_i64) == false, "One is negative and the other is zero failed",
        );
        assert!(
            have_same_sign(0_i64, -1_i64) == false, "One is negative and the other is zero failed",
        );

        /// Case 7: different types
        assert!(have_same_sign(1_i64, 2_u64), "Different types failed");
        assert!(have_same_sign(1_u64, 2_i64), "Different types failed");
    }
}
