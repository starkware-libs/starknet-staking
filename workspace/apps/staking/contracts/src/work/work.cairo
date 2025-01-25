#[starknet::contract]
pub mod Work {
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use contracts_commons::components::roles::RolesComponent;
    use contracts_commons::interfaces::identity::Identity;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use staking::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use staking::types::Epoch;
    use staking::work::errors::Error;
    use staking::work::interface::{IWork, WorkInfo};
    use starknet::storage::Map;
    use starknet::{ContractAddress, get_caller_address};
    pub const CONTRACT_IDENTITY: felt252 = 'Work';
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
        // Maps staker address to the last epoch he finished work.
        work_is_done: Map<ContractAddress, Epoch>,
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
    impl WorkImpl of IWork<ContractState> {
        fn work(ref self: ContractState, work_info: WorkInfo) {
            let operational_address = get_caller_address();
            let staking_dispatcher = self.staking_dispatcher.read();
            // Note: This function checks for a zero staker address and will panic if so.
            let staker_address = staking_dispatcher
                .get_staker_address_by_operational(:operational_address);
            let current_epoch = staking_dispatcher.get_current_epoch();
            self._validate_work(:work_info, :staker_address, :current_epoch);
            staking_dispatcher.update_rewards_from_work_contract(:staker_address);
            // TODO: emit event.
        }

        fn get_last_epoch_work_done(self: @ContractState, address: ContractAddress) -> Epoch {
            self.work_is_done.read(address)
        }

        fn is_work_done_in_curr_epoch(self: @ContractState, address: ContractAddress) -> bool {
            self.work_is_done.read(address) == self.staking_dispatcher.read().get_current_epoch()
        }
    }

    #[generate_trait]
    impl InternalWorkFunctions of InternalWorkFunctionsTrait {
        fn _validate_work(
            ref self: ContractState,
            work_info: WorkInfo,
            staker_address: ContractAddress,
            current_epoch: Epoch,
        ) {
            self._assert_work_is_not_done(:staker_address, :current_epoch);
            // TODO: Validate the work.
            // Work is one tx per epoch.
            self._mark_work_is_done(:staker_address, :current_epoch);
        }

        fn _assert_work_is_not_done(
            ref self: ContractState, staker_address: ContractAddress, current_epoch: Epoch,
        ) {
            assert!(
                self.work_is_done.read(staker_address) < current_epoch, "{}", Error::WORK_IS_DONE,
            );
        }

        fn _mark_work_is_done(
            ref self: ContractState, staker_address: ContractAddress, current_epoch: Epoch,
        ) {
            self.work_is_done.write(staker_address, current_epoch);
        }
    }
}
