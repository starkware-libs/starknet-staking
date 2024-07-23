use starknet::ContractAddress;

use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};

// TODO create a different struct for not exposing internal implemenation
#[derive(Debug, Default, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerInfo {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub pooling_contract: Option<ContractAddress>,
    pub unstake_time: Option<felt252>,
    pub amount_own: u128,
    pub amount_pool: u128,
    pub index: u64,
    pub unclaimed_rewards_own: u128,
    pub unclaimed_rewards_pool: u128,
    pub rev_share: u8,
}

#[derive(Debug, Default, Drop, PartialEq, Serde)]
pub struct StakingContractInfo {
    pub max_leverage: u64,
    pub min_stake: u128,
    pub token_address: ContractAddress,
    pub global_index: u64,
}

#[starknet::interface]
pub trait IStaking<TContractState> {
    fn stake(
        ref self: TContractState,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: u128,
        pooling_enabled: bool,
        rev_share: u8,
    ) -> bool;
    fn increase_stake(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> u128;
    fn claim_rewards(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn unstake_intent(ref self: TContractState) -> felt252;
    fn unstake_action(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn add_to_delegation_pool(
        ref self: TContractState, pooled_staker: ContractAddress, amount: u128
    ) -> (u128, u64);
    fn remove_from_delegation_pool_intent(
        ref self: TContractState,
        staker_address: ContractAddress,
        amount: u128,
        identifier: Span<felt252>
    ) -> felt252;
    fn remove_from_delegation_pool_action(
        ref self: TContractState, staker_address: ContractAddress, identifier: Span<felt252>
    ) -> u128;
    fn switch_staking_delegation_pool(
        ref self: TContractState,
        from_staker_address: ContractAddress,
        to_staker_address: ContractAddress,
        to_pool_address: ContractAddress,
        amount: u128,
        data: Span<felt252>
    ) -> bool;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress) -> bool;
    fn set_open_for_delegation(ref self: TContractState) -> ContractAddress;
    fn state_of(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
}
