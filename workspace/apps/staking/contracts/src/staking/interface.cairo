use starknet::{ContractAddress, ClassHash, get_block_timestamp};
use contracts::constants::EXIT_WAITING_WINDOW;
use core::cmp::max;

pub mod Events {
    use starknet::ContractAddress;
    #[derive(Drop, starknet::Event)]
    pub(crate) struct BalanceChanged {
        pub staker_address: ContractAddress,
        pub amount: u128
    }

    #[derive(Drop, starknet::Event)]
    pub(crate) struct NewDelegationPool {
        pub staker_address: ContractAddress,
        pub pooling_contract_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub(crate) struct StakerExitIntent {
        pub staker_address: ContractAddress,
        pub exit_at: u64
    }
}

// TODO create a different struct for not exposing internal implemenation
#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerInfo {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub pooling_contract: Option<ContractAddress>,
    pub unstake_time: Option<u64>,
    pub amount_own: u128,
    pub amount_pool: u128,
    pub index: u64,
    pub unclaimed_rewards_own: u128,
    pub unclaimed_rewards_pool: u128,
    pub rev_share: u16,
}

#[generate_trait]
pub impl StakerInfoImpl of StakerInfoTrait {
    fn compute_unpool_time(self: @StakerInfo) -> u64 {
        if let Option::Some(unstake_time) = *self.unstake_time {
            return max(unstake_time, get_block_timestamp());
        }
        get_block_timestamp() + EXIT_WAITING_WINDOW
    }
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct StakingContractInfo {
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
        rev_share: u16,
    ) -> bool;
    fn increase_stake(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> u128;
    fn claim_rewards(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn unstake_intent(ref self: TContractState) -> u64;
    fn unstake_action(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn add_to_delegation_pool(
        ref self: TContractState, pooled_staker: ContractAddress, amount: u128
    ) -> (u128, u64);
    fn remove_from_delegation_pool_intent(
        ref self: TContractState,
        staker_address: ContractAddress,
        identifier: ContractAddress,
        amount: u128,
    ) -> u64;
    fn remove_from_delegation_pool_action(
        ref self: TContractState, staker_address: ContractAddress, identifier: Span<felt252>
    ) -> u128;
    fn switch_staking_delegation_pool(
        ref self: TContractState,
        from_staker: ContractAddress,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        amount: u128,
        data: Span<felt252>
    ) -> bool;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress) -> bool;
    fn set_open_for_delegation(ref self: TContractState) -> ContractAddress;
    fn state_of(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
    fn claim_delegation_pool_rewards(
        ref self: TContractState, staker_address: ContractAddress
    ) -> u64;
    fn get_total_stake(self: @TContractState) -> u128;
}
