use contracts_commons::types::time::time::Timestamp;
use staking::types::Amount;
use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IRewardSupplier<TContractState> {
    // Calculates the rewards since the last_timestamp, and return the index diff.
    fn calculate_staking_rewards(ref self: TContractState) -> Amount;
    // Calculates the rewards for the current epoch.
    fn current_epoch_rewards(self: @TContractState) -> Amount;
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
    fn contract_parameters(self: @TContractState) -> RewardSupplierInfo;
}

pub mod Events {
    use contracts_commons::types::time::time::Timestamp;
    use staking::types::Amount;

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct MintRequest {
        pub total_amount: Amount,
        pub num_msgs: u128,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct CalculatedRewards {
        pub last_timestamp: Timestamp,
        pub new_timestamp: Timestamp,
        pub rewards_calculated: Amount,
    }
}

#[derive(Debug, Copy, Drop, Serde, PartialEq)]
pub struct RewardSupplierInfo {
    pub last_timestamp: Timestamp,
    pub unclaimed_rewards: Amount,
    pub l1_pending_requested_amount: Amount,
}
