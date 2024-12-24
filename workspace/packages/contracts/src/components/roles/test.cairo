use contracts_commons::components::roles;
use contracts_commons::components::roles::errors::AccessErrors;
use contracts_commons::components::roles::test_utils;
use contracts_commons::components::roles::test_utils::Constants;
use contracts_commons::event_test_utils::{assert_number_of_events};
use contracts_commons::test_utils::cheat_caller_address_once;
use core::num::traits::zero::Zero;
use openzeppelin::access::accesscontrol::AccessControlComponent::Errors as OZAccessErrors;
use roles::event_test_utils;
use roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use roles::interface::{IRolesSafeDispatcher, IRolesSafeDispatcherTrait};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};


pub fn assert_panic_with_error<T, +Drop<T>>(
    result: Result<T, Array<felt252>>, expected_error: felt252,
) {
    match result {
        Result::Ok(_) => panic!("Expected to fail with: {}", expected_error),
        Result::Err(error_data) => assert!(*error_data[0] == expected_error),
    };
}


#[test]
fn test_register_app_role_admin() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let governance_admin = Constants::INITIAL_ROOT_ADMIN();
    let app_role_admin = Constants::APP_ROLE_ADMIN();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Try to add zero address as app role admin.
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    let result = roles_safe_dispatcher.register_app_role_admin(account: Zero::zero());
    assert_panic_with_error(:result, expected_error: AccessErrors::ZERO_ADDRESS);

    // Try to add app role admin with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.register_app_role_admin(account: app_role_admin);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Register app role admin and perform the corresponding checks.
    let mut spy = snforge_std::spy_events();
    assert!(!roles_dispatcher.is_app_role_admin(account: app_role_admin));
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.register_app_role_admin(account: app_role_admin);

    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_register_app_role_admin first",
    );
    event_test_utils::assert_app_role_admin_added_event(
        events[1], added_account: app_role_admin, added_by: governance_admin,
    );
    assert!(roles_dispatcher.is_app_role_admin(account: app_role_admin));

    // Register app role admin that is already registered (should not emit events).
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.register_app_role_admin(account: app_role_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_register_app_role_admin second",
    );
}


#[test]
fn test_remove_app_role_admin() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let governance_admin = Constants::INITIAL_ROOT_ADMIN();
    let app_role_admin = Constants::APP_ROLE_ADMIN();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Remove app role admin that was not registered (should not emit events).
    assert!(!roles_dispatcher.is_app_role_admin(account: app_role_admin));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.remove_app_role_admin(account: app_role_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_remove_app_role_admin first",
    );

    // Register app role admin.
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.register_app_role_admin(account: app_role_admin);

    // Try to remove app role admin with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.remove_app_role_admin(account: app_role_admin);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Remove app role admin and perform the corresponding checks.
    assert!(roles_dispatcher.is_app_role_admin(account: app_role_admin));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.remove_app_role_admin(account: app_role_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_remove_app_role_admin second",
    );
    event_test_utils::assert_app_role_admin_removed_event(
        events[1], removed_account: app_role_admin, removed_by: governance_admin,
    );
    assert!(!roles_dispatcher.is_app_role_admin(account: app_role_admin));
}


#[test]
fn test_register_upgrade_governor() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let governance_admin = Constants::INITIAL_ROOT_ADMIN();
    let upgrade_governor = Constants::UPGRADE_GOVERNOR();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Try to add zero address as upgrade governor.
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    let result = roles_safe_dispatcher.register_upgrade_governor(account: Zero::zero());
    assert_panic_with_error(:result, expected_error: AccessErrors::ZERO_ADDRESS);

    // Try to add upgrade governor with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.register_upgrade_governor(account: upgrade_governor);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Register upgrade governor and perform the corresponding checks.
    let mut spy = snforge_std::spy_events();
    assert!(!roles_dispatcher.is_upgrade_governor(account: upgrade_governor));
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.register_upgrade_governor(account: upgrade_governor);

    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_register_upgrade_governor first",
    );
    event_test_utils::assert_upgrade_governor_added_event(
        events[1], added_account: upgrade_governor, added_by: governance_admin,
    );
    assert!(roles_dispatcher.is_upgrade_governor(account: upgrade_governor));

    // Register upgrade governor that is already registered (should not emit events).
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.register_upgrade_governor(account: upgrade_governor);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_register_upgrade_governor second",
    );
}


