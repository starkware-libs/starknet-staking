use contracts::staking::Staking::COMMISSION_DENOMINATOR;
use contracts::operator::Operator::MAX_WHITELIST_SIZE;
use contracts::constants::C_DENOM;

#[derive(Drop)]
pub enum Error {
    // Generic errors
    MESSAGES_COUNT_ISNT_U32,
    INTEREST_ISNT_U64,
    REWARDS_ISNT_U128,
    BALANCE_ISNT_U128,
    COMMISSION_ISNT_U128,
    // ERC20 errors,
    INSUFFICIENT_BALANCE,
    INSUFFICIENT_ALLOWANCE,
    // Shared errors
    STAKER_EXISTS,
    STAKER_NOT_EXISTS,
    OPERATIONAL_EXISTS,
    CALLER_CANNOT_INCREASE_STAKE,
    INVALID_REWARD_ADDRESS,
    INTENT_WINDOW_NOT_FINISHED,
    AMOUNT_TOO_HIGH,
    AMOUNT_IS_ZERO,
    CANNOT_INCREASE_COMMISSION,
    // Operator contract errors
    NOT_WHITELISTED,
    WHITELIST_FULL,
    // Staking contract errors
    AMOUNT_LESS_THAN_MIN_STAKE,
    COMMISSION_OUT_OF_RANGE,
    UNSTAKE_IN_PROGRESS,
    POOL_ADDRESS_DOES_NOT_EXIST,
    CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS,
    MISSING_UNSTAKE_INTENT,
    CALLER_IS_NOT_POOL_CONTRACT,
    MISSING_POOL_CONTRACT,
    DELEGATION_POOL_MISMATCH,
    GLOBAL_INDEX_DIFF_NOT_U64,
    GLOBAL_INDEX_DIFF_COMPUTATION_OVERFLOW,
    UNEXPECTED_BALANCE,
    STAKER_ALREADY_HAS_POOL,
    CONTRACT_IS_PAUSED,
    // Pool contract errors
    POOL_MEMBER_DOES_NOT_EXIST,
    STAKER_INACTIVE,
    POOL_MEMBER_EXISTS,
    UNDELEGATE_IN_PROGRESS,
    INSUFFICIENT_POOL_BALANCE,
    CALLER_IS_NOT_STAKING_CONTRACT,
    SWITCH_POOL_DATA_DESERIALIZATION_FAILED,
    FINAL_STAKER_INDEX_ALREADY_SET,
    MISSING_UNDELEGATE_INTENT,
    CALLER_CANNOT_ADD_TO_POOL,
    REWARD_ADDRESS_MISMATCH,
    // Minting contract errors
    TOTAL_SUPPLY_NOT_U128,
    POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS,
    UNAUTHORIZED_MESSAGE_SENDER,
    C_NUM_OUT_OF_RANGE,
    // Reward Supplier contract errors
    ON_RECEIVE_NOT_FROM_STARKGATE,
}


