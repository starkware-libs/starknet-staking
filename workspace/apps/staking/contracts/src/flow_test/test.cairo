use core::num::traits::Zero;
use snforge_std::TokenImpl;
use staking::constants::STRK_IN_FRIS;
use staking::flow_test::flows;
use staking::flow_test::utils::{
    RewardSupplierTrait, StakingTrait, SystemConfigTrait, SystemDelegatorTrait, SystemStakerTrait,
    SystemTrait, TokenHelperTrait, test_flow_local,
};
use staking::test_utils::constants::{STRK_BASE_VALUE, TEST_MIN_BTC_FOR_REWARDS};
use staking::test_utils::{
    StakingInitConfig, calculate_staker_btc_pool_rewards,
    calculate_staker_strk_rewards_with_balances_v2, calculate_strk_pool_rewards_with_pool_balance,
    compute_rewards_per_unit,
};
use staking::utils::compute_rewards_rounded_down;
use starkware_utils::math::abs::wide_abs_diff;
use starkware_utils::time::time::Time;
use crate::types::Amount;

#[test]
fn basic_stake_flow_test() {
    let flow = flows::BasicStakeFlow {};
    test_flow_local(:flow);
}

#[test]
fn multiple_tokens_delegation_flow_test() {
    let flow = flows::MultipleTokensDelegationFlow {};
    test_flow_local(:flow);
}

#[test]
fn multiple_btc_pools_different_decimals_flow_test() {
    let flow = flows::MultipleBTCPoolsDifferentDecimalsFlow {};
    test_flow_local(:flow);
}

#[test]
fn new_token_delegation_flow_test() {
    let flow = flows::NewTokenDelegationFlow {};
    test_flow_local(:flow);
}

#[test]
fn set_open_for_delegation_flow_test() {
    let flow = flows::SetOpenForDelegationFlow {};
    test_flow_local(:flow);
}

#[test]
fn disabled_token_delegation_flow_test() {
    let flow = flows::DisabledTokenDelegationFlow {};
    test_flow_local(:flow);
}

#[test]
fn attest_with_zero_total_btc_stake_flow_test() {
    let flow = flows::AttestWithZeroTotalBtcStakeFlow {};
    test_flow_local(:flow);
}

#[test]
fn delegator_intent_after_staker_action_flow_test() {
    let flow = flows::DelegatorIntentAfterStakerActionFlow {};
    test_flow_local(:flow);
}

#[test]
fn basic_stake_btc_flow_test() {
    let flow = flows::BasicStakeBTCFlow {};
    test_flow_local(:flow);
}

#[test]
fn delegator_intent_flow_test() {
    let flow = flows::DelegatorIntentFlow {};
    test_flow_local(:flow);
}

#[test]
fn add_token_without_enable_flow_test() {
    let flow = flows::AddTokenWithoutEnableFlow {};
    test_flow_local(:flow);
}

#[test]
fn operations_after_dead_staker_flow_test() {
    let flow = flows::OperationsAfterDeadStakerFlow {};
    test_flow_local(:flow);
}

#[test]
fn set_commission_multiple_pools_flow_test() {
    let flow = flows::SetCommissionMultiplePoolsFlow {};
    test_flow_local(:flow);
}

#[test]
fn delegator_didnt_update_after_staker_update_commission_flow_test() {
    let flow = flows::DelegatorDidntUpdateAfterStakerUpdateCommissionFlow {};
    test_flow_local(:flow);
}

#[test]
fn pool_with_min_btc_flow_test() {
    let flow = flows::PoolWithMinBtcFlow {};
    test_flow_local(:flow);
}

#[test]
fn delegator_updated_after_staker_update_commission_flow_test() {
    let flow = flows::DelegatorUpdatedAfterStakerUpdateCommissionFlow {};
    test_flow_local(:flow);
}

#[test]
fn staker_intent_last_action_first_flow_test() {
    let flow = flows::StakerIntentLastActionFirstFlow {};
    test_flow_local(:flow);
}

#[test]
fn pool_claim_rewards_flow_test() {
    let flow = flows::PoolClaimRewardsFlow {};
    test_flow_local(:flow);
}

#[test]
fn pool_claim_rewards_flow_btc_test() {
    let flow = flows::PoolClaimRewardsFlowBtc {};
    test_flow_local(:flow);
}

#[test]
fn pool_calculate_rewards_twice_flow_test() {
    let flow = flows::PoolCalculateRewardsTwiceFlow {};
    test_flow_local(:flow);
}

#[test]
fn delegator_exit_and_enter_again_flow_test() {
    let flow = flows::DelegatorExitAndEnterAgainFlow {};
    test_flow_local(:flow);
}

#[test]
fn staker_multiple_pools_attest_flow_test() {
    let flow = flows::StakerMultiplePoolsAttestFlow {};
    test_flow_local(:flow);
}

#[test]
fn delegator_exit_and_enter_again_with_switch_flow_test() {
    let flow = flows::DelegatorExitAndEnterAgainWithSwitchFlow {};
    test_flow_local(:flow);
}

#[test]
fn multiple_pools_delegator_intent_action_switch_flow_test() {
    let flow = flows::MultiplePoolsDelegatorIntentActionSwitchFlow {};
    test_flow_local(:flow);
}

#[test]
fn claim_rewards_multiple_delegators_flow_test() {
    let mut flow = flows::ClaimRewardsMultipleDelegatorsFlow {};
    test_flow_local(:flow);
}

