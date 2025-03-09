use core::hash::HashStateTrait;
use core::poseidon::PoseidonTrait;
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::{CheatSpan, cheat_caller_address};
use staking::attestation::attestation::Attestation;
use staking::attestation::errors::Error;
use staking::attestation::interface::{
    AttestInfo, IAttestationDispatcher, IAttestationDispatcherTrait, IAttestationSafeDispatcher,
    IAttestationSafeDispatcherTrait,
};
use staking::constants::MIN_ATTESTATION_WINDOW;
use staking::event_test_utils::{
    assert_number_of_events, assert_staker_attestation_successful_event,
};
use staking::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use staking::staking::objects::EpochInfoTrait;
use staking::test_utils;
use starkware_utils::components::replaceability::interface::{
    IReplaceableDispatcher, IReplaceableDispatcherTrait,
};
use starkware_utils::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use starkware_utils::errors::Describable;
use starkware_utils::test_utils::{assert_panic_with_error, cheat_caller_address_once};
use test_utils::{
    StakingInitConfig, advance_epoch_global, general_contract_system_deployment,
    stake_for_testing_using_dispatcher,
};

#[test]
fn test_attest() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    let operational_address = cfg.staker_info.operational_address;
    let staker_address = cfg.test_info.staker_address;
    let mut spy = snforge_std::spy_events();
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: operational_address,
    );
    let attest_info = AttestInfo {};
    let epoch = staking_dispatcher.get_current_epoch();
    attestation_dispatcher.attest(:attest_info);
    let is_attestation_done = attestation_dispatcher
        .is_attestation_done_in_curr_epoch(:staker_address);
    assert!(is_attestation_done == true);
    let events = spy.get_events().emitted_by(contract_address: attestation_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "attest");
    assert_staker_attestation_successful_event(spied_event: events[0], :staker_address, :epoch);
}

#[test]
#[feature("safe_dispatcher")]
fn test_attest_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    let attestation_safe_dispatcher = IAttestationSafeDispatcher {
        contract_address: attestation_contract,
    };
    let operational_address = cfg.staker_info.operational_address;
    // Catch ATTEST_IS_DONE.
    let attest_info = AttestInfo {};
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: operational_address,
    );
    attestation_dispatcher.attest(:attest_info);
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: operational_address,
    );
    let result = attestation_safe_dispatcher.attest(:attest_info);
    assert_panic_with_error(:result, expected_error: Error::ATTEST_IS_DONE.describe());
}

#[test]
fn test_is_attestation_done_in_curr_epoch() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    let staker_address = cfg.test_info.staker_address;
    let operational_address = cfg.staker_info.operational_address;
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: operational_address,
    );
    let attest_info = AttestInfo {};
    attestation_dispatcher.attest(:attest_info);
    let is_attestation_done = attestation_dispatcher
        .is_attestation_done_in_curr_epoch(:staker_address);
    assert!(is_attestation_done == true);
}

#[test]
#[feature("safe_dispatcher")]
fn test_is_attestation_done_in_curr_epoch_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_safe_dispatcher = IAttestationSafeDispatcher {
        contract_address: attestation_contract,
    };
    let staker_address = cfg.test_info.staker_address;
    // Catch NO_ATTEST_DONE.
    let result = attestation_safe_dispatcher.is_attestation_done_in_curr_epoch(:staker_address);
    assert_panic_with_error(:result, expected_error: Error::NO_ATTEST_DONE.describe());
}

#[test]
fn test_get_last_epoch_attestation_done() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    let staker_address = cfg.test_info.staker_address;
    let operational_address = cfg.staker_info.operational_address;
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: operational_address,
    );
    let attest_info = AttestInfo {};
    attestation_dispatcher.attest(:attest_info);
    let last_epoch_attesation_done = attestation_dispatcher
        .get_last_epoch_attestation_done(:staker_address);
    assert!(last_epoch_attesation_done == 1);
}

#[test]
#[feature("safe_dispatcher")]
fn test_get_last_epoch_attestation_done_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_safe_dispatcher = IAttestationSafeDispatcher {
        contract_address: attestation_contract,
    };
    let staker_address = cfg.test_info.staker_address;
    // Catch NO_ATTEST_DONE.
    let result = attestation_safe_dispatcher.get_last_epoch_attestation_done(:staker_address);
    assert_panic_with_error(:result, expected_error: Error::NO_ATTEST_DONE.describe());
}


