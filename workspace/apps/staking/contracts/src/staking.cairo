mod interface;

mod staking;

use staking::Staking;
use interface::{IStaking, StakerInfo, StakingContractInfo};

#[cfg(test)]
mod test;
