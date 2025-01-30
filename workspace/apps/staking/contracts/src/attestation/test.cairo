use contracts_commons::errors::Describable;
use contracts_commons::test_utils::{assert_panic_with_error, cheat_caller_address_once};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use staking::attestation::errors::Error;
use staking::attestation::interface::{
    AttestInfo, IAttestationDispatcher, IAttestationDispatcherTrait, IAttestationSafeDispatcher,
    IAttestationSafeDispatcherTrait,
};
use staking::event_test_utils::assert_number_of_events;
use staking::staking::objects::VersionedInternalStakerInfoGetters;
use staking::test_utils;
use test_utils::{
    StakingInitConfig, general_contract_system_deployment, stake_for_testing_using_dispatcher,
};

#[test]
fn test_attest() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    let operational_address = cfg.staker_info.operational_address();
    let staker_address = cfg.test_info.staker_address;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: operational_address,
    );
    let attest_info = AttestInfo {};
    attestation_dispatcher.attest(:attest_info);
    let is_attestation_done = attestation_dispatcher
        .is_attestation_done_in_curr_epoch(address: staker_address);
    assert_eq!(is_attestation_done, true);
    let events = spy.get_events().emitted_by(contract_address: attestation_contract).events;
    assert_number_of_events(actual: events.len(), expected: 0, message: "attest");
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
    let operational_address = cfg.staker_info.operational_address();
    // Catch ATTEST_IS_DONE.
    let attest_info = AttestInfo {};
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
    let operational_address = cfg.staker_info.operational_address();
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: operational_address,
    );
    let attest_info = AttestInfo {};
    attestation_dispatcher.attest(:attest_info);
    let is_attestation_done = attestation_dispatcher
        .is_attestation_done_in_curr_epoch(address: staker_address);
    assert_eq!(is_attestation_done, true);
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
    let result = attestation_safe_dispatcher
        .is_attestation_done_in_curr_epoch(address: staker_address);
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
    let operational_address = cfg.staker_info.operational_address();
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: operational_address,
    );
    let attest_info = AttestInfo {};
    attestation_dispatcher.attest(:attest_info);
    let last_epoch_attesation_done = attestation_dispatcher
        .get_last_epoch_attestation_done(address: staker_address);
    assert_eq!(last_epoch_attesation_done, 1);
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
    let result = attestation_safe_dispatcher
        .get_last_epoch_attestation_done(address: staker_address);
    assert_panic_with_error(:result, expected_error: Error::NO_ATTEST_DONE.describe());
}
