use contracts::types::{Inflation, Amount, Index};
use contracts_commons::constants::{MINUTE, WEEK};
use contracts_commons::types::time::TimeDelta;
pub const DEFAULT_EXIT_WAIT_WINDOW: TimeDelta = TimeDelta { seconds: 3 * WEEK };
pub const MAX_EXIT_WAIT_WINDOW: TimeDelta = TimeDelta { seconds: 12 * WEEK };
pub const BASE_VALUE: Index = 10_000_000_000_000_000_000_000_000_000; // 10**28
pub const MIN_TIME_BETWEEN_INDEX_UPDATES: TimeDelta = TimeDelta { seconds: 30 * MINUTE };
pub const STRK_IN_FRIS: Amount = 1_000_000_000_000_000_000; // 10**18
pub const DEFAULT_C_NUM: Inflation = 160;
pub const MAX_C_NUM: Inflation = 500;
pub const C_DENOM: Inflation = 10_000;
