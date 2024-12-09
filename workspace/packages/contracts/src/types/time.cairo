use contracts_commons::constants::{DAY, WEEK};
use core::traits::Into;

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct TimeDelta {
    pub seconds: u64,
}
impl TimeDeltaZero of core::num::traits::Zero<TimeDelta> {
    fn zero() -> TimeDelta {
        TimeDelta { seconds: 0 }
    }
    fn is_zero(self: @TimeDelta) -> bool {
        self.seconds.is_zero()
    }
    fn is_non_zero(self: @TimeDelta) -> bool {
        self.seconds.is_non_zero()
    }
}
impl TimeDeltaAdd of Add<TimeDelta> {
    fn add(lhs: TimeDelta, rhs: TimeDelta) -> TimeDelta {
        TimeDelta { seconds: lhs.seconds + rhs.seconds }
    }
}
impl TimeDeltaSub of Sub<TimeDelta> {
    fn sub(lhs: TimeDelta, rhs: TimeDelta) -> TimeDelta {
        TimeDelta { seconds: lhs.seconds - rhs.seconds }
    }
}
impl TimeDeltaIntoU64 of Into<TimeDelta, u64> {
    fn into(self: TimeDelta) -> u64 {
        self.seconds
    }
}
impl TimeDeltaPartialOrd of PartialOrd<TimeDelta> {
    fn lt(lhs: TimeDelta, rhs: TimeDelta) -> bool {
        lhs.seconds < rhs.seconds
    }
    fn le(lhs: TimeDelta, rhs: TimeDelta) -> bool {
        lhs.seconds <= rhs.seconds
    }
}


#[derive(Debug, PartialEq, Drop, Hash, Serde, Copy, starknet::Store)]
pub struct Timestamp {
    pub seconds: u64,
}
impl TimeStampZero of core::num::traits::Zero<Timestamp> {
    fn zero() -> Timestamp nopanic {
        Timestamp { seconds: 0 }
    }
    fn is_zero(self: @Timestamp) -> bool {
        self.seconds.is_zero()
    }
    fn is_non_zero(self: @Timestamp) -> bool {
        self.seconds.is_non_zero()
    }
}
impl TimeAddAssign of core::ops::AddAssign<Timestamp, TimeDelta> {
    fn add_assign(ref self: Timestamp, rhs: TimeDelta) {
        self.seconds += rhs.seconds;
    }
}
impl TimeStampPartialOrd of PartialOrd<Timestamp> {
    fn lt(lhs: Timestamp, rhs: Timestamp) -> bool {
        lhs.seconds < rhs.seconds
    }
}
impl TimeStampInto of Into<Timestamp, u64> {
    fn into(self: Timestamp) -> u64 nopanic {
        self.seconds
    }
}

#[generate_trait]
pub impl TimeImpl of Time {
    fn seconds(count: u64) -> TimeDelta nopanic {
        TimeDelta { seconds: count }
    }
    fn days(count: u64) -> TimeDelta {
        Self::seconds(count: count * DAY)
    }
    fn weeks(count: u64) -> TimeDelta {
        Self::seconds(count: count * WEEK)
    }
    fn now() -> Timestamp {
        Timestamp { seconds: starknet::get_block_timestamp() }
    }
    fn add(self: Timestamp, delta: TimeDelta) -> Timestamp {
        let mut value = self;
        value += delta;
        value
    }
    fn sub(self: Timestamp, other: Timestamp) -> TimeDelta {
        TimeDelta { seconds: self.seconds - other.seconds }
    }
    fn div(self: TimeDelta, divider: u64) -> TimeDelta {
        TimeDelta { seconds: self.seconds / divider }
    }
}


#[cfg(test)]
mod tests {
    use contracts_commons::constants::DAY;
    use snforge_std::start_cheat_block_timestamp_global;
    use core::num::traits::zero::Zero;
    use super::{Time, Timestamp, TimeDelta};

    #[test]
    fn test_timedelta_add() {
        let delta1 = Time::days(count: 1);
        let delta2 = Time::days(count: 2);
        let delta3 = delta1 + delta2;
        assert_eq!(delta3.seconds, delta1.seconds + delta2.seconds);
        assert_eq!(delta3.seconds, Time::days(count: 3).seconds);
    }

