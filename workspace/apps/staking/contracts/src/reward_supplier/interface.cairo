use starknet::{ContractAddress, EthAddress};
use contracts::types::Amount;
use contracts_commons::types::time::Timestamp;

#[starknet::interface]
pub trait IRewardSupplier<TContractState> {
    // Calculates the rewards since the last_timestamp, and return the index diff.
    fn calculate_staking_rewards(ref self: TContractState) -> u128;
    // Transfers rewards to the staking contract.
    fn claim_rewards(ref self: TContractState, amount: Amount);
    fn on_receive(
        ref self: TContractState,
        l2_token: ContractAddress,
        amount: u256,
        depositor: EthAddress,
        message: Span<felt252>
    ) -> bool;
    fn contract_parameters(self: @TContractState) -> RewardSupplierInfo;
}

pub mod Events {
    use contracts::types::Amount;
    use contracts_commons::types::time::Timestamp;

    #[derive(Drop, starknet::Event)]
    pub struct MintRequest {
        pub total_amount: Amount,
        pub num_msgs: u128,
    }

    #[derive(Drop, starknet::Event)]
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
