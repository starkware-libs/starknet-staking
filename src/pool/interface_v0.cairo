#[cfg(test)]
use core::num::traits::Zero;
use staking::pool::interface::PoolMemberInfoV1;
#[cfg(test)]
use staking::pool::objects::InternalPoolMemberInfoV1;
#[cfg(test)]
use staking::pool::pool_member_balance_trace::trace::PoolMemberCheckpointTrait;
use staking::types::{Amount, Commission, Index};
use starknet::ContractAddress;
use starkware_utils::time::time::Timestamp;

/// Pool V0 interface.
#[starknet::interface]
pub trait IPoolV0<TContractState> {
    fn pool_member_info(self: @TContractState, pool_member: ContractAddress) -> PoolMemberInfo;
    fn get_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> Option<PoolMemberInfo>;
    fn enter_delegation_pool(
        ref self: TContractState, reward_address: ContractAddress, amount: Amount,
    );
    fn exit_delegation_pool_intent(ref self: TContractState, amount: Amount);
}

/// Pool member info used in V0.
/// **Note**: This struct should not be used in V1. It should only be used for testing and migration
/// purposes.
#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub struct PoolMemberInfo {
    /// Address to send the member's rewards to.
    pub reward_address: ContractAddress,
    /// The pool member's balance.
    pub amount: Amount,
    /// Deprecated field previously used in rewards calculation.
    pub index: Index,
    /// The amount of unclaimed rewards for the pool member.
    pub unclaimed_rewards: Amount,
    /// The commission the staker takes from the pool rewards.
    pub commission: Commission,
    /// Amount of funds pending to be removed from the pool.
    pub unpool_amount: Amount,
    /// If the pool member has shown intent to unpool,
    /// this is the timestamp of when they could do that.
    /// Else, it is None.
    pub unpool_time: Option<Timestamp>,
}

#[generate_trait]
pub(crate) impl PoolMemberInfoImpl of PoolMemberInfoTrait {
    fn to_v1(self: PoolMemberInfo) -> PoolMemberInfoV1 {
        PoolMemberInfoV1 {
            reward_address: self.reward_address,
            amount: self.amount,
            unclaimed_rewards: self.unclaimed_rewards,
            commission: self.commission,
            unpool_amount: self.unpool_amount,
            unpool_time: self.unpool_time,
        }
    }
}

#[cfg(test)]
#[generate_trait]
pub(crate) impl PoolMemberInfoIntoInternalPoolMemberInfoV1Impl of PoolMemberInfoIntoInternalPoolMemberInfoV1Trait {
    fn to_internal(self: PoolMemberInfo) -> InternalPoolMemberInfoV1 {
        InternalPoolMemberInfoV1 {
            reward_address: self.reward_address,
            _deprecated_amount: self.amount,
            _deprecated_index: self.index,
            _unclaimed_rewards_from_v0: self.unclaimed_rewards,
            _deprecated_commission: self.commission,
            unpool_amount: self.unpool_amount,
            unpool_time: self.unpool_time,
            entry_to_claim_from: Zero::zero(),
            reward_checkpoint: PoolMemberCheckpointTrait::new(
                epoch: Zero::zero(),
                balance: self.amount,
                cumulative_rewards_trace_idx: Zero::zero(),
            ),
        }
    }
}
