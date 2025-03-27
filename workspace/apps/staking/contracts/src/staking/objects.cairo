use core::cmp::max;
use core::num::traits::Zero;
use staking::staking::errors::Error;
use staking::staking::interface::{
    CommissionCommitment, IStakingDispatcherTrait, IStakingLibraryDispatcher, StakerInfo,
    StakerPoolInfo, StakerPoolInfoTrait,
};
use staking::types::{Amount, Epoch, Index, InternalStakerInfoLatest};
use starknet::{ClassHash, ContractAddress, get_block_number};
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::types::time::time::{Time, TimeDelta, Timestamp};

const SECONDS_IN_YEAR: u64 = 365 * 24 * 60 * 60;
const STARTING_EPOCH: Epoch = 0;

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

    fn is_zero(self: @UndelegateIntentValue) -> bool {
        *self == Self::zero()
    }

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

#[derive(Debug, Hash, Drop, Serde, Copy, PartialEq, starknet::Store)]
pub(crate) struct EpochInfo {
    // The duration of a block in seconds.
    block_duration: u16,
    // The length of the epoch in blocks.
    length: u16,
    // The first block of the first epoch with this length.
    starting_block: u64,
    // The first epoch id with this length, changes by a call to update.
    starting_epoch: Epoch,
    // The starting block of the epoch prior to the update.
    last_starting_block_before_update: u64,
}

#[generate_trait]
pub(crate) impl EpochInfoImpl of EpochInfoTrait {
    fn new(block_duration: u16, epoch_length: u16, starting_block: u64) -> EpochInfo {
        assert!(epoch_length.is_non_zero(), "{}", Error::INVALID_EPOCH_LENGTH);
        assert!(block_duration.is_non_zero(), "{}", Error::INVALID_BLOCK_DURATION);
        assert!(starting_block >= get_block_number(), "{}", Error::INVALID_STARTING_BLOCK);
        EpochInfo {
            block_duration,
            length: epoch_length,
            starting_block,
            starting_epoch: STARTING_EPOCH,
            last_starting_block_before_update: Zero::zero(),
        }
    }

    /// The current epoch number.
    /// **Note:** This function fails before the first epoch.
    fn current_epoch(self: @EpochInfo) -> Epoch {
        let current_block = get_block_number();
        // If the epoch info updated and the current block is still in the previous epoch.
        if current_block < *self.starting_block {
            return *self.starting_epoch - 1;
        }
        ((current_block - *self.starting_block) / self.epoch_len_in_blocks().into())
            + *self.starting_epoch
    }

    fn update(ref self: EpochInfo, block_duration: u16, epoch_length: u16) {
        assert!(epoch_length.is_non_zero(), "{}", Error::INVALID_EPOCH_LENGTH);
        assert!(block_duration.is_non_zero(), "{}", Error::INVALID_BLOCK_DURATION);
        assert!(get_block_number() >= self.starting_block, "{}", Error::EPOCH_INFO_ALREADY_UPDATED);
        assert!(
            self.current_epoch() != STARTING_EPOCH, "{}", Error::EPOCH_INFO_UPDATED_IN_FIRST_EPOCH,
        );
        self.last_starting_block_before_update = self.current_epoch_starting_block();
        self.starting_epoch = self.next_epoch();
        self.starting_block = self.calculate_next_epoch_starting_block();
        self.length = epoch_length;
        self.block_duration = block_duration;
    }

    fn epochs_in_year(self: @EpochInfo) -> u64 {
        let blocks_in_year = SECONDS_IN_YEAR / (*self.block_duration).into();
        blocks_in_year / self.epoch_len_in_blocks().into()
    }

    fn epoch_len_in_blocks(self: @EpochInfo) -> u16 {
        if get_block_number() < *self.starting_block {
            // There was an update in this epoch, so we need to compute the previous length.
            (*self.starting_block - *self.last_starting_block_before_update).try_into().unwrap()
        } else {
            // No update in this epoch, so we can return the length.
            *self.length
        }
    }

    fn current_epoch_starting_block(self: @EpochInfo) -> u64 {
        if get_block_number() < *self.starting_block {
            // The epoch info updated and the current block is before the starting block of the
            // next epoch with the new length.
            return *self.last_starting_block_before_update;
        }
        self.calculate_next_epoch_starting_block() - self.epoch_len_in_blocks().into()
    }
}

#[generate_trait]
impl PrivateEpochInfoImpl of PrivateEpochInfoTrait {
    fn calculate_next_epoch_starting_block(self: @EpochInfo) -> u64 {
        let current_block = get_block_number();
        let blocks_passed = current_block - *self.starting_block;
        let length: u64 = self.epoch_len_in_blocks().into();
        let blocks_to_next_epoch = length - (blocks_passed % length);
        current_block + blocks_to_next_epoch
    }

    fn next_epoch(self: @EpochInfo) -> Epoch {
        self.current_epoch() + 1
    }
}

#[cfg(test)]
mod epoch_info_tests {
    use core::num::traits::Zero;
    use snforge_std::start_cheat_block_number_global;
    use staking::staking::objects::{EpochInfo, EpochInfoTrait};
    use starknet::get_block_number;

    #[test]
    fn test_new() {
        let block_duration = 1;
        let epoch_length = 1;
        let starting_block = get_block_number();

        let epoch_info = EpochInfoTrait::new(:block_duration, :epoch_length, :starting_block);
        let expected_epoch_info = EpochInfo {
            block_duration,
            length: epoch_length,
            starting_block,
            starting_epoch: Zero::zero(),
            last_starting_block_before_update: Zero::zero(),
        };
        assert_eq!(epoch_info, expected_epoch_info);
    }

