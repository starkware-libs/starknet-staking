use core::cmp::max;
use core::num::traits::{Pow, Zero};
use core::ops::{AddAssign, SubAssign};
use staking_test::constants::{STARTING_EPOCH, STRK_TOKEN_ADDRESS};
use staking_test::staking::errors::Error;
use staking_test::staking::interface::{CommissionCommitment, StakerInfoV1, StakerPoolInfoV1};
use staking_test::types::{Amount, Commission, Epoch, InternalStakerInfoLatest};
use starknet::storage::{Mutable, StoragePath};
use starknet::{ContractAddress, get_block_number};
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::storage::iterable_map::{
    IterableMap, IterableMapIntoIterImpl, IterableMapReadAccessImpl, IterableMapTrait,
    IterableMapWriteAccessImpl,
};
use starkware_utils::time::time::{Time, TimeDelta, Timestamp};

const SECONDS_IN_YEAR: u64 = 365 * 24 * 60 * 60;

#[derive(Hash, Drop, Serde, Copy, starknet::Store)]
pub struct UndelegateIntentKey {
    pub pool_contract: ContractAddress,
    // The identifier is generally the pool member address, but it can be any unique identifier,
    // depending on the logic of the pool contract.
    pub identifier: felt252,
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct UndelegateIntentValue {
    pub unpool_time: Timestamp,
    pub amount: NormalizedAmount,
    pub token_address: ContractAddress,
}

#[derive(Copy, Drop, Debug, Serde, starknet::Store, PartialEq)]
pub struct NormalizedAmount {
    pub amount_18_decimals: Amount,
}

#[generate_trait]
pub impl NormalizedAmountImpl of NormalizedAmountTrait {
    /// Convert from `Amount` in 18 decimals to `NormalizedAmount`.
    fn from_amount_18_decimals(amount: Amount) -> NormalizedAmount {
        NormalizedAmount { amount_18_decimals: amount }
    }

    /// Convert from `Amount` in the given `decimals` to `NormalizedAmount`.
    fn from_native_amount(amount: Amount, decimals: u8) -> NormalizedAmount {
        assert!(decimals == 18 || decimals == 8, "Unsupported decimals");
        NormalizedAmount { amount_18_decimals: amount * 10_u128.pow(18 - decimals.into()) }
    }

    /// Convert from `Amount` in STRK decimals to `NormalizedAmount`.
    fn from_strk_native_amount(amount: Amount) -> NormalizedAmount {
        NormalizedAmount { amount_18_decimals: amount }
    }

    /// Convert from `NormalizedAmount` to `Amount` in 18 decimals.
    fn to_amount_18_decimals(self: @NormalizedAmount) -> Amount {
        *self.amount_18_decimals
    }

    /// Convert from `NormalizedAmount` to `Amount` in the given `decimals`.
    fn to_native_amount(self: @NormalizedAmount, decimals: u8) -> Amount {
        assert!(decimals == 18 || decimals == 8, "Unsupported decimals");
        *self.amount_18_decimals / 10_u128.pow(18 - decimals.into())
    }

    /// Convert from `NormalizedAmount` to `Amount` in STRK decimals.
    fn to_strk_native_amount(self: @NormalizedAmount) -> Amount {
        *self.amount_18_decimals
    }
}

pub impl NormalizedAmountZero of Zero<NormalizedAmount> {
    fn zero() -> NormalizedAmount {
        NormalizedAmount { amount_18_decimals: Zero::zero() }
    }

    fn is_zero(self: @NormalizedAmount) -> bool {
        self.amount_18_decimals.is_zero()
    }

