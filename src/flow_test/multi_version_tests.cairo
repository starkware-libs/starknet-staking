use core::num::traits::Zero;
use staking::flow_test::flows;
use staking::flow_test::utils::test_multi_version_flow_mainnet;

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_exit_intent_upgrade_switch_regression_test() {
    let mut flow = flows::DelegatorExitIntentUpgradeSwitchFlow {
        staker: Option::None,
        delegator: Option::None,
        delegated_amount: Option::None,
        initial_reward_supplier_balance: Option::None,
        initial_stake_amount: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_upgrade_flow_regression_test() {
    let mut flow = flows::PoolUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, delegated_amount: Zero::zero(),
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn intent_delegator_upgrade_switch_regression_test() {
    let mut flow = flows::IntentDelegatorUpgradeSwitchFlow {
        staker: Option::None,
        pool_address: Option::None,
        delegator_full_intent: Option::None,
        delegator_half_intent: Option::None,
        delegator_zero_intent: Option::None,
        amount: Option::None,
        commission: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_attest_regression_test() {
    let mut flow = flows::PoolAttestFlow {
        staker: Option::None,
        delegator: Option::None,
        pool_rewards: Option::None,
        staker_rewards: Option::None,
        commission: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn intent_delegator_upgrade_intent_flow_test() {
    let mut flow = flows::IntentDelegatorUpgradeIntentFlow {
        staker: Option::None,
        pool_address: Option::None,
        delegator_full_intent: Option::None,
        delegator_half_intent: Option::None,
        delegator_zero_intent: Option::None,
        amount: Option::None,
        commission: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_with_pool_in_intent_migration_flow_test() {
    let mut flow = flows::StakerWithPoolInIntentMigrationFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_upgrade_basic_flow_regression_test() {
    let mut flow = flows::PoolUpgradeBasicFlow {
        staker: Option::None,
        stake_amount: Option::None,
        initial_reward_supplier_balance: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn intent_delegator_upgrade_action_regression_test() {
    let mut flow = flows::IntentDelegatorUpgradeActionFlow {
        staker: Option::None,
        pool_address: Option::None,
        delegator_full_intent: Option::None,
        delegator_half_intent: Option::None,
        delegator_zero_intent: Option::None,
        amount: Option::None,
        commission: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_exit_regression_test() {
    let mut flow = flows::StakerExitFlow { staker: Option::None, exit_wait_window: Option::None };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_exit_intent_attest_after_migration_flow_test() {
    let mut flow = flows::StakerExitIntentAttestAfterMigrationFlow { staker: Option::None };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn member_intent_staker_exit_upgrade_flow_test() {
    let mut flow = flows::MemberIntentStakerExitUpgradeFlow {
        pool: Option::None,
        delegator: Option::None,
        expected_rewards: Option::None,
        delegated_amount: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn exit_upgrade_set_public_key_flow_test() {
    let mut flow = flows::ExitUpgradeSetPublicKeyFlow { staker: Option::None };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn intent_upgrade_set_public_key_flow_test() {
    let mut flow = flows::IntentUpgradeSetPublicKeyFlow { staker: Option::None };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn find_sigma_migration_flow_test() {
    let mut flow = flows::FindSigmaMigrationFlow {
        pool: Option::None, delegator: Option::None, member_rewards: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn find_sigma_edge_cases_migration_flow_test() {
    let mut flow = flows::FindSigmaEdgeCasesMigrationFlow {
        pool: Option::None, delegator: Option::None, member_rewards: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn find_sigma_migration_idx_is_one_flow_test() {
    let mut flow = flows::FindSigmaMigrationIdxIsOneFlow {
        pool: Option::None, delegator: Option::None, member_rewards: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_rewards_migration_idx_is_zero_flow_test() {
    let mut flow = flows::DelegatorRewardsMigrationIdxIsZeroFlow {
        staker: Option::None, pool: Option::None, delegator: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_rewards_migration_idx_is_one_flow_test() {
    let mut flow = flows::DelegatorRewardsMigrationIdxIsOneFlow {
        pool: Option::None, delegator: Option::None, expected_rewards: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_rewards_migration_idx_len_is_one_flow_test() {
    let mut flow = flows::DelegatorRewardsMigrationIdxLenIsOneFlow {
        pool: Option::None, delegator: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_rewards_migration_idx_is_len_flow_test() {
    let mut flow = flows::DelegatorRewardsMigrationIdxIsLenFlow {
        pool: Option::None, delegator: Option::None, expected_rewards: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_rewards_migration_first_regular_case_flow_test() {
    let mut flow = flows::DelegatorRewardsMigrationFirstRegularCaseFlow {
        staker: Option::None,
        pool: Option::None,
        delegator: Option::None,
        expected_rewards: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_rewards_migration_second_regular_case_flow_test() {
    let mut flow = flows::DelegatorRewardsMigrationSecondRegularCaseFlow {
        staker: Option::None,
        pool: Option::None,
        delegator: Option::None,
        expected_rewards: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn member_claim_rewards_no_rewards_flow_test() {
    let mut flow = flows::MemberClaimRewardsNoRewardsFlow {
        pool: Option::None, delegator: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn member_claim_rewards_one_rewards_flow_test() {
    let mut flow = flows::MemberClaimRewardsOneRewardsFlow {
        pool: Option::None, delegator: Option::None, expected_rewards: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn member_change_balance_claim_rewards_one_rewards_flow_test() {
    let mut flow = flows::MemberChangeBalanceClaimRewardsOneRewardsFlow {
        staker: Option::None,
        pool: Option::None,
        delegator: Option::None,
        stake_amount: Option::None,
    };
    test_multi_version_flow_mainnet(ref :flow);
}
