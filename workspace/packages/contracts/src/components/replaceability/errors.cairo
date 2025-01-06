use contracts_commons::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum ReplaceErrors {
    FINALIZED,
    UNKNOWN_IMPLEMENTATION,
    NOT_ENABLED_YET,
    IMPLEMENTATION_EXPIRED,
    EIC_LIB_CALL_FAILED,
    REPLACE_CLASS_HASH_FAILED,
}

impl DescribableError of Describable<ReplaceErrors> {
    #[inline(always)]
    fn describe(self: @ReplaceErrors) -> ByteArray {
        match self {
            ReplaceErrors::FINALIZED => "FINALIZED",
            ReplaceErrors::UNKNOWN_IMPLEMENTATION => "UNKNOWN_IMPLEMENTATION",
            ReplaceErrors::NOT_ENABLED_YET => "NOT_ENABLED_YET",
            ReplaceErrors::IMPLEMENTATION_EXPIRED => "IMPLEMENTATION_EXPIRED",
            ReplaceErrors::EIC_LIB_CALL_FAILED => "EIC_LIB_CALL_FAILED",
            ReplaceErrors::REPLACE_CLASS_HASH_FAILED => "REPLACE_CLASS_HASH_FAILED",
        }
    }
}
