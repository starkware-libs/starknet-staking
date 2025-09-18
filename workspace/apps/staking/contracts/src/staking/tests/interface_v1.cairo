use staking::types::Amount;

/// Staking V1 interface.
/// Used for testing purposes.
#[cfg(test)]
#[starknet::interface]
pub trait IStakingV1ForTests<TContractState> {
    fn get_current_total_staking_power(self: @TContractState) -> Amount;
}
