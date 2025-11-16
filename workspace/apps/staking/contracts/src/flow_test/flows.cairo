use ReleaseVersion::{V0, V1, V2};
use core::num::traits::Zero;
use core::num::traits::ops::pow::Pow;
use snforge_std::{TokenImpl, get_class_hash, start_cheat_block_number_global};
use staking::attestation::attestation::Attestation::MIN_ATTESTATION_WINDOW;
use staking::constants::{ALPHA, ALPHA_DENOMINATOR, STRK_IN_FRIS};
use staking::errors::{GenericError, InternalError};
use staking::flow_test::utils::MainnetClassHashes::{
    MAINNET_POOL_CLASS_HASH_V1, MAINNET_STAKING_CLASS_HASH_V0, MAINNET_STAKING_CLASS_HASH_V1,
    MAINNET_STAKING_CLASS_HASH_V2,
};
use staking::flow_test::utils::{
    AttestationTrait, Delegator, FlowTrait, MultiVersionFlowTrait, ReleaseVersion,
    RewardSupplierTrait, Staker, StakingTrait, SystemDelegatorTrait, SystemPoolTrait,
    SystemStakerTrait, SystemState, SystemTrait, TokenHelperTrait,
};
use staking::pool::errors::Error as PoolError;
use staking::pool::interface_v0::{
    PoolMemberInfo, PoolMemberInfoIntoInternalPoolMemberInfoV1Trait, PoolMemberInfoTrait,
};
use staking::pool::pool::Pool::STRK_CONFIG;
use staking::pool::utils::compute_rewards_rounded_down;
use staking::staking::errors::Error as StakingError;
use staking::staking::interface::{
    IStakingDispatcherTrait, IStakingMigrationSafeDispatcherTrait, IStakingSafeDispatcherTrait,
    PoolInfo, StakerInfoV1, StakerInfoV1Trait, StakerPoolInfoV2,
};
use staking::staking::objects::{EpochInfoTrait, NormalizedAmountTrait, StakerVersion};
use staking::staking::staking::Staking::V3_PREV_CONTRACT_VERSION;
use staking::test_utils::constants::{
    BTC_18D_CONFIG, BTC_8D_CONFIG, BTC_DECIMALS_18, BTC_DECIMALS_8, EPOCH_DURATION, STRK_BASE_VALUE,
    TEST_BTC_DECIMALS, TEST_MIN_BTC_FOR_REWARDS, TEST_ONE_BTC,
};
use staking::test_utils::{
    calculate_pool_member_rewards, calculate_staker_btc_pool_rewards_v2,
    calculate_staker_strk_rewards_v2, calculate_strk_pool_rewards_v2,
    calculate_strk_pool_rewards_with_pool_balance_v2, compute_rewards_per_unit,
    declare_pool_contract, declare_pool_eic_contract, declare_staking_contract,
    load_from_simple_map, load_one_felt, strk_pool_update_rewards_v1, to_amount_18_decimals,
    upgrade_implementation,
};
use staking::types::{Amount, Commission};
use starknet::{ClassHash, ContractAddress, Store};
use starkware_utils::components::replaceability::interface::{EICData, ImplementationData};
use starkware_utils::errors::{Describable, ErrorDisplay};
use starkware_utils::math::abs::wide_abs_diff;
use starkware_utils::math::utils::mul_wide_and_div;
use starkware_utils::time::time::{Time, TimeDelta};
use starkware_utils_testing::test_utils::{assert_panic_with_error, cheat_caller_address_once};

/// Flow - Basic Stake:
/// Staker - Stake with pool - cover if pool_enabled=true
/// Staker increase_stake - cover if pool amount = 0 in calc_rew
/// Delegator delegate (and create) to Staker
/// Staker increase_stake - cover pool amount > 0 in calc_rew
/// Delegator increase_delegate
/// Exit and check
#[derive(Drop, Copy)]
pub(crate) struct BasicStakeFlow {}
pub(crate) impl BasicStakeFlowImpl of FlowTrait<BasicStakeFlow> {
    fn test(self: BasicStakeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let staker = system.new_staker(amount: stake_amount * 2);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, commission: 200);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount / 4);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_delegate(:delegator, :pool, amount: stake_amount / 4);
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount * 3 / 4);
        system.advance_k_epochs_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);
        system.staker_exit_action(:staker);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: pool) < 100);
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount * 2);
        assert!(system.token.balance_of(account: delegator.delegator.address) == stake_amount);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Pool upgrade regression flow.
/// Staker stake with pool
/// Upgrade
/// BasicStakeFlow
/// Staker2 stake with pool
/// Delegator switch
/// Test switch
#[derive(Drop, Copy)]
pub(crate) struct PoolUpgradeBasicFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) stake_amount: Option<Amount>,
    pub(crate) initial_reward_supplier_balance: Option<Amount>,
}
pub(crate) impl PoolUpgradeBasicFlowImpl of MultiVersionFlowTrait<PoolUpgradeBasicFlow> {
    fn versions(self: PoolUpgradeBasicFlow) -> Span<ReleaseVersion> {
        [V1, V2].span()
    }

    fn setup(ref self: PoolUpgradeBasicFlow, ref system: SystemState) {
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(amount: amount * 2);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
        self.stake_amount = Option::Some(amount);
        self.initial_reward_supplier_balance = Option::Some(initial_reward_supplier_balance);
    }

    fn test(self: PoolUpgradeBasicFlow, ref system: SystemState, version: ReleaseVersion) {
        let staker = self.staker.unwrap();
        let stake_amount = self.stake_amount.unwrap();
        let initial_reward_supplier_balance = self.initial_reward_supplier_balance.unwrap();

        // BasicStakeFlow
        system.advance_k_epochs_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount / 4);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_delegate(:delegator, :pool, amount: stake_amount / 4);
        system.advance_k_epochs_and_attest(:staker);

        let switch_amount = stake_amount * 3 / 4;
        system.delegator_exit_intent(:delegator, :pool, amount: switch_amount);
        system.advance_k_epochs_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);
        system.delegator_claim_rewards(:delegator, :pool);

        // Staker2 stake with pool
        let staker2 = system.new_staker(amount: stake_amount);
        system.stake(staker: staker2, amount: stake_amount, pool_enabled: true, commission: 100);
        let pool2 = system.staking.get_pool(staker: staker2);

        // Delegator switch
        system
            .switch_delegation_pool(
                :delegator,
                from_pool: pool,
                to_staker: staker2.staker.address,
                to_pool: pool2,
                amount: switch_amount,
            );

        // Test balances
        assert!(
            system.token.balance_of(account: system.staking.address) == switch_amount
                + stake_amount,
        );
        assert!(system.token.balance_of(account: pool) < 100);
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount * 2);
        assert!(
            system.token.balance_of(account: delegator.delegator.address) == stake_amount
                - switch_amount,
        );
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow - Basic Stake with BTC:
/// Staker stake
/// Staker open BTC pool
/// Staker increase_stake - cover if pool amount = 0 in calc_rew
/// Delegator delegate (and create) to Staker
/// Staker increase_stake - cover pool amount > 0 in calc_rew
/// Delegator increase_delegate
/// Delegator exit intent
/// Staker exit intent and action
/// Staker2 stake
/// Staker2 open BTC pool
/// Delegator switch
/// Test balances
#[derive(Drop, Copy)]
pub(crate) struct BasicStakeBTCFlow {}
pub(crate) impl BasicStakeBTCFlowImpl of FlowTrait<BasicStakeBTCFlow> {
    fn test(self: BasicStakeBTCFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let delegate_amount = TEST_MIN_BTC_FOR_REWARDS * 16;
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        system.stake(:staker, amount: stake_amount, pool_enabled: false, :commission);

        // Staker open BTC pool
        system.set_commission(:staker, :commission);
        let token = system.btc_token;
        let token_address = token.contract_address();
        let pool = system.set_open_for_delegation(:staker, :token_address);

        system.advance_k_epochs_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        let delegator = system.new_btc_delegator(amount: delegate_amount, :token);
        system.delegate_btc(:delegator, :pool, amount: delegate_amount / 2, :token);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount / 4);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_delegate_btc(:delegator, :pool, amount: delegate_amount / 4, :token);
        system.advance_k_epochs_and_attest(:staker);

        let switch_amount = delegate_amount * 3 / 4;
        system.delegator_exit_intent(:delegator, :pool, amount: switch_amount);
        system.advance_k_epochs_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.delegator_claim_rewards(:delegator, :pool);
        system.staker_exit_action(:staker);

        let staker2 = system.new_staker(amount: stake_amount);
        system
            .stake(
                staker: staker2,
                amount: stake_amount,
                pool_enabled: false,
                commission: commission / 2,
            );
        system.set_commission(staker: staker2, commission: commission / 2);
        let pool2 = system.set_open_for_delegation(staker: staker2, :token_address);
        system
            .switch_delegation_pool(
                :delegator,
                from_pool: pool,
                to_staker: staker2.staker.address,
                to_pool: pool2,
                amount: switch_amount,
            );

        assert!(system.token.balance_of(account: system.staking.address) == stake_amount);
        assert!(system.btc_token.balance_of(account: system.staking.address) == switch_amount);
        assert!(system.token.balance_of(account: pool) < 100);
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount * 2);
        assert!(
            system.btc_token.balance_of(account: delegator.delegator.address) == delegate_amount
                - switch_amount,
        );
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Staker exit_intent
/// Staker exit_action
/// Delegator partially exit_intent
/// Delegator exit_action
/// Delegator exit_intent
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorIntentAfterStakerActionFlow {}
pub(crate) impl DelegatorIntentAfterStakerActionFlowImpl of FlowTrait<
    DelegatorIntentAfterStakerActionFlow,
> {
    fn test(self: DelegatorIntentAfterStakerActionFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount);
        system.advance_k_epochs_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.staker_exit_action(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount / 2);
        system.delegator_exit_action(:delegator, :pool);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount / 2);
        system.delegator_exit_action(:delegator, :pool);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(
            system.token.balance_of(account: pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount * 2);
        assert!(system.token.balance_of(account: delegator.delegator.address) == stake_amount);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow:
/// Staker - Stake without pool - cover if pool_enabled=false
/// Staker increase_stake - cover if pool amount=none in update_rewards
/// Staker claim_rewards
/// Staker set_open_for_delegation
/// Delegator delegate - cover delegating after opening an initially closed pool
/// Exit and check
#[derive(Drop, Copy)]
pub(crate) struct SetOpenForDelegationFlow {}
pub(crate) impl SetOpenForDelegationFlowImpl of FlowTrait<SetOpenForDelegationFlow> {
    fn test(self: SetOpenForDelegationFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let initial_stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: initial_stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: initial_stake_amount, pool_enabled: false, :commission);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_stake(:staker, amount: initial_stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        assert!(system.token.balance_of(account: staker.reward.address).is_zero());
        system.staker_claim_rewards(:staker);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());

        let pool = system.set_open_for_strk_delegation(:staker, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let delegator = system.new_delegator(amount: initial_stake_amount);
        system.delegate(:delegator, :pool, amount: initial_stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.delegator_exit_intent(:delegator, :pool, amount: initial_stake_amount / 2);

        system.delegator_exit_action(:delegator, :pool);
        system.staker_exit_action(:staker);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(
            system.token.balance_of(account: pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.
        assert!(
            system.token.balance_of(account: staker.staker.address) == initial_stake_amount * 2,
        );
        assert!(
            system.token.balance_of(account: delegator.delegator.address) == initial_stake_amount,
        );
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow:
/// Staker1 stake with pool
/// Staker2 stake with pool
/// Staker1 add btc pool
/// Staker2 add btc pool
/// Strk delegator delegate to staker1
/// Btc delegator delegate to staker1
/// Delegators exit intent
/// Delegators change intent
/// Test delegators exit actions before exit window
/// Delegators exit actions after exit window
/// Delegators switch delegation pool
/// Test pools
#[derive(Drop, Copy)]
pub(crate) struct MultiplePoolsDelegatorIntentActionSwitchFlow {}
pub(crate) impl MultiplePoolsDelegatorIntentActionSwitchFlowImpl of FlowTrait<
    MultiplePoolsDelegatorIntentActionSwitchFlow,
> {
    fn test(self: MultiplePoolsDelegatorIntentActionSwitchFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let first_staker = system.new_staker(:amount);
        let second_staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(staker: first_staker, :amount, pool_enabled: true, :commission);
        system.stake(staker: second_staker, :amount, pool_enabled: true, :commission);

        // Set up pools.
        let first_strk_pool = system.staking.get_pool(staker: first_staker);
        let first_btc_pool = system
            .set_open_for_delegation(
                staker: first_staker, token_address: system.btc_token.contract_address(),
            );
        let second_strk_pool = system.staking.get_pool(staker: second_staker);
        let second_btc_pool = system
            .set_open_for_delegation(
                staker: second_staker, token_address: system.btc_token.contract_address(),
            );

        // Delegators delegate.
        let strk_delegator = system.new_delegator(:amount);
        let btc_delegator = system.new_btc_delegator(:amount, token: system.btc_token);
        system.delegate(delegator: strk_delegator, pool: first_strk_pool, :amount);
        system
            .delegate_btc(
                delegator: btc_delegator, pool: first_btc_pool, :amount, token: system.btc_token,
            );

        // Delegators exit intents.
        system.delegator_exit_intent(delegator: strk_delegator, pool: first_strk_pool, :amount);
        system.delegator_exit_intent(delegator: btc_delegator, pool: first_btc_pool, :amount);

        // Delegators change intent.
        let amount = amount / 2;
        system.delegator_exit_intent(delegator: strk_delegator, pool: first_strk_pool, :amount);
        system.delegator_exit_intent(delegator: btc_delegator, pool: first_btc_pool, :amount);

        // Delegators exit actions before exit window.
        cheat_caller_address_once(
            contract_address: first_strk_pool, caller_address: strk_delegator.delegator.address,
        );
        let res = system
            .safe_delegator_exit_action(delegator: strk_delegator, pool: first_strk_pool);
        assert_panic_with_error(res, GenericError::INTENT_WINDOW_NOT_FINISHED.describe());
        cheat_caller_address_once(
            contract_address: first_btc_pool, caller_address: btc_delegator.delegator.address,
        );
        let res = system.safe_delegator_exit_action(delegator: btc_delegator, pool: first_btc_pool);
        assert_panic_with_error(res, GenericError::INTENT_WINDOW_NOT_FINISHED.describe());

        // Delegators exit actions after exit window.
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.delegator_exit_action(delegator: strk_delegator, pool: first_strk_pool);
        system.delegator_exit_action(delegator: btc_delegator, pool: first_btc_pool);

        // Delegators switch delegation pool.
        system.delegator_exit_intent(delegator: strk_delegator, pool: first_strk_pool, :amount);
        system.delegator_exit_intent(delegator: btc_delegator, pool: first_btc_pool, :amount);
        system
            .switch_delegation_pool(
                delegator: strk_delegator,
                from_pool: first_strk_pool,
                to_staker: second_staker.staker.address,
                to_pool: second_strk_pool,
                amount: amount,
            );
        system
            .switch_delegation_pool(
                delegator: btc_delegator,
                from_pool: first_btc_pool,
                to_staker: second_staker.staker.address,
                to_pool: second_btc_pool,
                amount: amount,
            );

        // Test pools.
        let first_staker_expected_pool_info = StakerPoolInfoV2 {
            commission: Option::Some(commission),
            pools: array![
                PoolInfo {
                    pool_contract: first_strk_pool,
                    amount: Zero::zero(),
                    token_address: system.staking.get_token_address(),
                },
                PoolInfo {
                    pool_contract: first_btc_pool,
                    amount: Zero::zero(),
                    token_address: system.btc_token.contract_address(),
                },
            ]
                .span(),
        };
        let first_staker_pool_info = system.staker_pool_info(staker: first_staker);
        assert!(first_staker_pool_info == first_staker_expected_pool_info);

        let second_staker_expected_pool_info = StakerPoolInfoV2 {
            commission: Option::Some(commission),
            pools: array![
                PoolInfo {
                    pool_contract: second_strk_pool,
                    amount,
                    token_address: system.staking.get_token_address(),
                },
                PoolInfo {
                    pool_contract: second_btc_pool,
                    amount,
                    token_address: system.btc_token.contract_address(),
                },
            ]
                .span(),
        };
        let second_staker_pool_info = system.staker_pool_info(staker: second_staker);
        assert!(second_staker_pool_info == second_staker_expected_pool_info);
    }
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator exit_intent partial amount
/// Delegator exit_intent with lower amount - cover lowering partial undelegate
/// Delegator exit_intent with zero amount - cover clearing an intent
/// Delegator exit_intent all amount
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorIntentFlow {}
pub(crate) impl DelegatorIntentFlowImpl of FlowTrait<DelegatorIntentFlow> {
    fn test(self: DelegatorIntentFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegated_amount = stake_amount;
        let delegator = system.new_delegator(amount: delegated_amount);
        system.delegate(:delegator, :pool, amount: delegated_amount);
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 4);
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: Zero::zero());
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.advance_k_epochs_and_attest(:staker);
        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);
        system.advance_k_epochs_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: pool) < 100);
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

// Flow 8:
// Staker1 stake
// Staker2 stake
// Delegator delegate to staker1's pool
// Staker1 exit_intent
// Delegator exit_intent - get current block_timestamp as exit time
// Staker1 exit_action - cover staker action with while having a delegator in intent
// Delegator switch part of intent to staker2's pool - cover switching from a dead staker (should
// not matter he is back alive)
// Delegator exit_action in staker1's original pool - cover delegator exit action with dead staker
// Delegator claim rewards in staker2's pool - cover delegator claim rewards with dead staker
// Delegator exit_intent for remaining amount in staker1's original pool (the staker is dead there)
// Delegator exit_action in staker1's original pool - cover full delegator exit with dead staker
// Staker1 exit_intent
// Staker2 exit_intent
// Staker1 exit_action
// Staker2 exit_action
// Delegator exit_intent for full amount in staker2's pool
// Delegator exit_action for full amount in staker2's pool
#[derive(Drop, Copy)]
pub(crate) struct OperationsAfterDeadStakerFlow {}
pub(crate) impl OperationsAfterDeadStakerFlowImpl of FlowTrait<OperationsAfterDeadStakerFlow> {
    fn test(self: OperationsAfterDeadStakerFlow, ref system: SystemState) {
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let delegated_amount = stake_amount;
        let staker1 = system.new_staker(amount: stake_amount);
        let staker2 = system.new_staker(amount: stake_amount);
        let delegator = system.new_delegator(amount: delegated_amount);
        let commission = 200;

        system.stake(staker: staker1, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(staker: staker1);

        system.stake(staker: staker2, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(staker: staker1);
        system.advance_k_epochs_and_attest(staker: staker2);

        let staker1_pool = system.staking.get_pool(staker: staker1);
        system.delegate(:delegator, pool: staker1_pool, amount: delegated_amount);
        system.advance_k_epochs_and_attest(staker: staker1);

        system.staker_exit_intent(staker: staker1);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.advance_k_epochs_and_attest(staker: staker2);

        // After the following, delegator has 1/2 in staker1, and 1/2 in intent.
        system.delegator_exit_intent(:delegator, pool: staker1_pool, amount: delegated_amount / 2);
        system.advance_k_epochs_and_attest(staker: staker2);

        system.staker_exit_action(staker: staker1);

        // After the following, delegator has delegated_amount / 2 in staker1, delegated_amount
        // / 4 in intent, and delegated_amount / 4 in staker2.
        let staker2_pool = system.staking.get_pool(staker: staker2);
        system
            .switch_delegation_pool(
                :delegator,
                from_pool: staker1_pool,
                to_staker: staker2.staker.address,
                to_pool: staker2_pool,
                amount: delegated_amount / 4,
            );
        system.advance_k_epochs_and_attest(staker: staker2);

        // After the following, delegator has delegated_amount / 2 in staker1, and
        // delegated_amount / 4 in staker2.
        system.delegator_exit_action(:delegator, pool: staker1_pool);
        system.advance_k_epochs_and_attest(staker: staker2);

        // Claim rewards from second pool and see that the rewards are increasing.
        assert!(system.token.balance_of(account: delegator.reward.address).is_zero());
        system.delegator_claim_rewards(:delegator, pool: staker2_pool);
        let delegator_reward_before_advance_epoch = system
            .token
            .balance_of(account: delegator.reward.address);
        assert!(delegator_reward_before_advance_epoch.is_non_zero());

        // Advance epoch and claim rewards again, and see that the rewards are increasing.
        system.advance_epoch();
        system.delegator_claim_rewards(:delegator, pool: staker2_pool);
        let delegator_reward_after_advance_epoch = system
            .token
            .balance_of(account: delegator.reward.address);
        assert!(delegator_reward_after_advance_epoch > delegator_reward_before_advance_epoch);

        // Advance epoch and attest.
        system.advance_k_epochs_and_attest(staker: staker2);
        system.advance_epoch();

        // After the following, delegator has delegated_amount / 4 in staker2.
        system.delegator_exit_intent(:delegator, pool: staker1_pool, amount: delegated_amount / 2);
        system.delegator_exit_action(:delegator, pool: staker1_pool);
        system.delegator_claim_rewards(:delegator, pool: staker1_pool);

        // Clean up and make all parties exit.
        system.staker_exit_intent(staker: staker2);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.staker_exit_action(staker: staker2);
        system.delegator_exit_intent(:delegator, pool: staker2_pool, amount: delegated_amount / 4);
        system.delegator_exit_action(:delegator, pool: staker2_pool);
        system.delegator_claim_rewards(:delegator, pool: staker2_pool);

        // ------------- Flow complete, now asserts -------------

        // Assert pools' balances are low.
        assert!(system.token.balance_of(account: staker1_pool) < 100);
        assert!(system.token.balance_of(account: staker2_pool) < 100);

        // Assert all staked amounts were transferred back.
        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: staker1.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: staker2.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);

        // Asserts reward addresses are not empty.
        assert!(system.token.balance_of(account: staker1.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: staker2.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());

        // Assert all funds that moved from rewards supplier, were moved to correct addresses.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker1.reward.address)
                + system.token.balance_of(account: staker2.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: staker1_pool)
                + system.token.balance_of(account: staker2_pool),
        );
    }
}

// Flow:
// Staker stake with commission 100%
// Delegator delegate
// Staker update_commission to 0%
// Delegator exit_intent
// Delegator exit_action, should get rewards
// Staker exit_intent
// Staker exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorDidntUpdateAfterStakerUpdateCommissionFlow {}
pub(crate) impl DelegatorDidntUpdateAfterStakerUpdateCommissionFlowImpl of FlowTrait<
    DelegatorDidntUpdateAfterStakerUpdateCommissionFlow,
> {
    fn test(self: DelegatorDidntUpdateAfterStakerUpdateCommissionFlow, ref system: SystemState) {
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let delegated_amount = stake_amount;
        let staker = system.new_staker(amount: stake_amount);
        let delegator = system.new_delegator(amount: delegated_amount);
        let commission = 10000;

        // Stake with commission 100%
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        // Update commission to 0%
        system.set_commission(:staker, commission: Zero::zero());
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.advance_k_epochs_and_attest(:staker);
        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);

        // Clean up and make all parties exit.
        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        // ------------- Flow complete, now asserts -------------

        // Assert pool balance is zero.
        assert!(system.token.balance_of(account: pool) == 0);

        // Assert all staked amounts were transferred back.
        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);

        // Assert staker reward address is not empty.
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());

        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());

        // Assert all funds that moved from rewards supplier, were moved to correct addresses.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address),
        );
    }
}

// Flow:
// Staker stake with commission 100%
// Delegator delegate
// Staker update_commission to 0%
// Delegator claim rewards
// Delegator exit_intent
// Delegator exit_action, should get rewards
// Staker exit_intent
// Staker exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorUpdatedAfterStakerUpdateCommissionFlow {}
pub(crate) impl DelegatorUpdatedAfterStakerUpdateCommissionFlowImpl of FlowTrait<
    DelegatorUpdatedAfterStakerUpdateCommissionFlow,
> {
    fn test(self: DelegatorUpdatedAfterStakerUpdateCommissionFlow, ref system: SystemState) {
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let delegated_amount = stake_amount;
        let staker = system.new_staker(amount: stake_amount);
        let delegator = system.new_delegator(amount: delegated_amount);
        let commission = 10000;

        // Stake with commission 100%.
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);
        system.advance_k_epochs_and_attest(:staker);
        assert!(system.token.balance_of(account: pool).is_zero());

        // Update commission to 0%.
        system.set_commission(:staker, commission: Zero::zero());
        system.advance_k_epochs_and_attest(:staker);
        assert!(system.token.balance_of(account: pool).is_non_zero());

        // Delegator claim_rewards.
        system.delegator_claim_rewards(:delegator, :pool);
        assert!(
            system.token.balance_of(account: delegator.reward.address) == Zero::zero(),
        ); // TODO: Change this after implement calculate_rewards.
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);

        // Clean up and make all parties exit.
        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        // ------------- Flow complete, now asserts -------------

        // Assert pool balance is high.
        assert!(system.token.balance_of(account: pool) > 100);

        // Assert all staked amounts were transferred back.
        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);

        // Asserts reward addresses are not empty.
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());

        // Assert all funds that moved from rewards supplier, were moved to correct addresses.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator exit_intent
/// Staker exit_intent
/// Staker exit_action
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct StakerIntentLastActionFirstFlow {}
pub(crate) impl StakerIntentLastActionFirstFlowImpl of FlowTrait<StakerIntentLastActionFirstFlow> {
    fn test(self: StakerIntentLastActionFirstFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let initial_stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: initial_stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: initial_stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: initial_stake_amount);
        system.delegate(:delegator, :pool, amount: initial_stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: initial_stake_amount / 2);
        system.advance_k_epochs_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.staker_exit_action(:staker);

        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: pool) < 100);
        assert!(
            system.token.balance_of(account: staker.staker.address) == initial_stake_amount * 2,
        );
        assert!(
            system.token.balance_of(account: delegator.delegator.address) == initial_stake_amount,
        );
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Test pool upgrade flow.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// Delegator exit_intent
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct PoolUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegated_amount: Amount,
}
pub(crate) impl PoolUpgradeFlowImpl of MultiVersionFlowTrait<PoolUpgradeFlow> {
    fn versions(self: PoolUpgradeFlow) -> Span<ReleaseVersion> {
        [V0, V1, V2].span()
    }

