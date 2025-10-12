use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum Error {
    POOL_MEMBER_DOES_NOT_EXIST,
    STAKER_INACTIVE,
    POOL_MEMBER_EXISTS,
    UNDELEGATE_IN_PROGRESS,
    SWITCH_POOL_DATA_DESERIALIZATION_FAILED,
    STAKER_ALREADY_REMOVED,
    CALLER_CANNOT_ADD_TO_POOL,
    REWARD_ADDRESS_MISMATCH,
    POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS,
    POOL_MEMBER_IS_TOKEN,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::POOL_MEMBER_DOES_NOT_EXIST => "Pool member does not exist",
            Error::STAKER_INACTIVE => "Staker inactive",
            Error::UNDELEGATE_IN_PROGRESS => "Undelegate from pool in progress, pool member is in an exit window",
            Error::POOL_MEMBER_EXISTS => "Pool member exists, use add_to_delegation_pool instead",
            Error::STAKER_ALREADY_REMOVED => "Staker already removed",
            Error::CALLER_CANNOT_ADD_TO_POOL => "Caller address should be pool member address or reward address",
            Error::REWARD_ADDRESS_MISMATCH => "Reward address mismatch",
            Error::SWITCH_POOL_DATA_DESERIALIZATION_FAILED => "Switch pool data deserialization failed",
            Error::POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS => "Claim rewards must be called from pool member address or reward address",
            Error::POOL_MEMBER_IS_TOKEN => "Pool member is a token address",
        }
    }
}
