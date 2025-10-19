use staking::types::{BlockNumber, Epoch};
use starknet::ContractAddress;
pub use starkware_utils::components::roles::errors::AccessErrors;

#[starknet::interface]
pub trait IAttestation<TContractState> {
    /// Allows a staker to attest for the current epoch with a block hash, which is verified and
    /// recorded as complete upon success.
    ///
    /// #### Preconditions:
    /// - The attesting staker has not attested in the current epoch.
    ///
    /// #### Emits:
    /// - [`StakerAttestationSuccessful`](Events::StakerAttestationSuccessful)
    ///
    /// #### Errors:
    /// - [`ATTEST_STARTING_EPOCH`](staking::attestation::errors::Error::ATTEST_IS_DONE)
    /// - [`ATTEST_IS_DONE`](staking::attestation::errors::Error::ATTEST_IS_DONE)
    /// - [`ATTEST_OUT_OF_WINDOW`](staking::attestation::errors::Error::ATTEST_OUT_OF_WINDOW)
    /// - [`ATTEST_WRONG_BLOCK_HASH`](staking::attestation::errors::Error::ATTEST_WRONG_BLOCK_HASH)
    ///
    /// #### Access control:
    /// Only operational address of a staker.
    ///
    /// #### Internal calls:
    /// -[`staking::staking::interface::IStakingAttestation::get_attestation_info_by_operational_address`]
    /// -[`staking::staking::interface::IStakingAttestation::update_rewards_from_attestation_contract`]
    fn attest(ref self: TContractState, block_hash: felt252);
    /// Checks if the given `staker_address` has already attested in the current epoch.
    ///
    /// #### Errors:
    /// - [`ATTEST_STARTING_EPOCH`](staking::attestation::errors::Error::ATTEST_STARTING_EPOCH)
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStakingDispatcher::get_current_epoch`]
    fn is_attestation_done_in_curr_epoch(
        self: @TContractState, staker_address: ContractAddress,
    ) -> bool;
    /// Returns the last epoch in which the given `staker_address` submitted an attestation.
    fn get_last_epoch_attestation_done(
        self: @TContractState, staker_address: ContractAddress,
    ) -> Epoch;
    /// Returns the target attestation block number for the current epoch and the given
    /// `operational_address`.
    /// This function is used to help integration partners test the correct
    /// computation of the target attestation block.
    ///
    /// #### Internal calls:
    /// -[`staking::staking::interface::IStakingAttestation::get_attestation_info_by_operational_address`]
    fn get_current_epoch_target_attestation_block(
        self: @TContractState, operational_address: ContractAddress,
    ) -> BlockNumber;
    /// Returns the attestation window, which is the window in which stakers can attest.
    fn attestation_window(self: @TContractState) -> u16;
    /// Set the attestation window size.
    ///
    /// **Note**: New `attestation_window` takes effect immediately in the current epoch.
    /// It may cause some validators to miss rewards in that specific epoch due to changes in
    /// `target_attestation_block`.
    ///
    /// #### Preconditions:
    /// - `attestation_window` must be smaller than the epoch length.
    ///
    /// #### Emits:
    /// - [`AttestationWindowChanged`](Events::AttestationWindowChanged)
    ///
    /// #### Errors:
    /// - [`ONLY_APP_GOVERNOR`](AccessErrors::ONLY_APP_GOVERNOR)
    /// - [`ATTEST_WINDOW_TOO_SMALL`](staking::attestation::errors::Error::ATTEST_WINDOW_TOO_SMALL)
    ///
    /// #### Access control:
    /// Only app governor.
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