    fn setup(ref self: PoolUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegated_amount = delegated_amount;
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: PoolUpgradeFlow, ref system: SystemState, version: ReleaseVersion) {
        let pool = self.pool_address.unwrap();
        let delegator = self.delegator.unwrap();
        let delegated_amount = self.delegated_amount;
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.delegator_exit_action(:delegator, :pool);
        assert!(system.token.balance_of(account: pool) == Zero::zero());
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);
    }
}

/// Test multiple token delegations.
/// Flow:
/// Deploy 2 new btc tokens
/// Staker stake
/// Staker open delegation pools for BTC tokens
/// Delegators delegate to all pools
/// Attest
/// Disable 2 BTC tokens
/// Attest
/// Enable 1 BTC token
/// Attest
/// Test rewards
#[derive(Drop, Copy)]
pub(crate) struct MultipleTokensDelegationFlow {}
pub(crate) impl MultipleTokensDelegationFlowImpl of FlowTrait<MultipleTokensDelegationFlow> {
    fn test(self: MultipleTokensDelegationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        // Setup tokens.
        let first_btc_token = system.btc_token;
        let second_btc_token = system.deploy_second_btc_token();
        system.staking.add_token(token_address: second_btc_token.contract_address());
        system.staking.enable_token(token_address: second_btc_token.contract_address());
        let third_btc_token = system
            .deploy_new_btc_token(name: "THIRD_BTC_TOKEN", decimals: TEST_BTC_DECIMALS);
        system.staking.add_token(token_address: third_btc_token.contract_address());
        system.staking.enable_token(token_address: third_btc_token.contract_address());

        // Stake and open pools.
        system.advance_k_epochs();
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);
        let first_btc_pool = system
            .set_open_for_delegation(:staker, token_address: first_btc_token.contract_address());
        let second_btc_pool = system
            .set_open_for_delegation(:staker, token_address: second_btc_token.contract_address());
        let third_btc_pool = system
            .set_open_for_delegation(:staker, token_address: third_btc_token.contract_address());

        // Setup delegators.
        let first_btc_delegator_amount = TEST_MIN_BTC_FOR_REWARDS;
        let second_btc_delegator_amount = BTC_18D_CONFIG.min_for_rewards * 2;
        let third_btc_delegator_amount = first_btc_delegator_amount * 3;
        let first_btc_delegator = system
            .new_btc_delegator(amount: first_btc_delegator_amount, token: first_btc_token);
        let second_btc_delegator = system
            .new_btc_delegator(amount: second_btc_delegator_amount, token: second_btc_token);
        let third_btc_delegator = system
            .new_btc_delegator(amount: third_btc_delegator_amount, token: third_btc_token);

        // Delegators delegate.
        system
            .delegate_btc(
                delegator: first_btc_delegator,
                pool: first_btc_pool,
                amount: first_btc_delegator_amount,
                token: first_btc_token,
            );
        system
            .delegate_btc(
                delegator: second_btc_delegator,
                pool: second_btc_pool,
                amount: second_btc_delegator_amount,
                token: second_btc_token,
            );
        system
            .delegate_btc(
                delegator: third_btc_delegator,
                pool: third_btc_pool,
                amount: third_btc_delegator_amount,
                token: third_btc_token,
            );

        // Attest.
        system.advance_k_epochs_and_attest(:staker);

        // Calculate rewards.
        let mut total_first_pool_rewards = Zero::zero();
        let mut total_second_pool_rewards = Zero::zero();
        let mut total_third_pool_rewards = Zero::zero();
        let (_, first_pool_rewards) = calculate_staker_btc_pool_rewards_v2(
            pool_balance: first_btc_delegator_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: first_btc_token.contract_address(),
        );
        let (_, second_pool_rewards) = calculate_staker_btc_pool_rewards_v2(
            pool_balance: second_btc_delegator_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: second_btc_token.contract_address(),
        );
        let (_, third_pool_rewards) = calculate_staker_btc_pool_rewards_v2(
            pool_balance: third_btc_delegator_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: third_btc_token.contract_address(),
        );
        total_first_pool_rewards += first_pool_rewards;
        total_second_pool_rewards += second_pool_rewards;
        total_third_pool_rewards += third_pool_rewards;

        // Disable 2 BTC tokens and attest.
        system.advance_epoch();
        system.staking.disable_token(token_address: second_btc_token.contract_address());
        system.staking.disable_token(token_address: third_btc_token.contract_address());
        system.advance_block_into_attestation_window(:staker);
        system.attest(:staker);

        total_first_pool_rewards += first_pool_rewards;
        total_second_pool_rewards += second_pool_rewards;
        total_third_pool_rewards += third_pool_rewards;

        // Enable 1 BTC token and attest.
        system.advance_k_epochs();
        system.staking.enable_token(token_address: second_btc_token.contract_address());
        system.advance_block_into_attestation_window(:staker);
        system.attest(:staker);

        // Calculate rewards.
        let (_, first_pool_rewards) = calculate_staker_btc_pool_rewards_v2(
            pool_balance: first_btc_delegator_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: first_btc_token.contract_address(),
        );
        total_first_pool_rewards += first_pool_rewards;

        system.advance_k_epochs();
        system.advance_block_into_attestation_window(:staker);
        system.attest(:staker);

        // Calculate rewards.
        let (_, first_pool_rewards) = calculate_staker_btc_pool_rewards_v2(
            pool_balance: first_btc_delegator_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: first_btc_token.contract_address(),
        );
        let (_, second_pool_rewards) = calculate_staker_btc_pool_rewards_v2(
            pool_balance: second_btc_delegator_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: second_btc_token.contract_address(),
        );
        total_first_pool_rewards += first_pool_rewards;
        total_second_pool_rewards += second_pool_rewards;

        // Test rewards.
        system.advance_epoch();
        let actual_first_pool_rewards = system
            .delegator_claim_rewards(delegator: first_btc_delegator, pool: first_btc_pool);
        let actual_second_pool_rewards = system
            .delegator_claim_rewards(delegator: second_btc_delegator, pool: second_btc_pool);
        let actual_third_pool_rewards = system
            .delegator_claim_rewards(delegator: third_btc_delegator, pool: third_btc_pool);
        assert!(actual_first_pool_rewards == total_first_pool_rewards);
        assert!(actual_second_pool_rewards == total_second_pool_rewards);
        assert!(actual_third_pool_rewards == total_third_pool_rewards);
    }
}

/// Test pool member info migration with internal_pool_member_info, get_internal_pool_member_info
/// and pool_member_info_v1 functions.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// internal_pool_member_info & get_internal_pool_member_info & pool_member_info_v1
#[derive(Drop, Copy)]
pub(crate) struct PoolMemberInfoAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegator_info: Option<PoolMemberInfo>,
}
pub(crate) impl PoolMemberInfoAfterUpgradeFlowImpl of FlowTrait<PoolMemberInfoAfterUpgradeFlow> {
    fn setup(ref self: PoolMemberInfoAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        let delegator_info = system.pool_member_info(:delegator, :pool);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegator_info = Option::Some(delegator_info);
        system.advance_time(time: one_week);
        system.staking.update_global_index_if_needed();
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: PoolMemberInfoAfterUpgradeFlow, ref system: SystemState) {
        let delegator = self.delegator.unwrap();
        let pool = self.pool_address.unwrap();
        let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
        let internal_pool_member_info_after_upgrade = system
            .internal_pool_member_info(:delegator, :pool);
        let get_internal_pool_member_info_after_upgrade = system
            .get_internal_pool_member_info(:delegator, :pool);
        let expected_pool_member_info = strk_pool_update_rewards_v1(
            pool_member_info: self.delegator_info.unwrap(),
            updated_index: system.staking.get_global_index(),
        );
        assert!(pool_member_info == expected_pool_member_info.to_v1());
        assert!(internal_pool_member_info_after_upgrade == expected_pool_member_info.to_internal());
        assert!(
            get_internal_pool_member_info_after_upgrade == Option::Some(
                expected_pool_member_info.to_internal(),
            ),
        );
    }
}

/// Flow:
/// Staker1 stake
/// Staker2 stake
/// Upgrade
/// Migrate stakers
/// Test staker_pool_info for both
/// Both attest
/// Test rewards both
#[derive(Drop, Copy)]
pub(crate) struct MultipleStakersMigrationAttestFlow {
    pub(crate) staker1: Option<Staker>,
    pub(crate) staker2: Option<Staker>,
    pub(crate) staker_info1: Option<StakerInfoV1>,
    pub(crate) staker_info2: Option<StakerInfoV1>,
    pub(crate) commission: Option<Commission>,
    pub(crate) pool_address: Option<ContractAddress>,
}
pub(crate) impl MultipleStakersMigrationAttestFlowImpl of FlowTrait<
    MultipleStakersMigrationAttestFlow,
> {
    fn setup_v1(ref self: MultipleStakersMigrationAttestFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker1 = system.new_staker(amount: amount * 2);
        let staker2 = system.new_staker(amount: amount * 2);
        let commission = 200;
        system.stake(staker: staker1, :amount, pool_enabled: false, :commission);
        system.stake(staker: staker2, :amount, pool_enabled: true, :commission);
        system.advance_epoch();

        system.set_staker_for_migration(staker_address: staker1.staker.address);
        system.set_staker_for_migration(staker_address: staker2.staker.address);
        self.staker1 = Option::Some(staker1);
        self.staker2 = Option::Some(staker2);
        self.staker_info1 = Option::Some(system.staker_info_v1(staker: staker1));
        self.staker_info2 = Option::Some(system.staker_info_v1(staker: staker2));
        self.commission = Option::Some(commission);
        self.pool_address = Option::Some(system.staking.get_pool(staker: staker2));
    }

    fn test(self: MultipleStakersMigrationAttestFlow, ref system: SystemState) {
        let staker1 = self.staker1.unwrap();
        let staker2 = self.staker2.unwrap();
        let staker_info1 = self.staker_info1.unwrap();
        let staker_info2 = self.staker_info2.unwrap();
        let commission = self.commission.unwrap();
        let pool_address = self.pool_address.unwrap();
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        // Test pool info.
        let expected_pool_info1 = StakerPoolInfoV2 {
            commission: Option::None, pools: array![].span(),
        };
        let expected_pool_info2 = StakerPoolInfoV2 {
            commission: Option::Some(commission),
            pools: array![
                PoolInfo {
                    token_address: system.token.contract_address(),
                    pool_contract: pool_address,
                    amount: 0,
                },
            ]
                .span(),
        };
        let actual_pool_info1 = system.staker_pool_info(staker: staker1);
        let actual_pool_info2 = system.staker_pool_info(staker: staker2);
        assert!(actual_pool_info1 == expected_pool_info1);
        assert!(actual_pool_info2 == expected_pool_info2);

        // Test staker_info.
        let actual_staker_info1 = system.staker_info_v1(staker: staker1);
        let actual_staker_info2 = system.staker_info_v1(staker: staker2);
        assert!(actual_staker_info1 == staker_info1);
        assert!(actual_staker_info2 == staker_info2);

        // Second staker window is earlier.
        system.advance_block_into_attestation_window(staker: staker2);
        system.attest(staker: staker2);
        system.advance_block_into_attestation_window(staker: staker1);
        system.attest(staker: staker1);
        system.advance_epoch();

        // Test rewards.
        let (expected_rewards1, _) = calculate_staker_strk_rewards_v2(
            staker_info: staker_info1, :staking_contract, :minting_curve_contract,
        );
        let actual_rewards1 = system.staker_claim_rewards(staker: staker1);
        let actual_rewards2 = system.staker_claim_rewards(staker: staker2);
        assert!(actual_rewards1 == expected_rewards1);
        assert!(actual_rewards2 == actual_rewards1);
    }
}

/// Test pool member info migration with internal_pool_member_info, get_internal_pool_member_info
/// and pool_member_info_v1 functions.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Delegator exit_intent
/// Upgrade
/// internal_pool_member_info & get_internal_pool_member_info & pool_member_info_v1
#[derive(Drop, Copy)]
pub(crate) struct PoolMemberInfoUndelegateAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegator_info: Option<PoolMemberInfo>,
}
pub(crate) impl PoolMemberInfoUndelegateAfterUpgradeFlowImpl of FlowTrait<
    PoolMemberInfoUndelegateAfterUpgradeFlow,
> {
    fn setup(ref self: PoolMemberInfoUndelegateAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        system.advance_time(time: one_week);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);

        let delegator_info = system.pool_member_info(:delegator, :pool);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegator_info = Option::Some(delegator_info);
        system.advance_time(time: one_week);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: PoolMemberInfoUndelegateAfterUpgradeFlow, ref system: SystemState) {
        let delegator = self.delegator.unwrap();
        let pool = self.pool_address.unwrap();
        let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
        let internal_pool_member_info_after_upgrade = system
            .internal_pool_member_info(:delegator, :pool);
        let get_internal_pool_member_info_after_upgrade = system
            .get_internal_pool_member_info(:delegator, :pool);
        let mut expected_pool_member_info = self.delegator_info.unwrap();
        expected_pool_member_info.index = system.staking.get_global_index();
        assert!(pool_member_info == expected_pool_member_info.to_v1());
        assert!(internal_pool_member_info_after_upgrade == expected_pool_member_info.to_internal());
        assert!(
            get_internal_pool_member_info_after_upgrade == Option::Some(
                expected_pool_member_info.to_internal(),
            ),
        );
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// Delegator increase delegate
#[derive(Drop, Copy)]
pub(crate) struct IncreaseDelegationAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegated_amount: Option<Amount>,
}
pub(crate) impl IncreaseDelegationAfterUpgradeFlowImpl of FlowTrait<
    IncreaseDelegationAfterUpgradeFlow,
> {
    fn setup(ref self: IncreaseDelegationAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let delegated_amount = stake_amount;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegator = system.new_delegator(amount: delegated_amount * 2);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegated_amount = Option::Some(delegated_amount);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: IncreaseDelegationAfterUpgradeFlow, ref system: SystemState) {
        let delegator = self.delegator.unwrap();
        let pool = self.pool_address.unwrap();
        let delegated_amount = self.delegated_amount.unwrap();
        system.increase_delegate(:delegator, :pool, amount: delegated_amount);

        let delegator_info = system.pool_member_info_v1(:delegator, :pool);
        assert!(delegator_info.amount == delegated_amount * 2);
    }
}

/// Flow:
/// Staker stake with pool
/// Upgrade
/// Staker increase_stake
#[derive(Drop, Copy)]
pub(crate) struct IncreaseStakeAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) stake_amount: Option<Amount>,
}
pub(crate) impl IncreaseStakeAfterUpgradeFlowImpl of FlowTrait<IncreaseStakeAfterUpgradeFlow> {
    fn setup(ref self: IncreaseStakeAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        self.staker = Option::Some(staker);
        self.stake_amount = Option::Some(stake_amount);
        let pool = system.staking.get_pool(:staker);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: IncreaseStakeAfterUpgradeFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let stake_amount = self.stake_amount.unwrap();
        system.increase_stake(:staker, amount: stake_amount);

        let staker_info = system.staker_info_v1(:staker);
        assert!(staker_info.amount_own == stake_amount * 2);
    }
}

/// Test
/// Test delegator exit pool and enter again.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Attest
/// Attest
/// Attest
/// Delagator exit intent
/// Delegator exit action
/// Delegator delegate with the same address
/// Attest
/// Attest
/// Delegator claim rewards
/// Staker exit intent
/// Delegator exit intent
/// Staker exit action
/// Delegator exit action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorExitAndEnterAgainFlow {}
pub(crate) impl DelegatorExitAndEnterAgainFlowImpl of FlowTrait<DelegatorExitAndEnterAgainFlow> {
    fn test(self: DelegatorExitAndEnterAgainFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let initial_stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: initial_stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        system.stake(:staker, amount: initial_stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: initial_stake_amount);
        let delegated_amount = initial_stake_amount / 2;
        system.delegate(:delegator, :pool, amount: delegated_amount);
        system.advance_k_epochs_and_attest(:staker);
        // Calculate pool rewards.
        let pool_rewards_epoch = calculate_strk_pool_rewards_v2(
            staker_address: staker.staker.address, :staking_contract, :minting_curve_contract,
        );
        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);

        system.advance_k_epochs_and_attest(:staker);

        system.advance_exit_wait_window();

        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);

        let delegator_rewards_after_exit = system
            .token
            .balance_of(account: delegator.reward.address);

        assert!(delegator_rewards_after_exit == pool_rewards_epoch * 3);

        // Enter again in the same epoch of exit action.
        system.increase_delegate(:delegator, :pool, amount: delegated_amount);
        system.advance_k_epochs_and_attest(:staker);

        system.advance_k_epochs_and_attest(:staker);

        let rewards_from_claim = system.delegator_claim_rewards(:delegator, :pool);
        // Rewards claimed up to but not including current epoch rewards.
        assert!(rewards_from_claim == pool_rewards_epoch);
        assert!(
            system
                .token
                .balance_of(account: delegator.reward.address) == delegator_rewards_after_exit
                + pool_rewards_epoch,
        );

        // Staker and delegator exit.

        system.staker_exit_intent(:staker);
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);

        system.advance_exit_wait_window();

        system.staker_exit_action(:staker);
        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: pool) == 0);
        assert!(
            system.token.balance_of(account: staker.staker.address) == initial_stake_amount * 2,
        );
        assert!(
            system.token.balance_of(account: delegator.delegator.address) == initial_stake_amount,
        );
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address),
        );
    }
}

/// Test
/// Test delegator exit pool and enter again.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Attest
/// Attest
/// Attest
/// Delagator exit intent
/// Upgrade to V3
/// Delegator exit action
/// Delegator delegate with the same address
/// Attest
/// Attest
/// Delegator claim rewards
/// Staker exit intent
/// Delegator exit intent
/// Staker exit action
/// Delegator exit action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorExitIntentUpgradeSwitchFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegated_amount: Option<Amount>,
    pub(crate) initial_reward_supplier_balance: Option<Amount>,
    pub(crate) initial_stake_amount: Option<Amount>,
}
pub(crate) impl DelegatorExitIntentUpgradeSwitchFlowImpl of MultiVersionFlowTrait<
    DelegatorExitIntentUpgradeSwitchFlow,
> {
    fn versions(self: DelegatorExitIntentUpgradeSwitchFlow) -> Span<ReleaseVersion> {
        [V1, V2].span()
    }

    fn setup(ref self: DelegatorExitIntentUpgradeSwitchFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let initial_stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: initial_stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: initial_stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: initial_stake_amount);
        let delegated_amount = initial_stake_amount / 2;
        system.delegate(:delegator, :pool, amount: delegated_amount);
        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_k_epochs_and_attest(:staker);
        system.advance_exit_wait_window();

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
        self.delegator = Option::Some(delegator);
        self.delegated_amount = Option::Some(delegated_amount);
        self.initial_reward_supplier_balance = Option::Some(initial_reward_supplier_balance);
        self.initial_stake_amount = Option::Some(initial_stake_amount);
    }

    fn test(
        self: DelegatorExitIntentUpgradeSwitchFlow,
        ref system: SystemState,
        version: ReleaseVersion,
    ) {
        let staker = self.staker.unwrap();
        let delegator = self.delegator.unwrap();
        let initial_stake_amount = self.initial_stake_amount.unwrap();
        let pool = system.staking.get_pool(:staker);
        let delegated_amount = self.delegated_amount.unwrap();
        let initial_reward_supplier_balance = self.initial_reward_supplier_balance.unwrap();
        let commission = 200;

        // Switch to new pool.
        let second_stake_amount = initial_stake_amount * 2;
        let staker2 = system.new_staker(amount: second_stake_amount);
        system.stake(staker: staker2, amount: second_stake_amount, pool_enabled: true, :commission);
        let pool2 = system.staking.get_pool(staker: staker2);
        system
            .switch_delegation_pool(
                :delegator,
                from_pool: pool,
                to_staker: staker2.staker.address,
                to_pool: pool2,
                amount: delegated_amount,
            );

        // Switch back to old pool.
        system.delegator_exit_intent(:delegator, pool: pool2, amount: delegated_amount);
        system.advance_exit_wait_window();
        system
            .switch_delegation_pool(
                :delegator,
                from_pool: pool2,
                to_staker: staker.staker.address,
                to_pool: pool,
                amount: delegated_amount,
            );

        // Staker and delegator exit.

        system.staker_exit_intent(:staker);
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);

        system.advance_exit_wait_window();

        system.staker_exit_action(:staker);
        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);

        assert!(system.token.balance_of(account: system.staking.address) == second_stake_amount);
        assert!(system.token.balance_of(account: pool) == 0);
        assert!(system.token.balance_of(account: pool2) == 0);
        assert!(
            system.token.balance_of(account: staker.staker.address) == initial_stake_amount * 2,
        );
        assert!(
            system.token.balance_of(account: delegator.delegator.address) == initial_stake_amount,
        );
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address),
        );
    }
}

/// Test disabled token delegation.
/// Flow:
/// Staker stake
/// Open 2 BTC pools
/// Delegators delegate
/// Disable 1 BTC token
/// Attest
/// Test pool rewards and balance
#[derive(Drop, Copy)]
pub(crate) struct DisabledTokenDelegationFlow {}
pub(crate) impl DisabledTokenDelegationFlowImpl of FlowTrait<DisabledTokenDelegationFlow> {
    fn test(self: DisabledTokenDelegationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let delegated_amount_8 = TEST_MIN_BTC_FOR_REWARDS;
        let delegated_amount_18 = BTC_18D_CONFIG.min_for_rewards;
        let staker = system.new_staker(:amount);
        let commission = 200;

        // Setup tokens.
        let token = system.btc_token;
        let token_address = token.contract_address();
        let second_token = system.deploy_second_btc_token();
        let second_token_address = second_token.contract_address();
        system.staking.add_token(token_address: second_token_address);
        system.staking.enable_token(token_address: second_token_address);

        // Stake.
        system.stake(:staker, :amount, pool_enabled: false, :commission);

        // Open pools.
        system.set_commission(:staker, :commission);
        let pool = system.set_open_for_delegation(:staker, :token_address);
        let second_pool = system
            .set_open_for_delegation(:staker, token_address: second_token_address);

        // Delegate.
        let delegator = system.new_btc_delegator(amount: delegated_amount_8, :token);
        let second_delegator = system
            .new_btc_delegator(amount: delegated_amount_18, token: second_token);
        system.delegate_btc(:delegator, :pool, amount: delegated_amount_8, :token);
        system
            .delegate_btc(
                delegator: second_delegator,
                pool: second_pool,
                amount: delegated_amount_18,
                token: second_token,
            );

        // Advance k epochs so that attesting will be possible and the delegation will take effect.
        system.advance_k_epochs();

        // Disable token and attest.
        system.staking.disable_token(:token_address);
        system.advance_block_into_attestation_window(:staker);
        system.attest(:staker);
        system.advance_epoch();

        // Test rewards in the epoch we disabled the token, should be the same.
        let rewards = system.delegator_claim_rewards(:delegator, :pool);
        let second_delegator_rewards = system
            .delegator_claim_rewards(delegator: second_delegator, pool: second_pool);
        assert!(rewards == second_delegator_rewards);

        // Attest again.
        system.advance_block_into_attestation_window(:staker);
        system.attest(:staker);
        system.advance_epoch();

        // Test rewards in the epoch after we disabled the token, should be the same.
        let rewards = system.delegator_claim_rewards(:delegator, :pool);
        let second_delegator_rewards = system
            .delegator_claim_rewards(delegator: second_delegator, pool: second_pool);
        assert!(rewards == second_delegator_rewards);

        // Attest again.
        system.advance_block_into_attestation_window(:staker);
        system.attest(:staker);
        system.advance_epoch();

        // Test rewards in 2 epochs after we disabled the token.
        let (_, expected_rewards) = calculate_staker_btc_pool_rewards_v2(
            pool_balance: delegated_amount_18,
            :commission,
            staking_contract: system.staking.address,
            minting_curve_contract: system.minting_curve.address,
            token_address: second_token.contract_address(),
        );
        let rewards = system.delegator_claim_rewards(:delegator, :pool);
        let second_delegator_rewards = system
            .delegator_claim_rewards(delegator: second_delegator, pool: second_pool);
        let pool_balance = system.token.balance_of(account: pool);
        assert!(rewards == 0);
        assert!(second_delegator_rewards == expected_rewards);
        assert!(pool_balance == 0);
    }
}

/// Test delegator exit pool and enter again with switch.
/// Flow:
/// Staker1 stake with pool1
/// Staker2 stake with pool2
/// Staker1 attest
/// Delegator delegate pool1
/// Staker1 attest
/// Staker1 attest
/// Staker1 attest
/// Delagator exit intent pool1
/// Delegator full switch to pool2
/// Delegator claim rewards pool1
/// Delegator exit intent pool2
/// Delegator full switch to pool1
/// Staker1 attest
/// Staker1 attest
/// Delegator claim rewards pool1
/// Staker1 exit intent
/// Delegator exit intent pool1
/// Staker1 exit action
/// Delegator exit action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorExitAndEnterAgainWithSwitchFlow {}
pub(crate) impl DelegatorExitAndEnterAgainWithSwitchFlowImpl of FlowTrait<
    DelegatorExitAndEnterAgainWithSwitchFlow,
