use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IRewardSupplier<TContractState> {
    // Calculates the rewards since the last_timestamp, and return the index diff.
    fn calculate_staking_rewards(ref self: TContractState) -> u128;
    // Transfers rewards to the staking contract.
    fn claim_rewards(ref self: TContractState, amount: u128);
    fn on_receive(
        ref self: TContractState,
        l2_token: ContractAddress,
        amount: u256,
        depositor: EthAddress,
        message: Span<felt252>
    ) -> bool;
    fn state_of(self: @TContractState) -> RewardSupplierStatus;
}

#[derive(Debug, Copy, Drop, Serde, PartialEq)]
pub struct RewardSupplierStatus {
    pub last_timestamp: u64,
    pub unclaimed_rewards: u128,
    pub l1_pending_requested_amount: u128,
}

pub mod Events {
    #[derive(Drop, starknet::Event)]
    pub struct MintRequest {
        pub total_amount: u128,
        pub num_msgs: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CalculatedRewards {
        pub last_timestamp: u64,
        pub new_timestamp: u64,
        pub rewards_calculated: u128,
    }
}
