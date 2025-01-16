#[starknet::interface]
pub trait INonce<TContractState> {
    fn nonce(self: @TContractState) -> u64;
}