> {
    fn test(self: DelegatorExitAndEnterAgainWithSwitchFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let initial_stake_amount = min_stake * 2;
        let staker1 = system.new_staker(amount: initial_stake_amount * 2);
        let staker2 = system.new_staker(amount: initial_stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        system
            .stake(staker: staker1, amount: initial_stake_amount, pool_enabled: true, :commission);
        system
            .stake(staker: staker2, amount: initial_stake_amount, pool_enabled: true, :commission);
        let pool1 = system.staking.get_pool(staker: staker1);
        let pool2 = system.staking.get_pool(staker: staker2);

        system.advance_k_epochs_and_attest(staker: staker1);

        let delegator = system.new_delegator(amount: initial_stake_amount);
        let delegated_amount = initial_stake_amount / 2;
        system.delegate(:delegator, pool: pool1, amount: delegated_amount);
        system.advance_k_epochs_and_attest(staker: staker1);
        // Calculate pool rewards.
        let pool_rewards_epoch = calculate_strk_pool_rewards_v2(
            staker_address: staker1.staker.address, :staking_contract, :minting_curve_contract,
        );
        system.advance_k_epochs_and_attest(staker: staker1);
        system.advance_k_epochs_and_attest(staker: staker1);

        system.delegator_exit_intent(:delegator, pool: pool1, amount: delegated_amount);

        system.advance_k_epochs_and_attest(staker: staker1);

        system
            .switch_delegation_pool(
                :delegator,
                from_pool: pool1,
                to_staker: staker2.staker.address,
                to_pool: pool2,
                amount: delegated_amount,
            );

        let rewards = system.delegator_claim_rewards(:delegator, pool: pool1);

        let delegator_rewards_after_exit = system
            .token
            .balance_of(account: delegator.reward.address);

        assert!(rewards == pool_rewards_epoch * 3);
        assert!(delegator_rewards_after_exit == pool_rewards_epoch * 3);

        // Switch back.
        system.delegator_exit_intent(:delegator, pool: pool2, amount: delegated_amount);

        system
            .switch_delegation_pool(
                :delegator,
                from_pool: pool2,
                to_staker: staker1.staker.address,
                to_pool: pool1,
                amount: delegated_amount,
            );

        system.advance_k_epochs_and_attest(staker: staker1);

        system.advance_k_epochs_and_attest(staker: staker1);

        let rewards_from_claim = system.delegator_claim_rewards(:delegator, pool: pool1);
        // Rewards claimed up to but not including current epoch rewards.
        assert!(rewards_from_claim == pool_rewards_epoch);
        assert!(
            system
                .token
                .balance_of(account: delegator.reward.address) == delegator_rewards_after_exit
                + pool_rewards_epoch,
        );

        // Staker 1 and delegator exit.

        system.staker_exit_intent(staker: staker1);
        system.delegator_exit_intent(:delegator, pool: pool1, amount: delegated_amount);

        system.advance_exit_wait_window();

        system.staker_exit_action(staker: staker1);
        system.delegator_exit_action(:delegator, pool: pool1);
        system.delegator_claim_rewards(:delegator, pool: pool1);
        system.delegator_claim_rewards(:delegator, pool: pool2);

        assert!(system.token.balance_of(account: pool1) == 0);
        assert!(
            system.token.balance_of(account: staker1.staker.address) == initial_stake_amount * 2,
        );
        assert!(
            system.token.balance_of(account: delegator.delegator.address) == initial_stake_amount,
        );
        assert!(system.token.balance_of(account: staker1.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker1.reward.address)
                + system.token.balance_of(account: delegator.reward.address),
        );
    }
}

/// Test new token delegation
/// Flow:
/// Staker stake
/// Add new btc token
/// Staker open delegation pool for new token
/// Delegator delegate
/// Test staking power (zero)
/// Advance epoch
/// Test staking power (still zero)
/// Advance epoch
/// Test staking power
#[derive(Drop, Copy)]
pub(crate) struct NewTokenDelegationFlow {}
pub(crate) impl NewTokenDelegationFlowImpl of FlowTrait<NewTokenDelegationFlow> {
    fn test(self: NewTokenDelegationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        let delegated_amount = BTC_18D_CONFIG.min_for_rewards;

        // Stake and set commission.
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);

        // Deploy, add, and enable token.
        let token = system.deploy_second_btc_token();
        let token_address = token.contract_address();
        system.staking.add_token(:token_address);
        system.staking.enable_token(:token_address);

        // Set open for delegation and delegate.
        let pool = system.set_open_for_delegation(:staker, :token_address);
        let delegator = system.new_btc_delegator(amount: delegated_amount, :token);
        system.delegate_btc(:delegator, :pool, amount: delegated_amount, :token);

        // Test total staking power.
        let total_staking_power = system.staking.get_current_total_staking_power_v2();
        assert!(total_staking_power == (Zero::zero(), Zero::zero()));

        system.advance_epoch();
        // Test total staking power.
        let total_staking_power = system.staking.get_current_total_staking_power_v2();
        assert!(total_staking_power == (Zero::zero(), Zero::zero()));

        system.advance_epoch();
        // Test new token staking power.
        let new_token_staking_power = system
            .staking
            .dispatcher()
            .get_total_stake_for_token(:token_address);
        assert!(new_token_staking_power == delegated_amount);

        // Test total staking power after epoch.
        let total_staking_power = system.staking.get_current_total_staking_power_v2();
        let expected_btc_staking_power = to_amount_18_decimals(
            amount: delegated_amount, :token_address,
        );
        assert!(
            total_staking_power == (
                NormalizedAmountTrait::from_strk_native_amount(amount),
                NormalizedAmountTrait::from_amount_18_decimals(expected_btc_staking_power),
            ),
        );
    }
}

/// Flow:
/// Staker stake
/// Staker open 2 BTC pools (one with 8 decimals, one with 18 decimals)
/// Delegators delegate
/// Attest
/// Test rewards are not equal
/// Test total staking power
#[derive(Drop, Copy)]
pub(crate) struct MultipleBTCPoolsDifferentDecimalsFlow {}
pub(crate) impl MultipleBTCPoolsDifferentDecimalsFlowImpl of FlowTrait<
    MultipleBTCPoolsDifferentDecimalsFlow,
> {
    fn test(self: MultipleBTCPoolsDifferentDecimalsFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        let delegated_amount_8 = 10_u128.pow(BTC_DECIMALS_8.into()); // One BTC
        let delegated_amount_18 = 10_u128.pow(BTC_DECIMALS_18.into()); // One BTC

        // Stake and set commission.
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);

        // Setups tokens.
        let token_8 = system.deploy_new_btc_token(name: "BTC_TOKEN_8", decimals: BTC_DECIMALS_8);
        let token_18 = system.deploy_new_btc_token(name: "BTC_TOKEN_18", decimals: BTC_DECIMALS_18);
        let token_8_address = token_8.contract_address();
        let token_18_address = token_18.contract_address();
        system.staking.add_token(token_address: token_8_address);
        system.staking.add_token(token_address: token_18_address);
        system.staking.enable_token(token_address: token_8_address);
        system.staking.enable_token(token_address: token_18_address);

        // Set open for delegation.
        let pool_8 = system.set_open_for_delegation(:staker, token_address: token_8_address);
        let pool_18 = system.set_open_for_delegation(:staker, token_address: token_18_address);

        // Delegators delegate.
        let delegator_8 = system.new_btc_delegator(amount: delegated_amount_8, token: token_8);
        let delegator_18 = system.new_btc_delegator(amount: delegated_amount_18, token: token_18);
        system
            .delegate_btc(
                delegator: delegator_8, pool: pool_8, amount: delegated_amount_8, token: token_8,
            );
        system
            .delegate_btc(
                delegator: delegator_18,
                pool: pool_18,
                amount: delegated_amount_18,
                token: token_18,
            );

        // Attest.
        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        // Test rewards are not equal.
        let rewards_8 = system.delegator_claim_rewards(delegator: delegator_8, pool: pool_8);
        let rewards_18 = system.delegator_claim_rewards(delegator: delegator_18, pool: pool_18);
        let (_, btc_staking_power) = system.staking.get_current_total_staking_power_v2();
        assert!(rewards_8 == rewards_18);
        let expected_btc_staking_power = NormalizedAmountTrait::from_native_amount(
            amount: delegated_amount_8, decimals: BTC_DECIMALS_8,
        )
            + NormalizedAmountTrait::from_native_amount(
                amount: delegated_amount_18, decimals: BTC_DECIMALS_18,
            );
        assert!(btc_staking_power == expected_btc_staking_power);
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Delegator full exit_intent
/// Upgrade
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorActionAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) exit_wait_window: Option<TimeDelta>,
}
pub(crate) impl DelegatorActionAfterUpgradeFlowImpl of FlowTrait<DelegatorActionAfterUpgradeFlow> {
    fn setup(ref self: DelegatorActionAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.exit_wait_window = Option::Some(system.staking.get_exit_wait_window());
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: DelegatorActionAfterUpgradeFlow, ref system: SystemState) {
        let pool = self.pool_address.unwrap();
        let delegator = self.delegator.unwrap();

        let result = system.safe_delegator_exit_action(:delegator, :pool);
        assert_panic_with_error(
            :result, expected_error: GenericError::INTENT_WINDOW_NOT_FINISHED.describe(),
        );

        let exit_wait_window = self.exit_wait_window.unwrap();
        system.advance_time(time: exit_wait_window);
        system.delegator_exit_action(:delegator, :pool);
        system.delegator_claim_rewards(:delegator, :pool);

        let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
        assert!(pool_member_info.amount.is_zero());
        assert!(pool_member_info.unclaimed_rewards.is_zero());
        assert!(pool_member_info.unpool_amount.is_zero());
        assert!(pool_member_info.unpool_time.is_none());
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// Delegator exit_intent
#[derive(Drop, Copy)]
pub(crate) struct DelegatorIntentAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegated_amount: Option<Amount>,
}
pub(crate) impl DelegatorIntentAfterUpgradeFlowImpl of FlowTrait<DelegatorIntentAfterUpgradeFlow> {
    fn setup(ref self: DelegatorIntentAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let delegator = system.new_delegator(amount: stake_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: stake_amount);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegated_amount = Option::Some(stake_amount);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: DelegatorIntentAfterUpgradeFlow, ref system: SystemState) {
        let delegator = self.delegator.unwrap();
        let pool = self.pool_address.unwrap();
        let delegated_amount = self.delegated_amount.unwrap();
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);

        let delegator_info = system.pool_member_info_v1(:delegator, :pool);
        assert!(delegator_info.unpool_amount == delegated_amount);
        assert!(delegator_info.amount.is_zero());
        assert!(delegator_info.unpool_time.is_some());
    }
}

/// Flow:
/// Staker stake with pool
/// Upgrade
/// Staker exit_intent
#[derive(Drop, Copy)]
pub(crate) struct StakerIntentAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl StakerIntentAfterUpgradeFlowImpl of FlowTrait<StakerIntentAfterUpgradeFlow> {
    fn setup(ref self: StakerIntentAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        self.staker = Option::Some(staker);
        let pool = system.staking.get_pool(:staker);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: StakerIntentAfterUpgradeFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        system.staker_exit_intent(:staker);

        let staker_info = system.staker_info_v1(:staker);
        assert!(staker_info.unstake_time.is_some());
    }
}

/// Flow:
/// Staker stake with pool
/// Staker exit_intent
/// Upgrade
/// Staker exit_action
#[derive(Drop, Copy)]
pub(crate) struct StakerActionAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) exit_wait_window: Option<TimeDelta>,
}

pub(crate) impl StakerActionAfterUpgradeFlowImpl of FlowTrait<StakerActionAfterUpgradeFlow> {
    fn setup(ref self: StakerActionAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.staker_exit_intent(:staker);

        self.staker = Option::Some(staker);
        let pool = system.staking.get_pool(:staker);
        self.exit_wait_window = Option::Some(system.staking.get_exit_wait_window());
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: StakerActionAfterUpgradeFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let staker_info = system.staker_info_v1(:staker);
        assert!(staker_info.unstake_time.is_some());

        let result = system.safe_staker_exit_action(:staker);
        assert_panic_with_error(
            :result, expected_error: GenericError::INTENT_WINDOW_NOT_FINISHED.describe(),
        );

        let exit_wait_window = self.exit_wait_window.unwrap();
        system.advance_time(time: exit_wait_window);
        system.staker_exit_action(:staker);

        assert!(system.get_staker_info(:staker).is_none());
    }
}

/// Flow:
/// Staker stake
/// Staker exit_intent
/// Upgrade
/// Staker attest
#[derive(Drop, Copy)]
pub(crate) struct StakerAttestAfterIntentFlow {
    pub(crate) staker: Option<Staker>,
}

pub(crate) impl StakerAttestAfterIntentFlowImpl of FlowTrait<StakerAttestAfterIntentFlow> {
    fn setup(ref self: StakerAttestAfterIntentFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);

        system.stake(:staker, amount: stake_amount, pool_enabled: false, commission: 200);
        system.staker_exit_intent(:staker);

        self.staker = Option::Some(staker);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: StakerAttestAfterIntentFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();

        system.advance_k_epochs_and_attest(:staker);
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// Delegator partial undelegate
/// Delegator switch
#[derive(Drop, Copy)]
pub(crate) struct DelegatorPartialIntentAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegated_amount: Option<Amount>,
}
pub(crate) impl DelegatorPartialIntentAfterUpgradeFlowImpl of FlowTrait<
    DelegatorPartialIntentAfterUpgradeFlow,
> {
    fn setup(ref self: DelegatorPartialIntentAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let delegated_amount = stake_amount;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegated_amount = Option::Some(delegated_amount);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: DelegatorPartialIntentAfterUpgradeFlow, ref system: SystemState) {
        let delegator = self.delegator.unwrap();
        let pool = self.pool_address.unwrap();
        let delegated_amount = self.delegated_amount.unwrap();
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 2);

        let commission = 200;
        let second_staker = system.new_staker(amount: delegated_amount);
        system
            .stake(
                staker: second_staker, amount: delegated_amount, pool_enabled: true, :commission,
            );
        let second_pool = system.staking.get_pool(staker: second_staker);
        system
            .switch_delegation_pool(
                :delegator,
                from_pool: pool,
                to_staker: second_staker.staker.address,
                to_pool: second_pool,
                amount: delegated_amount / 2,
            );

        let delegator_info_first_pool = system.pool_member_info_v1(:delegator, :pool);
        assert!(delegator_info_first_pool.amount == delegated_amount / 2);
        let delegator_info_second_pool = system.pool_member_info_v1(:delegator, pool: second_pool);
        assert!(delegator_info_second_pool.amount == delegated_amount / 2);
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// Change commission
#[derive(Drop, Copy)]
pub(crate) struct ChangeCommissionAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) commission: Option<Commission>,
}
pub(crate) impl ChangeCommissionAfterUpgradeFlowImpl of FlowTrait<
    ChangeCommissionAfterUpgradeFlow,
> {
    fn setup(ref self: ChangeCommissionAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        self.staker = Option::Some(staker);
        self.pool_address = Option::Some(pool);
        self.commission = Option::Some(commission);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: ChangeCommissionAfterUpgradeFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let pool = self.pool_address.unwrap();
        let new_commission = self.commission.unwrap() - 1;
        system.set_commission(:staker, commission: new_commission);

        assert!(new_commission == system.contract_parameters_v1(:pool).commission);
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// Delegator claim rewards
#[derive(Drop, Copy)]
pub(crate) struct DelegatorClaimRewardsAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
}
pub(crate) impl DelegatorClaimRewardsAfterUpgradeFlowImpl of FlowTrait<
    DelegatorClaimRewardsAfterUpgradeFlow,
> {
    fn setup(ref self: DelegatorClaimRewardsAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);

        system.advance_time(time: one_week);
        system.staking.update_global_index_if_needed();
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: DelegatorClaimRewardsAfterUpgradeFlow, ref system: SystemState) {
        let pool = self.pool_address.unwrap();
        let delegator = self.delegator.unwrap();

        let unclaimed_rewards = system.pool_member_info_v1(:delegator, :pool).unclaimed_rewards;
        assert!(unclaimed_rewards == system.delegator_claim_rewards(:delegator, :pool));
        assert!(unclaimed_rewards == system.token.balance_of(account: delegator.reward.address));

        let unclaimed_rewards_after_claim = system
            .pool_member_info_v1(:delegator, :pool)
            .unclaimed_rewards;
        assert!(unclaimed_rewards_after_claim == Zero::zero());
    }
}

/// Flow
/// Disable btc token
/// Test btc token is not disabled
/// Advance epoch
/// Test btc token is disabled
#[derive(Drop, Copy)]
pub(crate) struct DisableBtcTokenSameAndNextEpochFlow {}
pub(crate) impl DisableBtcTokenSameAndNextEpochFlowImpl of FlowTrait<
    DisableBtcTokenSameAndNextEpochFlow,
> {
    fn test(self: DisableBtcTokenSameAndNextEpochFlow, ref system: SystemState) {
        system.advance_k_epochs();
        let expected_active_tokens = system.staking.dispatcher().get_active_tokens();
        let token_address = system.deploy_second_btc_token().contract_address();
        let strk_token_address = system.token.contract_address();
        let btc_token_address = system.btc_token.contract_address();

        let expected_tokens_false = array![
            (strk_token_address, true), (btc_token_address, true), (token_address, false),
        ]
            .span();
        let expected_tokens_true = array![
            (strk_token_address, true), (btc_token_address, true), (token_address, true),
        ]
            .span();

        system.staking.add_token(:token_address);
        let tokens = system.staking.dispatcher().get_tokens();
        assert!(tokens == expected_tokens_false);

        system.staking.enable_token(:token_address);
        let tokens = system.staking.dispatcher().get_tokens();
        assert!(tokens == expected_tokens_false);
        system.advance_epoch();
        let tokens = system.staking.dispatcher().get_tokens();
        assert!(tokens == expected_tokens_false);
        system.advance_epoch();
        let tokens = system.staking.dispatcher().get_tokens();
        assert!(tokens == expected_tokens_true);

        system.staking.disable_token(:token_address);
        let tokens = system.staking.dispatcher().get_tokens();
        assert!(tokens == expected_tokens_true);
        system.advance_epoch();
        let tokens = system.staking.dispatcher().get_tokens();
        assert!(tokens == expected_tokens_true);
        system.advance_epoch();
        let active_tokens = system.staking.dispatcher().get_active_tokens();
        let tokens = system.staking.dispatcher().get_tokens();
        assert!(active_tokens == expected_active_tokens);
        assert!(tokens == expected_tokens_false);

        system.advance_epoch();
        let active_tokens = system.staking.dispatcher().get_active_tokens();
        let tokens = system.staking.dispatcher().get_tokens();
        assert!(active_tokens == expected_active_tokens);
        assert!(tokens == expected_tokens_false);
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Delegator full intent
/// Upgrade
/// Delegator full switch
#[derive(Drop, Copy)]
pub(crate) struct DelegatorSwitchAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegated_amount: Option<Amount>,
}
pub(crate) impl DelegatorSwitchAfterUpgradeFlowImpl of FlowTrait<DelegatorSwitchAfterUpgradeFlow> {
    fn setup(ref self: DelegatorSwitchAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegated_amount = Option::Some(delegated_amount);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: DelegatorSwitchAfterUpgradeFlow, ref system: SystemState) {
        let delegator = self.delegator.unwrap();
        let pool = self.pool_address.unwrap();
        let delegated_amount = self.delegated_amount.unwrap();

        let commission = 200;
        let second_staker = system.new_staker(amount: delegated_amount);
        system
            .stake(
                staker: second_staker, amount: delegated_amount, pool_enabled: true, :commission,
            );
        let second_pool = system.staking.get_pool(staker: second_staker);
        system
            .switch_delegation_pool(
                :delegator,
                from_pool: pool,
                to_staker: second_staker.staker.address,
                to_pool: second_pool,
                amount: delegated_amount,
            );

        // Although the delegator has switched their entire delegated amount to the second pool,
        // they remain a member of the original pool. Keeping the delegator in the pool ensures they
        // can still receive any additional rewards that they may get for the current epoch.
        let delegator_info_first_pool = system.pool_member_info_v1(:delegator, :pool);
        assert!(delegator_info_first_pool.amount.is_zero());

        let delegator_info_second_pool = system.pool_member_info_v1(:delegator, pool: second_pool);
        assert!(delegator_info_second_pool.amount == delegated_amount);
    }
}

/// Test `staker_migration`.
/// Flow:
/// Stake with pool in V2.
/// Upgrade to V3.
/// Test pool contract has been upgraded to V3.
#[derive(Drop, Copy)]
pub(crate) struct StakerMigrationFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl StakerMigrationFlowImpl of FlowTrait<StakerMigrationFlow> {
    fn setup_v2(ref self: StakerMigrationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let delegator = system.new_delegator(:amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, :amount);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.pool_address = Option::Some(pool);
        self.staker = Option::Some(staker);
    }

    fn test(self: StakerMigrationFlow, ref system: SystemState) {
        let pool_address = self.pool_address.unwrap();
        let staker = self.staker.unwrap();
        let pool_class_hash = get_class_hash(contract_address: pool_address);
        let expected_pool_class_hash = declare_pool_contract();
        assert!(pool_class_hash == expected_pool_class_hash);

        let min_delegation_for_rewards: Amount = load_one_felt(
            target: pool_address, storage_address: selector!("min_delegation_for_rewards"),
        )
            .try_into()
            .unwrap();
        assert!(min_delegation_for_rewards == STRK_CONFIG.min_for_rewards);
        let staking_rewards_base_value: Amount = load_one_felt(
            target: pool_address, storage_address: selector!("staking_rewards_base_value"),
        )
            .try_into()
            .unwrap();
        assert!(staking_rewards_base_value == STRK_CONFIG.base_value);
        assert!(system.is_staker_up_to_date(:staker));
    }
}

/// Test `staker_migration` with multiple pools.
/// Flow:
/// Open STRK pool and 2 BTC pools in V2.
/// Upgrade to V3.
/// Test pool contracts have been upgraded to V3.
#[derive(Drop, Copy)]
pub(crate) struct StakerMigrationMultiplePoolsFlow {
    pub(crate) pool_addresses: Option<Span<ContractAddress>>,
    pub(crate) staker_pool_info: Option<StakerPoolInfoV2>,
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl StakerMigrationMultiplePoolsFlowImpl of FlowTrait<
    StakerMigrationMultiplePoolsFlow,
> {
    fn setup_v2(ref self: StakerMigrationMultiplePoolsFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let strk_pool = system.staking.get_pool(:staker);
        let btc_8d_token = system
            .deploy_new_btc_token(name: "BTC_8D_TOKEN", decimals: BTC_DECIMALS_8);
        let btc_18d_token = system
            .deploy_new_btc_token(name: "BTC_18D_TOKEN", decimals: BTC_DECIMALS_18);
        system.staking.add_token(token_address: btc_8d_token.contract_address());
        system.staking.add_token(token_address: btc_18d_token.contract_address());
        let btc_8d_pool = system
            .set_open_for_delegation(:staker, token_address: btc_8d_token.contract_address());
        let btc_18d_pool = system
            .set_open_for_delegation(:staker, token_address: btc_18d_token.contract_address());

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.pool_addresses = Option::Some([strk_pool, btc_8d_pool, btc_18d_pool].span());
        self.staker_pool_info = Option::Some(system.staker_pool_info(:staker));
        self.staker = Option::Some(staker);
    }

    fn test(self: StakerMigrationMultiplePoolsFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        assert!(system.staker_pool_info(:staker) == self.staker_pool_info.unwrap());
        let expected_class_hash = declare_pool_contract();
        for pool_address in self.pool_addresses.unwrap() {
            assert!(get_class_hash(contract_address: *pool_address) == expected_class_hash);
        }
        system.is_staker_up_to_date(:staker);
    }
}

/// Test `staker_migration` with multiple versions.
/// Flow:
/// Stake with pool in V0.
/// Upgrade to V1.
/// Stake with pool in V1.
/// Upgrade to V2.
/// Stake with pool in V2.
/// Upgrade to V3.
/// Test pool contracts have been upgraded to V3.
#[derive(Drop, Copy)]
pub(crate) struct StakerMigrationMultipleVersionsFlow {
    pub(crate) stakers: Option<Span<Staker>>,
}
pub(crate) impl StakerMigrationMultipleVersionsFlowImpl of FlowTrait<
    StakerMigrationMultipleVersionsFlow,
> {
    fn setup(ref self: StakerMigrationMultipleVersionsFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool_address = system.staking.get_pool(:staker);

        system.set_pool_for_upgrade(:pool_address);
        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.stakers = Option::Some([staker].span());
    }

    fn setup_v1(ref self: StakerMigrationMultipleVersionsFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        let mut stakers: Array<Staker> = self.stakers.unwrap().into();
        stakers.append(staker);
        self.stakers = Option::Some(stakers.span());
    }

    fn setup_v2(ref self: StakerMigrationMultipleVersionsFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        let stakers = self.stakers.unwrap();
        for staker in stakers {
            let pool = system.staker_pool_info(staker: *staker).pools[0].pool_contract;
            assert!(get_class_hash(*pool) == MAINNET_POOL_CLASS_HASH_V1());
        }

        system.set_staker_for_migration(staker_address: staker.staker.address);
        let mut stakers: Array<Staker> = stakers.into();
        stakers.append(staker);
        self.stakers = Option::Some(stakers.span());
    }

    fn test(self: StakerMigrationMultipleVersionsFlow, ref system: SystemState) {
        let stakers = self.stakers.unwrap();
        for staker in stakers {
            let pools = system.staker_pool_info(staker: *staker).pools;
            assert!(pools.len() == 1);
            let expected_class_hash = declare_pool_contract();
            assert!(
                get_class_hash(contract_address: *pools[0].pool_contract) == expected_class_hash,
            );
            system.is_staker_up_to_date(staker: *staker);
        }
    }
}

/// Test multi pool exit intent.
/// Flow:
/// Staker stake with pool
/// Staker open 2 BTC pools
/// Delegators delegate to both pools
/// Staker attest
/// Staker exit intent
/// Test total_stake
/// Staker exit action
/// Test delegations and rewards transferred to pools
#[derive(Drop, Copy)]
pub(crate) struct MultiPoolExitIntentFlow {}
pub(crate) impl MultiPoolExitIntentFlowImpl of FlowTrait<MultiPoolExitIntentFlow> {
    fn test(self: MultiPoolExitIntentFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let strk_delegator_amount = amount * 2;
        let first_btc_amount = TEST_MIN_BTC_FOR_REWARDS * 3;
        let second_btc_amount = BTC_18D_CONFIG.min_for_rewards * 4;
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        // Setup tokens and pools.
        let strk_token = system.token;
        let first_btc_token = system.btc_token;
        let second_btc_token = system.deploy_second_btc_token();
        system.staking.add_token(token_address: second_btc_token.contract_address());
        system.staking.enable_token(token_address: second_btc_token.contract_address());
        let strk_pool = system.staking.get_pool(:staker);
        let first_btc_pool = system
            .set_open_for_delegation(:staker, token_address: first_btc_token.contract_address());
        let second_btc_pool = system
            .set_open_for_delegation(:staker, token_address: second_btc_token.contract_address());

        // Setup delegations.
        let strk_delegator = system.new_delegator(amount: strk_delegator_amount);
        let first_btc_delegator = system
            .new_btc_delegator(amount: first_btc_amount, token: first_btc_token);
        let second_btc_delegator = system
            .new_btc_delegator(amount: second_btc_amount, token: second_btc_token);
        system.delegate(delegator: strk_delegator, pool: strk_pool, amount: strk_delegator_amount);
        system
            .delegate_btc(
                delegator: first_btc_delegator,
                pool: first_btc_pool,
                amount: first_btc_amount,
                token: first_btc_token,
            );
        system
            .delegate_btc(
                delegator: second_btc_delegator,
                pool: second_btc_pool,
                amount: second_btc_amount,
                token: second_btc_token,
            );

        // Attest.
        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        // Exit intent.
        system.staker_exit_intent(:staker);

        // Test total_stake.
        let strk_total_stake = system
            .staking
            .dispatcher()
            .get_total_stake_for_token(token_address: strk_token.contract_address());
        let first_btc_total_stake = system
            .staking
            .dispatcher()
            .get_total_stake_for_token(token_address: first_btc_token.contract_address());
        let second_btc_total_stake = system
            .staking
            .dispatcher()
            .get_total_stake_for_token(token_address: second_btc_token.contract_address());
        assert!(strk_total_stake == 0);
        assert!(first_btc_total_stake == 0);
        assert!(second_btc_total_stake == 0);

        // Exit action.
        system.advance_exit_wait_window();
        system.staker_exit_action(:staker);

        // Test delegations and rewards.
        let strk_pool_balance = strk_token.balance_of(account: strk_pool);
        let first_btc_pool_strk_balance = strk_token.balance_of(account: first_btc_pool);
        let second_btc_pool_strk_balance = strk_token.balance_of(account: second_btc_pool);
        let first_btc_pool_btc_balance = first_btc_token.balance_of(account: first_btc_pool);
        let second_btc_pool_btc_balance = second_btc_token.balance_of(account: second_btc_pool);
        assert!(strk_pool_balance > strk_delegator_amount);
        assert!(first_btc_pool_btc_balance == first_btc_amount);
        assert!(second_btc_pool_btc_balance == second_btc_amount);
        assert!(first_btc_pool_strk_balance > 0);
        assert!(second_btc_pool_strk_balance > first_btc_pool_strk_balance);
    }
}

/// Flow:
/// Staker stake with pool
/// 3 delegators delegate
/// Delegator full intent
/// Delegator half intent
/// Delegator zero intent
/// Upgrade
/// Staker migration
/// Staker2 stake with pool
/// Delegators switch
/// Test staker_pool_infos
/// Test delegators infos
#[derive(Drop, Copy)]
pub(crate) struct IntentDelegatorUpgradeSwitchFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator_full_intent: Option<Delegator>,
    pub(crate) delegator_half_intent: Option<Delegator>,
    pub(crate) delegator_zero_intent: Option<Delegator>,
    pub(crate) amount: Option<Amount>,
    pub(crate) commission: Option<Commission>,
}
pub(crate) impl IntentDelegatorUpgradeSwitchFlowImpl of MultiVersionFlowTrait<
    IntentDelegatorUpgradeSwitchFlow,
> {
    fn versions(self: IntentDelegatorUpgradeSwitchFlow) -> Span<ReleaseVersion> {
        [V0, V1, V2].span()
    }

    fn setup(ref self: IntentDelegatorUpgradeSwitchFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let delegator_full_intent = system.new_delegator(:amount);
        let delegator_half_intent = system.new_delegator(:amount);
        let delegator_zero_intent = system.new_delegator(:amount);

        system.delegate(delegator: delegator_full_intent, :pool, :amount);
        system.delegate(delegator: delegator_half_intent, :pool, :amount);
        system.delegate(delegator: delegator_zero_intent, :pool, :amount);

        system.delegator_exit_intent(delegator: delegator_full_intent, :pool, :amount);
        system.delegator_exit_intent(delegator: delegator_half_intent, :pool, amount: amount / 2);
        system.delegator_exit_intent(delegator: delegator_zero_intent, :pool, amount: Zero::zero());

        system.advance_exit_wait_window();

        system.set_staker_for_migration(staker_address: staker.staker.address);
        system.set_pool_for_upgrade(pool_address: pool);
        self.staker = Option::Some(staker);
        self.pool_address = Option::Some(pool);
        self.delegator_full_intent = Option::Some(delegator_full_intent);
        self.delegator_half_intent = Option::Some(delegator_half_intent);
        self.delegator_zero_intent = Option::Some(delegator_zero_intent);
        self.amount = Option::Some(amount);
        self.commission = Option::Some(commission);
    }

    fn test(
        self: IntentDelegatorUpgradeSwitchFlow, ref system: SystemState, version: ReleaseVersion,
    ) {
        let staker = self.staker.unwrap();
        let pool = self.pool_address.unwrap();
        let delegator_full_intent = self.delegator_full_intent.unwrap();
        let delegator_half_intent = self.delegator_half_intent.unwrap();
        let delegator_zero_intent = self.delegator_zero_intent.unwrap();
        let amount = self.amount.unwrap();
        let commission = self.commission.unwrap();

        // Staker2 stake with pool.
        let staker2 = system.new_staker(:amount);
        system.stake(staker: staker2, :amount, pool_enabled: true, :commission);
        let pool2 = system.staking.get_pool(staker: staker2);

        // Delegators switch.
        system
            .switch_delegation_pool(
                delegator: delegator_full_intent,
                from_pool: pool,
                to_staker: staker2.staker.address,
                to_pool: pool2,
                :amount,
            );
        system
            .switch_delegation_pool(
                delegator: delegator_half_intent,
                from_pool: pool,
                to_staker: staker2.staker.address,
                to_pool: pool2,
                amount: amount / 2,
            );
        let res = system
            .safe_switch_delegation_pool(
                delegator: delegator_zero_intent,
                from_pool: pool,
                to_staker: staker2.staker.address,
                to_pool: pool2,
                amount: Zero::zero(),
            );
        assert_panic_with_error(res, GenericError::AMOUNT_IS_ZERO.describe());

        // Test pools.
        let first_staker_expected_pool_info = StakerPoolInfoV2 {
            commission: Option::Some(commission),
            pools: array![
                PoolInfo {
                    pool_contract: pool,
                    amount: amount * 3 / 2,
                    token_address: system.staking.get_token_address(),
                },
            ]
                .span(),
        };
        let second_staker_expected_pool_info = StakerPoolInfoV2 {
            commission: Option::Some(commission),
            pools: array![
                PoolInfo {
                    pool_contract: pool2,
                    amount: amount * 3 / 2,
                    token_address: system.staking.get_token_address(),
                },
            ]
                .span(),
        };
        let first_staker_pool_info = system.staker_pool_info(:staker);
        let second_staker_pool_info = system.staker_pool_info(staker: staker2);
        assert!(first_staker_pool_info == first_staker_expected_pool_info);
        assert!(second_staker_pool_info == second_staker_expected_pool_info);

        // Test delegators infos.
        let delegator_full_intent_info_1 = system
            .pool_member_info_v1(delegator: delegator_full_intent, :pool);
        let delegator_half_intent_info_1 = system
            .pool_member_info_v1(delegator: delegator_half_intent, :pool);
        let delegator_zero_intent_info_1 = system
            .pool_member_info_v1(delegator: delegator_zero_intent, :pool);
        let delegator_full_intent_info_2 = system
            .pool_member_info_v1(delegator: delegator_full_intent, pool: pool2);
        let delegator_half_intent_info_2 = system
            .pool_member_info_v1(delegator: delegator_half_intent, pool: pool2);
        assert!(delegator_full_intent_info_1.amount == Zero::zero());
        assert!(delegator_half_intent_info_1.amount == amount / 2);
        assert!(delegator_zero_intent_info_1.amount == amount);
        assert!(delegator_full_intent_info_2.amount == amount);
        assert!(delegator_half_intent_info_2.amount == amount / 2);
    }
}

/// Flow:
/// Staker stake without pool
/// Upgrade
/// Staker migration
/// Test staker_pool_info did not change
/// Test staker_info did not change
#[derive(Drop, Copy)]
pub(crate) struct StakerWithoutPoolMigrationFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfoV1>,
    pub(crate) staker_pool_info: Option<StakerPoolInfoV2>,
}
pub(crate) impl StakerWithoutPoolMigrationFlowImpl of FlowTrait<StakerWithoutPoolMigrationFlow> {
    fn setup_v2(ref self: StakerWithoutPoolMigrationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(system.staker_info_v1(:staker));
        self.staker_pool_info = Option::Some(system.staker_pool_info(:staker));
    }

    fn test(self: StakerWithoutPoolMigrationFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();

        // Test staker_pool_info did not change.
        let staker_pool_info = system.staker_pool_info(:staker);
        assert!(staker_pool_info == self.staker_pool_info.unwrap());

        // Test staker_info did not change.
        let staker_info = system.staker_info_v1(:staker);
        assert!(staker_info == self.staker_info.unwrap());
    }
}

/// Flow:
/// Staker stake with pool
/// 3 delegators delegate
/// Delegator full intent
/// Delegator half intent
/// Delegator zero intent
/// Upgrade
/// Staker migration
/// Delegators exit action
/// Test staker_pool_info
/// Test delegators infos
/// Test delegators balances
#[derive(Drop, Copy)]
pub(crate) struct IntentDelegatorUpgradeActionFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator_full_intent: Option<Delegator>,
    pub(crate) delegator_half_intent: Option<Delegator>,
    pub(crate) delegator_zero_intent: Option<Delegator>,
    pub(crate) amount: Option<Amount>,
    pub(crate) commission: Option<Commission>,
}
pub(crate) impl IntentDelegatorUpgradeActionFlowImpl of MultiVersionFlowTrait<
    IntentDelegatorUpgradeActionFlow,
> {
    fn versions(self: IntentDelegatorUpgradeActionFlow) -> Span<ReleaseVersion> {
        [V0, V1, V2].span()
    }

    fn setup(ref self: IntentDelegatorUpgradeActionFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let delegator_full_intent = system.new_delegator(:amount);
        let delegator_half_intent = system.new_delegator(:amount);
        let delegator_zero_intent = system.new_delegator(:amount);

        system.delegate(delegator: delegator_full_intent, :pool, :amount);
        system.delegate(delegator: delegator_half_intent, :pool, :amount);
        system.delegate(delegator: delegator_zero_intent, :pool, :amount);

        system.delegator_exit_intent(delegator: delegator_full_intent, :pool, :amount);
        system.delegator_exit_intent(delegator: delegator_half_intent, :pool, amount: amount / 2);
        system.delegator_exit_intent(delegator: delegator_zero_intent, :pool, amount: Zero::zero());

        system.advance_exit_wait_window();

        system.set_staker_for_migration(staker_address: staker.staker.address);
        system.set_pool_for_upgrade(pool_address: pool);
        self.staker = Option::Some(staker);
        self.pool_address = Option::Some(pool);
        self.delegator_full_intent = Option::Some(delegator_full_intent);
        self.delegator_half_intent = Option::Some(delegator_half_intent);
        self.delegator_zero_intent = Option::Some(delegator_zero_intent);
        self.amount = Option::Some(amount);
        self.commission = Option::Some(commission);
    }

    fn test(
        self: IntentDelegatorUpgradeActionFlow, ref system: SystemState, version: ReleaseVersion,
    ) {
        let staker = self.staker.unwrap();
        let pool = self.pool_address.unwrap();
        let delegator_full_intent = self.delegator_full_intent.unwrap();
        let delegator_half_intent = self.delegator_half_intent.unwrap();
        let delegator_zero_intent = self.delegator_zero_intent.unwrap();
        let amount = self.amount.unwrap();
        let commission = self.commission.unwrap();

        // Delegators exit action.
        system.delegator_exit_action(delegator: delegator_full_intent, :pool);
        system.delegator_exit_action(delegator: delegator_half_intent, :pool);
        let res = system.safe_delegator_exit_action(delegator: delegator_zero_intent, :pool);
        assert_panic_with_error(res, GenericError::MISSING_UNDELEGATE_INTENT.describe());

        // Test pool.
        let expected_pool_info = StakerPoolInfoV2 {
            commission: Option::Some(commission),
            pools: array![
                PoolInfo {
                    pool_contract: pool,
                    amount: amount * 3 / 2,
                    token_address: system.staking.get_token_address(),
                },
            ]
                .span(),
        };
        let staker_pool_info = system.staker_pool_info(:staker);
        assert!(staker_pool_info == expected_pool_info);

        // Test delegators infos.
        let delegator_full_intent_info = system
            .pool_member_info_v1(delegator: delegator_full_intent, :pool);
        let delegator_half_intent_info = system
            .pool_member_info_v1(delegator: delegator_half_intent, :pool);
        let delegator_zero_intent_info = system
            .pool_member_info_v1(delegator: delegator_zero_intent, :pool);
        assert!(delegator_full_intent_info.amount == Zero::zero());
        assert!(delegator_half_intent_info.amount == amount / 2);
        assert!(delegator_zero_intent_info.amount == amount);

        // Test delegators balances.
        assert!(
            system.token.balance_of(account: delegator_full_intent.delegator.address) == amount,
        );
        assert!(
            system.token.balance_of(account: delegator_half_intent.delegator.address) == amount / 2,
        );
        assert!(
            system
                .token
                .balance_of(account: delegator_zero_intent.delegator.address) == Zero::zero(),
        );
    }
}

/// Test staker_migration - with pool, with intent.
/// Flow:
/// Staker stake with pool
/// Staker exit intent
/// Upgrade
/// Staker migration
/// Test staker_pool_info
/// Test staker_info did not change
#[derive(Drop, Copy)]
pub(crate) struct StakerWithPoolInIntentMigrationFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfoV1>,
}
pub(crate) impl StakerWithPoolInIntentMigrationFlowImpl of MultiVersionFlowTrait<
    StakerWithPoolInIntentMigrationFlow,
> {
    fn versions(self: StakerWithPoolInIntentMigrationFlow) -> Span<ReleaseVersion> {
        [V1, V2].span()
    }

    fn setup(ref self: StakerWithPoolInIntentMigrationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        system.staker_exit_intent(:staker);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(system.staker_info_v1(:staker));
    }

    fn test(
        self: StakerWithPoolInIntentMigrationFlow, ref system: SystemState, version: ReleaseVersion,
    ) {
        let staker = self.staker.unwrap();
        let old_staker_info = self.staker_info.unwrap();
        let old_pool_info = old_staker_info.get_pool_info();
        let pool_contract = old_pool_info.pool_contract;
        let expected_pool_info = StakerPoolInfoV2 {
            commission: Option::Some(old_pool_info.commission),
            pools: array![
                PoolInfo {
                    pool_contract,
                    amount: old_pool_info.amount,
                    token_address: system.staking.get_token_address(),
                },
            ]
                .span(),
        };

        let new_staker_info = system.staker_info_v1(:staker);
        let new_pool_info = system.staker_pool_info(:staker);

        assert!(new_pool_info == expected_pool_info);
        assert!(new_staker_info == old_staker_info);
        assert!(get_class_hash(contract_address: pool_contract) == declare_pool_contract());
    }
}

/// Flow:
/// Staker stake with pool
/// 3 delegators delegate
/// Delegator full intent
/// Delegator half intent
/// Delegator zero intent
/// Upgrade
/// Staker migration
/// Delegators change intent
/// Test staker_pool_info
/// Test delegators infos
#[derive(Drop, Copy)]
pub(crate) struct IntentDelegatorUpgradeIntentFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator_full_intent: Option<Delegator>,
    pub(crate) delegator_half_intent: Option<Delegator>,
    pub(crate) delegator_zero_intent: Option<Delegator>,
    pub(crate) amount: Option<Amount>,
    pub(crate) commission: Option<Commission>,
}
pub(crate) impl IntentDelegatorUpgradeIntentFlowImpl of MultiVersionFlowTrait<
    IntentDelegatorUpgradeIntentFlow,
> {
    fn versions(self: IntentDelegatorUpgradeIntentFlow) -> Span<ReleaseVersion> {
        [V0, V1, V2].span()
    }

    fn setup(ref self: IntentDelegatorUpgradeIntentFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let delegator_full_intent = system.new_delegator(:amount);
        let delegator_half_intent = system.new_delegator(:amount);
        let delegator_zero_intent = system.new_delegator(:amount);

        system.delegate(delegator: delegator_full_intent, :pool, :amount);
        system.delegate(delegator: delegator_half_intent, :pool, :amount);
        system.delegate(delegator: delegator_zero_intent, :pool, :amount);

        system.delegator_exit_intent(delegator: delegator_full_intent, :pool, :amount);
        system.delegator_exit_intent(delegator: delegator_half_intent, :pool, amount: amount / 2);
        system.delegator_exit_intent(delegator: delegator_zero_intent, :pool, amount: Zero::zero());

        system.advance_exit_wait_window();

        system.set_staker_for_migration(staker_address: staker.staker.address);
        system.set_pool_for_upgrade(pool_address: pool);
        self.staker = Option::Some(staker);
        self.pool_address = Option::Some(pool);
        self.delegator_full_intent = Option::Some(delegator_full_intent);
        self.delegator_half_intent = Option::Some(delegator_half_intent);
        self.delegator_zero_intent = Option::Some(delegator_zero_intent);
        self.amount = Option::Some(amount);
        self.commission = Option::Some(commission);
    }

    fn test(
        self: IntentDelegatorUpgradeIntentFlow, ref system: SystemState, version: ReleaseVersion,
    ) {
        let staker = self.staker.unwrap();
        let pool = self.pool_address.unwrap();
        let delegator_full_intent = self.delegator_full_intent.unwrap();
        let delegator_half_intent = self.delegator_half_intent.unwrap();
        let delegator_zero_intent = self.delegator_zero_intent.unwrap();
        let amount = self.amount.unwrap();
        let commission = self.commission.unwrap();

        // Delegators change intent.
        let full_delegator_new_intent = amount / 2;
        let half_delegator_new_intent = Zero::zero();
        let zero_delegator_new_intent = amount;
        system
            .delegator_exit_intent(
                delegator: delegator_full_intent, :pool, amount: full_delegator_new_intent,
            );
        system
            .delegator_exit_intent(
                delegator: delegator_half_intent, :pool, amount: half_delegator_new_intent,
            );
        system
            .delegator_exit_intent(
                delegator: delegator_zero_intent, :pool, amount: zero_delegator_new_intent,
            );

        // Test pool.
        let expected_pool_info = StakerPoolInfoV2 {
            commission: Option::Some(commission),
            pools: array![
                PoolInfo {
                    pool_contract: pool,
                    amount: amount * 3 / 2,
                    token_address: system.staking.get_token_address(),
                },
            ]
                .span(),
        };
        let staker_pool_info = system.staker_pool_info(:staker);
        assert!(staker_pool_info == expected_pool_info);

        // Test delegators infos.
        let delegator_full_intent_info = system
            .pool_member_info_v1(delegator: delegator_full_intent, :pool);
        let delegator_half_intent_info = system
            .pool_member_info_v1(delegator: delegator_half_intent, :pool);
        let delegator_zero_intent_info = system
            .pool_member_info_v1(delegator: delegator_zero_intent, :pool);
        assert!(delegator_full_intent_info.unpool_amount == full_delegator_new_intent);
        assert!(delegator_half_intent_info.unpool_amount == half_delegator_new_intent);
        assert!(delegator_zero_intent_info.unpool_amount == zero_delegator_new_intent);
    }
}

/// Test set commission multiple pools.
/// Flow:
/// Staker stake with pool
/// Staker set commission
/// Staker open BTC pool
/// Staker set commission
/// Test pool contract parameters
/// Delegators delegate
/// Attest
/// Test rewards
#[derive(Drop, Copy)]
pub(crate) struct SetCommissionMultiplePoolsFlow {}
pub(crate) impl SetCommissionMultiplePoolsFlowImpl of FlowTrait<SetCommissionMultiplePoolsFlow> {
    fn test(self: SetCommissionMultiplePoolsFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let btc_amount = TEST_MIN_BTC_FOR_REWARDS;
        let staker = system.new_staker(:amount);
        system.stake(:staker, :amount, pool_enabled: true, commission: 800);
        let strk_pool = system.staking.get_pool(:staker);
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;
        let btc_token = system.btc_token;
        let btc_token_address = btc_token.contract_address();

        system.set_commission(:staker, commission: 400);

        let btc_pool = system.set_open_for_delegation(:staker, token_address: btc_token_address);
        let final_commission = 200;
        system.set_commission(:staker, commission: final_commission);

        let strk_pool_contract_parameters = system.contract_parameters_v1(pool: strk_pool);
        let btc_pool_contract_parameters = system.contract_parameters_v1(pool: btc_pool);
        assert!(strk_pool_contract_parameters.commission == 200);
        assert!(btc_pool_contract_parameters.commission == 200);

        let strk_delegator = system.new_delegator(:amount);
        let btc_delegator = system.new_btc_delegator(amount: btc_amount, token: btc_token);
        system.delegate(delegator: strk_delegator, pool: strk_pool, :amount);
        system
            .delegate_btc(
                delegator: btc_delegator, pool: btc_pool, amount: btc_amount, token: btc_token,
            );

        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        let expected_strk_pool_rewards = calculate_strk_pool_rewards_with_pool_balance_v2(
            staker_address: staker.staker.address,
            :staking_contract,
            :minting_curve_contract,
            pool_balance: amount,
        );
        let (expected_btc_commission_rewards, expected_btc_pool_rewards) =
            calculate_staker_btc_pool_rewards_v2(
            pool_balance: btc_amount,
            commission: final_commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: btc_token_address,
        );
        let staker_info = system.staker_info_v1(:staker);
        let (expected_staker_rewards, _) = calculate_staker_strk_rewards_v2(
            :staker_info, :staking_contract, :minting_curve_contract,
        );

        let actual_strk_pool_rewards = system
            .delegator_claim_rewards(delegator: strk_delegator, pool: strk_pool);
        let actual_btc_pool_rewards = system
            .delegator_claim_rewards(delegator: btc_delegator, pool: btc_pool);
        let actual_staker_rewards = system.staker_claim_rewards(:staker);

        assert!(actual_strk_pool_rewards == expected_strk_pool_rewards);
        assert!(actual_btc_pool_rewards == expected_btc_pool_rewards);
        assert!(actual_staker_rewards == expected_staker_rewards + expected_btc_commission_rewards);
    }
}

/// Test staker_migration - without pool, in intent.
/// Flow:
/// Staker stake
/// Staker exit intent
/// Upgrade
/// Staker migration
/// Test staker_pool_info
/// Test staker_info did not change
#[derive(Drop, Copy)]
pub(crate) struct StakerWithoutPoolInIntentMigrationFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfoV1>,
}
pub(crate) impl StakerWithoutPoolInIntentMigrationFlowImpl of FlowTrait<
    StakerWithoutPoolInIntentMigrationFlow,
> {
    fn setup_v1(ref self: StakerWithoutPoolInIntentMigrationFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let amount = min_stake * 2;
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.staker_exit_intent(:staker);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(system.staker_info_v1(:staker));
    }

    fn test(self: StakerWithoutPoolInIntentMigrationFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let old_staker_info = self.staker_info.unwrap();
        let expected_pool_info = StakerPoolInfoV2 {
            commission: Option::None, pools: array![].span(),
        };

        let new_staker_info = system.staker_info_v1(:staker);
        let new_pool_info = system.staker_pool_info(:staker);

        assert!(new_pool_info == expected_pool_info);
        assert!(new_staker_info == old_staker_info);
    }
}

// Test staker_migration called twice.
#[derive(Drop, Copy)]
pub(crate) struct StakerMigrationCalledTwiceFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl StakerMigrationCalledTwiceFlowImpl of FlowTrait<StakerMigrationCalledTwiceFlow> {
    fn setup_v1(ref self: StakerMigrationCalledTwiceFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        /// Staker balance trace: epoch 1, stake_amount.
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        self.staker = Option::Some(staker);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: StakerMigrationCalledTwiceFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let staker_address = staker.staker.address;
        // Should panic.
        system.staker_migration(:staker_address);
    }
}

// Test internal_staker_info called without staker_migration.
#[derive(Drop, Copy)]
pub(crate) struct InternalStakerInfoWithoutStakerMigrationFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl InternalStakerInfoWithoutStakerMigrationFlowImpl of FlowTrait<
    InternalStakerInfoWithoutStakerMigrationFlow,
> {
    fn setup_v1(ref self: InternalStakerInfoWithoutStakerMigrationFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        /// Staker balance trace: epoch 1, stake_amount.
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        self.staker = Option::Some(staker);
    }

    fn test(self: InternalStakerInfoWithoutStakerMigrationFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        // Should panic.
        system.internal_staker_info(:staker);
    }
}

// TODO: Test all claim_rewards/calculate rewards of pools with BTC.

/// Test claim_rewards with multiple delegators.
#[derive(Drop, Copy)]
pub(crate) struct ClaimRewardsMultipleDelegatorsFlow {}
pub(crate) impl ClaimRewardsMultipleDelegatorsFlowImpl of FlowTrait<
    ClaimRewardsMultipleDelegatorsFlow,