#[test]
fn claim_rewards_multiple_delegators_btc_flow_test() {
    let flow = flows::ClaimRewardsMultipleDelegatorsBtcFlow {};
    test_flow_local(:flow);
}

#[test]
fn pool_with_lots_of_btc_flow_test() {
    let flow = flows::PoolWithLotsOfBtcFlow {};
    test_flow_local(:flow);
}

#[test]
fn pool_claim_after_claim_flow_test() {
    let flow = flows::PoolClaimAfterClaimFlow {};
    test_flow_local(:flow);
}

#[test]
fn change_balance_claim_rewards_flow_test() {
    let mut flow = flows::ChangeBalanceClaimRewardsFlow {};
    test_flow_local(:flow);
}

#[test]
fn increase_stake_intent_same_epoch_flow_test() {
    let flow = flows::IncreaseStakeIntentSameEpochFlow {};
    test_flow_local(:flow);
}

#[test]
fn assert_total_stake_after_multi_stake_flow_test() {
    let flow = flows::AssertTotalStakeAfterMultiStakeFlow {};
    test_flow_local(:flow);
}

#[test]
fn delegate_intent_same_epoch_flow_test() {
    let flow = flows::DelegateIntentSameEpochFlow {};
    test_flow_local(:flow);
}

#[test]
fn two_stakers_same_operational_address_flow_test() {
    let flow = flows::TwoStakersSameOperationalAddressFlow {};
    test_flow_local(:flow);
}

#[test]
fn add_to_delegation_after_exit_action_flow_test() {
    let flow = flows::AddToDelegationAfterExitActionFlow {};
    test_flow_local(:flow);
}

#[test]
fn set_epoch_info_flow_test() {
    let flow = flows::SetEpochInfoFlow {};
    test_flow_local(:flow);
}

#[test]
fn disable_btc_token_same_and_next_epoch_flow_test() {
    let flow = flows::DisableBtcTokenSameAndNextEpochFlow {};
    test_flow_local(:flow);
}

#[test]
fn attest_after_delegator_intent_flow_test() {
    let flow = flows::AttestAfterDelegatorIntentFlow {};
    test_flow_local(:flow);
}

#[test]
fn multi_pool_exit_intent_flow_test() {
    let flow = flows::MultiPoolExitIntentFlow {};
    test_flow_local(:flow);
}

#[test]
fn diverse_staker_vec_flow_test() {
    let flow = flows::DiverseStakerVecFlow {};
    test_flow_local(:flow);
}

#[test]
fn enable_disable_btc_token_same_epoch_flow_test() {
    let flow = flows::EnableDisableBtcTokenSameEpochFlow {};
    test_flow_local(flow);
}

#[test]
fn disable_enable_btc_token_same_epoch_flow_test() {
    let flow = flows::DisableEnableBtcTokenSameEpochFlow {};
    test_flow_local(flow);
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator exit_intent full amount
/// Delegator switch full amount to the same delegation pool
#[test]
#[should_panic(expected: "Self switch is not allowed")]
fn switch_to_same_delegation_pool_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount);
    let commission = 200;
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount);
    system.delegate(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    system
        .switch_delegation_pool(
            :delegator,
            from_pool: pool,
            to_staker: staker.staker.address,
            to_pool: pool,
            amount: delegated_amount,
        );
}

