use starknet::ContractAddress;

pub mod Events {
    use starknet::ContractAddress;

    #[derive(Drop, starknet::Event)]
    pub struct PoolMemberExitIntent {
        #[key]
        pub pool_member: ContractAddress,
        pub exit_timestamp: u64,
        pub amount: u128
    }

    #[derive(Drop, starknet::Event)]
    pub struct DelegationPoolMemberBalanceChanged {
        #[key]
        pub pool_member: ContractAddress,
        pub old_delegated_stake: u128,
        pub new_delegated_stake: u128
    }

    #[derive(Drop, starknet::Event)]
    pub struct PoolMemberRewardAddressChanged {
        #[key]
        pub pool_member: ContractAddress,
        pub new_address: ContractAddress,
        pub old_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct PoolMemberRewardClaimed {
        #[key]
        pub pool_member: ContractAddress,
        #[key]
        pub reward_address: ContractAddress,
        pub amount: u128
    }

    #[derive(Drop, starknet::Event)]
    pub struct FinalIndexSet {
        #[key]
        pub staker_address: ContractAddress,
        pub final_staker_index: u64
    }

    #[derive(Drop, starknet::Event)]
    pub struct DeletePoolMember {
        #[key]
        pub pool_member: ContractAddress,
        pub reward_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewPoolMember {
        #[key]
        pub pool_member: ContractAddress,
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub amount: u128
    }
}

#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub struct PoolMemberInfo {
    pub reward_address: ContractAddress,
    pub amount: u128,
    pub index: u64,
    pub unclaimed_rewards: u128,
    pub unpool_amount: u128,
    pub unpool_time: Option<u64>,
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct PoolContractInfo {
    pub staker_address: ContractAddress,
    pub final_staker_index: Option<u64>,
    pub staking_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub commission: u16,
}

#[starknet::interface]
pub trait IPool<TContractState> {
    fn enter_delegation_pool(
        ref self: TContractState, reward_address: ContractAddress, amount: u128
    ) -> bool;
    fn add_to_delegation_pool(
        ref self: TContractState, pool_member: ContractAddress, amount: u128
    ) -> u128;
    fn exit_delegation_pool_intent(ref self: TContractState, amount: u128);
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
    fn contract_parameters(self: @TContractState) -> PoolContractInfo;
    fn update_commission(ref self: TContractState, commission: u16) -> bool;
}