> {
    fn test(self: ClaimRewardsMultipleDelegatorsFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let commission = 200;
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let delegated_amount = min_stake;
        let delegator_1 = system.new_delegator(amount: delegated_amount);
        let delegator_2 = system.new_delegator(amount: delegated_amount);
        let delegator_3 = system.new_delegator(amount: delegated_amount);

        system.delegate(delegator: delegator_1, :pool, amount: delegated_amount);
        system.delegate(delegator: delegator_2, :pool, amount: delegated_amount / 2);
        system.delegate(delegator: delegator_3, :pool, amount: delegated_amount / 4);

        let pool_balance = delegated_amount + delegated_amount / 2 + delegated_amount / 4;

        system.advance_k_epochs_and_attest(:staker);

        // Compute pool rewards.
        let pool_rewards = calculate_strk_pool_rewards_v2(
            staker_address: staker.staker.address,
            staking_contract: system.staking.address,
            minting_curve_contract: system.minting_curve.address,
        );

        system.advance_epoch();

        // Compute expected rewards for each pool member.
        let expected_rewards_1 = calculate_pool_member_rewards(
            :pool_rewards, pool_member_balance: delegated_amount, :pool_balance,
        );
        let expected_rewards_2 = calculate_pool_member_rewards(
            :pool_rewards, pool_member_balance: delegated_amount / 2, :pool_balance,
        );
        let expected_rewards_3 = calculate_pool_member_rewards(
            :pool_rewards, pool_member_balance: delegated_amount / 4, :pool_balance,
        );

        // Claim rewards, and validate the results.
        let calculates_rewards_1 = system
            .pool_member_info_v1(delegator: delegator_1, :pool)
            .unclaimed_rewards;
        let calculates_rewards_2 = system
            .pool_member_info_v1(delegator: delegator_2, :pool)
            .unclaimed_rewards;
        let calculates_rewards_3 = system
            .pool_member_info_v1(delegator: delegator_3, :pool)
            .unclaimed_rewards;

        let actual_reward_1 = system.delegator_claim_rewards(delegator: delegator_1, :pool);
        let actual_reward_2 = system.delegator_claim_rewards(delegator: delegator_2, :pool);
        let actual_reward_3 = system.delegator_claim_rewards(delegator: delegator_3, :pool);

        assert!(system.staker_info_v1(:staker).get_pool_info().amount == pool_balance);

        assert!(calculates_rewards_1 == expected_rewards_1);
        assert!(calculates_rewards_2 == expected_rewards_2);
        assert!(calculates_rewards_3 == expected_rewards_3);

        assert!(actual_reward_1 == expected_rewards_1);
        assert!(actual_reward_2 == expected_rewards_2);
        assert!(actual_reward_3 == expected_rewards_3);

        assert!(
            system
                .token
                .balance_of(account: delegator_1.reward.address) == expected_rewards_1
                .into(),
        );
        assert!(
            system
                .token
                .balance_of(account: delegator_2.reward.address) == expected_rewards_2
                .into(),
        );
        assert!(
            system
                .token
                .balance_of(account: delegator_3.reward.address) == expected_rewards_3
                .into(),
        );
    }
}

/// Test claim_rewards with multiple delegators.
#[derive(Drop, Copy)]
pub(crate) struct ClaimRewardsMultipleDelegatorsBtcFlow {}
pub(crate) impl ClaimRewardsMultipleDelegatorsBtcFlowImpl of FlowTrait<
    ClaimRewardsMultipleDelegatorsBtcFlow,
> {
    fn test(self: ClaimRewardsMultipleDelegatorsBtcFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let commission = 200;
        let btc_token = system.btc_token;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;
        system.stake(:staker, amount: stake_amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);
        let pool = system
            .set_open_for_delegation(:staker, token_address: btc_token.contract_address());

        let delegated_amount = TEST_MIN_BTC_FOR_REWARDS * 16;
        let delegator_1 = system.new_btc_delegator(amount: delegated_amount, token: btc_token);
        let delegator_2 = system.new_btc_delegator(amount: delegated_amount, token: btc_token);
        let delegator_3 = system.new_btc_delegator(amount: delegated_amount, token: btc_token);

        system
            .delegate_btc(
                delegator: delegator_1, :pool, amount: delegated_amount, token: btc_token,
            );
        system
            .delegate_btc(
                delegator: delegator_2, :pool, amount: delegated_amount / 2, token: btc_token,
            );
        system
            .delegate_btc(
                delegator: delegator_3, :pool, amount: delegated_amount / 4, token: btc_token,
            );

        let pool_balance = delegated_amount + delegated_amount / 2 + delegated_amount / 4;

        system.advance_k_epochs_and_attest(:staker);

        // Compute pool rewards.
        let (_, pool_rewards) = calculate_staker_btc_pool_rewards_v2(
            :pool_balance,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: btc_token.contract_address(),
        );

        system.advance_epoch();

        // Compute expected rewards for each pool member.
        let expected_rewards_1 = calculate_pool_member_rewards(
            :pool_rewards, pool_member_balance: delegated_amount, :pool_balance,
        );
        let expected_rewards_2 = calculate_pool_member_rewards(
            :pool_rewards, pool_member_balance: delegated_amount / 2, :pool_balance,
        );
        let expected_rewards_3 = calculate_pool_member_rewards(
            :pool_rewards, pool_member_balance: delegated_amount / 4, :pool_balance,
        );
        let expected_staker_pool_info = StakerPoolInfoV2 {
            commission: Some(commission),
            pools: array![
                PoolInfo {
                    pool_contract: pool,
                    token_address: btc_token.contract_address(),
                    amount: pool_balance,
                },
            ]
                .span(),
        };

        // Claim rewards, and validate the results.
        let calculated_rewards_1 = system
            .pool_member_info_v1(delegator: delegator_1, :pool)
            .unclaimed_rewards;
        let calculated_rewards_2 = system
            .pool_member_info_v1(delegator: delegator_2, :pool)
            .unclaimed_rewards;
        let calculated_rewards_3 = system
            .pool_member_info_v1(delegator: delegator_3, :pool)
            .unclaimed_rewards;

        let actual_reward_1 = system.delegator_claim_rewards(delegator: delegator_1, :pool);
        let actual_reward_2 = system.delegator_claim_rewards(delegator: delegator_2, :pool);
        let actual_reward_3 = system.delegator_claim_rewards(delegator: delegator_3, :pool);

        assert!(system.staker_pool_info(:staker) == expected_staker_pool_info);

        assert!(calculated_rewards_1 == expected_rewards_1);
        assert!(calculated_rewards_2 == expected_rewards_2);
        assert!(calculated_rewards_3 == expected_rewards_3);

        assert!(actual_reward_1 == expected_rewards_1);
        assert!(actual_reward_2 == expected_rewards_2);
        assert!(actual_reward_3 == expected_rewards_3);

        assert!(
            system
                .token
                .balance_of(account: delegator_1.reward.address) == expected_rewards_1
                .into(),
        );
        assert!(
            system
                .token
                .balance_of(account: delegator_2.reward.address) == expected_rewards_2
                .into(),
        );
        assert!(
            system
                .token
                .balance_of(account: delegator_3.reward.address) == expected_rewards_3
                .into(),
        );
    }
}

/// Test Pool claim_rewards few times.
/// Flow:
/// Staker stake with pool
/// attest
/// Delegator delegate
/// attest
/// attest
/// Delegator claim_rewards
/// attest
/// attest
/// Delegator claim_rewards - Cover claim after claim
/// Delegator pool_member_info - Cover calculate after claim no rewards
/// Delegator claim_rewards - Cover claim after claim no rewards
/// Exit intent staker and delegator
/// Exit action staker and delegator
/// Delegator claim_rewards - Cover claim after exit action
#[derive(Drop, Copy)]
pub(crate) struct PoolClaimAfterClaimFlow {}
pub(crate) impl PoolClaimAfterClaimFlowImpl of FlowTrait<PoolClaimAfterClaimFlow> {
    fn test(self: PoolClaimAfterClaimFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let commission = 200;
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);

        let first_claim = system.delegator_claim_rewards(:delegator, :pool);

        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);

        let second_claim = system.delegator_claim_rewards(:delegator, :pool);
        assert!(second_claim == 2 * first_claim);

        let pool_member_info = system
            .pool_member_info_v1(:delegator, :pool); // Calculate after claim.
        assert!(pool_member_info.unclaimed_rewards == 0);

        let rewards_before = system.token.balance_of(account: delegator.reward.address);
        assert!(rewards_before == second_claim + first_claim);
        let claimed_rewards = system
            .delegator_claim_rewards(:delegator, :pool); // Claim after claim.
        assert!(claimed_rewards == 0);
        assert!(rewards_before == system.token.balance_of(account: delegator.reward.address));

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.staker_exit_intent(:staker);

        system.advance_exit_wait_window();

        system.delegator_exit_action(:delegator, :pool);
        system.staker_exit_action(:staker);

        system.delegator_claim_rewards(:delegator, :pool);

        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);
        assert!(system.token.balance_of(account: pool) == 0);
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address),
        );
    }
}

/// Test pool member change balance calculate rewards flow.
/// Flow:
/// Staker stake with pool
/// advance epoch and attest
/// Delegator1 delegate
/// advance epoch and attest
/// Delegator2 delegate
/// advance epoch and attest
/// Delegator1 increase delegate - Cover already got rewards for current epoch
/// advance epoch
/// Delegator1 increase delegate - Cover still didnt get rewards for current epoch
/// attest
/// advance epoch
/// Delegator1 increase delegate - Cover no rewards at all for current epoch
/// advance epoch
/// advance epoch and attest
/// Delegator1 exit intent full amount - Cover balance change to zero
/// advance epoch and attest
/// Delegator1 exit intent partial amount - Cover balance change to non-zero
/// advance epoch and attest
/// advance epoch and attest
/// Delegator1 exit action
/// Delegator1 increase delegate - Cover more than one reward between balance changes
/// advance epoch and attest
/// advance epoch
/// Delegator1 pool_member_info (calculate_rewards)
/// Delegator2 pool_member_info (calculate_rewards)
/// Delegator1 claim_rewards
/// Delegator2 claim_rewards
#[derive(Drop, Copy)]
pub(crate) struct ChangeBalanceClaimRewardsFlow {}
pub(crate) impl ChangeBalanceClaimRewardsFlowImpl of FlowTrait<ChangeBalanceClaimRewardsFlow> {
    fn test(self: ChangeBalanceClaimRewardsFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let staker_address = staker.staker.address;
        let commission = 200;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;
        let token_address = system.token.contract_address();
        let base_value = STRK_BASE_VALUE;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);
        system.advance_k_epochs_and_attest(:staker);

        let mut delegator_1_rewards: Amount = 0;
        let mut delegator_2_rewards: Amount = 0;
        let mut pool_balance: Amount = 0;
        let mut sigma: Amount = 0;

        let delegator_1 = system.new_delegator(amount: stake_amount);
        let mut delegated_amount_1 = stake_amount / 4;
        system.delegate(delegator: delegator_1, :pool, amount: delegated_amount_1);

        system.advance_k_epochs_and_attest(:staker);
        // Delelgator 1 is the only delegator in the pool.
        pool_balance += delegated_amount_1;
        delegator_1_rewards +=
            calculate_strk_pool_rewards_v2(
                :staker_address, :staking_contract, :minting_curve_contract,
            );

        let delegated_amount_2 = delegated_amount_1;
        let delegator_2 = system.new_delegator(amount: delegated_amount_2);
        system.delegate(delegator: delegator_2, :pool, amount: delegated_amount_2);

        system.advance_k_epochs_and_attest(:staker);
        pool_balance += delegated_amount_2;
        let pool_rewards = calculate_strk_pool_rewards_v2(
            :staker_address, :staking_contract, :minting_curve_contract,
        );
        delegator_1_rewards +=
            calculate_pool_member_rewards(
                :pool_rewards, pool_member_balance: delegated_amount_1, :pool_balance,
            );
        sigma +=
            compute_rewards_per_unit(
                staking_rewards: pool_rewards, total_stake: pool_balance, :token_address,
            );

        system.increase_delegate(delegator: delegator_1, :pool, amount: stake_amount / 4);

        system.advance_k_epochs();

        delegated_amount_1 += stake_amount / 4;
        pool_balance += stake_amount / 4;
        system.advance_block_into_attestation_window(:staker);

        system.increase_delegate(delegator: delegator_1, :pool, amount: stake_amount / 4);

        system.attest(:staker);
        let pool_rewards = calculate_strk_pool_rewards_with_pool_balance_v2(
            :staker_address, :staking_contract, :minting_curve_contract, :pool_balance,
        );
        delegator_1_rewards +=
            calculate_pool_member_rewards(
                :pool_rewards, pool_member_balance: delegated_amount_1, :pool_balance,
            );
        sigma +=
            compute_rewards_per_unit(
                staking_rewards: pool_rewards, total_stake: pool_balance, :token_address,
            );

        system.advance_k_epochs();
        delegated_amount_1 += stake_amount / 4;
        pool_balance += stake_amount / 4;

        system.increase_delegate(delegator: delegator_1, :pool, amount: stake_amount / 4);

        system.advance_k_epochs();
        delegated_amount_1 += stake_amount / 4;
        pool_balance += stake_amount / 4;

        system.advance_k_epochs_and_attest(:staker);
        let pool_rewards = calculate_strk_pool_rewards_v2(
            :staker_address, :staking_contract, :minting_curve_contract,
        );
        delegator_1_rewards +=
            calculate_pool_member_rewards(
                :pool_rewards, pool_member_balance: delegated_amount_1, :pool_balance,
            );
        sigma +=
            compute_rewards_per_unit(
                staking_rewards: pool_rewards, total_stake: pool_balance, :token_address,
            );

        system
            .delegator_exit_intent(
                delegator: delegator_1, :pool, amount: stake_amount,
            ); // Full exit intent.

        system.advance_k_epochs_and_attest(:staker);
        delegated_amount_1 = 0;
        pool_balance -= stake_amount;

        let pool_rewards = calculate_strk_pool_rewards_v2(
            :staker_address, :staking_contract, :minting_curve_contract,
        );
        sigma +=
            compute_rewards_per_unit(
                staking_rewards: pool_rewards, total_stake: pool_balance, :token_address,
            );

        system
            .delegator_exit_intent(
                delegator: delegator_1, :pool, amount: stake_amount / 4,
            ); // Partial exit intent.

        // More than one reward between balance changes.
        system.advance_k_epochs_and_attest(:staker);
        delegated_amount_1 += 3 * stake_amount / 4;
        pool_balance += 3 * stake_amount / 4;

        let pool_rewards = calculate_strk_pool_rewards_v2(
            :staker_address, :staking_contract, :minting_curve_contract,
        );
        let from_sigma = sigma;
        sigma +=
            compute_rewards_per_unit(
                staking_rewards: pool_rewards, total_stake: pool_balance, :token_address,
            );

        system.advance_k_epochs_and_attest(:staker);
        sigma +=
            compute_rewards_per_unit(
                staking_rewards: pool_rewards, total_stake: pool_balance, :token_address,
            );
        delegator_1_rewards +=
            compute_rewards_rounded_down(
                amount: delegated_amount_1, interest: sigma - from_sigma, :base_value,
            );

        system.advance_exit_wait_window();
        system.delegator_exit_action(delegator: delegator_1, :pool);
        system.increase_delegate(delegator: delegator_1, :pool, amount: stake_amount / 4);

        system.advance_k_epochs_and_attest(:staker);
        delegated_amount_1 += stake_amount / 4;
        pool_balance += stake_amount / 4;

        let pool_rewards = calculate_strk_pool_rewards_v2(
            :staker_address, :staking_contract, :minting_curve_contract,
        );
        delegator_1_rewards +=
            calculate_pool_member_rewards(
                :pool_rewards, pool_member_balance: delegated_amount_1, :pool_balance,
            );
        sigma +=
            compute_rewards_per_unit(
                staking_rewards: pool_rewards, total_stake: pool_balance, :token_address,
            );

        system.advance_k_epochs();

        delegator_2_rewards =
            compute_rewards_rounded_down(amount: delegated_amount_2, interest: sigma, :base_value);

        let calculated_rewards_1 = system
            .pool_member_info_v1(delegator: delegator_1, :pool)
            .unclaimed_rewards;
        let calculated_rewards_2 = system
            .pool_member_info_v1(delegator: delegator_2, :pool)
            .unclaimed_rewards;

        let actual_rewards_1 = system.delegator_claim_rewards(delegator: delegator_1, :pool);
        let actual_rewards_2 = system.delegator_claim_rewards(delegator: delegator_2, :pool);

        assert!(system.token.balance_of(account: pool) < 100);
        assert!(calculated_rewards_1 == delegator_1_rewards);
        assert!(calculated_rewards_2 == delegator_2_rewards);
        assert!(actual_rewards_1 == delegator_1_rewards);
        assert!(actual_rewards_2 == delegator_2_rewards);
        assert!(
            system.token.balance_of(account: delegator_1.reward.address) == delegator_1_rewards,
        );
        assert!(
            system.token.balance_of(account: delegator_2.reward.address) == delegator_2_rewards,
        );
    }
}

/// Test Claim Rewards After Upgrade.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// advance_time
/// Upgrade
/// attest
/// attest
/// attest
/// pool_member_info (calculate_rewards)
/// claim_rewards
#[derive(Drop, Copy)]
pub(crate) struct PoolClaimRewardsAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) staker: Option<Staker>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegator_info: Option<PoolMemberInfo>,
}
pub(crate) impl PoolClaimRewardsAfterUpgradeFlowImpl of FlowTrait<
    PoolClaimRewardsAfterUpgradeFlow,
> {
    fn setup(ref self: PoolClaimRewardsAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        system.advance_time(time: one_week);

        let delegator_info = system.pool_member_info(:delegator, :pool);

        self.pool_address = Option::Some(pool);
        self.staker = Option::Some(staker);
        self.delegator = Option::Some(delegator);
        self.delegator_info = Option::Some(delegator_info);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: PoolClaimRewardsAfterUpgradeFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let delegator = self.delegator.unwrap();
        let delegator_info = self.delegator_info.unwrap();
        let pool = self.pool_address.unwrap();

        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);

        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        // Calculate pool rewards
        let pool_rewards_one_epoch = calculate_strk_pool_rewards_v2(
            staker_address: staker.staker.address, :staking_contract, :minting_curve_contract,
        );
        let pool_total_rewards = pool_rewards_one_epoch * 3;

        let expected_pool_rewards = pool_total_rewards + delegator_info.unclaimed_rewards;

        let pool_member_info = system.pool_member_info_v1(:delegator, :pool);

        let actual_pool_rewards = system.delegator_claim_rewards(:delegator, :pool);

        assert!(pool_member_info.unclaimed_rewards == expected_pool_rewards);
        assert!(expected_pool_rewards == actual_pool_rewards);
        assert!(
            expected_pool_rewards == system.token.balance_of(account: delegator.reward.address),
        );
    }
}

/// Pool with min btc
/// Flow:
/// Staker stake
/// Staker open for btc delegation
/// Delegator delegate
/// Staker attest
/// Delegator claim rewards
/// Test rewards
#[derive(Drop, Copy)]
pub(crate) struct PoolWithMinBtcFlow {}
pub(crate) impl PoolWithMinBtcFlowImpl of FlowTrait<PoolWithMinBtcFlow> {
    fn test(self: PoolWithMinBtcFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);

        let token = system.btc_token;
        let token_address = token.contract_address();
        let pool = system.set_open_for_delegation(:staker, :token_address);

        let delegate_amount = TEST_MIN_BTC_FOR_REWARDS;
        let delegator = system.new_btc_delegator(amount: delegate_amount, :token);
        system.delegate_btc(:delegator, :pool, amount: delegate_amount - 1, :token);

        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        let pool_rewards = system.delegator_claim_rewards(:delegator, :pool);
        let staker_rewards = system.staker_claim_rewards(:staker);
        assert!(pool_rewards.is_zero());
        assert!(staker_rewards.is_non_zero());

        system.increase_delegate_btc(:delegator, :pool, amount: 1, :token);
        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        let (expected_commission_rewards, expected_pool_rewards) =
            calculate_staker_btc_pool_rewards_v2(
            pool_balance: delegate_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            :token_address,
        );
        let pool_rewards = system.delegator_claim_rewards(:delegator, :pool);
        let staker_rewards = system.staker_claim_rewards(:staker);
        assert!(pool_rewards == expected_pool_rewards);
        assert!(staker_rewards > expected_commission_rewards);
        assert!(
            wide_abs_diff(
                mul_wide_and_div(
                    lhs: pool_rewards + expected_commission_rewards,
                    rhs: ALPHA_DENOMINATOR - ALPHA,
                    div: ALPHA,
                )
                    .unwrap(),
                staker_rewards - expected_commission_rewards,
            ) < 100,
        );
    }
}

/// Test change balance after upgrade.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// advance_time
/// Upgrade
/// attest
/// add_to_delegation_pool
/// attest
/// attest
/// claim_rewards
#[derive(Drop, Copy)]
pub(crate) struct PoolChangeBalanceAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) staker: Option<Staker>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegator_info: Option<PoolMemberInfo>,
    pub(crate) delegated_amount: Amount,
}
pub(crate) impl PoolChangeBalanceAfterUpgradeFlowmpl of FlowTrait<
    PoolChangeBalanceAfterUpgradeFlow,
> {
    fn setup(ref self: PoolChangeBalanceAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: 2 * delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        system.advance_time(time: one_week);

        let delegator_info = system.pool_member_info(:delegator, :pool);

        self.pool_address = Option::Some(pool);
        self.staker = Option::Some(staker);
        self.delegator = Option::Some(delegator);
        self.delegator_info = Option::Some(delegator_info);
        self.delegated_amount = delegated_amount;
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: PoolChangeBalanceAfterUpgradeFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let delegator = self.delegator.unwrap();
        let delegator_info = self.delegator_info.unwrap();
        let pool = self.pool_address.unwrap();
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        system.advance_k_epochs_and_attest(:staker);

        // Calculate pool rewards
        let pool_rewards_first_epoch = calculate_strk_pool_rewards_v2(
            staker_address: staker.staker.address, :staking_contract, :minting_curve_contract,
        );
        assert!(pool_rewards_first_epoch.is_non_zero());

        system.add_to_delegation_pool(:delegator, :pool, amount: self.delegated_amount);

        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);

        // Calculate pool rewards
        let pool_rewards_second_epoch = calculate_strk_pool_rewards_v2(
            staker_address: staker.staker.address, :staking_contract, :minting_curve_contract,
        );
        assert!(pool_rewards_second_epoch > pool_rewards_first_epoch);

        let expected_pool_rewards = pool_rewards_first_epoch
            + pool_rewards_second_epoch
            + delegator_info.unclaimed_rewards;

        let actual_pool_rewards = system.delegator_claim_rewards(:delegator, :pool);

        assert!(expected_pool_rewards == actual_pool_rewards);
        assert!(
            expected_pool_rewards == system.token.balance_of(account: delegator.reward.address),
        );
    }
}

/// Pool with lots of btc
/// Flow:
/// Staker stake
/// Staker open for btc delegation
/// Delegator delegate
/// Staker attest
/// Delegator claim rewards
/// Test rewards
#[derive(Drop, Copy)]
pub(crate) struct PoolWithLotsOfBtcFlow {}
pub(crate) impl PoolWithLotsOfBtcFlowImpl of FlowTrait<PoolWithLotsOfBtcFlow> {
    fn test(self: PoolWithLotsOfBtcFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);

        let token = system.btc_token;
        let token_address = token.contract_address();
        let pool = system.set_open_for_delegation(:staker, :token_address);

        // ~ 5 times as much as total supply of btc.
        let delegate_amount = 10_u128.pow(8) * TEST_ONE_BTC;
        let delegator = system.new_btc_delegator(amount: delegate_amount, :token);
        system.delegate_btc(:delegator, :pool, amount: delegate_amount, :token);

        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        let (expected_commission_rewards, expected_pool_rewards) =
            calculate_staker_btc_pool_rewards_v2(
            pool_balance: delegate_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            :token_address,
        );
        let pool_rewards = system.delegator_claim_rewards(:delegator, :pool);
        let staker_rewards = system.staker_claim_rewards(:staker);
        assert!(wide_abs_diff(pool_rewards, expected_pool_rewards) < 100);
        assert!(staker_rewards > expected_commission_rewards);
        assert!(
            wide_abs_diff(
                mul_wide_and_div(
                    lhs: pool_rewards
                        + expected_commission_rewards
                        + system.token.balance_of(account: pool),
                    rhs: ALPHA_DENOMINATOR - ALPHA,
                    div: ALPHA,
                )
                    .unwrap(),
                staker_rewards - expected_commission_rewards,
            ) < 100,
        );
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Delegator full exit intent
/// Upgrade
/// Staker attest
/// Delegator claim rewards
#[derive(Drop, Copy)]
pub(crate) struct DelegatorIntentBeforeClaimRewardsAfterFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
}
pub(crate) impl DelegatorIntentBeforeClaimRewardsAfterFlowImpl of FlowTrait<
    DelegatorIntentBeforeClaimRewardsAfterFlow,
> {
    fn setup(ref self: DelegatorIntentBeforeClaimRewardsAfterFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let delegator = system.new_delegator(amount: stake_amount);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: stake_amount);
        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount);

        self.staker = Option::Some(staker);
        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: DelegatorIntentBeforeClaimRewardsAfterFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let pool = self.pool_address.unwrap();
        let delegator = self.delegator.unwrap();

        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        assert!(system.delegator_claim_rewards(:delegator, :pool).is_zero());
    }
}

/// Flow:
/// Staker stake with pool
/// Deploy, add, and enable second btc token
/// Staker open pools for both btc tokens
/// Strk delegator delegate
/// BTC delegator delegate (only one pool)
/// Attest
/// Test staker and pool rewards
#[derive(Drop, Copy)]
pub(crate) struct StakerMultiplePoolsAttestFlow {}
pub(crate) impl StakerMultiplePoolsAttestFlowImpl of FlowTrait<StakerMultiplePoolsAttestFlow> {
    fn test(self: StakerMultiplePoolsAttestFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let btc_amount = TEST_MIN_BTC_FOR_REWARDS;
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        // Setup btc.
        let first_btc_token = system.btc_token;
        let second_btc_token = system.deploy_second_btc_token();
        system.staking.add_token(token_address: second_btc_token.contract_address());
        system.staking.enable_token(token_address: second_btc_token.contract_address());

        // Setup pools.
        let strk_pool = system.staking.get_pool(:staker);
        let first_btc_pool = system
            .set_open_for_delegation(:staker, token_address: first_btc_token.contract_address());
        let second_btc_pool = system
            .set_open_for_delegation(:staker, token_address: second_btc_token.contract_address());

        // Setup delegators.
        let strk_delegator = system.new_delegator(:amount);
        let btc_delegator = system.new_btc_delegator(amount: btc_amount, token: first_btc_token);

        // Delegate.
        system.delegate(delegator: strk_delegator, pool: strk_pool, :amount);
        system
            .delegate_btc(
                delegator: btc_delegator,
                pool: first_btc_pool,
                amount: btc_amount,
                token: first_btc_token,
            );

        // Advance epoch and attest.
        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        // Calculate expected rewards.
        let expected_strk_pool_rewards = calculate_strk_pool_rewards_v2(
            staker_address: staker.staker.address, :staking_contract, :minting_curve_contract,
        );
        let (expected_btc_commission_rewards, expected_btc_pool_rewards) =
            calculate_staker_btc_pool_rewards_v2(
            pool_balance: btc_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: first_btc_token.contract_address(),
        );
        let (expected_staker_strk_rewards, _) = calculate_staker_strk_rewards_v2(
            staker_info: system.staker_info_v1(:staker), :staking_contract, :minting_curve_contract,
        );
        let actual_strk_pool_rewards = system
            .delegator_claim_rewards(delegator: strk_delegator, pool: strk_pool);
        let actual_btc_pool_rewards = system
            .delegator_claim_rewards(delegator: btc_delegator, pool: first_btc_pool);
        let actual_staker_rewards = system.staker_claim_rewards(:staker);
        let second_btc_pool_balance = second_btc_token.balance_of(account: second_btc_pool);

        // Assert rewards.
        assert!(
            wide_abs_diff(
                actual_staker_rewards,
                expected_staker_strk_rewards + expected_btc_commission_rewards,
            ) < 100,
        );
        assert!(wide_abs_diff(actual_strk_pool_rewards, expected_strk_pool_rewards) < 100);
        assert!(wide_abs_diff(actual_btc_pool_rewards, expected_btc_pool_rewards) < 100);
        assert!(second_btc_pool_balance == 0);
    }
}
/// Flow:
/// Staker stake without pool
/// Upgrade
/// Set open for delegation
/// Delegator delegate
#[derive(Drop, Copy)]
pub(crate) struct SetOpenForDelegationAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl SetOpenForDelegationAfterUpgradeFlowImpl of FlowTrait<
    SetOpenForDelegationAfterUpgradeFlow,
