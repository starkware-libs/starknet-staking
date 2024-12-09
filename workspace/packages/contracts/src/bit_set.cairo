use contracts_commons::bit_mask::{BitMask, PowOfTwo};
use core::iter::IntoIterator;
use core::iter::Iterator;
use core::num::traits::zero::Zero;
use core::num::traits::{BitSize, Bounded};
use core::starknet::storage_access::StorePacking;

pub type BitSetU8 = BitSet<u8>;
pub type BitSetU16 = BitSet<u16>;
pub type BitSetU32 = BitSet<u32>;
pub type BitSetU64 = BitSet<u64>;

#[derive(Debug, Drop, PartialEq)]
pub enum BitSetError {
    IndexOutOfBounds,
    InvalidBound,
}

#[derive(Debug, Drop, PartialEq)]
struct BitSet<T> {
    // TODO: Consider eliminate size limitations.
    bit_array: T,
    // Inclusive.
    lower_bound: usize,
    // Exclusive.
    upper_bound: usize,
}

impl BitSetStorePacking<
    T, +Into<T, u128>, +TryInto<u128, T>, +Drop<T>, +BitSize<T>, +Bounded<T>,
> of StorePacking<BitSet<T>, u128> {
    fn pack(value: BitSet<T>) -> u128 {
        let shift_64 = PowOfTwo::<u128>::two_to_the(64).expect('Valid fixed index.');
        let shift_96 = PowOfTwo::<u128>::two_to_the(96).expect('Valid fixed index.');

        let packed = value.bit_array.into()
            + value.lower_bound.into() * shift_64
            + value.upper_bound.into() * shift_96;
        packed
    }

    fn unpack(value: u128) -> BitSet<T> {
        let mask_t = Bounded::<T>::MAX.into();
        let bit_array = (value & mask_t).try_into().expect('Masked by T\'s bit-size bits.');

        let mask_32 = Bounded::<u32>::MAX.into();
        let shift_64 = PowOfTwo::<u128>::two_to_the(64).expect('Valid fixed index.');
        let shift_96 = PowOfTwo::<u128>::two_to_the(96).expect('Valid fixed index.');
        let lower_bound = ((value / shift_64) & mask_32).try_into().expect('Masked by 32 bits.');
        let upper_bound = ((value / shift_96) & mask_32).try_into().expect('Masked by 32 bits.');

        BitSet { bit_array, lower_bound, upper_bound }
    }
}

#[generate_trait]
impl BitSetInternalImpl<T> of BitSetInternalTrait<T> {
    fn _check_in_bounds(self: @BitSet<T>, index: usize) -> Result<(), BitSetError> {
        if index < *self.lower_bound || index >= *self.upper_bound {
            return Result::Err(BitSetError::IndexOutOfBounds);
        }
        Result::Ok(())
    }
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
    fn get_set_bits_indices(self: @BitSet<T>) -> Span<usize>;
    fn set_lower_bound(ref self: BitSet<T>, bound: usize) -> Result<(), BitSetError>;
    fn set_upper_bound(ref self: BitSet<T>, bound: usize) -> Result<(), BitSetError>;
    fn len(self: @BitSet<T>) -> usize;
}

impl BitSetImpl<
    T,
    +BitAnd<T>,
    +BitMask<T>,
    +BitOr<T>,
    +BitSize<T>,
    +BitXor<T>,
    +Bounded<T>,
    +Copy<T>,
    +Drop<T>,
    +PartialEq<T>,
    +Zero<T>,
