use staking::staking::objects::InternalStakerInfoV1;

// If we change the type, make sure the errors still show the right type.
pub(crate) type Commission = u16;
pub(crate) type Amount = u128;
pub(crate) type Index = u128;
pub(crate) type Inflation = u16;
pub(crate) type Epoch = u64;
pub(crate) type Version = u8;
// **Note**: This alias should be updated in the next version.
pub(crate) type InternalStakerInfoLatest = InternalStakerInfoV1;
