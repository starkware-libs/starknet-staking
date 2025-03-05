use contracts_commons::types::time::time::Timestamp;
use core::num::traits::zero::Zero;
use staking::pool::objects::InternalPoolMemberInfoV1;
use staking::types::{Amount, Commission, Index, InternalPoolMemberInfoLatest};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IPool<TContractState> {
    fn enter_delegation_pool(
        ref self: TContractState, reward_address: ContractAddress, amount: Amount,
    );
    fn add_to_delegation_pool(
        ref self: TContractState, pool_member: ContractAddress, amount: Amount,
    ) -> Amount;
    fn exit_delegation_pool_intent(ref self: TContractState, amount: Amount);
    fn exit_delegation_pool_action(
        ref self: TContractState, pool_member: ContractAddress,
    ) -> Amount;
    fn claim_rewards(ref self: TContractState, pool_member: ContractAddress) -> Amount;
    fn switch_delegation_pool(
        ref self: TContractState,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        amount: Amount,
    ) -> Amount;
    fn enter_delegation_pool_from_staking_contract(
        ref self: TContractState, amount: Amount, index: Index, data: Span<felt252>,
    );
    fn set_final_staker_index(ref self: TContractState, final_staker_index: Index);
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress);
    fn pool_member_info(self: @TContractState, pool_member: ContractAddress) -> PoolMemberInfo;
    fn get_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> Option<PoolMemberInfo>;
    fn contract_parameters(self: @TContractState) -> PoolContractInfo;
    fn update_commission_from_staking_contract(ref self: TContractState, commission: Commission);
    fn update_rewards_from_staking_contract(
        ref self: TContractState, rewards: Amount, pool_balance: Amount,
    );
}

// **Note**: This trait must be reimplemented in the next version of the contract.
#[starknet::interface]
pub trait IPoolMigration<TContractState> {
    /// Reads the internal pool member information for the given `pool_member` from storage and
    /// returns the latest version of this struct. panic if the pool member does not exist.
    ///
    /// Use this function instead of directly accessing storage to ensure you retrieve the
    /// latest version of the struct. Direct storage access may return an outdated version,
    /// which could be misaligned with the code and probably cause panics.
    fn internal_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> InternalPoolMemberInfoLatest;
    /// Reads the internal pool member information for the given `pool_member` from storage and
    /// returns the latest version of this struct. if the pool member does not exist, returns None.
    fn get_internal_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> Option<InternalPoolMemberInfoLatest>;
}

pub mod Events {
    use contracts_commons::types::time::time::Timestamp;
    use staking::types::Amount;
    use starknet::ContractAddress;

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberExitIntent {
        #[key]
        pub pool_member: ContractAddress,
        pub exit_timestamp: Timestamp,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberExitAction {
        #[key]
        pub pool_member: ContractAddress,
        pub unpool_amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberBalanceChanged {
        #[key]
        pub pool_member: ContractAddress,
        pub old_delegated_stake: Amount,
        pub new_delegated_stake: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberRewardAddressChanged {
        #[key]
        pub pool_member: ContractAddress,
        pub new_address: ContractAddress,
        pub old_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberRewardClaimed {
        #[key]
        pub pool_member: ContractAddress,
        #[key]
        pub reward_address: ContractAddress,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakerRemoved {
        #[key]
        pub staker_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct DeletePoolMember {
        #[key]
        pub pool_member: ContractAddress,
        pub reward_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct NewPoolMember {
        #[key]
        pub pool_member: ContractAddress,
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct SwitchDelegationPool {
        #[key]
        pub pool_member: ContractAddress,
        #[key]
        pub new_delegation_pool: ContractAddress,
        pub amount: Amount,
    }
}

#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub struct PoolMemberInfo {
    pub reward_address: ContractAddress,
    pub amount: Amount,
    pub index: Index,
    pub unclaimed_rewards: Amount,
    pub commission: Commission,
    pub unpool_amount: Amount,
    pub unpool_time: Option<Timestamp>,
}

pub(crate) impl StakerInfoIntoInternalStakerInfoV1 of Into<
    PoolMemberInfo, InternalPoolMemberInfoV1,
> {
    /// This function is used during convertion from `InternalPoolMemberInfo` to
    /// `InternalPoolMemberInfoV1`.
    fn into(self: PoolMemberInfo) -> InternalPoolMemberInfoV1 {
        InternalPoolMemberInfoV1 {
            reward_address: self.reward_address,
            _deprecated_amount: self.amount,
            _deprecated_index: self.index,
            _deprecated_unclaimed_rewards: self.unclaimed_rewards,
            _deprecated_commission: self.commission,
            unpool_amount: self.unpool_amount,
            unpool_time: self.unpool_time,
            entry_to_claim_from: Zero::zero(),
        }
    }
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct PoolContractInfo {
    pub staker_address: ContractAddress,
    pub final_staker_index: Option<Index>, // TODO: remove?
    pub staking_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub commission: Commission,
    pub staker_removed: bool,
}