> of BitSetTrait<T> {
    fn get(self: @BitSet<T>, index: usize) -> Result<bool, BitSetError> {
        self._check_in_bounds(index)?;
        // Get the bit by applying bitwise AND with the mask.
        let mask = BitMask::<T>::bit_mask(index).expect('Index should be bounded.');
        Result::Ok(*self.bit_array & mask != Zero::zero())
    }

    fn set(ref self: BitSet<T>, index: usize, value: bool) -> Result<(), BitSetError> {
        @self._check_in_bounds(index)?;
        if value {
            // Set the bit by applying bitwise OR with the mask.
            let mask = BitMask::<T>::bit_mask(index).expect('Index should be bounded.');
            self.bit_array = self.bit_array | mask;
        } else {
            // Clear the bit by applying bitwise AND with the inverse mask.
            let inverse_mask = BitMask::<T>::inverse_bit_mask(index)
                .expect('Index should be bounded.');
            self.bit_array = self.bit_array & inverse_mask;
        }
        Result::Ok(())
    }

    // TODO: Consider a better implementation
    fn count(self: @BitSet<T>) -> usize {
        let mut count = 0;
        let mut index = *self.lower_bound;
        while index < *self.upper_bound {
            let mask = BitMask::<T>::bit_mask(index).expect('Index should be bounded.');
            if *self.bit_array & mask != Zero::zero() {
                count += 1;
            }
            index += 1;
        };
        count
    }

    fn clear(ref self: BitSet<T>) {
        self.bit_array = Zero::zero();
    }

    fn set_all(ref self: BitSet<T>) {
        self.bit_array = Bounded::MAX;
    }

    fn toggle(ref self: BitSet<T>, index: usize) -> Result<(), BitSetError> {
        @self._check_in_bounds(index)?;
        // Toggle the bit by applying bitwise XOR with the mask.
        let mask = BitMask::<T>::bit_mask(index).expect('Index should be bounded.');
        self.bit_array = self.bit_array ^ mask;
        Result::Ok(())
    }

    // TODO: Consider a better implementation
    fn all(self: @BitSet<T>) -> bool {
        self.count() == *self.upper_bound - *self.lower_bound
    }

    // TODO: Consider a better implementation
    fn any(self: @BitSet<T>) -> bool {
        self.count() > 0
    }

    // TODO: Consider a better implementation
    fn none(self: @BitSet<T>) -> bool {
        self.count() == 0
    }

    fn get_set_bits_indices(self: @BitSet<T>) -> Span<usize> {
        let mut indices = array![];
        let mut index = *self.lower_bound;
        while index < *self.upper_bound {
            let mask = BitMask::<T>::bit_mask(index).expect('Index should be bounded.');
            if *self.bit_array & mask != Zero::zero() {
                indices.append(index);
            }
            index += 1;
        };
        indices.span()
    }

    fn set_lower_bound(ref self: BitSet<T>, bound: usize) -> Result<(), BitSetError> {
        if bound >= self.upper_bound {
            return Result::Err(BitSetError::InvalidBound);
        }
        self.lower_bound = bound;
        Result::Ok(())
    }

    fn set_upper_bound(ref self: BitSet<T>, bound: usize) -> Result<(), BitSetError> {
        if bound <= self.lower_bound || bound > BitSize::<T>::bits() {
            return Result::Err(BitSetError::InvalidBound);
        }
        self.upper_bound = bound;
        Result::Ok(())
    }

    fn len(self: @BitSet<T>) -> usize {
        *self.upper_bound - *self.lower_bound
    }
}

impl TIntoBitSet<T, +BitSize<T>, +Drop<T>> of Into<T, BitSet<T>> {
    fn into(self: T) -> BitSet<T> {
        BitSet { bit_array: self, lower_bound: Zero::zero(), upper_bound: BitSize::<T>::bits() }
    }
}