#[inline(always)]
pub fn panic_by_err(error: Error) -> core::never {
    match error {
        Error::ON_RECEIVE_NOT_FROM_STARKGATE => panic!("Only StarkGate can call on_receive."),
        Error::MESSAGES_COUNT_ISNT_U32 => panic!(
            "Number of messages is too large, expected to fit in u32."
        ),
        Error::INTEREST_ISNT_U64 => panic!("Interest is too large, expected to fit in u64."),
        Error::REWARDS_ISNT_U128 => panic!("Rewards is too large, expected to fit in u128."),
        Error::BALANCE_ISNT_U128 => panic!("Balance is too large, expected to fit in u128."),
        Error::COMMISSION_ISNT_U128 => panic!("Commission is too large, expected to fit in u128."),
        Error::STAKER_EXISTS => panic!("Staker already exists, use increase_stake instead."),
        Error::STAKER_NOT_EXISTS => panic!("Staker does not exist."),
        Error::CALLER_CANNOT_INCREASE_STAKE => panic!(
            "Caller address should be staker address or reward address."
        ),
        Error::NOT_WHITELISTED => panic!("Caller is not in whitelist."),
        Error::WHITELIST_FULL => panic!(
            "Whitelist is limited to {} addresses.", MAX_WHITELIST_SIZE
        ),
        Error::INVALID_REWARD_ADDRESS => panic!("Invalid reward address."),
        Error::AMOUNT_TOO_HIGH => panic!("Amount is too high."),
        Error::AMOUNT_IS_ZERO => panic!("Amount is zero."),
        Error::INTENT_WINDOW_NOT_FINISHED => panic!("Intent window is not finished."),
        Error::OPERATIONAL_EXISTS => panic!("Operational address already exists."),
        Error::AMOUNT_LESS_THAN_MIN_STAKE => panic!(
            "Amount is less than min stake - try again with enough funds."
        ),
        Error::COMMISSION_OUT_OF_RANGE => panic!(
            "Commission is out of range, expected to be 0-{}.", COMMISSION_DENOMINATOR
        ),
        Error::POOL_ADDRESS_DOES_NOT_EXIST => panic!("Pool address does not exist."),
        Error::MISSING_UNSTAKE_INTENT => panic!("Unstake intent is missing."),
        Error::UNSTAKE_IN_PROGRESS => panic!(
            "Unstake is in progress, staker is in an exit window."
        ),
        Error::CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS => panic!(
            "Claim rewards must be called from staker address or reward address."
        ),
        Error::POOL_MEMBER_DOES_NOT_EXIST => panic!("Pool member does not exist."),
        Error::STAKER_INACTIVE => panic!("Staker inactive."),
        Error::POOL_MEMBER_EXISTS => panic!(
            "Pool member exists, use add_to_delegation_pool instead."
        ),
        Error::UNDELEGATE_IN_PROGRESS => panic!(
            "Undelegate from pool in progress, pool member is in an exit window."
        ),
        Error::INSUFFICIENT_POOL_BALANCE => panic!("Insufficient pool balance."),
        Error::TOTAL_SUPPLY_NOT_U128 => panic!("Total supply does not fit in u128."),
        Error::POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS => panic!(
            "Claim rewards must be called from pool member address or reward address."
        ),
        Error::CALLER_IS_NOT_POOL_CONTRACT => panic!("Caller is not pool contract."),
        Error::CALLER_IS_NOT_STAKING_CONTRACT => panic!("Caller is not staking contract."),
        Error::FINAL_STAKER_INDEX_ALREADY_SET => panic!("Final staker index already set."),
        Error::MISSING_UNDELEGATE_INTENT => panic!("Undelegate intent is missing."),
        Error::CALLER_CANNOT_ADD_TO_POOL => panic!(
            "Caller address should be pool member address or reward address."
        ),
        Error::REWARD_ADDRESS_MISMATCH => panic!("Reward address mismatch."),
        Error::MISSING_POOL_CONTRACT => panic!("Staker does not have a pool contract."),
        Error::UNAUTHORIZED_MESSAGE_SENDER => panic!("Unauthorized message sender."),
        Error::SWITCH_POOL_DATA_DESERIALIZATION_FAILED => panic!(
            "Switch pool data deserialization failed."
        ),
        Error::DELEGATION_POOL_MISMATCH => panic!(
            "to_pool is not the delegation pool contract for to_staker."
        ),
        Error::GLOBAL_INDEX_DIFF_NOT_U64 => panic!("Global index diff does not fit in u64."),
        Error::GLOBAL_INDEX_DIFF_COMPUTATION_OVERFLOW => panic!(
            "Overflow during computation global index diff."
        ),
        Error::UNEXPECTED_BALANCE => panic!("Unexpected balance."),
        Error::CANNOT_INCREASE_COMMISSION => panic!("Commission cannot be increased."),
        Error::STAKER_ALREADY_HAS_POOL => panic!("Staker already has a pool."),
        Error::CONTRACT_IS_PAUSED => panic!("Contract is paused."),
        Error::C_NUM_OUT_OF_RANGE => panic!(
            "C numerator is out of range, expected to be 0-{}.", C_DENOM
        ),
        Error::INSUFFICIENT_BALANCE => panic!("Insufficient ERC20 balance."),
        Error::INSUFFICIENT_ALLOWANCE => panic!("Insufficient ERC20 allowance.")
    }
}

#[inline(always)]
pub fn assert_with_err(condition: bool, error: Error) {
    if !condition {
        panic_by_err(error);
    }
}

#[generate_trait]
pub impl OptionAuxImpl<T> of OptionAuxTrait<T> {
    #[inline(always)]
    fn expect_with_err(self: Option<T>, err: Error) -> T {
        match self {
            Option::Some(x) => x,
            Option::None => panic_by_err(err),
        }
    }
}
