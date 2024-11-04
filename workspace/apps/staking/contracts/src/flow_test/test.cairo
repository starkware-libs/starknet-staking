use contracts::test_utils::StakingInitConfig;
use contracts::flow_test::utils as flow_test_utils;
use flow_test_utils::{SystemTrait, StakerTrait, StakingTrait, RewardSupplierTrait};
use flow_test_utils::{TokenTrait, DelegatorTrait};
use contracts_commons::constants::{WEEK};
use contracts::constants::{STRK_IN_FRIS};
use contracts_commons::types::time::{Time, TimeDelta};
use core::num::traits::Zero;

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
    let one_week = TimeDelta { seconds: 1 * WEEK };
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
    system.advance_time(time: one_week.mul(3));

    delegator.exit_action(:pool);
    staker.exit_action();

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount * 2);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), stake_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(system.reward_supplier.get_unclaimed_rewards() - STRK_IN_FRIS < 100);
}
