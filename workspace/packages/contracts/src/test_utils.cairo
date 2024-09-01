use snforge_std::{CheatSpan, cheat_caller_address};
use starknet::ContractAddress;

pub fn cheat_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
}

