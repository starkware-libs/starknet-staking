#[starknet::interface]
pub trait Identity<TContractState> {
    fn identify(self: @TContractState) -> felt252;
    fn version(self: @TContractState) -> felt252;
}
