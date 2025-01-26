use contracts_commons::errors::OptionAuxTrait;
use contracts_commons::types::time::time::{TimeDelta, Timestamp};
use staking::staking::errors::Error;
use staking::staking::objects::{
    UndelegateIntentKey, UndelegateIntentValue, VersionedInternalStakerInfo,
    VersionedInternalStakerInfoTrait,
};
use staking::types::{Amount, Commission, Epoch, Index};
use starknet::{ClassHash, ContractAddress};

/// Public interface for the staking contract.
#[starknet::interface]
pub trait IStaking<TContractState> {
    fn stake(
        ref self: TContractState,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: Amount,
        pool_enabled: bool,
        commission: Commission,
    );
    fn increase_stake(
        ref self: TContractState, staker_address: ContractAddress, amount: Amount,
    ) -> Amount;
    fn claim_rewards(ref self: TContractState, staker_address: ContractAddress) -> Amount;
    fn unstake_intent(ref self: TContractState) -> Timestamp;
    fn unstake_action(ref self: TContractState, staker_address: ContractAddress) -> Amount;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress);
    fn set_open_for_delegation(ref self: TContractState, commission: Commission) -> ContractAddress;
    fn staker_info(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
    fn get_staker_info(
        self: @TContractState, staker_address: ContractAddress,
    ) -> Option<StakerInfo>;
    fn get_staker_address_by_operational(
        self: @TContractState, operational_address: ContractAddress,
    ) -> ContractAddress;
    fn get_current_epoch(self: @TContractState) -> Epoch;
    // TODO: Rename once internal update_rewards is deleted.
    fn update_rewards_from_attestation_contract(
        ref self: TContractState, staker_address: ContractAddress,
    );
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
    fn get_total_stake(self: @TContractState) -> Amount;
    fn get_pool_exit_intent(
        self: @TContractState, undelegate_intent_key: UndelegateIntentKey,
    ) -> UndelegateIntentValue;
    fn update_global_index_if_needed(ref self: TContractState) -> bool;
    fn declare_operational_address(ref self: TContractState, staker_address: ContractAddress);
    fn change_operational_address(ref self: TContractState, operational_address: ContractAddress);
    fn update_commission(ref self: TContractState, commission: Commission);
    fn is_paused(self: @TContractState) -> bool;
}

#[starknet::interface]
pub trait IStakingMigration<TContractState> {
    fn convert_from_upgraded_contract(
        self: @TContractState,
        versioned_internal_staker_info: VersionedInternalStakerInfo,
        staker_address: ContractAddress,
    ) -> VersionedInternalStakerInfo;
}

/// Interface for the staking pool contract.
/// All functions in this interface are called only by the pool contract.
#[starknet::interface]
pub trait IStakingPool<TContractState> {
    /// Adds `amount` FRI to the staking pool.
    ///
    /// Conditions:
    /// * The staker is not in exit window.
    ///
    /// The flow:
    /// 1. Update rewards for `staker_address`.
    /// 2. Transfer `amount` FRI from the pool contract (the caller) to staking contract.
    /// 3. Increase the staker's pooled amount by `amount`.
    /// 4. Increase the total_stake by `amount`.
    fn add_stake_from_pool(
        ref self: TContractState, staker_address: ContractAddress, amount: Amount,
    ) -> Index;