/// Flow:
/// Staker Stake.
/// Delegator delegate.
/// Staker exit_intent.
/// Advance time less than exit_wait_window.
/// Delegator claim rewards - cover `claim_rewards` when staker in intent.
/// Delegator intent - cover delegator in intent when staker still alive but in intent. Ignores if
/// `unstake_time` is none in `remove_from_delegation_pool_intent`.
/// Delegator action - cover action when A in intent.
/// Staker action.
#[test]
fn delegator_claim_rewards_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
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
    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount * 2);
    system.delegate(:delegator, :pool, amount: delegated_amount);
    system.advance_k_epochs_and_attest(:staker);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window().div(divider: 2));

    system.delegator_claim_rewards(:delegator, :pool);
    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.delegator_exit_action(:delegator, :pool);
    system.staker_exit_action(:staker);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(
        system.token.balance_of(account: pool) > 100,
    ); // TODO: Change this after implement calculate_rewards.
    assert!(system.token.balance_of(account: staker.staker.address) == stake_amount * 2);
    assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount * 2);
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
/// Flow:
/// Staker Stake
/// Delegator X delegate
/// Delegator Y delegate
/// Delegator X exit_intent full amount
/// Delegator X action
/// Delegator Y exit_intent full amount
/// Delegator Y action
/// Staker exit_intent
/// Staker exit_action
#[test]
fn two_delegators_full_intent_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
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

    let delegator_x = system.new_delegator(amount: delegated_amount);
    system.delegate(delegator: delegator_x, :pool, amount: delegated_amount);
    system.advance_k_epochs_and_attest(:staker);

    let delegator_y = system.new_delegator(amount: delegated_amount);
    system.delegate(delegator: delegator_y, :pool, amount: delegated_amount);
    system.advance_k_epochs_and_attest(:staker);

    system.delegator_exit_intent(delegator: delegator_x, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_k_epochs_and_attest(:staker);

    system.delegator_exit_action(delegator: delegator_x, :pool);
    system.delegator_claim_rewards(delegator: delegator_x, :pool);
    system.advance_k_epochs_and_attest(:staker);

    system.delegator_exit_intent(delegator: delegator_y, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_k_epochs_and_attest(:staker);

    system.delegator_exit_action(delegator: delegator_y, :pool);
    system.delegator_claim_rewards(delegator: delegator_y, :pool);
    system.advance_k_epochs_and_attest(:staker);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_action(:staker);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
    assert!(system.token.balance_of(account: delegator_x.delegator.address) == delegated_amount);
    assert!(system.token.balance_of(account: delegator_y.delegator.address) == delegated_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator_x.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator_y.reward.address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert!(
        initial_reward_supplier_balance == system
            .token
            .balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator_x.reward.address)
            + system.token.balance_of(account: delegator_y.reward.address)
            + system.token.balance_of(account: pool),
    );
}

/// Flow:
/// First staker Stake.
/// Delegator delegate.
/// Second staker Stake.
/// Delegator partially intent in first staker.
/// Delegator switch from first staker's pool to second staker's pool.
/// Delegator exit_action in first staker.
/// Delegator exit_intent in second staker.
/// Delegator switch from second staker's pool to first staker's pool.
/// Delegator change reward address in second staker's pool.
/// Delegator claim rewards in both stakers pools.
#[test]
fn partial_switches_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let stake_amount = system.staking.get_min_stake() * 2;
    let commission = 200;

    let first_staker = system.new_staker(amount: stake_amount);
    system.stake(staker: first_staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_k_epochs_and_attest(staker: first_staker);

    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount);
    let first_pool = system.staking.get_pool(staker: first_staker);
    system.delegate(:delegator, pool: first_pool, amount: delegated_amount);
    system.advance_k_epochs_and_attest(staker: first_staker);

    let second_staker = system.new_staker(amount: stake_amount);
    system.stake(staker: second_staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_k_epochs_and_attest(staker: first_staker);
    system.advance_k_epochs_and_attest(staker: second_staker);

    system.delegator_exit_intent(:delegator, pool: first_pool, amount: delegated_amount / 2);
    let second_pool = system.staking.get_pool(staker: second_staker);
    system
        .switch_delegation_pool(
            :delegator,
            from_pool: first_pool,
            to_staker: second_staker.staker.address,
            to_pool: second_pool,
            amount: delegated_amount / 4,
        );
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_k_epochs_and_attest(staker: first_staker);
    system.advance_k_epochs_and_attest(staker: second_staker);

    system.delegator_exit_action(:delegator, pool: first_pool);
    system.delegator_claim_rewards(:delegator, pool: first_pool);
    system.advance_k_epochs_and_attest(staker: first_staker);
    system.advance_k_epochs_and_attest(staker: second_staker);

    system.delegator_exit_intent(:delegator, pool: second_pool, amount: delegated_amount / 8);
    system
        .switch_delegation_pool(
            :delegator,
            from_pool: second_pool,
            to_staker: first_staker.staker.address,
            to_pool: first_pool,
            amount: delegated_amount / 8,
        );
    system.advance_k_epochs_and_attest(staker: first_staker);
    system.advance_k_epochs_and_attest(staker: second_staker);

    let new_reward_address = system.new_account(amount: Zero::zero()).address;
    system
        .delegator_change_reward_address(
            :delegator, pool: second_pool, reward_address: new_reward_address,
        );
    system.advance_k_epochs_and_attest(staker: first_staker);
    system.advance_k_epochs_and_attest(staker: second_staker);

    system.delegator_claim_rewards(:delegator, pool: first_pool);
    system.delegator_claim_rewards(:delegator, pool: second_pool);

    system.delegator_exit_intent(:delegator, pool: first_pool, amount: (delegated_amount * 5 / 8));
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_k_epochs_and_attest(staker: first_staker);
    system.advance_k_epochs_and_attest(staker: second_staker);
    system.delegator_exit_action(:delegator, pool: first_pool);
    system.delegator_claim_rewards(:delegator, pool: first_pool);

    system.delegator_exit_intent(:delegator, pool: second_pool, amount: delegated_amount / 8);
    system.advance_exit_wait_window();
    system.delegator_exit_action(:delegator, pool: second_pool);
    system.delegator_claim_rewards(:delegator, pool: second_pool);
    system.advance_k_epochs_and_attest(staker: first_staker);
    system.advance_k_epochs_and_attest(staker: second_staker);

    system.staker_exit_intent(staker: first_staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_k_epochs_and_attest(staker: second_staker);
    system.staker_exit_action(staker: first_staker);

    system.staker_exit_intent(staker: second_staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(staker: second_staker);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: first_pool) < 100);
    assert!(system.token.balance_of(account: second_pool) < 100);
    assert!(system.token.balance_of(account: first_staker.staker.address) == stake_amount);
    assert!(system.token.balance_of(account: second_staker.staker.address) == stake_amount);
    assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);

    assert!(system.token.balance_of(account: first_staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: second_staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: new_reward_address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert!(
        initial_reward_supplier_balance == system
            .token
            .balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: first_staker.reward.address)
            + system.token.balance_of(account: second_staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: new_reward_address)
            + system.token.balance_of(account: first_pool)
            + system.token.balance_of(account: second_pool),
    );
}
/// Flow - 4:
/// Staker A (SA) adds stake w/pool
/// Staker B (SB) adds stake w/pool
/// Delegtor Y (DY) add (100) to SB's pool
/// - check 1
///
/// DY intent to exit all (100) tokens from SB
/// DY switches all (100) to SA
/// - check 2
///
/// DY intent to exit all (100) tokens from SA
/// DY switches all (100) to SB
/// - check 3
///
/// clearance
/// - check4 (clearance)
#[test]
fn flow_4_switch_member_back_and_forth_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let delegated_amount = stake_amount;

    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let commission = 200;

    let staker_A = system.new_staker(amount: stake_amount);
    system.stake(staker: staker_A, amount: stake_amount, pool_enabled: true, :commission);
    assert!(system.staking.get_total_stake() == stake_amount);
    let pool_A = system.staking.get_pool(staker: staker_A);
    system.advance_k_epochs_and_attest(staker: staker_A);

    let staker_B = system.new_staker(amount: stake_amount);
    system.stake(staker: staker_B, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_k_epochs_and_attest(staker: staker_B);
    system.advance_k_epochs_and_attest(staker: staker_A);
    let pool_B = system.staking.get_pool(staker: staker_B);

    assert!(system.staking.get_total_stake() == 2 * stake_amount);

    let delegator_Y = system.new_delegator(amount: delegated_amount);
    system.delegate(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);

    system.advance_k_epochs_and_attest(staker: staker_A);
    assert!(system.token.balance_of(account: pool_B).is_zero());
    system.advance_k_epochs_and_attest(staker: staker_B);
    assert!(system.token.balance_of(account: pool_B).is_non_zero());
    assert!(system.staking.get_total_stake() == 2 * stake_amount + delegated_amount);
    assert!(
        system.token.balance_of(account: system.staking.address) == 2 * stake_amount
            + delegated_amount,
    );

    // DY intend to exit PB & switch to PA.
    system.delegator_exit_intent(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);
    system.advance_k_epochs_and_attest(staker: staker_A);
    system.advance_k_epochs_and_attest(staker: staker_B);
    system
        .switch_delegation_pool(
            delegator: delegator_Y,
            from_pool: pool_B,
            to_staker: staker_A.staker.address,
            to_pool: pool_A,
            amount: delegated_amount,
        );
    assert!(system.token.balance_of(account: pool_A).is_zero());
    system.advance_k_epochs_and_attest(staker: staker_A);
    assert!(system.token.balance_of(account: pool_A).is_non_zero());
    system.advance_k_epochs_and_attest(staker: staker_B);

    // DY intend to exit PA & switch to PB.
    system.delegator_exit_intent(delegator: delegator_Y, pool: pool_A, amount: delegated_amount);
    system.advance_k_epochs_and_attest(staker: staker_A);
    system.advance_k_epochs_and_attest(staker: staker_B);
    system
        .switch_delegation_pool(
            delegator: delegator_Y,
            from_pool: pool_A,
            to_staker: staker_B.staker.address,
            to_pool: pool_B,
            amount: delegated_amount,
        );
    system.advance_k_epochs_and_attest(staker: staker_A);
    system.advance_k_epochs_and_attest(staker: staker_B);

    // Perform test end clearance - All stakers and delegators exit staking.
    system.delegator_exit_intent(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(delegator: delegator_Y, pool: pool_B);
    system.delegator_claim_rewards(delegator: delegator_Y, pool: pool_B);

    system.staker_exit_intent(staker: staker_B);
    system.staker_exit_intent(staker: staker_A);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(staker: staker_A);
    system.staker_exit_action(staker: staker_B);

    /// Post clearance checks: ///

    // 1. Staking contract balance is zero.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());

    // 2. Stakers and delegator balances are the staked amounts.
    assert!(system.token.balance_of(account: staker_A.staker.address) == stake_amount);
    assert!(system.token.balance_of(account: staker_B.staker.address) == stake_amount);
    assert!(system.token.balance_of(account: delegator_Y.delegator.address) == delegated_amount);

    // 3. Reward addresses have some balance for all stakers & delegators.
    assert!(system.token.balance_of(account: staker_A.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: staker_B.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator_Y.reward.address).is_non_zero());

    // 4. Virtually all rewards awarded were claimed.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

    // 5. Rewards funds are well accounted for.
    assert!(
        initial_reward_supplier_balance == system
            .token
            .balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker_A.reward.address)
            + system.token.balance_of(account: staker_B.reward.address)
            + system.token.balance_of(account: delegator_Y.reward.address)
            + system.token.balance_of(account: pool_A)
            + system.token.balance_of(account: pool_B),
    );
}

/// flow:
/// Staker stake
/// First delegator delegate
/// Second delegator delegate
/// First delegator add_to_delegation_pool
/// Second delegator add_to_delegation_pool
/// First delegator exit_intent
/// First delegator exit_action
/// Second delegator exit_intent
/// Second delegator exit_action
/// Staker exit_intent
/// Staker exit_action
#[test]
fn delegators_add_to_delegation_pool_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
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
    let delegator_amount = stake_amount;

    let first_delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(delegator: first_delegator, :pool, amount: delegator_amount / 2);
    system.advance_k_epochs_and_attest(:staker);

    let second_delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(delegator: second_delegator, :pool, amount: delegator_amount / 2);
    system.advance_k_epochs_and_attest(:staker);

    system
        .add_to_delegation_pool(
            delegator: first_delegator, pool: pool, amount: delegator_amount / 2,
        );
    system.advance_k_epochs_and_attest(:staker);

    system
        .add_to_delegation_pool(
            delegator: second_delegator, pool: pool, amount: delegator_amount / 2,
        );
    system.advance_k_epochs_and_attest(:staker);
    system.advance_epoch();

    system.delegator_exit_intent(delegator: first_delegator, :pool, amount: delegator_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(delegator: first_delegator, :pool);
    system.delegator_claim_rewards(delegator: first_delegator, :pool);

    system.delegator_exit_intent(delegator: second_delegator, :pool, amount: delegator_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(delegator: second_delegator, :pool);
    system.delegator_claim_rewards(delegator: second_delegator, :pool);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(:staker);

    // Post clearance checks:

    // 1. Token balance virtually zero on stakers. Zero on staking contract.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);

    // 2. Stakers and delegator balances are the staked amounts.
    assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
    assert!(
        system.token.balance_of(account: first_delegator.delegator.address) == delegator_amount,
    );
    assert!(
        system.token.balance_of(account: second_delegator.delegator.address) == delegator_amount,
    );

    // 3. Reward addresses have some balance for all stakers & delegators.
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: first_delegator.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: second_delegator.reward.address).is_non_zero());

    // 4. Virtually all rewards awarded were claimed.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

    // 5. Rewards funds are well accounted for.
    assert!(
        initial_reward_supplier_balance == system
            .token
            .balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: first_delegator.reward.address)
            + system.token.balance_of(account: second_delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}

/// Flow:
/// Staker stake
/// Delegator delegate
/// Delegator partial exit_intent
/// Delegator add_to_delegation_pool
/// Delegator full exit_intent
/// Delegator add_to_delegation_pool
/// Delegator full exit_intent
/// Delegator exit_action
/// Staker exit_intent
/// Staker exit_action
#[test]
fn add_to_delegation_after_intent_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
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
    let delegator_amount = stake_amount;

    let delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(:delegator, :pool, amount: delegator_amount / 2);
    system.advance_k_epochs_and_attest(:staker);

    // Partial intent.
    system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount / 4);
    system.advance_k_epochs_and_attest(:staker);

    system.add_to_delegation_pool(:delegator, :pool, amount: delegator_amount / 4);
    system.advance_k_epochs_and_attest(:staker);

    // Full intent.
    system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount * 3 / 4);
    system.advance_k_epochs_and_attest(:staker);

    system.add_to_delegation_pool(:delegator, :pool, amount: delegator_amount / 4);
    system.advance_k_epochs_and_attest(:staker);
    system.advance_epoch();

    system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, :pool);
    system.delegator_claim_rewards(:delegator, :pool);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(:staker);

    // Post clearance checks:

    // 1. Token balance virtually zero on stakers. Zero on staking contract.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);

    // 2. Stakers and delegator balances are the staked amounts.
    assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
    assert!(system.token.balance_of(account: delegator.delegator.address) == delegator_amount);

    // 3. Reward addresses have some balance for all stakers & delegators.
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());

    // 4. Virtually all rewards awarded were claimed.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

    // 5. Rewards funds are well accounted for.
    assert!(
        initial_reward_supplier_balance == system
            .token
            .balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}

