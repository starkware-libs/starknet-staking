/// # Nonce Component
///
/// The Nonce component provides a simple mechanism for handling incremental nonce. It is commonly
/// used to prevent replay attacks when contracts accept signatures as input.
#[starknet::component]
pub mod NonceComponent {
    use contracts_commons::components::nonce::interface::INonce;

    #[storage]
    pub struct Storage {
        pub nonce: u64,
    }

    #[embeddable_as(NonceImpl)]
    impl Nonce<
        TContractState, +HasComponent<TContractState>,
    > of INonce<ComponentState<TContractState>> {
        /// Returns the next unused nonce for an address.
        fn nonce(self: @ComponentState<TContractState>) -> u64 {
            self.nonce.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Consumes a nonce, returns the current value, and increments nonce.
        fn use_next_nonce(ref self: ComponentState<TContractState>) -> u64 {
            let nonce = self.nonce.read();
            self.nonce.write(nonce + 1);
            nonce
        }

        /// Same as `use_next_nonce` but checking that `nonce` is the next valid one.
        fn use_checked_nonce(ref self: ComponentState<TContractState>, nonce: u64) -> u64 {
            let current = self.use_next_nonce();
            assert!(
                nonce == current, "Nonce: invalid nonce: current!=recieved {}!={}", current, nonce,
            );
            current
        }
    }
}
