use staking_test::types::{Amount, Index};
use starknet::ContractAddress;

/// Staking V1 interface.
/// Used for testing purposes.
#[starknet::interface]
pub trait IStakingV1ForTests<TContractState> {
    fn get_current_total_staking_power(self: @TContractState) -> Amount;
}

/// Staking Pool V1 interface.
/// Used for testing purposes.
#[starknet::interface]
pub trait IStakingPoolV1ForTests<TContractState> {
    fn pool_migration(ref self: TContractState, staker_address: ContractAddress) -> Index;
}
