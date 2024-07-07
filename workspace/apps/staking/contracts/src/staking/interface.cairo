use starknet::ContractAddress;


// TODO create a different struct for not exposing internal implemenation
#[derive(Drop, Serde, starknet::Store)]
pub struct StakerInfo {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<felt252>,
    pub amount: u128,
    pub index: u128,
    pub unclaimed_rewards: u128,
}


#[derive(Drop, Serde)]
pub struct StakingContractInfo {
    pub max_leverage: u128,
    pub min_stake: u128,
}

#[starknet::interface]
pub trait IStaking<TContractState> {
    fn stake(
        ref self: TContractState,
        staker_address: ContractAddress,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: u128,
        pooling_enabled: bool
    ) -> bool;
    fn increase_stake(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> u128;
    fn claim_rewards(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn unstake_intent(ref self: TContractState, staker_address: ContractAddress) -> felt252;
    fn unstake_action(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn add_to_pool(ref self: TContractState, staker_address: ContractAddress, amount: u128) -> u128;
    fn remove_from_pool_intent(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> felt252;
    fn remove_from_pool_action(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn switch_pool(
        ref self: TContractState,
        from_staker_address: ContractAddress,
        to_staker_address: ContractAddress,
        pool_address: ContractAddress,
        amount: u128,
        data: ByteArray
    ) -> bool;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress) -> bool;
    fn set_open_for_pooling(ref self: TContractState) -> ContractAddress;
    fn state_of(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
}
