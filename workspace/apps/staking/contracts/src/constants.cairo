use contracts::types::{TimeDelta, Inflation, Amount, Index};
use contracts_commons::constants::{SECONDS_IN_DAY, DAYS_IN_WEEK};
pub const DEFAULT_EXIT_WAIT_WINDOW: TimeDelta = SECONDS_IN_DAY * DAYS_IN_WEEK * 3; // 3 weeks
pub const BASE_VALUE: Index = 10_000_000_000_000_000_000_000_000_000; // 10**28
pub const MIN_DAYS_BETWEEN_INDEX_UPDATES: u64 = 1;
pub const STRK_IN_FRIS: Amount = 1_000_000_000_000_000_000; // 10**18
pub const DEFAULT_C_NUM: Inflation = 160;
pub const C_DENOM: Inflation = 10_000;
