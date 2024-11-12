#[starknet::interface]
pub trait IPausable<TState> {
    fn is_paused(self: @TState) -> bool;
    fn pause(ref self: TState);
    fn unpause(ref self: TState);
}
