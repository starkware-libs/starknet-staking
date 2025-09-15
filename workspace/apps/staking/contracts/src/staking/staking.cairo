#[starknet::contract]
pub mod Staking {
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use core::cmp::min;
    use core::num::traits::zero::Zero;
    use core::option::OptionTrait;
    use core::panics::panic_with_byte_array;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
        IERC20MetadataDispatcherTrait,
    };
    use staking::constants::{STARTING_EPOCH, STRK_TOKEN_ADDRESS};
    use staking::errors::GenericError;
    use staking::pool::errors::Error as PoolError;
    use staking::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait};
    use staking::reward_supplier::interface::{
        IRewardSupplierDispatcher, IRewardSupplierDispatcherTrait,
    };
    use staking::staking::errors::Error;
    use staking::staking::interface::{
        CommissionCommitment, ConfigEvents, Events, IStaking, IStakingAttestation, IStakingConfig,
        IStakingConsensus, IStakingMigration, IStakingPause, IStakingPool, IStakingRewardsManager,
        IStakingTokenManager, PauseEvents, PoolInfo, StakerInfoV1, StakerPoolInfoV1,
        StakerPoolInfoV2, StakingContractInfoV1, TokenManagerEvents,
    };
    use staking::staking::objects::{
        AttestationInfo, AttestationInfoTrait, EpochInfo, EpochInfoTrait,
        InternalStakerInfoLatestTrait, InternalStakerPoolInfoV2, InternalStakerPoolInfoV2MutTrait,
        InternalStakerPoolInfoV2Trait, NormalizedAmount, NormalizedAmountTrait, UndelegateIntentKey,
        UndelegateIntentValue, UndelegateIntentValueTrait, UndelegateIntentValueZero,
        VInternalStakerInfo, VInternalStakerInfoTrait,
    };
    use staking::staking::staker_balance_trace::trace::{
        MutableStakerBalanceTraceTrait, StakerBalanceTrace, StakerBalanceTraceTrait,
        StakerBalanceTrait,
    };
    use staking::types::{
        Amount, BlockNumber, Commission, Epoch, InternalStakerInfoLatest, PublicKey, Version,
    };
    use staking::utils::{
        CheckedIERC20DispatcherTrait, compute_commission_amount_rounded_down,
        compute_new_delegated_stake, deploy_delegation_pool_contract,
    };
    use starknet::class_hash::ClassHash;
    use starknet::storage::{
        Map, Mutable, MutableVecTrait, StoragePath, StoragePathEntry, StoragePathMutableConversion,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starkware_utils::components::replaceability::ReplaceabilityComponent;
    use starkware_utils::components::replaceability::ReplaceabilityComponent::InternalReplaceabilityTrait;
    use starkware_utils::components::roles::RolesComponent;
    use starkware_utils::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
    use starkware_utils::constants::WEEK;
    use starkware_utils::errors::{Describable, OptionAuxTrait};
    use starkware_utils::interfaces::identity::Identity;
    use starkware_utils::math::utils::mul_wide_and_div;
    use starkware_utils::storage::iterable_map::{
        IterableMap, IterableMapIntoIterImpl, IterableMapReadAccessImpl, IterableMapWriteAccessImpl,
        MutableIterableMapTrait,
    };
    use starkware_utils::time::time::{Time, TimeDelta, Timestamp};
    use starkware_utils::trace::trace::{MutableTraceTrait, Trace, TraceTrait};
    pub const CONTRACT_IDENTITY: felt252 = 'Staking Core Contract';
    pub const CONTRACT_VERSION: felt252 = '3.0.0';

    pub const COMMISSION_DENOMINATOR: Commission = 10000;
    pub(crate) const MAX_MIGRATION_TRACE_ENTRIES: u64 = 3;
    pub(crate) const DEFAULT_EXIT_WAIT_WINDOW: TimeDelta = TimeDelta { seconds: WEEK };
    pub(crate) const MAX_EXIT_WAIT_WINDOW: TimeDelta = TimeDelta { seconds: 12 * WEEK };
    /// Prev contract version for V2 (BTC) staking contract.
    /// This is the key for `prev_class_hash` (class hash of V1) in staking contract.
    /// Note: The key for `prev_class_hash` for class hash of V0 is '0'.
    pub(crate) const V2_PREV_CONTRACT_VERSION: Version = '1';

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

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
        // Deprecated global index of the staking system.
        // Was used in V0, to calculate the accrued interest.
        // global_index: Index,
        // Deprecated timestamp of the last global index update, used in V0.
        // global_index_last_update_timestamp: Timestamp,
        // Deprecated field of a dispatcher of the token contract, used in V1.
        // token_dispatcher: IERC20Dispatcher,
        // Deprecated field of the total stake, used in V0.
        // total_stake: Amount,
        // Deprecated field of the total stake, used in V1.
        // total_stake_trace: Trace,
        // -------------------------------
        /// Minimum amount of initial stake.
        min_stake: Amount,
        /// Map staker address to their staker info.
        staker_info: Map<ContractAddress, VInternalStakerInfo>,
        /// Map operational address to staker address, as it must be a 1 to 1 mapping.
        operational_address_to_staker_address: Map<ContractAddress, ContractAddress>,
        /// Map potential operational address to eligible staker address.
        eligible_operational_addresses: Map<ContractAddress, ContractAddress>,
        /// The class hash of the delegation pool contract.
        pool_contract_class_hash: ClassHash,
        /// Undelegate intents from pool contracts.
        pool_exit_intents: Map<UndelegateIntentKey, UndelegateIntentValue>,
        /// A dispatcher of the reward supplier contract.
        reward_supplier_dispatcher: IRewardSupplierDispatcher,
        /// Initial governor address of the spinned-off delegation pool contract.
        pool_contract_admin: ContractAddress,
        /// Storage of the `pause` flag state.
        is_paused: bool,
        /// Required delay (in seconds) between unstake intent and unstake action.
        exit_wait_window: TimeDelta,
        /// Epoch info.
        epoch_info: EpochInfo,
        /// The contract that staker sends attestation transaction to.
        attestation_contract: ContractAddress,
        /// Map version to class hash of the contract.
        prev_class_hash: Map<Version, ClassHash>,
        /// Map token address to checkpoints tracking total stake changes over time, with each
        /// checkpoint mapping an epoch to the updated stake. Stakers that performed unstake_intent
        /// are not included.
        tokens_total_stake_trace: Map<ContractAddress, Trace>,
        /// Map staker address to their balance trace.
        /// Deprecated field of the staker balance trace, used in V1.
        /// Now used only for migration from V1 to V2.
        staker_balance_trace: Map<ContractAddress, StakerBalanceTrace>,
        /// Map staker address to their own balance trace.
        staker_own_balance_trace: Map<ContractAddress, Trace>,
        /// Map staker address to their delegated balance trace per pool contract (map pool contract
        /// to their balance trace).
        staker_delegated_balance_trace: Map<ContractAddress, Map<ContractAddress, Trace>>,
        /// Map staker address to their pool info.
        staker_pool_info: Map<ContractAddress, InternalStakerPoolInfoV2>,
        /// Map token address to (is_active_first_epoch, is_active).
        /// The `is_active_first_epoch` is the first epoch that the `token_address` is in
        /// `is_active` state.
        /// Namely, if `e >= is_active_first_epoch` then the token is in `is_active` state.
        /// If `current_epoch <= e < is_active_first_epoch`, the tokens is in `!is_active` state.
        /// The state of older epochs cannot be determined.
        btc_tokens: IterableMap<ContractAddress, (Epoch, bool)>,
        /// Vector of staker addresses.
        /// **Note**: Stakers are not removed from this vector when they unstake.
        stakers: Vec<ContractAddress>,
        /// Map token address to its decimals.
        token_decimals: Map<ContractAddress, u8>,
        /// Map staker address to (activation_epoch, old_public_key, new_public_key).
        /// Similarily to `btc_tokens`, the `activation_epoch` is the first epoch from
        /// which the `new_public_key` is valid. Up until `activation_epoch`, the
        /// `old_public_key` is valid.
        public_key: Map<ContractAddress, (Epoch, PublicKey, PublicKey)>,
        /// Map staker address to the epoch when the unstake intent takes effect.
        /// **Note**: Stakers that called `unstake_intent` before V3 will not have this record.
        // TODO: Consider adding to InternalStakerInfoV1.
        // TODO: Consider view function.
        staker_unstake_intent_epoch: Map<ContractAddress, Epoch>,
        /// Last block number for which rewards were distributed.
        last_reward_block: BlockNumber,
        /// First epoch of V3 rewards distribution.
        v3_rewards_first_epoch: Epoch,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        StakeOwnBalanceChanged: Events::StakeOwnBalanceChanged,
        StakeDelegatedBalanceChanged: Events::StakeDelegatedBalanceChanged,
        NewDelegationPool: Events::NewDelegationPool,
        StakerExitIntent: Events::StakerExitIntent,
        StakerRewardAddressChanged: Events::StakerRewardAddressChanged,
        OperationalAddressChanged: Events::OperationalAddressChanged,
        NewStaker: Events::NewStaker,
        CommissionChanged: Events::CommissionChanged,
        CommissionInitialized: Events::CommissionInitialized,
        StakerRewardClaimed: Events::StakerRewardClaimed,
        DeleteStaker: Events::DeleteStaker,
        RewardsSuppliedToDelegationPool: Events::RewardsSuppliedToDelegationPool,
        Paused: PauseEvents::Paused,
        Unpaused: PauseEvents::Unpaused,
        MinimumStakeChanged: ConfigEvents::MinimumStakeChanged,
        ExitWaitWindowChanged: ConfigEvents::ExitWaitWindowChanged,
        RewardSupplierChanged: ConfigEvents::RewardSupplierChanged,
        EpochInfoChanged: ConfigEvents::EpochInfoChanged,
        V3RewardsFirstEpochSet: ConfigEvents::V3RewardsFirstEpochSet,
        OperationalAddressDeclared: Events::OperationalAddressDeclared,
        RemoveFromDelegationPoolIntent: Events::RemoveFromDelegationPoolIntent,
        RemoveFromDelegationPoolAction: Events::RemoveFromDelegationPoolAction,
        ChangeDelegationPoolIntent: Events::ChangeDelegationPoolIntent,
        CommissionCommitmentSet: Events::CommissionCommitmentSet,
        StakerRewardsUpdated: Events::StakerRewardsUpdated,
        TokenAdded: TokenManagerEvents::TokenAdded,
        TokenEnabled: TokenManagerEvents::TokenEnabled,
        TokenDisabled: TokenManagerEvents::TokenDisabled,
        PublicKeySet: Events::PublicKeySet,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        min_stake: Amount,
        pool_contract_class_hash: ClassHash,
        reward_supplier: ContractAddress,
        pool_contract_admin: ContractAddress,
        governance_admin: ContractAddress,
        prev_class_hash: ClassHash,
        epoch_info: EpochInfo,
        attestation_contract: ContractAddress,
    ) {
        self.roles.initialize(:governance_admin);
        self.replaceability.initialize(upgrade_delay: Zero::zero());
        self.min_stake.write(min_stake);
        self.pool_contract_class_hash.write(pool_contract_class_hash);
        self.reward_supplier_dispatcher.contract_address.write(reward_supplier);
        self.pool_contract_admin.write(pool_contract_admin);
        self.exit_wait_window.write(DEFAULT_EXIT_WAIT_WINDOW);
        self.is_paused.write(false);
        self.prev_class_hash.write(V2_PREV_CONTRACT_VERSION, prev_class_hash);
        self.epoch_info.write(epoch_info);
        self.attestation_contract.write(attestation_contract);
        self
            .tokens_total_stake_trace
            .entry(STRK_TOKEN_ADDRESS)
            .insert(key: STARTING_EPOCH, value: Zero::zero());
        self.token_decimals.write(STRK_TOKEN_ADDRESS, 18);
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
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: Amount,
        ) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let staker_address = get_caller_address();
            assert!(
                self.staker_info.read(staker_address).is_none(), "{}", GenericError::STAKER_EXISTS,
            );
            assert!(
                self.operational_address_to_staker_address.read(operational_address).is_zero(),
                "{}",
                GenericError::OPERATIONAL_EXISTS,
            );
            self.assert_staker_address_not_reused(:staker_address);
            assert!(
                !self.does_token_exist(token_address: staker_address), "{}", Error::STAKER_IS_TOKEN,
            );
            assert!(amount >= self.min_stake.read(), "{}", Error::AMOUNT_LESS_THAN_MIN_STAKE);
            let normalized_amount = NormalizedAmountTrait::from_strk_native_amount(:amount);

            // Transfer funds from staker. Sufficient approvals is a pre-condition.
            let staking_contract = get_contract_address();
            let token_dispatcher = strk_token_dispatcher();
            token_dispatcher
                .checked_transfer_from(
                    sender: staker_address, recipient: staking_contract, amount: amount.into(),
                );

            self
                .initialize_staker_own_balance_trace(
                    :staker_address, own_balance: normalized_amount,
                );

            // Create the record for the staker.
            self
                .staker_info
                .write(
                    staker_address,
                    VInternalStakerInfoTrait::new_latest(:reward_address, :operational_address),
                );

            // Update the operational address mapping, which is a 1 to 1 mapping.
            self.operational_address_to_staker_address.write(operational_address, staker_address);

            // Update total stake.
            self.add_to_total_stake(token_address: STRK_TOKEN_ADDRESS, amount: normalized_amount);

            // Add staker address to the stakers vector.
            self.stakers.push(staker_address);

            // Emit events.
            self
                .emit(
                    Events::NewStaker {
                        staker_address, reward_address, operational_address, self_stake: amount,
                    },
                );
            self
                .emit(
                    Events::StakeOwnBalanceChanged {
                        staker_address, old_self_stake: Zero::zero(), new_self_stake: amount,
                    },
                );
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: Amount,
        ) -> Amount {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let caller_address = get_caller_address();
            let staker_info = self.internal_staker_info(:staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);
            assert!(
                caller_address == staker_address || caller_address == staker_info.reward_address,
                "{}",
                GenericError::CALLER_CANNOT_INCREASE_STAKE,
            );
            assert!(amount.is_non_zero(), "{}", GenericError::AMOUNT_IS_ZERO);
            let normalized_amount = NormalizedAmountTrait::from_strk_native_amount(:amount);

            // Transfer funds from caller (which is either the staker or their reward address).
            let staking_contract_address = get_contract_address();
            let token_dispatcher = strk_token_dispatcher();
            token_dispatcher
                .checked_transfer_from(
                    sender: caller_address,
                    recipient: staking_contract_address,
                    amount: amount.into(),
                );

            // Update staker's staked amount, and total stake.
            let (normalized_old_self_stake, normalized_new_self_stake) = self
                .increase_staker_own_amount(:staker_address, amount: normalized_amount);

            // Emit events.
            let new_self_stake = normalized_new_self_stake.to_strk_native_amount();
            self
                .emit(
                    Events::StakeOwnBalanceChanged {
                        staker_address,
                        old_self_stake: normalized_old_self_stake.to_strk_native_amount(),
                        new_self_stake: new_self_stake,
                    },
                );
            new_self_stake
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> Amount {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let mut staker_info = self.internal_staker_info(:staker_address);
            let caller_address = get_caller_address();
            let reward_address = staker_info.reward_address;
            assert!(
                caller_address == staker_address || caller_address == reward_address,
                "{}",
                Error::CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS,
            );

            // Transfer rewards to staker's reward address and write updated staker info to storage.
            // Note: `send_rewards_to_staker` alters `staker_info` thus commit to storage is
            // performed only after that.
            let amount = staker_info.unclaimed_rewards_own;
            let token_dispatcher = strk_token_dispatcher();
            self.send_rewards_to_staker(:staker_address, ref :staker_info, :token_dispatcher);
            self.write_staker_info(:staker_address, :staker_info);
            amount
        }

        fn unstake_intent(ref self: ContractState) -> Timestamp {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let staker_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);

            // Set the unstake time.
            let unstake_time = Time::now().add(delta: self.exit_wait_window.read());
            staker_info.unstake_time = Option::Some(unstake_time);
            self.write_staker_info(:staker_address, :staker_info);

            // Write the unstake intent epoch.
            // TODO: Change to 2 epoch with
            // https://github.com/starkware-industries/starknet-apps/pull/5034
            // (or in this PR if it's already merged)
            self.staker_unstake_intent_epoch.write(staker_address, self.get_next_epoch());

            // Write off the delegated stake from the total stake.
            for (pool_contract, token_address) in self
                .staker_pool_info
                .entry(staker_address)
                .pools {
                let amount = self.get_delegated_balance(:staker_address, :pool_contract);
                self.remove_from_total_stake(:token_address, :amount);
                let decimals = self.get_token_decimals(:token_address);
                self
                    .emit(
                        Events::StakeDelegatedBalanceChanged {
                            staker_address,
                            token_address,
                            old_delegated_stake: amount.to_native_amount(:decimals),
                            new_delegated_stake: Zero::zero(),
                        },
                    );
            }
            // Write off the self stake from the total stake.
            let old_self_stake = self.get_own_balance(:staker_address);
            self.remove_from_total_stake(token_address: STRK_TOKEN_ADDRESS, amount: old_self_stake);

            // Emit events.
            self.emit(Events::StakerExitIntent { staker_address, exit_timestamp: unstake_time });
            self
                .emit(
                    Events::StakeOwnBalanceChanged {
                        staker_address,
                        old_self_stake: old_self_stake.to_strk_native_amount(),
                        new_self_stake: Zero::zero(),
                    },
                );
            unstake_time
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> Amount {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let mut staker_info = self.internal_staker_info(:staker_address);
            let unstake_time = staker_info
                .unstake_time
                .expect_with_err(Error::MISSING_UNSTAKE_INTENT);
            assert!(Time::now() >= unstake_time, "{}", GenericError::INTENT_WINDOW_NOT_FINISHED);

            // Send rewards to staker's reward address.
            // It must be part of this function's flow because staker_info is about to be erased.
            let token_dispatcher = strk_token_dispatcher();
            self.send_rewards_to_staker(:staker_address, ref :staker_info, :token_dispatcher);
            // Update staker info to storage (it will be erased later).
            // This is done here to avoid re-entrancy.
            self.write_staker_info(:staker_address, :staker_info);

            let staker_amount = self.get_own_balance(:staker_address).to_strk_native_amount();
            let staker_pool_info = self.staker_pool_info.entry(staker_address);
            self.remove_staker(:staker_address, :staker_info, :staker_pool_info);

            // Return stake to staker.
            token_dispatcher
                .checked_transfer(recipient: staker_address, amount: staker_amount.into());
            // Return delegated stake to pools and zero their balances.
            self
                .transfer_to_pools_when_unstake(
                    :staker_address, staker_pool_info: staker_pool_info.as_non_mut(),
                );
            // Clear staker pools.
            staker_pool_info.pools.clear();
            staker_amount
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let staker_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            let old_address = staker_info.reward_address;

            // Update reward_address and commit to storage.
            staker_info.reward_address = reward_address;
            self.write_staker_info(:staker_address, :staker_info);

            // Emit event.
            self
                .emit(
                    Events::StakerRewardAddressChanged {
                        staker_address, new_address: reward_address, old_address,
                    },
                );
        }

        fn set_open_for_delegation(
            ref self: ContractState, token_address: ContractAddress,
        ) -> ContractAddress {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let staker_address = get_caller_address();
            let staker_info = self.internal_staker_info(:staker_address);
            let staker_pool_info = self.staker_pool_info.entry(staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);
            assert!(self.does_token_exist(:token_address), "{}", Error::TOKEN_NOT_EXISTS);
            assert!(
                !staker_pool_info.has_pool_for_token(:token_address),
                "{}",
                Error::STAKER_ALREADY_HAS_POOL,
            );
            let commission = staker_pool_info.commission();

            // Deploy delegation pool contract.
            let pool_contract = self
                .deploy_delegation_pool_from_staking_contract(
                    :staker_address,
                    staking_contract: get_contract_address(),
                    :token_address,
                    :commission,
                );
            // Update pool to storage.
            staker_pool_info.pools.write(pool_contract, token_address);
            // Initialize the delegated balance trace.
            self.initialize_staker_delegated_balance_trace(:staker_address, :pool_contract);
            pool_contract
        }

        /// *Note*: This function assumes the staker trace is initialized.
        /// *Note*: V1 pool contracts use this function to get the commission. Breaking this
        /// function will require upgrading the V1 pool contracts.
        fn staker_info_v1(self: @ContractState, staker_address: ContractAddress) -> StakerInfoV1 {
            let internal_staker_info = self.internal_staker_info(:staker_address);
            let mut staker_info: StakerInfoV1 = internal_staker_info.into();
            // Set staker amount and pool amount from staker balance trace.
            staker_info.amount_own = self.get_own_balance(:staker_address).to_strk_native_amount();
            let staker_pool_info = self.staker_pool_info.entry(staker_address);
            if let Option::Some(pool_contract) = staker_pool_info.get_strk_pool() {
                let pool_amount = self.get_delegated_balance(:staker_address, :pool_contract);
                // Commission must be set since staker has a pool.
                let commission = staker_pool_info.commission();
                staker_info
                    .pool_info =
                        Option::Some(
                            StakerPoolInfoV1 {
                                pool_contract,
                                amount: pool_amount.to_strk_native_amount(),
                                commission,
                            },
                        );
            }
            staker_info
        }

        fn get_staker_info_v1(
            self: @ContractState, staker_address: ContractAddress,
        ) -> Option<StakerInfoV1> {
            if self.staker_info.read(staker_address).is_none() {
                return Option::None;
            }
            Option::Some(self.staker_info_v1(:staker_address))
        }

        fn staker_pool_info(
            self: @ContractState, staker_address: ContractAddress,
        ) -> StakerPoolInfoV2 {
            // Assert that the staker exists.
            self.internal_staker_info(:staker_address);
            let staker_pool_info = self.staker_pool_info.entry(staker_address);
            let commission = staker_pool_info.commission.read();
            let mut pools: Array<PoolInfo> = array![];
            for (pool_contract, token_address) in staker_pool_info.pools {
                let decimals = self.get_token_decimals(:token_address);
                let amount = self
                    .get_delegated_balance(:staker_address, :pool_contract)
                    .to_native_amount(:decimals);
                pools.append(PoolInfo { pool_contract, token_address, amount });
            }
            StakerPoolInfoV2 { commission, pools: pools.span() }
        }

        fn get_current_epoch(self: @ContractState) -> Epoch {
            self.epoch_info.read().current_epoch()
        }

        fn get_epoch_info(self: @ContractState) -> EpochInfo {
            self.epoch_info.read()
        }


        fn contract_parameters_v1(self: @ContractState) -> StakingContractInfoV1 {
            StakingContractInfoV1 {
                min_stake: self.min_stake.read(),
                token_address: STRK_TOKEN_ADDRESS,
                attestation_contract: self.attestation_contract.read(),
                pool_contract_class_hash: self.pool_contract_class_hash.read(),
                reward_supplier: self.reward_supplier_dispatcher.contract_address.read(),
                exit_wait_window: self.exit_wait_window.read(),
            }
        }

        fn get_total_stake(self: @ContractState) -> Amount {
            self._get_total_stake(token_address: STRK_TOKEN_ADDRESS).to_strk_native_amount()
        }

        fn get_current_total_staking_power(
            self: @ContractState,
        ) -> (NormalizedAmount, NormalizedAmount) {
            let strk_total_stake_trace = self.tokens_total_stake_trace.entry(STRK_TOKEN_ADDRESS);
            let curr_epoch = self.get_current_epoch();
            let strk_curr_total_stake = self
                .balance_at_epoch(trace: strk_total_stake_trace, epoch_id: curr_epoch);
            let mut btc_curr_total_stake: NormalizedAmount = Zero::zero();
            for (token_address, active_status) in self.btc_tokens {
                if self.is_btc_active(:active_status, :curr_epoch) {
                    let btc_total_stake_trace = self.tokens_total_stake_trace.entry(token_address);
                    btc_curr_total_stake += self
                        .balance_at_epoch(trace: btc_total_stake_trace, epoch_id: curr_epoch);
                }
            }
            (strk_curr_total_stake, btc_curr_total_stake)
        }

        fn change_operational_address(
            ref self: ContractState, operational_address: ContractAddress,
        ) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            assert!(
                self.operational_address_to_staker_address.read(operational_address).is_zero(),
                "{}",
                GenericError::OPERATIONAL_EXISTS,
            );
            let staker_address = get_caller_address();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);
            assert!(
                self.eligible_operational_addresses.read(operational_address) == staker_address,
                "{}",
                Error::OPERATIONAL_NOT_ELIGIBLE,
            );

            // Set operational address and write to storage.
            let old_address = staker_info.operational_address;
            self.operational_address_to_staker_address.write(old_address, Zero::zero());
            staker_info.operational_address = operational_address;
            self.write_staker_info(:staker_address, :staker_info);
            self.operational_address_to_staker_address.write(operational_address, staker_address);

            // Emit event.
            self
                .emit(
                    Events::OperationalAddressChanged {
                        staker_address, new_address: operational_address, old_address,
                    },
                );
        }

        fn declare_operational_address(ref self: ContractState, staker_address: ContractAddress) {
            self.general_prerequisites();
            let operational_address = get_caller_address();
            assert!(
                self.operational_address_to_staker_address.read(operational_address).is_zero(),
                "{}",
                Error::OPERATIONAL_IN_USE,
            );
            if self.eligible_operational_addresses.read(operational_address) == staker_address {
                return;
            }
            self.eligible_operational_addresses.write(operational_address, staker_address);
            self.emit(Events::OperationalAddressDeclared { operational_address, staker_address });
        }

        fn set_commission(ref self: ContractState, commission: Commission) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            assert!(commission <= COMMISSION_DENOMINATOR, "{}", Error::COMMISSION_OUT_OF_RANGE);
            let staker_address = get_caller_address();
            let staker_info = self.internal_staker_info(:staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);

            let staker_pool_info = self.staker_pool_info.entry(staker_address);
            if let Option::Some(old_commission) = staker_pool_info.commission.read() {
                self
                    .update_commission(
                        :staker_address, :staker_pool_info, :old_commission, :commission,
                    );
            } else {
                staker_pool_info.commission.write(Option::Some(commission));
                self.emit(Events::CommissionInitialized { staker_address, commission });
            }
        }

        /// **Note**: Current commission increase safeguards still allow for sudden commission
        /// changes.
        /// **Note**: Updating epoch info can impact the commission commitment expiration date.
        fn set_commission_commitment(
            ref self: ContractState, max_commission: Commission, expiration_epoch: Epoch,
        ) {
            self.general_prerequisites();
            assert!(max_commission <= COMMISSION_DENOMINATOR, "{}", Error::COMMISSION_OUT_OF_RANGE);
            let staker_address = get_caller_address();
            let staker_info = self.internal_staker_info(:staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);
            let staker_pool_info = self.staker_pool_info.entry(staker_address);
            assert!(staker_pool_info.has_pool(), "{}", Error::MISSING_POOL_CONTRACT);
            let current_epoch = self.get_current_epoch();
            if let Option::Some(commission_commitment) = staker_pool_info
                .commission_commitment
                .read() {
                assert!(
                    !self.is_commission_commitment_active(:commission_commitment),
                    "{}",
                    Error::COMMISSION_COMMITMENT_EXISTS,
                );
            }
            // Staker must have a commission since it has a pool.
            let current_commission = staker_pool_info.commission();
            assert!(current_commission <= max_commission, "{}", Error::MAX_COMMISSION_TOO_LOW);
            assert!(expiration_epoch > current_epoch, "{}", Error::EXPIRATION_EPOCH_TOO_EARLY);
            assert!(
                expiration_epoch - current_epoch <= self.get_epoch_info().epochs_in_year(),
                "{}",
                Error::EXPIRATION_EPOCH_TOO_FAR,
            );
            let commission_commitment = CommissionCommitment { max_commission, expiration_epoch };
            staker_pool_info.commission_commitment.write(Option::Some(commission_commitment));
            self
                .emit(
                    Events::CommissionCommitmentSet {
                        staker_address, max_commission, expiration_epoch,
                    },
                );
        }

        fn get_staker_commission_commitment(
            self: @ContractState, staker_address: ContractAddress,
        ) -> CommissionCommitment {
            // Assert that the staker exists.
            self.internal_staker_info(:staker_address);
            self.staker_pool_info.entry(staker_address).commission_commitment()
        }

        fn is_paused(self: @ContractState) -> bool {
            self.is_paused.read()
        }

        fn get_active_tokens(self: @ContractState) -> Span<ContractAddress> {
            let mut active_tokens: Array<ContractAddress> = array![STRK_TOKEN_ADDRESS];
            let curr_epoch = self.get_current_epoch();
            for (token_address, active_status) in self.btc_tokens {
                if self.is_btc_active(:active_status, :curr_epoch) {
                    active_tokens.append(token_address);
                }
            }
            active_tokens.span()
        }

        fn get_tokens(self: @ContractState) -> Span<(ContractAddress, bool)> {
            let mut tokens: Array<(ContractAddress, bool)> = array![(STRK_TOKEN_ADDRESS, true)];
            let curr_epoch = self.get_current_epoch();
            for (token_address, active_status) in self.btc_tokens {
                let is_btc_active = self.is_btc_active(:active_status, :curr_epoch);
                tokens.append((token_address, is_btc_active));
            }
            tokens.span()
        }

        fn get_total_stake_for_token(
            self: @ContractState, token_address: ContractAddress,
        ) -> Amount {
            let curr_epoch = self.get_current_epoch();
            assert!(self.does_token_exist(:token_address), "{}", Error::INVALID_TOKEN_ADDRESS);
            assert!(
                self.is_active_token(:token_address, :curr_epoch), "{}", Error::TOKEN_NOT_ACTIVE,
            );
            let decimals = self.get_token_decimals(:token_address);
            self._get_total_stake(:token_address).to_native_amount(:decimals)
        }

        fn set_public_key(ref self: ContractState, public_key: PublicKey) {
            self.general_prerequisites();
            assert!(public_key.is_non_zero(), "{}", Error::INVALID_PUBLIC_KEY);
            let staker_address = get_caller_address();
            let staker_info = self.internal_staker_info(:staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);

            let (curr_activation_epoch, _, prev_public_key) = self.public_key.read(staker_address);
            let curr_epoch = self.get_current_epoch();
            // TODO: Confirm with product this set period is ok.
            assert!(curr_epoch >= curr_activation_epoch, "{}", Error::PUBLIC_KEY_SET_IN_PROGRESS);
            assert!(prev_public_key != public_key, "{}", Error::PUBLIC_KEY_MUST_DIFFER);

            // TODO: Use new method for calculating the change epoch.
            let new_activation_epoch = curr_epoch + 2;
            self
                .public_key
                .write(staker_address, (new_activation_epoch, prev_public_key, public_key));
            self.emit(Events::PublicKeySet { staker_address, public_key });
        }

        fn get_current_public_key(
            self: @ContractState, staker_address: ContractAddress,
        ) -> PublicKey {
            // Assert the staker exists.
            self.internal_staker_info(:staker_address);
            self
                .get_public_key_at_epoch(:staker_address, epoch_id: self.get_current_epoch())
                .expect_with_err(Error::PUBLIC_KEY_NOT_SET)
        }
    }

    #[abi(embed_v0)]
    impl StakingConsensusImpl of IStakingConsensus<ContractState> {
        fn get_current_epoch_data(self: @ContractState) -> (Epoch, BlockNumber, u32) {
            let epoch_info = self.epoch_info.read();
            (
                epoch_info.current_epoch(),
                epoch_info.current_epoch_starting_block(),
                epoch_info.epoch_len_in_blocks(),
            )
        }
    }

    #[abi(embed_v0)]
    impl StakingMigrationImpl of IStakingMigration<ContractState> {
        fn internal_staker_info(
            self: @ContractState, staker_address: ContractAddress,
        ) -> InternalStakerInfoLatest {
            let internal_staker_info = self._internal_staker_info(:staker_address);
            // Assert staker already migrated to V2.
            assert!(
                !self.staker_own_balance_trace.entry(staker_address).is_empty(),
                "{}",
                Error::STAKER_NOT_MIGRATED,
            );
            internal_staker_info
        }

        /// **Note**: This function should be called only once per staker during upgrade.
        fn staker_migration(ref self: ContractState, staker_address: ContractAddress) {
            // Assert the staker is not migrated yet.
            assert!(
                self.staker_own_balance_trace.entry(staker_address).is_empty(),
                "{}",
                Error::STAKER_INFO_ALREADY_UPDATED,
            );
            // Migrate staker pool info.
            let internal_staker_info = self._internal_staker_info(:staker_address);
            let staker_pool_info = self.staker_pool_info.entry(staker_address);
            let mut pool_contract = Option::None;
            if let Option::Some(pool_info) = internal_staker_info._deprecated_pool_info {
                pool_contract = Option::Some(pool_info._deprecated_pool_contract);
                let token_address = STRK_TOKEN_ADDRESS;
                let commission = pool_info._deprecated_commission;
                staker_pool_info.commission.write(Option::Some(commission));
                staker_pool_info.pools.write(pool_contract.unwrap(), token_address);
            }
            // Note: Staker might have a commission commitment only if he has a pool.
            staker_pool_info
                .commission_commitment
                .write(internal_staker_info._deprecated_commission_commitment);
            // Migrate staker balance trace.
            self.migrate_staker_balance_trace(:staker_address, :pool_contract);
            // Add staker address to the stakers vector.
            self.stakers.push(staker_address);
        }
    }

    #[abi(embed_v0)]
    impl StakingPoolImpl of IStakingPool<ContractState> {
        fn add_stake_from_pool(
            ref self: ContractState, staker_address: ContractAddress, amount: Amount,
        ) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let staker_info = self.internal_staker_info(:staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);
            let pool_contract = get_caller_address();
            let token_address = self
                .staker_pool_info
                .entry(staker_address)
                .get_pool_token(:pool_contract)
                .expect_with_err(Error::CALLER_IS_NOT_POOL_CONTRACT);
            let decimals = self.get_token_decimals(:token_address);
            let normalized_amount = NormalizedAmountTrait::from_native_amount(:amount, :decimals);

            // Update the staker's staked amount, and add to total_stake.
            let old_delegated_stake = self.get_delegated_balance(:staker_address, :pool_contract);
            let new_delegated_stake = old_delegated_stake + normalized_amount;
            self
                .insert_staker_delegated_balance(
                    :staker_address, :pool_contract, delegated_balance: new_delegated_stake,
                );
            self.add_to_total_stake(:token_address, amount: normalized_amount);

            // Transfer funds from the pool contract to the staking contract.
            // Sufficient approval is a pre-condition.
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            token_dispatcher
                .checked_transfer_from(
                    sender: pool_contract, recipient: get_contract_address(), amount: amount.into(),
                );

            // Emit event.
            self
                .emit(
                    Events::StakeDelegatedBalanceChanged {
                        staker_address,
                        token_address,
                        old_delegated_stake: old_delegated_stake.to_native_amount(:decimals),
                        new_delegated_stake: new_delegated_stake.to_native_amount(:decimals),
                    },
                );
        }

        fn remove_from_delegation_pool_intent(
            ref self: ContractState,
            staker_address: ContractAddress,
            identifier: felt252,
            amount: Amount,
        ) -> Timestamp {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let staker_info = self.internal_staker_info(:staker_address);
            let pool_contract = get_caller_address();
            let token_address = self
                .staker_pool_info
                .entry(staker_address)
                .get_pool_token(:pool_contract)
                .expect_with_err(Error::CALLER_IS_NOT_POOL_CONTRACT);
            let decimals = self.get_token_decimals(:token_address);
            let normalized_amount = NormalizedAmountTrait::from_native_amount(:amount, :decimals);

            // Update the delegated stake according to the new intent.
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let old_intent_amount = self.get_pool_exit_intent(:undelegate_intent_key).amount;
            let new_intent_amount = normalized_amount;
            // After this call, the staker balance will be updated.
            let (old_delegated_stake, new_delegated_stake) = self
                .update_delegated_stake(
                    :staker_address,
                    :token_address,
                    :pool_contract,
                    :staker_info,
                    :old_intent_amount,
                    :new_intent_amount,
                );
            self
                .update_undelegate_intent_value(
                    :token_address, :staker_info, :undelegate_intent_key, :new_intent_amount,
                );

            self
                .emit(
                    Events::RemoveFromDelegationPoolIntent {
                        staker_address,
                        pool_contract,
                        token_address,
                        identifier,
                        old_intent_amount: old_intent_amount.to_native_amount(:decimals),
                        new_intent_amount: amount,
                    },
                );
            // If the staker is in the process of unstaking (intent called),
            // an event indicating the staked amount (own and delegated) to be zero
            // had already been emitted, thus unneeded now.
            if staker_info.unstake_time.is_none() {
                self
                    .emit(
                        Events::StakeDelegatedBalanceChanged {
                            staker_address,
                            token_address,
                            old_delegated_stake: old_delegated_stake.to_native_amount(:decimals),
                            new_delegated_stake: new_delegated_stake.to_native_amount(:decimals),
                        },
                    );
            }
            self.get_pool_exit_intent(:undelegate_intent_key).unpool_time
        }

        fn remove_from_delegation_pool_action(ref self: ContractState, identifier: felt252) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            let pool_contract = get_caller_address();
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let undelegate_intent = self.get_pool_exit_intent(:undelegate_intent_key);
            if undelegate_intent.amount.is_zero() {
                return;
            }
            assert!(
                Time::now() >= undelegate_intent.unpool_time,
                "{}",
                GenericError::INTENT_WINDOW_NOT_FINISHED,
            );

            // Clear the intent.
            self.clear_undelegate_intent(:undelegate_intent_key);
            // Extract the token address of the pool contract.
            let token_address = self.get_undelegate_intent_token(:undelegate_intent);
            let decimals = self.get_token_decimals(:token_address);
            // Transfer the intent amount to the pool contract.
            let native_amount = undelegate_intent.amount.to_native_amount(:decimals);
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            token_dispatcher
                .checked_transfer(recipient: pool_contract, amount: native_amount.into());

            // Emit event.
            self
                .emit(
                    Events::RemoveFromDelegationPoolAction {
                        pool_contract, token_address, identifier, amount: native_amount,
                    },
                );
        }

        fn switch_staking_delegation_pool(
            ref self: ContractState,
            to_staker: ContractAddress,
            to_pool: ContractAddress,
            switched_amount: Amount,
            data: Span<felt252>,
            identifier: felt252,
        ) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            if switched_amount.is_zero() {
                return;
            }
            let from_pool = get_caller_address();
            let undelegate_intent_key = UndelegateIntentKey {
                pool_contract: from_pool, identifier,
            };
            let mut undelegate_intent_value = self.get_pool_exit_intent(:undelegate_intent_key);
            assert!(
                undelegate_intent_value.is_non_zero(), "{}", PoolError::MISSING_UNDELEGATE_INTENT,
            );
            // Extract the token address of the `from_pool` contract.
            let token_address = self
                .get_undelegate_intent_token(undelegate_intent: undelegate_intent_value);
            let old_intent_amount = undelegate_intent_value.amount;
            assert!(to_pool != from_pool, "{}", Error::SELF_SWITCH_NOT_ALLOWED);
            let decimals = self.get_token_decimals(:token_address);
            let normalized_switched_amount = NormalizedAmountTrait::from_native_amount(
                amount: switched_amount, :decimals,
            );
            assert!(
                normalized_switched_amount <= old_intent_amount,
                "{}",
                GenericError::AMOUNT_TOO_HIGH,
            );

            let to_staker_info = self.internal_staker_info(staker_address: to_staker);

            // More asserts.
            assert!(to_staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);
            let to_token_address = self
                .staker_pool_info
                .entry(to_staker)
                .get_pool_token(pool_contract: to_pool)
                .expect_with_err(Error::DELEGATION_POOL_MISMATCH);
            assert!(token_address == to_token_address, "{}", Error::TOKEN_MISMATCH);

            // Update `to_staker`'s delegated stake amount, and add to total stake.
            let old_delegated_stake = self
                .get_delegated_balance(staker_address: to_staker, pool_contract: to_pool);
            let new_delegated_stake = old_delegated_stake + normalized_switched_amount;
            self
                .insert_staker_delegated_balance(
                    staker_address: to_staker,
                    pool_contract: to_pool,
                    delegated_balance: new_delegated_stake,
                );
            self.add_to_total_stake(:token_address, amount: normalized_switched_amount);

            // Update the undelegate intent. If the amount is zero, clear the intent.
            undelegate_intent_value.amount -= normalized_switched_amount;
            if undelegate_intent_value.amount.is_zero() {
                self.clear_undelegate_intent(:undelegate_intent_key);
            } else {
                self.pool_exit_intents.write(undelegate_intent_key, undelegate_intent_value);
            }

            // Notify `to_pool` about the new delegation.
            let to_pool_dispatcher = IPoolDispatcher { contract_address: to_pool };
            to_pool_dispatcher
                .enter_delegation_pool_from_staking_contract(amount: switched_amount, :data);

            // Emit events.
            self
                .emit(
                    Events::StakeDelegatedBalanceChanged {
                        staker_address: to_staker,
                        token_address,
                        old_delegated_stake: old_delegated_stake.to_native_amount(:decimals),
                        new_delegated_stake: new_delegated_stake.to_native_amount(:decimals),
                    },
                );
            self
                .emit(
                    Events::ChangeDelegationPoolIntent {
                        pool_contract: from_pool,
                        token_address,
                        identifier,
                        old_intent_amount: old_intent_amount.to_native_amount(:decimals),
                        new_intent_amount: undelegate_intent_value
                            .amount
                            .to_native_amount(:decimals),
                    },
                );
        }
    }

    #[abi(embed_v0)]
    impl StakingPauseImpl of IStakingPause<ContractState> {
        fn pause(ref self: ContractState) {
            self.roles.only_security_agent();
            if self.is_paused() {
                return;
            }
            self.is_paused.write(true);
            self.emit(PauseEvents::Paused { account: get_caller_address() });
        }

        fn unpause(ref self: ContractState) {
            self.roles.only_security_admin();
            if !self.is_paused() {
                return;
            }
            self.is_paused.write(false);
            self.emit(PauseEvents::Unpaused { account: get_caller_address() });
        }
    }

    #[abi(embed_v0)]
    impl StakingConfigImpl of IStakingConfig<ContractState> {
        fn set_min_stake(ref self: ContractState, min_stake: Amount) {
            self.roles.only_token_admin();
            let old_min_stake = self.min_stake.read();
            self.min_stake.write(min_stake);
            self
                .emit(
                    ConfigEvents::MinimumStakeChanged { old_min_stake, new_min_stake: min_stake },
                );
        }

        fn set_exit_wait_window(ref self: ContractState, exit_wait_window: TimeDelta) {
            self.roles.only_token_admin();
            assert!(exit_wait_window <= MAX_EXIT_WAIT_WINDOW, "{}", Error::ILLEGAL_EXIT_DURATION);
            let old_exit_window = self.exit_wait_window.read();
            self.exit_wait_window.write(exit_wait_window);
            self
                .emit(
                    ConfigEvents::ExitWaitWindowChanged {
                        old_exit_window, new_exit_window: exit_wait_window,
                    },
                );
        }

        fn set_reward_supplier(ref self: ContractState, reward_supplier: ContractAddress) {
            self.roles.only_token_admin();
            let old_reward_supplier = self.reward_supplier_dispatcher.contract_address.read();
            self.reward_supplier_dispatcher.contract_address.write(reward_supplier);
            self
                .emit(
                    ConfigEvents::RewardSupplierChanged {
                        old_reward_supplier, new_reward_supplier: reward_supplier,
                    },
                );
        }

        fn set_epoch_info(ref self: ContractState, epoch_duration: u32, epoch_length: u32) {
            self.roles.only_app_governor();
            let mut epoch_info = self.epoch_info.read();
            epoch_info.update(:epoch_duration, :epoch_length);
            self.epoch_info.write(epoch_info);
            self.emit(ConfigEvents::EpochInfoChanged { epoch_duration, epoch_length });
        }

        fn set_v3_rewards_first_epoch(ref self: ContractState, epoch_id: Epoch) {
            self.roles.only_app_governor();
            assert!(epoch_id >= self.get_current_epoch() + 2, "{}", Error::INVALID_EPOCH);
            assert!(!self.is_v3(), "{}", Error::REWARDS_ALREADY_V3);
            self.v3_rewards_first_epoch.write(epoch_id);
            self.emit(ConfigEvents::V3RewardsFirstEpochSet { v3_rewards_first_epoch: epoch_id });
        }
    }

    #[abi(embed_v0)]
    impl StakingTokenManagerImpl of IStakingTokenManager<ContractState> {
        fn add_token(ref self: ContractState, token_address: ContractAddress) {
            self.roles.only_token_admin();
            assert!(token_address.is_non_zero(), "{}", GenericError::ZERO_ADDRESS);
            assert!(self.staker_info.read(token_address).is_none(), "{}", Error::TOKEN_IS_STAKER);
            assert!(token_address != STRK_TOKEN_ADDRESS, "{}", Error::INVALID_TOKEN_ADDRESS);
            assert!(
                self.btc_tokens.read(token_address).is_none(), "{}", Error::TOKEN_ALREADY_EXISTS,
            );
            let token_dispatcher = IERC20MetadataDispatcher { contract_address: token_address };
            let decimals = token_dispatcher.decimals();
            assert!(decimals == 18 || decimals == 8, "{}", Error::INVALID_TOKEN_ADDRESS);
            self.btc_tokens.write(token_address, (STARTING_EPOCH, false));
            self.token_decimals.write(token_address, decimals);
            // Initialize the token total stake trace.
            self
                .tokens_total_stake_trace
                .entry(token_address)
                .insert(key: STARTING_EPOCH, value: Zero::zero());
            self.emit(TokenManagerEvents::TokenAdded { token_address });
        }

        fn enable_token(ref self: ContractState, token_address: ContractAddress) {
            self.roles.only_token_admin();
            let is_active_opt: Option<(Epoch, bool)> = self.btc_tokens.read(token_address);
            assert!(is_active_opt.is_some(), "{}", Error::TOKEN_NOT_EXISTS);
            let (is_active_first_epoch, is_active) = is_active_opt.unwrap();
            let curr_epoch = self.get_current_epoch();
            assert!(curr_epoch >= is_active_first_epoch, "{}", Error::INVALID_EPOCH);
            assert!(!is_active, "{}", Error::TOKEN_ALREADY_ENABLED);
            let next_is_active_first_epoch = curr_epoch + 1;
            self.btc_tokens.write(token_address, (next_is_active_first_epoch, true));
            self.emit(TokenManagerEvents::TokenEnabled { token_address });
        }

        fn disable_token(ref self: ContractState, token_address: ContractAddress) {
            self.roles.only_security_agent();
            let is_active_opt: Option<(Epoch, bool)> = self.btc_tokens.read(token_address);
            assert!(is_active_opt.is_some(), "{}", Error::TOKEN_NOT_EXISTS);
            let (is_active_first_epoch, is_active) = is_active_opt.unwrap();
            let curr_epoch = self.get_current_epoch();
            assert!(curr_epoch >= is_active_first_epoch, "{}", Error::INVALID_EPOCH);
            assert!(is_active, "{}", Error::TOKEN_ALREADY_DISABLED);
            let next_is_active_first_epoch = curr_epoch + 1;
            self.btc_tokens.write(token_address, (next_is_active_first_epoch, false));
            self.emit(TokenManagerEvents::TokenDisabled { token_address });
        }
    }

    #[abi(embed_v0)]
    impl StakingAttestationImpl of IStakingAttestation<ContractState> {
        fn update_rewards_from_attestation_contract(
            ref self: ContractState, staker_address: ContractAddress,
        ) {
            // Prerequisites and asserts.
            self.general_prerequisites();
            // TODO: Add v3 flag checking.
            self.assert_caller_is_attestation_contract();
            let mut staker_info = self.internal_staker_info(:staker_address);
            assert!(staker_info.unstake_time.is_none(), "{}", Error::UNSTAKE_IN_PROGRESS);

            let reward_supplier_dispatcher = self.reward_supplier_dispatcher.read();
            // Get current epoch data.
            let (strk_epoch_rewards, btc_epoch_rewards) = reward_supplier_dispatcher
                .calculate_current_epoch_rewards();
            let (strk_total_stake, btc_total_stake) = self.get_current_total_staking_power();
            let staker_pool_info = self.staker_pool_info.entry(staker_address).as_non_mut();
            let curr_epoch = self.get_current_epoch();
            self
                ._update_rewards(
                    :staker_address,
                    strk_total_rewards: strk_epoch_rewards,
                    btc_total_rewards: btc_epoch_rewards,
                    :strk_total_stake,
                    :btc_total_stake,
                    :staker_info,
                    :staker_pool_info,
                    :reward_supplier_dispatcher,
                    :curr_epoch,
                );
        }

        fn get_attestation_info_by_operational_address(
            self: @ContractState, operational_address: ContractAddress,
        ) -> AttestationInfo {
            let staker_address = self.get_staker_address_by_operational(:operational_address);

            // Return the attestation info.
            let staker_pool_info = self.staker_pool_info.entry(staker_address);
            let epoch_info = self.get_epoch_info();
            let epoch_len = epoch_info.epoch_len_in_blocks();
            let epoch_id = epoch_info.current_epoch();
            let current_epoch_starting_block = epoch_info.current_epoch_starting_block();
            let stake = self
                .get_staker_total_strk_balance_curr_epoch(
                    :staker_address, :staker_pool_info, curr_epoch: epoch_id,
                )
                .to_strk_native_amount();
            AttestationInfoTrait::new(
                :staker_address, :stake, :epoch_len, :epoch_id, :current_epoch_starting_block,
            )
        }
    }

    #[abi(embed_v0)]
    impl StakingRewardsManagerImpl of IStakingRewardsManager<ContractState> {
        fn update_rewards(
            ref self: ContractState, staker_address: ContractAddress, disable_rewards: bool,
        ) {
            self.general_prerequisites();
            // TODO: Add v3 flag checking.
            let current_block_number = starknet::get_block_number();
            assert!(
                current_block_number > self.last_reward_block.read(),
                "{}",
                Error::REWARDS_ALREADY_UPDATED,
            );

            // Assert staker exists.
            let staker_info = self.internal_staker_info(:staker_address);
            // TODO: Assert staker is not in unstake intent.

            let staker_pool_info = self.staker_pool_info.entry(staker_address).as_non_mut();
            let curr_epoch = self.get_current_epoch();
            let staker_total_strk_balance = self
                .get_staker_total_strk_balance_curr_epoch(
                    :staker_address, :staker_pool_info, :curr_epoch,
                );
            // Assert staker is active.
            assert!(staker_total_strk_balance.is_non_zero(), "{}", Error::INVALID_STAKER);

            // Update last block rewards.
            self.last_reward_block.write(current_block_number);

            if disable_rewards {
                return;
            }

            // Get current block data and update rewards.
            let reward_supplier_dispatcher = self.reward_supplier_dispatcher.read();
            let (strk_block_rewards, btc_block_rewards) = self
                .calculate_block_rewards(:reward_supplier_dispatcher);
            let staker_total_btc_balance = self
                .get_staker_total_btc_balance_curr_epoch(
                    :staker_address, :staker_pool_info, :curr_epoch,
                );
            self
                ._update_rewards(
                    :staker_address,
                    strk_total_rewards: strk_block_rewards,
                    btc_total_rewards: btc_block_rewards,
                    strk_total_stake: staker_total_strk_balance,
                    btc_total_stake: staker_total_btc_balance,
                    :staker_info,
                    :staker_pool_info,
                    :reward_supplier_dispatcher,
                    :curr_epoch,
                );
        }
    }

    #[generate_trait]
    pub(crate) impl InternalStakingMigration of IStakingMigrationInternal {
        /// Returns the class hash of the previous contract version.
        ///
        /// **Note**: This function must be reimplemented in the next version of the contract.
        fn get_prev_class_hash(self: @ContractState) -> ClassHash {
            self.prev_class_hash.read(V2_PREV_CONTRACT_VERSION)
        }
    }

    /// **Note**: This function doesn't verify that the token actually exists.
    #[generate_trait]
    pub(crate) impl InternalStakingFunctions of InternalStakingFunctionsTrait {
        /// This function differs from `internal_staker_info` function in that it doesn't assert
        /// that the staker has already migrated to V2.
        ///
        /// Use `_internal_staker_info` only within `staker_migration`.
        /// For all other cases, call `internal_staker_info`.
        fn _internal_staker_info(
            self: @ContractState, staker_address: ContractAddress,
        ) -> InternalStakerInfoLatest {
            let versioned_internal_staker_info = self.staker_info.read(staker_address);
            match versioned_internal_staker_info {
                VInternalStakerInfo::None => panic_with_byte_array(
                    err: @GenericError::STAKER_NOT_EXISTS.describe(),
                ),
                VInternalStakerInfo::V0(_) => panic_with_byte_array(
                    err: @Error::INTERNAL_STAKER_INFO_OUTDATED_VERSION.describe(),
                ),
                VInternalStakerInfo::V1(internal_staker_info_v1) => internal_staker_info_v1,
            }
        }

        fn _get_total_stake(
            self: @ContractState, token_address: ContractAddress,
        ) -> NormalizedAmount {
            let total_stake_trace = self.tokens_total_stake_trace.entry(token_address);
            // Trace is initialized with a zero stake at the first valid epoch, so it is safe to
            // unwrap.
            let (_, total_stake) = total_stake_trace.last().unwrap();
            NormalizedAmountTrait::from_amount_18_decimals(total_stake)
        }

        /// Calculates the rewards for a block in the current epoch (for STRK and BTC).
        fn calculate_block_rewards(
            self: @ContractState, reward_supplier_dispatcher: IRewardSupplierDispatcher,
        ) -> (Amount, Amount) {
            let (strk_rewards, btc_rewards) = reward_supplier_dispatcher
                .calculate_current_epoch_rewards();
            let epoch_len_in_blocks = self.get_epoch_info().epoch_len_in_blocks();
            (strk_rewards / epoch_len_in_blocks.into(), btc_rewards / epoch_len_in_blocks.into())
        }

        /// Migrate the last checkpoints of the staker balance trace.
        fn migrate_staker_balance_trace(
            ref self: ContractState,
            staker_address: ContractAddress,
            pool_contract: Option<ContractAddress>,
        ) {
            let deprecated_trace = self.staker_balance_trace.entry(staker_address);
            let len = deprecated_trace.length();
            let entries_to_migrate = min(len, MAX_MIGRATION_TRACE_ENTRIES);
            assert(entries_to_migrate > 0, 'No entries to migrate');
            let own_balance_trace = self.staker_own_balance_trace.entry(staker_address);
            let staker_pool_traces = self.staker_delegated_balance_trace.entry(staker_address);
            let delegated_balance_trace = pool_contract
                .map(|contract_address| staker_pool_traces.entry(contract_address));
            for i in (len - entries_to_migrate)..len {
                let (epoch, staker_balance) = deprecated_trace.at(i);
                let own_balance = staker_balance.amount_own();
                own_balance_trace.insert(key: epoch, value: own_balance);
                if let Option::Some(delegated_balance_trace) = delegated_balance_trace {
                    let delegated_balance = staker_balance.pool_amount();
                    delegated_balance_trace.insert(key: epoch, value: delegated_balance);
                } else {
                    assert!(
                        staker_balance.pool_amount().is_zero(), "{}", Error::POOL_BALANCE_NOT_ZERO,
                    )
                }
            }
        }

        /// Returns the token address for the given `undelegate_intent`.
        fn get_undelegate_intent_token(
            self: @ContractState, undelegate_intent: UndelegateIntentValue,
        ) -> ContractAddress {
            // If undelegate_intent.token_address is zero, it means the intent is for the STRK
            // token (it was created before the BTC version).
            if undelegate_intent.token_address.is_zero() {
                STRK_TOKEN_ADDRESS
            } else {
                undelegate_intent.token_address
            }
        }

        fn update_commission(
            ref self: ContractState,
            staker_address: ContractAddress,
            staker_pool_info: StoragePath<Mutable<InternalStakerPoolInfoV2>>,
            old_commission: Commission,
            commission: Commission,
        ) {
            if let Option::Some(commission_commitment) = staker_pool_info
                .commission_commitment
                .read() {
                if self.is_commission_commitment_active(:commission_commitment) {
                    assert!(
                        commission <= commission_commitment.max_commission,
                        "{}",
                        GenericError::INVALID_COMMISSION_WITH_COMMITMENT,
                    );
                    assert!(
                        commission != old_commission, "{}", GenericError::INVALID_SAME_COMMISSION,
                    );
                } else {
                    assert!(
                        commission < old_commission,
                        "{}",
                        GenericError::COMMISSION_COMMITMENT_EXPIRED,
                    );
                }
            } else {
                assert!(commission < old_commission, "{}", GenericError::INVALID_COMMISSION);
            }

            // Update commission in storage.
            staker_pool_info.commission.write(Option::Some(commission));

            // Emit event.
            self
                .emit(
                    Events::CommissionChanged {
                        staker_address, old_commission, new_commission: commission,
                    },
                );
        }

        fn claim_from_reward_supplier(
            ref self: ContractState,
            reward_supplier_dispatcher: IRewardSupplierDispatcher,
            amount: Amount,
            token_dispatcher: IERC20Dispatcher,
        ) {
            let staking_contract = get_contract_address();
            let balance_before = token_dispatcher.balance_of(account: staking_contract);
            reward_supplier_dispatcher.claim_rewards(:amount);
            let balance_after = token_dispatcher.balance_of(account: staking_contract);
            assert!(
                balance_after - balance_before == amount.into(), "{}", Error::UNEXPECTED_BALANCE,
            );
        }

        /// Sends the rewards to `staker_address`'s reward address.
        /// Important note:
        /// After calling this function, one must write the updated staker_info to the storage.
        fn send_rewards_to_staker(
            ref self: ContractState,
            staker_address: ContractAddress,
            ref staker_info: InternalStakerInfoLatest,
            token_dispatcher: IERC20Dispatcher,
        ) {
            let reward_address = staker_info.reward_address;
            let amount = staker_info.unclaimed_rewards_own;
            let reward_supplier_dispatcher = self.reward_supplier_dispatcher.read();

            self
                .claim_from_reward_supplier(
                    :reward_supplier_dispatcher, :amount, :token_dispatcher,
                );
            token_dispatcher.checked_transfer(recipient: reward_address, amount: amount.into());
            staker_info.unclaimed_rewards_own = Zero::zero();

            self.emit(Events::StakerRewardClaimed { staker_address, reward_address, amount });
        }

        /// Sends the rewards to `pool_address`.
        ///
        /// This function assumes the rewards are already in the staking contract. It doesnt claim
        /// rewards from rewards supplier contract.
        fn send_rewards_to_delegation_pool(
            ref self: ContractState,
            staker_address: ContractAddress,
            pool_address: ContractAddress,
            amount: Amount,
            token_dispatcher: IERC20Dispatcher,
        ) {
            token_dispatcher.checked_transfer(recipient: pool_address, amount: amount.into());
            self
                .emit(
                    Events::RewardsSuppliedToDelegationPool {
                        staker_address, pool_address, amount,
                    },
                );
        }

        fn clear_undelegate_intent(
            ref self: ContractState, undelegate_intent_key: UndelegateIntentKey,
        ) {
            self.pool_exit_intents.write(undelegate_intent_key, Zero::zero());
        }

        fn assert_is_unpaused(self: @ContractState) {
            assert!(!self.is_paused(), "{}", Error::CONTRACT_IS_PAUSED);
        }

        fn transfer_to_pools_when_unstake(
            ref self: ContractState,
            staker_address: ContractAddress,
            staker_pool_info: StoragePath<InternalStakerPoolInfoV2>,
        ) {
            for (pool_contract, token_address) in staker_pool_info.pools {
                let pool_balance = self.get_delegated_balance(:staker_address, :pool_contract);
                let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
                let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
                pool_dispatcher.set_staker_removed();
                self
                    .insert_staker_delegated_balance(
                        :staker_address, :pool_contract, delegated_balance: Zero::zero(),
                    );
                let decimals = self.get_token_decimals(:token_address);
                token_dispatcher
                    .checked_transfer(
                        recipient: pool_contract,
                        amount: pool_balance.to_native_amount(:decimals).into(),
                    );
            }
        }

        /// **Note**: `staker_pool_info.pools` is not cleaned up here, cleanup happens later, after
        /// `transfer_to_pools_when_unstake`.
        fn remove_staker(
            ref self: ContractState,
            staker_address: ContractAddress,
            staker_info: InternalStakerInfoLatest,
            staker_pool_info: StoragePath<Mutable<InternalStakerPoolInfoV2>>,
        ) {
            self.insert_staker_own_balance(:staker_address, own_balance: Zero::zero());
            self.staker_info.write(staker_address, VInternalStakerInfo::None);
            let operational_address = staker_info.operational_address;
            self.operational_address_to_staker_address.write(operational_address, Zero::zero());
            staker_pool_info.commission.write(Option::None);
            staker_pool_info.commission_commitment.write(Option::None);
            let pool_contracts = staker_pool_info.get_pools();
            self
                .emit(
                    Events::DeleteStaker {
                        staker_address,
                        reward_address: staker_info.reward_address,
                        operational_address,
                        pool_contracts,
                    },
                );
        }

        fn deploy_delegation_pool_from_staking_contract(
            ref self: ContractState,
            staker_address: ContractAddress,
            staking_contract: ContractAddress,
            token_address: ContractAddress,
            commission: Commission,
        ) -> ContractAddress {
            let class_hash = self.pool_contract_class_hash.read();
            let contract_address_salt: felt252 = Time::now().seconds.into();
            let pool_contract = deploy_delegation_pool_contract(
                :class_hash,
                :contract_address_salt,
                :staker_address,
                :staking_contract,
                :token_address,
                governance_admin: staking_contract,
            );
            let pool_contract_roles_dispatcher = IRolesDispatcher {
                contract_address: pool_contract,
            };
            pool_contract_roles_dispatcher.register_upgrade_governor(account: staking_contract);
            let governance_admin = self.pool_contract_admin.read();
            pool_contract_roles_dispatcher.register_governance_admin(account: governance_admin);
            self
                .emit(
                    Events::NewDelegationPool {
                        staker_address, pool_contract, token_address, commission,
                    },
                );
            pool_contract
        }

        /// Adjusts the total stake based on changes in the delegated amount.
        fn update_total_stake_according_to_delegated_stake_changes(
            ref self: ContractState,
            token_address: ContractAddress,
            old_delegated_stake: NormalizedAmount,
            new_delegated_stake: NormalizedAmount,
        ) {
            if new_delegated_stake < old_delegated_stake {
                self
                    .remove_from_total_stake(
                        :token_address, amount: old_delegated_stake - new_delegated_stake,
                    );
            } else {
                self
                    .add_to_total_stake(
                        :token_address, amount: new_delegated_stake - old_delegated_stake,
                    );
            }
        }

        fn add_to_total_stake(
            ref self: ContractState, token_address: ContractAddress, amount: NormalizedAmount,
        ) {
            self
                .update_total_stake(
                    :token_address, new_total_stake: self._get_total_stake(:token_address) + amount,
                );
        }

        fn remove_from_total_stake(
            ref self: ContractState, token_address: ContractAddress, amount: NormalizedAmount,
        ) {
            self
                .update_total_stake(
                    :token_address, new_total_stake: self._get_total_stake(:token_address) - amount,
                );
        }

        fn update_total_stake(
            ref self: ContractState,
            token_address: ContractAddress,
            new_total_stake: NormalizedAmount,
        ) {
            self
                .tokens_total_stake_trace
                .entry(token_address)
                .insert(key: self.get_next_epoch(), value: new_total_stake.to_amount_18_decimals());
        }

        /// Wrap initial operations required in any public staking function.
        fn general_prerequisites(ref self: ContractState) {
            self.assert_is_unpaused();
            self.assert_caller_is_not_zero();
        }

        fn assert_caller_is_not_zero(self: @ContractState) {
            assert!(get_caller_address().is_non_zero(), "{}", Error::CALLER_IS_ZERO_ADDRESS);
        }

        /// Updates the delegated stake amount in the given `staker_balance` according to changes
        /// in the intent amount. Also updates the total stake accordingly.
        /// Returns the tuple of (old delegated stake amount, new delegated stake amount).
        fn update_delegated_stake(
            ref self: ContractState,
            staker_address: ContractAddress,
            token_address: ContractAddress,
            pool_contract: ContractAddress,
            staker_info: InternalStakerInfoLatest,
            old_intent_amount: NormalizedAmount,
            new_intent_amount: NormalizedAmount,
        ) -> (NormalizedAmount, NormalizedAmount) {
            let old_delegated_stake = self.get_delegated_balance(:staker_address, :pool_contract);
            let new_delegated_stake = compute_new_delegated_stake(
                :old_delegated_stake, :old_intent_amount, :new_intent_amount,
            );

            // Do not update the total stake when the staker is in the process of unstaking,
            // since its delegated stake is already excluded from the total stake.
            if staker_info.unstake_time.is_none() {
                self
                    .update_total_stake_according_to_delegated_stake_changes(
                        :token_address, :old_delegated_stake, :new_delegated_stake,
                    )
            }
            self
                .insert_staker_delegated_balance(
                    :staker_address, :pool_contract, delegated_balance: new_delegated_stake,
                );
            (old_delegated_stake, new_delegated_stake)
        }

        /// Updates undelegate intent value with the given `new_intent_amount` and an updated unpool
        /// time.
        fn update_undelegate_intent_value(
            ref self: ContractState,
            token_address: ContractAddress,
            staker_info: InternalStakerInfoLatest,
            undelegate_intent_key: UndelegateIntentKey,
            new_intent_amount: NormalizedAmount,
        ) {
            let undelegate_intent_value = if new_intent_amount.is_zero() {
                Zero::zero()
            } else {
                let unpool_time = staker_info
                    .compute_unpool_time(exit_wait_window: self.exit_wait_window.read());
                assert!(token_address.is_non_zero(), "{}", Error::TOKEN_IS_ZERO_ADDRESS);
                UndelegateIntentValue { amount: new_intent_amount, unpool_time, token_address }
            };
            self.pool_exit_intents.write(undelegate_intent_key, undelegate_intent_value);
        }

        fn get_pool_exit_intent(
            self: @ContractState, undelegate_intent_key: UndelegateIntentKey,
        ) -> UndelegateIntentValue {
            let undelegate_intent_value = self.pool_exit_intents.read(undelegate_intent_key);
            // The following assertion serves as a sanity check.
            undelegate_intent_value.assert_valid();
            undelegate_intent_value
        }

        /// Gets an array of tuples with (pool_contract, token_address, pool_balance, pool_rewards)
        /// and updates the pool rewards.
        ///
        /// Returns an array of tuples (pool_contract, pool_rewards) for the
        /// StakerRewardsUpdated event.
        fn update_pool_rewards(
            ref self: ContractState,
            staker_address: ContractAddress,
            pools_rewards_data: Array<(ContractAddress, ContractAddress, NormalizedAmount, Amount)>,
        ) -> Array<(ContractAddress, Amount)> {
            let mut pool_rewards_list = array![];
            let strk_token_dispatcher = strk_token_dispatcher();
            for (pool_contract, token_address, pool_balance, pool_rewards) in pools_rewards_data {
                let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
                // Rewards are always in STRK.
                self
                    .send_rewards_to_delegation_pool(
                        :staker_address,
                        pool_address: pool_contract,
                        amount: pool_rewards,
                        token_dispatcher: strk_token_dispatcher,
                    );
                let decimals = self.get_token_decimals(:token_address);
                pool_dispatcher
                    .update_rewards_from_staking_contract(
                        rewards: pool_rewards,
                        pool_balance: pool_balance.to_native_amount(:decimals),
                    );
                pool_rewards_list.append((pool_contract, pool_rewards));
            }
            pool_rewards_list
        }

        /// Calculate and return the rewards for the own balance of the staker.
        ///
        /// **In V2:**
        /// - `strk_total_rewards` = STRK epoch rewards.
        /// - `strk_total_stake` = current total STRK staking power.
        ///
        /// **In V3:**
        /// - `strk_total_rewards` = STRK block rewards.
        /// - `strk_total_stake` = current total STRK staked for the given staker (own + delegated).
        ///
        /// **Note**: `curr_epoch` must be `get_current_epoch()`, it's passed as a param to save
        /// storage reads.
        fn calculate_staker_own_rewards(
            self: @ContractState,
            staker_address: ContractAddress,
            strk_total_rewards: Amount,
            strk_total_stake: NormalizedAmount,
            curr_epoch: Epoch,
        ) -> Amount {
            let own_balance_curr_epoch = self
                .get_staker_own_balance_at_epoch(:staker_address, epoch_id: curr_epoch);
            assert!(own_balance_curr_epoch.is_non_zero(), "{}", Error::ATTEST_WITH_ZERO_BALANCE);

            mul_wide_and_div(
                lhs: strk_total_rewards,
                rhs: own_balance_curr_epoch.to_strk_native_amount(),
                div: strk_total_stake.to_strk_native_amount(),
            )
                .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
        }

        /// This function calculates the rewards for the staker's pools.
        /// The rewards will be updated and sent to pools later in `update_pools_rewards`.
        ///
        /// Returns: total commission rewards, total pools rewards, and a list of tuples with
        /// (pool_contract, token_address, pool_balance, pool_rewards) for each pool that gets
        /// rewards.
        ///
        /// Precondition: Staker has at least one pool.
        ///
        /// **In V2:**
        /// - `strk_total_rewards` = STRK epoch rewards.
        /// - `strk_total_stake` = current total STRK staking power.
        /// - `btc_total_rewards` = BTC epoch rewards.
        /// - `btc_total_stake` = current total BTC staking power.
        ///
        /// **In V3:**
        /// - `strk_total_rewards` = STRK block rewards.
        /// - `strk_total_stake` = current total STRK staked for the given staker (own + delegated).
        /// - `btc_total_rewards` = BTC block rewards.
        /// - `btc_total_stake` = current total BTC staked for the given staker (delegated).
        ///
        /// **Note**: `curr_epoch` must be `get_current_epoch()`, it's passed as a param to save
        /// storage reads.
        fn calculate_staker_pools_rewards(
            self: @ContractState,
            staker_address: ContractAddress,
            staker_pool_info: StoragePath<InternalStakerPoolInfoV2>,
            strk_total_rewards: Amount,
            strk_total_stake: NormalizedAmount,
            btc_total_rewards: Amount,
            btc_total_stake: NormalizedAmount,
            curr_epoch: Epoch,
        ) -> (Amount, Amount, Array<(ContractAddress, ContractAddress, NormalizedAmount, Amount)>) {
            // Array for rewards data needed to update pools.
            // Contains tuples of (pool_contract, token_address, pool_balance, pool_rewards).
            let mut pool_rewards_array = array![];
            let mut total_commission_rewards: Amount = Zero::zero();
            let mut total_pools_rewards: Amount = Zero::zero();
            let commission = staker_pool_info.commission();
            for (pool_contract, token_address) in staker_pool_info.pools {
                if !self.is_active_token(:token_address, :curr_epoch) {
                    continue;
                }
                let pool_balance_curr_epoch = self
                    .get_staker_delegated_balance_at_epoch(
                        :staker_address, :pool_contract, epoch_id: curr_epoch,
                    );
                let (total_rewards, total_stake) = if token_address == STRK_TOKEN_ADDRESS {
                    (strk_total_rewards, strk_total_stake)
                } else {
                    (btc_total_rewards, btc_total_stake)
                };
                // Calculate rewards for this pool.
                let pool_rewards_including_commission = if total_stake.is_non_zero() {
                    mul_wide_and_div(
                        lhs: total_rewards,
                        rhs: pool_balance_curr_epoch.to_amount_18_decimals(),
                        div: total_stake.to_amount_18_decimals(),
                    )
                        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
                } else {
                    Zero::zero()
                };
                let (commission_rewards, pool_rewards) = self
                    .split_rewards_with_commission(
                        rewards_including_commission: pool_rewards_including_commission,
                        :commission,
                    );
                total_commission_rewards += commission_rewards;
                total_pools_rewards += pool_rewards;
                if pool_rewards.is_non_zero() {
                    pool_rewards_array
                        .append(
                            (pool_contract, token_address, pool_balance_curr_epoch, pool_rewards),
                        );
                }
            }
            (total_commission_rewards, total_pools_rewards, pool_rewards_array)
        }

        /// Split rewards into pool's rewards and commission rewards.
        /// Return a tuple of (commission_rewards, pool_rewards).
        fn split_rewards_with_commission(
            self: @ContractState, rewards_including_commission: Amount, commission: Commission,
        ) -> (Amount, Amount) {
            let commission_rewards = compute_commission_amount_rounded_down(
                :rewards_including_commission, :commission,
            );
            let pool_rewards = rewards_including_commission - commission_rewards;
            (commission_rewards, pool_rewards)
        }

        fn get_next_epoch(self: @ContractState) -> Epoch {
            self.get_current_epoch() + 1
        }

        fn insert_staker_own_balance(
            ref self: ContractState, staker_address: ContractAddress, own_balance: NormalizedAmount,
        ) {
            self
                .staker_own_balance_trace
                .entry(staker_address)
                .insert(key: self.get_next_epoch(), value: own_balance.to_strk_native_amount());
        }

        fn initialize_staker_own_balance_trace(
            ref self: ContractState, staker_address: ContractAddress, own_balance: NormalizedAmount,
        ) {
            assert!(
                self.staker_own_balance_trace.entry(key: staker_address).is_empty(),
                "{}",
                Error::STAKER_ADDRESS_ALREADY_USED,
            );
            // Initialize trace with baseline entry to ensure robust balance queries.
            self
                .staker_own_balance_trace
                .entry(staker_address)
                .insert(key: STARTING_EPOCH, value: Zero::zero());
            self.insert_staker_own_balance(:staker_address, :own_balance);
        }

        fn insert_staker_delegated_balance(
            ref self: ContractState,
            staker_address: ContractAddress,
            pool_contract: ContractAddress,
            delegated_balance: NormalizedAmount,
        ) {
            self
                .staker_delegated_balance_trace
                .entry(staker_address)
                .entry(pool_contract)
                .insert(
                    key: self.get_next_epoch(), value: delegated_balance.to_amount_18_decimals(),
                );
        }

        /// Initializes the delegated balance trace for the given `pool_contract`.
        ///
        /// The trace is initialized with the current epoch since the staker might attest
        /// in the same epoch after the pool created.
        fn initialize_staker_delegated_balance_trace(
            ref self: ContractState,
            staker_address: ContractAddress,
            pool_contract: ContractAddress,
        ) {
            let trace = self
                .staker_delegated_balance_trace
                .entry(key: staker_address)
                .entry(key: pool_contract);
            assert!(trace.is_empty(), "{}", Error::STAKER_ALREADY_HAS_POOL);
            trace.insert(key: STARTING_EPOCH, value: Zero::zero());
        }

        /// Return the last own balance recorded in the `staker_own_balance_trace`.
        fn get_own_balance(
            self: @ContractState, staker_address: ContractAddress,
        ) -> NormalizedAmount {
            let trace = self.staker_own_balance_trace.entry(key: staker_address);
            // Unwrap is safe since the trace must already be initialized.
            let (_, own_balance) = trace.last().unwrap();
            NormalizedAmountTrait::from_strk_native_amount(amount: own_balance)
        }

        /// Return the last delegated balance recorded in the `staker_delegated_balance_trace` of
        /// the given `pool_contract`.
        fn get_delegated_balance(
            self: @ContractState, staker_address: ContractAddress, pool_contract: ContractAddress,
        ) -> NormalizedAmount {
            let trace = self
                .staker_delegated_balance_trace
                .entry(key: staker_address)
                .entry(key: pool_contract);
            // Unwrap is safe since the trace must already be initialized.
            let (_, delegated_balance) = trace.last().unwrap();
            NormalizedAmountTrait::from_amount_18_decimals(amount: delegated_balance)
        }

        /// Return the total STRK balance of the staker in the current epoch.
        ///
        /// **Note**: `curr_epoch` must be `get_current_epoch()`, it's passed as a param to save
        /// storage reads.
        fn get_staker_total_strk_balance_curr_epoch(
            self: @ContractState,
            staker_address: ContractAddress,
            staker_pool_info: StoragePath<InternalStakerPoolInfoV2>,
            curr_epoch: Epoch,
        ) -> NormalizedAmount {
            let curr_own_balance = self
                .get_staker_own_balance_at_epoch(:staker_address, epoch_id: curr_epoch);
            let strk_pool = staker_pool_info.get_strk_pool();
            let curr_delegated_balance = if let Some(strk_pool) = strk_pool {
                self
                    .get_staker_delegated_balance_at_epoch(
                        :staker_address, pool_contract: strk_pool, epoch_id: curr_epoch,
                    )
            } else {
                Zero::zero()
            };
            curr_own_balance + curr_delegated_balance
        }

        /// Returns the total BTC balance of the staker in the current epoch.
        ///
        /// **Note**: `curr_epoch` must be `get_current_epoch()`, it's passed as a param to save
        /// storage reads.
        fn get_staker_total_btc_balance_curr_epoch(
            self: @ContractState,
            staker_address: ContractAddress,
            staker_pool_info: StoragePath<InternalStakerPoolInfoV2>,
            curr_epoch: Epoch,
        ) -> NormalizedAmount {
            let mut total_btc_balance: NormalizedAmount = Zero::zero();
            for (pool_contract, token_address) in staker_pool_info.pools {
                // TODO: Consider optimize here - `is_active_token` check again the STRK token.
                if token_address != STRK_TOKEN_ADDRESS
                    && self.is_active_token(:token_address, :curr_epoch) {
                    let pool_balance_curr_epoch = self
                        .get_staker_delegated_balance_at_epoch(
                            :staker_address, :pool_contract, epoch_id: curr_epoch,
                        );
                    total_btc_balance += pool_balance_curr_epoch;
                }
            }
            total_btc_balance
        }

        /// Note that `epoch_id` must be `get_current_epoch()` or `get_current_epoch() + 1`.
        /// This parameter exists to save calls to `get_current_epoch()`.
        fn get_staker_own_balance_at_epoch(
            self: @ContractState, staker_address: ContractAddress, epoch_id: Epoch,
        ) -> NormalizedAmount {
            let trace = self.staker_own_balance_trace.entry(key: staker_address);
            self.balance_at_epoch(:trace, :epoch_id)
        }

        /// Note that `epoch_id` must be `get_current_epoch()` or `get_current_epoch() + 1`.
        /// This parameter exists to save calls to `get_current_epoch()`.
        fn get_staker_delegated_balance_at_epoch(
            self: @ContractState,
            staker_address: ContractAddress,
            pool_contract: ContractAddress,
            epoch_id: Epoch,
        ) -> NormalizedAmount {
            let trace = self
                .staker_delegated_balance_trace
                .entry(key: staker_address)
                .entry(key: pool_contract);
            self.balance_at_epoch(:trace, :epoch_id)
        }

        /// Returns the balance at the specified epoch.
        ///
        /// Note that `epoch_id` must be `get_current_epoch()` or `get_current_epoch() + 1`.
        /// This parameter exists to save calls to `get_current_epoch()`.
        fn balance_at_epoch(
            self: @ContractState, trace: StoragePath<Trace>, epoch_id: Epoch,
        ) -> NormalizedAmount {
            let (epoch, balance) = trace.last().unwrap_or_else(|err| panic!("{err}"));
            let current_balance = if epoch <= epoch_id {
                balance
            } else {
                let (epoch, balance) = trace.second_last().unwrap_or_else(|err| panic!("{err}"));
                assert!(epoch <= epoch_id, "{}", GenericError::INVALID_SECOND_LAST);
                balance
            };
            NormalizedAmountTrait::from_amount_18_decimals(amount: current_balance)
        }

        /// Returns (old_own_balance, new_own_balance).
        fn increase_staker_own_amount(
            ref self: ContractState, staker_address: ContractAddress, amount: NormalizedAmount,
        ) -> (NormalizedAmount, NormalizedAmount) {
            let old_own_balance = self.get_own_balance(:staker_address);
            let new_own_balance = old_own_balance + amount;
            self.insert_staker_own_balance(:staker_address, own_balance: new_own_balance);
            self.add_to_total_stake(token_address: STRK_TOKEN_ADDRESS, :amount);
            (old_own_balance, new_own_balance)
        }

        fn is_commission_commitment_active(
            self: @ContractState, commission_commitment: CommissionCommitment,
        ) -> bool {
            self.get_current_epoch() < commission_commitment.expiration_epoch
        }

        fn get_staker_address_by_operational(
            self: @ContractState, operational_address: ContractAddress,
        ) -> ContractAddress {
            let staker_address = self
                .operational_address_to_staker_address
                .read(operational_address);
            assert!(staker_address.is_non_zero(), "{}", GenericError::STAKER_NOT_EXISTS);
            staker_address
        }

        fn write_staker_info(
            ref self: ContractState,
            staker_address: ContractAddress,
            staker_info: InternalStakerInfoLatest,
        ) {
            self
                .staker_info
                .write(staker_address, VInternalStakerInfoTrait::wrap_latest(staker_info));
        }

        fn assert_staker_address_not_reused(self: @ContractState, staker_address: ContractAddress) {
            // Catch stakers that entered in an older version (V0 or V1), and performed
            // `exit_action` in V1.
            assert!(
                self.staker_balance_trace.entry(key: staker_address).is_empty(),
                "{}",
                Error::STAKER_ADDRESS_ALREADY_USED_IN_V1,
            );
            assert!(
                self.staker_own_balance_trace.entry(key: staker_address).is_empty(),
                "{}",
                Error::STAKER_ADDRESS_ALREADY_USED,
            );
        }

        fn assert_caller_is_attestation_contract(self: @ContractState) {
            assert!(
                get_caller_address() == self.attestation_contract.read(),
                "{}",
                Error::CALLER_IS_NOT_ATTESTATION_CONTRACT,
            );
        }

        fn does_token_exist(self: @ContractState, token_address: ContractAddress) -> bool {
            token_address == STRK_TOKEN_ADDRESS || self.btc_tokens.read(token_address).is_some()
        }

        /// Returns true if the token is active in the current epoch.
        /// Assumes that the token exists.
        ///
        /// **Note**: `curr_epoch` must be `get_current_epoch()`, it's passed as a param to save
        /// storage reads.
        fn is_active_token(
            self: @ContractState, token_address: ContractAddress, curr_epoch: Epoch,
        ) -> bool {
            token_address == STRK_TOKEN_ADDRESS
                || self
                    .is_btc_active(
                        active_status: self.btc_tokens.read(token_address).unwrap(), :curr_epoch,
                    )
        }

        /// Returns true if the BTC token is active in the current epoch.
        ///
        /// **Note**: `curr_epoch` must be `get_current_epoch()`, it's passed as a param to save
        /// storage reads.
        fn is_btc_active(
            self: @ContractState, active_status: (Epoch, bool), curr_epoch: Epoch,
        ) -> bool {
            let (epoch, is_active) = active_status;
            (curr_epoch >= epoch) == is_active
        }

        fn get_token_decimals(self: @ContractState, token_address: ContractAddress) -> u8 {
            self.token_decimals.read(token_address)
        }

        /// Returns the public key for `staker_address` at `epoch_id`,
        /// or `None` if the public key is not set.
        /// **Note**: This function does not check if the staker exists.
        /// **Note**: `epoch_id` must be `get_current_epoch()` or `get_current_epoch() + 1`.
        fn get_public_key_at_epoch(
            self: @ContractState, staker_address: ContractAddress, epoch_id: Epoch,
        ) -> Option<PublicKey> {
            let (activation_epoch, old_pk, new_pk) = self.public_key.read(staker_address);
            let current_pk = if epoch_id >= activation_epoch {
                new_pk
            } else {
                old_pk
            };
            if current_pk.is_non_zero() {
                Some(current_pk)
            } else {
                None
            }
        }

        /// Calculates rewards for the given staker and his pools, updates the staker's
        /// `unclaimed_rewards`, and updates and transfers rewards to the pools.
        ///
        /// **In V2 - `update_rewards_from_attestation_contract`:**
        /// Rewards are calculated as the staker's relative share of the total stake, multiplied by
        /// epoch rewards.
        /// - `strk_total_rewards` = STRK epoch rewards.
        /// - `btc_total_rewards` = BTC epoch rewards.
        /// - `strk_total_stake` = current total STRK staking power.
        /// - `btc_total_stake` = current total BTC staking power.
        ///
        /// **In V3 - `update_rewards`:**
        /// Rewards are calculated as the relative share of the staker's own stake and each of his
        /// pools within the staker's total stake, multiplied by block rewards.
        /// - `strk_total_rewards` = STRK block rewards.
        /// - `btc_total_rewards` = BTC block rewards.
        /// - `strk_total_stake` = current total STRK staked for the given staker (own + delegated).
        /// - `btc_total_stake` = current total BTC staked for the given staker (delegated).
        ///
        /// **Note**: `curr_epoch` must be `get_current_epoch()`, it's passed as a param to save
        /// storage reads.
        fn _update_rewards(
            ref self: ContractState,
            staker_address: ContractAddress,
            strk_total_rewards: Amount,
            btc_total_rewards: Amount,
            strk_total_stake: NormalizedAmount,
            btc_total_stake: NormalizedAmount,
            mut staker_info: InternalStakerInfoLatest,
            staker_pool_info: StoragePath<InternalStakerPoolInfoV2>,
            reward_supplier_dispatcher: IRewardSupplierDispatcher,
            curr_epoch: Epoch,
        ) {
            // Calculate self rewards.
            let staker_own_rewards = self
                .calculate_staker_own_rewards(
                    :staker_address, :strk_total_rewards, :strk_total_stake, :curr_epoch,
                );

            // Calculate pools rewards.
            let (commission_rewards, total_pools_rewards, pools_rewards_data) = if staker_pool_info
                .has_pool() {
                self
                    .calculate_staker_pools_rewards(
                        :staker_address,
                        :staker_pool_info,
                        :strk_total_rewards,
                        :strk_total_stake,
                        :btc_total_rewards,
                        :btc_total_stake,
                        :curr_epoch,
                    )
            } else {
                (Zero::zero(), Zero::zero(), array![])
            };

            // Update reward supplier.
            let staker_rewards = staker_own_rewards + commission_rewards;
            // Update total rewards.
            reward_supplier_dispatcher
                .update_unclaimed_rewards_from_staking_contract(
                    rewards: staker_rewards + total_pools_rewards,
                );
            // Claim pools rewards.
            self
                .claim_from_reward_supplier(
                    :reward_supplier_dispatcher,
                    amount: total_pools_rewards,
                    token_dispatcher: strk_token_dispatcher(),
                );
            // Update staker rewards.
            staker_info.unclaimed_rewards_own += staker_rewards;

            // Update pools rewards.
            let pool_rewards_list = self.update_pool_rewards(:staker_address, :pools_rewards_data);
            // Emit event.
            self
                .emit(
                    Events::StakerRewardsUpdated {
                        staker_address, staker_rewards, pool_rewards: pool_rewards_list.span(),
                    },
                );

            // Write staker rewards to storage.
            self.write_staker_info(:staker_address, :staker_info);
        }

        fn is_v3(self: @ContractState) -> bool {
            let v3_epoch = self.v3_rewards_first_epoch.read();
            v3_epoch.is_non_zero() && self.get_current_epoch() >= v3_epoch
        }
    }

    /// Return the token dispatcher for STRK.
    fn strk_token_dispatcher() -> IERC20Dispatcher {
        IERC20Dispatcher { contract_address: STRK_TOKEN_ADDRESS }
    }
}
