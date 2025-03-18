// TODO: Update and uncomment the following tests to align with the new rewards mechanism.

use core::num::traits::Zero;
use staking::constants::STRK_IN_FRIS;
use staking::flow_test::flows;
use staking::flow_test::utils::{
    RewardSupplierTrait, StakingTrait, SystemConfigTrait, SystemDelegatorTrait, SystemStakerTrait,
    SystemTrait, test_flow_local, test_flow_mainnet,
};
use staking::test_utils::StakingInitConfig;
use starkware_utils::math::abs::wide_abs_diff;
use starkware_utils::test_utils::TokenTrait;
use starkware_utils::types::time::time::Time;

#[test]
fn basic_stake_flow_test() {
    let flow = flows::BasicStakeFlow {};
    test_flow_local(:flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn basic_stake_flow_regression_test() {
    let mut flow = flows::BasicStakeFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
fn set_open_for_delegation_flow_test() {
    let flow = flows::SetOpenForDelegationFlow {};
    test_flow_local(:flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn set_open_for_delegation_regression_test() {
    let mut flow = flows::SetOpenForDelegationFlow {};
    test_flow_mainnet(ref :flow);
}
#[test]
fn delegator_intent_after_staker_action_flow_test() {
    let flow = flows::DelegatorIntentAfterStakerActionFlow {};
    test_flow_local(:flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_after_staker_action_regression_test() {
    let mut flow = flows::DelegatorIntentAfterStakerActionFlow {};
    test_flow_mainnet(ref :flow);
}
#[test]
fn delegator_intent_flow_test() {
    let flow = flows::DelegatorIntentFlow {};
    test_flow_local(:flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_regression_test() {
    let mut flow = flows::DelegatorIntentFlow {};
    test_flow_mainnet(ref :flow);
}
// #[test]
// fn operations_after_dead_staker_flow_test() {
//     let flow = flows::OperationsAfterDeadStakerFlow {};
//     test_flow_local(:flow);
// }

// #[test]
// #[fork("MAINNET_LATEST")]
// fn operations_after_dead_staker_regression_test() {
//     let mut flow = flows::OperationsAfterDeadStakerFlow {};
//     test_flow_mainnet(ref :flow);
// }

#[test]
fn delegator_didnt_update_after_staker_update_commission_flow_test() {
    let flow = flows::DelegatorDidntUpdateAfterStakerUpdateCommissionFlow {};
    test_flow_local(:flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_didnt_update_after_staker_update_commission_regression_test() {
    let mut flow = flows::DelegatorDidntUpdateAfterStakerUpdateCommissionFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
fn delegator_updated_after_staker_update_commission_flow_test() {
    let flow = flows::DelegatorUpdatedAfterStakerUpdateCommissionFlow {};
    test_flow_local(:flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_updated_after_staker_update_commission_regression_test() {
    let mut flow = flows::DelegatorUpdatedAfterStakerUpdateCommissionFlow {};
    test_flow_mainnet(ref :flow);
}
#[test]
fn staker_intent_last_action_first_flow_test() {
    let flow = flows::StakerIntentLastActionFirstFlow {};
    test_flow_local(:flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_intent_last_action_first_regression_test() {
    let mut flow = flows::StakerIntentLastActionFirstFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_info_after_upgrade_regression_test() {
    let mut flow = flows::StakerInfoAfterUpgradeFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_info_with_pool_after_upgrade_regression_test() {
    let mut flow = flows::StakerInfoWithPoolAfterUpgradeFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_info_unstake_after_upgrade_regression_test() {
    let mut flow = flows::StakerInfoUnstakeAfterUpgradeFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn internal_staker_info_after_upgrade_regression_test() {
    let mut flow = flows::InternalStakerInfoAfterUpgradeFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn internal_staker_info_with_pool_after_upgrade_regression_test() {
    let mut flow = flows::InternalStakerInfoWithPoolAfterUpgradeFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn internal_staker_info_unstake_after_upgrade_regression_test() {
    let mut flow = flows::InternalStakerInfoUnstakeAfterUpgradeFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_upgrade_flow_regression_test() {
    let mut flow = flows::PoolUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, delegated_amount: Zero::zero(),
    };
    test_flow_mainnet(ref :flow);
}
// #[test]
// #[fork("MAINNET_LATEST")]
// fn internal_pool_member_info_after_upgrade_regression_test() {
//     let mut flow = flows::InternalPoolMemberInfoAfterUpgradeFlow {
//         pool_address: Option::None, delegator: Option::None, delegator_info: Option::None,
//     };
//     test_flow_mainnet(ref :flow);
// }

// #[test]
// #[fork("MAINNET_LATEST")]
// fn internal_pool_member_info_undelegate_after_upgrade_regression_test() {
//     let mut flow = flows::InternalPoolMemberInfoUndelegateAfterUpgradeFlow {
//         pool_address: Option::None, delegator: Option::None, delegator_info: Option::None,
//     };
//     test_flow_mainnet(ref :flow);
// }

// /// Flow:
// /// Staker Stake
// /// Delegator delegate
// /// Delegator exit_intent full amount
// /// Delegator switch full amount to the same delegation pool
// #[test]
// #[should_panic(expected: "SELF_SWITCH_NOT_ALLOWED")]
// fn switch_to_same_delegation_pool_flow_test() {
//     let cfg: StakingInitConfig = Default::default();
//     let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
//     let min_stake = system.staking.get_min_stake();
//     let stake_amount = min_stake * 2;
//     let staker = system.new_staker(amount: stake_amount);
//     let commission = 200;
//     let one_week = Time::weeks(count: 1);

//     system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
//     system.advance_time(time: one_week);

//     let pool = system.staking.get_pool(:staker);
//     let delegated_amount = stake_amount;
//     let delegator = system.new_delegator(amount: delegated_amount);
//     system.delegate(:delegator, :pool, amount: delegated_amount);
//     system.advance_time(time: one_week);

//     system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
//     system.advance_time(time: one_week);

//     system
//         .switch_delegation_pool(
//             :delegator,
//             from_pool: pool,
//             to_staker: staker.staker.address,
//             to_pool: pool,
//             amount: delegated_amount,
//         );
// }

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
    system.advance_epoch_and_attest(:staker);

    let pool = system.staking.get_pool(:staker);
    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount * 2);
    system.delegate(:delegator, :pool, amount: delegated_amount);
    system.advance_epoch_and_attest(:staker);

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
    system.advance_epoch_and_attest(:staker);

    let pool = system.staking.get_pool(:staker);
    let delegated_amount = stake_amount;

    let delegator_x = system.new_delegator(amount: delegated_amount);
    system.delegate(delegator: delegator_x, :pool, amount: delegated_amount);
    system.advance_epoch_and_attest(:staker);

    let delegator_y = system.new_delegator(amount: delegated_amount);
    system.delegate(delegator: delegator_y, :pool, amount: delegated_amount);
    system.advance_epoch_and_attest(:staker);

    system.delegator_exit_intent(delegator: delegator_x, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_epoch_and_attest(:staker);

    system.delegator_exit_action(delegator: delegator_x, :pool);
    system.advance_epoch_and_attest(:staker);

    system.delegator_exit_intent(delegator: delegator_y, :pool, amount: delegated_amount);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_epoch_and_attest(:staker);

    system.delegator_exit_action(delegator: delegator_y, :pool);
    system.advance_epoch_and_attest(:staker);

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
    system.advance_epoch_and_attest(staker: first_staker);

    let delegated_amount = stake_amount;
    let delegator = system.new_delegator(amount: delegated_amount);
    let first_pool = system.staking.get_pool(staker: first_staker);
    system.delegate(:delegator, pool: first_pool, amount: delegated_amount);
    system.advance_epoch_and_attest(staker: first_staker);

    let second_staker = system.new_staker(amount: stake_amount);
    system.stake(staker: second_staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_epoch_and_attest(staker: first_staker);
    system.advance_epoch_and_attest(staker: second_staker);

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
    system.advance_epoch_and_attest(staker: first_staker);
    system.advance_epoch_and_attest(staker: second_staker);

    system.delegator_exit_action(:delegator, pool: first_pool);
    system.advance_epoch_and_attest(staker: first_staker);
    system.advance_epoch_and_attest(staker: second_staker);

    system.delegator_exit_intent(:delegator, pool: second_pool, amount: delegated_amount / 8);
    system
        .switch_delegation_pool(
            :delegator,
            from_pool: second_pool,
            to_staker: first_staker.staker.address,
            to_pool: first_pool,
            amount: delegated_amount / 8,
        );
    system.advance_epoch_and_attest(staker: first_staker);
    system.advance_epoch_and_attest(staker: second_staker);

    let new_reward_address = system.new_account(amount: Zero::zero()).address;
    system
        .delegator_change_reward_address(
            :delegator, pool: second_pool, reward_address: new_reward_address,
        );
    system.advance_epoch_and_attest(staker: first_staker);
    system.advance_epoch_and_attest(staker: second_staker);

    system.delegator_claim_rewards(:delegator, pool: first_pool);
    system.delegator_claim_rewards(:delegator, pool: second_pool);

    system.delegator_exit_intent(:delegator, pool: first_pool, amount: (delegated_amount * 5 / 8));
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_epoch_and_attest(staker: first_staker);
    system.advance_epoch_and_attest(staker: second_staker);
    system.delegator_exit_action(:delegator, pool: first_pool);

    system.delegator_exit_intent(:delegator, pool: second_pool, amount: delegated_amount / 8);
    system.advance_exit_wait_window();
    system.delegator_exit_action(:delegator, pool: second_pool);
    system.advance_epoch_and_attest(staker: first_staker);
    system.advance_epoch_and_attest(staker: second_staker);

    system.staker_exit_intent(staker: first_staker);
    system.advance_time(time: system.staking.get_exit_wait_window());
    system.advance_epoch_and_attest(staker: second_staker);
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
// /// Flow - 4:
// /// Staker A (SA) adds stake w/pool
// /// Staker B (SB) adds stake w/pool
// /// Delegtor Y (DY) add (100) to SB's pool
// /// - check 1
// ///
// /// DY intent to exit all (100) tokens from SB
// /// DY switches all (100) to SA
// /// - check 2
// ///
// /// DY intent to exit all (100) tokens from SA
// /// DY switches all (100) to SB
// /// - check 3
// ///
// /// clearance
// /// - check4 (clearance)
// #[test]
// fn flow_4_switch_member_back_and_forth_test() {
//     let cfg: StakingInitConfig = Default::default();
//     let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
//     let min_stake = system.staking.get_min_stake();
//     let stake_amount = min_stake * 2;
//     let delegated_amount = stake_amount;

//     let initial_reward_supplier_balance = system
//         .token
//         .balance_of(account: system.reward_supplier.address);
//     let commission = 200;
//     let one_week = Time::weeks(count: 1);

//     let staker_A = system.new_staker(amount: stake_amount);
//     system.stake(staker: staker_A, amount: stake_amount, pool_enabled: true, :commission);
//     assert!(system.staking.get_total_stake() == stake_amount);
//     let pool_A = system.staking.get_pool(staker: staker_A);
//     system.advance_time(time: one_week);

//     let staker_B = system.new_staker(amount: stake_amount);
//     system.stake(staker: staker_B, amount: stake_amount, pool_enabled: true, :commission);
//     system.advance_time(time: one_week);
//     let pool_B = system.staking.get_pool(staker: staker_B);

//     assert!(system.staking.get_total_stake() == 2 * stake_amount);

//     let delegator_Y = system.new_delegator(amount: delegated_amount);
//     system.delegate(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);

//     system.advance_time(time: one_week);
//     assert!(system.staking.get_total_stake() == 2 * stake_amount + delegated_amount);
//     assert!(
//         system.token.balance_of(account: system.staking.address) == 2 * stake_amount
//             + delegated_amount,
//     );

//     // DY intend to exit PB & switch to PA.
//     system.delegator_exit_intent(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);
//     system.advance_time(time: one_week);
//     system
//         .switch_delegation_pool(
//             delegator: delegator_Y,
//             from_pool: pool_B,
//             to_staker: staker_A.staker.address,
//             to_pool: pool_A,
//             amount: delegated_amount,
//         );

//     // DY intend to exit PA & switch to PB.
//     system.delegator_exit_intent(delegator: delegator_Y, pool: pool_A, amount: delegated_amount);
//     system.advance_time(time: one_week);
//     system
//         .switch_delegation_pool(
//             delegator: delegator_Y,
//             from_pool: pool_A,
//             to_staker: staker_B.staker.address,
//             to_pool: pool_B,
//             amount: delegated_amount,
//         );

//     // Perform test end clearance - All stakers and delegators exit staking.
//     system.delegator_exit_intent(delegator: delegator_Y, pool: pool_B, amount: delegated_amount);
//     system.advance_time(time: system.staking.get_exit_wait_window());
//     system.delegator_exit_action(delegator: delegator_Y, pool: pool_B);

//     system.staker_exit_intent(staker: staker_B);
//     system.staker_exit_intent(staker: staker_A);
//     system.advance_time(time: system.staking.get_exit_wait_window());
//     system.staker_exit_action(staker: staker_A);
//     system.staker_exit_action(staker: staker_B);

//     /// Post clearance checks: ///

//     // 1. Token balance virtually zero on stakers. Zero on staking contract.
//     assert!(system.token.balance_of(account: system.staking.address).is_zero());
//     assert!(system.token.balance_of(account: pool_A) == 0);
//     assert!(
//         system.token.balance_of(account: pool_B) > 100,
//     ); // TODO: Change this after implement calculate_rewards.

//     // 2. Stakers and delegator balances are the staked amounts.
//     assert!(system.token.balance_of(account: staker_A.staker.address) == stake_amount);
//     assert!(system.token.balance_of(account: staker_B.staker.address) == stake_amount);
//     assert!(system.token.balance_of(account: delegator_Y.delegator.address) == delegated_amount);

//     // 3. Reward addresses have some balance for all stakers & delegators.
//     assert!(system.token.balance_of(account: staker_A.reward.address).is_non_zero());
//     assert!(system.token.balance_of(account: staker_B.reward.address).is_non_zero());
//     assert!(
//         system.token.balance_of(account: delegator_Y.reward.address).is_zero(),
//     ); // TODO: Change this after implement calculate_rewards.

//     // 4. Virtually all rewards awarded were claimed.
//     assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

//     // 5. Rewards funds are well accounted for.
//     assert!(
//         initial_reward_supplier_balance == system
//             .token
//             .balance_of(account: system.reward_supplier.address)
//             + system.token.balance_of(account: staker_A.reward.address)
//             + system.token.balance_of(account: staker_B.reward.address)
//             + system.token.balance_of(account: delegator_Y.reward.address)
//             + system.token.balance_of(account: pool_A)
//             + system.token.balance_of(account: pool_B),
//     );
// }

// /// flow:
// /// Staker stake
// /// First delegator delegate
// /// Second delegator delegate
// /// First delegator add_to_delegation_pool
// /// Second delegator add_to_delegation_pool
// /// First delegator exit_intent
// /// First delegator exit_action
// /// Second delegator exit_intent
// /// Second delegator exit_action
// /// Staker exit_intent
// /// Staker exit_action
// #[test]
// fn delegators_add_to_delegation_pool_flow_test() {
//     let cfg: StakingInitConfig = Default::default();
//     let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
//     let min_stake = system.staking.get_min_stake();
//     let stake_amount = min_stake * 2;
//     let staker = system.new_staker(amount: stake_amount);
//     let initial_reward_supplier_balance = system
//         .token
//         .balance_of(account: system.reward_supplier.address);
//     let commission = 200;
//     let one_week = Time::weeks(count: 1);

//     system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
//     system.advance_time(time: one_week);

//     let pool = system.staking.get_pool(:staker);
//     let delegator_amount = stake_amount;

//     let first_delegator = system.new_delegator(amount: delegator_amount);
//     system.delegate(delegator: first_delegator, :pool, amount: delegator_amount / 2);
//     system.advance_time(time: one_week);

//     let second_delegator = system.new_delegator(amount: delegator_amount);
//     system.delegate(delegator: second_delegator, :pool, amount: delegator_amount / 2);
//     system.advance_time(time: one_week);

//     system
//         .add_to_delegation_pool(
//             delegator: first_delegator, pool: pool, amount: delegator_amount / 2,
//         );
//     system.advance_time(time: one_week);

//     system
//         .add_to_delegation_pool(
//             delegator: second_delegator, pool: pool, amount: delegator_amount / 2,
//         );
//     system.advance_time(time: one_week);

//     system.delegator_exit_intent(delegator: first_delegator, :pool, amount: delegator_amount);
//     system.advance_time(time: system.staking.get_exit_wait_window());
//     system.delegator_exit_action(delegator: first_delegator, :pool);

//     system.delegator_exit_intent(delegator: second_delegator, :pool, amount: delegator_amount);
//     system.advance_time(time: system.staking.get_exit_wait_window());
//     system.delegator_exit_action(delegator: second_delegator, :pool);

//     system.staker_exit_intent(:staker);
//     system.advance_time(time: system.staking.get_exit_wait_window());
//     system.staker_exit_action(:staker);

//     // Post clearance checks:

//     // 1. Token balance virtually zero on stakers. Zero on staking contract.
//     assert!(system.token.balance_of(account: system.staking.address).is_zero());
//     assert!(
//         system.token.balance_of(account: pool) > 100,
//     ); // TODO: Change this after implement calculate_rewards.

//     // 2. Stakers and delegator balances are the staked amounts.
//     assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
//     assert!(
//         system.token.balance_of(account: first_delegator.delegator.address) == delegator_amount,
//     );
//     assert!(
//         system.token.balance_of(account: second_delegator.delegator.address) == delegator_amount,
//     );

//     // 3. Reward addresses have some balance for all stakers & delegators.
//     assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
//     assert!(
//         system.token.balance_of(account: first_delegator.reward.address).is_zero(),
//     ); // TODO: Change this after implement calculate_rewards.
//     assert!(
//         system.token.balance_of(account: second_delegator.reward.address).is_zero(),
//     ); // TODO: Change this after implement calculate_rewards.

//     // 4. Virtually all rewards awarded were claimed.
//     assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

//     // 5. Rewards funds are well accounted for.
//     assert!(
//         initial_reward_supplier_balance == system
//             .token
//             .balance_of(account: system.reward_supplier.address)
//             + system.token.balance_of(account: staker.reward.address)
//             + system.token.balance_of(account: first_delegator.reward.address)
//             + system.token.balance_of(account: second_delegator.reward.address)
//             + system.token.balance_of(account: pool),
//     );
// }

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

    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_epoch_and_attest(:staker);

    let pool = system.staking.get_pool(:staker);
    system.delegate(:delegator, :pool, amount: delegated_amount);
    system.advance_epoch_and_attest(:staker);

    // Delegator full exit intent.
    system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
    system.advance_epoch_and_attest(:staker);

    system.staker_exit_intent(:staker);
    system.advance_exit_wait_window();

    system.staker_exit_action(:staker);

    // Re-stake after exiting. Pool should be different.
    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_epoch_and_attest(:staker);
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
    system.delegator_claim_rewards(:delegator, :pool);
    system.advance_epoch_and_attest(:staker);

    // Delegator partially exit intent.
    let partial_amount = delegated_amount / 2;
    system.delegator_exit_intent(:delegator, pool: second_pool, amount: partial_amount);
    system.advance_epoch_and_attest(:staker);

    system.staker_exit_intent(:staker);
    system.advance_time(time: system.staking.get_exit_wait_window());

    system.staker_exit_action(:staker);

    // Second re-stake after exiting. Pool should be different.
    system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
    system.advance_epoch_and_attest(:staker);
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
    system.advance_epoch_and_attest(:staker);

    // Clean up and make all parties exit.
    system.delegator_exit_intent(:delegator, pool: second_pool, amount: partial_amount);
    system.delegator_exit_intent(:delegator, pool: third_pool, amount: partial_amount);
    system.advance_exit_wait_window();
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
            + system.token.balance_of(account: pool)
            + system.token.balance_of(account: second_pool)
            + system.token.balance_of(account: third_pool),
    );
}
// /// Flow:
// /// Staker stake
// /// Delegator delegate
// /// Delegator partial exit_intent
// /// Delegator add_to_delegation_pool
// /// Delegator full exit_intent
// /// Delegator add_to_delegation_pool
// /// Delegator full exit_intent
// /// Delegator exit_action
// /// Staker exit_intent
// /// Staker exit_action
// #[test]
// fn add_to_delegation_after_intent_flow_test() {
//     let cfg: StakingInitConfig = Default::default();
//     let mut system = SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy();
//     let min_stake = system.staking.get_min_stake();
//     let stake_amount = min_stake * 2;
//     let staker = system.new_staker(amount: stake_amount);
//     let initial_reward_supplier_balance = system
//         .token
//         .balance_of(account: system.reward_supplier.address);
//     let commission = 200;
//     let one_week = Time::weeks(1);

//     system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
//     system.advance_time(time: one_week);

//     let pool = system.staking.get_pool(:staker);
//     let delegator_amount = stake_amount;

//     let delegator = system.new_delegator(amount: delegator_amount);
//     system.delegate(:delegator, :pool, amount: delegator_amount / 2);
//     system.advance_time(time: one_week);

//     // Partial intent.
//     system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount / 4);
//     system.advance_time(time: one_week);

//     system.add_to_delegation_pool(:delegator, pool: pool, amount: delegator_amount / 4);
//     system.advance_time(time: one_week);

//     // Full intent.
//     system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount * 3 / 4);
//     system.advance_time(time: one_week);

//     system.add_to_delegation_pool(:delegator, pool: pool, amount: delegator_amount / 4);
//     system.advance_time(time: one_week);

//     system.delegator_exit_intent(:delegator, :pool, amount: delegator_amount);
//     system.advance_time(time: system.staking.get_exit_wait_window());
//     system.delegator_exit_action(:delegator, :pool);

//     system.staker_exit_intent(:staker);
//     system.advance_time(time: system.staking.get_exit_wait_window());
//     system.staker_exit_action(:staker);

//     // Post clearance checks:

//     // 1. Token balance virtually zero on stakers. Zero on staking contract.
//     assert!(system.token.balance_of(account: system.staking.address).is_zero());
//     assert!(
//         system.token.balance_of(account: pool) > 100,
//     ); // TODO: Change this after implement calculate_rewards.

//     // 2. Stakers and delegator balances are the staked amounts.
//     assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
//     assert!(system.token.balance_of(account: delegator.delegator.address) == delegator_amount);

//     // 3. Reward addresses have some balance for all stakers & delegators.
//     assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
//     assert!(
//         system.token.balance_of(account: delegator.reward.address).is_zero(),
//     ); // TODO: Change this after implement calculate_rewards.

//     // 4. Virtually all rewards awarded were claimed.
//     assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);

//     // 5. Rewards funds are well accounted for.
//     assert!(
//         initial_reward_supplier_balance == system
//             .token
//             .balance_of(account: system.reward_supplier.address)
//             + system.token.balance_of(account: staker.reward.address)
//             + system.token.balance_of(account: delegator.reward.address)
//             + system.token.balance_of(account: pool),
//     );
// }


