use contracts_commons::constants::{DAY, WEEK};
use core::traits::Into;

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct TimeDelta {
    pub seconds: u64
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


#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct TimeStamp {
    pub seconds: u64
}
impl TimeStampZero of core::num::traits::Zero<TimeStamp> {
    fn zero() -> TimeStamp {
        TimeStamp { seconds: 0 }
    }
    fn is_zero(self: @TimeStamp) -> bool {
        self.seconds.is_zero()
    }
    fn is_non_zero(self: @TimeStamp) -> bool {
        self.seconds.is_non_zero()
    }
}
impl TimeAddAssign of core::ops::AddAssign<TimeStamp, TimeDelta> {
    fn add_assign(ref self: TimeStamp, rhs: TimeDelta) {
        self.seconds += rhs.seconds;
    }
}
impl TimeStampPartialOrd of PartialOrd<TimeStamp> {
    fn lt(lhs: TimeStamp, rhs: TimeStamp) -> bool {
        lhs.seconds < rhs.seconds
    }
}
impl TimeStampInto of Into<TimeStamp, u64> {
    fn into(self: TimeStamp) -> u64 {
        self.seconds
    }
}

#[generate_trait]
pub impl TimeImpl of Time {
    fn seconds(count: u64) -> TimeDelta {
        TimeDelta { seconds: count }
    }
    fn days(count: u64) -> TimeDelta {
        Self::seconds(count * DAY)
    }
    fn weeks(count: u64) -> TimeDelta {
        Self::seconds(count * WEEK)
    }
    fn now() -> TimeStamp {
        TimeStamp { seconds: starknet::get_block_timestamp() }
    }
    fn add(self: TimeStamp, delta: TimeDelta) -> TimeStamp {
        let mut value = self;
        value += delta;
        value
    }
    fn sub(self: TimeStamp, other: TimeStamp) -> TimeDelta {
        TimeDelta { seconds: self.seconds - other.seconds }
    }
    fn mul(self: TimeDelta, multiplier: u64) -> TimeDelta {
        TimeDelta { seconds: self.seconds * multiplier }
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
    use super::{Time, TimeStamp, TimeDelta};

    #[test]
    fn test_timedelta_add() {
        let delta1 = Time::days(1);
        let delta2 = Time::days(2);
        let delta3 = delta1 + delta2;
        assert_eq!(delta3.seconds, delta1.seconds + delta2.seconds);
        assert_eq!(delta3.seconds, Time::days(3).seconds);
    }

    #[test]
    fn test_timedelta_sub() {
        let delta1 = Time::days(3);
        let delta2 = Time::days(1);
        let delta3 = delta1 - delta2;
        assert_eq!(delta3.seconds, delta1.seconds - delta2.seconds);
        assert_eq!(delta3.seconds, Time::days(2).seconds);
    }

    #[test]
    fn test_timedelta_mul() {
        let delta = Time::days(1);
        let delta2 = delta.mul(2);
        assert_eq!(delta2, Time::days(2));
    }

    #[test]
    fn test_timedelta_zero() {
        let delta = Time::days(0);
        assert_eq!(delta, Zero::zero());
    }

    #[test]
    fn test_timedelta_eq() {
        let delta1: TimeDelta = Zero::zero();
        let delta2: TimeDelta = Zero::zero();
        let delta3 = delta1 + Time::days(1);
        assert!(delta1 == delta2);
        assert!(delta1 != delta3);
    }

    #[test]
    fn test_timedelta_into() {
        let delta = Time::days(1);
        assert_eq!(delta.into(), Time::days(1).seconds);
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
        let mut time: TimeStamp = Zero::zero();
        time += Time::days(1);
        assert_eq!(time.seconds, Zero::zero() + Time::days(1).seconds);
    }

    #[test]
    fn test_timestamp_eq() {
        let time1: TimeStamp = Zero::zero();
        let time2: TimeStamp = Zero::zero();
        let time3 = time1.add(Time::days(1));
        assert!(time1 == time2);
        assert!(time1 != time3);
    }

    #[test]
    fn test_timestamp_into() {
        let time = Time::days(1);
        assert_eq!(time.into(), Time::days(1).seconds);
    }

    #[test]
    fn test_timestamp_sub() {
        let time1 = TimeStamp { seconds: 2 };
        let time2 = TimeStamp { seconds: 1 };
        let delta = time1.sub(time2);
        assert_eq!(delta, Time::seconds(1));
    }

    #[test]
    fn test_timestamp_lt() {
        let time1: TimeStamp = Zero::zero();
        let time2 = time1.add(Time::days(1));
        assert!(time1 < time2);
    }

    #[test]
    fn test_timestamp_zero() {
        let time: TimeStamp = TimeStamp { seconds: 0 };
        assert_eq!(time, Zero::zero());
    }

    #[test]
    fn test_time_add() {
        let time: TimeStamp = Zero::zero();
        let new_time = time.add(Time::days(1));
        assert_eq!(new_time.seconds, time.seconds + Time::days(1).seconds);
    }

    #[test]
    fn test_time_now() {
        start_cheat_block_timestamp_global(block_timestamp: Time::days(1).seconds);
        let time = Time::now();
        assert_eq!(time.seconds, Time::days(1).seconds);
    }

    #[test]
    fn test_time_seconds() {
        let seconds = 42;
        let time = Time::seconds(seconds);
        assert_eq!(time.seconds, seconds);
    }

    #[test]
    fn test_time_days() {
        let time = Time::days(1);
        assert_eq!(time.seconds, DAY);
    }
}
