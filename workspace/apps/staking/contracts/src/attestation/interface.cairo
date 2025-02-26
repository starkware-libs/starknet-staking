use staking::types::Epoch;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IAttestation<TContractState> {
    fn attest(ref self: TContractState, attest_info: AttestInfo);
    fn is_attestation_done_in_curr_epoch(
        self: @TContractState, staker_address: ContractAddress,
    ) -> bool;
    fn get_last_epoch_attestation_done(
        self: @TContractState, staker_address: ContractAddress,
    ) -> Epoch;
}

// TODO: implement
pub mod Events {}

// TODO: implement
#[derive(Debug, Copy, Drop, Serde, PartialEq)]
pub struct AttestInfo {}
