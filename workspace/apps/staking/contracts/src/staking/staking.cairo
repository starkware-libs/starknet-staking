#[starknet::contract]
pub mod Staking {
    use core::starknet::event::EventEmitter;
    use core::option::OptionTrait;
    use core::num::traits::zero::Zero;
    use contracts::{
        constants::{BASE_VALUE, EXIT_WAITING_WINDOW},
        errors::{Error, panic_by_err, assert_with_err, OptionAuxTrait},
        staking::{IStaking, StakerInfo, StakerInfoTrait, StakingContractInfo},
        utils::{
            u128_mul_wide_and_div_unsafe, deploy_delegation_pool_contract, compute_commission,
            compute_rewards, ceil_of_division
        },
    };
    use contracts::staking::objects::{
        UndelegateIntentValueZero, UndelegateIntentKey, UndelegateIntentValue
    };
    use contracts::staking::Events;
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
    use openzeppelin::{
        access::accesscontrol::AccessControlComponent, introspection::src5::SRC5Component
    };
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use starknet::get_block_timestamp;
    use starknet::class_hash::ClassHash;
    use starknet::syscalls::deploy_syscall;
    use contracts::pooling::interface::{IPoolingDispatcherTrait, IPoolingDispatcher};

    // TODO: Decide if MIN_INCREASE_STAKE is needed (if needed then decide on a value). 
    pub const MIN_INCREASE_STAKE: u128 = 10;
    pub const REV_SHARE_DENOMINATOR: u16 = 10000;

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
        staker_info: LegacyMap::<ContractAddress, Option<StakerInfo>>,
        operational_address_to_staker_address: LegacyMap::<ContractAddress, ContractAddress>,
        token_address: ContractAddress,
        total_stake: u128,
        pool_contract_class_hash: ClassHash,
        pool_exit_intents: LegacyMap::<UndelegateIntentKey, UndelegateIntentValue>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event,
        balance_changed: Events::BalanceChanged,
        new_delegation_pool: Events::NewDelegationPool,
        staker_exit_intent: Events::StakerExitIntent,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        min_stake: u128,
        pool_contract_class_hash: ClassHash,
    ) {
        self.token_address.write(token_address);
        self.min_stake.write(min_stake);
        self.global_index.write(BASE_VALUE);
        self.pool_contract_class_hash.write(pool_contract_class_hash);
    }

    #[abi(embed_v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u128,
            pooling_enabled: bool,
            rev_share: u16,
        ) -> bool {
            let staker_address = get_caller_address();
            assert_with_err(self.staker_info.read(staker_address).is_none(), Error::STAKER_EXISTS);
            assert_with_err(
                self.operational_address_to_staker_address.read(operational_address).is_zero(),
                Error::OPERATIONAL_EXISTS
            );
            assert_with_err(amount >= self.min_stake.read(), Error::AMOUNT_LESS_THAN_MIN_STAKE);
            assert_with_err(rev_share <= REV_SHARE_DENOMINATOR, Error::REV_SHARE_OUT_OF_RANGE);
            let staking_contract = get_contract_address();
            let token_address = self.token_address.read();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher
                .transfer_from(
                    sender: staker_address, recipient: staking_contract, amount: amount.into()
                );
            let pooling_contract = self
                .deploy_delegation_pool_contract_if_needed(
                    :staker_address, :staking_contract, :token_address, :pooling_enabled, :rev_share
                );
            self
                .staker_info
                .write(
                    staker_address,
                    Option::Some(
                        StakerInfo {
                            reward_address,
                            operational_address,
                            pooling_contract,
                            unstake_time: Option::None,
                            amount_own: amount,
                            amount_pool: 0,
                            index: self.global_index.read(),
                            unclaimed_rewards_own: 0,
                            unclaimed_rewards_pool: 0,
                            rev_share,
                        }
                    )
                );
            self.operational_address_to_staker_address.write(operational_address, staker_address);
            self.total_stake.write(self.get_total_stake() + amount);
            self.emit(Events::BalanceChanged { staker_address, amount });
            true
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            let mut staker_info = self.get_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            assert_with_err(
                amount >= MIN_INCREASE_STAKE, Error::AMOUNT_LESS_THAN_MIN_INCREASE_STAKE
            );
            let caller_address = get_caller_address();
            assert_with_err(
                caller_address == staker_address || caller_address == staker_info.reward_address,
                Error::CALLER_CANNOT_INCREASE_STAKE
            );
            let staking_contract_address = get_contract_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer_from(
                    sender: caller_address,
                    recipient: staking_contract_address,
                    amount: amount.into()
                );
            self.calculate_rewards(ref :staker_info);
            staker_info.amount_own += amount;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            self.total_stake.write(self.get_total_stake() + amount);
            // TODO: It is not clear from spec, but amount in the event may also include pooling.
            //       If so, this should be updated.
            self.emit(Events::BalanceChanged { staker_address, amount: staker_info.amount_own });
            staker_info.amount_own
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            let mut staker_info = self.get_staker_info(:staker_address);
            let caller_address = get_caller_address();
            assert_with_err(
                caller_address == staker_address || caller_address == staker_info.reward_address,
                Error::CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
            );
            self.calculate_rewards(ref :staker_info);
            let amount = staker_info.unclaimed_rewards_own;

            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher.transfer(recipient: staker_info.reward_address, amount: amount.into());

            staker_info.unclaimed_rewards_own = 0;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            amount
        }

        fn unstake_intent(ref self: ContractState) -> u64 {
            let staker_address = get_caller_address();
            let mut staker_info = self.get_staker_info(:staker_address);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            self.calculate_rewards(ref :staker_info);
            let current_time = get_block_timestamp();
            let unstake_time = current_time + EXIT_WAITING_WINDOW;
            staker_info.unstake_time = Option::Some(unstake_time);
            self.staker_info.write(staker_address, Option::Some(staker_info));
            self.emit(Events::StakerExitIntent { staker_address, exit_at: unstake_time });
            unstake_time
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            let staker_info = self.get_staker_info(:staker_address);
            let unstake_time = staker_info
                .unstake_time
                .expect_with_err(Error::MISSING_UNSTAKE_INTENT);
            assert_with_err(
                get_block_timestamp() >= unstake_time, Error::INTENT_WINDOW_NOT_FINISHED
            );
            // Claim rewards.
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer(
                    recipient: staker_info.reward_address,
                    amount: staker_info.unclaimed_rewards_own.into()
                );
            // Transfer to staker.
            let staker_amount = staker_info.amount_own;
            erc20_dispatcher.transfer(recipient: staker_address, amount: staker_amount.into());

            self.transfer_to_pool_when_unstake(:staker_info);
            self.remove_staker(:staker_address, :staker_info);
            staker_amount
        }
        // TODO: It is not clear from spec, but amount in the event may also include pooling.
        //       If so, should this be 0 or pooling?
        // self.emit(Events::BalanceChanged { staker_address, 0 });

        fn add_to_delegation_pool(
            ref self: ContractState, pooled_staker: ContractAddress, amount: u128
        ) -> (u128, u64) {
            let mut staker_info = self.get_staker_info(staker_address: pooled_staker);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            let pool_contract = staker_info
                .pooling_contract
                .expect_with_err(Error::POOL_ADDRESS_DOES_NOT_EXIST);
            assert_with_err(
                pool_contract == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );

            self.calculate_rewards(ref :staker_info);
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer_from(
                    sender: pool_contract, recipient: get_contract_address(), amount: amount.into()
                );
            staker_info.amount_pool += amount;
            self.staker_info.write(pooled_staker, Option::Some(staker_info));
            self.add_to_total_stake(:amount);
            (staker_info.amount_pool, staker_info.index)
        }

        fn remove_from_delegation_pool_intent(
            ref self: ContractState,
            staker_address: ContractAddress,
            identifier: felt252,
            amount: u128,
        ) -> u64 {
            let mut staker_info = self.get_staker_info(:staker_address);
            let pool_contract = staker_info
                .pooling_contract
                .expect_with_err(Error::MISSING_POOL_CONTRACT);
            assert_with_err(
                pool_contract == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );
            assert_with_err(staker_info.amount_pool >= amount, Error::INSUFFICIENT_POOL_BALANCE);
            self.calculate_rewards(ref :staker_info);
            staker_info.amount_pool -= amount;
            self.remove_from_total_stake(:amount);
            self.staker_info.write(staker_address, Option::Some(staker_info));
            let unpool_time = staker_info.compute_unpool_time();
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let pool_exit_entry = UndelegateIntentValue { unpool_time, amount };
            self.pool_exit_intents.write(undelegate_intent_key, pool_exit_entry);
            unpool_time
        }

        fn remove_from_delegation_pool_action(
            ref self: ContractState, identifier: felt252
        ) -> u128 {
            let pool_contract = get_caller_address();
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let undelegate_intent = self.pool_exit_intents.read(undelegate_intent_key);
            assert_with_err(
                get_block_timestamp() >= undelegate_intent.unpool_time,
                Error::INTENT_WINDOW_NOT_FINISHED
            );
            if undelegate_intent.amount > 0 {
                let erc20_dispatcher = IERC20Dispatcher {
                    contract_address: self.token_address.read()
                };
                erc20_dispatcher
                    .transfer(recipient: pool_contract, amount: undelegate_intent.amount.into());
            // TODO: Emit event.
            }
            self.clear_undelegate_intent(:undelegate_intent_key);
            undelegate_intent.amount
        }

        fn switch_staking_delegation_pool(
            ref self: ContractState,
            to_staker: ContractAddress,
            to_pool: ContractAddress,
            amount: u128,
            data: Span<felt252>,
            identifier: felt252
        ) -> bool {
            assert_with_err(amount.is_non_zero(), Error::AMOUNT_IS_ZERO);
            let pool_contract = get_caller_address();
            let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
            let mut undelegate_intent_value = self.pool_exit_intents.read(undelegate_intent_key);
            assert_with_err(
                undelegate_intent_value.is_non_zero(), Error::MISSING_UNDELEGATE_INTENT
            );
            assert_with_err(undelegate_intent_value.amount >= amount, Error::AMOUNT_TOO_HIGH);
            let mut to_staker_info = self.get_staker_info(staker_address: to_staker);
            assert_with_err(to_staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            let to_staker_pool_contract = to_staker_info
                .pooling_contract
                .expect_with_err(Error::MISSING_POOL_CONTRACT);
            assert_with_err(to_pool == to_staker_pool_contract, Error::MISSMATCHED_DELEGATION_POOL);

            self.calculate_rewards(ref staker_info: to_staker_info);
            to_staker_info.amount_pool += amount;
            self.staker_info.write(to_staker, Option::Some(to_staker_info));
            self.add_to_total_stake(:amount);

            undelegate_intent_value.amount -= amount;
            if undelegate_intent_value.amount.is_zero() {
                self.clear_undelegate_intent(:undelegate_intent_key);
            } else {
                self.pool_exit_intents.write(undelegate_intent_key, undelegate_intent_value);
            }
            let to_pool_dispatcher = IPoolingDispatcher { contract_address: to_pool };
            to_pool_dispatcher
                .enter_delegation_pool_from_staking_contract(
                    :amount, index: to_staker_info.index, :data
                );
            true
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            let staker_address = get_caller_address();
            let mut staker_info = self.get_staker_info(:staker_address);
            staker_info.reward_address = reward_address;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            true
        }

        fn set_open_for_delegation(ref self: ContractState) -> ContractAddress {
            Zero::zero()
        }

        fn state_of(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            self.get_staker_info(:staker_address)
        }

        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            StakingContractInfo {
                min_stake: self.min_stake.read(),
                token_address: self.token_address.read(),
                global_index: self.global_index.read(),
            }
        }

        fn claim_delegation_pool_rewards(
            ref self: ContractState, staker_address: ContractAddress
        ) -> u64 {
            let mut staker_info = self.get_staker_info(:staker_address);
            let pool_address = staker_info
                .pooling_contract
                .expect_with_err(Error::POOL_ADDRESS_DOES_NOT_EXIST);
            assert_with_err(
                pool_address == get_caller_address(), Error::CALLER_IS_NOT_POOL_CONTRACT
            );
            self.calculate_rewards(ref :staker_info);
            // Calculate rewards updated the index in staker_info.
            let updated_index = staker_info.index;
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer(
                    recipient: pool_address, amount: staker_info.unclaimed_rewards_pool.into()
                );

            staker_info.unclaimed_rewards_pool = 0;
            self.staker_info.write(staker_address, Option::Some(staker_info));
            updated_index
        }

        fn get_total_stake(self: @ContractState) -> u128 {
            self.total_stake.read()
        }
    }

    #[generate_trait]
    pub impl InternalStakingFunctions of InternalStakingFunctionsTrait {
        fn clear_undelegate_intent(
            ref self: ContractState, undelegate_intent_key: UndelegateIntentKey
        ) {
            self.pool_exit_intents.write(undelegate_intent_key, Zero::zero());
        }

        fn get_staker_info(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            self.staker_info.read(staker_address).expect_with_err(Error::STAKER_NOT_EXISTS)
        }

        fn calculate_and_update_pool_rewards(
            ref self: ContractState, interest: u64, ref staker_info: StakerInfo
        ) {
            if (staker_info.amount_pool > 0) {
                let mut rewards = compute_rewards(amount: staker_info.amount_pool, :interest);
                let commission = compute_commission(:rewards, rev_share: staker_info.rev_share);
                staker_info.unclaimed_rewards_own += commission;
                rewards -= commission;
                staker_info.unclaimed_rewards_pool += rewards;
            }
        }

        fn transfer_to_pool_when_unstake(ref self: ContractState, staker_info: StakerInfo) {
            if let Option::Some(pooling_contract) = staker_info.pooling_contract {
                let erc20_dispatcher = IERC20Dispatcher {
                    contract_address: self.token_address.read()
                };
                let pool_amount = staker_info.amount_pool + staker_info.unclaimed_rewards_pool;
                erc20_dispatcher.transfer(recipient: pooling_contract, amount: pool_amount.into());
                let pooling_dispatcher = IPoolingDispatcher { contract_address: pooling_contract };
                pooling_dispatcher.set_final_staker_index(final_staker_index: staker_info.index);
            }
        }

        fn remove_staker(
            ref self: ContractState, staker_address: ContractAddress, staker_info: StakerInfo
        ) {
            self.staker_info.write(staker_address, Option::None);
            self
                .operational_address_to_staker_address
                .write(staker_info.operational_address, Zero::zero());
        }

        /// Calculates the rewards for a given staker.
        /// 
        /// The caller for this function should validate that the staker exists.
        /// 
        /// rewards formula:
        /// $$ interest = (global\_index-self\_index) $$
        /// 
        /// single staker:
        /// $$ rewards = staker\_amount\_own * interest $$
        /// 
        /// staker with pool:
        /// $$ rewards = interest * (staker\_amount\_own + staker\_amount\_pool * rev\_share) $$
        /// 
        /// Fields that are changed in staker_info:
        /// - unclaimed_rewards_own
        /// - unclaimed_rewards_pool
        /// - index
        fn calculate_rewards(ref self: ContractState, ref staker_info: StakerInfo) -> bool {
            if (staker_info.unstake_time.is_some()) {
                return false;
            }
            let global_index = self.global_index.read();
            let interest = global_index - staker_info.index;
            staker_info.index = global_index;

            let staker_rewards = compute_rewards(amount: staker_info.amount_own, :interest);
            staker_info.unclaimed_rewards_own += staker_rewards;
            self.calculate_and_update_pool_rewards(:interest, ref :staker_info);
            true
        }

        fn deploy_delegation_pool_contract_if_needed(
            self: @ContractState,
            staker_address: ContractAddress,
            staking_contract: ContractAddress,
            token_address: ContractAddress,
            pooling_enabled: bool,
            rev_share: u16,
        ) -> Option<ContractAddress> {
            if !pooling_enabled {
                return Option::None;
            }
            let class_hash = self.pool_contract_class_hash.read();
            let contract_address_salt: felt252 = get_block_timestamp().into();
            deploy_delegation_pool_contract(
                :class_hash,
                :contract_address_salt,
                :staker_address,
                :staking_contract,
                :token_address,
                :rev_share
            )
        }

        fn add_to_total_stake(ref self: ContractState, amount: u128) {
            self.total_stake.write(self.total_stake.read() + amount);
        }

        fn remove_from_total_stake(ref self: ContractState, amount: u128) {
            self.total_stake.write(self.total_stake.read() - amount);
        }
    }
}