    fn is_non_zero(self: @NormalizedAmount) -> bool {
        !self.is_zero()
    }
}

pub impl NormalizedAmountAdd of Add<NormalizedAmount> {
    fn add(lhs: NormalizedAmount, rhs: NormalizedAmount) -> NormalizedAmount {
        NormalizedAmount { amount_18_decimals: lhs.amount_18_decimals + rhs.amount_18_decimals }
    }
}

pub impl NormalizedAmountAddAssign of AddAssign<NormalizedAmount, NormalizedAmount> {
    fn add_assign(ref self: NormalizedAmount, rhs: NormalizedAmount) {
        self.amount_18_decimals += rhs.amount_18_decimals;
    }
}

pub impl NormalizedAmountSub of Sub<NormalizedAmount> {
    fn sub(lhs: NormalizedAmount, rhs: NormalizedAmount) -> NormalizedAmount {
        NormalizedAmount { amount_18_decimals: lhs.amount_18_decimals - rhs.amount_18_decimals }
    }
}

pub impl NormalizedAmountSubAssign of SubAssign<NormalizedAmount, NormalizedAmount> {
    fn sub_assign(ref self: NormalizedAmount, rhs: NormalizedAmount) {
        self.amount_18_decimals -= rhs.amount_18_decimals;
    }
}

pub impl NormalizedAmountPartialOrd of PartialOrd<NormalizedAmount> {
    fn lt(lhs: NormalizedAmount, rhs: NormalizedAmount) -> bool {
        lhs.amount_18_decimals < rhs.amount_18_decimals
    }
}

pub impl UndelegateIntentValueZero of core::num::traits::Zero<UndelegateIntentValue> {
    fn zero() -> UndelegateIntentValue {
        UndelegateIntentValue {
            unpool_time: Zero::zero(), amount: Zero::zero(), token_address: Zero::zero(),
        }
    }

    fn is_zero(self: @UndelegateIntentValue) -> bool {
        *self == Self::zero()
    }

    fn is_non_zero(self: @UndelegateIntentValue) -> bool {
        !self.is_zero()
    }
}

#[generate_trait]
pub impl UndelegateIntentValueImpl of UndelegateIntentValueTrait {
    fn is_valid(self: @UndelegateIntentValue) -> bool {
        // The value is valid if and only if unpool_time and amount are both zero or both non-zero.
        self.unpool_time.is_zero() == self.amount.is_zero()
    }

    fn assert_valid(self: @UndelegateIntentValue) {
        assert!(self.is_valid(), "{}", Error::INVALID_UNDELEGATE_INTENT_VALUE);
    }
}

#[derive(Debug, Hash, Drop, Serde, Copy, PartialEq, starknet::Store)]
pub struct EpochInfo {
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
pub impl EpochInfoImpl of EpochInfoTrait {
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
    use staking_test::staking::objects::{EpochInfo, EpochInfoTrait};
    use staking_test::test_utils::constants::{EPOCH_DURATION, EPOCH_LENGTH, EPOCH_STARTING_BLOCK};
    use starknet::get_block_number;
    use starkware_utils_testing::test_utils::advance_block_number_global;
    use super::SECONDS_IN_YEAR;

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

    #[test]
    fn test_epoch_len_in_blocks() {
        let old_epoch_duration = EPOCH_DURATION;
        let old_epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(
            epoch_duration: old_epoch_duration, epoch_length: old_epoch_length, :starting_block,
        );
        assert!(epoch_info.epoch_len_in_blocks() == old_epoch_length);

        // Updates epoch info.
        let new_epoch_duration = old_epoch_duration * 15;
        let new_epoch_length = old_epoch_length * 15;
        advance_block_number_global(blocks: old_epoch_length.into());
        epoch_info.update(epoch_duration: new_epoch_duration, epoch_length: new_epoch_length);

        // Assert that the epoch length remains unchanged in the same epoch.
        assert!(epoch_info.epoch_len_in_blocks() == old_epoch_length);

        // Assert that the epoch length is updated after advancing epoch.
        advance_block_number_global(blocks: old_epoch_length.into());
        assert!(epoch_info.epoch_len_in_blocks() == new_epoch_length);
    }

    #[test]
    fn test_update() {
        let old_epoch_duration = EPOCH_DURATION;
        let old_epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(
            epoch_duration: old_epoch_duration, epoch_length: old_epoch_length, :starting_block,
        );
        advance_block_number_global(blocks: old_epoch_length.into());

        let new_epoch_duration = old_epoch_duration * 15;
        let new_epoch_length = old_epoch_length * 15;
        let expected_epoch_info = EpochInfo {
            epoch_duration: new_epoch_duration,
            length: new_epoch_length,
            starting_block: epoch_info.current_epoch_starting_block() + epoch_info.length.into(),
            starting_epoch: epoch_info.current_epoch() + 1,
            previous_length: epoch_info.length,
            previous_epoch_duration: epoch_info.epoch_duration,
        };
        epoch_info.update(epoch_duration: new_epoch_duration, epoch_length: new_epoch_length);
        assert!(epoch_info == expected_epoch_info);
    }

