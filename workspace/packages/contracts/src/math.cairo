use core::num::traits::zero::Zero;


/// Returns the absolute value of a number.
fn abs<T, +PartialOrd<T>, +Neg<T>, +Drop<T>, +Copy<T>, +Zero<T>, S, +TryInto<T, S>>(a: T) -> S {
    let res = if a > Zero::<T>::zero() {
        a
    } else {
        -a
    };
    res.try_into().unwrap()
}

pub trait Abs<T, S> {
    /// Returns the absolute value of a number.
    fn abs(self: T) -> S;
}

pub impl AbsImplI8 of Abs<i8, u8> {
    fn abs(self: i8) -> u8 {
        abs(self)
    }
}

pub impl AbsImplI16 of Abs<i16, u16> {
    fn abs(self: i16) -> u16 {
        abs(self)
    }
}

pub impl AbsImplI32 of Abs<i32, u32> {
    fn abs(self: i32) -> u32 {
        abs(self)
    }
}

pub impl AbsImplI64 of Abs<i64, u64> {
    fn abs(self: i64) -> u64 {
        abs(self)
    }
}

pub impl AbsImplI128 of Abs<i128, u128> {
    fn abs(self: i128) -> u128 {
        abs(self)
    }
}


#[cfg(test)]
mod tests {
    use super::{AbsImplI128, AbsImplI16, AbsImplI32, AbsImplI64, AbsImplI8};

    #[test]
    fn test_abs_i8() {
        assert_eq!(AbsImplI8::abs(1_i8), 1_u8);
        assert_eq!(AbsImplI8::abs(-1_i8), 1_u8);
    }

    #[test]
    fn test_abs_i16() {
        assert_eq!(AbsImplI16::abs(1_i16), 1_u16);
        assert_eq!(AbsImplI16::abs(-1_i16), 1_u16);
    }

    #[test]
    fn test_abs_i32() {
        assert_eq!(AbsImplI32::abs(1_i32), 1_u32);
        assert_eq!(AbsImplI32::abs(-1_i32), 1_u32);
    }

    #[test]
    fn test_abs_i64() {
        assert_eq!(AbsImplI64::abs(1_i64), 1_u64);
        assert_eq!(AbsImplI64::abs(-1_i64), 1_u64);
    }

    #[test]
    fn test_abs_i128() {
        assert_eq!(AbsImplI128::abs(1_i128), 1_u128);
        assert_eq!(AbsImplI128::abs(-1_i128), 1_u128);
    }
}
