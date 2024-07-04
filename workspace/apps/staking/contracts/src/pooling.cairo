use starknet::ContractAddress;

#[starknet::interface]
trait IPooling<TContractState> {
    fn pool(ref self: TContractState, amount: u128, reward_address: ContractAddress) -> bool;
    fn increase_pool(ref self: TContractState, amount: u128) -> u128;
    fn unpool_intent(ref self: TContractState) -> u128;
    fn unpool_action(ref self: TContractState) -> u128;
    fn claim_rewards(ref self: TContractState, pooler_address: ContractAddress) -> u128;
// fn switch_pool()
// fn enter_from_staking_contract
}

#[starknet::contract]
mod pooling {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;


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
        pooler_address_to_info: LegacyMap::<ContractAddress, PoolerInfo>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[derive(Drop, Serde, starknet::Store)]
    struct PoolerInfo {
        reward_address: ContractAddress,
        amount: u128,
        index: u128,
        unclaimed_rewards: u128,
        unpool_time: Option<felt252>,
    }

    #[abi(embed_v0)]
    impl PoolingImpl of super::IPooling<ContractState> {
        fn pool(ref self: ContractState, amount: u128, reward_address: ContractAddress) -> bool {
            true
        }
        fn increase_pool(ref self: ContractState, amount: u128) -> u128 {
            0
        }
        fn unpool_intent(ref self: ContractState) -> u128 {
            0
        }
        fn unpool_action(ref self: ContractState) -> u128 {
            0
        }
        fn claim_rewards(ref self: ContractState, pooler_address: ContractAddress) -> u128 {
            0
        }
    }
}
