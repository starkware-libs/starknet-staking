use contracts_commons::types::time::time::Timestamp;
use starknet::ContractAddress;

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct Deposit {
    #[key]
    pub position_id: u32,
    #[key]
    pub depositing_address: ContractAddress,
    pub asset_id: felt252,
    pub amount: i64,
    #[key]
    pub deposit_request_hash: felt252,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct DepositProcessed {
    #[key]
    pub position_id: u32,
    #[key]
    pub depositing_address: ContractAddress,
    pub asset_id: felt252,
    pub amount: i64,
    #[key]
    pub deposit_request_hash: felt252,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct DepositCanceled {
    #[key]
    pub position_id: u32,
    #[key]
    pub depositing_address: ContractAddress,
    pub asset_id: felt252,
    pub amount: i64,
    pub expiration: Timestamp,
    #[key]
    pub deposit_request_hash: felt252,
}
