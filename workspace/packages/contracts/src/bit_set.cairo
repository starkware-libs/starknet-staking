use core::iter::Iterator;
use core::iter::IntoIterator;
use core::num::traits::BitSize;
use core::num::traits::zero::Zero;
use core::starknet::storage_access::StorePacking;

use contracts_commons::pow_of_two::PowOfTwo;

const MASK_32: u64 = 0b11_111_111_111_111_111_111_111_111_111_111;

#[derive(Copy, Debug, Drop, PartialEq)]
struct BitSetRange {
    // Inclusive.
    lower_bound: usize,
    // Exclusive.
    upper_bound: usize,
}

impl BitSetRangeStorePacking of StorePacking<BitSetRange, u64> {
    fn pack(value: BitSetRange) -> u64 {
        let packed = value.lower_bound.into()
            + (value.upper_bound.into()
                * PowOfTwo::<u64>::two_to_the(32).expect('Valid fixed index.'));
        packed
    }

    fn unpack(value: u64) -> BitSetRange {
        let lower_bound = value & MASK_32;
        let upper_bound = value / PowOfTwo::<u64>::two_to_the(32).expect('Valid fixed index.');

        BitSetRange {
            lower_bound: lower_bound.try_into().expect('Masked by 32 bits.'),
            upper_bound: upper_bound.try_into().expect('Shifted right by 32 bits.'),
        }
    }
}

#[derive(Debug, Drop, PartialEq)]
pub struct BitSet<T> {
    // TODO: Consider eliminate size limitations.
    bit_array: T,
    _range: BitSetRange,
}

pub trait BitSetTrait<T> {
    // TODO: Wrap return types with a 'Result'.
    fn get(self: @BitSet<T>, index: usize) -> bool;
    fn set(ref self: BitSet<T>, index: usize, value: bool);
    fn count(self: @BitSet<T>) -> usize;
    fn clear(ref self: BitSet<T>);
    fn set_all(ref self: BitSet<T>);
    fn toggle(ref self: BitSet<T>, index: usize);
    fn all(self: @BitSet<T>) -> bool;
    fn any(self: @BitSet<T>) -> bool;
    fn none(self: @BitSet<T>) -> bool;
    fn get_true_indices(self: @BitSet<T>) -> Span<usize>;
    fn set_lower_bound(ref self: BitSet<T>, bound: usize);
    fn set_upper_bound(ref self: BitSet<T>, bound: usize);
    fn is_initialized(self: @BitSet<T>) -> bool;
    fn len(self: @BitSet<T>) -> usize;
}

impl BitSetImpl<T, +Drop<T>> of BitSetTrait<T> {
    fn get(self: @BitSet<T>, index: usize) -> bool {
        false
    }

    fn set(ref self: BitSet<T>, index: usize, value: bool) {
        ()
    }

    fn count(self: @BitSet<T>) -> usize {
        0
    }

    fn clear(ref self: BitSet<T>) {
        ()
    }

    fn set_all(ref self: BitSet<T>) {
        ()
    }

    fn toggle(ref self: BitSet<T>, index: usize) {
        ()
    }

    fn all(self: @BitSet<T>) -> bool {
        false
    }

    fn any(self: @BitSet<T>) -> bool {
        false
    }

    fn none(self: @BitSet<T>) -> bool {
        false
    }

    fn get_true_indices(self: @BitSet<T>) -> Span<usize> {
        array![].span()
    }

    fn set_lower_bound(ref self: BitSet<T>, bound: usize) {
        ()
    }

    fn set_upper_bound(ref self: BitSet<T>, bound: usize) {
        ()
    }

    fn is_initialized(self: @BitSet<T>) -> bool {
        false
    }

    fn len(self: @BitSet<T>) -> usize {
        0
    }
}

impl TIntoBitSet<T, +BitSize<T>, +Drop<T>> of Into<T, BitSet<T>> {
    fn into(self: T) -> BitSet<T> {
        BitSet {
            bit_array: self,
            _range: BitSetRange { lower_bound: Zero::zero(), upper_bound: BitSize::<T>::bits() }
        }
    }
}

impl SpanTryIntoBitSet<
    T, +BitOr<T>, +BitSize<T>, +Copy<T>, +Drop<T>, +Zero<T>, impl TPowOfTwo: PowOfTwo<T>
> of TryInto<Span<usize>, BitSet<T>> {
    fn try_into(self: Span<usize>) -> Option<BitSet<T>> {
        let mut bit_array = Zero::<T>::zero();
        let mut span_iter = self.into_iter();
        loop {
            match span_iter.next() {
                Option::Some(index) => {
                    match PowOfTwo::two_to_the(*index) {
                        // In case of invalid index we get an Error from 'PowOfTwo::two_to_the'.
                        Result::Err(_) => { break Option::None; },
                        Result::Ok(val) => bit_array = bit_array | val,
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
    use super::{BitSet, BitSetRange};

    const TESTED_BIT_ARRAY: u8 = 0b01100001;
    const TESTED_TRUE_INDICES: [usize; 3] = [0, 5, 6];
    const INVALID_INDEX: usize = 8;

    #[test]
    fn test_t_into_bit_set() {
        let bit_set = TESTED_BIT_ARRAY.into();
        let expected = BitSet {
            bit_array: TESTED_BIT_ARRAY, _range: BitSetRange { lower_bound: 0, upper_bound: 8 }
        };
        assert_eq!(bit_set, expected);
    }

    #[test]
    fn test_span_try_into_bit_set() {
        let valid_span = TESTED_TRUE_INDICES.span();
        let bit_set = valid_span.try_into().unwrap();
        let expected = BitSet {
            bit_array: TESTED_BIT_ARRAY, _range: BitSetRange { lower_bound: 0, upper_bound: 8 }
        };
        assert_eq!(bit_set, expected);

        let invalid_span = array![INVALID_INDEX].span();
        let bit_set_option: Option<BitSet<u8>> = invalid_span.try_into();
        assert!(bit_set_option.is_none());
    }

    #[test]
    fn test_bit_set_range_store_packing() {
        let packed: u64 =
            0b0_000_000_000_000_000_000_000_000_000_001_000_000_000_000_000_000_000_000_000_000_001;
        let unpacked = BitSetRange { lower_bound: 0b1, upper_bound: 0b10 };
        assert_eq!(StorePacking::pack(unpacked), packed);
        assert_eq!(StorePacking::unpack(packed), unpacked);
    }
}
