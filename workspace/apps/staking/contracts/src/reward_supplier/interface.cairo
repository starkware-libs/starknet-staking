use staking_test::types::Amount;
use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IRewardSupplier<TContractState> {
    // Calculates the rewards for the current epoch (for STRK and BTC).
    fn calculate_current_epoch_rewards(self: @TContractState) -> (Amount, Amount);
    // Updates the unclaimed rewards from the staking contract.
    fn update_unclaimed_rewards_from_staking_contract(ref self: TContractState, rewards: Amount);
    // Transfers rewards to the staking contract.
    fn claim_rewards(ref self: TContractState, amount: Amount);
    fn on_receive(
        ref self: TContractState,
        l2_token: ContractAddress,
        amount: u256,
        depositor: EthAddress,
        message: Span<felt252>,
    ) -> bool;
    fn contract_parameters_v1(self: @TContractState) -> RewardSupplierInfoV1;
    // Returns the alpha parameter, as percentage, used when computing BTC rewards.
    fn get_alpha(self: @TContractState) -> u128;
}

pub mod Events {
    use staking_test::types::Amount;

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct MintRequest {
        pub total_amount: Amount,
        pub num_msgs: u128,
    }
}

#[derive(Debug, Copy, Drop, Serde, PartialEq)]
pub struct RewardSupplierInfoV1 {
    pub unclaimed_rewards: Amount,
    pub l1_pending_requested_amount: Amount,
}
