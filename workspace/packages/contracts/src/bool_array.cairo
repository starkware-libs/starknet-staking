use core::iter::Iterator;
use core::iter::IntoIterator;
use core::num::traits::BitSize;
use core::num::traits::zero::Zero;
use core::ops::AddAssign;
use core::starknet::storage_access::StorePacking;

use contracts_commons::pow_of_two::PowOfTwo;

const MASK_32: u64 = 0b11_111_111_111_111_111_111_111_111_111_111;

#[derive(Copy, Debug, Drop, PartialEq)]
struct BoolArrayRange {
    // Inclusive.
    lower_bound: usize,
    // Exclusive.
    upper_bound: usize,
}

impl BoolArrayRangeStorePacking of StorePacking<BoolArrayRange, u64> {
    fn pack(value: BoolArrayRange) -> u64 {
        let packed = value.lower_bound.into()
            + (value.upper_bound.into()
                * PowOfTwo::<u64>::two_to_the(32).expect('Valid fixed index.'));
        packed
    }

    fn unpack(value: u64) -> BoolArrayRange {
        let lower_bound = value & MASK_32;
        let upper_bound = value / PowOfTwo::<u64>::two_to_the(32).expect('Valid fixed index.');

        BoolArrayRange {
            lower_bound: lower_bound.try_into().expect('Masked by 32 bits.'),
            upper_bound: upper_bound.try_into().expect('Shifted right by 32 bits.'),
        }
    }
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

impl SpanTryIntoBoolArray<
    T, +AddAssign<T, T>, +BitSize<T>, +Copy<T>, +Drop<T>, +Zero<T>, impl TPowOfTwo: PowOfTwo<T>
> of TryInto<Span<usize>, BoolArray<T>> {
    fn try_into(self: Span<usize>) -> Option<BoolArray<T>> {
        let mut bit_array = Zero::<T>::zero();
        let mut span_iter = self.into_iter();
        loop {
            match span_iter.next() {
                Option::Some(index) => {
                    match PowOfTwo::two_to_the(*index) {
                        // In case of invalid index we get an Error from 'PowOfTwo::two_to_the'.
                        Result::Err(_) => { break Option::None; },
                        Result::Ok(val) => bit_array += val,
                    };
                },
                // Iterator was fully consumed, ready to return.
                Option::None => { break Option::Some(bit_array.into()); },
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use core::starknet::storage_access::StorePacking;
    use super::{BoolArray, BoolArrayRange};

    const TESTED_BIT_ARRAY: u8 = 0b01100001;
    const TESTED_TRUE_INDICES: [usize; 3] = [0, 5, 6];
    const INVALID_INDEX: usize = 8;

    #[test]
    fn test_t_into_bool_array() {
        let bool_array = TESTED_BIT_ARRAY.into();
        let expected = BoolArray {
            bit_array: TESTED_BIT_ARRAY, _range: BoolArrayRange { lower_bound: 0, upper_bound: 8 }
        };
        assert_eq!(bool_array, expected);
    }

    #[test]
    fn test_span_try_into_bool_array() {
        let valid_span = TESTED_TRUE_INDICES.span();
        let bool_array = valid_span.try_into().unwrap();
        let expected = BoolArray {
            bit_array: TESTED_BIT_ARRAY, _range: BoolArrayRange { lower_bound: 0, upper_bound: 8 }
        };
        assert_eq!(bool_array, expected);

        let invalid_span = array![INVALID_INDEX].span();
        let bool_array_option: Option<BoolArray<u8>> = invalid_span.try_into();
        assert!(bool_array_option.is_none());
    }

    #[test]
    fn test_bool_array_range_store_packing() {
        let packed: u64 =
            0b0_000_000_000_000_000_000_000_000_000_001_000_000_000_000_000_000_000_000_000_000_001;
        let unpacked = BoolArrayRange { lower_bound: 0b1, upper_bound: 0b10 };
        assert_eq!(StorePacking::pack(unpacked), packed);
        assert_eq!(StorePacking::unpack(packed), unpacked);
    }
}