/// Test delegator claim rewards flow.
#[test]
fn delegator_claim_rewards_test_idx_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount);
    let commission = 200;
    let token_address = system.token.contract_address();
    let base_value = STRK_BASE_VALUE;

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

    let pool = system.staking.get_pool(:staker);
    let delegator_amount = stake_amount;
    let delegate_amount = delegator_amount / 4;

    let delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(:delegator, :pool, amount: delegate_amount);
    system.advance_k_epochs();
    let mut stake = stake_amount + delegate_amount;
    let mut pool_balance = delegate_amount;
    let mut sigma: Amount = 0;
    let pool_epoch_rewards = calculate_strk_pool_rewards_with_pool_balance(
        staker_address: staker.staker.address,
        staking_contract: system.staking.address,
        minting_curve_contract: system.minting_curve.address,
        :pool_balance,
    );

    // cumulative_rewards_trace_idx is the right entry in find_sigma.

    system.add_to_delegation_pool(:delegator, :pool, amount: delegate_amount);

    system.advance_block_custom_and_attest(:staker, :stake);
    sigma +=
        compute_rewards_per_unit(
            staking_rewards: pool_epoch_rewards, total_stake: pool_balance, :token_address,
        );

    system.advance_epoch();

    system.advance_block_custom_and_attest(:staker, :stake);
    sigma +=
        compute_rewards_per_unit(
            staking_rewards: pool_epoch_rewards, total_stake: pool_balance, :token_address,
        );

    system.advance_epoch();
    stake += delegate_amount;

    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    let mut expected_unclaimed_rewards_no_round = pool_epoch_rewards * 2;
    let mut expected_unclaimed_rewards = compute_rewards_rounded_down(
        amount: pool_balance, interest: sigma, :base_value,
    );
    assert!(pool_member_info.unclaimed_rewards == expected_unclaimed_rewards);

    // cumulative_rewards_trace_idx - 1 is the right entry in find_sigma.

    pool_balance += delegate_amount;
    let pool_epoch_rewards = calculate_strk_pool_rewards_with_pool_balance(
        staker_address: staker.staker.address,
        staking_contract: system.staking.address,
        minting_curve_contract: system.minting_curve.address,
        :pool_balance,
    );

    system.advance_block_custom_and_attest(:staker, :stake);
    sigma =
        compute_rewards_per_unit(
            staking_rewards: pool_epoch_rewards, total_stake: pool_balance, :token_address,
        );

    system.add_to_delegation_pool(:delegator, :pool, amount: delegate_amount);

    system.advance_epoch();

    system.advance_block_custom_and_attest(:staker, :stake);
    sigma +=
        compute_rewards_per_unit(
            staking_rewards: pool_epoch_rewards, total_stake: pool_balance, :token_address,
        );

    system.advance_epoch();
    stake += delegate_amount;

    system.advance_block_custom_and_attest(:staker, :stake);

    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    expected_unclaimed_rewards_no_round += pool_epoch_rewards * 2;
    expected_unclaimed_rewards +=
        compute_rewards_rounded_down(amount: pool_balance, interest: sigma, :base_value);
    assert!(pool_member_info.unclaimed_rewards == expected_unclaimed_rewards);

    // cumulative_rewards_trace_idx - 2 is the right entry in find_sigma.

    pool_balance += delegate_amount;
    let pool_epoch_rewards = calculate_strk_pool_rewards_with_pool_balance(
        staker_address: staker.staker.address,
        staking_contract: system.staking.address,
        minting_curve_contract: system.minting_curve.address,
        :pool_balance,
    );
    sigma =
        compute_rewards_per_unit(
            staking_rewards: pool_epoch_rewards, total_stake: pool_balance, :token_address,
        );

    system.add_to_delegation_pool(:delegator, :pool, amount: delegate_amount);

    system.advance_k_epochs();

    stake += delegate_amount;

    system.advance_block_custom_and_attest(:staker, :stake);

    system.advance_epoch();

    system.advance_block_custom_and_attest(:staker, :stake);

    expected_unclaimed_rewards_no_round += pool_epoch_rewards;
    expected_unclaimed_rewards +=
        compute_rewards_rounded_down(amount: pool_balance, interest: sigma, :base_value);

    pool_balance += delegate_amount;
    let pool_epoch_rewards = calculate_strk_pool_rewards_with_pool_balance(
        staker_address: staker.staker.address,
        staking_contract: system.staking.address,
        minting_curve_contract: system.minting_curve.address,
        :pool_balance,
    );
    sigma =
        compute_rewards_per_unit(
            staking_rewards: pool_epoch_rewards, total_stake: pool_balance, :token_address,
        );

    expected_unclaimed_rewards_no_round += pool_epoch_rewards;
    expected_unclaimed_rewards +=
        compute_rewards_rounded_down(amount: pool_balance, interest: sigma, :base_value);

    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == expected_unclaimed_rewards);

    system.advance_epoch();

    expected_unclaimed_rewards_no_round += pool_epoch_rewards;
    expected_unclaimed_rewards +=
        compute_rewards_rounded_down(amount: pool_balance, interest: sigma, :base_value);

    let actual_rewards = system.delegator_claim_rewards(:delegator, :pool);

    assert!(expected_unclaimed_rewards_no_round - actual_rewards <= 3);
    assert!(actual_rewards == expected_unclaimed_rewards);
    assert!(
        system
            .token
            .balance_of(account: delegator.reward.address) == expected_unclaimed_rewards
            .into(),
    );
}

