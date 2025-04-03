use staking::types::{Amount, Commission, Index, InternalPoolMemberInfoLatest};
use starknet::ContractAddress;
use starkware_utils::types::time::time::Timestamp;

#[starknet::interface]
pub trait IPool<TContractState> {
    /// Add a new pool member to the delegation pool with `amount` starting funds.
    fn enter_delegation_pool(
        ref self: TContractState, reward_address: ContractAddress, amount: Amount,
    );

    /// Increase the funds for `pool_member` by `amount`.
    /// Return the updated total amount.
    fn add_to_delegation_pool(
        ref self: TContractState, pool_member: ContractAddress, amount: Amount,
    ) -> Amount;

    /// Inform of the intent to exit the stake. This will deduct `amount` funds from the stake.
    /// Rewards collection for the `amount` deducted will be paused.
    /// This will also start the exit window timeout.
    fn exit_delegation_pool_intent(ref self: TContractState, amount: Amount);

    /// Executes the intent to exit the stake if enough time have passed.
    /// Transfers the funds back to `pool_member`.
    /// Return the amount of tokens transferred back to `pool_member`.
    fn exit_delegation_pool_action(
        ref self: TContractState, pool_member: ContractAddress,
    ) -> Amount;

    /// Calculate and update `pool_member`'s rewards,
    /// then transfer them to the reward address.
    /// Return the amount transferred to the reward address.
    fn claim_rewards(ref self: TContractState, pool_member: ContractAddress) -> Amount;

    /// Move `amount` funds of a pool member to `to_staker`'s pool `to_pool`.
    /// Return the amount left in exit window for the pool member in this pool.
    fn switch_delegation_pool(
        ref self: TContractState,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        amount: Amount,
    ) -> Amount;

    /// Entry point for staking contract to inform pool of a pool member
    /// moving `amount` funds from another pool to this one.
    /// No funds need to be transferred since staking contract holds the pool funds.
    fn enter_delegation_pool_from_staking_contract(
        ref self: TContractState, amount: Amount, data: Span<felt252>,
    );

    /// Informs the delegation pool contract that the staker has left.
    fn set_staker_removed(ref self: TContractState);

    /// Change the `reward_address` for a pool member.
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress);

    /// Return `PoolMemberInfoV1` of `pool_member`.
    fn pool_member_info_v1(self: @TContractState, pool_member: ContractAddress) -> PoolMemberInfoV1;

    /// Return `Option<PoolMemberInfoV1>` of `pool_member`.
    /// without throwing an error or panicking.
    fn get_pool_member_info_v1(
        self: @TContractState, pool_member: ContractAddress,
    ) -> Option<PoolMemberInfoV1>;

    /// Return `PoolContractInfo` of the contract.
    fn contract_parameters_v1(self: @TContractState) -> PoolContractInfo;

    /// Update the cumulative sum in the pool trace with
    /// `rewards` divided by `pool_balance` for the current epoch.
    fn update_rewards_from_staking_contract(
        ref self: TContractState, rewards: Amount, pool_balance: Amount,
    );
}

// **Note**: This trait must be reimplemented in the next version of the contract.
#[starknet::interface]
pub trait IPoolMigration<TContractState> {
    /// Reads the internal pool member information for the given `pool_member` from storage and
    /// returns the latest version of this struct. panic if the pool member does not exist.
    ///
    /// Use this function instead of directly accessing storage to ensure you retrieve the
    /// latest version of the struct. Direct storage access may return an outdated version,
    /// which could be misaligned with the code and probably cause panics.
    fn internal_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> InternalPoolMemberInfoLatest;
    /// Reads the internal pool member information for the given `pool_member` from storage and
    /// returns the latest version of this struct. if the pool member does not exist, returns None.
    fn get_internal_pool_member_info(
        self: @TContractState, pool_member: ContractAddress,
    ) -> Option<InternalPoolMemberInfoLatest>;
}

pub mod Events {
    use staking::types::Amount;
    use starknet::ContractAddress;
    use starkware_utils::types::time::time::Timestamp;

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

/// Pool member info used in V0.
#[derive(Drop, PartialEq, Serde, Copy, starknet::Store, Debug)]
pub struct PoolMemberInfo {
    /// Address to send the member's rewards to.
    pub reward_address: ContractAddress,
    /// The pool member's balance.
    pub amount: Amount,
    /// Deprecated field previously used in rewards calculation.
    pub index: Index,
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

#[generate_trait]
pub(crate) impl PoolMemberInfoImpl of PoolMemberInfoTrait {
    fn to_v1(self: PoolMemberInfo) -> PoolMemberInfoV1 {
        PoolMemberInfoV1 {
            reward_address: self.reward_address,
            amount: self.amount,
            unclaimed_rewards: self.unclaimed_rewards,
            commission: self.commission,
            unpool_amount: self.unpool_amount,
            unpool_time: self.unpool_time,
        }
    }
}

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

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct PoolContractInfo {
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
