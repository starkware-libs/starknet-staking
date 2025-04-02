use core::cmp::max;
use core::num::traits::Zero;
use staking::constants::STARTING_EPOCH;
use staking::staking::errors::Error;
use staking::staking::interface::{CommissionCommitment, StakerInfo, StakerInfoV1, StakerPoolInfo};
use staking::staking::interface_v0::{IStakingV0DispatcherTrait, IStakingV0LibraryDispatcher};
use staking::types::{Amount, Commission, Epoch, Index, InternalStakerInfoLatest};
use starknet::{ClassHash, ContractAddress, get_block_number};
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::types::time::time::{Time, TimeDelta, Timestamp};

const SECONDS_IN_YEAR: u64 = 365 * 24 * 60 * 60;

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
    // The duration of the epoch in seconds.
    epoch_duration: u32,
    // The length of the epoch in blocks.
    length: u32,
    // The first block of the first epoch with this length.
    starting_block: u64,
    // The first epoch id with this length, changes by a call to update.
    starting_epoch: Epoch,
    // The length of the epoch prior to the update.
    previous_length: u32,
    // The duration of the epoch prior to the update.
    previous_epoch_duration: u32,
}

#[generate_trait]
pub(crate) impl EpochInfoImpl of EpochInfoTrait {
    /// Create a new epoch info object. this should happen once, and is initializing the epoch info
    /// to the starting epoch.
    fn new(epoch_duration: u32, epoch_length: u32, starting_block: u64) -> EpochInfo {
        assert!(epoch_length.is_non_zero(), "{}", Error::INVALID_EPOCH_LENGTH);
        assert!(epoch_duration.is_non_zero(), "{}", Error::INVALID_EPOCH_DURATION);
        assert!(starting_block >= get_block_number(), "{}", Error::INVALID_STARTING_BLOCK);
        EpochInfo {
            epoch_duration,
            length: epoch_length,
            starting_block,
            starting_epoch: STARTING_EPOCH,
            previous_length: Zero::zero(),
            previous_epoch_duration: Zero::zero(),
        }
    }

    /// Get the current epoch number.
    /// **Note:** This function fails before the first epoch.
    fn current_epoch(self: @EpochInfo) -> Epoch {
        if self.update_done_in_this_epoch() {
            return *self.starting_epoch - 1;
        }
        ((get_block_number() - *self.starting_block) / self.epoch_len_in_blocks().into())
            + *self.starting_epoch
    }

    /// Update the epoch info.
    fn update(ref self: EpochInfo, epoch_duration: u32, epoch_length: u32) {
        assert!(epoch_length.is_non_zero(), "{}", Error::INVALID_EPOCH_LENGTH);
        assert!(epoch_duration.is_non_zero(), "{}", Error::INVALID_EPOCH_DURATION);
        assert!(get_block_number() >= self.starting_block, "{}", Error::EPOCH_INFO_ALREADY_UPDATED);
        assert!(
            self.current_epoch() != STARTING_EPOCH, "{}", Error::EPOCH_INFO_UPDATED_IN_FIRST_EPOCH,
        );
        self =
            EpochInfo {
                epoch_duration,
                length: epoch_length,
                starting_block: self.current_epoch_starting_block() + self.length.into(),
                starting_epoch: self.next_epoch(),
                previous_length: self.length,
                previous_epoch_duration: self.epoch_duration,
            }
    }

    /// Get the number of expected epochs in a year base on the current epoch duration.
    fn epochs_in_year(self: @EpochInfo) -> u64 {
        let epoch_duration = if self.update_done_in_this_epoch() {
            self.previous_epoch_duration
        } else {
            self.epoch_duration
        };
        SECONDS_IN_YEAR / (*epoch_duration).into()
    }

    /// Get the number of blocks in the current epoch.
    fn epoch_len_in_blocks(self: @EpochInfo) -> u32 {
        if self.update_done_in_this_epoch() {
            return *self.previous_length;
        }
        (*self.length)
    }

    /// Get the starting block of the current epoch.
    fn current_epoch_starting_block(self: @EpochInfo) -> u64 {
        if self.update_done_in_this_epoch() {
            // The epoch info updated and the current block is before the starting block of the
            // next epoch with the new length.
            return *self.starting_block - (*self.previous_length).into();
        }
        let num_epochs_from_starting = (get_block_number() - *self.starting_block)
            / (*self.length).into();
        *self.starting_block + num_epochs_from_starting * (*self.length).into()
    }
}

#[generate_trait]
impl PrivateEpochInfoImpl of PrivateEpochInfoTrait {
    fn next_epoch(self: @EpochInfo) -> Epoch {
        self.current_epoch() + 1
    }

    fn update_done_in_this_epoch(self: @EpochInfo) -> bool {
        get_block_number() < *self.starting_block
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
        let epoch_duration = 1;
        let epoch_length = 1;
        let starting_block = get_block_number();

        let epoch_info = EpochInfoTrait::new(:epoch_duration, :epoch_length, :starting_block);
        let expected_epoch_info = EpochInfo {
            epoch_duration,
            length: epoch_length,
            starting_block,
            starting_epoch: Zero::zero(),
            previous_length: Zero::zero(),
            previous_epoch_duration: Zero::zero(),
        };
        assert_eq!(epoch_info, expected_epoch_info);
    }

