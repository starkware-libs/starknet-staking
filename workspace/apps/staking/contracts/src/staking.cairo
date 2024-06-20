#[starknet::interface]
trait EmptyContractInterface<T> {
}

#[starknet::contract]
mod my_contract {
    
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;


    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl = AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
    }
}
