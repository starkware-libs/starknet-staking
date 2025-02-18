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
    );
    fn cancel_deposit(
        ref self: TContractState,
        beneficiary: u32,
        asset_id: felt252,
        quantized_amount: u128,
        salt: felt252,
    );
    fn get_deposit_status(self: @TContractState, deposit_hash: HashType) -> DepositStatus;
    fn get_asset_info(self: @TContractState, asset_id: felt252) -> (ContractAddress, u64);
}

const NOT_EXIST_CONSTANT: u64 = 0;
const DONE_CONSTANT: u64 = 1;
const CANCELED_CONSTANT: u64 = 2;

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
            DepositStatus::NOT_EXIST => NOT_EXIST_CONSTANT,
            DepositStatus::DONE => DONE_CONSTANT,
            DepositStatus::CANCELED => CANCELED_CONSTANT,
            DepositStatus::PENDING(time) => { time.into() },
        }
    }

    fn unpack(value: u64) -> DepositStatus {
        if (value == NOT_EXIST_CONSTANT) {
            DepositStatus::NOT_EXIST
        } else if (value == DONE_CONSTANT) {
            DepositStatus::DONE
        } else if (value == CANCELED_CONSTANT) {
            DepositStatus::CANCELED
        } else {
            DepositStatus::PENDING(Timestamp { seconds: value })
        }
    }
}
