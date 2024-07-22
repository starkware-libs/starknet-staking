use core::traits::Into;

#[derive(Drop)]
pub enum Error {
    // Generic errors
    INTEREST_ISNT_U64,
    REWARDS_ISNT_U128,
    REV_SHARE_ISNT_U128,
    // Shared errors
    STAKER_EXISTS,
    STAKER_DOES_NOT_EXIST,
    OPERATIONAL_EXISTS,
    POOLED_REWARDS_ISNT_U128,
    // Staking contract errors
    AMOUNT_LESS_THAN_MIN_STAKE,
    REV_SHARE_OUT_OF_RANGE,
    // Pooling contract errors
    POOL_MEMBER_DOES_NOT_EXIST,
    STAKER_IS_INACTIVE,
    POOL_MEMBER_EXISTS,
}


#[inline(always)]
pub fn panic_by_err(error: Error) {
    match error {
        Error::INTEREST_ISNT_U64 => panic!("Interest is too large, expected to fit in u64."),
        Error::REWARDS_ISNT_U128 => panic!("Staker rewards is too large, expected to fit in u128."),
        Error::REV_SHARE_ISNT_U128 => panic!("Rev share is too large, expected to fit in u128."),
        Error::STAKER_EXISTS => panic!("Staker already exists, use increase_stake instead."),
        Error::STAKER_DOES_NOT_EXIST => panic!("Staker does not exist."),
        Error::OPERATIONAL_EXISTS => panic!("Operational address already exists."),
        Error::AMOUNT_LESS_THAN_MIN_STAKE => panic!(
            "Amount is less than min stake - try again with enough funds."
        ),
        Error::REV_SHARE_OUT_OF_RANGE => panic!("Rev share is out of range, expected to be 0-100."),
        Error::POOLED_REWARDS_ISNT_U128 => panic!(
            "Pool rewards is too large, expected to fit in u128."
        ),
        Error::POOL_MEMBER_DOES_NOT_EXIST => panic!("Pool member does not exist."),
        Error::STAKER_IS_INACTIVE => panic!("Staker is inactive."),
        Error::POOL_MEMBER_EXISTS => panic!(
            "Pool member exists, use add_to_delegation_pool instead."
        ),
    }
}

#[inline(always)]
pub fn assert_with_err(condition: bool, error: Error) {
    if !condition {
        panic_by_err(error);
    }
}