> {
    fn setup(ref self: SetOpenForDelegationAfterUpgradeFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: false, commission: 200);
        self.staker = Option::Some(staker);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: SetOpenForDelegationAfterUpgradeFlow, ref system: SystemState) {
        let commission = 200;
        let amount = 1000;
        let staker = self.staker.unwrap();

        let pool = system.set_open_for_strk_delegation(:staker, :commission);

        let delegator = system.new_delegator(amount: amount * 2);
        let total_stake_before = system.staking.get_total_stake();
        system.delegate(:delegator, :pool, :amount);

        let delegator_info = system.pool_member_info_v1(:delegator, :pool);
        assert!(delegator_info.amount == amount);
        assert!(system.staking.get_total_stake() == total_stake_before + amount);
    }
}

/// Flow:
/// Staker stake
/// Staker attest
/// Advance epoch
/// Staker increase stake
/// Staker exit intent (same epoch)
/// Staker exit action
#[derive(Drop, Copy)]
pub(crate) struct IncreaseStakeIntentSameEpochFlow {}
pub(crate) impl IncreaseStakeIntentSameEpochFlowImpl of FlowTrait<
    IncreaseStakeIntentSameEpochFlow,
> {
    fn test(self: IncreaseStakeIntentSameEpochFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        system.stake(:staker, amount: stake_amount, pool_enabled: false, commission: 200);
        system.advance_k_epochs_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount);
        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        assert!(system.token.balance_of(account: staker.staker.address).is_zero());
        system.staker_exit_action(:staker);
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount * 2);
    }
}

/// Flow:
/// Staker stake
/// Delegator delegate
/// Staker attest
/// Delegator claim rewards
/// Staker claim rewards
/// Upgrade
/// Staker attest
/// Test pool rewards
/// Test staker rewards
/// Staker open BTC pool
/// BTC Delegator delegate
/// Staker attest
/// Test pool rewards
/// Test staker rewards
#[derive(Drop, Copy)]
pub(crate) struct PoolAttestFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) pool_rewards: Option<Amount>,
    pub(crate) staker_rewards: Option<Amount>,
    pub(crate) commission: Option<u16>,
}
pub(crate) impl PoolAttestFlowImpl of MultiVersionFlowTrait<PoolAttestFlow> {
    fn versions(self: PoolAttestFlow) -> Span<ReleaseVersion> {
        [V1, V2].span()
    }

    fn setup(ref self: PoolAttestFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(:amount);
        system.delegate(:delegator, :pool, :amount);
        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        let pool_rewards = system.delegator_claim_rewards(:delegator, :pool);
        let staker_rewards = system.staker_claim_rewards(:staker);
        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
        self.delegator = Option::Some(delegator);
        self.pool_rewards = Option::Some(pool_rewards);
        self.staker_rewards = Option::Some(staker_rewards);
        self.commission = Option::Some(commission);
    }

    fn test(self: PoolAttestFlow, ref system: SystemState, version: ReleaseVersion) {
        let staker = self.staker.unwrap();
        let pool = system.staking.get_pool(:staker);
        let delegator = self.delegator.unwrap();
        let pool_rewards = self.pool_rewards.unwrap();
        let staker_rewards = self.staker_rewards.unwrap();
        let commission = self.commission.unwrap();
        let token = system.btc_token;
        let btc_amount = TEST_MIN_BTC_FOR_REWARDS;

        // Attest.
        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        // Test pool rewards.
        let mid_pool_rewards = system.delegator_claim_rewards(:delegator, :pool);
        let mid_staker_rewards = system.staker_claim_rewards(:staker);
        // Verify rewards increase after upgrade due to C parameter rising to 4%.
        if (version == V1) {
            assert!(mid_pool_rewards > pool_rewards);
            assert!(mid_staker_rewards > staker_rewards);
        } else {
            assert!(mid_pool_rewards == pool_rewards);
            assert!(mid_staker_rewards == staker_rewards);
        }

        // Open BTC pool.
        let btc_pool = system
            .set_open_for_delegation(:staker, token_address: token.contract_address());
        let btc_delegator = system.new_btc_delegator(amount: btc_amount, :token);
        system.delegate_btc(delegator: btc_delegator, pool: btc_pool, amount: btc_amount, :token);

        // Attest.
        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        // Test pool rewards.
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;
        let (btc_commission_rewards, _) = calculate_staker_btc_pool_rewards_v2(
            pool_balance: btc_amount,
            :commission,
            :staking_contract,
            :minting_curve_contract,
            token_address: token.contract_address(),
        );
        let new_pool_rewards = system.delegator_claim_rewards(:delegator, :pool);
        let new_staker_rewards = system.staker_claim_rewards(:staker);
        assert!(new_pool_rewards == mid_pool_rewards);
        assert!(new_staker_rewards == mid_staker_rewards + btc_commission_rewards);
    }
}

/// Flow:
/// First staker stake with pool
/// First delegator delegate
/// Second staker stake with pool
/// Second delegator delegate
/// Assert total stake
#[derive(Drop, Copy)]
pub(crate) struct AssertTotalStakeAfterMultiStakeFlow {}
pub(crate) impl AssertTotalStakeAfterMultiStakeFlowImpl of FlowTrait<
    AssertTotalStakeAfterMultiStakeFlow,
> {
    fn test(self: AssertTotalStakeAfterMultiStakeFlow, ref system: SystemState) {
        let stake_amount = system.staking.get_min_stake() * 2;
        let commission = 200;

        let first_staker = system.new_staker(amount: stake_amount);
        system.stake(staker: first_staker, amount: stake_amount, pool_enabled: true, :commission);

        let first_delegator = system.new_delegator(amount: stake_amount);
        let first_pool = system.staking.get_pool(staker: first_staker);
        system.delegate(delegator: first_delegator, pool: first_pool, amount: stake_amount);

        let second_staker = system.new_staker(amount: stake_amount);
        system.stake(staker: second_staker, amount: stake_amount, pool_enabled: true, :commission);

        let second_delegator = system.new_delegator(amount: stake_amount);
        let second_pool = system.staking.get_pool(staker: second_staker);
        system.delegate(delegator: second_delegator, pool: second_pool, amount: stake_amount);

        assert!(system.staking.get_total_stake() == stake_amount * 4);
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Staker attest
/// Delegator full exit intent
/// Delegator exit action
#[derive(Drop, Copy)]
pub(crate) struct DelegateIntentSameEpochFlow {}
pub(crate) impl DelegateIntentSameEpochFlowImpl of FlowTrait<DelegateIntentSameEpochFlow> {
    fn test(self: DelegateIntentSameEpochFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let delegated_amount = stake_amount;
        let delegator = system.new_delegator(amount: delegated_amount);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs();
        system.advance_block_into_attestation_window(:staker);

        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);
        system.attest(:staker);
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());

        assert!(system.token.balance_of(account: delegator.delegator.address).is_zero());
        system.delegator_exit_action(:delegator, :pool);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);

        let delegator_info = system.pool_member_info_v1(:delegator, :pool);
        assert!(delegator_info.amount.is_zero());
        assert!(delegator_info.unclaimed_rewards.is_zero());
    }
}

/// Test Pool claim_rewards flow.
/// Flow:
/// Staker stake with pool
/// attest
/// Delegator1 delegate
/// Delegator2 delegate
/// Delegator3 delegate
/// Delegator1 claim_rewards
/// attest
/// Delegator1 claim_rewards - Cover zero epochs
/// attest
/// Delegator2 claim_rewards - Cover one epoch
/// attest
/// Delegator3 claim_rewards - Cover two epochs
/// attest
/// Delegator2 claim_rewards
/// Exit intent staker and all delegators
/// Exit action staker and all delegators
#[derive(Drop, Copy)]
pub(crate) struct PoolClaimRewardsFlow {}
pub(crate) impl PoolClaimRewardsFlowImpl of FlowTrait<PoolClaimRewardsFlow> {
    fn test(self: PoolClaimRewardsFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let commission = 200;
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let delegated_amount_1 = stake_amount / 2;
        let delegator_1 = system.new_delegator(amount: delegated_amount_1);
        let delegated_amount_2 = stake_amount / 4;
        let delegator_2 = system.new_delegator(amount: delegated_amount_2);
        let delegated_amount_3 = stake_amount / 8;
        let delegator_3 = system.new_delegator(amount: delegated_amount_3);
        let pool = system.staking.get_pool(:staker);
        system.delegate(delegator: delegator_1, :pool, amount: delegated_amount_1);
        system.delegate(delegator: delegator_2, :pool, amount: delegated_amount_2);
        system.delegate(delegator: delegator_3, :pool, amount: delegated_amount_3);

        let rewards_1 = system.delegator_claim_rewards(delegator: delegator_1, :pool);
        assert!(rewards_1 == Zero::zero());
        assert!(system.token.balance_of(account: delegator_1.reward.address) == Zero::zero());

        system.advance_k_epochs_and_attest(:staker);

        let rewards_1 = system
            .delegator_claim_rewards(delegator: delegator_1, :pool); // Cover zero epochs
        assert!(rewards_1 == Zero::zero());
        assert!(system.token.balance_of(account: delegator_1.reward.address) == Zero::zero());

        system.advance_k_epochs_and_attest(:staker);

        system.delegator_claim_rewards(delegator: delegator_2, :pool); // Cover one epoch

        system.advance_k_epochs_and_attest(:staker);

        system.delegator_claim_rewards(delegator: delegator_3, :pool); // Cover two epochs

        system.advance_k_epochs_and_attest(:staker);

        system.delegator_claim_rewards(delegator: delegator_2, :pool);

        system.delegator_exit_intent(delegator: delegator_1, :pool, amount: delegated_amount_1);
        system.delegator_exit_intent(delegator: delegator_2, :pool, amount: delegated_amount_2);
        system.delegator_exit_intent(delegator: delegator_3, :pool, amount: delegated_amount_3);
        system.staker_exit_intent(:staker);

        system.advance_time(time: system.staking.get_exit_wait_window());
        system.advance_epoch();

        system.delegator_exit_action(delegator: delegator_1, :pool);
        system.delegator_exit_action(delegator: delegator_2, :pool);
        system.delegator_exit_action(delegator: delegator_3, :pool);
        system.staker_exit_action(:staker);

        system.delegator_claim_rewards(delegator: delegator_1, :pool);
        system.delegator_claim_rewards(delegator: delegator_2, :pool);
        system.delegator_claim_rewards(delegator: delegator_3, :pool);

        let rewards_1 = system.token.balance_of(account: delegator_1.reward.address);
        let rewards_2 = system.token.balance_of(account: delegator_2.reward.address);
        let rewards_3 = system.token.balance_of(account: delegator_3.reward.address);

        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(
            system.token.balance_of(account: delegator_1.delegator.address) == delegated_amount_1,
        );
        assert!(
            system.token.balance_of(account: delegator_2.delegator.address) == delegated_amount_2,
        );
        assert!(
            system.token.balance_of(account: delegator_3.delegator.address) == delegated_amount_3,
        );
        assert!(system.token.balance_of(account: pool) < 100);
        assert!(rewards_1 > rewards_2);
        assert!(rewards_2 > rewards_3);
        assert!(rewards_3.is_non_zero());
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: pool)
                + rewards_1
                + rewards_2
                + rewards_3,
        );
    }
}

/// Test Pool claim_rewards flow with btc.
/// Flow:
/// Staker stake
/// Staker open btc pool
/// attest
/// Delegator1 delegate
/// Delegator2 delegate
/// Delegator3 delegate
/// Delegator1 claim_rewards
/// attest
/// Delegator1 claim_rewards - Cover zero epochs
/// attest
/// Delegator2 claim_rewards - Cover one epoch
/// attest
/// Delegator3 claim_rewards - Cover two epochs
/// attest
/// Delegator2 claim_rewards
/// Exit intent staker and all delegators
/// Exit action staker and all delegators
#[derive(Drop, Copy)]
pub(crate) struct PoolClaimRewardsFlowBtc {}
pub(crate) impl PoolClaimRewardsFlowBtcImpl of FlowTrait<PoolClaimRewardsFlowBtc> {
    fn test(self: PoolClaimRewardsFlowBtc, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let commission = 200;
        let token = system.btc_token;
        let token_address = token.contract_address();
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);

        system.stake(:staker, amount: stake_amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);
        let pool = system.set_open_for_delegation(:staker, :token_address);
        // TODO: uncomment after bugfix.
        // system.advance_k_epochs_and_attest(:staker);

        let delegated_amount_1 = stake_amount / 2;
        let delegator_1 = system.new_btc_delegator(amount: delegated_amount_1, :token);
        let delegated_amount_2 = stake_amount / 4;
        let delegator_2 = system.new_btc_delegator(amount: delegated_amount_2, :token);
        let delegated_amount_3 = stake_amount / 8;
        let delegator_3 = system.new_btc_delegator(amount: delegated_amount_3, :token);
        system.delegate_btc(delegator: delegator_1, :pool, amount: delegated_amount_1, :token);
        system.delegate_btc(delegator: delegator_2, :pool, amount: delegated_amount_2, :token);
        system.delegate_btc(delegator: delegator_3, :pool, amount: delegated_amount_3, :token);

        let rewards_1 = system.delegator_claim_rewards(delegator: delegator_1, :pool);
        assert!(rewards_1 == Zero::zero());
        assert!(system.token.balance_of(account: delegator_1.reward.address) == Zero::zero());

        system.advance_k_epochs_and_attest(:staker);

        let rewards_1 = system
            .delegator_claim_rewards(delegator: delegator_1, :pool); // Cover zero epochs
        assert!(rewards_1 == Zero::zero());
        assert!(system.token.balance_of(account: delegator_1.reward.address) == Zero::zero());

        system.advance_k_epochs_and_attest(:staker);

        system.delegator_claim_rewards(delegator: delegator_2, :pool); // Cover one epoch

        system.advance_k_epochs_and_attest(:staker);

        system.delegator_claim_rewards(delegator: delegator_3, :pool); // Cover two epochs

        system.advance_k_epochs_and_attest(:staker);

        system.delegator_claim_rewards(delegator: delegator_2, :pool);

        system.delegator_exit_intent(delegator: delegator_1, :pool, amount: delegated_amount_1);
        system.delegator_exit_intent(delegator: delegator_2, :pool, amount: delegated_amount_2);
        system.delegator_exit_intent(delegator: delegator_3, :pool, amount: delegated_amount_3);
        system.staker_exit_intent(:staker);

        system.advance_time(time: system.staking.get_exit_wait_window());
        system.advance_epoch();

        system.delegator_exit_action(delegator: delegator_1, :pool);
        system.delegator_exit_action(delegator: delegator_2, :pool);
        system.delegator_exit_action(delegator: delegator_3, :pool);
        system.staker_exit_action(:staker);

        system.delegator_claim_rewards(delegator: delegator_1, :pool);
        system.delegator_claim_rewards(delegator: delegator_2, :pool);
        system.delegator_claim_rewards(delegator: delegator_3, :pool);

        let rewards_1 = system.token.balance_of(account: delegator_1.reward.address);
        let rewards_2 = system.token.balance_of(account: delegator_2.reward.address);
        let rewards_3 = system.token.balance_of(account: delegator_3.reward.address);

        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(token.balance_of(account: delegator_1.delegator.address) == delegated_amount_1);
        assert!(token.balance_of(account: delegator_2.delegator.address) == delegated_amount_2);
        assert!(token.balance_of(account: delegator_3.delegator.address) == delegated_amount_3);
        assert!(token.balance_of(account: pool) < 100);
        assert!(rewards_1 > rewards_2);
        assert!(rewards_2 > rewards_3);
        assert!(rewards_3.is_non_zero());
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: pool)
                + rewards_1
                + rewards_2
                + rewards_3,
        );
    }
}

/// Flow:
/// Staker stake
/// Staker Attest
/// Staker exit intent
/// Staker exit action
/// Second staker stake with same operational address
/// Second staker Attest
/// Second staker exit intent
/// Second staker exit action
#[derive(Drop, Copy)]
pub(crate) struct TwoStakersSameOperationalAddressFlow {}
pub(crate) impl TwoStakersSameOperationalAddressFlowImpl of FlowTrait<
    TwoStakersSameOperationalAddressFlow,
> {
    fn test(self: TwoStakersSameOperationalAddressFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);

        let first_staker = system.new_staker(amount: stake_amount);
        system
            .stake(
                staker: first_staker, amount: stake_amount, pool_enabled: false, commission: 200,
            );
        system.advance_k_epochs_and_attest(staker: first_staker);

        system.staker_exit_intent(staker: first_staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(staker: first_staker);

        let mut second_staker = system.new_staker(amount: stake_amount);
        second_staker.operational.address = first_staker.operational.address;
        system
            .stake(
                staker: second_staker, amount: stake_amount, pool_enabled: false, commission: 200,
            );
        system.advance_k_epochs_and_attest(staker: second_staker);

        system.staker_exit_intent(staker: second_staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(staker: second_staker);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: first_staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: second_staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: first_staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: second_staker.reward.address).is_non_zero());
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: first_staker.reward.address)
                + system.token.balance_of(account: second_staker.reward.address),
        );
    }
}

/// Flow:
/// Staker stake with pool
/// First delegator delegate
/// Second delegator delegate
/// Third delegator delegate
/// First delegator full exit intent
/// Second delegator partial exit intent
/// Staker exit intent
/// Staker exit action
/// Upgrade (without upgrading the pool)
/// First delegator claim rewards
/// Second delegator claim rewards
/// Third delegator claim rewards
#[derive(Drop, Copy)]
pub(crate) struct ClaimRewardsWithNonUpgradedPoolFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) first_delegator: Option<Delegator>,
    pub(crate) first_delegator_info: Option<PoolMemberInfo>,
    pub(crate) second_delegator: Option<Delegator>,
    pub(crate) second_delegator_info: Option<PoolMemberInfo>,
    pub(crate) third_delegator: Option<Delegator>,
    pub(crate) third_delegator_info: Option<PoolMemberInfo>,
}
pub(crate) impl ClaimRewardsWithNonUpgradedPoolFlowImpl of FlowTrait<
    ClaimRewardsWithNonUpgradedPoolFlow,
> {
    fn setup(ref self: ClaimRewardsWithNonUpgradedPoolFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let first_delegator = system.new_delegator(amount: stake_amount);
        let second_delegator = system.new_delegator(amount: stake_amount);
        let third_delegator = system.new_delegator(amount: stake_amount);

        system.delegate(delegator: first_delegator, :pool, amount: stake_amount);
        system.delegate(delegator: second_delegator, :pool, amount: stake_amount);
        system.delegate(delegator: third_delegator, :pool, amount: stake_amount);
        system.advance_time(time: one_week);

        system.delegator_exit_intent(delegator: first_delegator, :pool, amount: stake_amount);
        system.delegator_exit_intent(delegator: second_delegator, :pool, amount: stake_amount / 2);
        system.advance_time(time: one_week);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        self.pool_address = Option::Some(pool);
        self.first_delegator = Option::Some(first_delegator);
        self
            .first_delegator_info =
                Option::Some(system.pool_member_info(delegator: first_delegator, :pool));
        self.second_delegator = Option::Some(second_delegator);
        self
            .second_delegator_info =
                Option::Some(system.pool_member_info(delegator: second_delegator, :pool));
        self.third_delegator = Option::Some(third_delegator);
        self
            .third_delegator_info =
                Option::Some(system.pool_member_info(delegator: third_delegator, :pool));
    }

    fn test(self: ClaimRewardsWithNonUpgradedPoolFlow, ref system: SystemState) {
        let pool = self.pool_address.unwrap();
        let first_delegator = self.first_delegator.unwrap();
        let first_delegator_info = self.first_delegator_info.unwrap();
        let second_delegator = self.second_delegator.unwrap();
        let second_delegator_info = self.second_delegator_info.unwrap();
        let third_delegator = self.third_delegator.unwrap();
        let third_delegator_info = self.third_delegator_info.unwrap();

        assert!(
            first_delegator_info
                .unclaimed_rewards == system
                .delegator_claim_rewards(delegator: first_delegator, :pool),
        );
        assert!(
            second_delegator_info
                .unclaimed_rewards == system
                .delegator_claim_rewards(delegator: second_delegator, :pool),
        );
        assert!(
            third_delegator_info
                .unclaimed_rewards == system
                .delegator_claim_rewards(delegator: third_delegator, :pool),
        );
    }
}

#[derive(Drop, Copy)]
pub(crate) struct DelegatorActionWithNonUpgradedPoolFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) first_delegator: Option<Delegator>,
    pub(crate) first_delegator_info: Option<PoolMemberInfo>,
    pub(crate) second_delegator: Option<Delegator>,
    pub(crate) second_delegator_info: Option<PoolMemberInfo>,
    pub(crate) third_delegator: Option<Delegator>,
    pub(crate) third_delegator_info: Option<PoolMemberInfo>,
    pub(crate) initial_reward_supplier_balance: Option<Amount>,
}
pub(crate) impl DelegatorActionWithNonUpgradedPoolFlowImpl of FlowTrait<
    DelegatorActionWithNonUpgradedPoolFlow,
> {
    fn setup(ref self: DelegatorActionWithNonUpgradedPoolFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let first_delegator = system.new_delegator(amount: stake_amount);
        let second_delegator = system.new_delegator(amount: stake_amount);
        let third_delegator = system.new_delegator(amount: stake_amount);

        system.delegate(delegator: first_delegator, :pool, amount: stake_amount);
        system.delegate(delegator: second_delegator, :pool, amount: stake_amount);
        system.delegate(delegator: third_delegator, :pool, amount: stake_amount);
        system.advance_time(time: one_week);

        system.delegator_exit_intent(delegator: first_delegator, :pool, amount: stake_amount);
        system.delegator_exit_intent(delegator: second_delegator, :pool, amount: stake_amount / 2);
        system.advance_time(time: one_week);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        self.staker = Option::Some(staker);
        self.pool_address = Option::Some(pool);
        self.first_delegator = Option::Some(first_delegator);
        self
            .first_delegator_info =
                Option::Some(system.pool_member_info(delegator: first_delegator, :pool));
        self.second_delegator = Option::Some(second_delegator);
        self
            .second_delegator_info =
                Option::Some(system.pool_member_info(delegator: second_delegator, :pool));
        self.third_delegator = Option::Some(third_delegator);
        self
            .third_delegator_info =
                Option::Some(system.pool_member_info(delegator: third_delegator, :pool));
        self.initial_reward_supplier_balance = Option::Some(initial_reward_supplier_balance);
    }

    fn test(self: DelegatorActionWithNonUpgradedPoolFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let pool = self.pool_address.unwrap();
        let first_delegator = self.first_delegator.unwrap();
        let first_delegator_info = self.first_delegator_info.unwrap();
        let second_delegator = self.second_delegator.unwrap();
        let second_delegator_info = self.second_delegator_info.unwrap();
        let third_delegator = self.third_delegator.unwrap();
        let third_delegator_info = self.third_delegator_info.unwrap();
        let initial_reward_supplier_balance = self.initial_reward_supplier_balance.unwrap();
        let one_week = Time::weeks(count: 1);

        // First delegator full exit action.
        system.delegator_exit_action(delegator: first_delegator, :pool);
        assert!(
            system
                .token
                .balance_of(account: first_delegator.delegator.address) == first_delegator_info
                .unpool_amount,
        );
        assert!(
            system
                .token
                .balance_of(account: first_delegator.reward.address) == first_delegator_info
                .unclaimed_rewards,
        );

        // Advancing time in order to make sure that it doesn't add rewards.
        system.advance_time(time: one_week);

        // Second delegator partial exit action.
        system.delegator_exit_action(delegator: second_delegator, :pool);
        assert!(
            system
                .token
                .balance_of(account: second_delegator.delegator.address) == second_delegator_info
                .unpool_amount,
        );

        // Second delegator full exit intent and action.
        system
            .delegator_exit_intent(
                delegator: second_delegator, :pool, amount: second_delegator_info.amount,
            );
        system.delegator_exit_action(delegator: second_delegator, :pool);
        assert!(
            system
                .token
                .balance_of(account: second_delegator.delegator.address) == second_delegator_info
                .unpool_amount
                + second_delegator_info.amount,
        );
        assert!(
            system
                .token
                .balance_of(account: second_delegator.reward.address) == second_delegator_info
                .unclaimed_rewards,
        );

        // Third delegator full exit intent and action.
        system
            .delegator_exit_intent(
                delegator: third_delegator, :pool, amount: third_delegator_info.amount,
            );
        system.delegator_exit_action(delegator: third_delegator, :pool);
        assert!(
            system
                .token
                .balance_of(account: third_delegator.delegator.address) == third_delegator_info
                .amount,
        );
        assert!(
            system
                .token
                .balance_of(account: third_delegator.reward.address) == third_delegator_info
                .unclaimed_rewards,
        );

        // Assert pool balance is near-zero.
        assert!(system.token.balance_of(account: pool) < 100);

        // Assert all staked amounts were transferred back.
        assert!(system.token.balance_of(account: system.staking.address).is_zero());

        // Assert all funds that moved from rewards supplier, were moved to correct addresses.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: pool)
                + system.token.balance_of(account: first_delegator.reward.address)
                + system.token.balance_of(account: second_delegator.reward.address)
                + system.token.balance_of(account: third_delegator.reward.address),
        );
    }
}

