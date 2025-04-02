use staking::staking::interface::StakingContractInfo;

/// Staking V0 interface.
#[starknet::interface]
pub trait IStakingV0<TContractState> {
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
}
