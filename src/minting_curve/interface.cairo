use staking::types::{Amount, Inflation};
pub use starkware_utils::components::roles::errors::AccessErrors;

#[starknet::interface]
pub trait IMintingCurve<TContractState> {
    /// Returns yearly mint amount (M * total_supply). Yearly mint is the amount of tokens that
    /// should be minted in a year given the current total stake in the staking contract.
    ///
    /// To calculate the amount, we utilize the minting curve formula (which is in percentage):
    ///   M = (C / 10) * sqrt(S),
    /// where:
    /// - M: Yearly mint rate (%)
    /// - C: Max theoretical inflation (%)
    /// - S: Staking rate of total supply (%)
    ///
    /// If C, S and M are given as a fractions (instead of percentages), we get:
    ///   M = C * sqrt(S).
    ///
    /// #### Internal calls:
    /// - [`staking::staking::interface::IStaking::get_current_total_staking_power`]
    fn yearly_mint(self: @TContractState) -> Amount;
    /// Returns [`MintingCurveContractInfo`] describing the contract.
    fn contract_parameters(self: @TContractState) -> MintingCurveContractInfo;
}

#[starknet::interface]
pub trait IMintingCurveConfig<TContractState> {
    /// Set the maximum inflation rate that can be minted in a year.
    /// `c_num` is the numerator of the fraction `c_num / C_DENOM` (currently `C_DENOM` = 10,000).
    /// If you wish to set the inflation rate to 1.7%, you should set `c_num` to 170.
    ///
    /// #### Emits:
    /// - [`MintingCapChanged`](ConfigEvents::MintingCapChanged)
    ///
    /// #### Errors:
    /// - [`ONLY_TOKEN_ADMIN`](AccessErrors::ONLY_TOKEN_ADMIN)
    /// - [`C_NUM_OUT_OF_RANGE`](staking::minting_curve::errors::Error::C_NUM_OUT_OF_RANGE)
    ///
    /// #### Access control:
    /// Only token admin.
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

/// Includes parameters and configuration of the minting curve contract.
#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct MintingCurveContractInfo {
    /// The numerator of the maximum inflation rate.
    pub c_num: Inflation,
    /// The denominator of the maximum inflation rate.
    pub c_denom: Inflation,
}
