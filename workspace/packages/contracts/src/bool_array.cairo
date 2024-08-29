use core::num::traits::BitSize;
use core::num::traits::zero::Zero;

#[derive(Debug, Drop, PartialEq)]
struct BoolArrayRange {
    // Inclusive.
    lower_bound: usize,
    // Exclusive.
    upper_bound: usize,
}

#[derive(Debug, Drop, PartialEq)]
pub struct BoolArray<T> {
    // TODO: Consider eliminate size limitations.
    bit_array: T,
    _range: BoolArrayRange,
}

pub trait BoolArrayTrait<T> {
    // TODO: Wrap return types with a 'Result'.
    fn get(self: @BoolArray<T>, index: usize) -> bool;
    fn set(ref self: BoolArray<T>, index: usize, value: bool);
    fn count(self: @BoolArray<T>) -> usize;
    fn clear(ref self: BoolArray<T>);
    fn set_all(ref self: BoolArray<T>);
    fn toggle(ref self: BoolArray<T>, index: usize);
    fn all(self: @BoolArray<T>) -> bool;
    fn any(self: @BoolArray<T>) -> bool;
    fn none(self: @BoolArray<T>) -> bool;
    fn get_true_indices(self: @BoolArray<T>) -> Span<usize>;
    fn set_lower_bound(ref self: BoolArray<T>, bound: usize);
    fn set_upper_bound(ref self: BoolArray<T>, bound: usize);
    fn is_initialized(self: @BoolArray<T>) -> bool;
    fn len(self: @BoolArray<T>) -> usize;
}

impl BoolArrayImpl<T, +Drop<T>> of BoolArrayTrait<T> {
    fn get(self: @BoolArray<T>, index: usize) -> bool {
        false
    }

    fn set(ref self: BoolArray<T>, index: usize, value: bool) {
        ()
    }

    fn count(self: @BoolArray<T>) -> usize {
        0
    }

    fn clear(ref self: BoolArray<T>) {
        ()
    }

    fn set_all(ref self: BoolArray<T>) {
        ()
    }

    fn toggle(ref self: BoolArray<T>, index: usize) {
        ()
    }

    fn all(self: @BoolArray<T>) -> bool {
        false
    }

    fn any(self: @BoolArray<T>) -> bool {
        false
    }

    fn none(self: @BoolArray<T>) -> bool {
        false
    }

    fn get_true_indices(self: @BoolArray<T>) -> Span<usize> {
        array![].span()
    }

    fn set_lower_bound(ref self: BoolArray<T>, bound: usize) {
        ()
    }

    fn set_upper_bound(ref self: BoolArray<T>, bound: usize) {
        ()
    }

    fn is_initialized(self: @BoolArray<T>) -> bool {
        false
    }

    fn len(self: @BoolArray<T>) -> usize {
        0
    }
}

impl TIntoBoolArray<T, +BitSize<T>, +Drop<T>> of Into<T, BoolArray<T>> {
    fn into(self: T) -> BoolArray<T> {
        BoolArray {
            bit_array: self,
            _range: BoolArrayRange { lower_bound: Zero::zero(), upper_bound: BitSize::<T>::bits() }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{BoolArray, BoolArrayRange};

    const TESTED_BIT_ARRAY: u8 = 0b01100001;

    #[test]
    fn test_t_into_bool_array() {
        let bool_array = TESTED_BIT_ARRAY.into();
        let expected = BoolArray {
            bit_array: TESTED_BIT_ARRAY, _range: BoolArrayRange { lower_bound: 0, upper_bound: 8 }
        };
        assert_eq!(bool_array, expected);
    }
}
