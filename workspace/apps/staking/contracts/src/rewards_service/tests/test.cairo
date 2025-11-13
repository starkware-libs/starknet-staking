use core::num::traits::Zero;
use openzeppelin::access::ownable::OwnableComponent::Errors as OwnableErrors;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin::upgrades::interface::{
    IUpgradeableDispatcher, IUpgradeableDispatcherTrait, IUpgradeableSafeDispatcher,
    IUpgradeableSafeDispatcherTrait,
};
use openzeppelin::upgrades::upgradeable::UpgradeableComponent::{
    Errors as UpgradeableErrors, Upgraded,
};
use snforge_std::{DeclareResultTrait, EventSpyTrait, EventsFilterTrait, get_class_hash, spy_events};
use staking::rewards_service::errors::Errors;
use staking::rewards_service::rewards_service::RewardsService::{
    DEFAULT_MAX_TIME_BETWEEN_UPDATES, DEFAULT_MIN_TIME_BETWEEN_UPDATES, MAX_BLOCK_TIME,
    MIN_BLOCK_TIME,
};
use staking::rewards_service::tests::test_utils::{
    RewardsServiceConfig, deploy_rewards_service, generic_test_fixture,
};
use staking::test_utils::{StakingInitConfig, general_contract_system_deployment};
use starknet::{get_block_number, get_block_timestamp};
use starkware_utils_testing::event_test_utils::assert_number_of_events;
use starkware_utils_testing::test_utils::{
    assert_expected_event_emitted, assert_panic_with_felt_error, cheat_caller_address_once,
    generic_load,
};

#[test]
fn test_constructor() {
    let (staking_cfg, rewards_service_cfg) = generic_test_fixture();
    let contract_address = rewards_service_cfg.rewards_service_address;
    assert_eq!(
        generic_load(contract_address, selector!("staking_address")),
        staking_cfg.test_info.staking_contract,
    );
    assert_eq!(
        generic_load(contract_address, selector!("permissioned_caller")),
        rewards_service_cfg.permissioned_caller,
    );
    assert_eq!(
        generic_load(contract_address, selector!("last_update_info")),
        (
            rewards_service_cfg.last_update_block_number,
            rewards_service_cfg.last_update_block_timestamp,
        ),
    );
    assert_eq!(
        generic_load(contract_address, selector!("update_interval_bounds")),
        (DEFAULT_MIN_TIME_BETWEEN_UPDATES, DEFAULT_MAX_TIME_BETWEEN_UPDATES),
    );
    assert_eq!(
        generic_load(contract_address, selector!("block_time_bounds")),
        (MIN_BLOCK_TIME, MAX_BLOCK_TIME),
    );
    let ownable_dispatcher = IOwnableDispatcher { contract_address };
    assert_eq!(ownable_dispatcher.owner(), rewards_service_cfg.owner);
}

#[test]
fn test_constructor_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let mut rewards_service_cfg: RewardsServiceConfig = Default::default();
    rewards_service_cfg.staking_address = cfg.test_info.staking_contract;

    // OWNER_NOT_APP_GOVERNOR.
    let result = deploy_rewards_service(rewards_service_cfg);
    assert!(result.is_err());
    assert_eq!(*result.unwrap_err()[0], Errors::OWNER_NOT_APP_GOVERNOR);

    rewards_service_cfg.owner = cfg.test_info.app_governor;

    // INVALID_BLOCK_NUMBER - zero.
    rewards_service_cfg.last_update_block_number = Zero::zero();
    let result = deploy_rewards_service(rewards_service_cfg);
    assert!(result.is_err());
    assert_eq!(*result.unwrap_err()[0], Errors::INVALID_BLOCK_NUMBER);

    // INVALID_BLOCK_NUMBER - future block number.
    rewards_service_cfg.last_update_block_number = get_block_number() + 1;
    let result = deploy_rewards_service(rewards_service_cfg);
    assert!(result.is_err());
    assert_eq!(*result.unwrap_err()[0], Errors::INVALID_BLOCK_NUMBER);

    rewards_service_cfg.last_update_block_number = get_block_number();

    // INVALID_BLOCK_TIMESTAMP - zero.
    rewards_service_cfg.last_update_block_timestamp = Zero::zero();
    let result = deploy_rewards_service(rewards_service_cfg);
    assert!(result.is_err());
    assert_eq!(*result.unwrap_err()[0], Errors::INVALID_BLOCK_TIMESTAMP);

    // INVALID_BLOCK_TIMESTAMP - future timestamp.
    rewards_service_cfg.last_update_block_timestamp = get_block_timestamp() + 1;
    let result = deploy_rewards_service(rewards_service_cfg);
    assert!(result.is_err());
    assert_eq!(*result.unwrap_err()[0], Errors::INVALID_BLOCK_TIMESTAMP);
}


#[test]
fn test_upgrade() {
    let (_, rewards_service_cfg) = generic_test_fixture();
    let contract_address = rewards_service_cfg.rewards_service_address;
    let owner = rewards_service_cfg.owner;
    let upgradeable_dispatcher = IUpgradeableDispatcher { contract_address };
    cheat_caller_address_once(:contract_address, caller_address: owner);
    let new_class_hash = *snforge_std::declare("MockContract").unwrap().contract_class().class_hash;
    let mut spy = spy_events();
    upgradeable_dispatcher.upgrade(new_class_hash);
    assert_eq!(get_class_hash(:contract_address), new_class_hash);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "upgrade");
    assert_expected_event_emitted(
        spied_event: events[0],
        expected_event: Upgraded { class_hash: new_class_hash },
        expected_event_selector: @selector!("UpgradeableEvent"),
        expected_event_name: "UpgradeableEvent",
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_upgrade_assertions() {
    let (_, rewards_service_cfg) = generic_test_fixture();
    let contract_address = rewards_service_cfg.rewards_service_address;
    let owner = rewards_service_cfg.owner;
    let contract_upgradeable_safe = IUpgradeableSafeDispatcher { contract_address };
    let new_class_hash = 'new_class_hash'.try_into().unwrap();

    // NOT_OWNER.
    let result = contract_upgradeable_safe.upgrade(:new_class_hash);
    assert_panic_with_felt_error(result, OwnableErrors::NOT_OWNER);

    // INVALID_CLASS.
    cheat_caller_address_once(:contract_address, caller_address: owner);
    let result = contract_upgradeable_safe.upgrade(new_class_hash: Zero::zero());
    assert_panic_with_felt_error(result, UpgradeableErrors::INVALID_CLASS);
}
