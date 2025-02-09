use contracts_commons::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub enum TraceErrors {
    UNORDERED_INSERTION,
    EMPTY_TRACE,
}

impl DescribableError of Describable<TraceErrors> {
    #[inline(always)]
    fn describe(self: @TraceErrors) -> ByteArray {
        match self {
            TraceErrors::UNORDERED_INSERTION => "Unordered insertion",
            TraceErrors::EMPTY_TRACE => "Empty trace",
        }
    }
}