    #[test]
    fn test_timedelta_sub() {
        let delta1 = Time::days(count: 3);
        let delta2 = Time::days(count: 1);
        let delta3 = delta1 - delta2;
        assert_eq!(delta3.seconds, delta1.seconds - delta2.seconds);
        assert_eq!(delta3.seconds, Time::days(count: 2).seconds);
    }

    #[test]
    fn test_timedelta_zero() {
        let delta = Time::days(count: 0);
        assert_eq!(delta, Zero::zero());
    }

    #[test]
    fn test_timedelta_eq() {
        let delta1: TimeDelta = Zero::zero();
        let delta2: TimeDelta = Zero::zero();
        let delta3 = delta1 + Time::days(count: 1);
        assert!(delta1 == delta2);
        assert!(delta1 != delta3);
    }

    #[test]
    fn test_timedelta_into() {
        let delta = Time::days(count: 1);
        assert_eq!(delta.into(), Time::days(count: 1).seconds);
    }

    #[test]
    fn test_timedelta_lt() {
        let delta1 = TimeDelta { seconds: 1 };
        let delta2 = TimeDelta { seconds: 2 };
        assert!(delta1 != delta2);
        assert!(delta1 < delta2);
        assert!(!(delta1 == delta2));
        assert!(!(delta1 > delta2));
    }

    fn test_timedelta_le() {
        let delta1 = TimeDelta { seconds: 1 };
        let delta2 = TimeDelta { seconds: 2 };
        assert!(delta1 != delta2);
        assert!(delta1 <= delta2);
        assert!(!(delta1 >= delta2));
        assert!(!(delta1 == delta2));
        let delta3 = TimeDelta { seconds: 1 };
        assert!(delta1 <= delta3);
        assert!(delta1 >= delta3);
        assert!(!(delta1 != delta3));
        assert!(delta1 == delta3);
    }

    #[test]
    fn test_timestamp_add_assign() {
        let mut time: Timestamp = Zero::zero();
        time += Time::days(count: 1);
        assert_eq!(time.seconds, Zero::zero() + Time::days(count: 1).seconds);
    }

    #[test]
    fn test_timestamp_eq() {
        let time1: Timestamp = Zero::zero();
        let time2: Timestamp = Zero::zero();
        let time3 = time1.add(delta: Time::days(count: 1));
        assert!(time1 == time2);
        assert!(time1 != time3);
    }

    #[test]
    fn test_timestamp_into() {
        let time = Time::days(count: 1);
        assert_eq!(time.into(), Time::days(count: 1).seconds);
    }

    #[test]
    fn test_timestamp_sub() {
        let time1 = Timestamp { seconds: 2 };
        let time2 = Timestamp { seconds: 1 };
        let delta = time1.sub(other: time2);
        assert_eq!(delta, Time::seconds(count: 1));
    }

    #[test]
    fn test_timestamp_lt() {
        let time1: Timestamp = Zero::zero();
        let time2 = time1.add(delta: Time::days(count: 1));
        assert!(time1 < time2);
    }

    #[test]
    fn test_timestamp_zero() {
        let time: Timestamp = Timestamp { seconds: 0 };
        assert_eq!(time, Zero::zero());
    }

    #[test]
    fn test_time_add() {
        let time: Timestamp = Zero::zero();
        let new_time = time.add(delta: Time::days(count: 1));
        assert_eq!(new_time.seconds, time.seconds + Time::days(count: 1).seconds);
    }

    #[test]
    fn test_time_now() {
        start_cheat_block_timestamp_global(block_timestamp: Time::days(count: 1).seconds);
        let time = Time::now();
        assert_eq!(time.seconds, Time::days(count: 1).seconds);
    }

    #[test]
    fn test_time_seconds() {
        let seconds = 42;
        let time = Time::seconds(count: seconds);
        assert_eq!(time.seconds, seconds);
    }

    #[test]
    fn test_time_days() {
        let time = Time::days(count: 1);
        assert_eq!(time.seconds, DAY);
    }
}
