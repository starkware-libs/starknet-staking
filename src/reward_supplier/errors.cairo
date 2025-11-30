use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub enum Error {
    ON_RECEIVE_NOT_FROM_STARKGATE,
    UNEXPECTED_TOKEN,
    BLOCK_DURATION_OVERFLOW,
    INVALID_BLOCK_NUMBER,
    INVALID_BLOCK_TIMESTAMP,
    INVALID_MIN_MAX_BLOCK_DURATION,
    INVALID_AVG_BLOCK_DURATION,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::ON_RECEIVE_NOT_FROM_STARKGATE => "Only StarkGate can call on_receive",
            Error::UNEXPECTED_TOKEN => "Unexpected token",
            Error::BLOCK_DURATION_OVERFLOW => "Block duration calculation overflow",
            Error::INVALID_BLOCK_NUMBER => "Invalid block number",
            Error::INVALID_BLOCK_TIMESTAMP => "Invalid block timestamp",
            Error::INVALID_MIN_MAX_BLOCK_DURATION => "Invalid min/max block duration",
            Error::INVALID_AVG_BLOCK_DURATION => "Invalid avg block duration",
        }
    }
}
