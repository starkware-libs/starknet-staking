use starknet::ContractAddress;


#[derive(Drop, Serde, starknet::Store)]
pub struct StakerInfo {
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub unstake_time: Option<felt252>,
    pub amount: u128,
    pub index: u128,
    pub unclaimed_rewards: u128,
}


#[derive(Drop, Serde)]
pub struct StakingContractInfo {
    pub max_leverage: u128,
    pub min_stake: u128,
}

#[starknet::interface]
pub trait IStaking<TContractState> {
    fn stake(
        ref self: TContractState,
        reward_address: ContractAddress,
        operational_address: ContractAddress,
        amount: u128,
        pooling_enabled: bool
    ) -> bool;
    fn increase_stake(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> u128;
    fn claim_rewards(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn unstake_intent(ref self: TContractState, staker_address: ContractAddress) -> felt252;
    fn unstake_action(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn add_to_pool(ref self: TContractState, staker_address: ContractAddress, amount: u128) -> u128;
    fn remove_from_pool_intent(
        ref self: TContractState, staker_address: ContractAddress, amount: u128
    ) -> felt252;
    fn remove_from_pool_action(ref self: TContractState, staker_address: ContractAddress) -> u128;
    fn switch_pool(
        ref self: TContractState,
        from_staker_address: ContractAddress,
        to_staker_address: ContractAddress,
        pool_address: ContractAddress,
        amount: u128,
        data: ByteArray
    ) -> bool;
    fn change_reward_address(ref self: TContractState, reward_address: ContractAddress) -> bool;
    fn set_open_for_pooling(ref self: TContractState) -> ContractAddress;
    fn state_of(self: @TContractState, staker_address: ContractAddress) -> StakerInfo;
    fn contract_parameters(self: @TContractState) -> StakingContractInfo;
}

#[starknet::contract]
pub mod Staking {
    use starknet::{ContractAddress, get_block_timestamp, contract_address_const};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use super::{StakerInfo, StakingContractInfo};


    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);


    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        global_index: u128,
        min_stake: u128,
        staker_address_to_staker_info: LegacyMap::<ContractAddress, StakerInfo>,
        operational_address_to_staker_address: LegacyMap::<ContractAddress, ContractAddress>,
        global_rev_share: u128,
        max_leverage: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct BalanceChanged {
        staker_address: ContractAddress,
        amount: u128
    }

    #[derive(Drop, starknet::Event)]
    struct NewPool {
        staker_address: ContractAddress,
        pooling_contract_address: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}


    #[abi(embed_v0)]
    impl StakingImpl of super::IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u128,
            pooling_enabled: bool
        ) -> bool {
            true
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            0
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            0
        }

        fn unstake_intent(ref self: ContractState, staker_address: ContractAddress) -> felt252 {
            0
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            0
        }

        fn add_to_pool(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            0
        }

        fn remove_from_pool_intent(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> felt252 {
            0
        }

        fn remove_from_pool_action(
            ref self: ContractState, staker_address: ContractAddress
        ) -> u128 {
            0
        }

        fn switch_pool(
            ref self: ContractState,
            from_staker_address: ContractAddress,
            to_staker_address: ContractAddress,
            pool_address: ContractAddress,
            amount: u128,
            data: ByteArray
        ) -> bool {
            true
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            true
        }

        fn set_open_for_pooling(ref self: ContractState) -> ContractAddress {
            contract_address_const::<0>()
        }

        fn state_of(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            StakerInfo {
                reward_address: contract_address_const::<0>(),
                operational_address: contract_address_const::<0>(),
                unstake_time: Option::None,
                amount: 0,
                index: 0,
                unclaimed_rewards: 0,
            }
        }

        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            StakingContractInfo { min_stake: 0, max_leverage: 0 }
        }
    }


    #[generate_trait]
    impl InternalStakingFunctions of InternalStakingFunctionsTrait {
        fn calculate_rewards(ref self: ContractState, staker_address: ContractAddress) -> bool {
            true
        }
    }
}
