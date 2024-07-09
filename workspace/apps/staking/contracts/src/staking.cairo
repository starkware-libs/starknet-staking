pub mod interface;

pub mod staking;

//convenient reference
pub use staking::Staking;
pub use interface::{IStaking, StakerInfo, StakingContractInfo};

#[cfg(test)]
mod test;
