use contracts_commons::errors::{OptionAuxTrait, assert_with_err};
use contracts_commons::types::time::{Time, TimeDelta, Timestamp};
use core::cmp::max;
use core::num::traits::Zero;
use staking::errors::Error;
use staking::staking::interface::{StakerInfo, StakerPoolInfo};
use staking::types::{Amount, Index};
use starknet::ContractAddress;

#[derive(Hash, Drop, Serde, Copy, starknet::Store)]
pub(crate) struct UndelegateIntentKey {
    pub pool_contract: ContractAddress,
    // The identifier is generally the pool member address, but it can be any unique identifier,
    // depending on the logic of the pool contract.
    pub identifier: felt252,
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub(crate) struct UndelegateIntentValue {
    pub unpool_time: Timestamp,
    pub amount: Amount,
}

pub(crate) impl UndelegateIntentValueZero of core::num::traits::Zero<UndelegateIntentValue> {
    fn zero() -> UndelegateIntentValue {
        UndelegateIntentValue { unpool_time: Zero::zero(), amount: Zero::zero() }
    }
    #[inline(always)]
    fn is_zero(self: @UndelegateIntentValue) -> bool {
        *self == Self::zero()
    }
    #[inline(always)]
    fn is_non_zero(self: @UndelegateIntentValue) -> bool {
        !self.is_zero()
    }
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub(crate) struct InternalStakerInfo {
    pub(crate) reward_address: ContractAddress,
    pub(crate) operational_address: ContractAddress,
    pub(crate) unstake_time: Option<Timestamp>,
    pub(crate) amount_own: Amount,
    pub(crate) index: Index,
    pub(crate) unclaimed_rewards_own: Amount,
    pub(crate) pool_info: Option<StakerPoolInfo>,
}

#[generate_trait]
pub(crate) impl InternalStakerInfoImpl of InternalStakerInfoTrait {
    fn compute_unpool_time(self: @InternalStakerInfo, exit_wait_window: TimeDelta) -> Timestamp {
        if let Option::Some(unstake_time) = *self.unstake_time {
            return max(unstake_time, Time::now());
        }
        Time::now().add(delta: exit_wait_window)
    }

    fn get_pool_info(self: @InternalStakerInfo) -> StakerPoolInfo {
        (*self.pool_info).expect_with_err(Error::MISSING_POOL_CONTRACT)
    }
}

pub(crate) impl InternalStakerInfoInto of Into<InternalStakerInfo, StakerInfo> {
    #[inline(always)]
    fn into(self: InternalStakerInfo) -> StakerInfo nopanic {
        StakerInfo {
            reward_address: self.reward_address,
            operational_address: self.operational_address,
            unstake_time: self.unstake_time,
            amount_own: self.amount_own,
            index: self.index,
            unclaimed_rewards_own: self.unclaimed_rewards_own,
            pool_info: self.pool_info,
        }
    }
}

#[generate_trait]
pub(crate) impl UndelegateIntentValueImpl of UndelegateIntentValueTrait {
    fn is_valid(self: @UndelegateIntentValue) -> bool {
        // The value is valid if and only if unpool_time and amount are both zero or both non-zero.
        self.unpool_time.is_zero() == self.amount.is_zero()
    }

    fn assert_valid(self: @UndelegateIntentValue) {
        assert_with_err(self.is_valid(), Error::INVALID_UNDELEGATE_INTENT_VALUE);
    }
}

#[cfg(test)]
mod test_undelegate_intent {
    use contracts_commons::types::time::Timestamp;
    use core::num::traits::zero::Zero;
    use super::{UndelegateIntentValue, UndelegateIntentValueTrait};

    const UNPOOL_TIME: Timestamp = Timestamp { seconds: 1 };

    #[test]
    fn test_zero() {
        let d: UndelegateIntentValue = Zero::zero();
        assert_eq!(
            d,
            UndelegateIntentValue {
                unpool_time: Timestamp { seconds: Zero::zero() }, amount: Zero::zero(),
            },
        );
    }

    #[test]
    fn test_is_zero() {
        let d: UndelegateIntentValue = Zero::zero();
        assert!(d.is_zero());
        assert!(!d.is_non_zero());
    }

    #[test]
    fn test_is_non_zero() {
        let d = UndelegateIntentValue { unpool_time: UNPOOL_TIME, amount: 1 };
        assert!(!d.is_zero());
        assert!(d.is_non_zero());
    }

