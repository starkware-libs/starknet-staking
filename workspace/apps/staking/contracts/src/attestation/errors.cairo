use starkware_utils::errors::{Describable, ErrorDisplay};
#[derive(Drop)]
pub(crate) enum Error {
    ATTEST_IS_DONE,
    ATTEST_OUT_OF_WINDOW,
    ATTEST_WRONG_HASH,
    ATTEST_WINDOW_TOO_SMALL,
    ATTEST_EPOCH_ZERO,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::ATTEST_IS_DONE => "Attestation is done for this epoch",
            Error::ATTEST_OUT_OF_WINDOW => "Attestation is out of window",
            Error::ATTEST_WRONG_HASH => "Attestation with wrong hash",
            Error::ATTEST_WINDOW_TOO_SMALL => "Attestation window is too small, must be larger then 10 blocks",
            Error::ATTEST_EPOCH_ZERO => "Attestation for epoch 0 is not allowed",
        }
    }
}
