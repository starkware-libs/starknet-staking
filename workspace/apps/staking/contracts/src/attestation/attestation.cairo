#[starknet::contract]
pub mod Attestation {
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use contracts_commons::components::replaceability::ReplaceabilityComponent::InternalReplaceabilityTrait;
    use contracts_commons::components::roles::RolesComponent;
    use contracts_commons::errors::OptionAuxTrait;
    use contracts_commons::interfaces::identity::Identity;
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use staking::attestation::errors::Error;
    use staking::attestation::interface::{AttestInfo, IAttestation};
    use staking::constants::MIN_ATTESTATION_WINDOW;
    use staking::staking::interface::{
        IStakingAttestationDispatcher, IStakingAttestationDispatcherTrait, IStakingDispatcher,
        IStakingDispatcherTrait,
    };
    use staking::types::Epoch;
    use starknet::storage::Map;
    use starknet::{ContractAddress, get_caller_address};
    pub const CONTRACT_IDENTITY: felt252 = 'Attestation';
    pub const CONTRACT_VERSION: felt252 = '1.0.0';

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl ReplaceabilityImpl =
        ReplaceabilityComponent::ReplaceabilityImpl<ContractState>;

    #[abi(embed_v0)]
    impl RolesImpl = RolesComponent::RolesImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        replaceability: ReplaceabilityComponent::Storage,
        #[substorage(v0)]
        roles: RolesComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        staking_contract: ContractAddress,
        // Maps staker address to the last epoch he attested.
        staker_last_attested_epoch: Map<ContractAddress, Option<Epoch>>,
        // Number of blocks where the staker can attest after the expected attestation block.
        attestation_window: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        accesscontrolEvent: AccessControlComponent::Event,
        #[flat]
        src5Event: SRC5Component::Event,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        staking_contract: ContractAddress,
        governance_admin: ContractAddress,
        attestation_window: u8,
    ) {
        self.roles.initialize(:governance_admin);
        self.replaceability.initialize(upgrade_delay: Zero::zero());
        self.staking_contract.write(staking_contract);
        assert_gt!(
            attestation_window, MIN_ATTESTATION_WINDOW, "{}", Error::ATTEST_WINDOW_TOO_SMALL,
        );
        self.attestation_window.write(attestation_window);
    }

    #[abi(embed_v0)]
    impl _Identity of Identity<ContractState> {
        fn identify(self: @ContractState) -> felt252 nopanic {
            CONTRACT_IDENTITY
        }

        fn version(self: @ContractState) -> felt252 nopanic {
            CONTRACT_VERSION
        }
    }

    #[abi(embed_v0)]
    impl AttestationImpl of IAttestation<ContractState> {
        fn attest(ref self: ContractState, attest_info: AttestInfo) {
            let operational_address = get_caller_address();
            let staking_dispatcher = IStakingAttestationDispatcher {
                contract_address: self.staking_contract.read(),
            };
            // Note: This function checks for a zero staker address and will panic if so.
            let staking_attestation_info = staking_dispatcher
                .get_attestation_info_by_operational_address(:operational_address);
            let (staker_address, current_epoch): (ContractAddress, Epoch) = staking_attestation_info
                .into();
            self._validate_attestation(:attest_info, :staker_address, :current_epoch);
            staking_dispatcher.update_rewards_from_attestation_contract(:staker_address);
            // TODO: emit event.
        }

        fn get_last_epoch_attestation_done(
            self: @ContractState, staker_address: ContractAddress,
        ) -> Epoch {
            self
                .staker_last_attested_epoch
                .read(staker_address)
                .expect_with_err(Error::NO_ATTEST_DONE)
        }

        fn is_attestation_done_in_curr_epoch(
            self: @ContractState, staker_address: ContractAddress,
        ) -> bool {
            let staking_dispatcher = IStakingDispatcher {
                contract_address: self.staking_contract.read(),
            };
            let current_epoch = staking_dispatcher.get_current_epoch();
            self.get_last_epoch_attestation_done(:staker_address) == current_epoch
        }

        fn attestation_window(self: @ContractState) -> u8 {
            self.attestation_window.read()
        }

        fn set_attestation_window(ref self: ContractState, attestation_window: u8) {
            self.roles.only_app_governor();
            assert!(
                attestation_window > MIN_ATTESTATION_WINDOW, "{}", Error::ATTEST_WINDOW_TOO_SMALL,
            );
            self.attestation_window.write(attestation_window);
            // TODO: emit event.
        }
    }

    #[generate_trait]
    impl InternalAttestationFunctions of InternalAttestationFunctionsTrait {
        fn _validate_attestation(
            ref self: ContractState,
            attest_info: AttestInfo,
            staker_address: ContractAddress,
            current_epoch: Epoch,
        ) {
            self._assert_attestation_is_not_done(:staker_address, :current_epoch);
            // TODO: Validate the attestaion.
            // Work is one tx per epoch.
            self._mark_attestation_is_done(:staker_address, :current_epoch);
        }

        fn _assert_attestation_is_not_done(
            ref self: ContractState, staker_address: ContractAddress, current_epoch: Epoch,
        ) {
            // None means no work done for this staker_address.
            if let Option::Some(last_epoch_done) = self
                .staker_last_attested_epoch
                .read(staker_address) {
                assert!(last_epoch_done != current_epoch, "{}", Error::ATTEST_IS_DONE);
            }
        }

        fn _mark_attestation_is_done(
            ref self: ContractState, staker_address: ContractAddress, current_epoch: Epoch,
        ) {
            self.staker_last_attested_epoch.write(staker_address, Option::Some(current_epoch));
        }
    }
}
