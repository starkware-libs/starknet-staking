pub mod interface;

pub mod staking;
pub mod objects;

//convenient reference
pub use staking::Staking;
pub use interface::{IStaking, StakerInfo, StakerPoolInfo, StakerInfoTrait, StakingContractInfo};
pub use interface::{IStakingPool, IStakingPause, IStakingConfig};
pub use interface::{Events, PauseEvents};

#[cfg(test)]
mod test;