/// Test delegator claim rewards flow - less than 3 entries in cumulative_rewards_trace.
#[test]
fn delegator_claim_rewards_test_less_than_3_entries_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount);
    let commission = 200;

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

    let pool = system.staking.get_pool(:staker);
    let delegator_amount = stake_amount;
    let delegate_amount = delegator_amount / 4;

    let delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(:delegator, :pool, amount: delegate_amount);
    // Test claim before have delegation.
    let rewards = system.delegator_claim_rewards(:delegator, :pool);
    assert!(rewards == 0);

    system.advance_epoch();

    // Test claim before have delegation.
    let rewards = system.delegator_claim_rewards(:delegator, :pool);
    assert!(rewards == 0);

    system.advance_epoch();

    // Test cumulative_rewards_trace_len = 1 (only zero entry).
    let rewards = system.delegator_claim_rewards(:delegator, :pool);
    assert!(rewards == 0);

    // Test cumulative_rewards_trace_len = 2 without existing current checkpoint.
    let mut stake = stake_amount + delegate_amount;
    let mut pool_balance = delegate_amount;
    system.advance_block_custom_and_attest(:staker, :stake);
    let pool_epoch_rewards = calculate_strk_pool_rewards_with_pool_balance(
        staker_address: staker.staker.address,
        staking_contract: system.staking.address,
        minting_curve_contract: system.minting_curve.address,
        :pool_balance,
    );

    system.advance_epoch();
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards);
    // Test cumulative_rewards_trace_len = 2 with existing current checkpoint.
    system.add_to_delegation_pool(:delegator, :pool, amount: delegate_amount);
    system.advance_k_epochs();
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards);
    system.advance_epoch();
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards);

    // Test cumulative_rewards_trace_len = 2 with existing after current checkpoint.
    system.add_to_delegation_pool(:delegator, :pool, amount: delegate_amount);
    system.advance_epoch();
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards);

    let rewards = system.delegator_claim_rewards(:delegator, :pool);
    assert!(rewards == pool_epoch_rewards);
    assert!(
        system.token.balance_of(account: delegator.reward.address) == pool_epoch_rewards.into(),
    );
}

