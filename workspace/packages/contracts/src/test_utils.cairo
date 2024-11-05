use contracts_commons::constants::{NAME, SYMBOL};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use snforge_std::{ContractClassTrait, DeclareResultTrait};
use snforge_std::{CheatSpan, cheat_caller_address, cheat_account_contract_address};
use starknet::ContractAddress;

pub fn cheat_only_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
}

pub fn cheat_account_contract_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress
) {
    cheat_account_contract_address(
        :contract_address, account_contract_address: caller_address, span: CheatSpan::TargetCalls(1)
    );
}

pub fn cheat_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
    cheat_account_contract_address(
        :contract_address, account_contract_address: caller_address, span: CheatSpan::TargetCalls(1)
    );
}


/// The `TokenConfig` struct is used to configure the initial settings for a token contract.
/// It includes the initial supply of tokens and the owner's address.
#[derive(Drop, Copy)]
pub struct TokenConfig {
    pub initial_supply: u256,
    pub owner: ContractAddress
}

/// The `TokenState` struct represents the state of a token contract.
/// It includes the contract address and the owner's address.
#[derive(Drop, Copy)]
pub struct TokenState {
    pub address: ContractAddress,
    pub owner: ContractAddress
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
