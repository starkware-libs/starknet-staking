use contracts_commons::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum TraceErrors {
    UNORDERED_INSERTION,
}

impl DescribableError of Describable<TraceErrors> {
    #[inline(always)]
    fn describe(self: @TraceErrors) -> ByteArray {
        match self {
            TraceErrors::UNORDERED_INSERTION => "Unordered insertion",
        }
    }
}
