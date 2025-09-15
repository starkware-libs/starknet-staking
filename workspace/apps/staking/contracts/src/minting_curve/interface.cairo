use staking::types::{Amount, Inflation};

#[starknet::interface]
pub trait IMintingCurve<TContractState> {
    /// Return yearly mint amount (M * total_supply).
    /// To calculate the amount, we utilize the minting curve formula (which is in percentage):
    ///   M = (C / 10) * sqrt(S),
    /// where:
    /// - M: Yearly mint rate (%)
    /// - C: Max theoretical inflation (%)
    /// - S: Staking rate of total supply (%)
    ///
    /// If C, S and M are given as a fractions (instead of percentages), we get:
    ///   M = C * sqrt(S).
    fn yearly_mint(self: @TContractState) -> Amount;
    fn contract_parameters(self: @TContractState) -> MintingCurveContractInfo;
}

#[starknet::interface]
pub trait IMintingCurveConfig<TContractState> {
    /// Set the maximum inflation rate that can be minted in a year.
    /// c_num is the numerator of the fraction c_num / C_DENOM (currently C_DENOM = 10,000).
    /// If you wish to set the inflation rate to 1.7%, you should set c_num to 170.
    fn set_c_num(ref self: TContractState, c_num: Inflation);
}

pub mod Events {
    use staking::types::Amount;

    #[derive(Drop, starknet::Event)]
    pub struct TotalSupplyChanged {
        pub old_total_supply: Amount,
        pub new_total_supply: Amount,
    }
}

pub mod ConfigEvents {
    use staking::types::Inflation;

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
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
