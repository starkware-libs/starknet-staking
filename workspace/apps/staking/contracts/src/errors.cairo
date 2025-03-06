use staking::minting_curve::errors::Error as MintingError;
use staking::pool::errors::Error as PoolError;
use staking::reward_supplier::errors::Error as RewardsSupplierError;
use staking::staking::errors::Error as StakingError;
use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum GenericError {
    Erc20Error: Erc20Error,
    StakingError: StakingError,
    PoolError: PoolError,
    MintingError: MintingError,
    RewardsSupplierError: RewardsSupplierError,
    // Shared errors
    STAKER_EXISTS,
    STAKER_NOT_EXISTS,
    OPERATIONAL_EXISTS,
    CALLER_CANNOT_INCREASE_STAKE,
    INVALID_REWARD_ADDRESS,
    INTENT_WINDOW_NOT_FINISHED,
    INVALID_COMMISSION,
    CALLER_IS_NOT_STAKING_CONTRACT,
    MESSAGES_COUNT_ISNT_U32,
    INTEREST_ISNT_INDEX_TYPE,
    REWARDS_ISNT_AMOUNT_TYPE,
    BALANCE_ISNT_AMOUNT_TYPE,
    COMMISSION_ISNT_AMOUNT_TYPE,
    AMOUNT_TOO_HIGH,
    AMOUNT_IS_ZERO,
}

impl DescribableGenericError of Describable<GenericError> {
    fn describe(self: @GenericError) -> ByteArray {
        match self {
            GenericError::Erc20Error(err) => err.describe(),
            GenericError::StakingError(err) => err.describe(),
            GenericError::PoolError(err) => err.describe(),
            GenericError::MintingError(err) => err.describe(),
            GenericError::RewardsSupplierError(err) => err.describe(),
            GenericError::STAKER_EXISTS => "Staker already exists, use increase_stake instead",
            GenericError::STAKER_NOT_EXISTS => "Staker does not exist",
            GenericError::CALLER_CANNOT_INCREASE_STAKE => "Caller address should be staker address or reward address",
            GenericError::INVALID_REWARD_ADDRESS => "Invalid reward address",
            GenericError::INTENT_WINDOW_NOT_FINISHED => "Intent window is not finished",
            GenericError::OPERATIONAL_EXISTS => "Operational address already exists",
            GenericError::INVALID_COMMISSION => "Commission can only be decreased",
            GenericError::CALLER_IS_NOT_STAKING_CONTRACT => "Caller is not staking contract",
            GenericError::MESSAGES_COUNT_ISNT_U32 => "Number of messages is too large, expected to fit in u32",
            GenericError::INTEREST_ISNT_INDEX_TYPE => "Interest is too large, expected to fit in u128",
            GenericError::REWARDS_ISNT_AMOUNT_TYPE => "Rewards is too large, expected to fit in u128",
            GenericError::BALANCE_ISNT_AMOUNT_TYPE => "Balance is too large, expected to fit in u128",
            GenericError::COMMISSION_ISNT_AMOUNT_TYPE => "Commission is too large, expected to fit in u128",
            GenericError::AMOUNT_TOO_HIGH => "Amount is too high",
            GenericError::AMOUNT_IS_ZERO => "Amount is zero",
        }
    }
}

#[derive(Drop)]
pub(crate) enum Erc20Error {
    INSUFFICIENT_BALANCE,
    INSUFFICIENT_ALLOWANCE,
}

impl DescribableErc20Error of Describable<Erc20Error> {
    fn describe(self: @Erc20Error) -> ByteArray {
        match self {
            Erc20Error::INSUFFICIENT_BALANCE => "Insufficient ERC20 balance",
            Erc20Error::INSUFFICIENT_ALLOWANCE => "Insufficient ERC20 allowance",
        }
    }
}

