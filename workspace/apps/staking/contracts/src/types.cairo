use staking::pool::objects::InternalPoolMemberInfoV1;
use staking::staking::objects::{InternalStakerInfoV1, InternalStakerPoolInfoV1};

// If we change the type, make sure the errors still show the right type.
pub(crate) type Commission = u16;
pub(crate) type Amount = u128;
pub(crate) type Index = u128;
pub(crate) type Inflation = u16;
pub(crate) type Epoch = u64;
pub(crate) type Version = felt252;
pub(crate) type VecIndex = u64;

// ------ Migration ------ //
// **Note**: These aliases should be updated in the next version.
pub(crate) type InternalStakerInfoLatest = InternalStakerInfoV1;
pub(crate) type InternalStakerPoolInfoLatest = InternalStakerPoolInfoV1;
pub(crate) type InternalPoolMemberInfoLatest = InternalPoolMemberInfoV1;
// ---------------------- //


