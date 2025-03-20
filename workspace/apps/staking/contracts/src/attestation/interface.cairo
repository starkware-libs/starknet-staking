use staking::types::Epoch;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IAttestation<TContractState> {
    fn attest(ref self: TContractState, block_hash: felt252);
    fn is_attestation_done_in_curr_epoch(
        self: @TContractState, staker_address: ContractAddress,
    ) -> bool;
    fn get_last_epoch_attestation_done(
        self: @TContractState, staker_address: ContractAddress,
    ) -> Epoch;
    fn validate_next_epoch_attestation_block(
        self: @TContractState, operational_address: ContractAddress, block_number: u64,
    ) -> bool;
    fn attestation_window(self: @TContractState) -> u16;
    fn set_attestation_window(ref self: TContractState, attestation_window: u16);
}

pub mod Events {
    use staking::types::Epoch;
    use starknet::ContractAddress;
    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct StakerAttestationSuccessful {
        #[key]
        pub staker_address: ContractAddress,
        pub epoch: Epoch,
    }

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct AttestationWindowChanged {
        pub old_attestation_window: u16,
        pub new_attestation_window: u16,
    }
}