/// Test delegator claim rewards flow - cumulative_rewards_trace_idx >= length.
#[test]
fn delegator_claim_rewards_test_idx_greater_than_length_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount);
    let commission = 200;

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_epoch();

    let pool = system.staking.get_pool(:staker);
    let delegator_amount = stake_amount;
    let delegate_amount = delegator_amount / 4;

    let delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(:delegator, :pool, amount: delegate_amount);
    system.advance_epoch();
    system.advance_block_custom_and_attest(:staker, stake: stake_amount);
    system.advance_epoch();
    let mut stake = stake_amount + delegate_amount;
    system.advance_block_custom_and_attest(:staker, :stake);
    system.advance_epoch();
    system.advance_block_custom_and_attest(:staker, :stake);
    system.advance_epoch();
    system.advance_epoch();
    system.advance_block_custom_and_attest(:staker, :stake);

    let mut pool_balance = delegate_amount;
    let pool_epoch_rewards = calculate_strk_pool_rewards_with_pool_balance(
        staker_address: staker.staker.address,
        staking_contract: system.staking.address,
        minting_curve_contract: system.minting_curve.address,
        :pool_balance,
    );

    system.add_to_delegation_pool(:delegator, :pool, amount: delegate_amount);
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards * 2);

    // idx == len + 1.
    system.advance_epoch();
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards * 3);

    system.advance_block_custom_and_attest(:staker, :stake);
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards * 3);
    // idx == len.
    system.advance_epoch();
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards * 4);
    system.advance_epoch();
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == pool_epoch_rewards * 4);

    let rewards = system.delegator_claim_rewards(:delegator, :pool);
    assert!(rewards == pool_epoch_rewards * 4);
    assert!(system.token.balance_of(account: delegator.reward.address) == rewards.into());
}

