#[starknet::component]
pub(crate) mod Deposit {
    use contracts_commons::components::deposit::interface::{DepositStatus, IDeposit};
    use contracts_commons::components::deposit::{errors, events};
    use contracts_commons::errors::panic_with_felt;
    use contracts_commons::math::Abs;
    use contracts_commons::types::time::time::{Time, TimeDelta};
    use contracts_commons::utils::{AddToStorage, SubFromStorage};
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::num::traits::Zero;
    use core::poseidon::PoseidonTrait;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{Map, StorageMapReadAccess, StoragePathEntry};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};


    #[storage]
    pub struct Storage {
        pub registered_deposits: Map<felt252, DepositStatus>,
        pub pending_deposits: Map<felt252, i64>,
        pub asset_data: Map<felt252, (ContractAddress, u64)>,
        pub cancellation_time: TimeDelta,
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
        fn deposit(
            ref self: ComponentState<TContractState>,
            asset_id: felt252,
            quantized_amount: i64,
            beneficiary: u32,
            salt: felt252,
        ) {
            assert(quantized_amount > 0, errors::INVALID_NON_POSITIVE_AMOUNT);
            let deposit_hash = self
                .deposit_hash(
                    signer: get_caller_address(), :asset_id, :quantized_amount, :beneficiary, :salt,
                );
            assert(
                self.get_deposit_status(:deposit_hash) == DepositStatus::NON_EXIST,
                errors::DEPOSIT_ALREADY_REGISTERED,
            );
            self
                .registered_deposits
                .write(key: deposit_hash, value: DepositStatus::PENDING(Time::now()));
            self.pending_deposits.entry(asset_id).add_and_write(quantized_amount);
            let (token_address, quantum) = self.get_asset_data(:asset_id);

            let token_contract = IERC20Dispatcher { contract_address: token_address };
            token_contract
                .transfer_from(
                    sender: get_caller_address(),
                    recipient: get_contract_address(),
                    amount: quantized_amount.abs().into() * quantum.into(),
                );
            self
                .emit(
                    events::Deposit {
                        position_id: beneficiary,
                        depositing_address: get_caller_address(),
                        asset_id,
                        amount: quantized_amount,
                        deposit_request_hash: deposit_hash,
                    },
                );
        }

        fn get_deposit_status(
            self: @ComponentState<TContractState>, deposit_hash: felt252,
        ) -> DepositStatus {
            self.internal_get_deposit_status(:deposit_hash)
        }

        fn get_asset_data(
            self: @ComponentState<TContractState>, asset_id: felt252,
        ) -> (ContractAddress, u64) {
            let (token_address, quantum) = self.asset_data.read(asset_id);
            assert(token_address.is_non_zero(), errors::ASSET_NOT_REGISTERED);
            (token_address, quantum)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialize(ref self: ComponentState<TContractState>) {
            self.cancellation_time.write(Time::weeks(count: 1));
        }

        fn deposit_hash(
            ref self: ComponentState<TContractState>,
            signer: ContractAddress,
            asset_id: felt252,
            quantized_amount: i64,
            beneficiary: u32,
            salt: felt252,
        ) -> felt252 {
            PoseidonTrait::new()
                .update_with(value: signer)
                .update_with(value: asset_id)
                .update_with(value: quantized_amount)
                .update_with(value: beneficiary)
                .update_with(value: salt)
                .finalize()
        }

        fn register_token(
            ref self: ComponentState<TContractState>,
            asset_id: felt252,
            token_address: ContractAddress,
            quantum: u64,
        ) {
            let (token_address_read, _) = self.asset_data.read(asset_id);
            assert(token_address_read.is_zero(), errors::ASSET_ALREADY_REGISTERED);
            self.asset_data.write(key: asset_id, value: (token_address, quantum));
        }

        fn process_deposit(
            ref self: ComponentState<TContractState>,
            depositor: ContractAddress,
            asset_id: felt252,
            quantized_amount: i64,
            beneficiary: u32,
            salt: felt252,
        ) {
            assert(quantized_amount > 0, errors::INVALID_NON_POSITIVE_AMOUNT);
            let deposit_hash = self
                .deposit_hash(signer: depositor, :asset_id, :quantized_amount, :beneficiary, :salt);
            let deposit_status = self.internal_get_deposit_status(:deposit_hash);
            match deposit_status {
                DepositStatus::NON_EXIST => { panic_with_felt(errors::DEPOSIT_NOT_REGISTERED) },
                DepositStatus::PENDING(_) => {},
                DepositStatus::DONE => { panic_with_felt(errors::DEPOSIT_ALREADY_DONE) },
            };

            self.registered_deposits.write(deposit_hash, DepositStatus::DONE);
            self.pending_deposits.entry(asset_id).sub_and_write(quantized_amount);
            self
                .emit(
                    events::DepositProcessed {
                        position_id: beneficiary,
                        depositing_address: depositor,
                        asset_id,
                        amount: quantized_amount,
                        deposit_request_hash: deposit_hash,
                    },
                );
        }

        fn internal_get_deposit_status(
            self: @ComponentState<TContractState>, deposit_hash: felt252,
        ) -> DepositStatus {
            self.registered_deposits.read(deposit_hash)
        }
    }
}
