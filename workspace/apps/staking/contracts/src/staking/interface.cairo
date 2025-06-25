use core::num::traits::Zero;
use staking::staking::errors::Error;
use staking::staking::objects::{
    AttestationInfo, EpochInfo, UndelegateIntentKey, UndelegateIntentValue,
};
use staking::types::{Amount, Commission, Epoch, InternalStakerInfoLatest};
use starknet::{ClassHash, ContractAddress};
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::time::time::{TimeDelta, Timestamp};

/// Public interface for the staking contract.
#[starknet::interface]
pub trait IStaking<TContractState> {
    fn stake(
        ref self: TContractState,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: Amount,
    );
    fn increase_stake(
        ref self: TContractState, staker_address: ContractAddress, amount: Amount,
    ) -> Amount;
    fn claim_rewards(ref self: TContractState, staker_address: ContractAddress) -> Amount;
    fn unstake_intent(ref self: TContractState) -> Timestamp;
    fn unstake_action(ref self: TContractState, staker_address: ContractAddress) -> Amount;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress);
    fn set_open_for_delegation(
        ref self: TContractState, token_address: ContractAddress,
    ) -> ContractAddress;
    fn staker_info_v1(self: @TContractState, staker_address: ContractAddress) -> StakerInfoV1;
    fn staker_pool_info(self: @TContractState, staker_address: ContractAddress) -> StakerPoolInfoV2;
    fn get_staker_info_v1(
        self: @TContractState, staker_address: ContractAddress,
    ) -> Option<StakerInfoV1>;
    fn get_current_epoch(self: @TContractState) -> Epoch;
    fn get_epoch_info(self: @TContractState) -> EpochInfo;
    fn get_staker_commission_commitment(
        self: @TContractState, staker_address: ContractAddress,
    ) -> CommissionCommitment;
    fn contract_parameters_v1(self: @TContractState) -> StakingContractInfoV1;
    fn get_total_stake(self: @TContractState) -> Amount;
    fn get_current_total_staking_power(self: @TContractState) -> (Amount, Amount);
    // TODO: Make this function internal?
    fn get_pool_exit_intent(
        self: @TContractState, undelegate_intent_key: UndelegateIntentKey,
    ) -> UndelegateIntentValue;
    fn declare_operational_address(ref self: TContractState, staker_address: ContractAddress);
    fn change_operational_address(ref self: TContractState, operational_address: ContractAddress);
    fn set_commission(ref self: TContractState, commission: Commission);
    fn set_commission_commitment(
        ref self: TContractState, max_commission: Commission, expiration_epoch: Epoch,
    );
    fn is_paused(self: @TContractState) -> bool;
    fn get_active_tokens(self: @TContractState) -> Span<ContractAddress>;
    fn get_total_stake_for_token(self: @TContractState, token_address: ContractAddress) -> Amount;
}

// **Note**: This trait must be reimplemented in the next version of the contract.
#[starknet::interface]
pub trait IStakingMigration<TContractState> {
    /// Reads the internal staker information for the given `staker_address` from storage and
    /// returns it.
    ///
    /// Precondition: The staker exists and its version is V1.
    fn internal_staker_info(
        self: @TContractState, staker_address: ContractAddress,
    ) -> InternalStakerInfoLatest;


    /// Reads the internal staker information for the given `staker_address` from storage
    /// and converts it to V1. Writes the updated version to storage and initializes the staker's
    /// balance trace.
    ///
    /// Precondition: The staker exists, does not have a pool and its version is V0.
    ///
    /// This function is used only during migration.
    fn staker_migration(ref self: TContractState, staker_address: ContractAddress);
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
    );

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
    fn set_epoch_info(ref self: TContractState, epoch_duration: u32, epoch_length: u32);
}

#[starknet::interface]
pub trait IStakingTokenManager<TContractState> {
    /// Add a new token to the staking contract.
    ///
    /// **Important note:** This function should be called only a limited number of times.
    /// Adding too many tokens can lead to unbounded complexity and potential performance issues.
    /// The token set is intended to remain fixed and small, ensuring all loops over it are safely
    /// bounded.
    /// It is the security admin's responsibility to enforce this token limit.
    fn add_token(ref self: TContractState, token_address: ContractAddress);
    /// Enable token for getting rewards.
    ///
    /// **Important note:** This function takes effect immediately upon execution.
    /// It impacts the current epoch’s rewards, potentially increasing or decreasing them,
    /// and may cause uneven distribution of rewards among stakers for this epoch.
    fn enable_token(ref self: TContractState, token_address: ContractAddress);
    /// Disable token for getting rewards.
    ///
    /// **Important note:** This function takes effect immediately upon execution.
    /// It impacts the current epoch’s rewards, potentially increasing or decreasing them,
    /// and may cause uneven distribution of rewards among stakers for this epoch.
    fn disable_token(ref self: TContractState, token_address: ContractAddress);
}

