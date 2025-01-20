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

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
struct InternalStakerInfo {
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    unstake_time: Option<Timestamp>,
    amount_own: Amount,
    index: Index,
    unclaimed_rewards_own: Amount,
    pool_info: Option<StakerPoolInfo>,
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
struct InternalStakerInfoV1 {
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    unstake_time: Option<Timestamp>,
    amount_own: Amount,
    index: Index,
    unclaimed_rewards_own: Amount,
    pool_info: Option<StakerPoolInfo>,
}

#[derive(Debug, PartialEq, Serde, Drop, Copy, starknet::Store)]
pub(crate) enum VersionedInternalStakerInfo {
    V0: InternalStakerInfo,
    #[default]
    None,
    V1: InternalStakerInfoV1,
}

#[generate_trait]
pub(crate) impl VersionedInternalStakerInfoImpl of VersionedInternalStakerInfoTrait {
    fn new_latest(
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        unstake_time: Option<Timestamp>,
        amount_own: Amount,
        index: Index,
        unclaimed_rewards_own: Amount,
        pool_info: Option<StakerPoolInfo>,
    ) -> VersionedInternalStakerInfo nopanic {
        VersionedInternalStakerInfo::V1(
            InternalStakerInfoV1 {
                reward_address,
                operational_address,
                unstake_time,
                amount_own,
                index,
                unclaimed_rewards_own,
                pool_info,
            },
        )
    }

    fn is_none(self: @VersionedInternalStakerInfo) -> bool nopanic {
        match *self {
            VersionedInternalStakerInfo::None => true,
            _ => false,
        }
    }

    fn is_latest(self: @VersionedInternalStakerInfo) -> bool {
        match *self {
            VersionedInternalStakerInfo::V1(_) => true,
            VersionedInternalStakerInfo::None(_) => true,
            _ => false,
        }
    }

    fn convert(self: VersionedInternalStakerInfo) -> VersionedInternalStakerInfo {
        match self {
            VersionedInternalStakerInfo::None => {
                panic_with_byte_array(err: @GenericError::STAKER_NOT_EXISTS.describe())
            },
            VersionedInternalStakerInfo::V0(internal_staker_info) => {
                Self::new_latest(
                    internal_staker_info.reward_address,
                    internal_staker_info.operational_address,
                    internal_staker_info.unstake_time,
                    internal_staker_info.amount_own,
                    internal_staker_info.index,
                    internal_staker_info.unclaimed_rewards_own,
                    internal_staker_info.pool_info,
                )
            },
            VersionedInternalStakerInfo::V1(_) => self,
        }
    }

    fn compute_unpool_time(
        self: @VersionedInternalStakerInfo, exit_wait_window: TimeDelta,
    ) -> Timestamp {
        let internal_staker_info = self.unwrap_latest_version();
        if let Option::Some(unstake_time) = internal_staker_info.unstake_time {
            return max(unstake_time, Time::now());
        }
        Time::now().add(delta: exit_wait_window)
    }