/// Test delegator claim rewards flow - cumulative_rewards_trace_idx == 1.
#[test]
fn delegator_claim_rewards_test_idx_is_one_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount);
    let commission = 200;

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_epoch();

    let pool = system.staking.get_pool(:staker);
    let delegator_amount = stake_amount;
    let delegate_amount = delegator_amount / 4;

    let delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(:delegator, :pool, amount: delegate_amount);
    system.advance_k_epochs();
    system.add_to_delegation_pool(:delegator, :pool, amount: delegate_amount);
    system.advance_k_epochs();
    let mut stake = stake_amount + 2 * delegate_amount;
    system.advance_block_custom_and_attest(:staker, :stake);
    let rewards = system.delegator_claim_rewards(:delegator, :pool);
    assert!(rewards == 0);

    system.advance_epoch();
    system.advance_block_custom_and_attest(:staker, :stake);
    system.advance_epoch();
    system.advance_block_custom_and_attest(:staker, :stake);
    system.advance_epoch();

    let pool_balance = delegate_amount * 2;
    let pool_epoch_rewards = calculate_strk_pool_rewards_with_pool_balance(
        staker_address: staker.staker.address,
        staking_contract: system.staking.address,
        minting_curve_contract: system.minting_curve.address,
        :pool_balance,
    );
    let expected_rewards = pool_epoch_rewards * 3;
    let pool_member_info = system.pool_member_info_v1(:delegator, :pool);
    assert!(pool_member_info.unclaimed_rewards == expected_rewards);
    let rewards = system.delegator_claim_rewards(:delegator, :pool);
    assert!(rewards == expected_rewards);
    assert!(system.token.balance_of(account: delegator.reward.address) == rewards.into());
}