    #[test]
    fn test_is_valid() {
        let d = UndelegateIntentValue { unpool_time: Zero::zero(), amount: Zero::zero() };
        assert!(d.is_valid());
        let d = UndelegateIntentValue { unpool_time: UNPOOL_TIME, amount: 1 };
        assert!(d.is_valid());
        let d = UndelegateIntentValue { unpool_time: Zero::zero(), amount: 1 };
        assert!(!d.is_valid());
        let d = UndelegateIntentValue { unpool_time: UNPOOL_TIME, amount: Zero::zero() };
        assert!(!d.is_valid());
    }

    #[test]
    fn test_assert_valid() {
        let d = UndelegateIntentValue { unpool_time: Zero::zero(), amount: Zero::zero() };
        d.assert_valid();
        let d = UndelegateIntentValue { unpool_time: UNPOOL_TIME, amount: 1 };
        d.assert_valid();
    }

    #[test]
    #[should_panic(expected: "Invalid undelegate intent value")]
    fn test_assert_valid_panic() {
        let d = UndelegateIntentValue { unpool_time: Zero::zero(), amount: 1 };
        d.assert_valid();
    }
}

#[cfg(test)]
mod test_internal_staker_info {
    use contracts_commons::types::time::Time;
    use core::num::traits::zero::Zero;
    use snforge_std::start_cheat_block_timestamp_global;
    use staking::constants::DEFAULT_EXIT_WAIT_WINDOW;
    use staking::staking::interface::{StakerInfo, StakerPoolInfo};
    use super::{InternalStakerInfo, InternalStakerInfoTrait};

    #[test]
    fn test_into() {
        let internal_staker_info = InternalStakerInfo {
            reward_address: Zero::zero(),
            operational_address: Zero::zero(),
            unstake_time: Option::None,
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: Zero::zero(),
            pool_info: Option::None,
        };
        let staker_info: StakerInfo = internal_staker_info.into();
        let expected_staker_info = StakerInfo {
            reward_address: Zero::zero(),
            operational_address: Zero::zero(),
            unstake_time: Option::None,
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: Zero::zero(),
            pool_info: Option::None,
        };
        assert_eq!(staker_info, expected_staker_info);
    }

    #[test]
    fn test_compute_unpool_time() {
        let exit_wait_window = DEFAULT_EXIT_WAIT_WINDOW;
        // Unstake_time is not set.
        let internal_staker_info = InternalStakerInfo {
            reward_address: Zero::zero(),
            operational_address: Zero::zero(),
            unstake_time: Option::None,
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: Zero::zero(),
            pool_info: Option::None,
        };
        assert_eq!(
            internal_staker_info.compute_unpool_time(:exit_wait_window),
            Time::now().add(delta: exit_wait_window),
        );

        // Unstake_time is set.
        let unstake_time = Time::now().add(delta: Time::weeks(count: 1));
        let internal_staker_info = InternalStakerInfo {
            reward_address: Zero::zero(),
            operational_address: Zero::zero(),
            unstake_time: Option::Some(unstake_time),
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: Zero::zero(),
            pool_info: Option::None,
        };

        // Unstake time > current time.
        assert_eq!(Time::now(), Zero::zero());
        assert_eq!(internal_staker_info.compute_unpool_time(:exit_wait_window), unstake_time);

        // Unstake time < current time.
        start_cheat_block_timestamp_global(
            block_timestamp: Time::now().add(delta: exit_wait_window).into(),
        );
        assert_eq!(internal_staker_info.compute_unpool_time(:exit_wait_window), Time::now());
    }

    #[test]
    fn test_get_pool_info() {
        let staker_pool_info = StakerPoolInfo {
            pool_contract: Zero::zero(),
            amount: Zero::zero(),
            unclaimed_rewards: Zero::zero(),
            commission: Zero::zero(),
        };
        let internal_staker_info = InternalStakerInfo {
            reward_address: Zero::zero(),
            operational_address: Zero::zero(),
            unstake_time: Option::None,
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: Zero::zero(),
            pool_info: Option::Some(staker_pool_info),
        };
        assert_eq!(internal_staker_info.get_pool_info(), staker_pool_info);
    }

    #[test]
    #[should_panic(expected: "Staker does not have a pool contract")]
    fn test_get_pool_info_panic() {
        let internal_staker_info = InternalStakerInfo {
            reward_address: Zero::zero(),
            operational_address: Zero::zero(),
            unstake_time: Option::None,
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: Zero::zero(),
            pool_info: Option::None,
        };
        internal_staker_info.get_pool_info();
    }
}
