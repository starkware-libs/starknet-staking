/// An External Initializer Contract to upgrade a pool contract.
#[starknet::contract]
mod PoolEIC {
    use core::num::traits::Zero;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use staking::constants::STRK_TOKEN_ADDRESS;
    use staking::pool::pool::Pool::STRK_CONFIG;
    use staking::types::Amount;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starkware_utils::components::replaceability::interface::IEICInitializable;

    #[storage]
    struct Storage {
        // --- These field exists only for pools that were created after V2 (BTC). ---
        /// Minimum amount of delegation required for rewards.
        /// Used to avoid overflow in the rewards calculation.
        min_delegation_for_rewards: Amount,
        /// Staking rewards base value.
        /// Used in rewards calculation: $$ rewards = amount * interest / base_value $$,
        /// Where `interest` scales with `base_value`.
        staking_rewards_base_value: Amount,
        // ---------------------------------------------------------------------------
        /// Dispatcher for the token contract.
        token_dispatcher: IERC20Dispatcher,
    }

    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 0, 'EXPECTED_DATA_LENGTH_0');
            if self.token_dispatcher.contract_address.read() != STRK_TOKEN_ADDRESS {
                assert!(self.min_delegation_for_rewards.read().is_non_zero());
                assert!(self.staking_rewards_base_value.read().is_non_zero());
                return;
            }
            let min_delegation_for_rewards = self.min_delegation_for_rewards.read();
            let staking_rewards_base_value = self.staking_rewards_base_value.read();
            assert!(
                min_delegation_for_rewards.is_zero() == staking_rewards_base_value.is_zero(),
                "Invalid values for min_delegation_for_rewards and staking_rewards_base_value",
            );
            // Write STRK values for pools that were created before V2.
            if min_delegation_for_rewards.is_zero() && staking_rewards_base_value.is_zero() {
                self.min_delegation_for_rewards.write(STRK_CONFIG.min_for_rewards);
                self.staking_rewards_base_value.write(STRK_CONFIG.base_value);
            }
        }
    }
}