#[test]
fn staker_claim_rewards_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let mut stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount * 2);
    let commission = 200;
    let staking_contract = system.staking.address;
    let minting_curve_contract = system.minting_curve.address;
    let mut total_staker_rewards: Amount = Zero::zero();
    let mut total_strk_pool_rewards: Amount = Zero::zero();

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_epoch();

    system.increase_stake(:staker, amount: stake_amount);
    system.advance_epoch();

    system.advance_block_custom_and_attest(:staker, stake: stake_amount);
    let (staker_rewards, pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: Zero::zero(),
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    total_staker_rewards += staker_rewards;
    total_strk_pool_rewards += pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    let delegator_amount = stake_amount;
    let base_strk_delegate_amount = delegator_amount / 4;
    let mut strk_delegate_amount = Zero::zero();
    let strk_pool = system.staking.get_pool(:staker);
    let strk_delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(delegator: strk_delegator, pool: strk_pool, amount: base_strk_delegate_amount);
    system.advance_epoch();

    stake_amount += stake_amount;
    system.advance_block_custom_and_attest(:staker, stake: stake_amount);
    let (staker_rewards, pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: Zero::zero(),
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    total_staker_rewards += staker_rewards;
    total_strk_pool_rewards += pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    system
        .increase_delegate(
            delegator: strk_delegator, pool: strk_pool, amount: base_strk_delegate_amount,
        );
    system.advance_epoch();

    strk_delegate_amount += base_strk_delegate_amount;
    system.advance_block_custom_and_attest(:staker, stake: stake_amount + strk_delegate_amount);
    let (staker_rewards, pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: strk_delegate_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    total_staker_rewards += staker_rewards;
    total_strk_pool_rewards += pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    // Full intent.
    system
        .delegator_exit_intent(
            delegator: strk_delegator, pool: strk_pool, amount: base_strk_delegate_amount * 2,
        );
    system.advance_epoch();

    strk_delegate_amount += base_strk_delegate_amount;
    system.advance_block_custom_and_attest(:staker, stake: stake_amount + strk_delegate_amount);
    let (staker_rewards, pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: strk_delegate_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    total_staker_rewards += staker_rewards;
    total_strk_pool_rewards += pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    // Partial intent.
    system
        .delegator_exit_intent(
            delegator: strk_delegator, pool: strk_pool, amount: base_strk_delegate_amount,
        );
    system.advance_epoch();

    system.advance_block_custom_and_attest(:staker, stake: stake_amount);
    let (staker_rewards, pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: Zero::zero(),
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    total_staker_rewards += staker_rewards;
    total_strk_pool_rewards += pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    // Add BTC stake.
    let btc_token = system.btc_token;
    let btc_token_address = btc_token.contract_address();
    let btc_pool = system.set_open_for_delegation(:staker, token_address: btc_token_address);
    let base_btc_delegate_amount = TEST_MIN_BTC_FOR_REWARDS * 16;
    let mut btc_delegator_amount: Amount = Zero::zero();
    let mut total_btc_pool_rewards: Amount = Zero::zero();
    let btc_delegator = system
        .new_btc_delegator(amount: base_btc_delegate_amount * 2, token: btc_token);
    system
        .delegate_btc(
            delegator: btc_delegator,
            pool: btc_pool,
            amount: base_btc_delegate_amount,
            token: btc_token,
        );
    system.advance_epoch();

    strk_delegate_amount -= base_strk_delegate_amount;
    system.advance_block_custom_and_attest(:staker, stake: stake_amount + strk_delegate_amount);
    let (staker_rewards, pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: strk_delegate_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    total_staker_rewards += staker_rewards;
    total_strk_pool_rewards += pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    system
        .increase_delegate_btc(
            delegator: btc_delegator,
            pool: btc_pool,
            amount: base_btc_delegate_amount,
            token: btc_token,
        );
    system.advance_epoch();

    btc_delegator_amount += base_btc_delegate_amount;
    system.advance_block_custom_and_attest(:staker, stake: stake_amount + strk_delegate_amount);
    let (staker_rewards, strk_pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: strk_delegate_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    let (commission_rewards, btc_pool_rewards) = calculate_staker_btc_pool_rewards(
        pool_balance: btc_delegator_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
        token_address: btc_token_address,
    );
    total_staker_rewards += staker_rewards + commission_rewards;
    total_strk_pool_rewards += strk_pool_rewards;
    total_btc_pool_rewards += btc_pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    // Full intent.
    system
        .delegator_exit_intent(
            delegator: btc_delegator, pool: btc_pool, amount: base_btc_delegate_amount * 2,
        );
    system.advance_epoch();

    btc_delegator_amount += base_btc_delegate_amount;
    system.advance_block_custom_and_attest(:staker, stake: stake_amount + strk_delegate_amount);
    let (staker_rewards, strk_pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: strk_delegate_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    let (commission_rewards, btc_pool_rewards) = calculate_staker_btc_pool_rewards(
        pool_balance: btc_delegator_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
        token_address: btc_token_address,
    );
    total_staker_rewards += staker_rewards + commission_rewards;
    total_strk_pool_rewards += strk_pool_rewards;
    total_btc_pool_rewards += btc_pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    system.advance_epoch();

    // Partial intent.
    system
        .delegator_exit_intent(
            delegator: btc_delegator, pool: btc_pool, amount: base_btc_delegate_amount,
        );
    system.advance_epoch();

    system.advance_block_custom_and_attest(:staker, stake: stake_amount + strk_delegate_amount);
    let (staker_rewards, strk_pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: strk_delegate_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    total_staker_rewards += staker_rewards;
    total_strk_pool_rewards += strk_pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    system.advance_epoch();
    btc_delegator_amount -= base_btc_delegate_amount;
    system.advance_block_custom_and_attest(:staker, stake: stake_amount + strk_delegate_amount);
    let (staker_rewards, strk_pool_rewards) = calculate_staker_strk_rewards_with_balances_v2(
        amount_own: stake_amount,
        pool_amount: strk_delegate_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
    );
    let (commission_rewards, btc_pool_rewards) = calculate_staker_btc_pool_rewards(
        pool_balance: btc_delegator_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
        token_address: btc_token_address,
    );
    total_staker_rewards += staker_rewards + commission_rewards;
    total_strk_pool_rewards += strk_pool_rewards;
    total_btc_pool_rewards += btc_pool_rewards;
    let staker_info = system.staker_info_v1(:staker);
    assert!(staker_info.unclaimed_rewards_own == total_staker_rewards);

    system.advance_epoch();

    let balance_before_claim = system.token.balance_of(account: staker.reward.address);
    let rewards = system.staker_claim_rewards(:staker);
    assert!(rewards == total_staker_rewards);
    assert!(
        system.token.balance_of(account: staker.reward.address) == balance_before_claim + rewards,
    );

    let balance_before_claim = system.token.balance_of(account: strk_delegator.reward.address);
    let rewards = system.delegator_claim_rewards(delegator: strk_delegator, pool: strk_pool);
    assert!(rewards == total_strk_pool_rewards);
    assert!(
        system.token.balance_of(account: strk_delegator.reward.address) == balance_before_claim
            + rewards,
    );

    let balance_before_claim = system.token.balance_of(account: btc_delegator.reward.address);
    let rewards = system.delegator_claim_rewards(delegator: btc_delegator, pool: btc_pool);
    assert!(rewards == total_btc_pool_rewards);
    assert!(
        system.token.balance_of(account: btc_delegator.reward.address) == balance_before_claim
            + rewards,
    );
}
