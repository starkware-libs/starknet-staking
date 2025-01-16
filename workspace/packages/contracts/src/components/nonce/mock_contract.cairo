#[starknet::contract]
pub mod NonceMock {
    use contracts_commons::components::nonce::NonceComponent;

    component!(path: NonceComponent, storage: nonce, event: NonceEvent);

    #[abi(embed_v0)]
    impl NoncesImpl = NonceComponent::NonceImpl<ContractState>;
    impl InternalImpl = NonceComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub nonce: NonceComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        NonceEvent: NonceComponent::Event,
    }
}
