use starknet::ContractAddress;

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct Deposit {
    #[key]
    pub beneficiary: u32,
    #[key]
    pub depositing_address: ContractAddress,
    pub asset_id: felt252,
    pub quantized_amount: u128,
    pub unquantized_amount: u128,
    #[key]
    pub deposit_request_hash: felt252,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct DepositProcessed {
    #[key]
    pub beneficiary: u32,
    #[key]
    pub depositing_address: ContractAddress,
    pub asset_id: felt252,
    pub quantized_amount: u128,
    pub unquantized_amount: u128,
    #[key]
    pub deposit_request_hash: felt252,
}

#[derive(Debug, Drop, PartialEq, starknet::Event)]
pub struct DepositCanceled {
    #[key]
    pub beneficiary: u32,
    #[key]
    pub depositing_address: ContractAddress,
    pub asset_id: felt252,
    pub quantized_amount: u128,
    pub unquantized_amount: u128,
    #[key]
    pub deposit_request_hash: felt252,
}
