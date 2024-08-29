#[starknet::interface]
pub trait IMintingCurve<TContractState> {
    fn yearly_mint(self: @TContractState) -> u128;
}

pub mod Events {
    #[derive(Drop, starknet::Event)]
    pub struct TotalSupplyChanged {
        pub old_total_supply: u128,
        pub new_total_supply: u128
    }
}
