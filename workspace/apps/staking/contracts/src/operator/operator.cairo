#[starknet::contract]
pub mod Operator {
    use contracts::operator::IOperator;
    use contracts::staking::{IStaking, StakerInfo, StakingContractInfo};
    use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use contracts_commons::components::roles::RolesComponent;
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use core::num::traits::zero::Zero;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{Map, Vec, MutableVecTrait, VecTrait};
    use contracts::errors::{Error, panic_by_err};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::cmp::min;

    pub const MAX_WHITELIST_SIZE: u64 = 100;

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

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
        whitelist_enabled: bool,
        whitelist: Vec<ContractAddress>,
        whitelist_map: Map<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState, staking_address: ContractAddress, security_admin: ContractAddress
    ) {
        self.accesscontrol.initializer();
        self.roles.initializer();
        self.replaceability.upgrade_delay.write(Zero::zero());
        self.staking_dispatcher.write(IStakingDispatcher { contract_address: staking_address });
        self.roles.register_security_admin(account: security_admin);
        self.whitelist_enabled.write(false);
    }

    #[abi(embed_v0)]
    impl OperatorImpl of IOperator<ContractState> {
        fn enable_whitelist(ref self: ContractState) {
            self.roles.only_security_agent();
            self.whitelist_enabled.write(true);
        }

        fn disable_whitelist(ref self: ContractState) {
            self.roles.only_security_admin();
            self.whitelist_enabled.write(false);
        }

        fn is_whitelist_enabled(self: @ContractState) -> bool {
            self.whitelist_enabled.read()
        }

        fn add_to_whitelist(ref self: ContractState, address: ContractAddress) {
            self.roles.only_security_admin();
            if self.whitelist.len() >= MAX_WHITELIST_SIZE {
                panic_by_err(Error::WHITELIST_FULL);
            }
            if self.is_in_whitelist(address) {
                return;
            }
            self.whitelist.append().write(address);
            self.whitelist_map.write(address, true);
        }

        fn get_whitelist_addresses(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            let len: u64 = min(self.whitelist.len(), MAX_WHITELIST_SIZE);
            for i in 0..len {
                addresses.append(self.whitelist.at(i).read());
            };
            addresses
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn check_whitelist(self: @ContractState, address: ContractAddress) {
            if self.is_whitelist_enabled() && !self.is_in_whitelist(address) {
                panic_by_err(Error::NOT_WHITELISTED);
            }
        }

        fn is_in_whitelist(self: @ContractState, address: ContractAddress) -> bool {
            self.whitelist_map.read(address)
        }
    }

    #[abi(embed_v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u128,
            pool_enabled: bool,
            commission: u16,
        ) -> bool {
            self.check_whitelist(get_caller_address());
            self
                .staking_dispatcher
                .read()
                .stake(:reward_address, :operational_address, :amount, :pool_enabled, :commission)
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            self.check_whitelist(get_caller_address());
            self.staking_dispatcher.read().increase_stake(:staker_address, :amount)
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            self.check_whitelist(get_caller_address());
            self.staking_dispatcher.read().claim_rewards(:staker_address)
        }

        fn unstake_intent(ref self: ContractState) -> u64 {
            self.check_whitelist(get_caller_address());
            self.staking_dispatcher.read().unstake_intent()
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            self.check_whitelist(get_caller_address());
            self.staking_dispatcher.read().unstake_action(:staker_address)
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            self.check_whitelist(get_caller_address());
            self.staking_dispatcher.read().change_reward_address(:reward_address)
        }

        fn set_open_for_delegation(ref self: ContractState, commission: u16) -> ContractAddress {
            self.check_whitelist(get_caller_address());
            self.staking_dispatcher.read().set_open_for_delegation(:commission)
        }

        fn state_of(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            self.staking_dispatcher.read().state_of(:staker_address)
        }

        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            self.staking_dispatcher.read().contract_parameters()
        }

        fn get_total_stake(self: @ContractState) -> u128 {
            self.staking_dispatcher.read().get_total_stake()
        }

        fn update_global_index_if_needed(ref self: ContractState) -> bool {
            self.check_whitelist(get_caller_address());
            self.staking_dispatcher.read().update_global_index_if_needed()
        }

        fn change_operational_address(
            ref self: ContractState, operational_address: ContractAddress
        ) -> bool {
            self.check_whitelist(get_caller_address());
            self.staking_dispatcher.read().change_operational_address(:operational_address)
        }

        // fn update_commission(ref self: ContractState, commission: u16) -> bool {
        //     self.check_whitelist(get_caller_address());
        //     self.staking_dispatcher.read().update_commission(:commission)
        // }

        fn is_paused(self: @ContractState) -> bool {
            self.staking_dispatcher.read().is_paused()
        }
    }
}
