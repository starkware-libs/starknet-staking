use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum Error {
    ON_RECEIVE_NOT_FROM_STARKGATE,
    UNEXPECTED_TOKEN,
    BLOCK_TIME_OVERFLOW,
    INVALID_BLOCK_NUMBER,
    INVALID_BLOCK_TIMESTAMP,
    INVALID_WEIGHTED_AVG_FACTOR,
    INVALID_MIN_MAX_BLOCK_TIME,
    INVALID_AVG_BLOCK_DURATION,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::ON_RECEIVE_NOT_FROM_STARKGATE => "Only StarkGate can call on_receive",
            Error::UNEXPECTED_TOKEN => "Unexpected token",
            Error::BLOCK_TIME_OVERFLOW => "Block time calculation overflow",
            Error::INVALID_BLOCK_NUMBER => "Invalid block number",
            Error::INVALID_BLOCK_TIMESTAMP => "Invalid block timestamp",
            Error::INVALID_WEIGHTED_AVG_FACTOR => "Invalid weighted average factor",
            Error::INVALID_MIN_MAX_BLOCK_TIME => "Invalid min/max block time",
            Error::INVALID_AVG_BLOCK_DURATION => "Invalid average block duration",
        }
    }
}
