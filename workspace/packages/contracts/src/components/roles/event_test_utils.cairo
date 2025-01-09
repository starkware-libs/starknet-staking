use contracts_commons::components::roles;
use contracts_commons::event_test_utils::panic_with_event_details;
use roles::interface as RolesInterface;
use roles::mock_contract::MockContract;
use roles::roles::RolesComponent::Event as RolesEvent;
use snforge_std::cheatcodes::events::{Event, Events, is_emitted};
use starknet::ContractAddress;

pub(crate) fn assert_app_role_admin_added_event(
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


pub(crate) fn assert_app_role_admin_removed_event(
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

pub(crate) fn assert_app_governor_added_event(
    spied_event: @(ContractAddress, Event),
    added_account: ContractAddress,
    added_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::AppGovernorAdded(RolesInterface::AppGovernorAdded { added_account, added_by }),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "AppGovernorAdded{{added_account: {:?}, added_by: {:?}}}", added_account, added_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_app_governor_removed_event(
    spied_event: @(ContractAddress, Event),
    removed_account: ContractAddress,
    removed_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::AppGovernorRemoved(
            RolesInterface::AppGovernorRemoved { removed_account, removed_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "AppGovernorRemoved{{removed_account: {:?}, removed_by: {:?}}}",
            removed_account,
            removed_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_token_admin_added_event(
    spied_event: @(ContractAddress, Event),
    added_account: ContractAddress,
    added_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::TokenAdminAdded(RolesInterface::TokenAdminAdded { added_account, added_by }),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "TokenAdminAdded{{added_account: {:?}, added_by: {:?}}}", added_account, added_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_token_admin_removed_event(
    spied_event: @(ContractAddress, Event),
    removed_account: ContractAddress,
    removed_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::TokenAdminRemoved(
            RolesInterface::TokenAdminRemoved { removed_account, removed_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "TokenAdminRemoved{{removed_account: {:?}, removed_by: {:?}}}",
            removed_account,
            removed_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_operator_added_event(
    spied_event: @(ContractAddress, Event),
    added_account: ContractAddress,
    added_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::OperatorAdded(RolesInterface::OperatorAdded { added_account, added_by }),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "OperatorAdded{{added_account: {:?}, added_by: {:?}}}", added_account, added_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_operator_removed_event(
    spied_event: @(ContractAddress, Event),
    removed_account: ContractAddress,
    removed_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::OperatorRemoved(
            RolesInterface::OperatorRemoved { removed_account, removed_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "OperatorRemoved{{removed_account: {:?}, removed_by: {:?}}}",
            removed_account,
            removed_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_upgrade_governor_added_event(
    spied_event: @(ContractAddress, Event),
    added_account: ContractAddress,
    added_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::UpgradeGovernorAdded(
            RolesInterface::UpgradeGovernorAdded { added_account, added_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "UpgradeGovernorAdded{{added_account: {:?}, added_by: {:?}}}", added_account, added_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_upgrade_governor_removed_event(
    spied_event: @(ContractAddress, Event),
    removed_account: ContractAddress,
    removed_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::UpgradeGovernorRemoved(
            RolesInterface::UpgradeGovernorRemoved { removed_account, removed_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "UpgradeGovernorRemoved{{removed_account: {:?}, removed_by: {:?}}}",
            removed_account,
            removed_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_governance_admin_added_event(
    spied_event: @(ContractAddress, Event),
    added_account: ContractAddress,
    added_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::GovernanceAdminAdded(
            RolesInterface::GovernanceAdminAdded { added_account, added_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "GovernanceAdminAdded{{added_account: {:?}, added_by: {:?}}}", added_account, added_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_governance_admin_removed_event(
    spied_event: @(ContractAddress, Event),
    removed_account: ContractAddress,
    removed_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::GovernanceAdminRemoved(
            RolesInterface::GovernanceAdminRemoved { removed_account, removed_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "GovernanceAdminRemoved{{removed_account: {:?}, removed_by: {:?}}}",
            removed_account,
            removed_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_security_agent_added_event(
    spied_event: @(ContractAddress, Event),
    added_account: ContractAddress,
    added_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::SecurityAgentAdded(
            RolesInterface::SecurityAgentAdded { added_account, added_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "SecurityAgentAdded{{added_account: {:?}, added_by: {:?}}}", added_account, added_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_security_agent_removed_event(
    spied_event: @(ContractAddress, Event),
    removed_account: ContractAddress,
    removed_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::SecurityAgentRemoved(
            RolesInterface::SecurityAgentRemoved { removed_account, removed_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "SecurityAgentRemoved{{removed_account: {:?}, removed_by: {:?}}}",
            removed_account,
            removed_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_security_admin_added_event(
    spied_event: @(ContractAddress, Event),
    added_account: ContractAddress,
    added_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::SecurityAdminAdded(
            RolesInterface::SecurityAdminAdded { added_account, added_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "SecurityAdminAdded{{added_account: {:?}, added_by: {:?}}}", added_account, added_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}


pub(crate) fn assert_security_admin_removed_event(
    spied_event: @(ContractAddress, Event),
    removed_account: ContractAddress,
    removed_by: ContractAddress,
) {
    let expected_event = @MockContract::Event::RolesEvent(
        RolesEvent::SecurityAdminRemoved(
            RolesInterface::SecurityAdminRemoved { removed_account, removed_by },
        ),
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "SecurityAdminRemoved{{removed_account: {:?}, removed_by: {:?}}}",
            removed_account,
            removed_by,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}
