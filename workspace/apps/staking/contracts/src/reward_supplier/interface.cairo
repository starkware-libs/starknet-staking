use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IRewardSupplier<TContractState> {
    // Calculates the rewards since the last_timestamp, and return the index diff.
    fn calculate_staking_rewards(ref self: TContractState) -> u128;
    // Transfers rewards to the staking contract.
    fn claim_rewards(ref self: TContractState, amount: u128);
    fn on_receive(
        self: @TContractState,
        l2_token: ContractAddress,
        amount: u256,
        depositor: EthAddress,
        message: Span<felt252>
    ) -> bool;
}
