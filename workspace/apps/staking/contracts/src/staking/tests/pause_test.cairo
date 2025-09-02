use core::num::traits::Zero;
use snforge_std::TokenTrait;
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use staking::event_test_utils::{
    assert_number_of_events, assert_paused_event, assert_unpaused_event,
};
use staking::staking::interface::{
    IStakingAttestationDispatcher, IStakingAttestationDispatcherTrait, IStakingDispatcher,
    IStakingDispatcherTrait, IStakingPauseDispatcher, IStakingPauseDispatcherTrait,
    IStakingPoolDispatcher, IStakingPoolDispatcherTrait,
};
use staking::test_utils::constants::{
    DUMMY_ADDRESS, DUMMY_IDENTIFIER, NON_SECURITY_ADMIN, NON_SECURITY_AGENT,
};
use staking::test_utils::{
    StakingInitConfig, general_contract_system_deployment, load_one_felt, pause_staking_contract,
    stake_for_testing_using_dispatcher,
};
use starkware_utils_testing::test_utils::cheat_caller_address_once;

#[test]
fn test_pause() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    let is_paused = load_one_felt(
        target: staking_contract, storage_address: selector!("is_paused"),
    );
    assert!(is_paused == 0);
    assert!(!staking_dispatcher.is_paused());
    let mut spy = snforge_std::spy_events();
    // Pause with security agent.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    staking_pause_dispatcher.pause();
    let is_paused = load_one_felt(
        target: staking_contract, storage_address: selector!("is_paused"),
    );
    assert!(is_paused != 0);
    assert!(staking_dispatcher.is_paused());
    // Unpause with security admin.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_admin,
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
fn test_already_paused_and_unpaused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    let is_paused = load_one_felt(
        target: staking_contract, storage_address: selector!("is_paused"),
    );
    assert!(is_paused == 0);
    assert!(!staking_dispatcher.is_paused());
    let mut spy = snforge_std::spy_events();
    // Unpause with security admin when already unpaused should change nothing and emit nothing.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_admin,
    );
    staking_pause_dispatcher.unpause();
    let is_paused = load_one_felt(
        target: staking_contract, storage_address: selector!("is_paused"),
    );
    assert!(is_paused == 0);
    assert!(!staking_dispatcher.is_paused());
    // Pause with security agent.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    staking_pause_dispatcher.pause();
    assert!(staking_dispatcher.is_paused());
    // Pause with security agent when already paused should change nothing and emit nothing.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    staking_pause_dispatcher.pause();
    assert!(staking_dispatcher.is_paused());
    // Validate the single Paused event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "pause");
    assert_paused_event(spied_event: events[0], account: cfg.test_info.security_agent);
}

#[test]
#[should_panic(expected: "ONLY_SECURITY_AGENT")]
fn test_pause_not_security_agent() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    let non_security_agent = NON_SECURITY_AGENT();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: non_security_agent,
    );
    staking_pause_dispatcher.pause();
}

#[test]
#[should_panic(expected: "ONLY_SECURITY_ADMIN")]
fn test_unpause_not_security_admin() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    let non_security_admin = NON_SECURITY_ADMIN();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: non_security_admin,
    );
    staking_pause_dispatcher.unpause();
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_stake_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    stake_for_testing_using_dispatcher(:cfg);
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_increase_stake_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.increase_stake(staker_address: DUMMY_ADDRESS(), amount: 0);
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_claim_rewards_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.claim_rewards(staker_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_unstake_intent_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.unstake_intent();
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_unstake_action_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.unstake_action(staker_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_change_reward_address_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.change_reward_address(reward_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_set_open_for_delegation_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher
        .set_open_for_delegation(token_address: cfg.test_info.strk_token.contract_address());
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_change_operational_address_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.change_operational_address(operational_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_declare_operational_address_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.declare_operational_address(staker_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_set_commission_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.set_commission(commission: 0);
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_add_stake_from_pool_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_pool_dispatcher.add_stake_from_pool(staker_address: DUMMY_ADDRESS(), amount: 0);
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_remove_from_delegation_pool_intent_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: DUMMY_ADDRESS(), identifier: DUMMY_IDENTIFIER, amount: 0,
        );
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_remove_from_delegation_pool_action_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_pool_dispatcher.remove_from_delegation_pool_action(identifier: DUMMY_IDENTIFIER);
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_switch_staking_delegation_pool_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_pool_dispatcher
        .switch_staking_delegation_pool(
            to_staker: DUMMY_ADDRESS(),
            to_pool: DUMMY_ADDRESS(),
            switched_amount: 0,
            data: [].span(),
            identifier: DUMMY_IDENTIFIER,
        );
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_update_rewards_from_attestation_contract_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingAttestationDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher.update_rewards_from_attestation_contract(staker_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_set_commission_commitment_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    pause_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    staking_dispatcher
        .set_commission_commitment(max_commission: Zero::zero(), expiration_epoch: Zero::zero());
}

