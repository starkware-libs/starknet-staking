use contracts_commons::errors::OptionAuxTrait;
use contracts_commons::types::time::time::{Time, TimeDelta, Timestamp};
use core::cmp::max;
use core::num::traits::Zero;
use staking::staking::errors::Error;
use staking::staking::interface::{
    IStakingDispatcherTrait, IStakingLibraryDispatcher, StakerInfo, StakerPoolInfo,
};
use staking::types::{Amount, Epoch, Index, InternalStakerInfoLatest};
use starknet::{ClassHash, ContractAddress, get_block_number};

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

// TODO: pack
#[derive(Debug, Hash, Drop, Serde, Copy, PartialEq, starknet::Store)]
pub(crate) struct EpochInfo {
    length: u16,
    // The first block of the first epoch with this length.
    starting_block: u64,
    // The first epoch, can be changed by fn update.
    starting_epoch: Epoch,
}

#[generate_trait]
pub(crate) impl EpochInfoImpl of EpochInfoTrait {
    fn new(length: u16, starting_block: u64) -> EpochInfo {
        assert!(length.is_non_zero(), "{}", Error::INVALID_EPOCH_LENGTH);
        EpochInfo { length, starting_block, starting_epoch: Zero::zero() }
    }

    fn current_epoch(self: @EpochInfo) -> Epoch {
        let current_block = get_block_number();
        // If the epoch info updated and the current block is before the starting block of the
        // next epoch with the new length.
        if current_block < *self.starting_block {
            return *self.starting_epoch - 1;
        }
        ((current_block - *self.starting_block) / (*self.length).into()) + *self.starting_epoch
    }

    fn update(ref self: EpochInfo, epoch_length: u16) {
        assert!(epoch_length.is_non_zero(), "{}", Error::INVALID_EPOCH_LENGTH);
        self.starting_epoch = self.next_epoch();
        self.starting_block = self.calculate_next_epoch_starting_block();
        self.length = epoch_length;
    }

    fn length(self: @EpochInfo) -> u16 {
        *self.length
    }
}

#[generate_trait]
impl PrivateEpochInfoImpl of PrivateEpochInfoTrait {
    fn calculate_next_epoch_starting_block(self: @EpochInfo) -> u64 {
        let current_block = get_block_number();
        let blocks_passed = current_block - *self.starting_block;
        let length: u64 = (*self.length).into();
        let blocks_to_next_epoch = length - (blocks_passed % length);
        current_block + blocks_to_next_epoch
    }

    fn next_epoch(self: @EpochInfo) -> Epoch {
        self.current_epoch() + 1
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

// **Note**: This struct should be made private in the next version of Internal Staker Info.
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

// **Note**: This struct should be updated in the next version of Internal Staker Info.
#[derive(Debug, PartialEq, Serde, Drop, Copy, starknet::Store)]
pub(crate) enum VersionedInternalStakerInfo {
    V0: InternalStakerInfo,
    #[default]
    None,
    V1: InternalStakerInfoV1,
}

// **Note**: This trait must be reimplemented in the next version of Internal Staker Info.
#[generate_trait]
pub(crate) impl InternalStakerInfoConvert of InternalStakerInfoConvertTrait {
    fn convert(
        self: InternalStakerInfo, prev_class_hash: ClassHash, staker_address: ContractAddress,
    ) -> InternalStakerInfoV1 {
        let library_dispatcher = IStakingLibraryDispatcher { class_hash: prev_class_hash };
        library_dispatcher.staker_info(staker_address).into()
    }
}

// **Note**: This trait must be reimplemented in the next version of Internal Staker Info.
#[generate_trait]
pub(crate) impl VersionedInternalStakerInfoImpl of VersionedInternalStakerInfoTrait {
    fn wrap_latest(value: InternalStakerInfoV1) -> VersionedInternalStakerInfo nopanic {
        VersionedInternalStakerInfo::V1(value)
    }

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
}

#[generate_trait]
pub(crate) impl InternalStakerInfoLatestImpl of InternalStakerInfoLatestTrait {
    fn compute_unpool_time(
        self: @InternalStakerInfoLatest, exit_wait_window: TimeDelta,
    ) -> Timestamp {
        if let Option::Some(unstake_time) = *self.unstake_time {
            return max(unstake_time, Time::now());
        }
        Time::now().add(delta: exit_wait_window)
    }

    fn get_pool_info(self: @InternalStakerInfoLatest) -> StakerPoolInfo {
        (*self.pool_info).expect_with_err(Error::MISSING_POOL_CONTRACT)
    }

    fn get_total_amount(self: @InternalStakerInfoLatest) -> Amount {
        if let Option::Some(pool_info) = *self.pool_info {
            return pool_info.amount + *self.amount_own;
        }
        (*self.amount_own)
    }
}

impl InternalStakerInfoLatestIntoStakerInfo of Into<InternalStakerInfoLatest, StakerInfo> {
    #[inline(always)]
    fn into(self: InternalStakerInfoLatest) -> StakerInfo nopanic {
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

/// This module is used in tests to verify that changing the storage type from
/// `Option<InternalStakerInfo>` to `VersionedInternalStakerInfo` retains the same `StoragePath`
/// and `StoragePtr`.
///
/// The `#[rename("staker_info")]` attribute ensures the variable name remains consistent,
/// as it is part of the storage path calculation.
#[cfg(test)]
#[starknet::contract]
pub mod VersionedStorageContractTest {
    use starknet::storage::Map;
    use super::{ContractAddress, InternalStakerInfo, VersionedInternalStakerInfo};

    #[storage]
    pub struct Storage {
        #[allow(starknet::colliding_storage_paths)]
        pub staker_info: Map<ContractAddress, Option<InternalStakerInfo>>,
        #[rename("staker_info")]
        pub new_staker_info: Map<ContractAddress, VersionedInternalStakerInfo>,
    }
}
