use core::iter::Iterator;
use core::iter::IntoIterator;
use core::num::traits::BitSize;
use core::num::traits::zero::Zero;

use contracts_commons::pow_of_two::PowOfTwo;

pub enum BitSetError {}

#[derive(Debug, Drop, PartialEq)]
pub struct BitSet<T> {
    // TODO: Consider eliminate size limitations.
    bit_array: T,
    // Inclusive.
    lower_bound: usize,
    // Exclusive.
    upper_bound: usize,
}

pub trait BitSetTrait<T> {
    fn get(self: @BitSet<T>, index: usize) -> Result<bool, BitSetError>;
    fn set(ref self: BitSet<T>, index: usize, value: bool) -> Result<(), BitSetError>;
    fn count(self: @BitSet<T>) -> usize;
    fn clear(ref self: BitSet<T>);
    fn set_all(ref self: BitSet<T>);
    fn toggle(ref self: BitSet<T>, index: usize) -> Result<(), BitSetError>;
    fn all(self: @BitSet<T>) -> bool;
    fn any(self: @BitSet<T>) -> bool;
    fn none(self: @BitSet<T>) -> bool;
    fn get_true_indices(self: @BitSet<T>) -> Span<usize>;
    fn set_lower_bound(ref self: BitSet<T>, bound: usize) -> Result<(), BitSetError>;
    fn set_upper_bound(ref self: BitSet<T>, bound: usize) -> Result<(), BitSetError>;
    fn is_initialized(self: @BitSet<T>) -> bool;
    fn len(self: @BitSet<T>) -> usize;
}

impl BitSetImpl<T, +Drop<T>> of BitSetTrait<T> {
    fn get(self: @BitSet<T>, index: usize) -> Result<bool, BitSetError> {
        Result::Ok(false)
    }

    fn set(ref self: BitSet<T>, index: usize, value: bool) -> Result<(), BitSetError> {
        Result::Ok(())
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

    fn toggle(ref self: BitSet<T>, index: usize) -> Result<(), BitSetError> {
        Result::Ok(())
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

    fn set_lower_bound(ref self: BitSet<T>, bound: usize) -> Result<(), BitSetError> {
        Result::Ok(())
    }

    fn set_upper_bound(ref self: BitSet<T>, bound: usize) -> Result<(), BitSetError> {
        Result::Ok(())
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
        BitSet { bit_array: self, lower_bound: Zero::zero(), upper_bound: BitSize::<T>::bits(), }
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
    use super::BitSet;

    const TESTED_BIT_ARRAY: u8 = 0b01100001;
    const TESTED_TRUE_INDICES: [usize; 3] = [0, 5, 6];
    const INVALID_INDEX: usize = 8;

    #[test]
    fn test_t_into_bit_set() {
        let bit_set = TESTED_BIT_ARRAY.into();
        let expected = BitSet { bit_array: TESTED_BIT_ARRAY, lower_bound: 0, upper_bound: 8, };
        assert_eq!(bit_set, expected);
    }

    #[test]
    fn test_span_try_into_bit_set() {
        let valid_span = TESTED_TRUE_INDICES.span();
        let bit_set = valid_span.try_into().unwrap();
        let expected = BitSet { bit_array: TESTED_BIT_ARRAY, lower_bound: 0, upper_bound: 8, };
        assert_eq!(bit_set, expected);

        let invalid_span = array![INVALID_INDEX].span();
        let bit_set_option: Option<BitSet<u8>> = invalid_span.try_into();
        assert!(bit_set_option.is_none());
    }
    // TODO(uriel): Restore and change this test once BitSet will implement StorePacking.
// #[test]
// fn test_bit_set_range_store_packing() {
//     let packed: u64 =
//         0b0_000_000_000_000_000_000_000_000_000_001_000_000_000_000_000_000_000_000_000_000_001;
//     let unpacked = BitSetRange { lower_bound: 0b1, upper_bound: 0b10 };
//     assert_eq!(StorePacking::pack(unpacked), packed);
//     assert_eq!(StorePacking::unpack(packed), unpacked);
// }
}
