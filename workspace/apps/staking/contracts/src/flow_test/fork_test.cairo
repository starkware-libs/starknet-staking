use core::num::traits::Zero;
use staking_test::flow_test::flows;
use staking_test::flow_test::utils::test_flow_mainnet;

#[test]
#[fork("MAINNET_LATEST")]
fn basic_stake_flow_regression_test() {
    let mut flow = flows::BasicStakeFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn set_open_for_delegation_regression_test() {
    let mut flow = flows::SetOpenForDelegationFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_after_staker_action_regression_test() {
    let mut flow = flows::DelegatorIntentAfterStakerActionFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn multiple_stakers_migration_attest_regression_test() {
    let mut flow = flows::MultipleStakersMigrationAttestFlow {
        staker1: Option::None,
        staker2: Option::None,
        staker_info1: Option::None,
        staker_info2: Option::None,
        commission: Option::None,
        pool_address: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_regression_test() {
    let mut flow = flows::DelegatorIntentFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn operations_after_dead_staker_regression_test() {
    let mut flow = flows::OperationsAfterDeadStakerFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_didnt_update_after_staker_update_commission_regression_test() {
    let mut flow = flows::DelegatorDidntUpdateAfterStakerUpdateCommissionFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_updated_after_staker_update_commission_regression_test() {
    let mut flow = flows::DelegatorUpdatedAfterStakerUpdateCommissionFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_multiple_entries_migration_attest_regression_test() {
    let mut flow = flows::StakerMultipleEntriesMigrationAttestFlow {
        staker: Option::None, amount: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_intent_last_action_first_regression_test() {
    let mut flow = flows::StakerIntentLastActionFirstFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_address_already_used_in_older_version_regression_test() {
    let mut flow = flows::StakerAddressAlreadyUsedInOlderVersionFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

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
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_upgrade_flow_regression_test() {
    let mut flow = flows::PoolUpgradeFlow {
        pool_address: Option::None,
        delegator: Option::None,
        delegated_amount: Zero::zero(),
        staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn total_stake_trace_after_upgrade_flow_test() {
    let mut flow = flows::TotalStakeTraceAfterUpgradeFlow { amount: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_in_v0_action_in_v2_regression_test() {
    let mut flow = flows::DelegatorIntentInV0ActionInV2Flow {
        staker: Option::None,
        delegators: Option::None,
        amount: Option::None,
        pool_address: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_in_v0_change_intent_action_in_v2_regression_test() {
    let mut flow = flows::DelegatorIntentInV0ChangeIntentActionInV2Flow {
        staker: Option::None,
        delegators: Option::None,
        amount: Option::None,
        pool_address: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_claim_rewards_after_upgrade_regression_test() {
    let mut flow = flows::PoolClaimRewardsAfterUpgradeFlow {
        pool_address: Option::None,
        staker: Option::None,
        delegator: Option::None,
        delegator_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
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
    test_flow_mainnet(ref :flow);
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
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_member_info_after_upgrade_regression_test() {
    let mut flow = flows::PoolMemberInfoAfterUpgradeFlow {
        pool_address: Option::None,
        delegator: Option::None,
        delegator_info: Option::None,
        staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_member_info_undelegate_after_upgrade_regression_test() {
    let mut flow = flows::PoolMemberInfoUndelegateAfterUpgradeFlow {
        pool_address: Option::None,
        delegator: Option::None,
        delegator_info: Option::None,
        staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn increase_delegation_after_upgrade_regression_test() {
    let mut flow = flows::IncreaseDelegationAfterUpgradeFlow {
        pool_address: Option::None,
        delegator: Option::None,
        delegated_amount: Option::None,
        staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn change_commission_after_upgrade_regression_test() {
    let mut flow = flows::ChangeCommissionAfterUpgradeFlow {
        staker: Option::None, pool_address: Option::None, commission: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_claim_rewards_after_upgrade_regression_test() {
    let mut flow = flows::DelegatorClaimRewardsAfterUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_partial_intent_after_upgrade_regression_test() {
    let mut flow = flows::DelegatorPartialIntentAfterUpgradeFlow {
        pool_address: Option::None,
        delegator: Option::None,
        delegated_amount: Option::None,
        staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
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
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn increase_stake_after_upgrade_regression_test() {
    let mut flow = flows::IncreaseStakeAfterUpgradeFlow {
        staker: Option::None, stake_amount: Option::None, pool_address: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_change_balance_after_upgrade_regression_test() {
    let mut flow = flows::PoolChangeBalanceAfterUpgradeFlow {
        pool_address: Option::None,
        staker: Option::None,
        delegator: Option::None,
        delegator_info: Option::None,
        delegated_amount: Zero::zero(),
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_action_after_upgrade_regression_test() {
    let mut flow = flows::DelegatorActionAfterUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_after_upgrade_regression_test() {
    let mut flow = flows::DelegatorIntentAfterUpgradeFlow {
        pool_address: Option::None,
        delegator: Option::None,
        delegated_amount: Option::None,
        staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_intent_after_upgrade_regression_test() {
    let mut flow = flows::StakerIntentAfterUpgradeFlow {
        staker: Option::None, pool_address: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_action_after_upgrade_regression_test() {
    let mut flow = flows::StakerActionAfterUpgradeFlow {
        staker: Option::None, pool_address: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn staker_attest_after_intent_regression_test() {
    let mut flow = flows::StakerAttestAfterIntentFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_switch_after_upgrade_regression_test() {
    let mut flow = flows::DelegatorSwitchAfterUpgradeFlow {
        pool_address: Option::None,
        delegator: Option::None,
        delegated_amount: Option::None,
        staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_migration_regression_test() {
    let mut flow = flows::StakerMigrationFlow {
        staker: Option::None,
        staker_info: Option::None,
        internal_staker_info: Option::None,
        commission_commitment: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_with_pool_without_commission_commitment_migration_flow_test() {
    let mut flow = flows::StakerWithPoolWithoutCommissionCommitmentMigrationFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
#[should_panic(expected: "Staker Info is already up-to-date")]
fn staker_migration_called_twice_regression_test() {
    let mut flow = flows::StakerMigrationCalledTwiceFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
#[should_panic(expected: "Staker is not migrated to latest version")]
fn internal_staker_info_without_staker_migration_regression_test() {
    let mut flow = flows::InternalStakerInfoWithoutStakerMigrationFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_before_claim_rewards_after_regression_test() {
    let mut flow = flows::DelegatorIntentBeforeClaimRewardsAfterFlow {
        staker: Option::None, pool_address: Option::None, delegator: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn set_open_for_delegation_after_upgrade_flow_test() {
    let mut flow = flows::SetOpenForDelegationAfterUpgradeFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn total_stake_after_upgrade_flow_test() {
    let mut flow = flows::TotalStakeAfterUpgradeFlow {
        total_stake: Option::None,
        current_total_stake: Option::None,
        staker: Option::None,
        staker2: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn claim_rewards_with_non_upgraded_pool_flow_test() {
    let mut flow = flows::ClaimRewardsWithNonUpgradedPoolFlow {
        pool_address: Option::None,
        first_delegator: Option::None,
        first_delegator_info: Option::None,
        second_delegator: Option::None,
        second_delegator_info: Option::None,
        third_delegator: Option::None,
        third_delegator_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_with_pool_in_intent_migration_flow_test() {
    let mut flow = flows::StakerWithPoolInIntentMigrationFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_upgrade_basic_flow_regression_test() {
    let mut flow = flows::PoolUpgradeBasicFlow {
        staker: Option::None,
        stake_amount: Option::None,
        initial_reward_supplier_balance: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_without_pool_in_intent_migration_flow_test() {
    let mut flow = flows::StakerWithoutPoolInIntentMigrationFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_action_with_non_upgraded_pool_regression_test() {
    let mut flow = flows::DelegatorActionWithNonUpgradedPoolFlow {
        staker: Option::None,
        pool_address: Option::None,
        first_delegator: Option::None,
        first_delegator_info: Option::None,
        second_delegator: Option::None,
        second_delegator_info: Option::None,
        third_delegator: Option::None,
        third_delegator_info: Option::None,
        initial_reward_supplier_balance: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn switch_with_non_upgraded_pool_regression_test() {
    let mut flow = flows::SwitchWithNonUpgradedPoolFlow {
        pool_address: Option::None,
        first_delegator: Option::None,
        second_delegator: Option::None,
        stake_amount: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_exit_before_enter_after_regression_test() {
    let mut flow = flows::DelegatorExitBeforeEnterAfterFlow {
        pool_address: Option::None, delegator: Option::None, staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_exit_with_non_upgraded_pool_regression_test() {
    let mut flow = flows::DelegatorExitWithNonUpgradedPoolFlow {
        pool_address: Option::None,
        first_delegator: Option::None,
        first_delegator_info: Option::None,
        second_delegator: Option::None,
        second_delegator_info: Option::None,
        third_delegator: Option::None,
        third_delegator_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_without_pool_advance_epoch_migration_open_strk_pool_flow_test() {
    let mut flow = flows::StakerWithoutPoolAdvanceEpochMigrationOpenStrkPoolFlow {
        staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn multiple_stakers_migration_vec_flow_test() {
    let mut flow = flows::MultipleStakersMigrationVecFlow { old_stakers: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_without_pool_migration_open_pools_flow_test() {
    let mut flow = flows::StakerWithoutPoolMigrationOpenPoolsFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_in_intent_migration_vec_flow_test() {
    let mut flow = flows::StakerInIntentMigrationVecFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_without_pool_migration_balance_traces_flow_test() {
    let mut flow = flows::StakerWithoutPoolMigrationBalanceTracesFlow {
        staker: Option::None, staker_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
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
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_with_pool_migration_set_commission_regression_test() {
    let mut flow = flows::StakerWithPoolMigrationSetCommissionFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_exit_regression_test() {
    let mut flow = flows::StakerExitFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_exit_intent_attest_after_migration_flow_test() {
    let mut flow = flows::StakerExitIntentAttestAfterMigrationFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}
