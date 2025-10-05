use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum Error {
    ON_RECEIVE_NOT_FROM_STARKGATE,
    UNEXPECTED_TOKEN,
    BLOCK_TIME_OVERFLOW,
    INVALID_BLOCK_NUMBER,
    INVALID_BLOCK_TIMESTAMP,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::ON_RECEIVE_NOT_FROM_STARKGATE => "Only StarkGate can call on_receive",
            Error::UNEXPECTED_TOKEN => "Unexpected token",
            Error::BLOCK_TIME_OVERFLOW => "Block time calculation overflow",
            Error::INVALID_BLOCK_NUMBER => "Invalid block number",
            Error::INVALID_BLOCK_TIMESTAMP => "Invalid block timestamp",
        }
    }
}
