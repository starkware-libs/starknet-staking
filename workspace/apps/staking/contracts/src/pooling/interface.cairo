use starknet::ContractAddress;

#[derive(Default, Drop, PartialEq, Serde, Copy, starknet::Store)]
pub struct PoolerInfo {
    pub reward_address: ContractAddress,
    pub amount: u64,
    pub index: u128,
    pub unclaimed_rewards: u64,
    pub unpool_time: Option<felt252>,
}

use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};

#[starknet::interface]
pub trait IPooling<TContractState> {
    fn pool(ref self: TContractState, amount: u64, reward_address: ContractAddress) -> bool;
    fn increase_pool(ref self: TContractState, amount: u64) -> u64;
    fn unpool_intent(ref self: TContractState) -> u64;
    fn unpool_action(ref self: TContractState) -> u64;
    fn claim_rewards(ref self: TContractState, pool_member_address: ContractAddress) -> u64;
// fn switch_pool()
// fn enter_from_staking_contract
}
