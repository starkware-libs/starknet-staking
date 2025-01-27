#[starknet::contract]
pub mod Attestation {
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use contracts_commons::components::roles::RolesComponent;
    use contracts_commons::errors::OptionAuxTrait;
    use contracts_commons::interfaces::identity::Identity;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use staking::attestation::errors::Error;
    use staking::attestation::interface::{AttestInfo, IAttestation};
    use staking::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
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
        staking_dispatcher: IStakingDispatcher,
        // Maps staker address to the last epoch he attested.
        staker_last_attested_epoch: Map<ContractAddress, Option<Epoch>>,
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

    // TODO: initialize roles?
    #[constructor]
    pub fn constructor(ref self: ContractState, staking_contract: ContractAddress) {
        self.staking_dispatcher.write(IStakingDispatcher { contract_address: staking_contract });
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
            let staking_dispatcher = self.staking_dispatcher.read();
            // Note: This function checks for a zero staker address and will panic if so.
            let staker_address = staking_dispatcher
                .get_staker_address_by_operational(:operational_address);
            let current_epoch = staking_dispatcher.get_current_epoch();
            self._validate_attestation(:attest_info, :staker_address, :current_epoch);
            staking_dispatcher.update_rewards_from_attestation_contract(:staker_address);
            // TODO: emit event.
        }

        fn get_last_epoch_attestation_done(
            self: @ContractState, address: ContractAddress,
        ) -> Epoch {
            self.staker_last_attested_epoch.read(address).expect_with_err(Error::NO_ATTEST_DONE)
        }

        fn is_attestation_done_in_curr_epoch(
            self: @ContractState, address: ContractAddress,
        ) -> bool {
            let current_epoch = self.staking_dispatcher.read().get_current_epoch();
            self.get_last_epoch_attestation_done(:address) == current_epoch
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
