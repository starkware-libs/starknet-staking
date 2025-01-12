use contracts_commons::errors::{Describable, ErrorDisplay};
#[derive(Drop)]
pub(crate) enum Error {
    WORK_IS_DONE,
}

impl DescribableError of Describable<Error> {
    #[inline(always)]
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::WORK_IS_DONE => "Work is done for this epoch",
        }
    }
}