    /// Registers an intention to remove `amount` FRI of pooled stake from the staking contract.
    /// Returns the timestmap when the pool is allowed to remove the `amount` for `identifier`.
    ///
    /// The flow, if making a brand new intent:
    /// 1. Update rewards for `staker_address`.
    /// 2. Decrease the staker's pooled amount by `amount`.
    /// 3. Decrease total_stake by `amount`.
    /// 4. Calculate the timestamp when the pool may perform remove_from_delegation_pool_action for
    ///    this `amount` and `identifier` (notate it as unpool_time for following use).
    /// 5. Create an entry in pool_exit_intents map for this `identifier` and pool contract address
    ///    with the value being `UndelegateIntentValue { amount, unpool_time }`.
    /// 6. Return unpool_time.
    ///
    /// The function supports overriding intentions, upwards and downwards, *which recalculates the
    /// unpool_time and restarts the timer*. This slightly changes the flow, meaning that if the
    /// pool already has an intent for this `identifier`, the flow remains the same except for
    /// points 2 and 3:
    /// * If the amount to be removed is greater in the previous intent, the staker's pooled amount
    ///   and total_stake will be *decreased* by the difference between the new and the old amount.
    /// * If the amount to be removed is smaller in the previous intent, the staker's pooled amount
    ///   and total_stake will be *increased* by the difference between the old and the new amount.
    ///
    /// If the amount to be removed is zero, any existing intent associated with this `identifier`
    /// will be removed, and the returned unpool time will be zero.
    fn remove_from_delegation_pool_intent(
        ref self: TContractState,
        staker_address: ContractAddress,
        identifier: felt252,
        amount: Amount,
    ) -> Timestamp;

    /// Transfers the removal intent amount back to the pool contract, and clears the intent.
    ///
    /// Conditions:
    /// * There is an entry in the pool_exit_intents map for this `identifier` and pool contract
    ///   (the caller).
    /// * The unpool_time, in the value of the entry above, has passed.
    fn remove_from_delegation_pool_action(ref self: TContractState, identifier: felt252);

    /// Moves the stake from being in exit intent, to being staked in `to_staker`'s pooled stake.
    /// Conditions:
    /// * There is an entry in the pool_exit_intents map for this `identifier` and pool contract,
    ///   with an amount greater than `switched_amount`. Note: It does not matter if the unpool_time
    ///   has passed or not.
    /// * `to_staker` is not in exit window.
    ///
    /// The flow:
    /// 1. Update rewards for `to_staker`.
    /// 2. Increase `to_staker`'s pooled amount by `switched_amount`.
    /// 3. Increase the total_stake by `switched_amount`. This happens because when an intent is
    ///    made, the intent amount is subtracted from the total_stake.
    /// 4. Decrease the intent amount by `switched_amount`, in the pool_exit_intents map's entry for
    ///    this `identifier` and pool contract. If amount is 0, remove the entry.
    /// 5. Invoke enter_delegation_pool_from_staking_contract in `to_pool`'s contract, which lets
    ///    `to_pool` know that new pooled stake was added.
    fn switch_staking_delegation_pool(
        ref self: TContractState,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        switched_amount: Amount,
        data: Span<felt252>,
        identifier: felt252,
    );

    /// Transfers the staker's pooled stake rewards to the pool contract (the caller).
    ///
    /// The flow:
    /// 1. Update the rewards for `staker_address`.
    /// 2. Send `pool_info.unclaimed_rewards` FRI to the pool contract.
    /// 3. Set pool_info.unclaimed_rewards to zero.
    fn claim_delegation_pool_rewards(
        ref self: TContractState, staker_address: ContractAddress,
    ) -> Index;
}

#[starknet::interface]
pub trait IStakingPause<TContractState> {
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
}

#[starknet::interface]
pub trait IStakingConfig<TContractState> {
    fn set_min_stake(ref self: TContractState, min_stake: Amount);
    fn set_exit_wait_window(ref self: TContractState, exit_wait_window: TimeDelta);
    fn set_reward_supplier(ref self: TContractState, reward_supplier: ContractAddress);
}

