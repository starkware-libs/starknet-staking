use contracts::types::{Inflation, Amount};

#[starknet::interface]
pub trait IMintingCurve<TContractState> {
    fn yearly_mint(self: @TContractState) -> Amount;
    fn contract_parameters(self: @TContractState) -> MintingCurveContractInfo;
}

#[starknet::interface]
pub trait IMintingCurveConfig<TContractState> {
    fn set_c_num(ref self: TContractState, c_num: Inflation);
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct MintingCurveContractInfo {
    pub c_num: Inflation,
    pub c_denom: Inflation,
}

pub mod Events {
    use contracts::types::Amount;

    #[derive(Drop, starknet::Event)]
    pub struct TotalSupplyChanged {
        pub old_total_supply: Amount,
        pub new_total_supply: Amount
    }
}
