use contracts_commons::math::wide_abs_diff;
use contracts_commons::test_utils::TokenTrait;
use contracts_commons::types::time::time::Time;
use core::num::traits::Zero;
use flow_test_utils::{
    RewardSupplierTrait, StakingTrait, SystemConfigTrait, SystemDelegatorTrait, SystemStakerTrait,
    SystemTrait, test_flow_local, test_flow_mainnet,
};
use staking::constants::STRK_IN_FRIS;
use staking::flow_test::flows::BasicStakeFlow;
use staking::flow_test::utils as flow_test_utils;
use staking::test_utils::StakingInitConfig;

#[test]
fn basic_stake_flow_test() {
    let flow = BasicStakeFlow {};
    test_flow_local(:flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn basic_stake_flow_regression_test() {
    let mut flow = BasicStakeFlow {};
    test_flow_mainnet(ref :flow);
}

/// Flow:
/// Staker - Stake without pool - cover if pool_enabled=false
/// Staker increase_stake - cover if pool amount=none in update_rewards
/// Staker claim_rewards
/// Staker set_open_for_delegation
/// Delegator delegate - cover delegating after opening an initially closed pool
/// Exit and check
#[test]
fn set_open_for_delegation_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let initial_stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: initial_stake_amount * 2);
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let commission = 200;
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: initial_stake_amount, pool_enabled: false, :commission);
    system.advance_time(time: one_week);

    system.increase_stake(:staker, amount: initial_stake_amount / 2);
    system.advance_time(time: one_week);

    assert!(system.token.balance_of(account: staker.reward.address).is_zero());
    system.staker_claim_rewards(:staker);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());

    let pool = system.set_open_for_delegation(:staker, :commission);
    system.advance_time(time: one_week);

    let delegator = system.new_delegator(amount: initial_stake_amount);
    system.delegate(:delegator, :pool, amount: initial_stake_amount / 2);
    system.advance_time(time: one_week);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.delegator_exit_intent(:delegator, :pool, amount: initial_stake_amount / 2);
    system.advance_time(time: one_week);

    system.delegator_exit_action(:delegator, :pool);
    system.staker_exit_action(:staker);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), initial_stake_amount * 2);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), initial_stake_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Staker exit_intent
/// Staker exit_action
/// Delegator partially exit_intent - cover calculating rewards using `final_staker_index`
/// Delegator exit_action
/// Delegator exit_intent
/// Delegator exit_action
#[test]
fn delegator_intent_after_staker_action_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount * 2);
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let commission = 200;
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegator = system.new_delegator(amount: stake_amount);
    system.delegate(:delegator, :pool, amount: stake_amount);
    system.advance_time(time: one_week);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_action(:staker);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: stake_amount / 2);
    system.advance_time(time: one_week);
    system.delegator_exit_action(:delegator, :pool);

    system.delegator_exit_intent(:delegator, :pool, amount: stake_amount / 2);
    system.delegator_exit_action(:delegator, :pool);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount * 2);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), stake_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator exit_intent partial amount
/// Delegator exit_intent with lower amount - cover lowering partial undelegate
/// Delegator exit_intent with zero amount - cover clearing an intent
/// Delegator exit_intent all amount
/// Delegator exit_action
#[test]
fn delegator_intent_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount);
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let commission = 200;
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount);
    system.delegate(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 2);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 4);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 2);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: Zero::zero());
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, :pool);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(:staker);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegated_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}


