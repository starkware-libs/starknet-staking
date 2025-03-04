use contracts_commons::errors::{Describable, ErrorDisplay};
#[derive(Drop)]
pub(crate) enum Error {
    NO_ATTEST_DONE,
    ATTEST_IS_DONE,
    ATTEST_WINDOW_TOO_SMALL,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::NO_ATTEST_DONE => "No attestation is done for this staker",
            Error::ATTEST_IS_DONE => "Attestation is done for this epoch",
            Error::ATTEST_WINDOW_TOO_SMALL => "Attestation window is too small, must be larger then 10 blocks",
        }
    }
}
