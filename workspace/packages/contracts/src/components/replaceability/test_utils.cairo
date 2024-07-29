use contracts_commons::components::replaceability::interface::IReplaceableDispatcher;
use contracts_commons::components::replaceability::interface::ImplementationData;
use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use snforge_std::{ContractClassTrait, declare, get_class_hash};
use starknet::{ContractAddress, contract_address_const};
use starknet::class_hash::{class_hash_const, ClassHash};

pub(crate) mod Constants {
    use super::{ContractAddress, ImplementationData, contract_address_const};
    use super::dummy_implementation_data;

    pub(crate) const DEFAULT_UPGRADE_DELAY: u64 = 12345;

    pub(crate) fn CALLER_ADDRESS() -> ContractAddress {
        contract_address_const::<'CALLER_ADDRESS'>()
    }

    pub(crate) fn DUMMY_NONFINAL_IMPLEMENTATION_DATA() -> ImplementationData {
        dummy_implementation_data(final: false)
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

fn dummy_implementation_data(final: bool) -> ImplementationData {
    ImplementationData {
        impl_hash: class_hash_const::<0>(), eic_data: Option::None(()), final: final
    }
}