    fn get_pool_info(self: @VersionedInternalStakerInfo) -> StakerPoolInfo {
        let internal_staker_info = self.unwrap_latest_version();
        (internal_staker_info.pool_info).expect_with_err(Error::MISSING_POOL_CONTRACT)
    }
}

#[generate_trait]
pub(crate) impl VersionedInternalStakerInfoImplGetters of VersionedInternalStakerInfoGetters {
    fn reward_address(self: @VersionedInternalStakerInfo) -> ContractAddress {
        self.unwrap_latest_version().reward_address
    }
    fn operational_address(self: @VersionedInternalStakerInfo) -> ContractAddress {
        self.unwrap_latest_version().operational_address
    }
    fn unstake_time(self: @VersionedInternalStakerInfo) -> Option<Timestamp> {
        self.unwrap_latest_version().unstake_time
    }
    fn amount_own(self: @VersionedInternalStakerInfo) -> Amount {
        self.unwrap_latest_version().amount_own
    }
    fn index(self: @VersionedInternalStakerInfo) -> Index {
        self.unwrap_latest_version().index
    }
    fn unclaimed_rewards_own(self: @VersionedInternalStakerInfo) -> Amount {
        self.unwrap_latest_version().unclaimed_rewards_own
    }
    fn pool_info(self: @VersionedInternalStakerInfo) -> Option<StakerPoolInfo> {
        self.unwrap_latest_version().pool_info
    }
}

#[generate_trait]
pub(crate) impl VersionedInternalStakerInfoImplSetters of VersionedInternalStakerInfoSetters {
    fn set_reward_address(ref self: VersionedInternalStakerInfo, reward_address: ContractAddress) {
        let mut internal_staker_info = self.unwrap_latest_version();
        internal_staker_info.reward_address = reward_address;
        self = VersionedInternalStakerInfoInternalTrait::new(internal_staker_info);
    }
    fn set_operational_address(
        ref self: VersionedInternalStakerInfo, operational_address: ContractAddress,
    ) {
        let mut internal_staker_info = self.unwrap_latest_version();
        internal_staker_info.operational_address = operational_address;
        self = VersionedInternalStakerInfoInternalTrait::new(internal_staker_info);
    }
    fn set_unstake_time(ref self: VersionedInternalStakerInfo, unstake_time: Option<Timestamp>) {
        let mut internal_staker_info = self.unwrap_latest_version();
        internal_staker_info.unstake_time = unstake_time;
        self = VersionedInternalStakerInfoInternalTrait::new(internal_staker_info);
    }
    fn set_amount_own(ref self: VersionedInternalStakerInfo, amount_own: Amount) {
        let mut internal_staker_info = self.unwrap_latest_version();
        internal_staker_info.amount_own = amount_own;
        self = VersionedInternalStakerInfoInternalTrait::new(internal_staker_info);
    }
    fn set_index(ref self: VersionedInternalStakerInfo, index: Index) {
        let mut internal_staker_info = self.unwrap_latest_version();
        internal_staker_info.index = index;
        self = VersionedInternalStakerInfoInternalTrait::new(internal_staker_info);
    }
    fn set_unclaimed_rewards_own(
        ref self: VersionedInternalStakerInfo, unclaimed_rewards_own: Amount,
    ) {
        let mut internal_staker_info = self.unwrap_latest_version();
        internal_staker_info.unclaimed_rewards_own = unclaimed_rewards_own;
        self = VersionedInternalStakerInfoInternalTrait::new(internal_staker_info);
    }
    fn set_pool_info(ref self: VersionedInternalStakerInfo, pool_info: Option<StakerPoolInfo>) {
        let mut internal_staker_info = self.unwrap_latest_version();
        internal_staker_info.pool_info = pool_info;
        self = VersionedInternalStakerInfoInternalTrait::new(internal_staker_info);
    }
}

#[generate_trait]
impl VersionedInternalStakerInfoInternalImpl of VersionedInternalStakerInfoInternalTrait {
    fn new(value: InternalStakerInfoV1) -> VersionedInternalStakerInfo nopanic {
        VersionedInternalStakerInfo::V1(value)
    }

    fn unwrap_latest_version(self: @VersionedInternalStakerInfo) -> InternalStakerInfoV1 {
        match *self {
            VersionedInternalStakerInfo::V0(_) => panic_with_byte_array(
                err: @Error::INTERNAL_STAKER_INFO_OUTDATED_VERSION.describe(),
            ),
            VersionedInternalStakerInfo::V1(internal_staker_info) => internal_staker_info,
            VersionedInternalStakerInfo::None => panic_with_byte_array(
                err: @GenericError::STAKER_NOT_EXISTS.describe(),
            ),
        }
    }
}

impl VersionedInternalStakerInfoIntoStakerInfo of Into<VersionedInternalStakerInfo, StakerInfo> {
    #[inline(always)]
    fn into(self: VersionedInternalStakerInfo) -> StakerInfo {
        let internal_staker_info = self.unwrap_latest_version();
        StakerInfo {
            reward_address: internal_staker_info.reward_address,
            operational_address: internal_staker_info.operational_address,
            unstake_time: internal_staker_info.unstake_time,
            amount_own: internal_staker_info.amount_own,
            index: internal_staker_info.index,
            unclaimed_rewards_own: internal_staker_info.unclaimed_rewards_own,
            pool_info: internal_staker_info.pool_info,
        }
    }
}

#[cfg(test)]
#[generate_trait]
pub(crate) impl VersionedInternalStakerInfoTestImpl of VersionedInternalStakerInfoTestTrait {
    fn new_v0(
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        unstake_time: Option<Timestamp>,
        amount_own: Amount,
        index: Index,
        unclaimed_rewards_own: Amount,
        pool_info: Option<StakerPoolInfo>,
    ) -> VersionedInternalStakerInfo {
        VersionedInternalStakerInfo::V0(
            InternalStakerInfo {
                reward_address,
                operational_address,
                unstake_time,
                amount_own,
                index,
                unclaimed_rewards_own,
                pool_info,
            },
        )
    }
}

#[cfg(test)]
#[generate_trait]
pub(crate) impl InternalStakerInfoTestImpl of InternalStakerInfoTestTrait {
    fn new(
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        unstake_time: Option<Timestamp>,
        amount_own: Amount,
        index: Index,
        unclaimed_rewards_own: Amount,
        pool_info: Option<StakerPoolInfo>,
    ) -> InternalStakerInfo {
        InternalStakerInfo {
            reward_address,
            operational_address,
            unstake_time,
            amount_own,
            index,
            unclaimed_rewards_own,
            pool_info,
        }
    }
}
