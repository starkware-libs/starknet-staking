#[starknet::contract]
pub mod Staking {
    use starknet::ContractAddress;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use contracts::staking::{IStaking, StakerInfo, StakingContractInfo};
    use contracts::errors::StakerErrors;
    use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};


    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        global_index: u128,
        min_stake: u64,
        staker_address_to_staker_info: LegacyMap::<ContractAddress, StakerInfo>,
        operational_address_to_staker_address: LegacyMap::<ContractAddress, ContractAddress>,
        global_rev_share: u64,
        max_leverage: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct BalanceChanged {
        staker_address: ContractAddress,
        amount: u64
    }

    #[derive(Drop, starknet::Event)]
    struct NewPool {
        staker_address: ContractAddress,
        pooling_contract_address: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, min_stake: u64, max_leverage: u64) {
        self.min_stake.write(min_stake);
        self.max_leverage.write(max_leverage);
    }

    #[abi(embed_v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            staker_address: ContractAddress,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u64,
            pooling_enabled: bool
        ) -> bool {
            true
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u64
        ) -> u64 {
            0
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u64 {
            0
        }

        fn unstake_intent(ref self: ContractState, staker_address: ContractAddress) -> felt252 {
            0
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u64 {
            0
        }

        fn add_to_pool(
            ref self: ContractState, staker_address: ContractAddress, amount: u64
        ) -> u64 {
            0
        }

        fn remove_from_pool_intent(
            ref self: ContractState, staker_address: ContractAddress, amount: u64
        ) -> felt252 {
            0
        }

        fn remove_from_pool_action(
            ref self: ContractState, staker_address: ContractAddress
        ) -> u64 {
            0
        }

        fn switch_pool(
            ref self: ContractState,
            from_staker_address: ContractAddress,
            to_staker_address: ContractAddress,
            pool_address: ContractAddress,
            amount: u64,
            data: ByteArray
        ) -> bool {
            true
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            true
        }

        fn set_open_for_pooling(ref self: ContractState) -> ContractAddress {
            Default::default()
        }

        fn state_of(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            let staker_info = self.staker_address_to_staker_info.read(staker_address);
            assert(staker_info != Default::default(), StakerErrors::STAKER_DOES_NOT_EXISTS);
            staker_info
        }

        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            StakingContractInfo {
                min_stake: self.min_stake.read(), max_leverage: self.max_leverage.read()
            }
        }
    }


    /// Calculates the rewards for a given staker
    /// 
    /// The caller for this function should validate that the staker exists in the storage.
    /// 
    /// rewards formula:
    /// $$ interest = (global\_index-self\_index) $$
    /// 
    /// single staker:
    /// $$ rewards = staker\_amount\_own * interest $$
    /// 
    /// staker with pool:
    /// $$ rewards = staker\_amount\_own * interest + staker\_amount\_pool * interest * global\_rev\_share $$
    /// 
    #[generate_trait]
    impl InternalStakingFunctions of InternalStakingFunctionsTrait {
        fn calculate_rewards(
            ref self: ContractState, staker_address: ContractAddress, ref staker_info: StakerInfo
        ) -> () {
            if (staker_info.unstake_time.is_some()) {
                return ();
            }
            let interest: u64 = (self.global_index.read() - staker_info.index).try_into().unwrap();
            let mut own_rewards = staker_info.amount_own * interest;
            if (staker_info.pooling_contract.is_some()) {
                let mut pooled_rewards = staker_info.amount_pool * interest;
                let rev_share = pooled_rewards * self.global_rev_share.read();
                own_rewards += rev_share;
                pooled_rewards -= rev_share;
                staker_info.unclaimed_rewards_pool += pooled_rewards;
            }
            staker_info.unclaimed_rewards_own += own_rewards;
            staker_info.index = self.global_index.read();
            self.staker_address_to_staker_info.write(staker_address, staker_info);
        }
    }
}
