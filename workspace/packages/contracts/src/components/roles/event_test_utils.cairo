use contracts_commons::components::roles;
use contracts_commons::event_test_utils::{panic_with_event_details};
use roles::interface as RolesInterface;
use roles::mock_contract::MockContract;
use roles::roles::RolesComponent::Event as RolesEvent;
use snforge_std::cheatcodes::events::{Event, Events, is_emitted};
use starknet::ContractAddress;

pub fn assert_app_role_admin_added_event(
    spied_event: @(ContractAddress, Event),
    added_account: ContractAddress,
    added_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::AppRoleAdminAdded(
            RolesInterface::AppRoleAdminAdded { added_account, added_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "AppRoleAdminAdded{{added_account: {:?}, added_by: {:?}}}", added_account, added_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub fn assert_app_role_admin_removed_event(
    spied_event: @(ContractAddress, Event),
    removed_account: ContractAddress,
    removed_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::AppRoleAdminRemoved(
            RolesInterface::AppRoleAdminRemoved { removed_account, removed_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "AppRoleAdminRemoved{{removed_account: {:?}, removed_by: {:?}}}",
            removed_account,
            removed_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}
