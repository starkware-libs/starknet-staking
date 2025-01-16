#[starknet::interface]
pub trait INonce<TState> {
    fn nonce(self: @TState) -> u64;
}
