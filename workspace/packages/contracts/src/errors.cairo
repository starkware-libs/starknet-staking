use core::fmt::{Display, Error as fmtError, Formatter};
use core::panics::panic_with_byte_array;

pub fn assert_with_byte_array(condition: bool, err: ByteArray) {
    if !condition {
        panic_with_byte_array(err: @err)
    }
}

pub trait Describable<T> {
    fn describe(self: @T) -> ByteArray;
}

#[generate_trait]
pub impl OptionAuxImpl<T> of OptionAuxTrait<T> {
    fn expect_with_err<TError, +Describable<TError>, +Drop<TError>>(
        self: Option<T>, err: TError,
    ) -> T {
        match self {
            Option::Some(x) => x,
            Option::None => panic_with_byte_array(err: @err.describe()),
        }
    }
}

pub impl ErrorDisplay<T, +Describable<T>> of Display<T> {
    fn fmt(self: @T, ref f: Formatter) -> Result<(), fmtError> {
        let description = self.describe();
        f.buffer.append(@description);
        Result::Ok(())
    }
}