    #[test]
    #[should_panic(expected: "Invalid epoch length, must be greater than 0")]
    fn test_update_with_invalid_epoch_length() {
        let epoch_duration = EPOCH_DURATION;
        let epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(:epoch_duration, :epoch_length, :starting_block);
        advance_block_number_global(blocks: epoch_length.into());

        epoch_info.update(:epoch_duration, epoch_length: Zero::zero());
    }

    #[test]
    #[should_panic(expected: "Invalid epoch duration, must be greater than 0")]
    fn test_update_with_invalid_epoch_duration() {
        let epoch_duration = EPOCH_DURATION;
        let epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(:epoch_duration, :epoch_length, :starting_block);
        advance_block_number_global(blocks: epoch_length.into());

        epoch_info.update(epoch_duration: Zero::zero(), :epoch_length);
    }

    #[test]
    #[should_panic(expected: "Epoch info already updated in this epoch")]
    fn test_update_twice() {
        let epoch_duration = EPOCH_DURATION;
        let epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(:epoch_duration, :epoch_length, :starting_block);
        advance_block_number_global(blocks: epoch_length.into());

        epoch_info.update(:epoch_duration, :epoch_length);
        epoch_info.update(:epoch_duration, :epoch_length);
    }

    #[test]
    #[should_panic(expected: "Epoch info can not be updated in the first epoch")]
    fn test_update_in_first_epoch() {
        let epoch_duration = EPOCH_DURATION;
        let epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(:epoch_duration, :epoch_length, :starting_block);

        epoch_info.update(:epoch_duration, :epoch_length);
    }

    #[test]
    fn test_epochs_in_year() {
        let old_epoch_duration = EPOCH_DURATION;
        let old_epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(
            epoch_duration: old_epoch_duration, epoch_length: old_epoch_length, :starting_block,
        );
        assert!(epoch_info.epochs_in_year() == SECONDS_IN_YEAR / old_epoch_duration.into());

        let new_epoch_duration = old_epoch_duration * 15;
        let new_epoch_length = old_epoch_length * 15;
        advance_block_number_global(blocks: old_epoch_length.into());
        epoch_info.update(epoch_duration: new_epoch_duration, epoch_length: new_epoch_length);
        assert!(epoch_info.epochs_in_year() == SECONDS_IN_YEAR / old_epoch_duration.into());

        advance_block_number_global(blocks: old_epoch_length.into());
        assert!(epoch_info.epochs_in_year() == SECONDS_IN_YEAR / new_epoch_duration.into());
    }

    #[test]
    fn test_current_epoch() {
        let epoch_duration = EPOCH_DURATION;
        let old_epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(
            :epoch_duration, epoch_length: old_epoch_length, :starting_block,
        );
        let current_epoch_before = epoch_info.current_epoch();

        advance_block_number_global(blocks: old_epoch_length.into() - 1);
        assert!(epoch_info.current_epoch() == current_epoch_before);

        advance_block_number_global(blocks: 1);
        assert!(epoch_info.current_epoch() == current_epoch_before + 1);

        // Updates epoch info.
        let new_epoch_length = old_epoch_length * 15;
        let current_epoch_before = epoch_info.current_epoch();
        epoch_info.update(:epoch_duration, epoch_length: new_epoch_length);

        assert!(epoch_info.current_epoch() == current_epoch_before);

        advance_block_number_global(blocks: old_epoch_length.into() - 1);
        assert!(epoch_info.current_epoch() == current_epoch_before);

        advance_block_number_global(blocks: 1);
        assert!(epoch_info.current_epoch() == current_epoch_before + 1);

        advance_block_number_global(blocks: new_epoch_length.into() - 1);
        assert!(epoch_info.current_epoch() == current_epoch_before + 1);

        advance_block_number_global(blocks: 1);
        assert!(epoch_info.current_epoch() == current_epoch_before + 2);
    }

