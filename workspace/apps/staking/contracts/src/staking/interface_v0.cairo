use staking::staking::errors::Error;
use staking::staking::interface::{StakerInfoV1, StakerPoolInfoV1};
use staking::types::{Amount, Commission, Index};
use starknet::{ClassHash, ContractAddress};
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::time::time::{TimeDelta, Timestamp};

/// Staking V0 interface.
/// Used for testing purposes.
#[cfg(test)]
#[starknet::interface]
pub trait IStakingV0ForTests<TContractState> {
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
    fn update_global_index_if_needed(ref self: TContractState) -> bool;
    fn stake(
        self: @TContractState,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: Amount,
        pool_enabled: bool,
        commission: Commission,
    );
    fn set_open_for_delegation(self: @TContractState, commission: Commission) -> ContractAddress;
    fn update_commission(ref self: TContractState, commission: Commission);
    fn staker_info(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
}

/// StakerInfo struct used in V0.
/// **Note**: This struct should not be used in V1. It should only be used for testing and migration
/// purposes.
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

#[generate_trait]
pub impl StakerInfoImpl of StakerInfoTrait {
    fn get_pool_info(self: StakerInfo) -> StakerPoolInfo {
        self.pool_info.expect_with_err(Error::MISSING_POOL_CONTRACT)
    }

    fn to_v1(self: StakerInfo) -> StakerInfoV1 {
        StakerInfoV1 {
            reward_address: self.reward_address,
            operational_address: self.operational_address,
            unstake_time: self.unstake_time,
            amount_own: self.amount_own,
            unclaimed_rewards_own: self.unclaimed_rewards_own,
            pool_info: match self.pool_info {
                Option::Some(pool_info) => Option::Some(
                    StakerPoolInfoV1 {
                        pool_contract: pool_info.pool_contract,
                        amount: pool_info.amount,
                        commission: pool_info.commission,
                    },
                ),
                Option::None => Option::None,
            },
        }
    }
}

/// `StakingContractInfo` struct used in V0.
/// **Note**: This struct should not be used in V1. It should only be used for testing.
#[cfg(test)]
#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct StakingContractInfo {
    pub min_stake: Amount,
    pub token_address: ContractAddress,
    pub global_index: Index,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
    pub exit_wait_window: TimeDelta,
}

/// This struct was used in V0 for both InternalStakerInfo and StakerInfo.
/// Should not be in used except for migration purpose.
#[cfg(test)]
#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub(crate) struct StakerPoolInfo {
    pub pool_contract: ContractAddress,
    pub amount: Amount,
    pub unclaimed_rewards: Amount,
    pub commission: Commission,
}
