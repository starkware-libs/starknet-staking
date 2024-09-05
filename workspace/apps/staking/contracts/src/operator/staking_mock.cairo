#[starknet::contract]
pub mod StakingForOperatorMock {
    use contracts::staking::{IStaking, StakerInfo, StakingContractInfo};
    use starknet::{ContractAddress, get_execution_info, contract_address_const};
    use starknet::class_hash::class_hash_const;

    #[storage]
    struct Storage {
        caller_address: ContractAddress,
        account_contract_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[constructor]
    pub fn constructor(ref self: ContractState,) {}

    // this impl returns dummy values for all functions
    // for contract address and class hash we can't use test_utils
    // since this is inside of a contract and we can't mark the contract
    // as #[cfg(test)].
    #[abi(embed_v0)]
    impl StakingMockImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u128,
            pool_enabled: bool,
            commission: u16,
        ) -> bool {
            self.assert_execution_context();
            true
        }
        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            self.assert_execution_context();
            0
        }
        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            self.assert_execution_context();
            0
        }
        fn unstake_intent(ref self: ContractState) -> u64 {
            self.assert_execution_context();
            0
        }
        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            self.assert_execution_context();
            0
        }
        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            self.assert_execution_context();
            true
        }
        fn set_open_for_delegation(ref self: ContractState, commission: u16) -> ContractAddress {
            self.assert_execution_context();
            contract_address_const::<'DUMMY_ADDRESS'>()
        }
        fn state_of(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            self.assert_execution_context();
            StakerInfo {
                reward_address: contract_address_const::<'DUMMY_ADDRESS'>(),
                operational_address: contract_address_const::<'DUMMY_ADDRESS'>(),
                unstake_time: Option::None,
                amount_own: 0,
                index: 0,
                unclaimed_rewards_own: 0,
                pool_info: Option::None,
            }
        }
        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            self.assert_execution_context();
            StakingContractInfo {
                min_stake: 0,
                token_address: contract_address_const::<'DUMMY_ADDRESS'>(),
                global_index: 0,
                pool_contract_class_hash: class_hash_const::<'DUMMY'>(),
                reward_supplier: contract_address_const::<'DUMMY_ADDRESS'>(),
                exit_wait_window: 0,
            }
        }
        fn get_total_stake(self: @ContractState) -> u128 {
            self.assert_execution_context();
            0
        }
        fn update_global_index_if_needed(ref self: ContractState) -> bool {
            self.assert_execution_context();
            true
        }
        fn change_operational_address(
            ref self: ContractState, operational_address: ContractAddress
        ) -> bool {
            self.assert_execution_context();
            true
        }
        // fn update_commission(ref self: ContractState, commission: u16) -> bool {
        //     self.assert_execution_context();
        //     true
        // }
        fn is_paused(self: @ContractState) -> bool {
            self.assert_execution_context();
            false
        }
    }

    #[starknet::interface]
    pub trait IStakingMockSetter<TContractState> {
        fn set_addresses(
            ref self: TContractState,
            caller_address: ContractAddress,
            account_contract_address: ContractAddress
        );
    }

    #[abi(embed_v0)]
    impl StakingMockSetterImpl of IStakingMockSetter<ContractState> {
        fn set_addresses(
            ref self: ContractState,
            caller_address: ContractAddress,
            account_contract_address: ContractAddress
        ) {
            self.caller_address.write(caller_address);
            self.account_contract_address.write(account_contract_address);
        }
    }

    #[generate_trait]
    pub impl InternalStakingMockFunctions of InternalStakingMockFunctionsTrait {
        fn assert_execution_context(self: @ContractState) {
            let exec_info = get_execution_info();
            assert!(
                exec_info.tx_info.account_contract_address == self.account_contract_address.read(),
                "account_contract_address: {:?}, self.account_contract_address.read(): {:?}",
                exec_info.tx_info.account_contract_address,
                self.account_contract_address.read()
            );
            assert!(
                exec_info.caller_address == self.caller_address.read(),
                "caller_address: {:?}, self.caller_address.read(): {:?}",
                exec_info.caller_address,
                self.caller_address.read()
            );
        }
    }
}
