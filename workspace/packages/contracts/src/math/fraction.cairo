use contracts_commons::math::abs::Abs;
use core::num::traits::{One, WideMul, Zero};

#[derive(Copy, Debug, Drop, Hash, Serde)]
struct Fraction<N, D> {
    numerator: N,
    denominator: D,
}

#[generate_trait]
pub impl FractionImpl<
    N, D, +Drop<N>, +Drop<D>, +Zero<D>, +Copy<N>, +Copy<D>,
> of FractionTrait<N, D> {
    fn new<N1, D1, +Into<N1, N>, +Into<D1, D>, +Drop<D1>>(
        numerator: N1, denominator: D1,
    ) -> Fraction<N, D> {
        /// TODO : consider  reducing a fraction to its simplest form.
        let numerator = numerator.into();
        let denominator = denominator.into();
        assert(denominator.is_non_zero(), 'Denominator must be non-zero');
        Fraction { numerator, denominator }
    }

    fn numerator(self: @Fraction<N, D>) -> N {
        *self.numerator
    }

    fn denominator(self: @Fraction<N, D>) -> D {
        *self.denominator
    }
}

impl FractionNegI128U128 of Neg<Fraction<i128, u128>> {
    fn neg(a: Fraction<i128, u128>) -> Fraction<i128, u128> {
        Fraction { numerator: -a.numerator, denominator: a.denominator }
    }
}

impl FractionZeroI128U128 of Zero<Fraction<i128, u128>> {
    fn zero() -> Fraction<i128, u128> {
        Fraction { numerator: 0, denominator: 1 }
    }

    fn is_zero(self: @Fraction<i128, u128>) -> bool {
        *self.numerator == 0
    }

    fn is_non_zero(self: @Fraction<i128, u128>) -> bool {
        !self.is_zero()
    }
}

impl FractionOneI128U128 of One<Fraction<i128, u128>> {
    fn one() -> Fraction<i128, u128> {
        Fraction { numerator: 1, denominator: 1 }
    }

    fn is_one(self: @Fraction<i128, u128>) -> bool {
        let numerator: i128 = *self.numerator;
        let denominator: u128 = *self.denominator;
        if numerator < 0 {
            return false;
        }
        numerator.abs() == denominator
    }
    /// Returns `false` if `self` is equal to the multiplicative identity.
    fn is_non_one(self: @Fraction<i128, u128>) -> bool {
        !self.is_one()
    }
}

impl FractionPartialEqI128U128 of PartialEq<Fraction<i128, u128>> {
    fn eq(lhs: @Fraction<i128, u128>, rhs: @Fraction<i128, u128>) -> bool {
        (lhs <= rhs) && (lhs >= rhs)
    }
}

impl FractionPartialOrdI128U128 of PartialOrd<Fraction<i128, u128>> {
    fn lt(lhs: Fraction<i128, u128>, rhs: Fraction<i128, u128>) -> bool {
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

impl FractionWideMul<
    N,
    D,
    impl NWideMul: WideMul<N, N>,
    impl DWideMul: WideMul<D, D>,
    +Drop<NWideMul::Target>,
    +Drop<D>,
> of WideMul<Fraction<N, D>, Fraction<N, D>> {
    type Target = Fraction<NWideMul::Target, DWideMul::Target>;
    fn wide_mul(self: Fraction<N, D>, other: Fraction<N, D>) -> Self::Target {
        let numerator: NWideMul::Target = self.numerator.wide_mul(other.numerator);
        let denominator: DWideMul::Target = self.denominator.wide_mul(other.denominator);
        Fraction { numerator, denominator }
    }
}

impl FractionTraitI128U128 = FractionImpl<i128, u128>;

#[cfg(test)]
mod tests {
    use core::num::traits::{One, Zero};
    use super::*;

    #[test]
    // This test verifies that the constructor functions correctly with various types of numerators
    // and denominators.
    // It ensures that the constructor does not panic when provided with valid arguments.
    fn fraction_constructor_test() {
        // Signed numerator and unsigned denominator.
        assert_eq!(
            FractionTraitI128U128::new(numerator: (-317_i32), denominator: 54_u128),
            FractionTraitI128U128::new(numerator: (-634_i32), denominator: 108_u128),
            "Fraction equality failed",
        );
        // Both are unsigned, from different types.
        assert_eq!(
            FractionTraitI128U128::new(numerator: 1_i8, denominator: 32_u64),
            FractionTraitI128U128::new(numerator: 4_i16, denominator: 128_u128),
            "Fraction equality failed",
        );
        assert_eq!(
            FractionTraitI128U128::new(numerator: 5_u8, denominator: 2_u8),
            FractionTraitI128U128::new(numerator: 10_u64, denominator: 4_u8),
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
        FractionTraitI128U128::new(numerator: 1_u8, denominator: 0_u8);
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

    #[test]
    fn fraction_wide_mul_test() {
        let f1 = FractionTrait::<u8, u8>::new(numerator: 1_u8, denominator: 2_u8);
        let f2 = FractionTrait::new(numerator: 1_u8, denominator: 3_u8);
        let f3: Fraction<u16, u16> = f1.wide_mul(f2);
        assert!(f3.numerator == 1_u16 && f3.denominator == 6_u16, "Fraction wide mul failed");

        let f1 = FractionTrait::<u128, u128>::new(numerator: 1_u8, denominator: 2_u8);
        let f2 = FractionTrait::new(numerator: 1_u8, denominator: 3_u8);
        let f3: Fraction<u256, u256> = f1.wide_mul(f2);
        assert!(f3.numerator == 1_u256 && f3.denominator == 6_u256, "Fraction wide mul failed");

        let f1 = FractionTrait::<i8, u8>::new(numerator: -1_i8, denominator: 2_u8);
        let f2 = FractionTrait::new(numerator: 1_i8, denominator: 3_u8);
        let f3: Fraction<i16, u16> = f1.wide_mul(f2);
        assert!(f3.numerator == -1_i16 && f3.denominator == 6_u16, "Fraction wide mul failed");
    }

    #[test]
    fn fraction_numerator_test() {
        let f: Fraction<u8, u8> = FractionTrait::new(numerator: 1_u8, denominator: 2_u8);
        assert_eq!(f.numerator(), 1_u8);
    }

    #[test]
    fn fraction_denominator_test() {
        let f: Fraction<u8, u8> = FractionTrait::new(numerator: 1_u8, denominator: 2_u8);
        assert_eq!(f.denominator(), 2_u8);
    }
}
