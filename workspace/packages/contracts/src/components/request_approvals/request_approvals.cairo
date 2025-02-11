#[starknet::component]
pub(crate) mod RequestApprovalsComponent {
    use contracts_commons::components::request_approvals::errors;
    use contracts_commons::components::request_approvals::interface::{
        IRequestApprovals, RequestStatus,
    };
    use contracts_commons::message_hash::OffchainMessageHash;
    use contracts_commons::types::{HashType, PublicKey};
    use contracts_commons::utils::validate_stark_signature;
    use core::num::traits::Zero;
    use core::panic_with_felt252;
    use openzeppelin::utils::snip12::StructHash;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        pub approved_requests: Map<HashType, RequestStatus>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(RequestApprovalsImpl)]
    impl RequestApprovals<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IRequestApprovals<ComponentState<TContractState>> {
        fn get_request_status(
            self: @ComponentState<TContractState>, request_hash: felt252,
        ) -> RequestStatus {
            self._get_request_status(:request_hash)
        }
    }


    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Registers an approval for a request.
        /// If the owner_account is non-zero, the caller must be the owner_account.
        /// The approval is signed with the public key.
        /// The signature is verified with the hash of the request.
        /// The request is stored with a status of PENDING.
        fn register_approval<T, +StructHash<T>, +OffchainMessageHash<T>, +Drop<T>>(
            ref self: ComponentState<TContractState>,
            owner_account: ContractAddress,
            public_key: PublicKey,
            signature: Span<felt252>,
            args: T,
        ) -> HashType {
            let request_hash = args.get_message_hash(:public_key);
            assert(
                self._get_request_status(:request_hash) == RequestStatus::NOT_EXIST,
                errors::REQUEST_ALREADY_REGISTERED,
            );
            if owner_account.is_non_zero() {
                assert(owner_account == get_caller_address(), errors::CALLER_IS_NOT_OWNER_ACCOUNT);
            }
            validate_stark_signature(:public_key, msg_hash: request_hash, :signature);
            self.approved_requests.write(key: request_hash, value: RequestStatus::PENDING);
            request_hash
        }

        /// Consumes an approved request.
        /// The request marked with a status of DONE.
        ///
        /// Validations:
        /// The request must be registered with PENDING state.
        /// The request must not be in the DONE state.
        fn consume_approved_request<T, +StructHash<T>, +OffchainMessageHash<T>, +Drop<T>>(
            ref self: ComponentState<TContractState>, args: T, public_key: PublicKey,
        ) -> HashType {
            let request_hash = args.get_message_hash(:public_key);
            let request_status = self._get_request_status(:request_hash);
            match request_status {
                RequestStatus::NOT_EXIST => panic_with_felt252(errors::REQUEST_NOT_REGISTERED),
                RequestStatus::DONE => panic_with_felt252(errors::REQUEST_ALREADY_PROCESSED),
                RequestStatus::PENDING => {},
            };
            self.approved_requests.write(request_hash, RequestStatus::DONE);
            request_hash
        }
    }

    #[generate_trait]
    impl PrivateImpl<
        TContractState, +HasComponent<TContractState>,
    > of PrivateTrait<TContractState> {
        fn _get_request_status(
            self: @ComponentState<TContractState>, request_hash: felt252,
        ) -> RequestStatus {
            self.approved_requests.read(request_hash)
        }
    }
}
