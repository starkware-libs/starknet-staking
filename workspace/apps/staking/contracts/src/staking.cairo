pub mod interface;

pub mod staking;
pub mod objects;

//convenient reference
pub use staking::Staking;
pub use interface::{IStaking, StakerPoolInfo, StakingContractInfo};
pub use interface::{StakerInfo, StakerInfoTrait};
pub use interface::{IStakingPool, IStakingPause, IStakingConfig};
pub use interface::{Events, PauseEvents, ConfigEvents};

#[cfg(test)]
mod test;

#[cfg(test)]
mod pause_test;
