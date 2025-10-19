use staking::pool::objects::InternalPoolMemberInfoV1;
use staking::staking::objects::{InternalStakerInfoV1, InternalStakerPoolInfoV1};

// If we change the type, make sure the errors still show the right type.
pub type Commission = u16;
pub type Amount = u128;
pub type Index = u128;
pub type Inflation = u16;
pub type Epoch = u64;
pub type Version = felt252;
pub type VecIndex = u64;
pub type PublicKey = felt252;
pub type BlockNumber = u64;
pub type StakingPower = u128;

// ------ Migration ------ //
/// **Note**: These aliases should be updated in the next version.
pub(crate) type InternalStakerInfoLatest = InternalStakerInfoV1;
pub(crate) type InternalStakerPoolInfoLatest = InternalStakerPoolInfoV1;
pub(crate) type InternalPoolMemberInfoLatest = InternalPoolMemberInfoV1;
// ---------------------- //


