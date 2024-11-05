pub mod interface;

pub mod staking;
pub mod align_upg_vars_eic;
pub mod objects;

//convenient reference
pub use staking::Staking;
pub use interface::{IStaking, StakerPoolInfo, StakingContractInfo};
pub use interface::{StakerInfo, StakerInfoTrait};
pub use interface::{IStakingPool, IStakingPause, IStakingConfig};
pub use interface::{Events, PauseEvents, ConfigEvents};

pub mod staking_tester;
pub use staking_tester::IStakingTester;

#[cfg(test)]
mod test;

#[cfg(test)]
mod pause_test;