#[starknet::interface]
pub trait IStakingAttestation<TContractState> {
    fn update_rewards_from_attestation_contract(
        ref self: TContractState, staker_address: ContractAddress,
    );
    fn get_attestation_info_by_operational_address(
        self: @TContractState, operational_address: ContractAddress,
    ) -> AttestationInfo;
}

pub mod Events {
    use staking::types::{Amount, Commission, Epoch};
    use starknet::ContractAddress;
    use starkware_utils::time::time::Timestamp;
    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakeOwnBalanceChanged {
        #[key]
        pub staker_address: ContractAddress,
        pub old_self_stake: Amount,
        pub new_self_stake: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakeDelegatedBalanceChanged {
        #[key]
        pub staker_address: ContractAddress,
        #[key]
        pub token_address: ContractAddress,
        pub old_delegated_stake: Amount,
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
        #[key]
        pub token_address: ContractAddress,
        pub commission: Commission,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct CommissionInitialized {
        #[key]
        pub staker_address: ContractAddress,
        pub commission: Commission,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct CommissionChanged {
        #[key]
        pub staker_address: ContractAddress,
        pub new_commission: Commission,
        pub old_commission: Commission,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakerExitIntent {
        #[key]
        pub staker_address: ContractAddress,
        pub exit_timestamp: Timestamp,
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
    pub struct StakerRewardsUpdated {
        #[key]
        pub staker_address: ContractAddress,
        pub staker_rewards: Amount,
        pub pool_rewards: Span<(ContractAddress, Amount)>,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct DeleteStaker {
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub operational_address: ContractAddress,
        pub pool_contracts: Span<ContractAddress>,
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
        pub token_address: ContractAddress,
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
        pub token_address: ContractAddress,
        #[key]
        pub identifier: felt252,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct ChangeDelegationPoolIntent {
        #[key]
        pub pool_contract: ContractAddress,
        #[key]
        pub token_address: ContractAddress,
        #[key]
        pub identifier: felt252,
        pub old_intent_amount: Amount,
        pub new_intent_amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct CommissionCommitmentSet {
        #[key]
        pub staker_address: ContractAddress,
        pub max_commission: Commission,
        pub expiration_epoch: Epoch,
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
    use staking::types::Amount;
    use starknet::ContractAddress;
    use starkware_utils::time::time::TimeDelta;
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

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct EpochInfoChanged {
        pub epoch_duration: u32,
        pub epoch_length: u32,
    }
}

pub mod TokenManagerEvents {
    use starknet::ContractAddress;
    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct TokenAdded {
        #[key]
        pub token_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct TokenEnabled {
        #[key]
        pub token_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct TokenDisabled {
        #[key]
        pub token_address: ContractAddress,
    }
}

/// `StakingContractInfo` struct used in V1.
#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct StakingContractInfoV1 {
    pub min_stake: Amount,
    pub token_address: ContractAddress,
    pub attestation_contract: ContractAddress,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
    pub exit_wait_window: TimeDelta,
}

/// `StakerInfo` struct used in V1.
#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerInfoV1 {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<Timestamp>,
    pub amount_own: Amount,
    pub unclaimed_rewards_own: Amount,
    pub pool_info: Option<StakerPoolInfoV1>,
}

/// `StakerPoolInfo` struct used in V1 as a part of `StakerInfoV1`.
#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct StakerPoolInfoV1 {
    pub pool_contract: ContractAddress,
    pub amount: Amount,
    pub commission: Commission,
}

/// `StakerPoolInfo` struct used in V2.
#[derive(Debug, PartialEq, Drop, Serde, Copy)]
pub struct StakerPoolInfoV2 {
    pub commission: Option<Commission>,
    pub pools: Span<PoolInfo>,
}

/// `PoolInfo` struct used in V2 as a part of `StakerPoolInfoV2`.
#[derive(Debug, PartialEq, Drop, Serde, Copy)]
pub struct PoolInfo {
    pub pool_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub amount: Amount,
}

#[generate_trait]
pub impl StakerInfoV1Impl of StakerInfoV1Trait {
    fn get_pool_info(self: StakerInfoV1) -> StakerPoolInfoV1 {
        self.pool_info.expect_with_err(Error::MISSING_POOL_CONTRACT)
    }
}

#[derive(starknet::Store, Drop, Debug, PartialEq, Serde, Copy)]
pub struct CommissionCommitment {
    pub max_commission: Commission,
    pub expiration_epoch: Epoch,
}

pub impl CommissionCommitmentZero of Zero<CommissionCommitment> {
    fn zero() -> CommissionCommitment {
        CommissionCommitment { max_commission: Zero::zero(), expiration_epoch: Zero::zero() }
    }

    fn is_zero(self: @CommissionCommitment) -> bool {
        *self == Self::zero()
    }

    fn is_non_zero(self: @CommissionCommitment) -> bool {
        !self.is_zero()
    }
}
