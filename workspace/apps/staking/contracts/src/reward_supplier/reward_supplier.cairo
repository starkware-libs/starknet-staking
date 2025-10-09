#[starknet::contract]
pub mod RewardSupplier {
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use core::cmp::{max, min};
    use core::num::traits::Zero;
    use core::traits::TryInto;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use staking::constants::{
        ALPHA, ALPHA_DENOMINATOR, SECONDS_IN_YEAR, STRK_IN_FRIS, STRK_TOKEN_ADDRESS,
    };
    use staking::errors::GenericError;
    use staking::minting_curve::interface::{IMintingCurveDispatcher, IMintingCurveDispatcherTrait};
    use staking::reward_supplier::errors::Error;
    use staking::reward_supplier::interface::{
        BlockTimeConfig, Events, IRewardSupplier, IRewardSupplierConfig, RewardSupplierInfoV1,
    };
    use staking::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use staking::staking::objects::EpochInfoTrait;
    use staking::types::{Amount, BlockNumber};
    use staking::utils::{CheckedIERC20DispatcherTrait, compute_threshold};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::syscalls::send_message_to_l1_syscall;
    use starknet::{
        ContractAddress, EthAddress, SyscallResultTrait, get_caller_address, get_contract_address,
    };
    use starkware_utils::components::replaceability::ReplaceabilityComponent;
    use starkware_utils::components::roles::RolesComponent;
    use starkware_utils::errors::OptionAuxTrait;
    use starkware_utils::interfaces::identity::Identity;
    use starkware_utils::math::utils::{ceil_of_division, mul_wide_and_div};
    use starkware_utils::time::time::Timestamp;
    pub const CONTRACT_IDENTITY: felt252 = 'Reward Supplier';
    pub const CONTRACT_VERSION: felt252 = '3.0.0';
    /// Scale factor for block time measurements.
    pub(crate) const BLOCK_TIME_SCALE: u64 = 100;
    /// Default avg block time.
    pub(crate) const DEFAULT_AVG_BLOCK_TIME: u64 = 3 * BLOCK_TIME_SCALE;
    /// Default block time configuration.
    pub(crate) const DEFAULT_BLOCK_TIME_CONFIG: BlockTimeConfig = BlockTimeConfig {
        min_block_time: 2 * BLOCK_TIME_SCALE,
        max_block_time: 5 * BLOCK_TIME_SCALE,
        weighted_avg_factor: 80,
    };

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
        minting_curve_dispatcher: IMintingCurveDispatcher,
        staking_contract: ContractAddress,
        token_dispatcher: IERC20Dispatcher,
        /// L1 reward supplier contract.
        l1_reward_supplier: felt252,
        /// Token bridge address.
        starkgate_address: ContractAddress,
        /// Average block time in units of 1 / BLOCK_TIME_SCALE seconds.
        // TODO: Initial in EIC.
        avg_block_time: u64,
        /// The latest block data used for average block time calculation.
        /// Updated at the start of each epoch.
        block_snapshot: (BlockNumber, Timestamp),
        /// Configuration for block time calculation.
        // TODO: Initial in EIC.
        block_time_config: BlockTimeConfig,
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
        self.avg_block_time.write(DEFAULT_AVG_BLOCK_TIME);
        self.block_time_config.write(DEFAULT_BLOCK_TIME_CONFIG);
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
            let btc_rewards = self.calculate_btc_rewards(:total_rewards);
            let strk_rewards = total_rewards - btc_rewards;

