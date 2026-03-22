use staking::types::Amount;
use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IRewardSupplier<TContractState> {
    /// Returns ([`Amount`](staking::types::Amount), [`Amount`](staking::types::Amount)) of rewards
    /// for the current epoch, for STRK and BTC respectively (in FRI).
    /// Used for attestation rewards.
    ///
    /// #### Internal calls:
    /// - [`minting_curve::minting_curve::interface::IMintingCurve::yearly_mint`]
    /// - [`staking::staking::interface::IStaking::get_epoch_info`]
    fn calculate_current_epoch_rewards(self: @TContractState) -> (Amount, Amount);
    /// Returns ([`Amount`](staking::types::Amount), [`Amount`](staking::types::Amount)) of rewards
    /// for block in the current epoch, for STRK and BTC respectively (in FRI).
    /// Used for the consensus rewards.
    ///
    /// This function is called once per epoch. It updates `avg_block_duration` and returns (STRK,
    /// BTC) block rewards for the current epoch.
    ///
    /// #### Errors:
    /// -
    /// [`CALLER_IS_NOT_STAKING_CONTRACT`](staking::errors::GenericError::CALLER_IS_NOT_STAKING_CONTRACT)
    ///
    /// #### Access control:
    /// Only staking contract.
    ///
    /// #### Internal calls:
    /// - [`minting_curve::minting_curve::interface::IMintingCurve::yearly_mint`]
    fn update_current_epoch_block_rewards(ref self: TContractState) -> (Amount, Amount);
    /// Updates the unclaimed rewards from the staking contract.
    ///
    /// #### Emits:
    /// - [`MintRequest`](Events::MintRequest) if funds are needed.
    ///
    /// #### Errors:
    /// -
    /// [`CALLER_IS_NOT_STAKING_CONTRACT`](staking::errors::GenericError::CALLER_IS_NOT_STAKING_CONTRACT)
    ///
    /// #### Access control:
    /// Only staking contract.
    fn update_unclaimed_rewards_from_staking_contract(ref self: TContractState, rewards: Amount);
    /// Transfers the given `amount` (FRI) of rewards to the staking contract.
    ///
    /// #### Preconditions:
    /// - `reward_supplier.unclaimed_rewards >= amount`
    ///
    /// #### Errors:
    /// -
    /// [`CALLER_IS_NOT_STAKING_CONTRACT`](staking::errors::GenericError::CALLER_IS_NOT_STAKING_CONTRACT)
    /// - [`AMOUNT_TOO_HIGH`](staking::errors::GenericError::AMOUNT_TOO_HIGH)
    ///
    /// #### Access control:
    /// Only staking contract.
    fn claim_rewards(ref self: TContractState, amount: Amount);
    /// Callback function for StarkGate deposit.
    ///
    /// Notifies the contract that a transfer of `amount` from L1 via StarkGate has occurred and
    /// returns `true` upon success.
    /// This function reverts only if `amount` exceeds 2**128 FRI, which is highly unlikely.
    ///
    /// #### Errors:
    /// -
    /// [`ON_RECEIVE_NOT_FROM_STARKGATE`](staking::reward_supplier::errors::Error::ON_RECEIVE_NOT_FROM_STARKGATE)
    /// - [`UNEXPECTED_TOKEN`](staking::reward_supplier::errors::Error::UNEXPECTED_TOKEN)
    /// - [`AMOUNT_TOO_HIGH`](staking::errors::GenericError::AMOUNT_TOO_HIGH)
    ///
    /// #### Access control:
    /// Only StarkGate.
    fn on_receive(
        ref self: TContractState,
        l2_token: ContractAddress,
        amount: u256,
        depositor: EthAddress,
        message: Span<felt252>,
    ) -> bool;
    /// Returns [`RewardSupplierInfoV1`] describing the contract.
    fn contract_parameters_v1(self: @TContractState) -> RewardSupplierInfoV1;
    /// Returns the alpha parameter, as percentage, used when computing BTC rewards.
    fn get_alpha(self: @TContractState) -> u128;
    /// Returns the block duration configuration.
    fn get_block_duration_config(self: @TContractState) -> BlockDurationConfig;
}

#[starknet::interface]
pub trait IRewardSupplierConfig<TContractState> {
    /// Sets the block duration configuration.
    ///
    /// #### Preconditions:
    /// - `block_duration_config.min_block_duration > 0`
    /// - `block_duration_config.min_block_duration <= block_duration_config.max_block_duration`
    ///
    /// #### Errors:
    /// - [`ONLY_APP_GOVERNOR`](AccessErrors::ONLY_APP_GOVERNOR)
    /// -
    /// [`INVALID_MIN_MAX_BLOCK_DURATION`](staking::reward_supplier::errors::Error::INVALID_MIN_MAX_BLOCK_DURATION)
    ///
    /// #### Access control:
    /// Only app governor.
    fn set_block_duration_config(
        ref self: TContractState, block_duration_config: BlockDurationConfig,
    );
}

pub mod Events {
    use staking::types::Amount;

    #[derive(Debug, Drop, PartialEq, starknet::Event)]
    pub struct MintRequest {
        pub total_amount: Amount,
        pub num_msgs: u128,
    }
}

#[derive(Debug, Copy, Drop, Serde, PartialEq)]
pub struct RewardSupplierInfoV1 {
    pub unclaimed_rewards: Amount,
    pub l1_pending_requested_amount: Amount,
}

/// Configuration for block duration calculation.
#[derive(Debug, Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct BlockDurationConfig {
    /// Minimum block duration, in units of 1 / BLOCK_DURATION_SCALE seconds.
    pub min_block_duration: u64,
    /// Maximum block duration, in units of 1 / BLOCK_DURATION_SCALE seconds.
    pub max_block_duration: u64,
}
