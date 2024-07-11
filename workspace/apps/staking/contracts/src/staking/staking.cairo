#[starknet::contract]
pub mod Staking {
    use contracts::{
        BASE_VALUE, errors::{Error, panic_by_err},
        staking::{IStaking, StakerInfo, StakingContractInfo}, utils::{u128_mul_wide_and_div_unsafe},
    };
    use starknet::ContractAddress;
    use openzeppelin::{
        access::accesscontrol::AccessControlComponent, introspection::src5::SRC5Component
    };
    use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};

    // TODO(Nir, 01/08/2024): Add the correct value and type for the global rev share
    pub const GLOBAL_REV_SHARE: u8 = 0;
    pub const GLOBAL_REV_SHARE_DENOMINATOR: u8 = 100;


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
        global_index: u64,
        min_stake: u128,
        staker_address_to_info: LegacyMap::<ContractAddress, StakerInfo>,
        operational_address_to_staker_address: LegacyMap::<ContractAddress, ContractAddress>,
        global_rev_share: u8,
        max_leverage: u64,
        token_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BalanceChanged {
        staker_address: ContractAddress,
        amount: u128
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
    pub fn constructor(
        ref self: ContractState, token_address: ContractAddress, min_stake: u128, max_leverage: u64
    ) {
        self.token_address.write(token_address);
        self.min_stake.write(min_stake);
        self.max_leverage.write(max_leverage);
        self.global_index.write(BASE_VALUE);
    }

    #[abi(embed_v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u128,
            pooling_enabled: bool
        ) -> bool {
            true
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            0
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            0
        }

        fn unstake_intent(ref self: ContractState) -> felt252 {
            0
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            0
        }

        fn add_to_delegation_pool(
            ref self: ContractState, pooled_staker: ContractAddress, amount: u128
        ) -> u128 {
            0
        }

        fn remove_from_delegation_pool_intent(
            ref self: ContractState,
            staker_address: ContractAddress,
            amount: u128,
            identifier: Span<felt252>
        ) -> felt252 {
            0
        }

        fn remove_from_delegation_pool_action(
            ref self: ContractState, staker_address: ContractAddress, identifier: Span<felt252>
        ) -> u128 {
            0
        }

        fn switch_staking_delegation_pool(
            ref self: ContractState,
            from_staker_address: ContractAddress,
            to_staker_address: ContractAddress,
            to_pool_address: ContractAddress,
            amount: u128,
            data: Span<felt252>
        ) -> bool {
            true
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            true
        }

        fn set_open_for_delegation(ref self: ContractState) -> ContractAddress {
            Default::default()
        }

        fn state_of(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            let staker_info = self.staker_address_to_info.read(staker_address);
            if (staker_info == Default::default()) {
                panic_by_err(Error::STAKER_DOES_NOT_EXIST)
            }
            staker_info
        }

        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            StakingContractInfo {
                min_stake: self.min_stake.read(),
                max_leverage: self.max_leverage.read(),
                token_address: self.token_address.read(),
                global_index: self.global_index.read(),
                global_rev_share: GLOBAL_REV_SHARE
            }
        }
    }

    #[generate_trait]
    pub impl InternalStakingFunctions of InternalStakingFunctionsTrait {
        /// Calculates the rewards for a given staker.
        /// 
        /// The caller for this function should validate that the staker exists in the storage
        /// 
        /// rewards formula:
        /// $$ interest = (global\_index-self\_index) $$
        /// 
        /// single staker:
        /// $$ rewards = staker\_amount\_own * interest $$
        /// 
        /// staker with pool:
        /// $$ rewards = staker\_amount\_own * interest + staker\_amount\_pool * interest * global\_rev\_share $$
        fn calculate_rewards(
            ref self: ContractState, staker_address: ContractAddress, ref staker_info: StakerInfo
        ) -> () {
            if (staker_info.unstake_time.is_some()) {
                return ();
            }
            let global_index = self.global_index.read();
            let interest: u64 = global_index - staker_info.index;
            let mut own_rewards = u128_mul_wide_and_div_unsafe(
                staker_info.amount_own, interest.into(), BASE_VALUE.into(), Error::REWARDS_ISNT_U128
            );
            if (staker_info.pooling_contract.is_some()) {
                // todo: see if we can do without the special mul
                let mut pooled_rewards = u128_mul_wide_and_div_unsafe(
                    staker_info.amount_pool,
                    interest.into(),
                    BASE_VALUE.into(),
                    Error::POOLED_REWARDS_ISNT_U128
                );
                let rev_share = u128_mul_wide_and_div_unsafe(
                    pooled_rewards,
                    GLOBAL_REV_SHARE.into(),
                    GLOBAL_REV_SHARE_DENOMINATOR.into(),
                    Error::REV_SHARE_ISNT_U64
                );
                own_rewards += rev_share;
                pooled_rewards -= rev_share;
                staker_info.unclaimed_rewards_pool += pooled_rewards;
            }
            staker_info.unclaimed_rewards_own += own_rewards;
            staker_info.index = global_index;
            self.staker_address_to_info.write(staker_address, staker_info);
        }
    }
}
