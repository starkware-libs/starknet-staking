use contracts_commons::types::time::time::Timestamp;
use staking::pool::interface::{IPoolDispatcherTrait, IPoolLibraryDispatcher, PoolMemberInfo};
use staking::types::{Amount, Commission, Epoch, Index, InternalPoolMemberInfoLatest};
use starknet::{ClassHash, ContractAddress};

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
    pub(crate) amount: Amount,
    pub(crate) index: Index,
    pub(crate) unclaimed_rewards: Amount,
    pub(crate) commission: Commission,
    pub(crate) unpool_amount: Amount,
    pub(crate) unpool_time: Option<Timestamp>,
    pub(crate) last_claimed_epoch: Epoch,
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
        library_dispatcher.pool_member_info(pool_member).into()
    }
}

// **Note**: This trait must be reimplemented in the next version of Internal Pool Member Info.
#[generate_trait]
pub(crate) impl VInternalPoolMemberInfoImpl of VInternalPoolMemberInfoTrait {
    fn wrap_latest(value: InternalPoolMemberInfoV1) -> VInternalPoolMemberInfo nopanic {
        VInternalPoolMemberInfo::V1(value)
    }

    fn new_latest(
        reward_address: ContractAddress,
        amount: Amount,
        index: Index,
        unclaimed_rewards: Amount,
        commission: Commission,
        unpool_amount: Amount,
        unpool_time: Option<Timestamp>,
        last_claimed_epoch: Epoch,
    ) -> VInternalPoolMemberInfo nopanic {
        VInternalPoolMemberInfo::V1(
            InternalPoolMemberInfoV1 {
                reward_address,
                amount,
                index,
                unclaimed_rewards,
                commission,
                unpool_amount,
                unpool_time,
                last_claimed_epoch,
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
            amount: self.amount,
            index: self.index,
            unclaimed_rewards: self.unclaimed_rewards,
            commission: self.commission,
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
    use super::InternalPoolMemberInfoLatest;

    #[test]
    fn test_into() {
        let internal_pool_member_info = InternalPoolMemberInfoLatest {
            reward_address: Zero::zero(),
            amount: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards: Zero::zero(),
            commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
            last_claimed_epoch: Zero::zero(),
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
        assert_eq!(pool_member_info, expected_pool_member_info);
    }
}
