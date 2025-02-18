use contracts_commons::math::abs::Abs;
use core::num::traits::one::One;
use core::num::traits::zero::Zero;

#[derive(Copy, Debug, Drop, Hash, Serde)]
struct Fraction {
    numerator: i128,
    denominator: u128,
}

#[generate_trait]
pub impl FractionlImpl<
    N, D, +Into<N, i128>, +Drop<N>, +Into<D, u128>, +Drop<D>,
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
    use core::num::traits::{One, Zero};
    use super::*;

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
