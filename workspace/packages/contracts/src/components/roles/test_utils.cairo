use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

pub(crate) mod Constants {
    use starknet::contract_address_const;
    use super::ContractAddress;

    pub(crate) fn WRONG_ADMIN() -> ContractAddress {
        contract_address_const::<'WRONG_ADMIN'>()
    }
    pub(crate) fn INITIAL_ROOT_ADMIN() -> ContractAddress {
        contract_address_const::<'INITIAL_ROOT_ADMIN'>()
    }
    pub(crate) fn GOVERNANCE_ADMIN() -> ContractAddress {
        contract_address_const::<'GOVERNANCE_ADMIN'>()
    }
    pub(crate) fn SECURITY_ADMIN() -> ContractAddress {
        contract_address_const::<'SECURITY_ADMIN'>()
    }
    pub(crate) fn APP_ROLE_ADMIN() -> ContractAddress {
        contract_address_const::<'APP_ROLE_ADMIN'>()
    }
    pub(crate) fn APP_GOVERNOR() -> ContractAddress {
        contract_address_const::<'APP_GOVERNOR'>()
    }
    pub(crate) fn OPERATOR() -> ContractAddress {
        contract_address_const::<'OPERATOR'>()
    }
    pub(crate) fn TOKEN_ADMIN() -> ContractAddress {
        contract_address_const::<'TOKEN_ADMIN'>()
    }
    pub(crate) fn UPGRADE_GOVERNOR() -> ContractAddress {
        contract_address_const::<'UPGRADE_GOVERNOR'>()
    }
    pub(crate) fn SECURITY_AGENT() -> ContractAddress {
        contract_address_const::<'SECURITY_AGENT'>()
    }
}

pub(crate) fn deploy_mock_contract() -> ContractAddress {
    let mock_contract = *declare("MockContract").unwrap().contract_class();
    let (contract_address, _) = mock_contract
        .deploy(@array![Constants::INITIAL_ROOT_ADMIN().into()])
        .unwrap();
    contract_address
}
