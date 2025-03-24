use core::num::traits::Zero;
use staking::pool::interface::{IPoolDispatcherTrait, IPoolLibraryDispatcher, PoolMemberInfo};
use staking::types::{Amount, Commission, Index, InternalPoolMemberInfoLatest, VecIndex};
use starknet::{ClassHash, ContractAddress};
use starkware_utils::types::time::time::Timestamp;

#[derive(Debug, Drop, Serde, Copy)]
pub struct SwitchPoolData {
    pub pool_member: ContractAddress,
    pub reward_address: ContractAddress,
}

#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
struct InternalPoolMemberInfo {
    reward_address: ContractAddress,
    amount: Amount,
    index: Index,
    unclaimed_rewards: Amount,
    commission: Commission,
    unpool_amount: Amount,
    unpool_time: Option<Timestamp>,
}

// **Note**: This struct should be made private in the next version of Internal Pool Member Info.
#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub(crate) struct InternalPoolMemberInfoV1 {
    pub(crate) reward_address: ContractAddress,
    // **Note**: This field was used in V0 and is replaced by `pool_member_epoch_balance` in V1.
    pub(crate) _deprecated_amount: Amount,
    // **Note**: This field was used in V0, in V1, rewards are calculated based on epochs.
    pub(crate) _deprecated_index: Index,
    // **Note**: This field was used in V0, in V1 it only holds unclaimed rewards from before the
    // upgrade.
    pub(crate) _deprecated_unclaimed_rewards: Amount,
    // **Note**: This field was used in V0 for rewards calculation. In V1, rewards are transferred
    // to the pool after commission deduction.
    pub(crate) _deprecated_commission: Commission,
    pub(crate) unpool_amount: Amount,
    pub(crate) unpool_time: Option<Timestamp>,
    // Holds the entry in the member balance trace vector to start claiming rewards from.
    pub(crate) entry_to_claim_from: VecIndex,
}

#[generate_trait]
pub impl InternalPoolMemberInfoLatestImpl of InternalPoolMemberInfoLatestTrait {
    fn new(
        reward_address: ContractAddress, entry_to_claim_from: VecIndex,
    ) -> InternalPoolMemberInfoV1 {
        InternalPoolMemberInfoV1 {
            reward_address,
            _deprecated_amount: Zero::zero(),
            _deprecated_index: Zero::zero(),
            _deprecated_unclaimed_rewards: Zero::zero(),
            _deprecated_commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
            entry_to_claim_from,
        }
    }
}


// **Note**: This struct should be updated in the next version of Internal Pool Member Info.
#[derive(Debug, PartialEq, Serde, Drop, Copy, starknet::Store)]
pub(crate) enum VInternalPoolMemberInfo {
    V0: InternalPoolMemberInfo,
    #[default]
    None,
    V1: InternalPoolMemberInfoV1,
}

// **Note**: This trait must be reimplemented in the next version of Internal Pool Member Info.
#[generate_trait]
pub(crate) impl InternalPoolMemberInfoConvert of InternalPoolMemberInfoConvertTrait {
    fn convert(
        self: InternalPoolMemberInfo, prev_class_hash: ClassHash, pool_member: ContractAddress,
    ) -> InternalPoolMemberInfoV1 {
        let library_dispatcher = IPoolLibraryDispatcher { class_hash: prev_class_hash };
        let pool_member_info = library_dispatcher.pool_member_info(pool_member);
        InternalPoolMemberInfoV1 {
            reward_address: pool_member_info.reward_address,
            _deprecated_amount: pool_member_info.amount,
            _deprecated_index: pool_member_info.index,
            _deprecated_unclaimed_rewards: pool_member_info.unclaimed_rewards,
            _deprecated_commission: pool_member_info.commission,
            unpool_amount: pool_member_info.unpool_amount,
            unpool_time: pool_member_info.unpool_time,
            entry_to_claim_from: Zero::zero(),
        }
    }
}

// **Note**: This trait must be reimplemented in the next version of Internal Pool Member Info.
#[generate_trait]
pub(crate) impl VInternalPoolMemberInfoImpl of VInternalPoolMemberInfoTrait {
    fn wrap_latest(value: InternalPoolMemberInfoV1) -> VInternalPoolMemberInfo nopanic {
        VInternalPoolMemberInfo::V1(value)
    }

    fn new_latest(
        reward_address: ContractAddress, entry_to_claim_from: VecIndex,
    ) -> VInternalPoolMemberInfo {
        VInternalPoolMemberInfo::V1(
            InternalPoolMemberInfoV1 {
                reward_address,
                _deprecated_amount: Zero::zero(),
                _deprecated_index: Zero::zero(),
                _deprecated_unclaimed_rewards: Zero::zero(),
                _deprecated_commission: Zero::zero(),
                unpool_amount: Zero::zero(),
                unpool_time: Option::None,
                entry_to_claim_from,
            },
        )
    }

