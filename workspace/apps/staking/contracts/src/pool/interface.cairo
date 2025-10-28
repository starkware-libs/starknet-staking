use staking::types::{Amount, Commission, InternalPoolMemberInfoLatest};
use starknet::ContractAddress;
use starkware_utils::time::time::Timestamp;

#[starknet::interface]
pub trait IPool<TContractState> {
    /// Add a new pool member to the delegation pool with `amount` starting funds.
    ///
    /// #### Preconditions:
    /// - The staker is active and not in exit window.
    /// - The caller address does not exist as a pool member in the pool.
    /// - `amount > 0`.
    /// - Caller address has sufficient funds.
    /// - Caller address has sufficient approval for transfer to pool contract.
    ///
    /// #### Emits:
    /// - [`NewPoolMember`](Events::NewPoolMember)
    /// - [`PoolMemberBalanceChanged`](Events::PoolMemberBalanceChanged)
    ///
    /// #### Errors:
    /// - [`STAKER_INACTIVE`](staking::pool::errors::Error::STAKER_INACTIVE)
    /// - [`POOL_MEMBER_EXISTS`](staking::pool::errors::Error::POOL_MEMBER_EXISTS)
    /// - [`AMOUNT_IS_ZERO`](staking::errors::GenericError::AMOUNT_IS_ZERO)
    /// - [`POOL_MEMBER_IS_TOKEN`](staking::pool::errors::Error::POOL_MEMBER_IS_TOKEN)
    /// - [`REWARD_ADDRESS_IS_TOKEN`](staking::errors::GenericError::REWARD_ADDRESS_IS_TOKEN)
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStakingPool::add_stake_from_pool`]
    /// - [`staking::staking::interface::IStaking::get_current_epoch`]
    fn enter_delegation_pool(
        ref self: TContractState, reward_address: ContractAddress, amount: Amount,
    );
    /// Increase the funds for `pool_member` by `amount`. Returns the updated total amount of the
    /// pool member.
    ///
    /// #### Preconditions:
    /// - The staker is active and not in exit window.
    /// - `pool_member` exists as a member in the pool.
    /// - `amount > 0`.
    /// - `pool_member` has sufficient funds.
    /// - `pool_member` has sufficient approval for transfer to pool contract.
    ///
    /// #### Emits:
    /// - [`PoolMemberBalanceChanged`](Events::PoolMemberBalanceChanged)
    ///
    /// #### Errors:
    /// - [`STAKER_INACTIVE`](staking::pool::errors::Error::STAKER_INACTIVE)
    /// - [`POOL_MEMBER_DOES_NOT_EXIST`](staking::pool::errors::Error::POOL_MEMBER_DOES_NOT_EXIST)
    /// - [`CALLER_CANNOT_ADD_TO_POOL`](staking::pool::errors::Error::CALLER_CANNOT_ADD_TO_POOL)
    /// - [`AMOUNT_IS_ZERO`](staking::errors::GenericError::AMOUNT_IS_ZERO)
    ///
    /// #### Access control:
    /// Only the pool member address or reward address of the given `pool_member`.
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStakingPool::add_stake_from_pool`]
    /// - [`staking::staking::interface::IStaking::get_current_epoch`]
    fn add_to_delegation_pool(
        ref self: TContractState, pool_member: ContractAddress, amount: Amount,
    ) -> Amount;
    /// Signals intent to withdraw the specified `amount` from the stake.
    /// Reward accrual for the requested `amount` will be suspended.
    /// Initiates the exit window countdown for withdrawing funds.
    ///
    /// #### Preconditions:
    /// - Caller address exists as a pool member in the pool.
    /// - `amount` is less than or equal to the total amount of the caller pool member.
    /// - The staker is active or the caller pool member is not in exit window.
    ///
    /// #### Emits:
    /// - [`PoolMemberExitIntent`](Events::PoolMemberExitIntent)
    /// - [`PoolMemberBalanceChanged`](Events::PoolMemberBalanceChanged)
    ///
    /// #### Errors:
    /// - [`POOL_MEMBER_DOES_NOT_EXIST`](staking::pool::errors::Error::POOL_MEMBER_DOES_NOT_EXIST)
    /// - [`AMOUNT_TOO_HIGH`](staking::errors::GenericError::AMOUNT_TOO_HIGH)
    /// - [`UNDELEGATE_IN_PROGRESS`](staking::pool::errors::Error::UNDELEGATE_IN_PROGRESS)
    ///
    /// #### Access control:
    /// Only the pool member address.
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStakingPool::remove_from_delegation_pool_intent`]
    /// - [`staking::staking::interface::IStaking::get_current_epoch`]
    fn exit_delegation_pool_intent(ref self: TContractState, amount: Amount);
    /// Completes a pending exit for the given pool member once the required waiting period has
    /// passed.
    /// Sends the withdrawn funds to `pool_member` and returns the transferred amount.
    ///
    /// #### Preconditions:
    /// - `pool_member` exists and requested to exit.
    /// - The exit window for `pool_member` has elapsed.
    ///
    /// #### Emits:
    /// - [`PoolMemberExitAction`](Events::PoolMemberExitAction)
    ///
    /// #### Errors:
    /// - [`POOL_MEMBER_DOES_NOT_EXIST`](staking::pool::errors::Error::POOL_MEMBER_DOES_NOT_EXIST)
    /// - [`MISSING_UNDELEGATE_INTENT`](staking::errors::GenericError::MISSING_UNDELEGATE_INTENT)
    /// - [`INTENT_WINDOW_NOT_FINISHED`](staking::errors::GenericError::INTENT_WINDOW_NOT_FINISHED)
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStakingPool::remove_from_delegation_pool_action`]
    fn exit_delegation_pool_action(
        ref self: TContractState, pool_member: ContractAddress,
    ) -> Amount;
    /// Updates `pool_member`'s rewards, transfers them to the reward address and returns the amount
    /// transferred.
    ///
    /// **Note**: Rewards are claimable up to, but not including, the current epoch.
    ///
    /// #### Preconditions:
    /// - `pool_member` exists as a pool member in the pool.
    ///
    /// #### Emits:
    /// - [`PoolMemberRewardClaimed`](Events::PoolMemberRewardClaimed)
    ///
    /// #### Errors:
    /// - [`POOL_MEMBER_DOES_NOT_EXIST`](staking::pool::errors::Error::POOL_MEMBER_DOES_NOT_EXIST)
    /// -
    /// [`POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS`](staking::pool::errors::Error::POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS)
    ///
    /// #### Access control:
    /// Only the pool member address or reward address of the given `pool_member`.
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStaking::get_current_epoch`]
    fn claim_rewards(ref self: TContractState, pool_member: ContractAddress) -> Amount;
    /// Moves `amount` funds of a pool member to `to_staker`'s pool `to_pool`.
    /// Returns the amount left in exit window for the pool member in this pool.
    ///
    /// #### Preconditions:
    /// - `amount > 0`.
    /// - The caller address exists as a pool member in the pool.
    /// - The caller pool member is in exit window.
    /// - The caller pool member's `unpool_amount` is greater than or equal to `amount`.
    /// - `to_staker` exists in the staking contract and is not in exit window.
    /// - `to_pool` is the delegation pool contract for `to_staker`.
    /// - `to_pool` is not the current pool.
    ///
    /// #### Emits:
    /// - [`SwitchDelegationPool`](Events::SwitchDelegationPool)
    ///
    /// #### Errors:
    /// - [`AMOUNT_IS_ZERO`](staking::errors::GenericError::AMOUNT_IS_ZERO)
    /// - [`POOL_MEMBER_DOES_NOT_EXIST`](staking::pool::errors::Error::POOL_MEMBER_DOES_NOT_EXIST)
    /// - [`MISSING_UNDELEGATE_INTENT`](staking::errors::GenericError::MISSING_UNDELEGATE_INTENT)
    /// - [`AMOUNT_TOO_HIGH`](staking::errors::GenericError::AMOUNT_TOO_HIGH)
    ///
    /// #### Access control:
    /// Only the pool member address.
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStakingPool::switch_staking_delegation_pool`]
    fn switch_delegation_pool(
        ref self: TContractState,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        amount: Amount,
    ) -> Amount;
    // TODO: Move to separate trait.
    /// Called by the staking contract when a pool member moves `amount` funds from another pool to
    /// this one during a pool switch.
    ///
    /// No funds are transferred since the staking contract holds the pool funds.
    ///
    /// #### Preconditions:
    /// - `amount > 0`.
    ///
    /// #### Emits:
    /// - [`NewPoolMember`](Events::NewPoolMember)
    /// - [`PoolMemberBalanceChanged`](Events::PoolMemberBalanceChanged)
    ///
    /// #### Errors:
    /// - [`AMOUNT_IS_ZERO`](staking::errors::GenericError::AMOUNT_IS_ZERO)
    /// -
    /// [`CALLER_IS_NOT_STAKING_CONTRACT`](staking::errors::GenericError::CALLER_IS_NOT_STAKING_CONTRACT)
    /// -
    /// [`SWITCH_POOL_DATA_DESERIALIZATION_FAILED`](staking::pool::errors::Error::SWITCH_POOL_DATA_DESERIALIZATION_FAILED)
    /// - [`REWARD_ADDRESS_MISMATCH`](staking::pool::errors::Error::REWARD_ADDRESS_MISMATCH)
    ///
    /// #### Access control:
    /// Only the staking contract.
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStaking::get_current_epoch`]
    fn enter_delegation_pool_from_staking_contract(
        ref self: TContractState, amount: Amount, data: Span<felt252>,
    );
    /// Called by the staking contract to signal that the associated staker has been exited from the
    /// staking contract.
    ///
    /// #### Preconditions:
    /// - The staker is not already removed.
    ///
    /// #### Emits:
    /// - [`StakerRemoved`](Events::StakerRemoved)
    ///
    /// #### Errors:
    /// -
    /// [`CALLER_IS_NOT_STAKING_CONTRACT`](staking::errors::GenericError::CALLER_IS_NOT_STAKING_CONTRACT)
    /// - [`STAKER_ALREADY_REMOVED`](staking::pool::errors::Error::STAKER_ALREADY_REMOVED)
    ///
    /// #### Access control:
    /// Only the staking contract.
    fn set_staker_removed(ref self: TContractState);
    /// Changes the `reward_address` for the caller pool member.
    ///
    /// #### Preconditions:
    /// - The caller address exists as a pool member in the pool.
    /// - `reward_address` is not the token address.
    ///
    /// #### Emits:
    /// - [`PoolMemberRewardAddressChanged`](Events::PoolMemberRewardAddressChanged)
    ///
    /// #### Errors:
    /// - [`REWARD_ADDRESS_IS_TOKEN`](staking::errors::GenericError::REWARD_ADDRESS_IS_TOKEN)
    /// - [`POOL_MEMBER_DOES_NOT_EXIST`](staking::pool::errors::Error::POOL_MEMBER_DOES_NOT_EXIST)
    ///
    /// #### Access control:
    /// Only the pool member address.
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress);
    /// Returns [`PoolMemberInfoV1`] of the given `pool_member`.
    ///
    /// #### Preconditions:
    /// - `pool_member` exists as a pool member in the pool.
    ///
    /// #### Errors:
    /// - [`POOL_MEMBER_DOES_NOT_EXIST`](staking::pool::errors::Error::POOL_MEMBER_DOES_NOT_EXIST)
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStaking::staker_pool_info`]
    /// - [`staking::staking::interface::IStaking::get_current_epoch`]
    fn pool_member_info_v1(self: @TContractState, pool_member: ContractAddress) -> PoolMemberInfoV1;
    /// Returns `Option<[PoolMemberInfoV1]>` of the given `pool_member`.
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStaking::staker_pool_info`]
    /// - [`staking::staking::interface::IStaking::get_current_epoch`]
    fn get_pool_member_info_v1(
        self: @TContractState, pool_member: ContractAddress,
    ) -> Option<PoolMemberInfoV1>;
    /// Returns [`PoolContractInfoV1`] describing the contract.
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStaking::staker_pool_info`]
    fn contract_parameters_v1(self: @TContractState) -> PoolContractInfoV1;
    /// Updates the cumulative rewards trace with `rewards` divided by `pool_balance` for the
    /// current epoch.
    ///
    /// #### Errors:
    /// -
    /// [`CALLER_IS_NOT_STAKING_CONTRACT`](staking::errors::GenericError::CALLER_IS_NOT_STAKING_CONTRACT)
    ///
    /// #### Access control:
    /// Only the staking contract.
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStaking::get_current_epoch`]
    fn update_rewards_from_staking_contract(
        ref self: TContractState, rewards: Amount, pool_balance: Amount,
    );
}

// **Note**: This trait must be reimplemented in the next version of `InternalPoolMemberInfo`.
#[starknet::interface]
pub trait IPoolMigration<TContractState> {
    /// Reads the internal pool member information for the given `pool_member` from storage and
    /// returns the latest version of this struct.
    ///
    /// Use this function instead of directly accessing storage to ensure you retrieve the
    /// latest version of the struct. Direct storage access may return an outdated version,
    /// which could be misaligned with the code and probably cause panics.
    ///
    /// #### Preconditions:
    /// - `pool_member` exists as a pool member in the pool.
    ///
    /// #### Errors:
    /// - [`POOL_MEMBER_DOES_NOT_EXIST`](staking::pool::errors::Error::POOL_MEMBER_DOES_NOT_EXIST)
    fn internal_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> InternalPoolMemberInfoLatest;
    /// Reads the internal pool member information for the given `pool_member` from storage and
    /// returns the latest version of this struct. If the pool member does not exist, returns None.
    fn get_internal_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> Option<InternalPoolMemberInfoLatest>;
}

pub mod Events {
    use staking::types::Amount;
    use starknet::ContractAddress;
    use starkware_utils::time::time::Timestamp;

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberExitIntent {
        #[key]
        pub pool_member: ContractAddress,
        pub exit_timestamp: Timestamp,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberExitAction {
        #[key]
        pub pool_member: ContractAddress,
        pub unpool_amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberBalanceChanged {
        #[key]
        pub pool_member: ContractAddress,
        pub old_delegated_stake: Amount,
        pub new_delegated_stake: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberRewardAddressChanged {
        #[key]
        pub pool_member: ContractAddress,
        pub new_address: ContractAddress,
        pub old_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct PoolMemberRewardClaimed {
        #[key]
        pub pool_member: ContractAddress,
        #[key]
        pub reward_address: ContractAddress,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakerRemoved {
        #[key]
        pub staker_address: ContractAddress,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct NewPoolMember {
        #[key]
        pub pool_member: ContractAddress,
        #[key]
        pub staker_address: ContractAddress,
        pub reward_address: ContractAddress,
        pub amount: Amount,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct SwitchDelegationPool {
        #[key]
        pub pool_member: ContractAddress,
        #[key]
        pub new_delegation_pool: ContractAddress,
        pub amount: Amount,
    }
}

/// Includes information about the pool member's addresses, balances and intent information,
/// rewards.
#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub struct PoolMemberInfoV1 {
    /// Address to send the member's rewards to.
    pub reward_address: ContractAddress,
    /// The pool member's balance.
    pub amount: Amount,
    /// The amount of unclaimed rewards for the pool member.
    pub unclaimed_rewards: Amount,
    /// The commission the staker takes from the pool rewards.
    pub commission: Commission,
    /// Amount of funds pending to be removed from the pool.
    pub unpool_amount: Amount,
    /// If the pool member has shown intent to unpool,
    /// this is the timestamp of when they could do that.
    /// Else, it is None.
    pub unpool_time: Option<Timestamp>,
}

/// Includes parameters and information about the pool contract.
#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct PoolContractInfoV1 {
    /// Address of the staker that owns the pool.
    pub staker_address: ContractAddress,
    /// Indicates whether the staker has been removed from the staking contract.
    pub staker_removed: bool,
    /// Address of the staking contract.
    pub staking_contract: ContractAddress,
    /// Address of the token contract.
    pub token_address: ContractAddress,
    /// The commission the staker takes from the pool rewards.
    pub commission: Commission,
}
