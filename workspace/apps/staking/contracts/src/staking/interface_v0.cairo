use staking::staking::interface::{StakerInfo, StakingContractInfo};
use starknet::ContractAddress;

/// Staking V0 interface.
#[starknet::interface]
pub trait IStakingV0<TContractState> {
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
    fn staker_info(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
}
