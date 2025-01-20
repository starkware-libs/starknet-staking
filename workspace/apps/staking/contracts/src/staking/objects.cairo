use contracts_commons::errors::{Describable, OptionAuxTrait};
use contracts_commons::types::time::time::{Time, TimeDelta, Timestamp};
use core::cmp::max;
use core::num::traits::Zero;
use core::panics::panic_with_byte_array;
use staking::errors::GenericError;
use staking::staking::errors::Error;
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

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub(crate) struct InternalStakerInfoV1 {
    pub(crate) reward_address: ContractAddress,
    pub(crate) operational_address: ContractAddress,
    pub(crate) unstake_time: Option<Timestamp>,
    pub(crate) amount_own: Amount,
    pub(crate) index: Index,
    pub(crate) unclaimed_rewards_own: Amount,
    pub(crate) pool_info: Option<StakerPoolInfo>,
}

#[derive(Debug, PartialEq, Serde, Drop, Copy, starknet::Store)]
pub(crate) enum VersionedInternalStakerInfo {
    V0: InternalStakerInfo,
    #[default]
    None,
    V1: InternalStakerInfoV1,
}

#[generate_trait]
pub(crate) impl InternalStakerInfoV1Impl of InternalStakerInfoV1Trait {
    fn compute_unpool_time(self: @InternalStakerInfoV1, exit_wait_window: TimeDelta) -> Timestamp {
        if let Option::Some(unstake_time) = *self.unstake_time {
            return max(unstake_time, Time::now());
        }
        Time::now().add(delta: exit_wait_window)
    }

    fn get_pool_info(self: @InternalStakerInfoV1) -> StakerPoolInfo {
        (*self.pool_info).expect_with_err(Error::MISSING_POOL_CONTRACT)
    }
}

pub(crate) impl InternalStakerInfoV1IntoStakerInfo of Into<InternalStakerInfoV1, StakerInfo> {
    #[inline(always)]
    fn into(self: InternalStakerInfoV1) -> StakerInfo nopanic {
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
        assert!(self.is_valid(), "{}", Error::INVALID_UNDELEGATE_INTENT_VALUE);
    }
}

#[generate_trait]
pub(crate) impl VersionedInternalStakerInfoImpl of VersionedInternalStakerInfoTrait {
    fn is_none(self: @VersionedInternalStakerInfo) -> bool nopanic {
        match *self {
            VersionedInternalStakerInfo::None => true,
            _ => false,
        }
    }

    fn get_internal_staker_info_v1(self: VersionedInternalStakerInfo) -> InternalStakerInfoV1 {
        match self {
            VersionedInternalStakerInfo::V0(internal_staker_info) => internal_staker_info.into(),
            VersionedInternalStakerInfo::V1(internal_staker_info_v1) => internal_staker_info_v1,
            VersionedInternalStakerInfo::None => panic_with_byte_array(
                err: @GenericError::STAKER_NOT_EXISTS.describe(),
            ),
        }
    }

    fn new(value: InternalStakerInfoV1) -> VersionedInternalStakerInfo {
        VersionedInternalStakerInfo::V1(value)
    }

    fn new_latest(
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: Amount,
        index: Index,
        pool_info: Option<StakerPoolInfo>,
    ) -> VersionedInternalStakerInfo {
        VersionedInternalStakerInfo::V1(
            InternalStakerInfoV1 {
                reward_address,
                operational_address,
                unstake_time: Option::None,
                amount_own: amount,
                index: index,
                unclaimed_rewards_own: Zero::zero(),
                pool_info,
            },
        )
    }
}

pub(crate) impl InternalStakerInfoIntoInternalStakerInfoV1 of Into<
    InternalStakerInfo, InternalStakerInfoV1,
> {
    #[inline(always)]
    fn into(self: InternalStakerInfo) -> InternalStakerInfoV1 nopanic {
        InternalStakerInfoV1 {
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

