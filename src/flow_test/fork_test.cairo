use core::num::traits::Zero;
use staking::flow_test::flows;
use staking::flow_test::utils::test_flow_mainnet;

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
fn staker_intent_last_action_first_regression_test() {
    let mut flow = flows::StakerIntentLastActionFirstFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_address_already_used_in_older_version_regression_test() {
    let mut flow = flows::StakerAddressAlreadyUsedInOlderVersionFlow {
        staker_v1: Option::None, staker_v2: Option::None,
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
fn pool_member_info_after_upgrade_regression_test() {
    let mut flow = flows::PoolMemberInfoAfterUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, delegator_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pool_member_info_undelegate_after_upgrade_regression_test() {
    let mut flow = flows::PoolMemberInfoUndelegateAfterUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, delegator_info: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn increase_delegation_after_upgrade_regression_test() {
    let mut flow = flows::IncreaseDelegationAfterUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, delegated_amount: Option::None,
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
        pool_address: Option::None, delegator: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_partial_intent_after_upgrade_regression_test() {
    let mut flow = flows::DelegatorPartialIntentAfterUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, delegated_amount: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn increase_stake_after_upgrade_regression_test() {
    let mut flow = flows::IncreaseStakeAfterUpgradeFlow {
        staker: Option::None, stake_amount: Option::None,
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
        pool_address: Option::None, delegator: Option::None, exit_wait_window: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_intent_after_upgrade_regression_test() {
    let mut flow = flows::DelegatorIntentAfterUpgradeFlow {
        pool_address: Option::None, delegator: Option::None, delegated_amount: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_intent_after_upgrade_regression_test() {
    let mut flow = flows::StakerIntentAfterUpgradeFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_action_after_upgrade_regression_test() {
    let mut flow = flows::StakerActionAfterUpgradeFlow {
        staker: Option::None, pool_address: Option::None, exit_wait_window: Option::None,
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
        pool_address: Option::None, delegator: Option::None, delegated_amount: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_migration_regression_test() {
    let mut flow = flows::StakerMigrationFlow { pool_address: Option::None, staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_migration_multiple_pools_regression_test() {
    let mut flow = flows::StakerMigrationMultiplePoolsFlow {
        pool_addresses: Option::None, staker_pool_info: Option::None, staker: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_migration_multiple_versions_regression_test() {
    let mut flow = flows::StakerMigrationMultipleVersionsFlow { stakers: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
#[should_panic(expected: "Staker is already migrated to latest version")]
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
        pool_address: Option::None, delegator: Option::None,
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
fn staker_without_pool_migration_flow_test() {
    let mut flow = flows::StakerWithoutPoolMigrationFlow {
        staker: Option::None, staker_info: Option::None, staker_pool_info: Option::None,
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
fn pool_eic_flow_test() {
    let mut flow = flows::PoolEICFlow {
        pool_v0: Option::None,
        pool_v1: Option::None,
        pool_v2: Option::None,
        pool_btc_8d_v2: Option::None,
        pool_btc_18d_v2: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staking_prev_class_hash_flow_test() {
    let mut flow = flows::StakingPrevClassHashFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_migration_skip_version_flow_test() {
    let mut flow = flows::StakerMigrationSkipVersionFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn staker_migration_missing_class_hash_flow_test() {
    let mut flow = flows::StakerMigrationMissingClassHashFlow {};
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn pre_v3_staker_version_flow_test() {
    let mut flow = flows::StakerVersionFlow { stakers: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn get_public_key_after_upgrade_flow_test() {
    let mut flow = flows::GetPublicKeyAfterUpgradeFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn set_public_key_same_epoch_as_upgrade_flow_test() {
    let mut flow = flows::SetPublicKeySameEpochAsUpgradeFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn get_stakers_after_upgrade_flow_test() {
    let mut flow = flows::GetStakersAfterUpgradeFlow { staker: Option::None };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn toggle_tokens_before_after_upgrade_flow_test() {
    let mut flow = flows::ToggleTokensBeforeAfterUpgradeFlow {
        token_a: Option::None, token_b: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_change_balance_over_versions_flow_test() {
    let mut flow = flows::DelegatorChangeBalanceOverVersionsFlow {
        staker: Option::None,
        pool: Option::None,
        delegator: Option::None,
        expected_rewards: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_from_v0_flow_test() {
    let mut flow = flows::DelegatorFromV0Flow {
        staker: Option::None,
        pool: Option::None,
        delegator: Option::None,
        expected_rewards: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_v0_change_balance_before_rewards_flow_test() {
    let mut flow = flows::DelegatorV0ChangeBalanceBeforeRewardsFlow {
        staker: Option::None, pool: Option::None, delegator: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn delegator_v0_rewards_v1_change_balance_before_rewards_flow_test() {
    let mut flow = flows::DelegatorV0RewardsV1ChangeBalanceBeforeRewardsFlow {
        staker: Option::None,
        pool: Option::None,
        delegator: Option::None,
        expected_rewards: Option::None,
    };
    test_flow_mainnet(ref :flow);
}

#[test]
#[fork("MAINNET_LATEST")]
fn enable_disable_token_before_after_upgrade_flow_test() {
    let mut flow = flows::EnableDisableTokenBeforeAfterUpgradeFlow {
        token_a: Option::None,
        token_b: Option::None,
        staker: Option::None,
        pool_a: Option::None,
        pool_b: Option::None,
        delegator_a: Option::None,
        delegator_b: Option::None,
        delegation_amount: Option::None,
    };
    test_flow_mainnet(ref :flow);
}
