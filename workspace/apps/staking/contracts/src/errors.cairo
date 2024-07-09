use core::traits::Into;

pub enum Error {
    // Generic errors
    INTEREST_ISNT_U64,
    // Shared errors
    STAKER_EXISTS,
    STAKER_DOES_NOT_EXIST,
    OPERATIONAL_EXISTS,
    // Staking contract errors
    AMOUNT_LESS_THAN_MIN_STAKE,
    // Pooling contract errors
    POOL_MEMBER_DOES_NOT_EXIST,
}


#[inline(always)]
pub fn panic_by_err(error: Error) {
    match error {
        Error::INTEREST_ISNT_U64 => panic!("Interest is too large, expected to fit in u64."),
        Error::STAKER_EXISTS => panic!("Staker already exists, use increase_stake instead."),
        Error::STAKER_DOES_NOT_EXIST => panic!("Staker does not exist."),
        Error::OPERATIONAL_EXISTS => panic!("Operational already exists."),
        Error::AMOUNT_LESS_THAN_MIN_STAKE => panic!(
            "Amount is less than min stake - try again with enough funds."
        ),
        Error::POOL_MEMBER_DOES_NOT_EXIST => panic!("Pool member does not exist."),
    }
}