#[test]
fn test_remove_upgrade_governor() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let governance_admin = Constants::INITIAL_ROOT_ADMIN();
    let upgrade_governor = Constants::UPGRADE_GOVERNOR();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Remove upgrade governor that was not registered (should not emit events).
    assert!(!roles_dispatcher.is_upgrade_governor(account: upgrade_governor));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.remove_upgrade_governor(account: upgrade_governor);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_remove_upgrade_governor first",
    );

    // Register upgrade governor.
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.register_upgrade_governor(account: upgrade_governor);

    // Try to remove upgrade governor with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.remove_upgrade_governor(account: upgrade_governor);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Remove upgrade governor and perform the corresponding checks.
    assert!(roles_dispatcher.is_upgrade_governor(account: upgrade_governor));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: governance_admin);
    roles_dispatcher.remove_upgrade_governor(account: upgrade_governor);
    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_remove_upgrade_governor second",
    );
    event_test_utils::assert_upgrade_governor_removed_event(
        events[1], removed_account: upgrade_governor, removed_by: governance_admin,
    );
    assert!(!roles_dispatcher.is_upgrade_governor(account: upgrade_governor));
}


#[test]
fn test_register_governance_admin() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let initial_governance_admin = Constants::INITIAL_ROOT_ADMIN();
    let governance_admin = Constants::GOVERNANCE_ADMIN();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Try to add zero address as governance admin.
    cheat_caller_address_once(:contract_address, caller_address: initial_governance_admin);
    let result = roles_safe_dispatcher.register_governance_admin(account: Zero::zero());
    assert_panic_with_error(:result, expected_error: AccessErrors::ZERO_ADDRESS);

    // Try to add governance admin with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.register_governance_admin(account: governance_admin);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Register governance admin and perform the corresponding checks.
    let mut spy = snforge_std::spy_events();
    assert!(!roles_dispatcher.is_governance_admin(account: governance_admin));
    cheat_caller_address_once(:contract_address, caller_address: initial_governance_admin);
    roles_dispatcher.register_governance_admin(account: governance_admin);

    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_register_governance_admin first",
    );
    event_test_utils::assert_governance_admin_added_event(
        events[1], added_account: governance_admin, added_by: initial_governance_admin,
    );
    assert!(roles_dispatcher.is_governance_admin(account: governance_admin));

    // Register governance admin that is already registered (should not emit events).
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: initial_governance_admin);
    roles_dispatcher.register_governance_admin(account: governance_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_register_governance_admin second",
    );
}


#[test]
fn test_remove_governance_admin() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let initial_governance_admin = Constants::INITIAL_ROOT_ADMIN();
    let governance_admin = Constants::GOVERNANCE_ADMIN();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Remove governance admin that was not registered (should not emit events).
    assert!(!roles_dispatcher.is_governance_admin(account: governance_admin));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: initial_governance_admin);
    roles_dispatcher.remove_governance_admin(account: governance_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_remove_governance_admin first",
    );

    // Register governance admin.
    cheat_caller_address_once(:contract_address, caller_address: initial_governance_admin);
    roles_dispatcher.register_governance_admin(account: governance_admin);

    // Try to remove governance admin with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.remove_governance_admin(account: governance_admin);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Remove governance admin and perform the corresponding checks.
    assert!(roles_dispatcher.is_governance_admin(account: governance_admin));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: initial_governance_admin);
    roles_dispatcher.remove_governance_admin(account: governance_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_remove_governance_admin second",
    );
    event_test_utils::assert_governance_admin_removed_event(
        events[1], removed_account: governance_admin, removed_by: initial_governance_admin,
    );
    assert!(!roles_dispatcher.is_governance_admin(account: governance_admin));
}


#[test]
fn test_register_security_agent() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let security_admin = Constants::INITIAL_ROOT_ADMIN();
    let security_agent = Constants::SECURITY_AGENT();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Try to add zero address as security agent.
    cheat_caller_address_once(:contract_address, caller_address: security_admin);
    let result = roles_safe_dispatcher.register_security_agent(account: Zero::zero());
    assert_panic_with_error(:result, expected_error: AccessErrors::ZERO_ADDRESS);

    // Try to add security agent with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.register_security_agent(account: security_agent);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Register security agent and perform the corresponding checks.
    let mut spy = snforge_std::spy_events();
    assert!(!roles_dispatcher.is_security_agent(account: security_agent));
    cheat_caller_address_once(:contract_address, caller_address: security_admin);
    roles_dispatcher.register_security_agent(account: security_agent);

    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_register_security_agent first",
    );
    event_test_utils::assert_security_agent_added_event(
        events[1], added_account: security_agent, added_by: security_admin,
    );
    assert!(roles_dispatcher.is_security_agent(account: security_agent));

    // Register security agent that is already registered (should not emit events).
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: security_admin);
    roles_dispatcher.register_security_agent(account: security_agent);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_register_security_agent second",
    );
}

