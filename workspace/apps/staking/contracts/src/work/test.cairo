use contracts_commons::errors::Describable;
use contracts_commons::test_utils::{assert_panic_with_error, cheat_caller_address_once};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use staking::event_test_utils::assert_number_of_events;
use staking::test_utils;
use staking::work::errors::Error;
use staking::work::interface::{
    IWorkDispatcher, IWorkDispatcherTrait, IWorkSafeDispatcher, IWorkSafeDispatcherTrait, WorkInfo,
};
use test_utils::{
    StakingInitConfig, general_contract_system_deployment, stake_for_testing_using_dispatcher,
};

#[test]
fn test_work() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let work_contract = cfg.test_info.work_contract;
    let work_dispatcher = IWorkDispatcher { contract_address: work_contract };
    let operational_address = cfg.staker_info.operational_address;
    let staker_address = cfg.test_info.staker_address;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: work_contract, caller_address: operational_address);
    let work_info = WorkInfo {};
    work_dispatcher.work(:work_info);
    let is_work_done = work_dispatcher.is_work_done_in_curr_epoch(address: staker_address);
    assert_eq!(is_work_done, true);
    let events = spy.get_events().emitted_by(contract_address: work_contract).events;
    assert_number_of_events(actual: events.len(), expected: 0, message: "work");
}

#[test]
#[feature("safe_dispatcher")]
fn test_work_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let work_contract = cfg.test_info.work_contract;
    let work_dispatcher = IWorkDispatcher { contract_address: work_contract };
    let work_safe_dispatcher = IWorkSafeDispatcher { contract_address: work_contract };
    let operational_address = cfg.staker_info.operational_address;
    // Catch WORK_IS_DONE.
    let work_info = WorkInfo {};
    cheat_caller_address_once(contract_address: work_contract, caller_address: operational_address);
    work_dispatcher.work(:work_info);
    cheat_caller_address_once(contract_address: work_contract, caller_address: operational_address);
    let result = work_safe_dispatcher.work(:work_info);
    assert_panic_with_error(:result, expected_error: Error::WORK_IS_DONE.describe());
}

#[test]
fn test_is_work_done_in_curr_epoch() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let work_contract = cfg.test_info.work_contract;
    let work_dispatcher = IWorkDispatcher { contract_address: work_contract };
    let staker_address = cfg.test_info.staker_address;
    let is_work_done = work_dispatcher.is_work_done_in_curr_epoch(address: staker_address);
    assert_eq!(is_work_done, false);
    let operational_address = cfg.staker_info.operational_address;
    cheat_caller_address_once(contract_address: work_contract, caller_address: operational_address);
    let work_info = WorkInfo {};
    work_dispatcher.work(:work_info);
    let is_work_done = work_dispatcher.is_work_done_in_curr_epoch(address: staker_address);
    assert_eq!(is_work_done, true);
}