    #[test]
    fn test_current_epoch_starting_block() {
        let epoch_duration = EPOCH_DURATION;
        let old_epoch_length = EPOCH_LENGTH;
        let starting_block = EPOCH_STARTING_BLOCK;
        start_cheat_block_number_global(block_number: starting_block);
        let mut epoch_info = EpochInfoTrait::new(
            :epoch_duration, epoch_length: old_epoch_length, :starting_block,
        );

        let mut expected_epoch_starting_block = starting_block;
        advance_block_number_global(blocks: old_epoch_length.into() - 1);
        assert!(epoch_info.current_epoch_starting_block() == expected_epoch_starting_block);

        advance_block_number_global(blocks: 1);
        expected_epoch_starting_block += old_epoch_length.into();
        assert!(epoch_info.current_epoch_starting_block() == expected_epoch_starting_block);

        // Updates epoch info.
        let new_epoch_length = old_epoch_length.into() * 15;
        epoch_info.update(:epoch_duration, epoch_length: new_epoch_length);

        advance_block_number_global(blocks: old_epoch_length.into() - 1);
        assert!(epoch_info.current_epoch_starting_block() == expected_epoch_starting_block);

        advance_block_number_global(blocks: 1);
        expected_epoch_starting_block += old_epoch_length.into();
        assert!(epoch_info.current_epoch_starting_block() == expected_epoch_starting_block);

        advance_block_number_global(blocks: new_epoch_length.into() - 1);
        assert!(epoch_info.current_epoch_starting_block() == expected_epoch_starting_block);

        advance_block_number_global(blocks: 1);
        expected_epoch_starting_block += new_epoch_length.into();
        assert!(epoch_info.current_epoch_starting_block() == expected_epoch_starting_block);
    }
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct InternalStakerPoolInfoV1 {
    pub _deprecated_pool_contract: ContractAddress,
    pub _deprecated_commission: Commission,
}

#[starknet::storage_node]
pub struct InternalStakerPoolInfoV2 {
    /// Commission for all pools. Indicates if pools are enabled.
    pub commission: Option<Commission>,
    /// Map pool contract to their token address.
    pub pools: IterableMap<ContractAddress, ContractAddress>,
    /// The commitment to the commission.
    pub commission_commitment: Option<CommissionCommitment>,
}

#[generate_trait]
pub impl InternalStakerPoolInfoV2Impl of InternalStakerPoolInfoV2Trait {
    fn commission(self: StoragePath<InternalStakerPoolInfoV2>) -> Commission {
        self.commission.read().expect_with_err(Error::COMMISSION_NOT_SET)
    }

    fn commission_commitment(self: StoragePath<InternalStakerPoolInfoV2>) -> CommissionCommitment {
        self.commission_commitment.read().expect_with_err(Error::COMMISSION_COMMITMENT_NOT_SET)
    }

    fn get_strk_pool(self: StoragePath<InternalStakerPoolInfoV2>) -> Option<ContractAddress> {
        for (pool_contract, token_address) in self.pools {
            if token_address == STRK_TOKEN_ADDRESS {
                return Option::Some(pool_contract);
            }
        }
        Option::None
    }
}

#[generate_trait]
pub impl InternalStakerPoolInfoV2MutImpl of InternalStakerPoolInfoV2MutTrait {
    fn commission(self: StoragePath<Mutable<InternalStakerPoolInfoV2>>) -> Commission {
        self.commission.read().expect_with_err(Error::COMMISSION_NOT_SET)
    }

    fn get_pool_token(
        self: StoragePath<Mutable<InternalStakerPoolInfoV2>>, pool_contract: ContractAddress,
    ) -> Option<ContractAddress> {
        self.pools.read(pool_contract)
    }

    fn get_pools(self: StoragePath<Mutable<InternalStakerPoolInfoV2>>) -> Span<ContractAddress> {
        let mut pools: Array<ContractAddress> = array![];
        for (pool_contract, _) in self.pools {
            pools.append(pool_contract);
        }
        pools.span()
    }

