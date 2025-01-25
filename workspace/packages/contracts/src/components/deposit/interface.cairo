use contracts_commons::components::deposit::errors;
use contracts_commons::types::time::time::Timestamp;
use core::panic_with_felt252;
use core::starknet::storage_access::StorePacking;
use starknet::ContractAddress;


#[starknet::interface]
pub trait IDeposit<TContractState> {
    fn deposit(
        ref self: TContractState,
        asset_id: felt252,
        quantized_amount: i64,
        beneficiary: u32,
        salt: felt252,
    );
    fn get_deposit_status(self: @TContractState, hash: felt252) -> DepositStatus;
    fn get_asset_data(self: @TContractState, asset_id: felt252) -> (ContractAddress, u64);
}

#[derive(Debug, Drop, PartialEq, Serde)]
pub(crate) enum DepositStatus {
    NON_EXIST,
    DONE,
    PENDING: Timestamp,
}

pub(crate) impl DepositStatusImpl of TryInto<DepositStatus, Timestamp> {
    fn try_into(self: DepositStatus) -> Option<Timestamp> {
        match self {
            DepositStatus::PENDING(time) => Option::Some(time),
            _ => Option::None,
        }
    }
}

const TWO_POW_4: u64 = 0x10;
const STATUS_MASK: u128 = 0x3;

impl DepositStatusPacking of StorePacking<DepositStatus, u128> {
    fn pack(value: DepositStatus) -> u128 {
        match value {
            DepositStatus::NON_EXIST => 0,
            DepositStatus::DONE => 1,
            DepositStatus::PENDING(time) => { 2_u128 + (TWO_POW_4 * time.into()).into() },
        }
    }

    fn unpack(value: u128) -> DepositStatus {
        let status = value & STATUS_MASK;
        if status == 0 {
            DepositStatus::NON_EXIST
        } else if status == 1 {
            DepositStatus::DONE
        } else if status == 2 {
            let time: u64 = ((value - 2) / TWO_POW_4.into()).try_into().unwrap();
            DepositStatus::PENDING(Timestamp { seconds: time })
        } else {
            panic_with_felt252(errors::INVALID_STATUS)
        }
    }
}
