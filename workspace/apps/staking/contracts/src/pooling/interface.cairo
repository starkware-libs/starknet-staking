use starknet::ContractAddress;

pub mod Events {
    use starknet::ContractAddress;

    #[derive(Drop, starknet::Event)]
    pub(crate) struct PoolMemberExitIntent {
        #[key]
        pub pool_member: ContractAddress,
        pub exit_timestamp: u64,
        pub amount: u128
    }

    #[derive(Drop, starknet::Event)]
    pub(crate) struct DelegationBalanceChange {
        #[key]
        pub pool_member: ContractAddress,
        pub old_delegated_stake: u128,
        pub new_delegated_stake: u128
    }

    #[derive(Drop, starknet::Event)]
    pub(crate) struct PoolMemberRewardAddressChanged {
        #[key]
        pub pool_member: ContractAddress,
        pub new_address: ContractAddress,
        pub old_address: ContractAddress
    }
}

#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub struct PoolMemberInfo {
    pub reward_address: ContractAddress,
    pub amount: u128,
    pub index: u64,
    pub unclaimed_rewards: u128,
    pub unpool_time: Option<u64>,
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct PoolingContractInfo {
    pub staker_address: ContractAddress,
    pub final_staker_index: Option<u64>,
    pub staking_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub commission: u16,
}

#[starknet::interface]
pub trait IPooling<TContractState> {
    fn enter_delegation_pool(
        ref self: TContractState, amount: u128, reward_address: ContractAddress
    ) -> bool;
    fn add_to_delegation_pool(
        ref self: TContractState, pool_member: ContractAddress, amount: u128
    ) -> u128;
    fn exit_delegation_pool_intent(ref self: TContractState);
    fn exit_delegation_pool_action(ref self: TContractState, pool_member: ContractAddress) -> u128;
    fn claim_rewards(ref self: TContractState, pool_member: ContractAddress) -> u128;
    fn switch_delegation_pool(
        ref self: TContractState, to_staker: ContractAddress, to_pool: ContractAddress, amount: u128
    ) -> u128;
    fn enter_delegation_pool_from_staking_contract(
        ref self: TContractState, amount: u128, index: u64, data: Span<felt252>
    ) -> bool;
    fn set_final_staker_index(ref self: TContractState, final_staker_index: u64);
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress) -> bool;
    fn state_of(self: @TContractState, pool_member: ContractAddress) -> PoolMemberInfo;
    fn contract_parameters(self: @TContractState) -> PoolingContractInfo;
}
