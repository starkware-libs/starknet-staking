#[starknet::contract]
pub mod RewardSupplier {
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use core::num::traits::Zero;
    use core::traits::TryInto;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use staking::constants::{ALPHA, STRK_IN_FRIS, STRK_TOKEN_ADDRESS};
    use staking::errors::{GenericError, InternalError};
    use staking::minting_curve::interface::{IMintingCurveDispatcher, IMintingCurveDispatcherTrait};
    use staking::reward_supplier::errors::Error;
    use staking::reward_supplier::interface::{Events, IRewardSupplier, RewardSupplierInfoV1};
    use staking::reward_supplier::utils::calculate_btc_rewards;
    use staking::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use staking::staking::objects::EpochInfoTrait;
    use staking::types::Amount;
    use staking::utils::compute_threshold;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::syscalls::send_message_to_l1_syscall;
    use starknet::{
        ContractAddress, EthAddress, SyscallResultTrait, get_caller_address, get_contract_address,
    };
    use starkware_utils::components::replaceability::ReplaceabilityComponent;
    use starkware_utils::components::roles::RolesComponent;
    use starkware_utils::erc20::erc20_utils::CheckedIERC20DispatcherTrait;
    use starkware_utils::errors::OptionAuxTrait;
    use starkware_utils::interfaces::identity::Identity;
    use starkware_utils::math::utils::ceil_of_division;
    pub const CONTRACT_IDENTITY: felt252 = 'Reward Supplier';
    pub const CONTRACT_VERSION: felt252 = '3.0.0';

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl ReplaceabilityImpl =
        ReplaceabilityComponent::ReplaceabilityImpl<ContractState>;