#[test]
fn test_remove_security_agent() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let security_admin = Constants::INITIAL_ROOT_ADMIN();
    let security_agent = Constants::SECURITY_AGENT();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Remove security agent that was not registered (should not emit events).
    assert!(!roles_dispatcher.is_security_agent(account: security_agent));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: security_admin);
    roles_dispatcher.remove_security_agent(account: security_agent);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_remove_security_agent first",
    );

    // Register security agent.
    cheat_caller_address_once(:contract_address, caller_address: security_admin);
    roles_dispatcher.register_security_agent(account: security_agent);

    // Try to remove security agent with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.remove_security_agent(account: security_agent);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Remove security agent and perform the corresponding checks.
    assert!(roles_dispatcher.is_security_agent(account: security_agent));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: security_admin);
    roles_dispatcher.remove_security_agent(account: security_agent);
    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_remove_security_agent second",
    );
    event_test_utils::assert_security_agent_removed_event(
        events[1], removed_account: security_agent, removed_by: security_admin,
    );
    assert!(!roles_dispatcher.is_security_agent(account: security_agent));
}


#[test]
fn test_register_security_admin() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let initial_security_admin = Constants::INITIAL_ROOT_ADMIN();
    let security_admin = Constants::SECURITY_ADMIN();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Try to add zero address as security admin.
    cheat_caller_address_once(:contract_address, caller_address: initial_security_admin);
    let result = roles_safe_dispatcher.register_security_admin(account: Zero::zero());
    assert_panic_with_error(:result, expected_error: AccessErrors::ZERO_ADDRESS);

    // Try to add security admin with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.register_security_admin(account: security_admin);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Register security admin and perform the corresponding checks.
    let mut spy = snforge_std::spy_events();
    assert!(!roles_dispatcher.is_security_admin(account: security_admin));
    cheat_caller_address_once(:contract_address, caller_address: initial_security_admin);
    roles_dispatcher.register_security_admin(account: security_admin);

    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_register_security_admin first",
    );
    event_test_utils::assert_security_admin_added_event(
        events[1], added_account: security_admin, added_by: initial_security_admin,
    );
    assert!(roles_dispatcher.is_security_admin(account: security_admin));

    // Register security admin that is already registered (should not emit events).
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: initial_security_admin);
    roles_dispatcher.register_security_admin(account: security_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_register_security_admin second",
    );
}


#[test]
fn test_remove_security_admin() {
    // Deploy mock contract.
    let contract_address = test_utils::deploy_mock_contract();
    let roles_dispatcher = IRolesDispatcher { contract_address };
    let roles_safe_dispatcher = IRolesSafeDispatcher { contract_address };
    let initial_security_admin = Constants::INITIAL_ROOT_ADMIN();
    let security_admin = Constants::SECURITY_ADMIN();
    let wrong_admin = Constants::WRONG_ADMIN();

    // Remove security admin that was not registered (should not emit events).
    assert!(!roles_dispatcher.is_security_admin(account: security_admin));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: initial_security_admin);
    roles_dispatcher.remove_security_admin(account: security_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    assert_number_of_events(
        actual: events.len(), expected: 0, message: "test_remove_security_admin first",
    );

    // Register security admin.
    cheat_caller_address_once(:contract_address, caller_address: initial_security_admin);
    roles_dispatcher.register_security_admin(account: security_admin);

    // Try to remove security admin with unqualified caller.
    cheat_caller_address_once(:contract_address, caller_address: wrong_admin);
    let result = roles_safe_dispatcher.remove_security_admin(account: security_admin);
    assert_panic_with_error(:result, expected_error: OZAccessErrors::MISSING_ROLE);

    // Remove security admin and perform the corresponding checks.
    assert!(roles_dispatcher.is_security_admin(account: security_admin));
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(:contract_address, caller_address: initial_security_admin);
    roles_dispatcher.remove_security_admin(account: security_admin);
    let events = spy.get_events().emitted_by(:contract_address).events;
    // We only check events[1] because events[0] is an event emitted by OZ AccessControl.
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "test_remove_security_admin second",
    );
    event_test_utils::assert_security_admin_removed_event(
        events[1], removed_account: security_admin, removed_by: initial_security_admin,
    );
    assert!(!roles_dispatcher.is_security_admin(account: security_admin));
}