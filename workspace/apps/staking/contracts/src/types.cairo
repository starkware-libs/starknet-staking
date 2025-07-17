use staking_test::pool::objects::InternalPoolMemberInfoV1;
use staking_test::staking::objects::{InternalStakerInfoV1, InternalStakerPoolInfoV1};

// If we change the type, make sure the errors still show the right type.
pub type Commission = u16;
pub type Amount = u128;
pub type Index = u128;
pub type Inflation = u16;
pub type Epoch = u64;
pub type Version = felt252;
pub type VecIndex = u64;

// ------ Migration ------ //
// **Note**: These aliases should be updated in the next version.
pub type InternalStakerInfoLatest = InternalStakerInfoV1;
pub type InternalStakerPoolInfoLatest = InternalStakerPoolInfoV1;
pub type InternalPoolMemberInfoLatest = InternalPoolMemberInfoV1;
// ---------------------- //


