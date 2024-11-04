use core::num::traits::zero::Zero;

// Fixed-point decimal with 2 decimal places.
//
// Example: 0.75 is represented as 75.
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct FixedTwoDecimal {
    value: u8 // Stores number * 100
}

#[generate_trait]
pub impl FixedTwoDecimalImpl of FixedTwoDecimalTrait {
    fn new(value: u8) -> FixedTwoDecimal {
        assert(value <= 100, 'Value must be <= 100');
        FixedTwoDecimal { value }
    }

    fn value(self: @FixedTwoDecimal) -> u8 {
        *self.value
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
}
