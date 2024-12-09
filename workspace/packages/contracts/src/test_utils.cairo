use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use contracts_commons::constants::{NAME, SYMBOL};
use contracts_commons::interfaces::identity::{IdentityDispatcher, IdentityDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{CheatSpan, cheat_account_contract_address, cheat_caller_address};
use snforge_std::{ContractClassTrait, DeclareResultTrait};
use starknet::ContractAddress;

pub fn cheat_only_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress,
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
}

pub fn cheat_account_contract_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress,
) {
    cheat_account_contract_address(
        :contract_address,
        account_contract_address: caller_address,
        span: CheatSpan::TargetCalls(1),
    );
}


pub fn set_caller_as_upgrade_governor(contract: ContractAddress, caller: ContractAddress) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: caller);
    roles_dispatcher.register_upgrade_governor(account: caller);
}

pub fn set_account_as_security_admin(
    contract: ContractAddress, account: ContractAddress, governance_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: governance_admin);
    roles_dispatcher.register_security_admin(:account);
}

pub fn set_account_as_security_agent(
    contract: ContractAddress, account: ContractAddress, security_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: security_admin);
    roles_dispatcher.register_security_agent(:account);
}

pub fn set_account_as_app_role_admin(
    contract: ContractAddress, account: ContractAddress, governance_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: governance_admin);
    roles_dispatcher.register_app_role_admin(:account);
}

pub fn set_account_as_upgrade_governor(
    contract: ContractAddress, account: ContractAddress, governance_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: governance_admin);
    roles_dispatcher.register_upgrade_governor(:account);
}

pub fn set_account_as_token_admin(
    contract: ContractAddress, account: ContractAddress, app_role_admin: ContractAddress,
) {
    let roles_dispatcher = IRolesDispatcher { contract_address: contract };
    cheat_caller_address_once(contract_address: contract, caller_address: app_role_admin);
    roles_dispatcher.register_token_admin(:account);
}

pub fn cheat_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress,
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
    cheat_account_contract_address(
        :contract_address,
        account_contract_address: caller_address,
        span: CheatSpan::TargetCalls(1),
    );
}

pub fn check_identity(
    target: ContractAddress, expected_identity: felt252, expected_version: felt252,
) {
    let identitier = IdentityDispatcher { contract_address: target };
    let identity = identitier.identify();
    let version = identitier.version();
    assert_eq!(expected_identity, identity);
    assert_eq!(expected_version, version);
}

/// The `TokenConfig` struct is used to configure the initial settings for a token contract.
/// It includes the initial supply of tokens and the owner's address.
#[derive(Drop, Copy)]
pub struct TokenConfig {
    pub initial_supply: u256,
    pub owner: ContractAddress,
}

/// The `TokenState` struct represents the state of a token contract.
/// It includes the contract address and the owner's address.
#[derive(Drop, Copy)]
pub struct TokenState {
    pub address: ContractAddress,
    pub owner: ContractAddress,
}

#[generate_trait]
pub impl TokenImpl of TokenTrait {
    fn deploy(self: TokenConfig) -> TokenState {
        let mut calldata = ArrayTrait::new();
        NAME().serialize(ref calldata);
        SYMBOL().serialize(ref calldata);
        self.initial_supply.serialize(ref calldata);
        self.owner.serialize(ref calldata);
        let token_contract = snforge_std::declare("DualCaseERC20Mock").unwrap().contract_class();
        let (address, _) = token_contract.deploy(@calldata).unwrap();
        TokenState { address, owner: self.owner }
    }

    fn fund(self: TokenState, recipient: ContractAddress, amount: u128) {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: self.address };
        cheat_caller_address_once(contract_address: self.address, caller_address: self.owner);
        erc20_dispatcher.transfer(recipient: recipient, amount: amount.into());
    }

    fn approve(self: TokenState, owner: ContractAddress, spender: ContractAddress, amount: u128) {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: self.address };
        cheat_caller_address_once(contract_address: self.address, caller_address: owner);
        erc20_dispatcher.approve(spender: spender, amount: amount.into());
    }

    fn balance_of(self: TokenState, account: ContractAddress) -> u128 {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: self.address };
        erc20_dispatcher.balance_of(account: account).try_into().unwrap()
    }
}
