use starknet::{ContractAddress, ClassHash, get_block_timestamp};
use core::cmp::max;
use contracts::errors::{Error, OptionAuxTrait};
use contracts::types::{Commission, TimeDelta, TimeStamp, Index};

pub mod Events {
    use starknet::ContractAddress;
    use contracts::types::{Commission, TimeStamp, Index};
    #[derive(Drop, starknet::Event)]
    pub struct StakeBalanceChanged {
        #[key]
        pub staker_address: ContractAddress,
        pub old_self_stake: u128,
        pub old_delegated_stake: u128,
        pub new_self_stake: u128,
        pub new_delegated_stake: u128
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewStaker {
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub operational_address: ContractAddress,
        pub self_stake: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewDelegationPool {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub pool_contract: ContractAddress,
        pub commission: Commission
    }

    #[derive(Drop, starknet::Event)]
    pub struct CommissionChanged {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub pool_contract: ContractAddress,
        pub new_commission: Commission,
        pub old_commission: Commission
    }

    #[derive(Drop, starknet::Event)]
    pub struct StakerExitIntent {
        #[key]
        pub staker_address: ContractAddress,
        pub exit_timestamp: TimeStamp,
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
    pub struct StakerRewardClaimed {
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub amount: u128
    }

    #[derive(Drop, starknet::Event)]
    pub struct GlobalIndexUpdated {
        pub old_index: Index,
        pub new_index: Index,
        pub global_index_last_update_timestamp: TimeStamp,
        pub global_index_current_update_timestamp: TimeStamp
    }

    #[derive(Drop, starknet::Event)]
    pub struct DeleteStaker {
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub operational_address: ContractAddress,
        pub pool_contract: Option<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardsSuppliedToDelegationPool {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub pool_address: ContractAddress,
        pub amount: u128
    }
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerPoolInfo {
    pub pool_contract: ContractAddress,
    pub amount: u128,
    pub unclaimed_rewards: u128,
    pub commission: Commission,
}

// TODO create a different struct for not exposing internal implemenation
#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerInfo {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<u64>,
    pub amount_own: u128,
    pub index: Index,
    pub unclaimed_rewards_own: u128,
    pub pool_info: Option<StakerPoolInfo>,
}

#[generate_trait]
pub impl StakerInfoImpl of StakerInfoTrait {
    fn compute_unpool_time(self: @StakerInfo, exit_wait_window: TimeDelta) -> TimeStamp {
        if let Option::Some(unstake_time) = *self.unstake_time {
            return max(unstake_time, get_block_timestamp());
        }
        get_block_timestamp() + exit_wait_window
    }

    fn get_pool_info_unchecked(self: StakerInfo) -> StakerPoolInfo {
        self.pool_info.expect_with_err(Error::MISSING_POOL_CONTRACT)
    }
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct StakingContractInfo {
    pub min_stake: u128,
    pub token_address: ContractAddress,
    pub global_index: Index,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
    pub exit_wait_window: TimeDelta
}

/// Public interface for the staking contract.
/// This interface is exposed by the operator contract.
#[starknet::interface]
pub trait IStaking<TContractState> {
    fn stake(
        ref self: TContractState,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: u128,
        pool_enabled: bool,
        commission: Commission,
    );
    fn increase_stake(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> u128;
    fn claim_rewards(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn unstake_intent(ref self: TContractState) -> u64;
    fn unstake_action(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress);
    fn set_open_for_delegation(ref self: TContractState, commission: u16) -> ContractAddress;
    fn staker_info(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
    fn get_total_stake(self: @TContractState) -> u128;
    fn update_global_index_if_needed(ref self: TContractState) -> bool;
    fn change_operational_address(ref self: TContractState, operational_address: ContractAddress);
    // fn update_commission(ref self: TContractState, commission: Commission) -> bool;
    fn is_paused(self: @TContractState) -> bool;
}

/// Interface for the staking pool contract.
/// All functions in this interface are called only by the pool contract.
#[starknet::interface]
pub trait IStakingPool<TContractState> {
    fn add_stake_from_pool(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> (u128, Index);

    /// Registers an intention to remove `amount` FRI of pooled stake from the staking contract.
    /// Returns the timestmap when the pool is allowed to remove the `amount` for `identifier`.
    ///
    /// The flow, if making a brand new intent:
    /// 1. Decrease the staker's pooled amount by `amount`.
    /// 2. Decrease total_stake by `amount`.
    /// 3. Calculate the timestamp when the pool may perform remove_from_delegation_pool_action for
    ///    this `amount` and `identifier` (notate it as unpool_time for following use).
    /// 4. Create an entry in pool_exit_intents map for this `identifier` and pool contract address
    ///    with the value being `UndelegateIntentValue { amount, unpool_time }`.
    /// 5. Return unpool_time.
    ///
    /// The function supports overriding intentions, upwards and downwards, *which recalculates the
    /// unpool_time and restarts the timer*. This slightly changes the flow, meaning that if the
    /// pool already has an intent for this `identifier`, the flow is the same except for
    /// points 1 and 2:
    /// * If the amount to be removed is greater in the previous intent, the staker's pooled amount
    ///   and total_stake will be *decreased* by the difference between the new and the old amount.
    /// * If the amount to be removed is smaller in the previous intent, the staker's pooled amount
    ///   and total_stake will be *increased* by the difference between the old and the new amount.
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
    fn claim_delegation_pool_rewards(
        ref self: TContractState, staker_address: ContractAddress
    ) -> Index;
}

#[starknet::interface]
pub trait IStakingPause<TContractState> {
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
}

pub mod PauseEvents {
    use starknet::ContractAddress;
    #[derive(Drop, starknet::Event)]
    pub struct Paused {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unpaused {
        pub account: ContractAddress,
    }
}

#[starknet::interface]
pub trait IStakingConfig<TContractState> {
    fn set_min_stake(ref self: TContractState, min_stake: u128);
    fn set_exit_wait_window(ref self: TContractState, exit_wait_window: TimeDelta);
    fn set_reward_supplier(ref self: TContractState, reward_supplier: ContractAddress);
}
