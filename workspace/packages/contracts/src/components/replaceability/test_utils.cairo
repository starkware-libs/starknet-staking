use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait};

pub mod Constants {
    pub const DEFAULT_UPGRADE_DELAY: u64 = 12345;
}

pub mod Errors {
    pub const UPGRADE_DELAY_ERROR: felt252 = 'upgrade delay error';
}

pub fn deploy_replaceability_mock() -> ContractAddress {
    let replaceable_contract = declare("ReplaceabilityMock").unwrap();
    let (contract_address, _) = replaceable_contract
        .deploy(@array![Constants::DEFAULT_UPGRADE_DELAY.into()])
        .unwrap();
    return contract_address;
}