    fn is_none(self: @VInternalPoolMemberInfo) -> bool nopanic {
        match *self {
            VInternalPoolMemberInfo::None => true,
            _ => false,
        }
    }
}


pub(crate) impl InternalPoolMemberInfoLatestIntoPoolMemberInfo of Into<
    InternalPoolMemberInfoLatest, PoolMemberInfo,
> {
    fn into(self: InternalPoolMemberInfoLatest) -> PoolMemberInfo {
        PoolMemberInfo {
            reward_address: self.reward_address,
            amount: self._deprecated_amount,
            index: self._deprecated_index,
            unclaimed_rewards: self._deprecated_unclaimed_rewards,
            commission: self._deprecated_commission,
            unpool_amount: self.unpool_amount,
            unpool_time: self.unpool_time,
        }
    }
}

#[cfg(test)]
#[generate_trait]
pub(crate) impl VInternalPoolMemberInfoTestImpl of VInternalPoolMemberInfoTestTrait {
    fn new_v0(
        reward_address: ContractAddress,
        amount: Amount,
        index: Index,
        unclaimed_rewards: Amount,
        commission: Commission,
        unpool_amount: Amount,
        unpool_time: Option<Timestamp>,
    ) -> VInternalPoolMemberInfo {
        VInternalPoolMemberInfo::V0(
            InternalPoolMemberInfo {
                reward_address,
                amount,
                index,
                unclaimed_rewards,
                commission,
                unpool_amount,
                unpool_time,
            },
        )
    }
    fn unwrap_latest(self: VInternalPoolMemberInfo) -> InternalPoolMemberInfoLatest {
        match self {
            VInternalPoolMemberInfo::V1(value) => value,
            _ => panic!("Unexpected VInternalPoolMemberInfo version"),
        }
    }
}

#[cfg(test)]
#[generate_trait]
pub(crate) impl InternalPoolMemberInfoTestImpl of InternalPoolMemberInfoTestTrait {
    fn new(
        reward_address: ContractAddress,
        amount: Amount,
        index: Index,
        unclaimed_rewards: Amount,
        commission: Commission,
        unpool_amount: Amount,
        unpool_time: Option<Timestamp>,
    ) -> InternalPoolMemberInfo {
        InternalPoolMemberInfo {
            reward_address,
            amount,
            index,
            unclaimed_rewards,
            commission,
            unpool_amount,
            unpool_time,
        }
    }
}

/// This module is used in tests to verify that changing the storage type from
/// `Option<InternalPoolMemberInfo>` to `VInternalPoolMemberInfo` retains the same `StoragePath`
/// and `StoragePtr`.
///
/// The `#[rename("pool_member_info")]` attribute ensures the variable name remains consistent,
/// as it is part of the storage path calculation.
#[cfg(test)]
#[starknet::contract]
pub mod VStorageContractTest {
    use starknet::storage::Map;
    use super::{ContractAddress, InternalPoolMemberInfo, VInternalPoolMemberInfo};

    #[storage]
    pub struct Storage {
        #[allow(starknet::colliding_storage_paths)]
        pub pool_member_info: Map<ContractAddress, Option<InternalPoolMemberInfo>>,
        #[rename("pool_member_info")]
        pub new_pool_member_info: Map<ContractAddress, VInternalPoolMemberInfo>,
    }
}

#[cfg(test)]
mod internal_pool_member_info_latest_tests {
    use core::num::traits::zero::Zero;
    use staking::pool::interface::PoolMemberInfo;
    use staking::test_utils::constants::POOL_MEMBER_REWARD_ADDRESS;
    use super::{InternalPoolMemberInfoLatest, InternalPoolMemberInfoLatestTrait};

    #[test]
    fn test_into() {
        let internal_pool_member_info = InternalPoolMemberInfoLatest {
            reward_address: Zero::zero(),
            _deprecated_amount: Zero::zero(),
            _deprecated_index: Zero::zero(),
            _deprecated_unclaimed_rewards: Zero::zero(),
            _deprecated_commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
            entry_to_claim_from: Zero::zero(),
        };
        let pool_member_info: PoolMemberInfo = internal_pool_member_info.into();
        let expected_pool_member_info = PoolMemberInfo {
            reward_address: Zero::zero(),
            amount: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards: Zero::zero(),
            commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
        };
        assert!(pool_member_info == expected_pool_member_info);
    }

    #[test]
    fn test_new() {
        let pool_member_info = InternalPoolMemberInfoLatestTrait::new(
            reward_address: POOL_MEMBER_REWARD_ADDRESS(), entry_to_claim_from: Zero::zero(),
        );
        let expected = InternalPoolMemberInfoLatest {
            reward_address: POOL_MEMBER_REWARD_ADDRESS(),
            _deprecated_amount: Zero::zero(),
            _deprecated_index: Zero::zero(),
            _deprecated_unclaimed_rewards: Zero::zero(),
            _deprecated_commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
            entry_to_claim_from: Zero::zero(),
        };
        assert_eq!(pool_member_info, expected);
    }
}

