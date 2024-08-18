#[starknet::component]
pub mod ReplaceabilityComponent {
    use contracts_commons::components::replaceability::interface::EIC_INITIALIZE_SELECTOR;
    use contracts_commons::components::replaceability::interface::IMPLEMENTATION_EXPIRATION;
    use contracts_commons::components::replaceability::interface::ImplementationAdded;
    use contracts_commons::components::replaceability::interface::ImplementationData;
    use contracts_commons::components::replaceability::interface::ImplementationFinalized;
    use contracts_commons::components::replaceability::interface::ImplementationRemoved;
    use contracts_commons::components::replaceability::interface::ImplementationReplaced;
    use contracts_commons::components::replaceability::interface::IReplaceable;
    use contracts_commons::components::roles::RolesComponent;
    use contracts_commons::components::roles::RolesComponent::InternalTrait;
    use contracts_commons::errors::ReplaceErrors;
    use core::num::traits::Zero;
    use core::poseidon;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::get_block_timestamp;
    use starknet::syscalls::{library_call_syscall, replace_class_syscall};
    use starknet::storage::Map;


    #[storage]
    struct Storage {
        // Delay in seconds before performing an upgrade.
        upgrade_delay: u64,
        // Timestamp by which implementation can be activated.
        impl_activation_time: Map<felt252, u64>,
        // Timestamp until which implementation can be activated.
        impl_expiration_time: Map<felt252, u64>,
        // Is the implementation finalized.
        finalized: bool,
    }

    #[event]
    #[derive(Copy, Drop, PartialEq, starknet::Event)]
    pub enum Event {
        ImplementationAdded: ImplementationAdded,
        ImplementationRemoved: ImplementationRemoved,
        ImplementationReplaced: ImplementationReplaced,
        ImplementationFinalized: ImplementationFinalized,
    }

    // Derives the implementation_data key.
    fn calc_impl_key(implementation_data: ImplementationData) -> felt252 {
        // Hash the implementation_data to obtain a key.
        let mut hash_input = ArrayTrait::new();
        implementation_data.serialize(ref hash_input);
        poseidon::poseidon_hash_span(hash_input.span())
    }

    #[embeddable_as(ReplaceabilityImpl)]
    pub impl Replaceability<
        TContractState,
        +HasComponent<TContractState>,
        impl Roles: RolesComponent::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IReplaceable<ComponentState<TContractState>> {
        fn get_upgrade_delay(self: @ComponentState<TContractState>) -> u64 {
            self.upgrade_delay.read()
        }

        fn get_impl_activation_time(
            self: @ComponentState<TContractState>, implementation_data: ImplementationData
        ) -> u64 {
            let impl_key = calc_impl_key(:implementation_data);
            self.impl_activation_time.read(impl_key)
        }

        fn add_new_implementation(
            ref self: ComponentState<TContractState>, implementation_data: ImplementationData
        ) {
            // The call is restricted to the upgrade governor.
            let roles_comp = get_dep_component!(@self, Roles);
            roles_comp.only_upgrade_governor();

            let activation_time = get_block_timestamp() + self.get_upgrade_delay();
            let expiration_time = activation_time + IMPLEMENTATION_EXPIRATION;
            // TODO(Yaniv, 01/08/2024) -  add an assertion that the `implementation_data.impl_hash`
            // is declared.
            self.set_impl_activation_time(:implementation_data, :activation_time);
            self.set_impl_expiration_time(:implementation_data, :expiration_time);
            self.emit(ImplementationAdded { implementation_data });
        }

        fn remove_implementation(
            ref self: ComponentState<TContractState>, implementation_data: ImplementationData
        ) {
            // The call is restricted to the upgrade governor.
            let roles_comp = get_dep_component!(@self, Roles);
            roles_comp.only_upgrade_governor();

            // Read implementation activation time.
            let impl_activation_time = self.get_impl_activation_time(:implementation_data);

            if (impl_activation_time.is_non_zero()) {
                self.set_impl_activation_time(:implementation_data, activation_time: 0);
                self.set_impl_expiration_time(:implementation_data, expiration_time: 0);
                self.emit(ImplementationRemoved { implementation_data });
            }
        }