pub mod Events {
    use contracts_commons::types::time::time::Timestamp;
    use staking::types::{Amount, Commission, Index};
    use starknet::ContractAddress;
    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakeBalanceChanged {
        #[key]
        pub staker_address: ContractAddress,
        pub old_self_stake: Amount,
        pub old_delegated_stake: Amount,
        pub new_self_stake: Amount,
        pub new_delegated_stake: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct NewStaker {
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub operational_address: ContractAddress,
        pub self_stake: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct NewDelegationPool {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub pool_contract: ContractAddress,
        pub commission: Commission,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct CommissionChanged {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub pool_contract: ContractAddress,
        pub new_commission: Commission,
        pub old_commission: Commission,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakerExitIntent {
        #[key]
        pub staker_address: ContractAddress,
        pub exit_timestamp: Timestamp,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakerRewardAddressChanged {
        #[key]
        pub staker_address: ContractAddress,
        pub new_address: ContractAddress,
        pub old_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct OperationalAddressDeclared {
        #[key]
        pub operational_address: ContractAddress,
        #[key]
        pub staker_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct OperationalAddressChanged {
        #[key]
        pub staker_address: ContractAddress,
        pub new_address: ContractAddress,
        pub old_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakerRewardClaimed {
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct GlobalIndexUpdated {
        pub old_index: Index,
        pub new_index: Index,
        pub global_index_last_update_timestamp: Timestamp,
        pub global_index_current_update_timestamp: Timestamp,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct DeleteStaker {
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub operational_address: ContractAddress,
        pub pool_contract: Option<ContractAddress>,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct RewardsSuppliedToDelegationPool {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub pool_address: ContractAddress,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct RemoveFromDelegationPoolIntent {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub pool_contract: ContractAddress,
        #[key]
        pub identifier: felt252,
        pub old_intent_amount: Amount,
        pub new_intent_amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct RemoveFromDelegationPoolAction {
        #[key]
        pub pool_contract: ContractAddress,
        #[key]
        pub identifier: felt252,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct ChangeDelegationPoolIntent {
        #[key]
        pub pool_contract: ContractAddress,
        #[key]
        pub identifier: felt252,
        pub old_intent_amount: Amount,
        pub new_intent_amount: Amount,
    }
}

pub mod PauseEvents {
    use starknet::ContractAddress;
    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct Paused {
        pub account: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct Unpaused {
        pub account: ContractAddress,
    }
}

pub mod ConfigEvents {
    use contracts_commons::types::time::time::TimeDelta;
    use staking::types::Amount;
    use starknet::ContractAddress;
    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct MinimumStakeChanged {
        pub old_min_stake: Amount,
        pub new_min_stake: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct ExitWaitWindowChanged {
        pub old_exit_window: TimeDelta,
        pub new_exit_window: TimeDelta,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct RewardSupplierChanged {
        pub old_reward_supplier: ContractAddress,
        pub new_reward_supplier: ContractAddress,
    }
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct StakingContractInfo {
    pub min_stake: Amount,
    pub token_address: ContractAddress,
    pub global_index: Index,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
    pub exit_wait_window: TimeDelta,
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerInfo {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<Timestamp>,
    pub amount_own: Amount,
    pub index: Index,
    pub unclaimed_rewards_own: Amount,
    pub pool_info: Option<StakerPoolInfo>,
}

pub(crate) impl StakerInfoIntoVersionedInternalStakerInfo of Into<
    StakerInfo, VersionedInternalStakerInfo,
> {
    #[inline(always)]
    fn into(self: StakerInfo) -> VersionedInternalStakerInfo nopanic {
        VersionedInternalStakerInfoTrait::new_latest(
            reward_address: self.reward_address,
            operational_address: self.operational_address,
            unstake_time: self.unstake_time,
            amount_own: self.amount_own,
            index: self.index,
            unclaimed_rewards_own: self.unclaimed_rewards_own,
            pool_info: self.pool_info,
        )
    }
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerPoolInfo {
    pub pool_contract: ContractAddress,
    pub amount: Amount,
    pub unclaimed_rewards: Amount,
    pub commission: Commission,
}

#[generate_trait]
pub impl StakerInfoImpl of StakerInfoTrait {
    fn get_pool_info(self: StakerInfo) -> StakerPoolInfo {
        self.pool_info.expect_with_err(Error::MISSING_POOL_CONTRACT)
    }
}
