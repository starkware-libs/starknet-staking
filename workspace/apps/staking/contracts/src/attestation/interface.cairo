use staking::types::{BlockNumber, Epoch};
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
    fn get_current_epoch_target_attestation_block(
        self: @TContractState, operational_address: ContractAddress,
    ) -> BlockNumber;
    fn attestation_window(self: @TContractState) -> u16;
    /// **Note**: New `attestation_window` takes effect immediately in the current epoch.
    /// It may cause some validators to miss rewards in that specific epoch due to changes in
    /// `target_attestation_block`.
    /// **Note**: `attestation_window` must be smaller than the epoch length.
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