/// Flow:
/// Staker stake with pool
/// First delegator delegate
/// Second delegator delegate
/// Third delegator delegate
/// First delegator full exit intent
/// Second delegator partial exit intent
/// Staker exit intent
/// Staker exit action
/// Upgrade (without upgrading the pool)
/// New staker stake with pool
/// First delegator switch
/// Second delegator switch
#[derive(Drop, Copy)]
pub(crate) struct SwitchWithNonUpgradedPoolFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) first_delegator: Option<Delegator>,
    pub(crate) second_delegator: Option<Delegator>,
    pub(crate) stake_amount: Option<Amount>,
}
pub(crate) impl SwitchWithNonUpgradedPoolFlowImpl of FlowTrait<SwitchWithNonUpgradedPoolFlow> {
    fn setup(ref self: SwitchWithNonUpgradedPoolFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let first_delegator = system.new_delegator(amount: stake_amount);
        let second_delegator = system.new_delegator(amount: stake_amount);
        let third_delegator = system.new_delegator(amount: stake_amount);

        system.delegate(delegator: first_delegator, :pool, amount: stake_amount);
        system.delegate(delegator: second_delegator, :pool, amount: stake_amount);
        system.delegate(delegator: third_delegator, :pool, amount: stake_amount);
        system.advance_time(time: one_week);

        system.delegator_exit_intent(delegator: first_delegator, :pool, amount: stake_amount);
        system.delegator_exit_intent(delegator: second_delegator, :pool, amount: stake_amount / 2);
        system.advance_time(time: one_week);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        self.pool_address = Option::Some(pool);
        self.first_delegator = Option::Some(first_delegator);
        self.second_delegator = Option::Some(second_delegator);
        self.stake_amount = Option::Some(stake_amount);
    }

    fn test(self: SwitchWithNonUpgradedPoolFlow, ref system: SystemState) {
        let pool = self.pool_address.unwrap();
        let first_delegator = self.first_delegator.unwrap();
        let second_delegator = self.second_delegator.unwrap();
        let stake_amount = self.stake_amount.unwrap();
        let commission = 200;

        let to_staker = system.new_staker(amount: stake_amount);
        system.stake(staker: to_staker, amount: stake_amount, pool_enabled: true, :commission);
        let to_pool = system.staking.get_pool(staker: to_staker);

        system
            .switch_delegation_pool(
                delegator: first_delegator,
                from_pool: pool,
                to_staker: to_staker.staker.address,
                :to_pool,
                amount: stake_amount,
            );
        assert!(system.get_pool_member_info(delegator: first_delegator, :pool).is_none());
        assert!(
            system
                .pool_member_info_v1(delegator: first_delegator, pool: to_pool)
                .amount == stake_amount,
        );

        system
            .switch_delegation_pool(
                delegator: second_delegator,
                from_pool: pool,
                to_staker: to_staker.staker.address,
                :to_pool,
                amount: stake_amount / 2,
            );
        assert!(
            system.pool_member_info(delegator: second_delegator, :pool).amount == stake_amount / 2,
        );
        assert!(
            system
                .pool_member_info_v1(delegator: second_delegator, pool: to_pool)
                .amount == stake_amount
                / 2,
        );
        // TODO: Intent and switch with a third delegator and catch `MISSING_UNDELEGATE_INTENT`.
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Delegator exit intent
/// Delegator exit action
/// Upgrade
/// Delegator enter
#[derive(Drop, Copy)]
pub(crate) struct DelegatorExitBeforeEnterAfterFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
}
pub(crate) impl DelegatorExitBeforeEnterAfterFlowImpl of FlowTrait<
    DelegatorExitBeforeEnterAfterFlow,
> {
    fn setup(ref self: DelegatorExitBeforeEnterAfterFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount);
        system.advance_time(time: one_week);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.delegator_exit_action(:delegator, :pool);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        system.set_pool_for_upgrade(pool_address: pool);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: DelegatorExitBeforeEnterAfterFlow, ref system: SystemState) {
        let pool = self.pool_address.unwrap();
        let delegator = self.delegator.unwrap();
        let delegate_amount = 100;

        system.delegate(:delegator, :pool, amount: delegate_amount);
        assert!(system.pool_member_info_v1(:delegator, :pool).amount == delegate_amount);
    }
}

/// Test attest with total_btc_stake = 0
/// Flow:
/// Staker stake
/// Staker open btc pool
/// Staker attest
/// Test no rewards for btc pool
#[derive(Drop, Copy)]
pub(crate) struct AttestWithZeroTotalBtcStakeFlow {}
pub(crate) impl AttestWithZeroTotalBtcStakeFlowImpl of FlowTrait<AttestWithZeroTotalBtcStakeFlow> {
    fn test(self: AttestWithZeroTotalBtcStakeFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);
        let token_address = system.btc_token.contract_address();

        let pool = system.set_open_for_delegation(:staker, :token_address);
        system.advance_k_epochs_and_attest(:staker);

        let pool_balance = system.token.balance_of(account: pool);
        assert!(pool_balance == 0);
    }
}

/// Flow:
/// Staker stake with pool
/// First delegator delegate
/// Second delegator delegate
/// Third delegator delegate
/// Third delegator exit intent
/// Staker exit intent
/// Staker exit action
/// Upgrade (without upgrading the pool)
/// First delegator exit intent
/// First delegator exit action
/// Second delegator exit intent
/// Second delegator exit action
/// Third delegator exit intent
#[derive(Drop, Copy)]
pub(crate) struct DelegatorExitWithNonUpgradedPoolFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) first_delegator: Option<Delegator>,
    pub(crate) first_delegator_info: Option<PoolMemberInfo>,
    pub(crate) second_delegator: Option<Delegator>,
    pub(crate) second_delegator_info: Option<PoolMemberInfo>,
    pub(crate) third_delegator: Option<Delegator>,
    pub(crate) third_delegator_info: Option<PoolMemberInfo>,
}
pub(crate) impl DelegatorExitWithNonUpgradedPoolFlowImpl of FlowTrait<
    DelegatorExitWithNonUpgradedPoolFlow,
> {
    fn setup(ref self: DelegatorExitWithNonUpgradedPoolFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let first_delegator = system.new_delegator(amount: stake_amount);
        let second_delegator = system.new_delegator(amount: stake_amount);
        let third_delegator = system.new_delegator(amount: stake_amount);

        system.delegate(delegator: first_delegator, :pool, amount: stake_amount);
        system.delegate(delegator: second_delegator, :pool, amount: stake_amount);
        system.delegate(delegator: third_delegator, :pool, amount: stake_amount);
        system.advance_time(time: one_week);

        system.delegator_exit_intent(delegator: third_delegator, :pool, amount: stake_amount);
        system.advance_time(time: one_week);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        self.pool_address = Option::Some(pool);
        self.first_delegator = Option::Some(first_delegator);
        self
            .first_delegator_info =
                Option::Some(system.pool_member_info(delegator: first_delegator, :pool));
        self.second_delegator = Option::Some(second_delegator);
        self
            .second_delegator_info =
                Option::Some(system.pool_member_info(delegator: second_delegator, :pool));
        self.third_delegator = Option::Some(third_delegator);
        self
            .third_delegator_info =
                Option::Some(system.pool_member_info(delegator: third_delegator, :pool));
    }

    fn test(self: DelegatorExitWithNonUpgradedPoolFlow, ref system: SystemState) {
        let pool = self.pool_address.unwrap();
        let first_delegator = self.first_delegator.unwrap();
        let first_delegator_info = self.first_delegator_info.unwrap();
        let second_delegator = self.second_delegator.unwrap();
        let second_delegator_info = self.second_delegator_info.unwrap();
        let third_delegator = self.third_delegator.unwrap();
        let third_delegator_info = self.third_delegator_info.unwrap();

        system
            .delegator_exit_intent(
                delegator: first_delegator, :pool, amount: first_delegator_info.amount,
            );
        assert!(system.pool_member_info(delegator: first_delegator, :pool).amount.is_zero());
        assert!(
            system
                .pool_member_info(delegator: first_delegator, :pool)
                .unpool_amount == first_delegator_info
                .amount,
        );
        system.delegator_exit_action(delegator: first_delegator, :pool);
        assert!(
            system
                .token
                .balance_of(account: first_delegator.delegator.address) == first_delegator_info
                .amount,
        );

        system
            .delegator_exit_intent(
                delegator: second_delegator, :pool, amount: second_delegator_info.amount / 2,
            );
        assert!(
            system
                .pool_member_info(delegator: second_delegator, :pool)
                .amount == second_delegator_info
                .amount
                / 2,
        );
        assert!(
            system
                .pool_member_info(delegator: second_delegator, :pool)
                .unpool_amount == second_delegator_info
                .amount
                / 2,
        );
        system.delegator_exit_action(delegator: second_delegator, :pool);
        assert!(
            system
                .token
                .balance_of(account: second_delegator.delegator.address) == second_delegator_info
                .amount
                / 2,
        );

        cheat_caller_address_once(
            contract_address: pool, caller_address: third_delegator.delegator.address,
        );
        let result = system
            .safe_delegator_exit_intent(
                delegator: third_delegator, :pool, amount: third_delegator_info.amount,
            );
        assert_panic_with_error(result, PoolError::UNDELEGATE_IN_PROGRESS.describe());
    }
}

/// Test add token without enable
/// Flow:
/// Staker stake
/// Add token
/// Staker open pool with new token
/// Delegator delegate
/// Staker attest
/// Test no pool rewards
#[derive(Drop, Copy)]
pub(crate) struct AddTokenWithoutEnableFlow {}
pub(crate) impl AddTokenWithoutEnableFlowImpl of FlowTrait<AddTokenWithoutEnableFlow> {
    fn test(self: AddTokenWithoutEnableFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.set_commission(:staker, :commission);
        let token = system.deploy_second_btc_token();
        system.staking.add_token(token_address: token.contract_address());

        let pool = system.set_open_for_delegation(:staker, token_address: token.contract_address());

        let delegator = system.new_btc_delegator(:amount, :token);
        system.delegate_btc(:delegator, :pool, :amount, :token);

        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        let delegator_rewards = system.delegator_claim_rewards(:delegator, :pool);
        let unclaimed_rewards = system.reward_supplier.get_unclaimed_rewards();
        let staker_info = system.staker_info_v1(:staker);
        let (expected_staker_rewards, _) = calculate_staker_strk_rewards_v2(
            :staker_info, :staking_contract, :minting_curve_contract,
        );
        assert!(delegator_rewards == Zero::zero());
        assert!(wide_abs_diff(unclaimed_rewards, expected_staker_rewards) == STRK_IN_FRIS.into());
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Delegator exit intent
/// Delegator exit action
/// Delegator add to delegation
#[derive(Drop, Copy)]
pub(crate) struct AddToDelegationAfterExitActionFlow {}
pub(crate) impl AddToDelegationAfterExitActionFlowImpl of FlowTrait<
    AddToDelegationAfterExitActionFlow,
> {
    fn test(self: AddToDelegationAfterExitActionFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let commission = 200;

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);

        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.delegator_exit_action(:delegator, :pool);
        assert!(system.pool_member_info_v1(:delegator, :pool).amount.is_zero());

        system.increase_delegate(:delegator, :pool, amount: stake_amount);
        system.advance_k_epochs_and_attest(:staker);
        system.advance_epoch();

        assert!(system.pool_member_info_v1(:delegator, :pool).amount == stake_amount);
        assert!(system.pool_member_info_v1(:delegator, :pool).unclaimed_rewards.is_non_zero());
    }
}

/// Flow:
/// Staker stake
/// Set epoch info
/// Staker attest
/// Advance epoch
/// Assert epoch rewards are changed
#[derive(Drop, Copy)]
pub(crate) struct SetEpochInfoFlow {}
pub(crate) impl SetEpochInfoFlowImpl of FlowTrait<SetEpochInfoFlow> {
    fn test(self: SetEpochInfoFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let commission = 200;

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs();

        let target_block_before_set = system
            .attestation
            .unwrap()
            .get_current_epoch_target_attestation_block(
                operational_address: staker.operational.address,
            );
        let (strk_epoch_rewards_before_set, btc_epoch_rewards_before_set) = system
            .reward_supplier
            .calculate_current_epoch_rewards();
        assert!(strk_epoch_rewards_before_set.is_non_zero());
        assert!(btc_epoch_rewards_before_set.is_non_zero());

        // Set new epoch info.
        let new_epoch_duration = EPOCH_DURATION * 15;
        let new_epoch_length = system.staking.get_epoch_info().epoch_len_in_blocks() * 15;
        system
            .staking
            .set_epoch_info(epoch_duration: new_epoch_duration, epoch_length: new_epoch_length);

        let target_block_after_set = system
            .attestation
            .unwrap()
            .get_current_epoch_target_attestation_block(
                operational_address: staker.operational.address,
            );
        assert!(target_block_after_set == target_block_before_set);

        let (strk_epoch_rewards_after_set, btc_epoch_rewards_after_set) = system
            .reward_supplier
            .calculate_current_epoch_rewards();
        assert!(strk_epoch_rewards_after_set == strk_epoch_rewards_before_set);
        assert!(btc_epoch_rewards_after_set == btc_epoch_rewards_before_set);

        // Advance block into attestation window and attest.
        start_cheat_block_number_global(
            block_number: MIN_ATTESTATION_WINDOW.into() + target_block_after_set,
        );
        system.attest(:staker);
        assert!(
            strk_epoch_rewards_after_set == system.staker_info_v1(:staker).unclaimed_rewards_own,
        );

        system.advance_epoch();
        let (strk_epoch_rewards_after_advance_epoch, btc_epoch_rewards_after_advance_epoch) = system
            .reward_supplier
            .calculate_current_epoch_rewards();
        assert!(strk_epoch_rewards_after_advance_epoch > strk_epoch_rewards_before_set);
        assert!(btc_epoch_rewards_after_advance_epoch > btc_epoch_rewards_before_set);
    }
}

/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Delegator exit intent
/// Staker Attest
/// Assert zero rewards for the delegator
#[derive(Drop, Copy)]
pub(crate) struct AttestAfterDelegatorIntentFlow {}
pub(crate) impl AttestAfterDelegatorIntentFlowImpl of FlowTrait<AttestAfterDelegatorIntentFlow> {
    fn test(self: AttestAfterDelegatorIntentFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let commission = 200;

        let staker = system.new_staker(amount: stake_amount);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs();

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount);

        system.advance_block_into_attestation_window(:staker);
        system.attest(:staker);

        assert!(system.pool_member_info_v1(:delegator, :pool).unclaimed_rewards.is_zero());
    }
}

/// Test calculate rewards twice
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// attest
/// attest
/// pool_member_info
/// attest
/// attest
/// pool_member_info
#[derive(Drop, Copy)]
pub(crate) struct PoolCalculateRewardsTwiceFlow {}
pub(crate) impl PoolCalculateRewardsTwiceFlowImpl of FlowTrait<PoolCalculateRewardsTwiceFlow> {
    fn test(self: PoolCalculateRewardsTwiceFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let commission = 200;
        let staking_contract = system.staking.address;
        let minting_curve_contract = system.minting_curve.address;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_k_epochs_and_attest(:staker);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);

        let pool_rewards_one_epoch = calculate_strk_pool_rewards_v2(
            staker_address: staker.staker.address, :staking_contract, :minting_curve_contract,
        );

        let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
        assert!(pool_member_info.unclaimed_rewards == pool_rewards_one_epoch);

        system.advance_k_epochs_and_attest(:staker);
        system.advance_k_epochs_and_attest(:staker);

        let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
        assert!(pool_member_info.unclaimed_rewards == 3 * pool_rewards_one_epoch);
    }
}

/// Test diverse staker vector
/// (staker with pool, staker without pool, staker in intent, staker in action)
/// Flow:
/// Staker1 stake with pool
/// Staker2 stake
/// Staker3 stake with pool
/// Staker4 stake with pool
/// Staker4 exit intent
/// Advance time
/// Staker4 exit action
/// Staker3 exit intent
#[derive(Drop, Copy)]
pub(crate) struct DiverseStakerVecFlow {}
pub(crate) impl DiverseStakerVecFlowImpl of FlowTrait<DiverseStakerVecFlow> {
    fn test(self: DiverseStakerVecFlow, ref system: SystemState) {
        let stake_amount = system.staking.get_min_stake();
        let commission = 200;

        let staker_with_pool = system.new_staker(amount: stake_amount);
        let staker_without_pool = system.new_staker(amount: stake_amount);
        let staker_in_intent = system.new_staker(amount: stake_amount);
        let staker_in_action = system.new_staker(amount: stake_amount);

        system
            .stake(staker: staker_with_pool, amount: stake_amount, pool_enabled: true, :commission);
        system
            .stake(
                staker: staker_without_pool, amount: stake_amount, pool_enabled: false, :commission,
            );
        system
            .stake(staker: staker_in_intent, amount: stake_amount, pool_enabled: true, :commission);
        system
            .stake(staker: staker_in_action, amount: stake_amount, pool_enabled: true, :commission);

        system.staker_exit_intent(staker: staker_in_action);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(staker: staker_in_action);

        system.staker_exit_intent(staker: staker_in_intent);

        let actual_stakers = system.staking.get_stakers();
        assert!(actual_stakers.len() == 4);
        assert!(actual_stakers.at(index: 0) == @staker_with_pool.staker.address);
        assert!(actual_stakers.at(index: 1) == @staker_without_pool.staker.address);
        assert!(actual_stakers.at(index: 2) == @staker_in_intent.staker.address);
        assert!(actual_stakers.at(index: 3) == @staker_in_action.staker.address);
    }
}

/// Test multiple stakers migration
/// Flow:
/// Staker1 stake
/// Staker2 stake
/// Upgrade
/// Migrate stakers
/// Test stakers in stakers vector
/// Staker3 stake
/// Test stakers in stakers vector
#[derive(Drop, Copy)]
pub(crate) struct MultipleStakersMigrationVecFlow {
    pub(crate) old_stakers: Option<(Staker, Staker)>,
}
pub(crate) impl MultipleStakersMigrationVecFlowImpl of FlowTrait<MultipleStakersMigrationVecFlow> {
    fn setup_v1(ref self: MultipleStakersMigrationVecFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker1 = system.new_staker(:amount);
        let staker2 = system.new_staker(:amount);
        let commission = 200;
        system.stake(staker: staker1, :amount, pool_enabled: false, :commission);
        system.stake(staker: staker2, :amount, pool_enabled: false, :commission);

        system.set_staker_for_migration(staker_address: staker1.staker.address);
        system.set_staker_for_migration(staker_address: staker2.staker.address);
        self.old_stakers = Option::Some((staker1, staker2));
    }

    fn test(self: MultipleStakersMigrationVecFlow, ref system: SystemState) {
        let old_stakers = self.old_stakers.unwrap();
        let (staker1, staker2) = old_stakers;

        let actual_stakers = system.staking.get_stakers();
        assert!(actual_stakers == array![staker1.staker.address, staker2.staker.address].span());

        let amount = system.staking.get_min_stake();
        let staker3 = system.new_staker(:amount);
        let commission = 200;
        system.stake(staker: staker3, :amount, pool_enabled: false, :commission);

        let actual_stakers = system.staking.get_stakers();
        assert!(
            actual_stakers == array![
                staker1.staker.address, staker2.staker.address, staker3.staker.address,
            ]
                .span(),
        );
    }
}

/// Test staker without pool migration open pools
/// Flow:
/// Staker stake
/// Upgrade
/// Staker migration
/// Staker open btc pool
/// Staker open strk pool
/// Staker open btc pool with the same token (should fail)
/// Test staker_pool_info
#[derive(Drop, Copy)]
pub(crate) struct StakerWithoutPoolMigrationOpenPoolsFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl StakerWithoutPoolMigrationOpenPoolsFlowImpl of FlowTrait<
    StakerWithoutPoolMigrationOpenPoolsFlow,
> {
    fn setup_v1(ref self: StakerWithoutPoolMigrationOpenPoolsFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
    }
    fn test(self: StakerWithoutPoolMigrationOpenPoolsFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let commission = 100;
        system.set_commission(:staker, :commission);

        // Open pools.
        let btc_pool_contract = system
            .set_open_for_delegation(:staker, token_address: system.btc_token.contract_address());
        let strk_pool_contract = system
            .set_open_for_delegation(:staker, token_address: system.token.contract_address());

        // Try to open a second btc pool with the same token.
        let res = system
            .safe_set_open_for_delegation(
                staker: staker, token_address: system.btc_token.contract_address(),
            );
        assert_panic_with_error(res, StakingError::STAKER_ALREADY_HAS_POOL.describe());

        // Assert pool info.
        let expected_pool_info = StakerPoolInfoV2 {
            commission: Option::Some(commission),
            pools: array![
                PoolInfo {
                    pool_contract: btc_pool_contract,
                    token_address: system.btc_token.contract_address(),
                    amount: 0,
                },
                PoolInfo {
                    pool_contract: strk_pool_contract,
                    token_address: system.token.contract_address(),
                    amount: 0,
                },
            ]
                .span(),
        };
        let staker_pool_info = system.staker_pool_info(:staker);
        assert!(staker_pool_info == expected_pool_info);
        let expected_class_hash = declare_pool_contract();
        assert!(get_class_hash(contract_address: btc_pool_contract) == expected_class_hash);
        assert!(get_class_hash(contract_address: strk_pool_contract) == expected_class_hash);
    }
}

/// Flow:
/// Staker stake with pool
/// Upgrade
/// Staker migration
/// Staker set commission
/// Test staker pool info commission is set
#[derive(Drop, Copy)]
pub(crate) struct StakerWithPoolMigrationSetCommissionFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl StakerWithPoolMigrationSetCommissionFlowImpl of FlowTrait<
    StakerWithPoolMigrationSetCommissionFlow,
> {
    fn setup_v1(ref self: StakerWithPoolMigrationSetCommissionFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
    }
    fn test(self: StakerWithPoolMigrationSetCommissionFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();

        system.set_commission(:staker, commission: 100);
        let staker_pool_info = system.staker_pool_info(:staker);
        assert!(staker_pool_info.commission == Option::Some(100));
        // TODO: Test rewards with commission, and use multiversion.
    }
}

/// Flow:
/// Staker stake
/// Staker exit intent
/// Upgrade
/// Staker migration
/// Advance time
/// Staker exit action
/// Test staker does not exist
#[derive(Drop, Copy)]
pub(crate) struct StakerExitFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) exit_wait_window: Option<TimeDelta>,
}
pub(crate) impl StakerExitFlowImpl of MultiVersionFlowTrait<StakerExitFlow> {
    fn versions(self: StakerExitFlow) -> Span<ReleaseVersion> {
        [V1, V2].span()
    }

    fn setup(ref self: StakerExitFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.staker_exit_intent(:staker);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
        self.exit_wait_window = Option::Some(system.staking.get_exit_wait_window());
    }

    #[feature("safe_dispatcher")]
    fn test(self: StakerExitFlow, ref system: SystemState, version: ReleaseVersion) {
        let staker = self.staker.unwrap();
        let exit_wait_window = self.exit_wait_window.unwrap();
        system.advance_time(time: exit_wait_window);
        system.staker_exit_action(:staker);

        let res = system
            .staking
            .safe_dispatcher()
            .staker_info_v1(staker_address: staker.staker.address);
        assert_panic_with_error(res, StakingError::STAKER_NOT_EXISTS.describe());
    }
}

/// Flow:
/// Staker stake
/// Staker exit intent
/// Upgrade
/// Staker migration
/// Test staker attestation fails
#[derive(Drop, Copy)]
pub(crate) struct StakerExitIntentAttestAfterMigrationFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl StakerExitIntentAttestAfterMigrationFlowImpl of MultiVersionFlowTrait<
    StakerExitIntentAttestAfterMigrationFlow,
> {
    fn versions(self: StakerExitIntentAttestAfterMigrationFlow) -> Span<ReleaseVersion> {
        [V1, V2].span()
    }

    fn setup(ref self: StakerExitIntentAttestAfterMigrationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.advance_epoch();
        system.staker_exit_intent(:staker);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
    }

    #[feature("safe_dispatcher")]
    fn test(
        self: StakerExitIntentAttestAfterMigrationFlow,
        ref system: SystemState,
        version: ReleaseVersion,
    ) {
        let staker = self.staker.unwrap();

        system.advance_block_into_attestation_window(:staker);
        let res = system.safe_attest(:staker);
        assert_panic_with_error(res, StakingError::UNSTAKE_IN_PROGRESS.describe());
    }
}

/// Test staker address already used in older version of the contract
/// Flow:
/// Stake
/// Staker exit
/// Upgrade to V2
/// Stake
/// Staker exit
/// Upgrade to V3
/// Attempt stake both stakers
#[derive(Drop, Copy)]
pub(crate) struct StakerAddressAlreadyUsedInOlderVersionFlow {
    pub(crate) staker_v1: Option<Staker>,
    pub(crate) staker_v2: Option<Staker>,
}
pub(crate) impl StakerAddressAlreadyUsedInOlderVersionFlowImpl of FlowTrait<
    StakerAddressAlreadyUsedInOlderVersionFlow,