        // Replaces the non-finalized current implementation to one that was previously added and
        // whose activation time had passed.
        fn replace_to(
            ref self: ComponentState<TContractState>, implementation_data: ImplementationData
        ) {
            // The call is restricted to the upgrade governor.
            let roles_comp = get_dep_component!(@self, Roles);
            roles_comp.only_upgrade_governor();

            // Validate implementation is not finalized.
            assert(!self.is_finalized(), ReplaceErrors::FINALIZED);

            let now = get_block_timestamp();
            let impl_activation_time = self.get_impl_activation_time(:implementation_data);
            let impl_expiration_time = self.get_impl_expiration_time(:implementation_data);

            // Zero activation time means that this implementation & init vector combination
            // was not previously added.
            assert(impl_activation_time.is_non_zero(), ReplaceErrors::UNKNOWN_IMPLEMENTATION);

            assert(impl_activation_time <= now, ReplaceErrors::NOT_ENABLED_YET);
            assert(now <= impl_expiration_time, ReplaceErrors::IMPLEMENTATION_EXPIRED);
            // We emit now so that finalize emits last (if it does).
            self.emit(ImplementationReplaced { implementation_data });

            // Finalize imeplementation, if needed.
            if (implementation_data.final) {
                self.finalize();
                self.emit(ImplementationFinalized { impl_hash: implementation_data.impl_hash });
            }

            // Handle EIC.
            match implementation_data.eic_data {
                Option::Some(eic_data) => {
                    // Wrap the calldata as a span, as preperation for the library_call_syscall
                    // invocation.
                    let mut calldata_wrapper = ArrayTrait::new();
                    eic_data.eic_init_data.serialize(ref calldata_wrapper);

                    // Invoke the EIC's initialize function as a library call.
                    let res = library_call_syscall(
                        class_hash: eic_data.eic_hash,
                        function_selector: EIC_INITIALIZE_SELECTOR,
                        calldata: calldata_wrapper.span()
                    );
                    assert(res.is_ok(), ReplaceErrors::EIC_LIB_CALL_FAILED);
                },
                Option::None(()) => {}
            };

            // Replace the class hash.
            let result = replace_class_syscall(implementation_data.impl_hash);
            assert(result.is_ok(), ReplaceErrors::REPLACE_CLASS_HASH_FAILED);

            // Remove implementation data, as it was comsumed.
            self.set_impl_activation_time(:implementation_data, activation_time: 0);
            self.set_impl_expiration_time(:implementation_data, expiration_time: 0);
        }
    }

    #[generate_trait]
    pub impl InternalReplaceability<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of InternalReplaceableTrait<TContractState> {
        fn is_finalized(self: @ComponentState<TContractState>) -> bool {
            self.finalized.read()
        }

        fn finalize(ref self: ComponentState<TContractState>) {
            self.finalized.write(true);
        }

        fn set_impl_activation_time(
            ref self: ComponentState<TContractState>,
            implementation_data: ImplementationData,
            activation_time: u64
        ) {
            let impl_key = calc_impl_key(:implementation_data);
            self.impl_activation_time.write(impl_key, activation_time);
        }

        fn get_impl_expiration_time(
            self: @ComponentState<TContractState>, implementation_data: ImplementationData
        ) -> u64 {
            let impl_key = calc_impl_key(:implementation_data);
            self.impl_expiration_time.read(impl_key)
        }

        fn set_impl_expiration_time(
            ref self: ComponentState<TContractState>,
            implementation_data: ImplementationData,
            expiration_time: u64
        ) {
            let impl_key = calc_impl_key(:implementation_data);
            self.impl_expiration_time.write(impl_key, expiration_time);
        }
    }
}
