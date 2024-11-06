use contracts::test_utils::StakingInitConfig;
use contracts::flow_test::utils as flow_test_utils;
use contracts_commons::test_utils::{TokenTrait};
use flow_test_utils::{SystemTrait, StakerTrait, StakingTrait, RewardSupplierTrait};
use flow_test_utils::{DelegatorTrait};
use contracts::constants::{STRK_IN_FRIS};
use contracts_commons::types::time::Time;
use core::num::traits::Zero;
use contracts::utils::abs_diff;

/// Flow - Basic Stake:
/// Staker - Stake with pool - cover if pool_enabled=true
/// Staker increase_stake - cover if pool amount=0 in calc_rew
/// Delegator delegate (and create) to Staker
/// Staker increase_stake - cover pool amount > 0 in calc_rew
/// Delegator increase_delegate
/// Exit and check

#[test]
fn basic_stake_flow_test() {
    // TODO: new cfg - split to basic cfg and specific flow cfg.
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let one_week = Time::weeks(1);
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let staker = system.new_staker(amount: stake_amount * 2);
    staker.stake(amount: stake_amount, pool_enabled: true, commission: 200);
    system.advance_time(time: one_week);

    staker.increase_stake(amount: stake_amount / 2);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegator = system.new_delegator(amount: stake_amount);
    delegator.delegate(:pool, amount: stake_amount / 2);
    system.advance_time(time: one_week);

    staker.increase_stake(amount: stake_amount / 4);
    system.advance_time(time: one_week);

    delegator.increase_delegate(:pool, amount: stake_amount / 4);
    system.advance_time(time: one_week);

    delegator.exit_intent(:pool, amount: stake_amount * 3 / 4);
    system.advance_time(time: one_week);

    staker.exit_intent();
    system.advance_time(time: system.staking.get_exit_wait_window());

    delegator.exit_action(:pool);
    staker.exit_action();

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount * 2);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), stake_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool)
    );
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
    let mut system = SystemTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let initial_stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: initial_stake_amount * 2);
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let commission = 200;
    let one_week = Time::weeks(1);

    staker.stake(amount: initial_stake_amount, pool_enabled: false, :commission);
    system.advance_time(time: one_week);

    staker.increase_stake(amount: initial_stake_amount / 2);
    system.advance_time(time: one_week);

    assert!(system.token.balance_of(account: staker.reward.address).is_zero());
    staker.claim_rewards();
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());

    let pool = staker.set_open_for_delegation(:commission);
    system.advance_time(time: one_week);

    let delegator = system.new_delegator(amount: initial_stake_amount);
    delegator.delegate(:pool, amount: initial_stake_amount / 2);
    system.advance_time(time: one_week);

    staker.exit_intent();
    system.advance_time(time: system.staking.get_exit_wait_window());

    delegator.exit_intent(:pool, amount: initial_stake_amount / 2);
    system.advance_time(time: one_week);

    delegator.exit_action(:pool);
    staker.exit_action();

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), initial_stake_amount * 2);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), initial_stake_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool)
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
    let mut system = SystemTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let staker = system.new_staker(amount: stake_amount);
    let initial_reward_supplier_balance = system
        .token
        .balance_of(account: system.reward_supplier.address);
    let commission = 200;
    let one_week = Time::weeks(1);

    staker.stake(amount: stake_amount, pool_enabled: true, :commission);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount);
    delegator.delegate(:pool, amount: delegated_amount);
    system.advance_time(time: one_week);

    delegator.exit_intent(:pool, amount: delegated_amount / 2);
    system.advance_time(time: one_week);

    delegator.exit_intent(:pool, amount: delegated_amount / 4);
    system.advance_time(time: one_week);

    delegator.exit_intent(:pool, amount: delegated_amount / 2);
    system.advance_time(time: one_week);

    delegator.exit_intent(:pool, amount: Zero::zero());
    system.advance_time(time: one_week);

    delegator.exit_intent(:pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    delegator.exit_action(:pool);

    staker.exit_intent();
    system.advance_time(time: system.staking.get_exit_wait_window());
    staker.exit_action();

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), delegated_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
    assert_eq!(
        initial_reward_supplier_balance,
        system.token.balance_of(account: system.reward_supplier.address)
            + system.token.balance_of(account: staker.reward.address)
            + system.token.balance_of(account: delegator.reward.address)
            + system.token.balance_of(account: pool)
    );
}