> {
    fn setup_v1(ref self: StakerAddressAlreadyUsedInOlderVersionFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.staker_exit_intent(:staker);
        system.advance_exit_wait_window();
        system.staker_exit_action(:staker);

        self.staker_v1 = Option::Some(staker);
    }

    fn setup_v2(ref self: StakerAddressAlreadyUsedInOlderVersionFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);
        system.staker_exit_intent(:staker);
        system.advance_exit_wait_window();
        system.staker_exit_action(:staker);

        self.staker_v2 = Option::Some(staker);
    }

    #[feature("safe_dispatcher")]
    fn test(self: StakerAddressAlreadyUsedInOlderVersionFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker_v1 = self.staker_v1.unwrap();
        let staker_v2 = self.staker_v2.unwrap();

        let result = system.safe_stake(staker: staker_v1, :amount);
        assert_panic_with_error(result, StakingError::STAKER_ADDRESS_ALREADY_USED_IN_V1.describe());
        let result = system.safe_stake(staker: staker_v2, :amount);
        assert_panic_with_error(result, StakingError::STAKER_ADDRESS_ALREADY_USED.describe());
    }
}

/// Flow:
/// Create btc token
/// Enable btc token
/// Try to disable btc token
/// Advance epoch
/// Disable btc token
/// Test btc token is disabled
#[derive(Drop, Copy)]
pub(crate) struct EnableDisableBtcTokenSameEpochFlow {}
pub(crate) impl EnableDisableBtcTokenSameEpochFlowImpl of FlowTrait<
    EnableDisableBtcTokenSameEpochFlow,
> {
    fn test(self: EnableDisableBtcTokenSameEpochFlow, ref system: SystemState) {
        system.advance_k_epochs();
        let expected_active_tokens = system.staking.dispatcher().get_active_tokens();

        let token_address = system.deploy_second_btc_token().contract_address();
        system.staking.add_token(:token_address);
        system.staking.enable_token(:token_address);
        let res = system.staking.safe_disable_token(:token_address);
        assert_panic_with_error(res, StakingError::INVALID_EPOCH.describe());
        system.advance_epoch();
        let res = system.staking.safe_disable_token(:token_address);
        assert_panic_with_error(res, StakingError::INVALID_EPOCH.describe());
        system.advance_epoch();
        system.staking.disable_token(:token_address);
        system.advance_k_epochs();
        let active_tokens = system.staking.dispatcher().get_active_tokens();
        assert!(active_tokens == expected_active_tokens);
    }
}

/// Flow:
/// Disable btc token
/// Try to enable btc token
/// Advance epoch
/// Enable btc token
/// Test btc token is enabled
#[derive(Drop, Copy)]
pub(crate) struct DisableEnableBtcTokenSameEpochFlow {}
pub(crate) impl DisableEnableBtcTokenSameEpochFlowImpl of FlowTrait<
    DisableEnableBtcTokenSameEpochFlow,
> {
    fn test(self: DisableEnableBtcTokenSameEpochFlow, ref system: SystemState) {
        let expected_active_tokens = system.staking.dispatcher().get_active_tokens();
        let token_address = system.btc_token.contract_address();
        system.advance_k_epochs();
        system.staking.disable_token(:token_address);
        let res = system.staking.safe_enable_token(:token_address);
        assert_panic_with_error(res, StakingError::INVALID_EPOCH.describe());
        system.advance_epoch();
        let res = system.staking.safe_enable_token(:token_address);
        assert_panic_with_error(res, StakingError::INVALID_EPOCH.describe());
        system.advance_epoch();
        system.staking.enable_token(:token_address);

        let active_tokens = system.staking.dispatcher().get_active_tokens();
        assert!(active_tokens == expected_active_tokens);
    }
}

#[derive(Drop, Copy)]
pub(crate) struct PoolEICFlow {
    pub(crate) pool_v0: Option<ContractAddress>,
    pub(crate) pool_v1: Option<ContractAddress>,
    pub(crate) pool_v2: Option<ContractAddress>,
    pub(crate) pool_btc_8d_v2: Option<ContractAddress>,
    pub(crate) pool_btc_18d_v2: Option<ContractAddress>,
}
pub(crate) impl PoolEICFlowImpl of FlowTrait<PoolEICFlow> {
    fn setup(ref self: PoolEICFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool_address = system.staking.get_pool(:staker);
        self.pool_v0 = Option::Some(pool_address);
        system.set_pool_for_upgrade(pool_address: pool_address);
    }

    fn setup_v1(ref self: PoolEICFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool_address = system.staking.get_pool(:staker);
        self.pool_v1 = Option::Some(pool_address);
    }

    fn setup_v2(ref self: PoolEICFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool_address = system.staking.get_pool(:staker);
        self.pool_v2 = Option::Some(pool_address);
        // Open BTC pool with 8 decimals.
        let btc_8d_token = system.btc_token;
        let btc_8d_token_address = btc_8d_token.contract_address();
        let pool_btc_8d = system
            .set_open_for_delegation(:staker, token_address: btc_8d_token_address);
        self.pool_btc_8d_v2 = Option::Some(pool_btc_8d);
        // Open BTC pool with 18 decimals.
        let btc_18d_token = system.deploy_second_btc_token();
        let btc_18d_token_address = btc_18d_token.contract_address();
        system.staking.add_token(token_address: btc_18d_token_address);
        system.staking.enable_token(token_address: btc_18d_token_address);
        let pool_btc_18d = system
            .set_open_for_delegation(:staker, token_address: btc_18d_token_address);
        self.pool_btc_18d_v2 = Option::Some(pool_btc_18d);
    }

    fn test(self: PoolEICFlow, ref system: SystemState) {
        let pools = [
            self.pool_v0.unwrap(), self.pool_v1.unwrap(), self.pool_v2.unwrap(),
            self.pool_btc_8d_v2.unwrap(), self.pool_btc_18d_v2.unwrap(),
        ];

        // Test storage variables before upgrade.
        // Test storage variables of old STRK pools.
        let strk_pools_before_v2 = [self.pool_v0.unwrap(), self.pool_v1.unwrap()];
        for strk_pool in strk_pools_before_v2.span() {
            let min_delegation_for_rewards: Amount = load_one_felt(
                target: *strk_pool, storage_address: selector!("min_delegation_for_rewards"),
            )
                .try_into()
                .unwrap();
            assert!(min_delegation_for_rewards.is_zero());
            let staking_rewards_base_value: Amount = load_one_felt(
                target: *strk_pool, storage_address: selector!("staking_rewards_base_value"),
            )
                .try_into()
                .unwrap();
            assert!(staking_rewards_base_value.is_zero());
        }
        // Test storage variables of new STRK pool.
        let strk_pool = self.pool_v2.unwrap();
        let min_delegation_for_rewards: Amount = load_one_felt(
            target: strk_pool, storage_address: selector!("min_delegation_for_rewards"),
        )
            .try_into()
            .unwrap();
        assert!(min_delegation_for_rewards == STRK_CONFIG.min_for_rewards);
        let staking_rewards_base_value: Amount = load_one_felt(
            target: strk_pool, storage_address: selector!("staking_rewards_base_value"),
        )
            .try_into()
            .unwrap();
        assert!(staking_rewards_base_value == STRK_CONFIG.base_value);
        // Test storage variables of 8 decimals BTC pool.
        let btc_8d_pool = self.pool_btc_8d_v2.unwrap();
        let min_delegation_for_rewards: Amount = load_one_felt(
            target: btc_8d_pool, storage_address: selector!("min_delegation_for_rewards"),
        )
            .try_into()
            .unwrap();
        assert!(min_delegation_for_rewards == BTC_8D_CONFIG.min_for_rewards);
        let staking_rewards_base_value: Amount = load_one_felt(
            target: btc_8d_pool, storage_address: selector!("staking_rewards_base_value"),
        )
            .try_into()
            .unwrap();
        assert!(staking_rewards_base_value == BTC_8D_CONFIG.base_value);
        // Test storage variables of 18 decimals BTC pool.
        let btc_18d_pool = self.pool_btc_18d_v2.unwrap();
        let min_delegation_for_rewards: Amount = load_one_felt(
            target: btc_18d_pool, storage_address: selector!("min_delegation_for_rewards"),
        )
            .try_into()
            .unwrap();
        assert!(min_delegation_for_rewards == BTC_18D_CONFIG.min_for_rewards);
        let staking_rewards_base_value: Amount = load_one_felt(
            target: btc_18d_pool, storage_address: selector!("staking_rewards_base_value"),
        )
            .try_into()
            .unwrap();
        assert!(staking_rewards_base_value == BTC_18D_CONFIG.base_value);

        // Upgrade pools.
        for pool in pools.span() {
            // Upgrade pool using EIC.
            let eic_data = EICData {
                eic_hash: declare_pool_eic_contract(), eic_init_data: [].span(),
            };
            let implementation_data = ImplementationData {
                impl_hash: declare_pool_contract(), eic_data: Option::Some(eic_data), final: false,
            };
            upgrade_implementation(
                contract_address: *pool,
                :implementation_data,
                upgrade_governor: system.staking.address,
            );
        }

        // Test storage variables after upgrade.
        // Test storage variables of STRK pools.
        let strk_pools = [self.pool_v0.unwrap(), self.pool_v1.unwrap(), self.pool_v2.unwrap()];
        for strk_pool in strk_pools.span() {
            let min_delegation_for_rewards: Amount = load_one_felt(
                target: *strk_pool, storage_address: selector!("min_delegation_for_rewards"),
            )
                .try_into()
                .unwrap();
            assert!(min_delegation_for_rewards == STRK_CONFIG.min_for_rewards);
            let staking_rewards_base_value: Amount = load_one_felt(
                target: *strk_pool, storage_address: selector!("staking_rewards_base_value"),
            )
                .try_into()
                .unwrap();
            assert!(staking_rewards_base_value == STRK_CONFIG.base_value);
        }
        // Test storage variables of 8 decimals BTC pool.
        let btc_8d_pool = self.pool_btc_8d_v2.unwrap();
        let min_delegation_for_rewards: Amount = load_one_felt(
            target: btc_8d_pool, storage_address: selector!("min_delegation_for_rewards"),
        )
            .try_into()
            .unwrap();
        assert!(min_delegation_for_rewards == BTC_8D_CONFIG.min_for_rewards);
        let staking_rewards_base_value: Amount = load_one_felt(
            target: btc_8d_pool, storage_address: selector!("staking_rewards_base_value"),
        )
            .try_into()
            .unwrap();
        assert!(staking_rewards_base_value == BTC_8D_CONFIG.base_value);
        // Test storage variables of 18 decimals BTC pool.
        let btc_18d_pool = self.pool_btc_18d_v2.unwrap();
        let min_delegation_for_rewards: Amount = load_one_felt(
            target: btc_18d_pool, storage_address: selector!("min_delegation_for_rewards"),
        )
            .try_into()
            .unwrap();
        assert!(min_delegation_for_rewards == BTC_18D_CONFIG.min_for_rewards);
        let staking_rewards_base_value: Amount = load_one_felt(
            target: btc_18d_pool, storage_address: selector!("staking_rewards_base_value"),
        )
            .try_into()
            .unwrap();
        assert!(staking_rewards_base_value == BTC_18D_CONFIG.base_value);
    }
}

#[derive(Drop, Copy)]
pub(crate) struct FindSigmaMigrationFlow {
    pub(crate) pool: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) member_rewards: Option<Amount>,
}
pub(crate) impl FindSigmaMigrationFlowImpl of FlowTrait<FindSigmaMigrationFlow> {
    fn setup_v2(ref self: FindSigmaMigrationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);
        self.pool = Option::Some(pool);
        let delegator = system.new_delegator(amount: 2 * amount);
        system.delegate(:delegator, :pool, amount: amount / 4);
        system.advance_epoch();
        system.advance_block_custom_and_attest(:staker, stake: amount + (amount / 4));
        system.increase_delegate(:delegator, :pool, amount: amount / 4);

        system.advance_epoch();
        system.advance_block_custom_and_attest(:staker, stake: amount + (2 * amount / 4));
        system.increase_delegate(:delegator, :pool, amount: amount / 4);

        system.advance_epoch();
        system.advance_epoch();
        system.increase_delegate(:delegator, :pool, amount: amount / 4);
        system.advance_block_custom_and_attest(:staker, stake: amount + (3 * amount / 4));
        system.advance_epoch();
        system.advance_block_custom_and_attest(:staker, stake: amount + amount);
        system.advance_epoch();
        system.increase_delegate(:delegator, :pool, amount: amount / 4);

        system.advance_epoch();
        let member_info = system.pool_member_info_v1(:delegator, :pool);
        assert!(member_info.unclaimed_rewards.is_non_zero());
        self.delegator = Option::Some(delegator);
        self.member_rewards = Option::Some(member_info.unclaimed_rewards);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: FindSigmaMigrationFlow, ref system: SystemState) {
        let pool = self.pool.unwrap();
        let expected_class_hash = declare_pool_contract();
        assert!(get_class_hash(contract_address: pool) == expected_class_hash);

        let delegator = self.delegator.unwrap();
        let member_info = system.pool_member_info_v1(:delegator, :pool);
        let expected_member_rewards = self.member_rewards.unwrap();
        assert!(member_info.unclaimed_rewards == expected_member_rewards);
        let balance_before = system.token.balance_of(account: delegator.reward.address);
        let rewards = system.delegator_claim_rewards(:delegator, :pool);
        let balance_after = system.token.balance_of(account: delegator.reward.address);
        assert!(rewards == expected_member_rewards);
        assert!(balance_after == balance_before + expected_member_rewards);
    }
}

#[derive(Drop, Copy)]
pub(crate) struct FindSigmaEdgeCasesMigrationFlow {
    pub(crate) pool: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) member_rewards: Option<Amount>,
}
pub(crate) impl FindSigmaEdgeCasesMigrationFlowImpl of FlowTrait<FindSigmaEdgeCasesMigrationFlow> {
    fn setup_v2(ref self: FindSigmaEdgeCasesMigrationFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);
        self.pool = Option::Some(pool);
        let delegator = system.new_delegator(amount: 2 * amount);
        system.delegate(:delegator, :pool, amount: amount / 4);
        system.advance_epoch();
        system.advance_block_custom_and_attest(:staker, stake: amount + (amount / 4));

        system.advance_epoch();
        system.delegator_claim_rewards(:delegator, :pool);

        system.increase_delegate(:delegator, :pool, amount: amount / 4);
        system.advance_epoch();
        system.increase_delegate(:delegator, :pool, amount: amount / 4);

        system.advance_epoch();
        let member_info = system.pool_member_info_v1(:delegator, :pool);
        self.delegator = Option::Some(delegator);
        self.member_rewards = Option::Some(member_info.unclaimed_rewards);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: FindSigmaEdgeCasesMigrationFlow, ref system: SystemState) {
        let pool = self.pool.unwrap();
        let expected_class_hash = declare_pool_contract();
        assert!(get_class_hash(contract_address: pool) == expected_class_hash);

        let delegator = self.delegator.unwrap();
        let member_info = system.pool_member_info_v1(:delegator, :pool);
        let expected_member_rewards = self.member_rewards.unwrap();
        assert!(member_info.unclaimed_rewards == expected_member_rewards);
        let balance_before = system.token.balance_of(account: delegator.reward.address);
        let rewards = system.delegator_claim_rewards(:delegator, :pool);
        let balance_after = system.token.balance_of(account: delegator.reward.address);
        assert!(rewards == expected_member_rewards);
        assert!(balance_after == balance_before + expected_member_rewards);
    }
}

#[derive(Drop, Copy)]
pub(crate) struct FindSigmaMigrationIdxIsOneFlow {
    pub(crate) pool: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) member_rewards: Option<Amount>,
}
pub(crate) impl FindSigmaMigrationIdxIsOneFlowImpl of FlowTrait<FindSigmaMigrationIdxIsOneFlow> {
    fn setup_v2(ref self: FindSigmaMigrationIdxIsOneFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);
        self.pool = Option::Some(pool);
        let delegator = system.new_delegator(amount: 2 * amount);
        system.delegate(:delegator, :pool, amount: amount / 4);
        system.advance_epoch();
        system.increase_delegate(:delegator, :pool, amount: amount / 4);
        system.advance_epoch();
        system.increase_delegate(:delegator, :pool, amount: amount / 4);

        system.advance_epoch();
        let member_info = system.pool_member_info_v1(:delegator, :pool);
        self.delegator = Option::Some(delegator);
        self.member_rewards = Option::Some(member_info.unclaimed_rewards);
        system.set_staker_for_migration(staker_address: staker.staker.address);
    }

    fn test(self: FindSigmaMigrationIdxIsOneFlow, ref system: SystemState) {
        let pool = self.pool.unwrap();
        let expected_class_hash = declare_pool_contract();
        assert!(get_class_hash(contract_address: pool) == expected_class_hash);

        let delegator = self.delegator.unwrap();
        let member_info = system.pool_member_info_v1(:delegator, :pool);
        let expected_member_rewards = self.member_rewards.unwrap();
        assert!(member_info.unclaimed_rewards == expected_member_rewards);
        let balance_before = system.token.balance_of(account: delegator.reward.address);
        let rewards = system.delegator_claim_rewards(:delegator, :pool);
        let balance_after = system.token.balance_of(account: delegator.reward.address);
        assert!(rewards == expected_member_rewards);
        assert!(balance_after == balance_before + expected_member_rewards);
    }
}


// TODO: Implement this flow test.
// Stake
// Upgrade
// Attest at STARTING_EPOCH (should fail)

// TODO: Add test:
// Stake without pool
// Change balance in some epochs (trace length should be > 1)
// Upgrade
// Open strk pool

// TODO: decimal tests:
// 1. Test with many decimals.
// 2. Test attept to switch between pools with different decimals.
// 3. Test exit pool with 8 and enter pool with 18 (and vice versa).
// 4. Test switch between BTC 18 decimals and STRK (both 18 decimals).
// 5. Test one delegator in 2 BTC pools with different decimals.

#[derive(Drop, Copy)]
pub(crate) struct StakingPrevClassHashFlow {}
pub(crate) impl StakingPrevClassHashFlowImpl of FlowTrait<StakingPrevClassHashFlow> {
    fn test(self: StakingPrevClassHashFlow, ref system: SystemState) {
        let staking_contract = system.staking.address;
        // Test prev_class_hash from v3.
        let map_selector = selector!("prev_class_hash");
        let storage_address = snforge_std::map_entry_address(
            :map_selector, keys: [V3_PREV_CONTRACT_VERSION].span(),
        );
        let v3_prev_class_hash = *snforge_std::load(
            target: staking_contract, :storage_address, size: Store::<ClassHash>::size().into(),
        )
            .at(0);
        assert!(v3_prev_class_hash.try_into().unwrap() == MAINNET_STAKING_CLASS_HASH_V2());
        // Test prev_class_hash from v2.
        let v2_prev_contract_version = V3_PREV_CONTRACT_VERSION - 1;
        let storage_address = snforge_std::map_entry_address(
            :map_selector, keys: [v2_prev_contract_version].span(),
        );
        let v2_prev_class_hash = *snforge_std::load(
            target: staking_contract, :storage_address, size: Store::<ClassHash>::size().into(),
        )
            .at(0);
        assert!(v2_prev_class_hash.try_into().unwrap() == MAINNET_STAKING_CLASS_HASH_V1());
        // Test prev_class_hash from v1.
        let v1_prev_contract_version = v2_prev_contract_version - 1;
        let storage_address = snforge_std::map_entry_address(
            :map_selector, keys: [v1_prev_contract_version].span(),
        );
        let v1_prev_class_hash = *snforge_std::load(
            target: staking_contract, :storage_address, size: Store::<ClassHash>::size().into(),
        )
            .at(0);
        assert!(v1_prev_class_hash.try_into().unwrap() == MAINNET_STAKING_CLASS_HASH_V0());
    }
}

/// Flow:
/// Stake in V1
/// Upgrade to V3 without migrating staker
/// Attempt to migrate staker
/// Catch STAKER_NOT_MIGRATED.
#[derive(Drop, Copy)]
pub(crate) struct StakerMigrationSkipVersionFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl StakerMigrationSkipVersionFlowImpl of FlowTrait<StakerMigrationSkipVersionFlow> {
    fn setup_v1(ref self: StakerMigrationSkipVersionFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let amount = min_stake * 2;
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        self.staker = Option::Some(staker);
    }

    #[feature("safe_dispatcher")]
    fn test(self: StakerMigrationSkipVersionFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let staker_address = staker.staker.address;
        let migration_safe_dispatcher = system.staking.migration_safe_dispatcher();

        let result = migration_safe_dispatcher.staker_migration(staker_address: staker_address);
        assert_panic_with_error(result, StakingError::STAKER_NOT_MIGRATED.describe());
    }
}

/// Flow:
/// Stake in V2.
/// Upgrade staking contract to V3 without EIC.
/// Attempt to migrate staker.
/// Catch MISSING_CLASS_HASH.
#[derive(Drop, Copy)]
pub(crate) struct StakerMigrationMissingClassHashFlow {}
pub(crate) impl StakerMigrationMissingClassHashFlowImpl of FlowTrait<
    StakerMigrationMissingClassHashFlow,
> {
    #[feature("safe_dispatcher")]
    fn setup_v2(ref self: StakerMigrationMissingClassHashFlow, ref system: SystemState) {
        let min_stake = system.staking.get_min_stake();
        let amount = min_stake * 2;
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        // Upgrade staking contract to V3 without EIC.
        let implementation_data = ImplementationData {
            impl_hash: declare_staking_contract(), eic_data: Option::None, final: false,
        };
        upgrade_implementation(
            contract_address: system.staking.address,
            :implementation_data,
            upgrade_governor: system.staking.roles.upgrade_governor,
        );

        // Staker migration.
        let staker_address = staker.staker.address;
        let migration_safe_dispatcher = system.staking.migration_safe_dispatcher();
        let result = migration_safe_dispatcher.staker_migration(staker_address: staker_address);
        assert_panic_with_error(result, InternalError::MISSING_CLASS_HASH.describe());
    }

    fn test(self: StakerMigrationMissingClassHashFlow, ref system: SystemState) {}
}

/// Flow:
/// Staker 1 stake
/// Upgrade to V1 (without migration)
/// Staker 2 stake
/// Upgrade to V2 (without migration)
/// Staker 3 stake
/// Upgrade to V3 (without migration)
/// Check version for each staker.
#[derive(Drop, Copy)]
pub(crate) struct StakerVersionFlow {
    pub(crate) stakers: Option<Span<Staker>>,
}
pub(crate) impl StakerVersionFlowImpl of FlowTrait<StakerVersionFlow> {
    fn setup(ref self: StakerVersionFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        self.stakers = Option::Some([staker].span());
    }

    fn setup_v1(ref self: StakerVersionFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        let mut stakers: Array<Staker> = self.stakers.unwrap().into();
        stakers.append(staker);
        self.stakers = Option::Some(stakers.span());
    }

    fn setup_v2(ref self: StakerVersionFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);

        let mut stakers: Array<Staker> = self.stakers.unwrap().into();
        stakers.append(staker);
        self.stakers = Option::Some(stakers.span());
    }

    fn test(self: StakerVersionFlow, ref system: SystemState) {
        let stakers = self.stakers.unwrap();
        for staker in stakers {
            let staker_version: StakerVersion = load_from_simple_map(
                map_selector: selector!("staker_version"),
                key: *staker.staker.address,
                contract: system.staking.address,
            );
            assert!(staker_version == StakerVersion::PreV3);
        }
    }
}

/// Flow:
/// Stake
/// Delegate
/// Accrue rewards
/// Delegator exit intent
/// Staker exit intent + action
/// Upgrade to latest version
/// Delegator exit action
/// Test balances
#[derive(Drop, Copy)]
pub(crate) struct MemberIntentStakerExitUpgradeFlow {
    pub(crate) pool: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) expected_rewards: Option<Amount>,
    pub(crate) delegated_amount: Option<Amount>,
}
pub(crate) impl MemberIntentStakerExitUpgradeFlowImpl of MultiVersionFlowTrait<
    MemberIntentStakerExitUpgradeFlow,
> {
    fn versions(self: MemberIntentStakerExitUpgradeFlow) -> Span<ReleaseVersion> {
        [V0, V1, V2].span()
    }

    fn setup(ref self: MemberIntentStakerExitUpgradeFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: true, :commission);
        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(:amount);
        system.delegate(:delegator, :pool, :amount);

        // Accrue rewards.
        system.accrue_rewards(:staker);

        // Delegator exit intent and staker exit action.
        system.delegator_exit_intent(:delegator, :pool, :amount);
        system.staker_exit_intent(:staker);
        system.advance_exit_wait_window();
        system.staker_exit_action(:staker);

        let unclaimed_rewards = system.delegator_unclaimed_rewards(:delegator, :pool);
        assert!(unclaimed_rewards.is_non_zero());

        self.pool = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.expected_rewards = Option::Some(unclaimed_rewards);
        self.delegated_amount = Option::Some(amount);
    }

    fn test(
        self: MemberIntentStakerExitUpgradeFlow, ref system: SystemState, version: ReleaseVersion,
    ) {
        let pool = self.pool.unwrap();
        let delegator = self.delegator.unwrap();
        let expected_rewards = self.expected_rewards.unwrap();
        let delegated_amount = self.delegated_amount.unwrap();
        system.delegator_exit_action(:delegator, :pool);
        if (version != V0) {
            system.delegator_claim_rewards(:delegator, :pool);
        }
        assert!(system.token.balance_of(account: delegator.reward.address) == expected_rewards);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);
        assert!(system.token.balance_of(account: pool) < 100);
    }
}

/// Flow:
/// Stake
/// Upgrade
/// Attempt to get public key
/// Catch PUBLIC_KEY_NOT_SET
#[derive(Drop, Copy)]
pub(crate) struct GetPublicKeyAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
}
pub(crate) impl GetPublicKeyAfterUpgradeFlowImpl of FlowTrait<GetPublicKeyAfterUpgradeFlow> {
    fn setup(ref self: GetPublicKeyAfterUpgradeFlow, ref system: SystemState) {
        let amount = system.staking.get_min_stake();
        let staker = system.new_staker(:amount);
        let commission = 200;
        system.stake(:staker, :amount, pool_enabled: false, :commission);

        system.set_staker_for_migration(staker_address: staker.staker.address);
        self.staker = Option::Some(staker);
    }

    #[feature("safe_dispatcher")]
    fn test(self: GetPublicKeyAfterUpgradeFlow, ref system: SystemState) {
        let staker = self.staker.unwrap();
        let staker_address = staker.staker.address;
        let result = system.staking.safe_dispatcher().get_current_public_key(:staker_address);
        assert_panic_with_error(result, StakingError::PUBLIC_KEY_NOT_SET.describe());
    }
}