    #[test]
    #[should_panic(expected: "Invalid epoch length, must be greater than 0")]
    fn test_new_with_invalid_epoch_length() {
        EpochInfoTrait::new(block_duration: 1, epoch_length: Zero::zero(), starting_block: 1);
    }

    #[test]
    #[should_panic(expected: "Invalid block duration, must be greater than 0")]
    fn test_new_with_invalid_block_duration() {
        EpochInfoTrait::new(block_duration: Zero::zero(), epoch_length: 1, starting_block: 1);
    }

    #[test]
    #[should_panic(
        expected: "Invalid starting block, must be greater than or equal to current block number",
    )]
    fn test_new_with_invalid_starting_block() {
        start_cheat_block_number_global(block_number: 1);
        EpochInfoTrait::new(block_duration: 1, epoch_length: 1, starting_block: Zero::zero());
    }
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
// This struct is used in V0 and should not be in used except for migration purpose.
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
    // **Note**: This field was used in V0 and no longer in use in the new rewards mechanism
    // introduced in V1. Still in use in `pool_migration`.
    pub(crate) _deprecated_index_V0: Index,
    pub(crate) unclaimed_rewards_own: Amount,
    pub(crate) pool_info: Option<StakerPoolInfo>,
    pub(crate) commission_commitment: Option<CommissionCommitment>,
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
    ) -> (InternalStakerInfoV1, Amount) {
        let library_dispatcher = IStakingLibraryDispatcher { class_hash: prev_class_hash };
        let staker_info = library_dispatcher.staker_info(staker_address);
        let internal_staker_info_v1 = InternalStakerInfoV1 {
            reward_address: staker_info.reward_address,
            operational_address: staker_info.operational_address,
            unstake_time: staker_info.unstake_time,
            _deprecated_index_V0: staker_info.index,
            unclaimed_rewards_own: staker_info.unclaimed_rewards_own,
            pool_info: staker_info.pool_info,
            // This assumes that the function is called only during migration. in a different
            // context, the commission commitment will be lost.
            commission_commitment: Option::None,
        };
        (internal_staker_info_v1, staker_info.amount_own)
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
        pool_info: Option<StakerPoolInfo>,
    ) -> VersionedInternalStakerInfo {
        VersionedInternalStakerInfo::V1(
            InternalStakerInfoV1 {
                reward_address,
                operational_address,
                unstake_time: Option::None,
                _deprecated_index_V0: Zero::zero(),
                unclaimed_rewards_own: Zero::zero(),
                pool_info,
                commission_commitment: Option::None,
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
}

impl InternalStakerInfoLatestIntoStakerInfo of Into<InternalStakerInfoLatest, StakerInfo> {
    fn into(self: InternalStakerInfoLatest) -> StakerInfo {
        StakerInfo {
            reward_address: self.reward_address,
            operational_address: self.operational_address,
            unstake_time: self.unstake_time,
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: self.unclaimed_rewards_own,
            pool_info: self.pool_info,
        }
    }
}

#[cfg(test)]
pub(crate) impl StakerInfoIntoInternalStakerInfoV1 of Into<StakerInfo, InternalStakerInfoV1> {
    fn into(self: StakerInfo) -> InternalStakerInfoV1 {
        InternalStakerInfoV1 {
            reward_address: self.reward_address,
            operational_address: self.operational_address,
            unstake_time: self.unstake_time,
            _deprecated_index_V0: self.index,
            unclaimed_rewards_own: self.unclaimed_rewards_own,
            pool_info: self.pool_info,
            // This assumes that the function is called only during migration. in a different
            // context, the commission commitment will be lost.
            commission_commitment: Option::None,
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

#[derive(Serde, Drop, Copy, Debug)]
pub struct AttestationInfo {
    // The address of the staker mapped to the operational address provided.
    staker_address: ContractAddress,
    // The amount of stake the staker has in current epoch.
    stake: Amount,
    // The length of the epoch in blocks.
    epoch_len: u16,
    // The id of the current epoch.
    epoch_id: Epoch,
    // The first block of the current epoch.
    current_epoch_starting_block: u64,
}

#[generate_trait]
pub impl AttestationInfoImpl of AttestationInfoTrait {
    fn new(
        staker_address: ContractAddress,
        stake: Amount,
        epoch_len: u16,
        epoch_id: Epoch,
        current_epoch_starting_block: u64,
    ) -> AttestationInfo {
        AttestationInfo { staker_address, stake, epoch_len, epoch_id, current_epoch_starting_block }
    }

    fn staker_address(self: @AttestationInfo) -> ContractAddress {
        *self.staker_address
    }
    fn stake(self: @AttestationInfo) -> Amount {
        *self.stake
    }
    fn epoch_len(self: @AttestationInfo) -> u16 {
        *self.epoch_len
    }
    fn epoch_id(self: @AttestationInfo) -> Epoch {
        *self.epoch_id
    }
    fn current_epoch_starting_block(self: @AttestationInfo) -> u64 {
        *self.current_epoch_starting_block
    }
    fn get_next_epoch_attestation_info(self: @AttestationInfo) -> AttestationInfo {
        Self::new(
            staker_address: *self.staker_address,
            stake: *self.stake,
            epoch_len: *self.epoch_len,
            epoch_id: *self.epoch_id + 1,
            current_epoch_starting_block: *self.current_epoch_starting_block
                + (*self.epoch_len).into(),
        )
    }
}
