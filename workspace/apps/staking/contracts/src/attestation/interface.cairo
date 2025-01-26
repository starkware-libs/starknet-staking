use staking::types::Epoch;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IAttestation<TContractState> {
    fn attest(ref self: TContractState, attest_info: AttestInfo);
    // TODO: Rename address to staker_address or operational_address when it known.
    fn is_attestation_done_in_curr_epoch(self: @TContractState, address: ContractAddress) -> bool;
    fn get_last_epoch_attestation_done(self: @TContractState, address: ContractAddress) -> Epoch;
}

// TODO: implement
pub mod Events {}

// TODO: implement
#[derive(Debug, Copy, Drop, Serde, PartialEq)]
pub struct AttestInfo {}
