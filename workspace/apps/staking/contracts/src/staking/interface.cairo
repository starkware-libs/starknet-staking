use starknet::{ContractAddress, ClassHash, get_block_timestamp};
use contracts::constants::EXIT_WAITING_WINDOW;
use core::cmp::max;
use contracts::errors::{panic_by_err, Error, OptionAuxTrait};

pub mod Events {
    use starknet::ContractAddress;
    #[derive(Drop, starknet::Event)]
    pub struct StakeBalanceChange {
        #[key]
        pub staker_address: ContractAddress,
        pub old_self_stake: u128,
        pub old_delegated_stake: u128,
        pub new_self_stake: u128,
        pub new_delegated_stake: u128
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewDelegationPool {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub pool_contract: ContractAddress,
        pub commission: u16
    }

    #[derive(Drop, starknet::Event)]
    pub struct StakerExitIntent {
        #[key]
        pub staker_address: ContractAddress,
        pub exit_timestamp: u64,
        pub amount: u128
    }

    #[derive(Drop, starknet::Event)]
    pub struct StakerRewardAddressChanged {
        #[key]
        pub staker_address: ContractAddress,
        pub new_address: ContractAddress,
        pub old_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct OperationalAddressChanged {
        #[key]
        pub staker_address: ContractAddress,
        pub new_address: ContractAddress,
        pub old_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GlobalIndexUpdated {
        pub old_index: u64,
        pub new_index: u64,
        pub last_index_update_timestamp: u64,
        pub current_index_update_timestamp: u64
    }

    #[derive(Drop, starknet::Event)]
    pub struct DeleteStaker {
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub operational_address: ContractAddress,
        pub pool_contract: Option<ContractAddress>,
    }
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerPoolInfo {
    pub pooling_contract: ContractAddress,
    pub amount: u128,
    pub unclaimed_rewards: u128,
    pub commission: u16,
}

// TODO create a different struct for not exposing internal implemenation
#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerInfo {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<u64>,
    pub amount_own: u128,
    pub index: u64,
    pub unclaimed_rewards_own: u128,
    pub pool_info: Option<StakerPoolInfo>,
}

#[generate_trait]
pub impl StakerInfoImpl of StakerInfoTrait {
    fn compute_unpool_time(self: @StakerInfo) -> u64 {
        if let Option::Some(unstake_time) = *self.unstake_time {
            return max(unstake_time, get_block_timestamp());
        }
        get_block_timestamp() + EXIT_WAITING_WINDOW
    }

    fn get_pool_info_unchecked(self: StakerInfo) -> StakerPoolInfo {
        self.pool_info.expect_with_err(Error::MISSING_POOL_CONTRACT)
    }
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct StakingContractInfo {
    pub min_stake: u128,
    pub token_address: ContractAddress,
    pub global_index: u64,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
}

#[starknet::interface]
pub trait IStaking<TContractState> {
    fn stake(
        ref self: TContractState,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: u128,
        pooling_enabled: bool,
        commission: u16,
    ) -> bool;
    fn increase_stake(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> u128;
    fn claim_rewards(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn unstake_intent(ref self: TContractState) -> u64;
    fn unstake_action(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn add_stake_from_pool(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> (u128, u64);
    fn remove_from_delegation_pool_intent(
        ref self: TContractState,
        staker_address: ContractAddress,
        identifier: felt252,
        amount: u128,
    ) -> u64;
    fn remove_from_delegation_pool_action(ref self: TContractState, identifier: felt252) -> u128;
    fn switch_staking_delegation_pool(
        ref self: TContractState,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        switched_amount: u128,
        data: Span<felt252>,
        identifier: felt252
    ) -> bool;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress) -> bool;
    fn set_open_for_delegation(ref self: TContractState, commission: u16) -> ContractAddress;
    fn state_of(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
    fn claim_delegation_pool_rewards(
        ref self: TContractState, staker_address: ContractAddress
    ) -> u64;
    fn get_total_stake(self: @TContractState) -> u128;
    fn update_global_index_if_needed(ref self: TContractState) -> bool;
    fn change_operational_address(
        ref self: TContractState, operational_address: ContractAddress
    ) -> bool;
    fn update_commission(ref self: TContractState, commission: u16) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
}
