use contracts_commons::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum TimeErrors {
    TIMEDELTA_ADD_OVERFLOW,
    TIMEDELTA_SUB_UNDERFLOW,
    TIMESTAMP_ADD_OVERFLOW,
    TIMESTAMP_SUB_UNDERFLOW,
    TIMEDELTA_DAYS_OVERFLOW,
    TIMEDELTA_WEEKS_OVERFLOW,
    TIMEDELTA_DIV_BY_ZERO,
}

impl DescribableError of Describable<TimeErrors> {
    #[inline(always)]
    fn describe(self: @TimeErrors) -> ByteArray {
        match self {
            TimeErrors::TIMEDELTA_ADD_OVERFLOW => "TimeDelta_add Overflow",
            TimeErrors::TIMEDELTA_SUB_UNDERFLOW => "TimeDelta_sub Underflow",
            TimeErrors::TIMESTAMP_ADD_OVERFLOW => "Timestamp_add Overflow",
            TimeErrors::TIMESTAMP_SUB_UNDERFLOW => "Timestamp_sub Underflow",
            TimeErrors::TIMEDELTA_DAYS_OVERFLOW => "Timedelta overflow: too many days",
            TimeErrors::TIMEDELTA_WEEKS_OVERFLOW => "Timedelta overflow: too many weeks",
            TimeErrors::TIMEDELTA_DIV_BY_ZERO => "TimeDelta division by 0",
        }
    }
}
