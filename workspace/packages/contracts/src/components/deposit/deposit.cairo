#[starknet::component]
pub(crate) mod Deposit {
    use contracts_commons::components::deposit::interface::{DepositStatus, IDeposit};
    use contracts_commons::components::deposit::{errors, events};
    use contracts_commons::types::HashType;
    use contracts_commons::types::time::time::{Time, TimeDelta};
    use contracts_commons::utils::{AddToStorage, SubFromStorage};
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::num::traits::Zero;
    use core::panic_with_felt252;
    use core::poseidon::PoseidonTrait;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::{Map, StorageMapReadAccess, StoragePathEntry};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};


    #[storage]
    pub struct Storage {
        registered_deposits: Map<HashType, DepositStatus>,
        aggregate_quantized_pending_deposits: Map<felt252, u128>,
        // asset_id -> (ContractAddress, quantum)
        asset_info: Map<felt252, (ContractAddress, u64)>,
        deposit_grace_period: TimeDelta,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Deposit: events::Deposit,
        DepositCanceled: events::DepositCanceled,
        DepositProcessed: events::DepositProcessed,
    }


    #[embeddable_as(DepositImpl)]
    impl Deposit<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of IDeposit<ComponentState<TContractState>> {
        /// Deposit is called by the user to add a deposit request.
        ///
        /// Validations:
        /// - The quantized amount must be greater than 0.
        /// - The deposit requested does not exists.
        ///
        /// Execution:
        /// - Transfers the quantized amount from the user to the contract.
        /// - Registers the deposit request.
        /// - Updates the deposit status to pending.
        /// - Updates the aggregate_quantized_pending_deposits.
        /// - Emits a Deposit event.
        fn deposit(
            ref self: ComponentState<TContractState>,
            beneficiary: u32,
            asset_id: felt252,
            quantized_amount: u128,
            salt: felt252,
        ) {
            assert(quantized_amount > 0, errors::ZERO_AMOUNT);
            let caller_address = get_caller_address();
            let deposit_hash = deposit_hash(
                depositor: caller_address, :beneficiary, :asset_id, :quantized_amount, :salt,
            );
            assert(
                self._get_deposit_status(:deposit_hash) == DepositStatus::NOT_EXIST,
                errors::DEPOSIT_ALREADY_REGISTERED,
            );
            self
                .registered_deposits
                .write(key: deposit_hash, value: DepositStatus::PENDING(Time::now()));
            let (token_address, quantum) = self._get_asset_info(:asset_id);
            self
                .aggregate_quantized_pending_deposits
                .entry(asset_id)
                .add_and_write(quantized_amount);

            let unquantized_amount = quantized_amount * quantum.into();
            let token_contract = IERC20Dispatcher { contract_address: token_address };
            token_contract
                .transfer_from(
                    sender: caller_address,
                    recipient: get_contract_address(),
                    amount: unquantized_amount.into(),
                );
            self
                .emit(
                    events::Deposit {
                        beneficiary,
                        depositing_address: caller_address,
                        asset_id,
                        quantized_amount,
                        unquantized_amount,
                        deposit_request_hash: deposit_hash,
                    },
                );
        }

        /// Cancel deposit is called by the user to cancel a deposit request which did not take
        /// place yet.
        ///
        /// Validations:
        /// - The deposit requested to cancel exists, is not canceled and is not processed.
        /// - The cancellation delay has passed.
        ///
        /// Execution:
        /// - Transfers the quantized amount back to the user.
        /// - Updates the deposit status to canceled.
        /// - Updates the aggregate_quantized_pending_deposits.
        /// - Emits a DepositCanceled event.
        fn cancel_deposit(
            ref self: ComponentState<TContractState>,
            beneficiary: u32,
            asset_id: felt252,
            quantized_amount: u128,
            salt: felt252,
        ) {
            let caller_address = get_caller_address();
            let deposit_hash = deposit_hash(
                depositor: caller_address, :beneficiary, :asset_id, :quantized_amount, :salt,
            );

            // Validations
            match self._get_deposit_status(:deposit_hash) {
                DepositStatus::PENDING(deposit_timestamp) => assert(
                    deposit_timestamp.add(self.deposit_grace_period.read()) < Time::now(),
                    errors::DEPOSIT_NOT_CANCELABLE,
                ),
                DepositStatus::NOT_EXIST => panic_with_felt252(errors::DEPOSIT_NOT_REGISTERED),
                DepositStatus::DONE => panic_with_felt252(errors::DEPOSIT_ALREADY_PROCESSED),
                DepositStatus::CANCELED => panic_with_felt252(errors::DEPOSIT_ALREADY_CANCELED),
            }

            self.registered_deposits.write(key: deposit_hash, value: DepositStatus::CANCELED);
            self
                .aggregate_quantized_pending_deposits
                .entry(asset_id)
                .sub_and_write(quantized_amount);
            let (token_address, quantum) = self._get_asset_info(:asset_id);

            let token_contract = IERC20Dispatcher { contract_address: token_address };
            let unquantized_amount = quantized_amount * quantum.into();
            token_contract.transfer(recipient: caller_address, amount: unquantized_amount.into());
            self
                .emit(
                    events::DepositCanceled {
                        beneficiary,
                        depositing_address: caller_address,
                        asset_id,
                        quantized_amount,
                        unquantized_amount,
                        deposit_request_hash: deposit_hash,
                    },
                );
        }

        fn get_deposit_status(
            self: @ComponentState<TContractState>, deposit_hash: HashType,
        ) -> DepositStatus {
            self._get_deposit_status(:deposit_hash)
        }

        fn get_asset_info(
            self: @ComponentState<TContractState>, asset_id: felt252,
        ) -> (ContractAddress, u64) {
            self._get_asset_info(:asset_id)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>, deposit_grace_period: TimeDelta) {
            assert(self.deposit_grace_period.read().is_zero(), errors::ALREADY_INITIALIZED);
            assert(deposit_grace_period.is_non_zero(), errors::INVALID_DEPOSIT_GRACE_PERIOD);
            self.deposit_grace_period.write(deposit_grace_period);
        }

        /// Each `asset_id` can be registered only once.
        /// Same `token_address` and `quantum` can be shared by different asset_id.
        fn register_token(
            ref self: ComponentState<TContractState>,
            asset_id: felt252,
            token_address: ContractAddress,
            quantum: u64,
        ) {
            let (_token_address, _) = self.asset_info.read(asset_id);
            assert(_token_address.is_zero(), errors::ASSET_ALREADY_REGISTERED);
            assert(token_address.is_non_zero(), errors::INVALID_ZERO_TOKEN_ADDRESS);
            assert(quantum.is_non_zero(), errors::INVALID_ZERO_QUANTUM);
            self.asset_info.write(key: asset_id, value: (token_address, quantum));
        }

        fn process_deposit(
            ref self: ComponentState<TContractState>,
            depositor: ContractAddress,
            beneficiary: u32,
            asset_id: felt252,
            quantized_amount: u128,
            salt: felt252,
        ) {
            assert(quantized_amount > 0, errors::ZERO_AMOUNT);
            let deposit_hash = deposit_hash(
                :depositor, :beneficiary, :asset_id, :quantized_amount, :salt,
            );
            let deposit_status = self._get_deposit_status(:deposit_hash);
            match deposit_status {
                DepositStatus::NOT_EXIST => { panic_with_felt252(errors::DEPOSIT_NOT_REGISTERED) },
                DepositStatus::DONE => { panic_with_felt252(errors::DEPOSIT_ALREADY_PROCESSED) },
                DepositStatus::CANCELED => { panic_with_felt252(errors::DEPOSIT_ALREADY_CANCELED) },
                DepositStatus::PENDING(_) => {},
            };
            let (_, quantum) = self._get_asset_info(:asset_id);
            self
                .aggregate_quantized_pending_deposits
                .entry(asset_id)
                .sub_and_write(quantized_amount);
            let unquantized_amount = quantized_amount * quantum.into();
            self
                .emit(
                    events::DepositProcessed {
                        beneficiary,
                        depositing_address: depositor,
                        asset_id,
                        quantized_amount,
                        unquantized_amount,
                        deposit_request_hash: deposit_hash,
                    },
                );
            self.registered_deposits.write(deposit_hash, DepositStatus::DONE);
        }

        fn get_asset_aggregate_quantized_pending_deposits(
            self: @ComponentState<TContractState>, asset_id: felt252,
        ) -> u128 {
            self.aggregate_quantized_pending_deposits.read(asset_id)
        }
    }

    #[generate_trait]
    impl PrivateImpl<
        TContractState, +HasComponent<TContractState>,
    > of PrivateTrait<TContractState> {
        fn _get_deposit_status(
            self: @ComponentState<TContractState>, deposit_hash: HashType,
        ) -> DepositStatus {
            self.registered_deposits.read(deposit_hash)
        }

        fn _get_asset_info(
            self: @ComponentState<TContractState>, asset_id: felt252,
        ) -> (ContractAddress, u64) {
            let (token_address, quantum) = self.asset_info.read(asset_id);
            assert(token_address.is_non_zero(), errors::ASSET_NOT_REGISTERED);
            (token_address, quantum)
        }
    }

    fn deposit_hash(
        depositor: ContractAddress,
        beneficiary: u32,
        asset_id: felt252,
        quantized_amount: u128,
        salt: felt252,
    ) -> HashType {
        PoseidonTrait::new()
            .update_with(value: depositor)
            .update_with(value: beneficiary)
            .update_with(value: asset_id)
            .update_with(value: quantized_amount)
            .update_with(value: salt)
            .finalize()
    }
}

