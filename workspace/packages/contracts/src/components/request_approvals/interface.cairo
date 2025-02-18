use contracts_commons::components::request_approvals::errors;
use core::panic_with_felt252;
use core::starknet::storage_access::StorePacking;


#[starknet::interface]
pub trait IRequestApprovals<TContractState> {
    /// Returns the status of a request.
    fn get_request_status(self: @TContractState, request_hash: felt252) -> RequestStatus;
}

#[derive(Debug, Drop, PartialEq, Serde)]
pub enum RequestStatus {
    NOT_EXIST,
    DONE,
    PENDING,
}

const NOT_EXIST_CONSTANT: u8 = 0;
const DONE_CONSTANT: u8 = 1;
const PENDING_CONSTANT: u8 = 2;

const STATUS_MASK: u8 = 0x3;

impl RequestStatusPacking of StorePacking<RequestStatus, u8> {
    fn pack(value: RequestStatus) -> u8 {
        match value {
            RequestStatus::NOT_EXIST => NOT_EXIST_CONSTANT,
            RequestStatus::DONE => DONE_CONSTANT,
            RequestStatus::PENDING => PENDING_CONSTANT,
        }
    }

    fn unpack(value: u8) -> RequestStatus {
        let status = value & STATUS_MASK;

        if (status == NOT_EXIST_CONSTANT) {
            RequestStatus::NOT_EXIST
        } else if (value == DONE_CONSTANT) {
            RequestStatus::DONE
        } else if (value == PENDING_CONSTANT) {
            RequestStatus::PENDING
        } else {
            panic_with_felt252(errors::INVALID_STATUS)
        }
    }
}
