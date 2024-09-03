use contracts_commons::components::replaceability::ReplaceabilityComponent;
use contracts_commons::components::replaceability::interface::EICData;
use contracts_commons::components::replaceability::interface::IReplaceableDispatcher;
use contracts_commons::components::replaceability::interface::ImplementationData;
use contracts_commons::components::replaceability::interface::ImplementationFinalized;
use contracts_commons::components::replaceability::interface::ImplementationReplaced;
use contracts_commons::components::replaceability::mock::ReplaceabilityMock;
use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use snforge_std::{ContractClassTrait, declare, load};
use snforge_std::cheatcodes::events::{Event, Events, is_emitted};
use starknet::ContractAddress;
use starknet::class_hash::ClassHash;

pub(crate) mod Constants {
    use super::{ContractAddress, ImplementationData};
    use starknet::contract_address_const;
    use starknet::class_hash::class_hash_const;

    pub(crate) const DEFAULT_UPGRADE_DELAY: u64 = 12345;
    pub(crate) const EIC_UPGRADE_DELAY_ADDITION: u64 = 5;

    pub(crate) fn CALLER_ADDRESS() -> ContractAddress {
        contract_address_const::<'CALLER_ADDRESS'>()
    }

    pub(crate) fn DUMMY_FINAL_IMPLEMENTATION_DATA() -> ImplementationData {
        ImplementationData {
            impl_hash: class_hash_const::<0>(), eic_data: Option::None(()), final: true
        }
    }

    pub(crate) fn DUMMY_NONFINAL_IMPLEMENTATION_DATA() -> ImplementationData {
        ImplementationData {
            impl_hash: class_hash_const::<0>(), eic_data: Option::None(()), final: false
        }
    }

    pub(crate) fn NOT_UPGRADE_GOVERNOR_ACCOUNT() -> ContractAddress {
        contract_address_const::<'NOT_UPGRADE_GOVERNOR_ACCOUNT'>()
    }
}

pub(crate) fn deploy_replaceability_mock() -> IReplaceableDispatcher {
    let replaceable_contract = declare("ReplaceabilityMock").unwrap();
    let (contract_address, _) = replaceable_contract
        .deploy(@array![Constants::DEFAULT_UPGRADE_DELAY.into()])
        .unwrap();
    return IReplaceableDispatcher { contract_address: contract_address };
}

pub(crate) fn get_upgrade_governor_account(contract_address: ContractAddress) -> ContractAddress {
    let caller_address: ContractAddress = Constants::CALLER_ADDRESS();
    set_caller_as_upgrade_governor(contract_address, caller_address);
    return caller_address;
}

fn set_caller_as_upgrade_governor(contract_address: ContractAddress, caller: ContractAddress) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract_address };
    roles_dispatcher.register_upgrade_governor(account: caller);
}

pub fn dummy_final_implementation_data_with_class_hash(
    class_hash: ClassHash
) -> ImplementationData {
    ImplementationData { impl_hash: class_hash, eic_data: Option::None(()), final: true }
}

pub(crate) fn dummy_nonfinal_implementation_data_with_class_hash(
    class_hash: ClassHash
) -> ImplementationData {
    ImplementationData { impl_hash: class_hash, eic_data: Option::None(()), final: false }
}

pub(crate) fn dummy_nonfinal_eic_implementation_data_with_class_hash(
    class_hash: ClassHash
) -> ImplementationData {
    // Set the eic_init_data calldata.
    let calldata = array![Constants::EIC_UPGRADE_DELAY_ADDITION.into()];

    let eic_contract = declare("EICTestContract").unwrap();
    let eic_data = EICData { eic_hash: eic_contract.class_hash, eic_init_data: calldata.span() };

    ImplementationData { impl_hash: class_hash, eic_data: Option::Some(eic_data), final: false }
}

pub(crate) fn assert_implementation_replaced_event_emitted(
    mut spied_event: @(ContractAddress, Event), implementation_data: ImplementationData
) {
    let expected_event = @ReplaceabilityMock::Event::ReplaceabilityEvent(
        ReplaceabilityComponent::Event::ImplementationReplaced(
            ImplementationReplaced { implementation_data: implementation_data }
        )
    );
    assert_expected_event_emitted(:spied_event, :expected_event);
}

pub(crate) fn assert_implementation_finalized_event_emitted(
    mut spied_event: @(ContractAddress, Event), implementation_data: ImplementationData
) {
    let expected_event = @ReplaceabilityMock::Event::ReplaceabilityEvent(
        ReplaceabilityComponent::Event::ImplementationFinalized(
            ImplementationFinalized { impl_hash: implementation_data.impl_hash }
        )
    );
    assert_expected_event_emitted(:spied_event, :expected_event);
}

fn assert_expected_event_emitted(
    mut spied_event: @(ContractAddress, Event), expected_event: @ReplaceabilityMock::Event
) {
    let (event_address, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*event_address, raw_event.clone())] };
    if (!is_emitted(
        self: @wrapped_spied_event, expected_emitted_by: event_address, :expected_event
    )) {
        let event_from: felt252 = (*event_address).into();
        panic!("Could not match expected event from {}", event_from);
    }
}

pub(crate) fn assert_finalized_status(expected: bool, contract_address: ContractAddress) {
    // load the finalized attribute from the storage of the given contract.
    let finalized = *load(
        target: contract_address, storage_address: selector!("finalized"), size: 1
    )
        .at(0);
    assert!(finalized == expected.into());
}