// Flow 8:
// Staker1 stake
// Staker2 stake
// Delegator delegate to staker1's pool
// Staker1 exit_intent
// Delegator exit_intent - get current block_timestamp as exit time
// Staker1 exit_action - cover staker action with while having a delegator in intent
// Staker1 stake (again)
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
#[test]
fn operations_after_dead_staker_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
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
    let one_week = Time::weeks(count: 1);

    system.stake(staker: staker1, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    system.stake(staker: staker2, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let staker1_pool = system.staking.get_pool(staker: staker1);
    system.delegate(:delegator, pool: staker1_pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    system.staker_exit_intent(staker: staker1);
    system.advance_time(time: system.staking.get_exit_wait_window());

    // After the following, delegator has 1/2 in staker1, and 1/2 in intent.
    system.delegator_exit_intent(:delegator, pool: staker1_pool, amount: delegated_amount / 2);
    system.advance_time(time: one_week);

    system.staker_exit_action(staker: staker1);

    // Re-stake after exiting. Pool should be different.
    system.stake(staker: staker1, amount: stake_amount, pool_enabled: true, :commission);
    let staker1_second_pool = system.staking.get_pool(staker: staker1);
    system.advance_time(time: one_week);
    assert_ne!(staker1_pool, staker1_second_pool);

    // After the following, delegator has delegated_amount / 2 in staker1, delegated_amount / 4 in
    // intent, and delegated_amount / 4 in staker2.
    let staker2_pool = system.staking.get_pool(staker: staker2);
    system
        .switch_delegation_pool(
            :delegator,
            from_pool: staker1_pool,
            to_staker: staker2.staker.address,
            to_pool: staker2_pool,
            amount: delegated_amount / 4,
        );
    system.advance_time(time: one_week);

    // After the following, delegator has delegated_amount / 2 in staker1, and delegated_amount / 4
    // in staker2.
    system.delegator_exit_action(:delegator, pool: staker1_pool);
    system.advance_time(time: one_week);

    // Claim rewards from second pool and see that the rewards are increasing.
    let delegator_reward_balance_before_claim = system
        .token
        .balance_of(account: delegator.reward.address);
    system.delegator_claim_rewards(:delegator, pool: staker2_pool);
    system.advance_time(time: one_week);
    let delegator_reward_balance_after_claim = system
        .token
        .balance_of(account: delegator.reward.address);
    assert!(delegator_reward_balance_after_claim > delegator_reward_balance_before_claim);

    // After the following, delegator has delegated_amount / 4 in staker2.
    system.delegator_exit_intent(:delegator, pool: staker1_pool, amount: delegated_amount / 2);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, pool: staker1_pool);

    // Clean up and make all parties exit.
    system.staker_exit_intent(staker: staker1);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_intent(staker: staker2);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_action(staker: staker1);
    system.staker_exit_action(staker: staker2);
    system.delegator_exit_intent(:delegator, pool: staker2_pool, amount: delegated_amount / 4);
    system.delegator_exit_action(:delegator, pool: staker2_pool);

    // ------------- Flow complete, now asserts -------------

    // Assert pools' balances are low.
    assert!(system.token.balance_of(account: staker1_pool) < 100);
    assert!(system.token.balance_of(account: staker1_second_pool) < 100);
    assert!(system.token.balance_of(account: staker2_pool) < 100);

    // Assert all staked amounts were transferred back.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert_eq!(system.token.balance_of(account: staker1.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: staker2.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegated_amount);

    // Asserts reward addresses are not empty.
    assert!(system.token.balance_of(account: staker1.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: staker2.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());

    // Assert all funds that moved from rewards supplier, were moved to correct addresses.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker1.reward.address)
            + system.token.balance_of(account: staker2.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: staker1_pool)
            + system.token.balance_of(account: staker1_second_pool)
            + system.token.balance_of(account: staker2_pool),
    );
}

// Flow:
// Staker stake with commission 100%
// Delegator delegate
// Staker update_commission to 0%
// Delegator exit_intent
// Delegator exit_action, should get 0 rewards
// Staker exit_intent
// Staker exit_action
#[test]
fn delegator_didnt_update_after_staker_update_commission_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let delegated_amount = stake_amount;
    let staker = system.new_staker(amount: stake_amount);
    let delegator = system.new_delegator(amount: delegated_amount);
    let commission = 10000;
    let one_week = Time::weeks(count: 1);

    // Stake with commission 100%
    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    system.delegate(:delegator, :pool, amount: delegated_amount);

    // Update commission to 0%
    system.update_commission(:staker, commission: Zero::zero());
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, :pool);

    // Clean up and make all parties exit.
    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(:staker);

    // ------------- Flow complete, now asserts -------------

    // Assert pool balance is high.
    assert!(system.token.balance_of(account: pool) > 100);

    // Assert all staked amounts were transferred back.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegated_amount);

    // Assert staker reward address is not empty.
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());

    // Assert delegator reward address is empty.
    assert!(system.token.balance_of(account: delegator.reward.address).is_zero());

    // Assert all funds that moved from rewards supplier, were moved to correct addresses.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: pool),
    );
}

