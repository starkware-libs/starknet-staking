#[starknet::component]
pub(crate) mod PausableComponent {
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use contracts_commons::components::pausable::interface::IPausable;
    use contracts_commons::components::roles::RolesComponent;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        pub paused: bool,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Paused: Paused,
        Unpaused: Unpaused,
    }

    /// Emitted when paused, where `account` triggered the action.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Paused {
        pub account: ContractAddress,
    }

    /// Emitted when un-paused, where `account` triggered the action.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Unpaused {
        pub account: ContractAddress,
    }

    pub mod Errors {
        pub const PAUSED: felt252 = 'PAUSED';
        pub const NOT_PAUSED: felt252 = 'NOT_PAUSED';
    }

    #[embeddable_as(PausableImpl)]
    impl Pausable<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Roles: RolesComponent::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
    > of IPausable<ComponentState<TContractState>> {
        /// Returns true if the contract is paused, and false otherwise.
        fn is_paused(self: @ComponentState<TContractState>) -> bool {
            self.paused.read()
        }

        /// Triggers a stopped state.
        ///
        /// Requirements:
        ///
        /// - The contract is not paused.
        ///
        /// Emits a `Paused` event.
        fn pause(ref self: ComponentState<TContractState>) {
            let roles = get_dep_component!(@self, Roles);
            roles.only_security_agent();
            self.assert_not_paused();
            self.paused.write(true);
            self.emit(Paused { account: get_caller_address() });
        }

        /// Lifts the pause on the contract.
        ///
        /// Requirements:
        ///
        /// - The contract is paused.
        ///
        /// Emits an `Unpaused` event.
        fn unpause(ref self: ComponentState<TContractState>) {
            let roles = get_dep_component!(@self, Roles);
            roles.only_security_admin();
            self.assert_paused();
            self.paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Makes a function only callable when the contract is not paused.
        fn assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self.paused.read(), Errors::PAUSED);
        }

        /// Makes a function only callable when the contract is paused.
        fn assert_paused(self: @ComponentState<TContractState>) {
            assert(self.paused.read(), Errors::NOT_PAUSED);
        }
    }
}
