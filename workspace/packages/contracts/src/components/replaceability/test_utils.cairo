use contracts_commons::components::replaceability::interface::EICData;
use contracts_commons::components::replaceability::interface::IReplaceableDispatcher;
use contracts_commons::components::replaceability::interface::ImplementationData;
use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use snforge_std::{ContractClassTrait, declare, get_class_hash};
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
