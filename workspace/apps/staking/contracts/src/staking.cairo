pub mod interface;

pub mod staking;
pub mod objects;

//convenient reference
pub use staking::Staking;
pub use interface::{IStaking, StakerInfo, StakerInfoTrait, StakingContractInfo};
pub use interface::Events;

#[cfg(test)]
mod test;