    /// Returns true if the staker has a pool.
    fn has_pool(self: StoragePath<Mutable<InternalStakerPoolInfoV2>>) -> bool {
        self.pools.len() > 0
    }

    fn has_pool_for_token(
        self: StoragePath<Mutable<InternalStakerPoolInfoV2>>, token_address: ContractAddress,
    ) -> bool {
        for (_, pool_token_address) in self.pools {
            if pool_token_address == token_address {
                return true;
            }
        }
        false
    }
}

// **Note**: This struct should be made private in the next version of Internal Staker Info.
#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct InternalStakerInfoV1 {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<Timestamp>,
    pub unclaimed_rewards_own: Amount,
    pub _deprecated_pool_info: Option<InternalStakerPoolInfoV1>,
    pub _deprecated_commission_commitment: Option<CommissionCommitment>,
}

// **Note**: This struct should be updated in the next version of Internal Staker Info.
#[derive(Debug, PartialEq, Drop, Copy, starknet::Store)]
pub enum VersionedInternalStakerInfo {
    #[default]
    None,
    V0: (),
    V1: InternalStakerInfoV1,
}

#[generate_trait]
pub impl VersionedInternalStakerInfoImpl of VersionedInternalStakerInfoTrait {
    fn wrap_latest(value: InternalStakerInfoV1) -> VersionedInternalStakerInfo nopanic {
        VersionedInternalStakerInfo::V1(value)
    }

    fn new_latest(
        reward_address: ContractAddress, operational_address: ContractAddress,
    ) -> VersionedInternalStakerInfo {
        VersionedInternalStakerInfo::V1(
            InternalStakerInfoV1 {
                reward_address,
                operational_address,
                unstake_time: Option::None,
                unclaimed_rewards_own: Zero::zero(),
                _deprecated_pool_info: Option::None,
                _deprecated_commission_commitment: Option::None,
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
pub impl InternalStakerInfoLatestImpl of InternalStakerInfoLatestTrait {
    fn compute_unpool_time(
        self: @InternalStakerInfoLatest, exit_wait_window: TimeDelta,
    ) -> Timestamp {
        if let Option::Some(unstake_time) = *self.unstake_time {
            return max(unstake_time, Time::now());
        }
        Time::now().add(delta: exit_wait_window)
    }
}

#[generate_trait]
pub impl InternalStakerInfoLatestTestImpl of InternalStakerInfoLatestTestTrait {
    fn _deprecated_get_pool_info(self: @InternalStakerInfoLatest) -> InternalStakerPoolInfoV1 {
        (*self._deprecated_pool_info).expect_with_err(Error::MISSING_POOL_CONTRACT)
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
            pool_info: match self._deprecated_pool_info {
                Option::Some(pool_info) => Option::Some(
                    StakerPoolInfoV1 {
                        pool_contract: pool_info._deprecated_pool_contract,
                        amount: Zero::zero(),
                        commission: pool_info._deprecated_commission,
                    },
                ),
                Option::None => Option::None,
            },
        }
    }
}

#[cfg(test)]
#[generate_trait]
pub impl StakerInfoIntoInternalStakerInfoV1Impl of StakerInfoIntoInternalStakerInfoV1ITrait {
    fn to_internal(self: StakerInfoV1) -> InternalStakerInfoV1 {
        InternalStakerInfoV1 {
            reward_address: self.reward_address,
            operational_address: self.operational_address,
            unstake_time: self.unstake_time,
            unclaimed_rewards_own: self.unclaimed_rewards_own,
            _deprecated_pool_info: match self.pool_info {
                Option::Some(pool_info) => Option::Some(
                    InternalStakerPoolInfoV1 {
                        _deprecated_pool_contract: pool_info.pool_contract,
                        _deprecated_commission: pool_info.commission,
                    },
                ),
                Option::None => Option::None,
            },
            // This assumes that the function is called only during migration. in a different
            // context, the commission commitment will be lost.
            _deprecated_commission_commitment: Option::None,
        }
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
}
