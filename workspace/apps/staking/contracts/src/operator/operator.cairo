#[starknet::contract]
pub mod Operator {
    use contracts::staking::{IStaking, StakerInfo, StakingContractInfo};
    use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use contracts_commons::components::roles::RolesComponent;
    use core::num::traits::zero::Zero;
    use openzeppelin::{
        access::accesscontrol::AccessControlComponent, introspection::src5::SRC5Component
    };
    use starknet::ContractAddress;

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ReplaceabilityImpl =
        ReplaceabilityComponent::ReplaceabilityImpl<ContractState>;

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
        staking_dispatcher: IStakingDispatcher
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        RolesEvent: RolesComponent::Event,
        AccessControlEvent: AccessControlComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, staking_address: ContractAddress) {
        self.replaceability.upgrade_delay.write(Zero::zero());
        self.staking_dispatcher.write(IStakingDispatcher { contract_address: staking_address });
    }

    #[abi(embed_v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u128,
            pooling_enabled: bool,
            commission: u16,
        ) -> bool {
            self
                .staking_dispatcher
                .read()
                .stake(
                    :reward_address, :operational_address, :amount, :pooling_enabled, :commission
                )
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            self.staking_dispatcher.read().increase_stake(:staker_address, :amount)
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            self.staking_dispatcher.read().claim_rewards(:staker_address)
        }

        fn unstake_intent(ref self: ContractState) -> u64 {
            self.staking_dispatcher.read().unstake_intent()
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            self.staking_dispatcher.read().unstake_action(:staker_address)
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            self.staking_dispatcher.read().change_reward_address(:reward_address)
        }

        fn set_open_for_delegation(ref self: ContractState, commission: u16) -> ContractAddress {
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
            self.staking_dispatcher.read().update_global_index_if_needed()
        }

        fn change_operational_address(
            ref self: ContractState, operational_address: ContractAddress
        ) -> bool {
            self.staking_dispatcher.read().change_operational_address(:operational_address)
        }

        fn update_commission(ref self: ContractState, commission: u16) -> bool {
            self.staking_dispatcher.read().update_commission(:commission)
        }

        fn is_paused(self: @ContractState) -> bool {
            self.staking_dispatcher.read().is_paused()
        }
    }
}
