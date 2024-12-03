use contracts::types::{Amount, Inflation};

#[starknet::interface]
pub trait IMintingCurve<TContractState> {
    fn yearly_mint(self: @TContractState) -> Amount;
    fn contract_parameters(self: @TContractState) -> MintingCurveContractInfo;
}

#[starknet::interface]
pub trait IMintingCurveConfig<TContractState> {
    fn set_c_num(ref self: TContractState, c_num: Inflation);
}

pub mod Events {
    use contracts::types::Amount;

    #[derive(Drop, starknet::Event)]
    pub struct TotalSupplyChanged {
        pub old_total_supply: Amount,
        pub new_total_supply: Amount,
    }
}

pub mod ConfigEvents {
    use contracts::types::Inflation;

    #[derive(Drop, starknet::Event)]
    pub struct MintingCapChanged {
        pub old_c: Inflation,
        pub new_c: Inflation,
    }
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct MintingCurveContractInfo {
    pub c_num: Inflation,
    pub c_denom: Inflation,
}