    #[test]
    #[should_panic(expected: "Invalid epoch length, must be greater than 0")]
    fn test_new_with_invalid_epoch_length() {
        EpochInfoTrait::new(epoch_duration: 1, epoch_length: Zero::zero(), starting_block: 1);
    }

    #[test]
    #[should_panic(expected: "Invalid epoch duration, must be greater than 0")]
    fn test_new_with_invalid_epoch_duration() {
        EpochInfoTrait::new(epoch_duration: Zero::zero(), epoch_length: 1, starting_block: 1);
    }

    #[test]
    #[should_panic(
        expected: "Invalid starting block, must be greater than or equal to current block number",
    )]
    fn test_new_with_invalid_starting_block() {
        start_cheat_block_number_global(block_number: 1);
        EpochInfoTrait::new(epoch_duration: 1, epoch_length: 1, starting_block: Zero::zero());
    }
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct InternalStakerPoolInfoV1 {
    pub pool_contract: ContractAddress,
    pub commission: Commission,
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
    pub(crate) unclaimed_rewards_own: Amount,
    pub(crate) pool_info: Option<InternalStakerPoolInfoV1>,
    pub(crate) commission_commitment: Option<CommissionCommitment>,
}

// **Note**: This struct should be updated in the next version of Internal Staker Info.
#[derive(Debug, PartialEq, Drop, Copy, starknet::Store)]
pub(crate) enum VersionedInternalStakerInfo {
    #[default]
    None,
    V0: InternalStakerInfo,
    V1: InternalStakerInfoV1,
}

// **Note**: This trait must be reimplemented in the next version of Internal Staker Info.
#[generate_trait]
pub(crate) impl InternalStakerInfoConvert of InternalStakerInfoConvertTrait {
    fn convert(
        self: InternalStakerInfo, prev_class_hash: ClassHash, staker_address: ContractAddress,
    ) -> (InternalStakerInfoV1, Amount, Index, Amount, Amount) {
        let library_dispatcher = IStakingV0LibraryDispatcher { class_hash: prev_class_hash };
        let staker_info: StakerInfo = library_dispatcher.staker_info(:staker_address);
        let internal_staker_info_v1 = InternalStakerInfoV1 {
            reward_address: staker_info.reward_address,
            operational_address: staker_info.operational_address,
            unstake_time: staker_info.unstake_time,
            unclaimed_rewards_own: staker_info.unclaimed_rewards_own,
            pool_info: match staker_info.pool_info {
                Option::Some(pool_info) => Option::Some(
                    InternalStakerPoolInfoV1 {
                        pool_contract: pool_info.pool_contract, commission: pool_info.commission,
                    },
                ),
                Option::None => Option::None,
            },
            // This assumes that the function is called only during migration. in a different
            // context, the commission commitment will be lost.
            commission_commitment: Option::None,
        };
        let (pool_unclaimed_rewards, pool_amount) = match staker_info.pool_info {
            Option::Some(pool_info) => (pool_info.unclaimed_rewards, pool_info.amount),
            Option::None => (Zero::zero(), Zero::zero()),
        };
        (
            internal_staker_info_v1,
            staker_info.amount_own,
            staker_info.index,
            pool_unclaimed_rewards,
            pool_amount,
        )
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
        pool_info: Option<InternalStakerPoolInfoV1>,
    ) -> VersionedInternalStakerInfo {
        VersionedInternalStakerInfo::V1(
            InternalStakerInfoV1 {
                reward_address,
                operational_address,
                unstake_time: Option::None,
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

    fn get_pool_info(self: @InternalStakerInfoLatest) -> InternalStakerPoolInfoV1 {
        (*self.pool_info).expect_with_err(Error::MISSING_POOL_CONTRACT)
    }
}

impl InternalStakerInfoLatestIntoStakerInfoV1 of Into<InternalStakerInfoLatest, StakerInfoV1> {
    fn into(self: InternalStakerInfoLatest) -> StakerInfoV1 {
        StakerInfoV1 {
            reward_address: self.reward_address,
            operational_address: self.operational_address,
            unstake_time: self.unstake_time,
            amount_own: Zero::zero(),
            unclaimed_rewards_own: self.unclaimed_rewards_own,
            pool_info: match self.pool_info {
                Option::Some(pool_info) => Option::Some(
                    StakerPoolInfo {
                        pool_contract: pool_info.pool_contract,
                        amount: Zero::zero(),
                        unclaimed_rewards: Zero::zero(),
                        commission: pool_info.commission,
                    },
                ),
                Option::None => Option::None,
            },
        }
    }
}

#[cfg(test)]
pub(crate) impl StakerInfoIntoInternalStakerInfoV1 of Into<StakerInfoV1, InternalStakerInfoV1> {
    fn into(self: StakerInfoV1) -> InternalStakerInfoV1 {
        InternalStakerInfoV1 {
            reward_address: self.reward_address,
            operational_address: self.operational_address,
            unstake_time: self.unstake_time,
            unclaimed_rewards_own: self.unclaimed_rewards_own,
            pool_info: match self.pool_info {
                Option::Some(pool_info) => Option::Some(
                    InternalStakerPoolInfoV1 {
                        pool_contract: pool_info.pool_contract, commission: pool_info.commission,
                    },
                ),
                Option::None => Option::None,
            },
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
    epoch_len: u32,
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
        epoch_len: u32,
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
    fn epoch_len(self: @AttestationInfo) -> u32 {
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
