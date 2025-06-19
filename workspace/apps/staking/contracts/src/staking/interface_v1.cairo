use staking::types::Index;
use starknet::ContractAddress;

/// Staking V1 interface.
/// Used for testing purposes.
#[cfg(test)]
#[starknet::interface]
pub trait IStakingPoolV1ForTests<TContractState> {
    fn pool_migration(ref self: TContractState, staker_address: ContractAddress) -> Index;
}
