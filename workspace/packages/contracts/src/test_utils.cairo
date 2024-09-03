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