// Flow:
// Staker stake with commission 100%
// Delegator delegate
// Staker update_commission to 0%
// Delegator update commission to 0% by calling claim_rewards
// Delegator exit_intent
// Delegator exit_action, should get rewards
// Staker exit_intent
// Staker exit_action
#[test]
fn delegator_updated_after_staker_update_commission_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let delegated_amount = stake_amount;
    let staker = system.new_staker(amount: stake_amount);
    let delegator = system.new_delegator(amount: delegated_amount);
    let commission = 10000;
    let one_week = Time::weeks(count: 1);

    // Stake with commission 100%
    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    system.delegate(:delegator, :pool, amount: delegated_amount);

    // Update commission to 0%
    system.update_commission(:staker, commission: Zero::zero());
    system.advance_time(time: one_week);

    // Delegator claim_rewards to update commission to 0%
    system.delegator_claim_rewards(:delegator, :pool);
    assert_eq!(system.token.balance_of(account: delegator.reward.address), Zero::zero());
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, :pool);

    // Clean up and make all parties exit.
    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(:staker);

    // ------------- Flow complete, now asserts -------------

    // Assert pool balance is high.
    assert!(system.token.balance_of(account: pool) > 100);

    // Assert all staked amounts were transferred back.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegated_amount);

    // Asserts reward addresses are not empty.
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());

    // Assert all funds that moved from rewards supplier, were moved to correct addresses.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator exit_intent
/// Staker exit_intent
/// Staker exit_action
/// Delegator exit_action
#[test]
fn staker_intent_last_action_first_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let initial_stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: initial_stake_amount * 2);
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let commission = 200;
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: initial_stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegator = system.new_delegator(amount: initial_stake_amount);
    system.delegate(:delegator, :pool, amount: initial_stake_amount / 2);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: initial_stake_amount / 2);
    system.advance_time(time: one_week);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_action(:staker);
    system.advance_time(time: one_week);

    system.delegator_exit_action(:delegator, :pool);
    system.advance_time(time: one_week);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), initial_stake_amount * 2);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), initial_stake_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator exit_intent full amount
