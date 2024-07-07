use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct PoolerInfo {
    pub reward_address: ContractAddress,
    pub amount: u128,
    pub index: u128,
    pub unclaimed_rewards: u128,
    pub unpool_time: Option<felt252>,
}

#[starknet::interface]
pub trait IPooling<TContractState> {
    fn pool(ref self: TContractState, amount: u128, reward_address: ContractAddress) -> bool;
    fn increase_pool(ref self: TContractState, amount: u128) -> u128;
    fn unpool_intent(ref self: TContractState) -> u128;
    fn unpool_action(ref self: TContractState) -> u128;
    fn claim_rewards(ref self: TContractState, pooler_address: ContractAddress) -> u128;
// fn switch_pool()
// fn enter_from_staking_contract
}
