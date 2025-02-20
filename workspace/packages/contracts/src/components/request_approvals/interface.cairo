use contracts_commons::types::HashType;

#[starknet::interface]
pub trait IRequestApprovals<TContractState> {
    /// Returns the status of a request.
    fn get_request_status(self: @TContractState, request_hash: HashType) -> RequestStatus;
}

#[derive(Debug, Drop, PartialEq, Serde, starknet::Store)]
pub enum RequestStatus {
    #[default]
    NOT_REGISTERED,
    PROCESSED,
    PENDING,
}
