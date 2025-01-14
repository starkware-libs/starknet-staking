use contracts_commons::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum Error {
    ON_RECEIVE_NOT_FROM_STARKGATE,
    UNEXPECTED_TOKEN,
}

impl DescribableError of Describable<Error> {
    #[inline(always)]
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::ON_RECEIVE_NOT_FROM_STARKGATE => "Only StarkGate can call on_receive",
            Error::UNEXPECTED_TOKEN => "UNEXPECTED_TOKEN",
        }
    }
}