impl SpanTryIntoBitSet<
    T, +BitOr<T>, +BitSize<T>, +Copy<T>, +Drop<T>, +Zero<T>, impl TPowOfTwo: PowOfTwo<T>,
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
    use core::num::traits::Bounded;
    use core::starknet::storage_access::StorePacking;
    use super::{BitSet, BitSetError, BitSetTrait};

    const TESTED_BIT_ARRAY: u8 = 0b01100001;
    const TESTED_TRUE_INDICES: [usize; 3] = [0, 5, 6];
    const INVALID_INDEX: usize = 8;

    #[test]
    fn test_t_into_bit_set() {
        let bit_set = TESTED_BIT_ARRAY.into();
        let expected = BitSet { bit_array: TESTED_BIT_ARRAY, lower_bound: 0, upper_bound: 8 };
        assert_eq!(bit_set, expected);
    }

    #[test]
    fn test_span_try_into_bit_set() {
        let valid_span = TESTED_TRUE_INDICES.span();
        let bit_set = valid_span.try_into().unwrap();
        let expected = BitSet { bit_array: TESTED_BIT_ARRAY, lower_bound: 0, upper_bound: 8 };
        assert_eq!(bit_set, expected);

        let invalid_span = array![INVALID_INDEX].span();
        let bit_set_option: Option<BitSet<u8>> = invalid_span.try_into();
        assert!(bit_set_option.is_none());
    }

    #[test]
    fn test_bit_set_store_packing() {
        let packed: u128 =
            0b00_000_000_000_000_000_000_000_000_000_010_000_000_000_000_000_000_000_000_000_000_010_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_110;
        // The type of bit_array field does not change the fact that it is packed into the 64
        // lower bits, so the packed version is the same for the _u8, _u16, _u32, _u64 suffixes.
        let unpacked = BitSet { bit_array: 0b110_u8, lower_bound: 0b1, upper_bound: 0b10 };
        assert_eq!(StorePacking::unpack(packed), unpacked);
        assert_eq!(StorePacking::pack(unpacked), packed);
    }

    #[test]
    fn test_get_set_bits_indices() {
        let bit_set: BitSet<u8> = TESTED_TRUE_INDICES.span().try_into().unwrap();
        assert_eq!(bit_set.get_set_bits_indices(), TESTED_TRUE_INDICES.span());
    }

    #[test]
    fn test_get() {
        let bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert!(bit_set.get(0).unwrap());
        assert!(!bit_set.get(1).unwrap());
    }

    #[test]
    fn test_get_out_of_bounds() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert_eq!(bit_set.get(8), Result::Err(BitSetError::IndexOutOfBounds));
        assert_eq!(bit_set.get(9), Result::Err(BitSetError::IndexOutOfBounds));

        bit_set.set_lower_bound(1).unwrap();
        assert_eq!(bit_set.get(0), Result::Err(BitSetError::IndexOutOfBounds));
    }

    #[test]
    fn test_set() {
        let mut bit_set: BitSet<u8> = 0_u8.into();

        bit_set.set(1, true).unwrap();
        let expected = array![1].span().try_into().unwrap();
        assert_eq!(bit_set, expected);

        bit_set.set(1, true).unwrap();
        // assert nothing changed (1 -> 1).
        assert_eq!(bit_set, expected);

        bit_set.set(1, false).unwrap();
        let expected = array![].span().try_into().unwrap();
        assert_eq!(bit_set, expected);

        bit_set.set(1, false).unwrap();
        // assert nothing changed (0 -> 0).
        assert_eq!(bit_set, expected);
    }

    #[test]
    fn test_set_out_of_bounds() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert_eq!(bit_set.set(8, true), Result::Err(BitSetError::IndexOutOfBounds));
        assert_eq!(bit_set.set(9, true), Result::Err(BitSetError::IndexOutOfBounds));

        bit_set.set_lower_bound(1).unwrap();
        assert_eq!(bit_set.set(0, true), Result::Err(BitSetError::IndexOutOfBounds));
    }

    #[test]
    fn test_toggle() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        bit_set.toggle(0).unwrap();
        assert!(!bit_set.get(0).unwrap());
        bit_set.toggle(0).unwrap();
        assert!(bit_set.get(0).unwrap());
    }

    #[test]
    fn test_toggle_out_of_bounds() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert_eq!(bit_set.toggle(8), Result::Err(BitSetError::IndexOutOfBounds));
        assert_eq!(bit_set.toggle(9), Result::Err(BitSetError::IndexOutOfBounds));

        bit_set.set_lower_bound(1).unwrap();
        assert_eq!(bit_set.toggle(0), Result::Err(BitSetError::IndexOutOfBounds));
    }

    #[test]
    fn test_set_lower_bound() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert!(bit_set.get(0).is_ok());
        bit_set.set_lower_bound(1).unwrap();
        assert_eq!(bit_set.get(0), Result::Err(BitSetError::IndexOutOfBounds));
        assert!(bit_set.get(1).is_ok());

        assert_eq!(bit_set.set_lower_bound(8), Result::Err(BitSetError::InvalidBound));
        assert_eq!(bit_set.set_lower_bound(9), Result::Err(BitSetError::InvalidBound));
    }

    #[test]
    fn test_set_upper_bound() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert!(bit_set.get(4).is_ok());
        bit_set.set_upper_bound(4).unwrap();
        assert_eq!(bit_set.get(4), Result::Err(BitSetError::IndexOutOfBounds));
        assert_eq!(bit_set.get(5), Result::Err(BitSetError::IndexOutOfBounds));
        assert!(bit_set.get(3).is_ok());

        assert_eq!(bit_set.set_upper_bound(9), Result::Err(BitSetError::InvalidBound));
        bit_set.set_lower_bound(1).unwrap();
        assert_eq!(bit_set.set_upper_bound(0), Result::Err(BitSetError::InvalidBound));
    }

    #[test]
    fn test_clear() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert!(bit_set.get(0).unwrap());
        assert!(bit_set.get(5).unwrap());
        assert!(bit_set.get(6).unwrap());
        bit_set.clear();
        assert!(!bit_set.get(0).unwrap());
        assert!(!bit_set.get(5).unwrap());
        assert!(!bit_set.get(6).unwrap());
    }

    #[test]
    fn test_set_all() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert!(!bit_set.get(1).unwrap());
        assert!(!bit_set.get(2).unwrap());
        assert!(!bit_set.get(3).unwrap());
        assert!(!bit_set.get(4).unwrap());
        assert!(!bit_set.get(7).unwrap());
        bit_set.set_all();
        assert!(bit_set.get(1).unwrap());
        assert!(bit_set.get(2).unwrap());
        assert!(bit_set.get(3).unwrap());
        assert!(bit_set.get(4).unwrap());
        assert!(bit_set.get(7).unwrap());
    }

    #[test]
    fn test_count() {
        let bit_set: BitSet<u8> = 0_u8.into();
        assert_eq!(bit_set.count(), 0);

        let bit_set: BitSet<u8> = Bounded::<u8>::MAX.into();
        assert_eq!(bit_set.count(), 8);

        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert_eq!(bit_set.count(), 3);
        bit_set.set_lower_bound(1).unwrap();
        assert_eq!(bit_set.count(), 2);
        bit_set.set_upper_bound(6).unwrap();
        assert_eq!(bit_set.count(), 1);
    }

    #[test]
    fn test_all() {
        let bit_set: BitSet<u8> = 0_u8.into();
        assert!(!bit_set.all());

        let mut bit_set: BitSet<u8> = Bounded::<u8>::MAX.into();
        assert!(bit_set.all());
        bit_set.toggle(0).unwrap();
        assert!(!bit_set.all());
        bit_set.set_lower_bound(1).unwrap();
        assert!(bit_set.all());
    }

    #[test]
    fn test_none() {
        let bit_set: BitSet<u8> = Bounded::<u8>::MAX.into();
        assert!(!bit_set.none());

        let mut bit_set: BitSet<u8> = 0_u8.into();
        assert!(bit_set.none());
        bit_set.toggle(0).unwrap();
        assert!(!bit_set.none());
        bit_set.set_lower_bound(1).unwrap();
        assert!(bit_set.none());
    }

    #[test]
    fn test_any() {
        let mut bit_set: BitSet<u8> = 0_u8.into();
        assert!(!bit_set.any());
        bit_set.toggle(0).unwrap();
        assert!(bit_set.any());
        bit_set.set_lower_bound(1).unwrap();
        assert!(!bit_set.any());
    }

    #[test]
    fn test_len() {
        let mut bit_set: BitSet<u8> = TESTED_BIT_ARRAY.into();
        assert_eq!(bit_set.len(), 8);
        bit_set.set_lower_bound(1).unwrap();
        bit_set.set_upper_bound(7).unwrap();
        assert_eq!(bit_set.len(), 6);
    }
}
