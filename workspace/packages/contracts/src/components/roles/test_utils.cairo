use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

pub(crate) mod Constants {
    use starknet::contract_address_const;
    use super::ContractAddress;

    pub(crate) fn WRONG_ADMIN() -> ContractAddress {
        contract_address_const::<'WRONG_ADMIN'>()
    }
    pub(crate) fn GOVERNANCE_ADMIN() -> ContractAddress {
        contract_address_const::<'GOVERNANCE_ADMIN'>()
    }
    pub(crate) fn APP_ROLE_ADMIN() -> ContractAddress {
        contract_address_const::<'APP_ROLE_ADMIN'>()
    }
}

pub(crate) fn deploy_mock_contract() -> ContractAddress {
    let mock_contract = *declare("MockContract").unwrap().contract_class();
    let (contract_address, _) = mock_contract
        .deploy(@array![Constants::GOVERNANCE_ADMIN().into()])
        .unwrap();
    contract_address
}
