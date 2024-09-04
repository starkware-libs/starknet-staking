use starknet::ContractAddress;

#[starknet::interface]
pub trait IOperator<TContractState> {
    fn enable_whitelist(ref self: TContractState);
    fn disable_whitelist(ref self: TContractState);
    fn is_whitelist_enabled(self: @TContractState) -> bool;
    fn add_to_whitelist(ref self: TContractState, address: ContractAddress);
    fn get_whitelist_addresses(self: @TContractState) -> Array<ContractAddress>;
}
