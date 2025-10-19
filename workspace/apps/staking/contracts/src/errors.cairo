use staking::minting_curve::errors::Error as MintingError;
use staking::pool::errors::Error as PoolError;
use staking::reward_supplier::errors::Error as RewardsSupplierError;
use staking::staking::errors::Error as StakingError;
use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub enum GenericError {
    Erc20Error: Erc20Error,
    StakingError: StakingError,
    PoolError: PoolError,
    MintingError: MintingError,
    RewardsSupplierError: RewardsSupplierError,
    // Shared errors
    INTENT_WINDOW_NOT_FINISHED,
    CALLER_IS_NOT_STAKING_CONTRACT,
    AMOUNT_TOO_HIGH,
    AMOUNT_IS_ZERO,
    ZERO_CLASS_HASH,
    ZERO_ADDRESS,
    REWARD_ADDRESS_IS_TOKEN,
    INVALID_TOKEN_DECIMALS,
    MISSING_UNDELEGATE_INTENT,
}

impl DescribableGenericError of Describable<GenericError> {
    fn describe(self: @GenericError) -> ByteArray {
        match self {
            GenericError::Erc20Error(err) => err.describe(),
            GenericError::StakingError(err) => err.describe(),
            GenericError::PoolError(err) => err.describe(),
            GenericError::MintingError(err) => err.describe(),
            GenericError::RewardsSupplierError(err) => err.describe(),
            GenericError::INTENT_WINDOW_NOT_FINISHED => "Intent window is not finished",
            GenericError::CALLER_IS_NOT_STAKING_CONTRACT => "Caller is not staking contract",
            GenericError::AMOUNT_TOO_HIGH => "Amount is too high",
            GenericError::AMOUNT_IS_ZERO => "Amount is zero",
            GenericError::ZERO_CLASS_HASH => "Class hash is zero",
            GenericError::ZERO_ADDRESS => "Address is zero",
            GenericError::REWARD_ADDRESS_IS_TOKEN => "Reward address is a token address",
            GenericError::INVALID_TOKEN_DECIMALS => "Invalid token decimals",
            GenericError::MISSING_UNDELEGATE_INTENT => "Undelegate intent is missing",
        }
    }
}

#[derive(Drop)]
pub(crate) enum InternalError {
    INVALID_EPOCH_IN_TRACE,
    REWARDS_COMPUTATION_OVERFLOW,
    BALANCE_ISNT_AMOUNT_TYPE,
    COMMISSION_ISNT_AMOUNT_TYPE,
    INVALID_LAST_EPOCH,
    INVALID_SECOND_LAST_EPOCH,
    INVALID_THIRD_LAST,
    TOKEN_IS_ZERO_ADDRESS,
    POOL_BALANCE_NOT_ZERO,
    UNEXPECTED_INTERNAL_MEMBER_INFO_VERSION,
    INVALID_REWARDS_TRACE_IDX,
}

impl DescribableInternalError of Describable<InternalError> {
    fn describe(self: @InternalError) -> ByteArray {
        match self {
            InternalError::INVALID_EPOCH_IN_TRACE => "Invalid epoch in trace",
            InternalError::REWARDS_COMPUTATION_OVERFLOW => "Overflow during computation rewards",
            InternalError::BALANCE_ISNT_AMOUNT_TYPE => "Balance is too large, expected to fit in u128",
            InternalError::COMMISSION_ISNT_AMOUNT_TYPE => "Commission is too large, expected to fit in u128",
            InternalError::INVALID_LAST_EPOCH => "Invalid last epoch",
            InternalError::INVALID_SECOND_LAST_EPOCH => "Invalid second last epoch",
            InternalError::INVALID_THIRD_LAST => "Invalid third last epoch, must be lower than or equal to current epoch",
            InternalError::TOKEN_IS_ZERO_ADDRESS => "Zero address token is not allowed",
            InternalError::POOL_BALANCE_NOT_ZERO => "Staker has no pool, but `pool_amount` is not zero",
            InternalError::UNEXPECTED_INTERNAL_MEMBER_INFO_VERSION => "Unexpected VInternalPoolMemberInfo version",
            InternalError::INVALID_REWARDS_TRACE_IDX => "Invalid cumulative rewards trace idx",
        }
    }
}
#[derive(Drop)]
pub enum Erc20Error {
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

