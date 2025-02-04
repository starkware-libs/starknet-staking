use contracts_commons::types::time::time::Timestamp;
use staking::types::{Amount, Commission, Index};
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
}

pub mod Events {
    use contracts_commons::types::time::time::Timestamp;
    use staking::types::{Amount, Index};
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
    pub struct FinalIndexSet {
        #[key]
        pub staker_address: ContractAddress,
        pub final_staker_index: Index,
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
    pub new_amount: u256,
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct PoolContractInfo {
    pub staker_address: ContractAddress,
    pub final_staker_index: Option<Index>,
    pub staking_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub commission: Commission,
}
