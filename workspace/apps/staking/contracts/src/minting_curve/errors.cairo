use staking_test::constants::MAX_C_NUM;
use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub enum Error {
    UNAUTHORIZED_MESSAGE_SENDER,
    C_NUM_OUT_OF_RANGE,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::UNAUTHORIZED_MESSAGE_SENDER => "Unauthorized message sender",
            Error::C_NUM_OUT_OF_RANGE => format!("C Numerator out of range (0-{})", MAX_C_NUM),
        }
    }
}
