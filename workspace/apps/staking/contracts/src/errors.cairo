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
    INTENT_WINDOW_NOT_FINISHED,
    INVALID_COMMISSION,
    INVALID_COMMISSION_WITH_COMMITMENT,
    COMMISSION_COMMITMENT_EXPIRED,
    INVALID_SAME_COMMISSION,
    INVALID_EPOCH,
    CALLER_IS_NOT_STAKING_CONTRACT,
    REWARDS_ISNT_AMOUNT_TYPE,
    BALANCE_ISNT_AMOUNT_TYPE,
    COMMISSION_ISNT_AMOUNT_TYPE,
    AMOUNT_TOO_HIGH,
    AMOUNT_IS_ZERO,
    INVALID_THIRD_LAST,
    ZERO_CLASS_HASH,
    ZERO_ADDRESS,
    REWARD_ADDRESS_IS_TOKEN,
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
            GenericError::INTENT_WINDOW_NOT_FINISHED => "Intent window is not finished",
            GenericError::OPERATIONAL_EXISTS => "Operational address already exists",
            GenericError::INVALID_COMMISSION => "Commission can only be decreased",
            GenericError::INVALID_COMMISSION_WITH_COMMITMENT => "Commission can be set below the maximum specified in the commission commitment",
            GenericError::INVALID_SAME_COMMISSION => "  Commission can't be set to the same value",
            GenericError::INVALID_EPOCH => "Invalid epoch",
            GenericError::COMMISSION_COMMITMENT_EXPIRED => "Commission commitment has expired, can only decrease or set a new commitment",
            GenericError::CALLER_IS_NOT_STAKING_CONTRACT => "Caller is not staking contract",
            GenericError::REWARDS_ISNT_AMOUNT_TYPE => "Rewards is too large, expected to fit in u128",
            GenericError::BALANCE_ISNT_AMOUNT_TYPE => "Balance is too large, expected to fit in u128",
            GenericError::COMMISSION_ISNT_AMOUNT_TYPE => "Commission is too large, expected to fit in u128",
            GenericError::AMOUNT_TOO_HIGH => "Amount is too high",
            GenericError::AMOUNT_IS_ZERO => "Amount is zero",
            GenericError::INVALID_THIRD_LAST => "Invalid third last epoch, must be lower than or equal to current epoch",
            GenericError::ZERO_CLASS_HASH => "Class hash is zero",
            GenericError::ZERO_ADDRESS => "Address is zero",
            GenericError::REWARD_ADDRESS_IS_TOKEN => "Reward address is a token address",
        }
    }
}

#[derive(Drop)]
pub(crate) enum Erc20Error {
    INSUFFICIENT_BALANCE,
    INSUFFICIENT_ALLOWANCE,
    TRANSFER_FAILED,
}

impl DescribableErc20Error of Describable<Erc20Error> {
    fn describe(self: @Erc20Error) -> ByteArray {
        match self {
            Erc20Error::INSUFFICIENT_BALANCE => "Insufficient ERC20 balance",
            Erc20Error::INSUFFICIENT_ALLOWANCE => "Insufficient ERC20 allowance",
            Erc20Error::TRANSFER_FAILED => "ERC20 transfer failed",
        }
    }
}