            (strk_rewards, btc_rewards)
        }

        // TODO: Emit event?
        fn update_current_epoch_block_rewards(ref self: ContractState) -> (Amount, Amount) {
            let staking_contract = self.staking_contract.read();
            assert!(
                get_caller_address() == staking_contract,
                "{}",
                GenericError::CALLER_IS_NOT_STAKING_CONTRACT,
            );
            self.set_avg_block_time();
            // Calculate block rewards for the current epoch.
            let minting_curve_dispatcher = self.minting_curve_dispatcher.read();
            let yearly_mint = minting_curve_dispatcher.yearly_mint();
            let avg_block_time = self.avg_block_time.read();
            let total_rewards = mul_wide_and_div(
                lhs: yearly_mint,
                rhs: avg_block_time.into(),
                div: BLOCK_TIME_SCALE.into() * SECONDS_IN_YEAR.into(),
            )
                .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
            let btc_rewards = self.calculate_btc_rewards(:total_rewards);
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

        fn get_block_time_config(self: @ContractState) -> BlockTimeConfig {
            self.block_time_config.read()
        }

        fn get_avg_block_duration(self: @ContractState) -> u64 {
            self.avg_block_time.read()
        }
    }

    #[abi(embed_v0)]
    impl RewardSupplierConfigImpl of IRewardSupplierConfig<ContractState> {
        fn set_block_time_config(ref self: ContractState, block_time_config: BlockTimeConfig) {
            // TODO: Is this the right role?
            self.roles.only_app_governor();
            // TODO: Emit event?
            // Assert that block_time_config is valid.
            // TODO: More validations?
            assert!(
                block_time_config.weighted_avg_factor > 0, "{}", Error::INVALID_WEIGHTED_AVG_FACTOR,
            );
            assert!(
                block_time_config.weighted_avg_factor <= 100,
                "{}",
                Error::INVALID_WEIGHTED_AVG_FACTOR,
            );
            assert!(block_time_config.min_block_time > 0, "{}", Error::INVALID_MIN_MAX_BLOCK_TIME);
            assert!(
                block_time_config.min_block_time <= block_time_config.max_block_time,
                "{}",
                Error::INVALID_MIN_MAX_BLOCK_TIME,
            );
            self.block_time_config.write(block_time_config);
        }

        fn set_avg_block_duration(ref self: ContractState, avg_block_duration: u64) {
            // TODO: Is this the right role?
            self.roles.only_app_governor();
            let block_time_config = self.block_time_config.read();
            assert!(
                avg_block_duration >= block_time_config.min_block_time
                    && avg_block_duration <= block_time_config.max_block_time,
                "{}",
                Error::INVALID_AVG_BLOCK_DURATION,
            );
            self.avg_block_time.write(avg_block_duration);
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
                .expect_with_err(GenericError::BALANCE_ISNT_AMOUNT_TYPE);

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

        fn calculate_btc_rewards(self: @ContractState, total_rewards: Amount) -> Amount {
            mul_wide_and_div(lhs: total_rewards, rhs: ALPHA, div: ALPHA_DENOMINATOR)
                .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
        }

        fn set_avg_block_time(ref self: ContractState) {
            let current_block_number = starknet::get_block_number();
            let current_timestamp = starknet::get_block_timestamp();
            let (snapshot_block_number, snapshot_timestamp) = self.block_snapshot.read();
            // Sanity asserts.
            assert!(
                current_block_number > snapshot_block_number, "{}", Error::INVALID_BLOCK_NUMBER,
            );
            assert!(
                current_timestamp > snapshot_timestamp.into(), "{}", Error::INVALID_BLOCK_TIMESTAMP,
            );
            self
                .block_snapshot
                .write((current_block_number, Timestamp { seconds: current_timestamp }));
            // If this is the first time we're setting the block snapshot, can't calculate avg block
            // time yet.
            if snapshot_block_number.is_zero() || snapshot_timestamp.is_zero() {
                return;
            }
            let time_delta = current_timestamp - snapshot_timestamp.into();
            let num_blocks = current_block_number - snapshot_block_number;
            let mut calculated_block_time = mul_wide_and_div(
                lhs: time_delta, rhs: BLOCK_TIME_SCALE, div: num_blocks,
            )
                .expect_with_err(err: Error::BLOCK_TIME_OVERFLOW);
            let block_time_config = self.block_time_config.read();
            // Adjust calculated_block_time with min and max block time.
            calculated_block_time = max(calculated_block_time, block_time_config.min_block_time);
            calculated_block_time = min(calculated_block_time, block_time_config.max_block_time);
            // Use weighted average between calculated_block_time and the current avg_block_time.
            let old_avg_block_time = self.avg_block_time.read();
            let weighted_avg_factor = block_time_config.weighted_avg_factor.into();
            let new_avg_block_time = (weighted_avg_factor * calculated_block_time
                + (100 - weighted_avg_factor) * old_avg_block_time)
                / 100;
            self.avg_block_time.write(new_avg_block_time);
        }
    }
}