#[test]
fn test_constructor() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = Attestation::contract_state_for_testing();
    Attestation::constructor(
        ref state,
        staking_contract: cfg.test_info.staking_contract,
        governance_admin: cfg.test_info.governance_admin,
        attestation_window: MIN_ATTESTATION_WINDOW + 1,
    );
    assert!(state.staking_contract.read() == cfg.test_info.staking_contract);
}

#[test]
#[should_panic(expected: "Attestation window is too small, must be larger then 10 blocks")]
fn test_constructor_assertions() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = Attestation::contract_state_for_testing();
    Attestation::constructor(
        ref state,
        staking_contract: cfg.test_info.staking_contract,
        governance_admin: cfg.test_info.governance_admin,
        attestation_window: MIN_ATTESTATION_WINDOW,
    );
}

#[test]
fn test_contract_admin_role() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);

    // Assert the correct governance admins is set.
    let attestation_roles_dispatcher = IRolesDispatcher {
        contract_address: cfg.test_info.attestation_contract,
    };
    assert!(
        attestation_roles_dispatcher.is_governance_admin(account: cfg.test_info.governance_admin),
    );
}

#[test]
fn test_contract_upgrade_delay() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);

    // Assert the upgrade delay is properly set.
    let attestation_replaceable_dispatcher = IReplaceableDispatcher {
        contract_address: cfg.test_info.attestation_contract,
    };
    assert!(attestation_replaceable_dispatcher.get_upgrade_delay() == 0);
}

#[test]
fn test_validate_next_planned_attestation_block() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };

    // Calculate the next planned attestation block number.
    let hash = PoseidonTrait::new()
        .update(cfg.staker_info._deprecated_amount_own.into())
        .update(cfg.staking_contract_info.epoch_info.current_epoch().into() + 1)
        .update(cfg.test_info.staker_address.into())
        .finalize();
    // TODO: Change the magic number to the const default attestation window.
    let block_offset: u256 = hash
        .into() % (cfg.staking_contract_info.epoch_info.epoch_len_in_blocks()
            - (MIN_ATTESTATION_WINDOW.into() + 1))
        .into();
    // TODO: Change starting block once set in the staking contract.
    let planned_attestation_block_number = 0 + block_offset.try_into().unwrap();

    cheat_caller_address(
        contract_address: attestation_contract,
        caller_address: cfg.staker_info.operational_address,
        span: CheatSpan::TargetCalls(3),
    );
    assert!(
        attestation_dispatcher
            .validate_next_planned_attestation_block(
                block_number: planned_attestation_block_number,
            ),
    );
    assert!(
        !attestation_dispatcher
            .validate_next_planned_attestation_block(
                block_number: planned_attestation_block_number - 1,
            ),
    );
    assert!(
        !attestation_dispatcher
            .validate_next_planned_attestation_block(
                block_number: planned_attestation_block_number + 1,
            ),
    );
}

#[test]
fn test_set_attestation_window() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    assert!(attestation_dispatcher.attestation_window() == MIN_ATTESTATION_WINDOW + 1);
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: cfg.test_info.app_governor,
    );
    attestation_dispatcher.set_attestation_window(attestation_window: MIN_ATTESTATION_WINDOW + 2);
    assert!(attestation_dispatcher.attestation_window() == MIN_ATTESTATION_WINDOW + 2);
}

#[test]
#[feature("safe_dispatcher")]
fn test_set_attestation_window_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_safe_dispatcher = IAttestationSafeDispatcher {
        contract_address: attestation_contract,
    };
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: cfg.test_info.app_governor,
    );
    // Catch ATTEST_WINDOW_TOO_SMALL.
    let result = attestation_safe_dispatcher
        .set_attestation_window(attestation_window: MIN_ATTESTATION_WINDOW);
    assert_panic_with_error(:result, expected_error: Error::ATTEST_WINDOW_TOO_SMALL.describe());
}

#[test]
#[should_panic(expected: "ONLY_APP_GOVERNOR")]
fn test_attest_role_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    // Catch ONLY_APP_GOVERNOR.
    attestation_dispatcher.set_attestation_window(attestation_window: MIN_ATTESTATION_WINDOW);
}
