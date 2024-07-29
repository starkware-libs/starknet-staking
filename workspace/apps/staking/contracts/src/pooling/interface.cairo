use starknet::ContractAddress;

#[derive(Default, Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub struct PoolMemberInfo {
    pub reward_address: ContractAddress,
    pub amount: u128,
    pub index: u64,
    pub unclaimed_rewards: u128,
    pub unpool_time: Option<u64>,
}

use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};

#[starknet::interface]
pub trait IPooling<TContractState> {
    fn enter_delegation_pool(
        ref self: TContractState, amount: u128, reward_address: ContractAddress
    ) -> bool;
    fn add_to_delegation_pool(ref self: TContractState, amount: u128) -> u128;
    fn exit_delegation_pool_intent(ref self: TContractState) -> u128;
    fn exit_delegation_pool_action(ref self: TContractState) -> u128;
    fn claim_rewards(ref self: TContractState, pool_member_address: ContractAddress) -> u128;
    fn switch_delegation_pool(
        ref self: TContractState,
        to_staker_address: ContractAddress,
        to_pool_address: ContractAddress,
        amount: u128
    ) -> u128;
    fn enter_from_staking_contract(
        ref self: TContractState, amount: u128, index: u64, data: Span<felt252>
    ) -> bool;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress) -> bool;
}
