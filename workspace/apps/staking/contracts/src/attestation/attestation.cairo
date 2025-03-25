#[starknet::contract]
pub mod Attestation {
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use core::hash::HashStateTrait;
    use core::num::traits::Zero;
    use core::poseidon::PoseidonTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use staking::attestation::errors::Error;
    use staking::attestation::interface::{Events, IAttestation};
    use staking::constants::MIN_ATTESTATION_WINDOW;
    use staking::staking::interface::{
        IStakingAttestationDispatcher, IStakingAttestationDispatcherTrait, IStakingDispatcher,
        IStakingDispatcherTrait,
    };
    use staking::staking::objects::{
        AttestationInfo as StakingAttestationInfo, AttestationInfoTrait,
    };
    use staking::types::Epoch;
    use starknet::storage::Map;
    use starknet::syscalls::get_block_hash_syscall;
    use starknet::{ContractAddress, get_block_number, get_caller_address};
    use starkware_utils::components::replaceability::ReplaceabilityComponent;
    use starkware_utils::components::replaceability::ReplaceabilityComponent::InternalReplaceabilityTrait;
    use starkware_utils::components::roles::RolesComponent;
    use starkware_utils::interfaces::identity::Identity;
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
        // Maps staker address to the last epoch it attested.
        staker_last_attested_epoch: Map<ContractAddress, Epoch>,
        // Number of blocks where the staker can attest after the expected attestation block.
        // Note: that it still needs to be after the minimum attestation window.
        attestation_window: u16,
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
        StakerAttestationSuccessful: Events::StakerAttestationSuccessful,
        AttestationWindowChanged: Events::AttestationWindowChanged,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        staking_contract: ContractAddress,
        governance_admin: ContractAddress,
        attestation_window: u16,
    ) {
        self.roles.initialize(:governance_admin);
        self.replaceability.initialize(upgrade_delay: Zero::zero());
        self.staking_contract.write(staking_contract);
        assert!(attestation_window >= MIN_ATTESTATION_WINDOW, "{}", Error::ATTEST_WINDOW_TOO_SMALL);
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
        fn attest(ref self: ContractState, block_hash: felt252) {
            let operational_address = get_caller_address();
            let staking_dispatcher = IStakingAttestationDispatcher {
                contract_address: self.staking_contract.read(),
            };
            // Note: This function checks for a zero staker address and will panic if so.
            let staking_attestation_info = staking_dispatcher
                .get_attestation_info_by_operational_address(:operational_address);
            self._validate_attestation(:block_hash, :staking_attestation_info);
            // Work is one tx per epoch.
            self
                ._mark_attestation_is_done(
                    staker_address: staking_attestation_info.staker_address(),
                    current_epoch: staking_attestation_info.epoch_id(),
                );
            staking_dispatcher
                .update_rewards_from_attestation_contract(
                    staker_address: staking_attestation_info.staker_address(),
                );
        }

        fn get_last_epoch_attestation_done(
            self: @ContractState, staker_address: ContractAddress,
        ) -> Epoch {
            self.staker_last_attested_epoch.read(staker_address)
        }

        fn is_attestation_done_in_curr_epoch(
            self: @ContractState, staker_address: ContractAddress,
        ) -> bool {
            let staking_dispatcher = IStakingDispatcher {
                contract_address: self.staking_contract.read(),
            };
            let current_epoch = staking_dispatcher.get_current_epoch();
            assert!(current_epoch.is_non_zero(), "{}", Error::ATTEST_EPOCH_ZERO);
            self.get_last_epoch_attestation_done(:staker_address) == current_epoch
        }

        /// This function is used to help integration partners test the correct
        /// computation of the expected attestation block.
        /// It is not intended to be used in production, due to it's limitations as stated
        /// below.
        ///
        /// **Note**: This function does not return the correct result if it is called in
        ///  the same epoch that an attestation info update is performed in.
        /// In addition, it assumes no changes to the staking power or any other parameters
        /// that affect the attestation block calculation.
        fn validate_next_epoch_attestation_block(
            self: @ContractState, operational_address: ContractAddress, block_number: u64,
        ) -> bool {
            let attestation_window = self.attestation_window.read();
            let staking_dispatcher = IStakingAttestationDispatcher {
                contract_address: self.staking_contract.read(),
            };
            let attestation_info = staking_dispatcher
                .get_attestation_info_by_operational_address(:operational_address);
            let next_attestation_info = attestation_info.get_next_epoch_attestation_info();
            let expected_attestation_block = self
                ._calculate_expected_attestation_block(
                    staking_attestation_info: next_attestation_info, :attestation_window,
                );
            expected_attestation_block == block_number
        }

        fn attestation_window(self: @ContractState) -> u16 {
            self.attestation_window.read()
        }

        fn set_attestation_window(ref self: ContractState, attestation_window: u16) {
            self.roles.only_app_governor();
            assert!(
                attestation_window >= MIN_ATTESTATION_WINDOW, "{}", Error::ATTEST_WINDOW_TOO_SMALL,
            );
            let old_attestation_window = self.attestation_window.read();
            self.attestation_window.write(attestation_window);
            self
                .emit(
                    Events::AttestationWindowChanged {
                        old_attestation_window, new_attestation_window: attestation_window,
                    },
                );
        }
    }

    #[generate_trait]
    impl InternalAttestationFunctions of InternalAttestationFunctionsTrait {
        fn _validate_attestation(
            ref self: ContractState,
            block_hash: felt252,
            staking_attestation_info: StakingAttestationInfo,
        ) {
            let staker_address = staking_attestation_info.staker_address();
            let current_epoch = staking_attestation_info.epoch_id();
            assert!(current_epoch.is_non_zero(), "{}", Error::ATTEST_EPOCH_ZERO);
            self._assert_attestation_is_not_done(:staker_address, :current_epoch);
            let attestation_window = self.attestation_window.read();
            let expected_attestation_block = self
                ._calculate_expected_attestation_block(
                    :staking_attestation_info, :attestation_window,
                );
            self._assert_attest_in_window(:expected_attestation_block, :attestation_window);

            // Check the attestation data (correct block hash).
            let expected_block_hash = self.get_expected_block_hash(:expected_attestation_block);
            assert!(expected_block_hash == block_hash, "{}", Error::ATTEST_WRONG_BLOCK_HASH);
        }

        fn _assert_attestation_is_not_done(
            ref self: ContractState, staker_address: ContractAddress, current_epoch: Epoch,
        ) {
            let last_epoch_done = self.staker_last_attested_epoch.read(staker_address);
            assert!(current_epoch > last_epoch_done, "{}", Error::ATTEST_IS_DONE);
        }

        fn _mark_attestation_is_done(
            ref self: ContractState, staker_address: ContractAddress, current_epoch: Epoch,
        ) {
            self.staker_last_attested_epoch.write(staker_address, current_epoch);
            self.emit(Events::StakerAttestationSuccessful { staker_address, epoch: current_epoch });
        }

        fn _calculate_expected_attestation_block(
            self: @ContractState,
            staking_attestation_info: StakingAttestationInfo,
            attestation_window: u16,
        ) -> u64 {
            // Compute staker hash for the attestation.
            let hash = PoseidonTrait::new()
                .update(staking_attestation_info.stake().into())
                .update(staking_attestation_info.epoch_id().into())
                .update(staking_attestation_info.staker_address().into())
                .finalize();
            // Calculate staker's block number in this epoch.
            let block_offset: u256 = hash
                .into() % (staking_attestation_info.epoch_len() - attestation_window.into())
                .into();
            // Calculate actual block number for attestation.
            let expected_attestation_block = staking_attestation_info.current_epoch_starting_block()
                + block_offset.try_into().unwrap();
            expected_attestation_block
        }

        fn _assert_attest_in_window(
            self: @ContractState, expected_attestation_block: u64, attestation_window: u16,
        ) {
            let current_block_number = get_block_number();
            let min_block = expected_attestation_block + MIN_ATTESTATION_WINDOW.into();
            let max_block = expected_attestation_block + attestation_window.into();
            assert!(
                min_block <= current_block_number && current_block_number <= max_block,
                "{}",
                Error::ATTEST_OUT_OF_WINDOW,
            );
        }

        /// **Note**: This function has two implementations.
        /// In test environments, the syscall is not supported, returns zero or errors unexpectedly.
        /// This allows the function to be tested without relying on the actual block hash
        /// retrieval syscall.
        #[cfg(not(target: 'test'))]
        fn get_expected_block_hash(
            self: @ContractState, expected_attestation_block: u64,
        ) -> felt252 {
            get_block_hash_syscall(expected_attestation_block).unwrap()
        }

        #[cfg(target: 'test')]
        fn get_expected_block_hash(
            self: @ContractState, expected_attestation_block: u64,
        ) -> felt252 {
            Zero::zero()
        }
    }
}
