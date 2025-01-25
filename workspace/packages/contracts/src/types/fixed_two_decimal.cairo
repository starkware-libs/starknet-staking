use core::num::traits::zero::Zero;

// Fixed-point decimal with 2 decimal places.
//
// Example: 0.75 is represented as 75.
#[derive(Copy, Debug, Default, Drop, PartialEq, Serde, starknet::Store)]
pub struct FixedTwoDecimal {
    value: u8 // Stores number * 100
}

const DENOMINATOR: u8 = 100_u8;

#[generate_trait]
pub impl FixedTwoDecimalImpl of FixedTwoDecimalTrait {
    fn new(value: u8) -> FixedTwoDecimal {
        assert(value <= DENOMINATOR, 'Value must be <= 100');
        FixedTwoDecimal { value }
    }

    /// Multiplies the fixed-point value by `other` and divides by DENOMINATOR.
    /// Integer division truncates toward zero to the nearest integer.
    ///
    /// Example: FixedTwoDecimalTrait::new(75).mul(300) == 225
    /// Example: FixedTwoDecimalTrait::new(75).mul(301) == 225
    /// Example: FixedTwoDecimalTrait::new(75).mul(-5) == -3
    fn mul<T, +Mul<T>, +Into<u8, T>, +Div<T>, +Drop<T>>(self: @FixedTwoDecimal, other: T) -> T {
        ((*self.value).into() * other) / DENOMINATOR.into()
    }
}

impl FixedTwoDecimalZero of core::num::traits::Zero<FixedTwoDecimal> {
    fn zero() -> FixedTwoDecimal {
        FixedTwoDecimal { value: 0 }
    }
    fn is_zero(self: @FixedTwoDecimal) -> bool {
        self.value.is_zero()
    }
    fn is_non_zero(self: @FixedTwoDecimal) -> bool {
        self.value.is_non_zero()
    }
}


#[cfg(test)]
mod tests {
    use core::num::traits::zero::Zero;
    use super::{FixedTwoDecimal, FixedTwoDecimalTrait};

    #[test]
    fn test_new() {
        let d = FixedTwoDecimalTrait::new(75);
        assert_eq!(d.value, 75);
    }

    #[test]
    #[should_panic(expected: 'Value must be <= 100')]
    fn test_new_invalid_max() {
        FixedTwoDecimalTrait::new(101);
    }

    #[test]
    fn test_zero() {
        let d: FixedTwoDecimal = Zero::zero();
        assert_eq!(d.value, 0);
    }
    #[test]
    fn test_is_zero() {
        let d: FixedTwoDecimal = Zero::zero();
        assert!(d.is_zero());
        assert!(!d.is_non_zero());
    }
    #[test]
    fn test_is_non_zero() {
        let d: FixedTwoDecimal = FixedTwoDecimalTrait::new(1);
        assert!(d.is_non_zero());
        assert!(!d.is_zero());
    }

    #[test]
    fn test_mul() {
        assert_eq!(FixedTwoDecimalTrait::new(75).mul(300_u128), 225);
        assert_eq!(FixedTwoDecimalTrait::new(75).mul(301_u128), 225);
        assert_eq!(FixedTwoDecimalTrait::new(75).mul(299_u128), 224);
        assert_eq!(FixedTwoDecimalTrait::new(75).mul(-5_i128), -3_i128);
    }
}
