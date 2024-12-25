use core::panics::panic_with_byte_array;

pub fn assert_with_byte_array(condition: bool, err: ByteArray) {
    if !condition {
        panic_with_byte_array(err: @err)
    }
}

pub trait Describable<T> {
    fn describe(self: T) -> ByteArray;
}

pub trait Panicable<TError, +Describable<TError>> {
    fn panic(self: TError) -> core::never {
        panic_with_byte_array(@self.describe())
    }
}

pub fn assert_with_err<TError, +Describable<TError>, +Panicable<TError>, +Drop<TError>>(
    condition: bool, error: TError,
) {
    if !condition {
        error.panic();
    }
}

#[generate_trait]
pub impl OptionAuxImpl<T> of OptionAuxTrait<T> {
    fn expect_with_err<TError, +Describable<TError>, +Panicable<TError>, +Drop<TError>>(
        self: Option<T>, err: TError,
    ) -> T {
        match self {
            Option::Some(x) => x,
            Option::None => err.panic(),
        }
    }
}
