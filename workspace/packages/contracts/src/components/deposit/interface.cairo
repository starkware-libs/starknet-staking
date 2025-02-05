use contracts_commons::types::HashType;
use contracts_commons::types::time::time::Timestamp;
use core::starknet::storage_access::StorePacking;
use starknet::ContractAddress;


#[starknet::interface]
pub trait IDeposit<TContractState> {
    fn deposit(
        ref self: TContractState,
        beneficiary: u32,
        asset_id: felt252,
        quantized_amount: u128,
        salt: felt252,
    ) -> HashType;
    fn get_deposit_status(self: @TContractState, deposit_hash: HashType) -> DepositStatus;
    fn get_asset_info(self: @TContractState, asset_id: felt252) -> (ContractAddress, u64);
}

#[derive(Debug, Drop, PartialEq, Serde)]
pub enum DepositStatus {
    NOT_EXIST,
    DONE,
    CANCELED,
    PENDING: Timestamp,
}

impl DepositStatusPacking of StorePacking<DepositStatus, u64> {
    fn pack(value: DepositStatus) -> u64 {
        match value {
            DepositStatus::NOT_EXIST => 0,
            DepositStatus::DONE => 1,
            DepositStatus::CANCELED => 2,
            DepositStatus::PENDING(time) => { time.into() },
        }
    }

    fn unpack(value: u64) -> DepositStatus {
        match value {
            0 => DepositStatus::NOT_EXIST,
            1 => DepositStatus::DONE,
            2 => DepositStatus::CANCELED,
            _ => DepositStatus::PENDING(Timestamp { seconds: value }),
        }
    }
}