    #[abi(embed_v0)]
    impl RolesImpl = RolesComponent::RolesImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        replaceability: ReplaceabilityComponent::Storage,
        #[substorage(v0)]
        roles: RolesComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // ------ Deprecated fields ------
        // Deprecated last_timestamp field, used in V0.
        // last_timestamp: Timestamp,
        // -------------------------------
        /// The amount of unclaimed rewards owed to the staking contract.
        unclaimed_rewards: Amount,
        /// The amount of tokens requested from L1.
        l1_pending_requested_amount: Amount,
        /// The amount of tokens that is requested from L1 in a single message.
        base_mint_amount: Amount,
        /// Minting curve contract dispatcher. Used to get the yearly mint.
        minting_curve_dispatcher: IMintingCurveDispatcher,
        /// Staking contract address.
        staking_contract: ContractAddress,
        /// STRK token dispatcher.
        token_dispatcher: IERC20Dispatcher,
        /// L1 reward supplier contract.
        l1_reward_supplier: felt252,
        /// Token bridge address.
        starkgate_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        accesscontrolEvent: AccessControlComponent::Event,
        #[flat]
        src5Event: SRC5Component::Event,
        MintRequest: Events::MintRequest,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        base_mint_amount: Amount,
        minting_curve_contract: ContractAddress,
        staking_contract: ContractAddress,
        l1_reward_supplier: felt252,
        starkgate_address: ContractAddress,
        governance_admin: ContractAddress,
    ) {
        let token_address = STRK_TOKEN_ADDRESS;
        self.roles.initialize(:governance_admin);
        self.staking_contract.write(staking_contract);
        self.token_dispatcher.contract_address.write(token_address);
        // Initialize unclaimed_rewards with 1 STRK to make up for round ups of pool rewards
        // calculation in the staking contract.
        self.unclaimed_rewards.write(STRK_IN_FRIS);
        self.l1_pending_requested_amount.write(Zero::zero());
        self.base_mint_amount.write(base_mint_amount);
        self.minting_curve_dispatcher.contract_address.write(minting_curve_contract);
        self.l1_reward_supplier.write(l1_reward_supplier);
        self.starkgate_address.write(starkgate_address);
    }

    #[abi(embed_v0)]
    impl _Identity of Identity<ContractState> {
        fn identify(self: @ContractState) -> felt252 nopanic {
            CONTRACT_IDENTITY
        }

        fn version(self: @ContractState) -> felt252 nopanic {
            CONTRACT_VERSION
        }
    }

    #[abi(embed_v0)]
    impl RewardSupplierImpl of IRewardSupplier<ContractState> {
        fn calculate_current_epoch_rewards(self: @ContractState) -> (Amount, Amount) {
            let minting_curve_dispatcher = self.minting_curve_dispatcher.read();
            let staking_dispatcher = IStakingDispatcher {
                contract_address: self.staking_contract.read(),
            };

            let yearly_mint = minting_curve_dispatcher.yearly_mint();
            let epochs_in_year = staking_dispatcher.get_epoch_info().epochs_in_year();
            let total_rewards = yearly_mint / epochs_in_year.into();
            let btc_rewards = calculate_btc_rewards(:total_rewards);
            let strk_rewards = total_rewards - btc_rewards;

            (strk_rewards, btc_rewards)
        }

        fn update_unclaimed_rewards_from_staking_contract(
            ref self: ContractState, rewards: Amount,
        ) {
            assert!(
                get_caller_address() == self.staking_contract.read(),
                "{}",
                GenericError::CALLER_IS_NOT_STAKING_CONTRACT,
            );

            let unclaimed_rewards = self.unclaimed_rewards.read() + rewards;
            self.unclaimed_rewards.write(unclaimed_rewards);
            // Request funds from L1 if needed.
            self.request_funds(:unclaimed_rewards);
        }

        // This function is called by the staking contract, claiming an amount of owed rewards.
        fn claim_rewards(ref self: ContractState, amount: Amount) {
            // Asserts.
            let staking_contract = self.staking_contract.read();
            assert!(
                get_caller_address() == staking_contract,
                "{}",
                GenericError::CALLER_IS_NOT_STAKING_CONTRACT,
            );
            let unclaimed_rewards = self.unclaimed_rewards.read();
            assert!(amount <= unclaimed_rewards, "{}", GenericError::AMOUNT_TOO_HIGH);

            // Update unclaimed_rewards and transfer the requested rewards to the staking contract.
            self.unclaimed_rewards.write(unclaimed_rewards - amount);
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher.checked_transfer(recipient: staking_contract, amount: amount.into());
        }

        fn on_receive(
            ref self: ContractState,
            l2_token: ContractAddress,
            amount: u256,
            depositor: EthAddress,
            message: Span<felt252>,
        ) -> bool {
            // Note that the deposit can be done by anyone (not just the L1 reward supplier), so
            // depositor is not checked.

            // These messages accepted only from the token bridge.
            assert!(
                get_caller_address() == self.starkgate_address.read(),
                "{}",
                Error::ON_RECEIVE_NOT_FROM_STARKGATE,
            );
            // The bridge may serve multiple tokens, only the correct token may be received.
            assert!(
                l2_token == self.token_dispatcher.contract_address.read(),
                "{}",
                Error::UNEXPECTED_TOKEN,
            );
            let amount_u128: Amount = amount
                .try_into()
                .expect_with_err(GenericError::AMOUNT_TOO_HIGH);
            let mut l1_pending_requested_amount = self.l1_pending_requested_amount.read();
            if amount_u128 > l1_pending_requested_amount {
                self.l1_pending_requested_amount.write(Zero::zero());
            } else {
                l1_pending_requested_amount -= amount_u128;
                self.l1_pending_requested_amount.write(l1_pending_requested_amount);
            }
            true
        }

        fn contract_parameters_v1(self: @ContractState) -> RewardSupplierInfoV1 {
            RewardSupplierInfoV1 {
                unclaimed_rewards: self.unclaimed_rewards.read(),
                l1_pending_requested_amount: self.l1_pending_requested_amount.read(),
            }
        }

        fn get_alpha(self: @ContractState) -> u128 {
            ALPHA
        }
    }

    #[generate_trait]
    impl InternalRewardSupplierFunctions of InternalRewardSupplierFunctionsTrait {
        /// Requests funds from L1 to account for new rewards, if the contract's balance is too low.
        fn request_funds(ref self: ContractState, unclaimed_rewards: Amount) {
            // Read current balance.
            let token_dispatcher = self.token_dispatcher.read();
            let balance: Amount = token_dispatcher
                .balance_of(account: get_contract_address())
                .try_into()
                .expect_with_err(InternalError::BALANCE_ISNT_AMOUNT_TYPE);

            // Calculate credit, which is the contract's balance plus the amount already requested
            // from L1, and the debit, which is the unclaimed rewards.
            let mut l1_pending_requested_amount = self.l1_pending_requested_amount.read();
            let credit = balance + l1_pending_requested_amount;
            let debit = unclaimed_rewards;

            // If there isn't enough credit to cover the debit + threshold, request funds.
            let base_mint_amount = self.base_mint_amount.read();
            let threshold = compute_threshold(base_mint_amount);
            if credit < debit + threshold {
                let diff = debit + threshold - credit;
                let num_msgs = ceil_of_division(dividend: diff, divisor: base_mint_amount);
                let total_amount = num_msgs * base_mint_amount;
                for _ in 0..num_msgs {
                    self.send_mint_request_to_l1_reward_supplier();
                }
                self.emit(Events::MintRequest { total_amount, num_msgs });
                l1_pending_requested_amount += total_amount;
            }

            // Commit to storage the requested amount, which is now part of the credit.
            self.l1_pending_requested_amount.write(l1_pending_requested_amount);
        }

        fn send_mint_request_to_l1_reward_supplier(self: @ContractState) {
            let payload: Span<felt252> = array![self.base_mint_amount.read().into()].span();
            let to_address = self.l1_reward_supplier.read();
            send_message_to_l1_syscall(:to_address, :payload).unwrap_syscall();
        }
    }
}
