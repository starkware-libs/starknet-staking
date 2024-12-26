use contracts_commons::types::time::Timestamp;
use staking::pool::interface::PoolMemberInfo;
use staking::types::{Amount, Commission, Index};
use starknet::ContractAddress;

#[derive(Debug, Drop, Serde, Copy)]
pub struct SwitchPoolData {
    pub pool_member: ContractAddress,
    pub reward_address: ContractAddress,
}

#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub struct InternalPoolMemberInfo {
    pub reward_address: ContractAddress,
    pub amount: Amount,
    pub index: Index,
    pub unclaimed_rewards: Amount,
    pub commission: Commission,
    pub unpool_amount: Amount,
    pub unpool_time: Option<Timestamp>,
}

pub(crate) impl InternalPoolMemberInfoInto of Into<InternalPoolMemberInfo, PoolMemberInfo> {
    #[inline(always)]
    fn into(self: InternalPoolMemberInfo) -> PoolMemberInfo {
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
mod internal_pool_member_info_tests {
    use core::num::traits::zero::Zero;
    use staking::pool::interface::PoolMemberInfo;
    use super::InternalPoolMemberInfo;

    #[test]
    fn test_into() {
        let internal_pool_member_info = InternalPoolMemberInfo {
            reward_address: Zero::zero(),
            amount: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards: Zero::zero(),
            commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
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
