use contracts::event_test_utils::{assert_number_of_events, assert_paused_event};
use contracts::event_test_utils::{assert_unpaused_event};
use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use contracts::staking::interface::{IStakingPauseDispatcher, IStakingPauseDispatcherTrait};
use contracts::staking::interface::{IStakingPoolDispatcher, IStakingPoolDispatcherTrait};
use contracts::test_utils::{StakingInitConfig, general_contract_system_deployment};
use contracts::test_utils::{load_one_felt, pause_staking_contract};
use contracts::test_utils::stake_for_testing_using_dispatcher;
use contracts::test_utils::constants::{DUMMY_IDENTIFIER, DUMMY_ADDRESS};
use contracts_commons::test_utils::cheat_caller_address_once;
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};

#[test]
fn test_pause() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    let is_paused = load_one_felt(
        target: staking_contract, storage_address: selector!("is_paused")
    );
    assert_eq!(is_paused, 0);
    assert!(!staking_dispatcher.is_paused());
    let mut spy = snforge_std::spy_events();
    // Pause with security agent.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent
    );
    staking_pause_dispatcher.pause();
    let is_paused = load_one_felt(
        target: staking_contract, storage_address: selector!("is_paused")
    );
    assert_ne!(is_paused, 0);
    assert!(staking_dispatcher.is_paused());
    // Unpause with security admin.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_admin
    );
    staking_pause_dispatcher.unpause();
    assert!(!staking_dispatcher.is_paused());
    // Validate Paused and Unpaused events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "pause");
    assert_paused_event(spied_event: events[0], account: cfg.test_info.security_agent);
    assert_unpaused_event(spied_event: events[1], account: cfg.test_info.security_admin);
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_stake_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_increase_stake_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_dispatcher.increase_stake(staker_address: DUMMY_ADDRESS(), amount: 0);
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_claim_rewards_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_disaptcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_disaptcher.claim_rewards(staker_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_unstake_intent_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_dispatcher.unstake_intent();
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_unstake_action_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_dispatcher.unstake_action(staker_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_change_reward_address_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_dispatcher.change_reward_address(reward_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_set_open_for_delegation_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_dispatcher.set_open_for_delegation(commission: 0);
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_update_global_index_if_needed_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_dispatcher.update_global_index_if_needed();
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_change_operational_address_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_dispatcher.change_operational_address(operational_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_add_stake_from_pool_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_pool_dispatcher.add_stake_from_pool(staker_address: DUMMY_ADDRESS(), amount: 0);
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_remove_from_delegation_pool_intent_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: DUMMY_ADDRESS(), identifier: DUMMY_IDENTIFIER, amount: 0
        );
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_remove_from_delegation_pool_action_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_pool_dispatcher.remove_from_delegation_pool_action(identifier: DUMMY_IDENTIFIER);
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_switch_staking_delegation_pool_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_pool_dispatcher
        .switch_staking_delegation_pool(
            to_staker: DUMMY_ADDRESS(),
            to_pool: DUMMY_ADDRESS(),
            switched_amount: 0,
            data: [].span(),
            identifier: DUMMY_IDENTIFIER
        );
}

#[test]
#[should_panic(expected: "Contract is paused.")]
fn test_claim_delegation_pool_rewards_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract
    };
    staking_pool_dispatcher.claim_delegation_pool_rewards(staker_address: DUMMY_ADDRESS());
}
// TODO: Test that only security admin can unpause
// TODO: Test that only security agent can pause


