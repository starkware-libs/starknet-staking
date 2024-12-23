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
    let governance_admin = Constants::GOVERNANCE_ADMIN();
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
    let governance_admin = Constants::GOVERNANCE_ADMIN();
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