/// Delegator switch full amount to the same delegation pool
#[test]
#[should_panic(expected: "SELF_SWITCH_NOT_ALLOWED")]
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
/// Staker exit_intent.
/// Advance time less than exit_wait_window.
/// Delegator delegate.
/// Delegator claim rewards - cover `claim_delegation_pool_rewards` when staker in intent.
/// Delegator intent - cover pool in intent when staker still alive but in intent. Ignores if
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
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount * 2);
    system.delegate(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window().div(divider: 2));

    system.delegator_claim_rewards(:delegator, :pool);
    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.delegator_exit_action(:delegator, :pool);
    system.staker_exit_action(:staker);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount * 2);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegated_amount * 2);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
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
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegated_amount = stake_amount;

    let delegator_x = system.new_delegator(amount: delegated_amount);
    system.delegate(delegator: delegator_x, :pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    let delegator_y = system.new_delegator(amount: delegated_amount);
    system.delegate(delegator: delegator_y, :pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(delegator: delegator_x, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.delegator_exit_action(delegator: delegator_x, :pool);
    system.delegator_exit_intent(delegator: delegator_y, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.delegator_exit_action(delegator: delegator_y, :pool);
    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_action(:staker);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator_x.delegator.address), delegated_amount);
    assert_eq!(system.token.balance_of(account: delegator_y.delegator.address), delegated_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator_x.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator_y.reward.address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
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
    let one_week = Time::weeks(count: 1);

    let first_staker = system.new_staker(amount: stake_amount);
    system.stake(staker: first_staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount);
    let first_pool = system.staking.get_pool(staker: first_staker);
    system.delegate(:delegator, pool: first_pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    let second_staker = system.new_staker(amount: stake_amount);
    system.stake(staker: second_staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

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

    system.delegator_exit_action(:delegator, pool: first_pool);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, pool: second_pool, amount: delegated_amount / 8);
    system
        .switch_delegation_pool(
            :delegator,
            from_pool: second_pool,
            to_staker: first_staker.staker.address,
            to_pool: first_pool,
            amount: delegated_amount / 8,
        );
    system.advance_time(time: one_week);

    let new_reward_address = system.new_account(amount: Zero::zero()).address;
    system
        .delegator_change_reward_address(
            :delegator, pool: second_pool, reward_address: new_reward_address,
        );
    system.advance_time(time: one_week);

    system.delegator_claim_rewards(:delegator, pool: first_pool);
    system.delegator_claim_rewards(:delegator, pool: second_pool);

    system.delegator_exit_intent(:delegator, pool: first_pool, amount: (delegated_amount * 5 / 8));
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, pool: first_pool);

    system.delegator_exit_intent(:delegator, pool: second_pool, amount: delegated_amount / 8);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, pool: second_pool);

    system.staker_exit_intent(staker: first_staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(staker: first_staker);

    system.staker_exit_intent(staker: second_staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(staker: second_staker);

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: first_pool) < 100);
    assert!(system.token.balance_of(account: second_pool) < 100);
    assert_eq!(system.token.balance_of(account: first_staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: second_staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegated_amount);

    assert!(system.token.balance_of(account: first_staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: second_staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: new_reward_address).is_non_zero());
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
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
    let one_week = Time::weeks(count: 1);

    let staker_A = system.new_staker(amount: stake_amount);
    system.stake(staker: staker_A, amount: stake_amount, pool_enabled: true, :commission);
    assert_eq!(system.staking.get_total_stake(), stake_amount);
    let pool_A = system.staking.get_pool(staker: staker_A);
    system.advance_time(time: one_week);

    let staker_B = system.new_staker(amount: stake_amount);
    system.stake(staker: staker_B, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);
    let pool_B = system.staking.get_pool(staker: staker_B);

    assert_eq!(system.staking.get_total_stake(), 2 * stake_amount);

    let delegator_Y = system.new_delegator(amount: delegated_amount);
    system.delegate(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);

    system.advance_time(time: one_week);
    assert_eq!(system.staking.get_total_stake(), 2 * stake_amount + delegated_amount);
    assert_eq!(
        system.token.balance_of(account: system.staking.address),
        2 * stake_amount + delegated_amount,
    );

    // DY intend to exit PB & switch to PA.
    system.delegator_exit_intent(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);
    system.advance_time(time: one_week);
    system
        .switch_delegation_pool(
            delegator: delegator_Y,
            from_pool: pool_B,
            to_staker: staker_A.staker.address,
            to_pool: pool_A,
            amount: delegated_amount,
        );

    // DY intend to exit PA & switch to PB.
    system.delegator_exit_intent(delegator: delegator_Y, pool: pool_A, amount: delegated_amount);
    system.advance_time(time: one_week);
    system
        .switch_delegation_pool(
            delegator: delegator_Y,
            from_pool: pool_A,
            to_staker: staker_B.staker.address,
            to_pool: pool_B,
            amount: delegated_amount,
        );

    // Perform test end clearance - All stakers and delegators exit staking.
    system.delegator_exit_intent(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(delegator: delegator_Y, pool: pool_B);

    system.staker_exit_intent(staker: staker_B);
    system.staker_exit_intent(staker: staker_A);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(staker: staker_A);
    system.staker_exit_action(staker: staker_B);

    /// Post clearance checks: ///

    // 1. Token balance virtually zero on stakers. Zero on staking contract.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool_A) < 100);
    assert!(system.token.balance_of(account: pool_B) < 100);

    // 2. Stakers and delegator balances are the staked amounts.
    assert_eq!(system.token.balance_of(account: staker_A.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: staker_B.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator_Y.delegator.address), delegated_amount);

    // 3. Reward addresses have some balance for all stakers & delegators.
    assert!(system.token.balance_of(account: staker_A.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: staker_B.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator_Y.reward.address).is_non_zero());

    // 4. Virtually all rewards awarded were claimed.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

    // 5. Rewards funds are well accounted for.
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
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
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegator_amount = stake_amount;

    let first_delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(delegator: first_delegator, :pool, amount: delegator_amount / 2);
    system.advance_time(time: one_week);

    let second_delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(delegator: second_delegator, :pool, amount: delegator_amount / 2);
    system.advance_time(time: one_week);

    system
        .add_to_delegation_pool(
            delegator: first_delegator, pool: pool, amount: delegator_amount / 2,
        );
    system.advance_time(time: one_week);

    system
        .add_to_delegation_pool(
            delegator: second_delegator, pool: pool, amount: delegator_amount / 2,
        );
    system.advance_time(time: one_week);

    system.delegator_exit_intent(delegator: first_delegator, :pool, amount: delegator_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(delegator: first_delegator, :pool);

    system.delegator_exit_intent(delegator: second_delegator, :pool, amount: delegator_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(delegator: second_delegator, :pool);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(:staker);

    // Post clearance checks:

    // 1. Token balance virtually zero on stakers. Zero on staking contract.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);

    // 2. Stakers and delegator balances are the staked amounts.
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount);
    assert_eq!(
        system.token.balance_of(account: first_delegator.delegator.address), delegator_amount,
    );
    assert_eq!(
        system.token.balance_of(account: second_delegator.delegator.address), delegator_amount,
    );

    // 3. Reward addresses have some balance for all stakers & delegators.
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: first_delegator.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: first_delegator.reward.address).is_non_zero());

    // 4. Virtually all rewards awarded were claimed.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

    // 5. Rewards funds are well accounted for.
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: first_delegator.reward.address)
            + system.token.balance_of(account: second_delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator full exit_intent
/// Staker exit_intent
/// Staker exit_action
/// Staker stake again
/// Delegator full switch_delegation_pool to staker's new pool
/// Delegator partial exit_intent
/// Staker exit_intent
/// Staker exit_action
/// Staker stake again
/// Delegator partial switch_delegation_pool to staker's new pool
#[test]
fn same_staker_different_pool_flow_test() {
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let delegated_amount = stake_amount;
    let staker = system.new_staker(amount: stake_amount);
    let delegator = system.new_delegator(amount: delegated_amount);
    let commission = 200;
    let one_week = Time::weeks(count: 1);

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    system.delegate(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    // Delegator full exit intent.
    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_action(:staker);

    // Re-stake after exiting. Pool should be different.
    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);
    let second_pool = system.staking.get_pool(:staker);
    assert!(pool != second_pool);

    // Full switch.
    system
        .switch_delegation_pool(
            :delegator,
            from_pool: pool,
            to_staker: staker.staker.address,
            to_pool: second_pool,
            amount: delegated_amount,
        );
    system.advance_time(time: one_week);

    // Delegator partially exit intent.
    let partial_amount = delegated_amount / 2;
    system.delegator_exit_intent(:delegator, pool: second_pool, amount: partial_amount);
    system.advance_time(time: one_week);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_action(:staker);

    // Second re-stake after exiting. Pool should be different.
    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);
    let third_pool = system.staking.get_pool(:staker);
    assert!(second_pool != third_pool);

    // Partial switch.
    system
        .switch_delegation_pool(
            :delegator,
            from_pool: second_pool,
            to_staker: staker.staker.address,
            to_pool: third_pool,
            amount: partial_amount / 2,
        );
    system
        .switch_delegation_pool(
            :delegator,
            from_pool: second_pool,
            to_staker: staker.staker.address,
            to_pool: third_pool,
            amount: partial_amount / 2,
        );
    system.advance_time(time: one_week);

    // Clean up and make all parties exit.
    system.delegator_exit_intent(:delegator, pool: second_pool, amount: partial_amount);
    system.delegator_exit_intent(:delegator, pool: third_pool, amount: partial_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, pool: second_pool);
    system.delegator_exit_action(:delegator, pool: third_pool);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(:staker);

    // ------------- Flow complete, now asserts -------------

    // Assert pools' balances are low.
    assert!(system.token.balance_of(account: pool) < 100);
    assert!(system.token.balance_of(account: second_pool) < 100);
    assert!(system.token.balance_of(account: third_pool) < 100);

    // Assert all staked amounts were transferred back.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegated_amount);

    // Asserts reward addresses are not empty.
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());

    // Assert all funds that moved from rewards supplier, were moved to correct addresses.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool)
            + system.token.balance_of(account: second_pool)
            + system.token.balance_of(account: third_pool),
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
    let one_week = Time::weeks(1);

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegator_amount = stake_amount;

    let delegator = system.new_delegator(amount: delegator_amount);
    system.delegate(:delegator, :pool, amount: delegator_amount / 2);
    system.advance_time(time: one_week);

    // Partial intent.
    system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount / 4);
    system.advance_time(time: one_week);

    system.add_to_delegation_pool(:delegator, pool: pool, amount: delegator_amount / 4);
    system.advance_time(time: one_week);

    // Full intent.
    system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount * 3 / 4);
    system.advance_time(time: one_week);

    system.add_to_delegation_pool(:delegator, pool: pool, amount: delegator_amount / 4);
    system.advance_time(time: one_week);

    system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.delegator_exit_action(:delegator, :pool);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.staker_exit_action(:staker);

    // Post clearance checks:

    // 1. Token balance virtually zero on stakers. Zero on staking contract.
    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);

    // 2. Stakers and delegator balances are the staked amounts.
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegator_amount);

    // 3. Reward addresses have some balance for all stakers & delegators.
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());

    // 4. Virtually all rewards awarded were claimed.
    assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

    // 5. Rewards funds are well accounted for.
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool),
    );
}
