use core::num::traits::Zero;
use staking::constants::STRK_IN_FRIS;
use staking::flow_test::utils::{
    Delegator, FlowTrait, RewardSupplierTrait, Staker, StakingTrait, SystemDelegatorTrait,
    SystemStakerTrait, SystemState, SystemTrait, SystemType,
};
use staking::pool::interface::PoolMemberInfo;
use staking::staking::interface::StakerInfo;
use staking::test_utils::{pool_update_rewards, staker_update_rewards};
use staking::types::Amount;
use starknet::ContractAddress;
use starkware_utils::math::abs::wide_abs_diff;
use starkware_utils::test_utils::TokenTrait;
use starkware_utils::types::time::time::Time;

/// Flow - Basic Stake:
/// Staker - Stake with pool - cover if pool_enabled=true
/// Staker increase_stake - cover if pool amount = 0 in calc_rew
/// Delegator delegate (and create) to Staker
/// Staker increase_stake - cover pool amount > 0 in calc_rew
/// Delegator increase_delegate
/// Exit and check
#[derive(Drop, Copy)]
pub(crate) struct BasicStakeFlow {}
pub(crate) impl BasicStakeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<BasicStakeFlow, TTokenState> {
    fn get_pool_address(self: BasicStakeFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: BasicStakeFlow, ref system: SystemState<TTokenState>) {}

    fn test(self: BasicStakeFlow, ref system: SystemState<TTokenState>, system_type: SystemType) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let staker = system.new_staker(amount: stake_amount * 2);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, commission: 200);
        system.advance_epoch_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount / 2);
        system.advance_epoch_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount / 2);
        system.advance_epoch_and_attest(:staker);

        system.increase_stake(:staker, amount: stake_amount / 4);
        system.advance_epoch_and_attest(:staker);

        system.increase_delegate(:delegator, :pool, amount: stake_amount / 4);
        system.advance_epoch_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount * 3 / 4);
        system.advance_epoch_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.delegator_exit_action(:delegator, :pool);
        system.staker_exit_action(:staker);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(
            system.token.balance_of(account: pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount * 2);
        assert!(system.token.balance_of(account: delegator.delegator.address) == stake_amount);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Staker exit_intent
/// Staker exit_action
/// Delegator partially exit_intent
/// Delegator exit_action
/// Delegator exit_intent
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorIntentAfterStakerActionFlow {}
pub(crate) impl DelegatorIntentAfterStakerActionFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<DelegatorIntentAfterStakerActionFlow, TTokenState> {
    fn get_pool_address(self: DelegatorIntentAfterStakerActionFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(
        ref self: DelegatorIntentAfterStakerActionFlow, ref system: SystemState<TTokenState>,
    ) {}

    fn test(
        self: DelegatorIntentAfterStakerActionFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_epoch_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount);
        system.advance_epoch_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.staker_exit_action(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount / 2);
        system.delegator_exit_action(:delegator, :pool);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount / 2);
        system.delegator_exit_action(:delegator, :pool);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(
            system.token.balance_of(account: pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount * 2);
        assert!(system.token.balance_of(account: delegator.delegator.address) == stake_amount);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow:
/// Staker - Stake without pool - cover if pool_enabled=false
/// Staker increase_stake - cover if pool amount=none in update_rewards
/// Staker claim_rewards
/// Staker set_open_for_delegation
/// Delegator delegate - cover delegating after opening an initially closed pool
/// Exit and check
#[derive(Drop, Copy)]
pub(crate) struct SetOpenForDelegationFlow {}
pub(crate) impl SetOpenForDelegationFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<SetOpenForDelegationFlow, TTokenState> {
    fn get_pool_address(self: SetOpenForDelegationFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: SetOpenForDelegationFlow, ref system: SystemState<TTokenState>) {}

    fn test(
        self: SetOpenForDelegationFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let min_stake = system.staking.get_min_stake();
        let initial_stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: initial_stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: initial_stake_amount, pool_enabled: false, :commission);
        system.advance_epoch_and_attest(:staker);

        system.increase_stake(:staker, amount: initial_stake_amount / 2);
        system.advance_epoch_and_attest(:staker);

        assert!(system.token.balance_of(account: staker.reward.address).is_zero());
        system.staker_claim_rewards(:staker);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());

        let pool = system.set_open_for_delegation(:staker, :commission);
        system.advance_epoch_and_attest(:staker);

        let delegator = system.new_delegator(amount: initial_stake_amount);
        system.delegate(:delegator, :pool, amount: initial_stake_amount / 2);
        system.advance_epoch_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.delegator_exit_intent(:delegator, :pool, amount: initial_stake_amount / 2);

        system.delegator_exit_action(:delegator, :pool);
        system.staker_exit_action(:staker);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(
            system.token.balance_of(account: pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.
        assert!(
            system.token.balance_of(account: staker.staker.address) == initial_stake_amount * 2,
        );
        assert!(
            system.token.balance_of(account: delegator.delegator.address) == initial_stake_amount,
        );
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator exit_intent partial amount
/// Delegator exit_intent with lower amount - cover lowering partial undelegate
/// Delegator exit_intent with zero amount - cover clearing an intent
/// Delegator exit_intent all amount
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorIntentFlow {}
pub(crate) impl DelegatorIntentFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<DelegatorIntentFlow, TTokenState> {
    fn get_pool_address(self: DelegatorIntentFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: DelegatorIntentFlow, ref system: SystemState<TTokenState>) {}

    fn test(
        self: DelegatorIntentFlow, ref system: SystemState<TTokenState>, system_type: SystemType,
    ) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_epoch_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegated_amount = stake_amount;
        let delegator = system.new_delegator(amount: delegated_amount);
        system.delegate(:delegator, :pool, amount: delegated_amount);
        system.advance_epoch_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 2);
        system.advance_epoch_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 4);
        system.advance_epoch_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount / 2);
        system.advance_epoch_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: Zero::zero());
        system.advance_epoch_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.advance_epoch_and_attest(:staker);
        system.delegator_exit_action(:delegator, :pool);
        system.advance_epoch_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(
            system.token.balance_of(account: pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

// Flow 8:
// Staker1 stake
// Staker2 stake
// Delegator delegate to staker1's pool
// Staker1 exit_intent
// Delegator exit_intent - get current block_timestamp as exit time
// Staker1 exit_action - cover staker action with while having a delegator in intent
// Staker1 stake (again)
// Delegator switch part of intent to staker2's pool - cover switching from a dead staker (should
// not matter he is back alive)
// Delegator exit_action in staker1's original pool - cover delegator exit action with dead staker
// Delegator claim rewards in staker2's pool - cover delegator claim rewards with dead staker
// Delegator exit_intent for remaining amount in staker1's original pool (the staker is dead there)
// Delegator exit_action in staker1's original pool - cover full delegator exit with dead staker
// Staker1 exit_intent
// Staker2 exit_intent
// Staker1 exit_action
// Staker2 exit_action
// Delegator exit_intent for full amount in staker2's pool
// Delegator exit_action for full amount in staker2's pool
#[derive(Drop, Copy)]
pub(crate) struct OperationsAfterDeadStakerFlow {}
pub(crate) impl OperationsAfterDeadStakerFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<OperationsAfterDeadStakerFlow, TTokenState> {
    fn get_pool_address(self: OperationsAfterDeadStakerFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: OperationsAfterDeadStakerFlow, ref system: SystemState<TTokenState>) {}

    fn test(
        self: OperationsAfterDeadStakerFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let delegated_amount = stake_amount;
        let staker1 = system.new_staker(amount: stake_amount);
        let staker2 = system.new_staker(amount: stake_amount);
        let delegator = system.new_delegator(amount: delegated_amount);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(staker: staker1, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_time(time: one_week);

        system.stake(staker: staker2, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_time(time: one_week);

        let staker1_pool = system.staking.get_pool(staker: staker1);
        system.delegate(:delegator, pool: staker1_pool, amount: delegated_amount);
        system.advance_time(time: one_week);

        system.staker_exit_intent(staker: staker1);
        system.advance_time(time: system.staking.get_exit_wait_window());

        // After the following, delegator has 1/2 in staker1, and 1/2 in intent.
        system.delegator_exit_intent(:delegator, pool: staker1_pool, amount: delegated_amount / 2);
        system.advance_time(time: one_week);

        system.staker_exit_action(staker: staker1);

        // Re-stake after exiting. Pool should be different.
        system.stake(staker: staker1, amount: stake_amount, pool_enabled: true, :commission);
        let staker1_second_pool = system.staking.get_pool(staker: staker1);
        system.advance_time(time: one_week);
        assert!(staker1_pool != staker1_second_pool);

        // After the following, delegator has delegated_amount / 2 in staker1, delegated_amount
        // / 4 in intent, and delegated_amount / 4 in staker2.
        let staker2_pool = system.staking.get_pool(staker: staker2);
        system
            .switch_delegation_pool(
                :delegator,
                from_pool: staker1_pool,
                to_staker: staker2.staker.address,
                to_pool: staker2_pool,
                amount: delegated_amount / 4,
            );
        system.advance_time(time: one_week);

        // After the following, delegator has delegated_amount / 2 in staker1, and
        // delegated_amount / 4 in staker2.
        system.delegator_exit_action(:delegator, pool: staker1_pool);
        system.advance_time(time: one_week);

        // Claim rewards from second pool and see that the rewards are increasing.
        let delegator_reward_balance_before_claim = system
            .token
            .balance_of(account: delegator.reward.address);
        system.delegator_claim_rewards(:delegator, pool: staker2_pool);
        system.advance_time(time: one_week);
        let delegator_reward_balance_after_claim = system
            .token
            .balance_of(account: delegator.reward.address);
        assert!(
            delegator_reward_balance_after_claim == delegator_reward_balance_before_claim,
        ); // TODO: Change this after implement calculate_rewards.

        // After the following, delegator has delegated_amount / 4 in staker2.
        system.delegator_exit_intent(:delegator, pool: staker1_pool, amount: delegated_amount / 2);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.delegator_exit_action(:delegator, pool: staker1_pool);

        // Clean up and make all parties exit.
        system.staker_exit_intent(staker: staker1);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.staker_exit_intent(staker: staker2);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.staker_exit_action(staker: staker1);
        system.staker_exit_action(staker: staker2);
        system.delegator_exit_intent(:delegator, pool: staker2_pool, amount: delegated_amount / 4);
        system.delegator_exit_action(:delegator, pool: staker2_pool);

        // ------------- Flow complete, now asserts -------------

        // Assert pools' balances are low.
        assert!(
            system.token.balance_of(account: staker1_pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.
        assert!(system.token.balance_of(account: staker1_second_pool) == 0);
        assert!(
            system.token.balance_of(account: staker2_pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.

        // Assert all staked amounts were transferred back.
        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: staker1.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: staker2.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);

        // Asserts reward addresses are not empty.
        assert!(system.token.balance_of(account: staker1.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: staker2.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.

        // Assert all funds that moved from rewards supplier, were moved to correct addresses.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker1.reward.address)
                + system.token.balance_of(account: staker2.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: staker1_pool)
                + system.token.balance_of(account: staker1_second_pool)
                + system.token.balance_of(account: staker2_pool),
        );
    }
}

// Flow:
// Staker stake with commission 100%
// Delegator delegate
// Staker update_commission to 0%
// Delegator exit_intent
// Delegator exit_action, should get rewards
// Staker exit_intent
// Staker exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorDidntUpdateAfterStakerUpdateCommissionFlow {}
pub(crate) impl DelegatorDidntUpdateAfterStakerUpdateCommissionFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<DelegatorDidntUpdateAfterStakerUpdateCommissionFlow, TTokenState> {
    fn get_pool_address(
        self: DelegatorDidntUpdateAfterStakerUpdateCommissionFlow,
    ) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(
        ref self: DelegatorDidntUpdateAfterStakerUpdateCommissionFlow,
        ref system: SystemState<TTokenState>,
    ) {}

    fn test(
        self: DelegatorDidntUpdateAfterStakerUpdateCommissionFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let delegated_amount = stake_amount;
        let staker = system.new_staker(amount: stake_amount);
        let delegator = system.new_delegator(amount: delegated_amount);
        let commission = 10000;

        // Stake with commission 100%
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_epoch_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        // Update commission to 0%
        system.update_commission(:staker, commission: Zero::zero());
        system.advance_epoch_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.advance_epoch_and_attest(:staker);
        system.delegator_exit_action(:delegator, :pool);

        // Clean up and make all parties exit.
        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        // ------------- Flow complete, now asserts -------------

        // Assert pool balance is high.
        assert!(system.token.balance_of(account: pool) > 100);

        // Assert all staked amounts were transferred back.
        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);

        // Assert staker reward address is not empty.
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());

        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.

        // Assert all funds that moved from rewards supplier, were moved to correct addresses.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

// Flow:
// Staker stake with commission 100%
// Delegator delegate
// Staker update_commission to 0%
// Delegator update commission to 0% by calling claim_rewards
// Delegator exit_intent
// Delegator exit_action, should get rewards
// Staker exit_intent
// Staker exit_action
#[derive(Drop, Copy)]
pub(crate) struct DelegatorUpdatedAfterStakerUpdateCommissionFlow {}
pub(crate) impl DelegatorUpdatedAfterStakerUpdateCommissionFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<DelegatorUpdatedAfterStakerUpdateCommissionFlow, TTokenState> {
    fn get_pool_address(
        self: DelegatorUpdatedAfterStakerUpdateCommissionFlow,
    ) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(
        ref self: DelegatorUpdatedAfterStakerUpdateCommissionFlow,
        ref system: SystemState<TTokenState>,
    ) {}

    fn test(
        self: DelegatorUpdatedAfterStakerUpdateCommissionFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let delegated_amount = stake_amount;
        let staker = system.new_staker(amount: stake_amount);
        let delegator = system.new_delegator(amount: delegated_amount);
        let commission = 10000;
        let one_week = Time::weeks(count: 1);

        // Stake with commission 100%
        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);
        system.advance_time(time: one_week);

        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        // Update commission to 0%
        system.update_commission(:staker, commission: Zero::zero());
        system.advance_time(time: one_week);

        // Delegator claim_rewards to update commission to 0%
        system.delegator_claim_rewards(:delegator, :pool);
        assert!(system.token.balance_of(account: delegator.reward.address) == Zero::zero());
        system.advance_time(time: one_week);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.delegator_exit_action(:delegator, :pool);

        // Clean up and make all parties exit.
        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.staker_exit_action(:staker);

        // ------------- Flow complete, now asserts -------------

        // Assert pool balance is high.
        assert!(system.token.balance_of(account: pool) > 100);

        // Assert all staked amounts were transferred back.
        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(system.token.balance_of(account: staker.staker.address) == stake_amount);
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);

        // Asserts reward addresses are not empty.
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.

        // Assert all funds that moved from rewards supplier, were moved to correct addresses.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Flow:
/// Staker Stake
/// Delegator delegate
/// Delegator exit_intent
/// Staker exit_intent
/// Staker exit_action
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct StakerIntentLastActionFirstFlow {}
pub(crate) impl StakerIntentLastActionFirstFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<StakerIntentLastActionFirstFlow, TTokenState> {
    fn get_pool_address(self: StakerIntentLastActionFirstFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: StakerIntentLastActionFirstFlow, ref system: SystemState<TTokenState>) {}

    fn test(
        self: StakerIntentLastActionFirstFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let min_stake = system.staking.get_min_stake();
        let initial_stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: initial_stake_amount * 2);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let commission = 200;

        system.stake(:staker, amount: initial_stake_amount, pool_enabled: true, :commission);
        system.advance_epoch_and_attest(:staker);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: initial_stake_amount);
        system.delegate(:delegator, :pool, amount: initial_stake_amount / 2);
        system.advance_epoch_and_attest(:staker);

        system.delegator_exit_intent(:delegator, :pool, amount: initial_stake_amount / 2);
        system.advance_epoch_and_attest(:staker);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.staker_exit_action(:staker);

        system.delegator_exit_action(:delegator, :pool);

        assert!(system.token.balance_of(account: system.staking.address).is_zero());
        assert!(
            system.token.balance_of(account: pool) > 100,
        ); // TODO: Change this after implement calculate_rewards.
        assert!(
            system.token.balance_of(account: staker.staker.address) == initial_stake_amount * 2,
        );
        assert!(
            system.token.balance_of(account: delegator.delegator.address) == initial_stake_amount,
        );
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(
            system.token.balance_of(account: delegator.reward.address).is_zero(),
        ); // TODO: Change this after implement calculate_rewards.
        assert!(wide_abs_diff(system.reward_supplier.get_unclaimed_rewards(), STRK_IN_FRIS) < 100);
        assert!(
            initial_reward_supplier_balance == system
                .token
                .balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}

/// Test InternalStakerInfo migration with staker_info function.
/// Flow:
/// Staker stake without pool
/// Upgrade
/// staker_info
#[derive(Drop, Copy)]
pub(crate) struct StakerInfoAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfo>,
}
pub(crate) impl StakerInfoAfterUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<StakerInfoAfterUpgradeFlow, TTokenState> {
    fn get_pool_address(self: StakerInfoAfterUpgradeFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: StakerInfoAfterUpgradeFlow, ref system: SystemState<TTokenState>) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: false, :commission);

        let staker_info = system.staker_info(:staker);

        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(staker_info);

        system.advance_time(time: one_week);
        system.update_global_index_via_change_reward_address(:staker);
    }

    fn test(
        self: StakerInfoAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let staker_info_after_upgrade = system.staker_info(staker: self.staker.unwrap());
        let expected_staker_info = staker_update_rewards(
            staker_info: self.staker_info.unwrap(), global_index: system.staking.get_global_index(),
        );
        assert!(staker_info_after_upgrade == expected_staker_info);
    }
}

/// Test InternalStakerInfo migration with staker_info function.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// staker_info
#[derive(Drop, Copy)]
pub(crate) struct StakerInfoWithPoolAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfo>,
}
pub(crate) impl StakerInfoWithPoolAfterUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<StakerInfoWithPoolAfterUpgradeFlow, TTokenState> {
    fn get_pool_address(self: StakerInfoWithPoolAfterUpgradeFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: StakerInfoWithPoolAfterUpgradeFlow, ref system: SystemState<TTokenState>) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        let staker_info = system.staker_info(:staker);

        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(staker_info);

        system.advance_time(time: one_week);
    }

    fn test(
        self: StakerInfoWithPoolAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let staker_info_after_upgrade = system.staker_info(staker: self.staker.unwrap());
        let expected_staker_info = staker_update_rewards(
            staker_info: self.staker_info.unwrap(), global_index: system.staking.get_global_index(),
        );
        assert!(staker_info_after_upgrade == expected_staker_info);
    }
}

/// Test InternalStakerInfo migration with staker_info function.
/// Flow:
/// Staker stake with pool
/// Staker unstake_intent
/// Upgrade
/// staker_info
#[derive(Drop, Copy)]
pub(crate) struct StakerInfoUnstakeAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfo>,
}
pub(crate) impl StakerInfoUnstakeAfterUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<StakerInfoUnstakeAfterUpgradeFlow, TTokenState> {
    fn get_pool_address(self: StakerInfoUnstakeAfterUpgradeFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: StakerInfoUnstakeAfterUpgradeFlow, ref system: SystemState<TTokenState>) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        system.advance_time(time: one_week);

        system.staker_exit_intent(:staker);

        let staker_info = system.staker_info(:staker);

        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(staker_info);

        system.advance_time(time: one_week);
    }

    fn test(
        self: StakerInfoUnstakeAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let staker_info_after_upgrade = system.staker_info(staker: self.staker.unwrap());
        let expected_staker_info = self.staker_info.unwrap();
        assert!(staker_info_after_upgrade == expected_staker_info);
    }
}

/// Test InternalStakerInfo migration with internal_staker_info function.
/// Flow:
/// Staker stake without pool
/// Upgrade
/// internal_staker_info
#[derive(Drop, Copy)]
pub(crate) struct InternalStakerInfoAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfo>,
}
pub(crate) impl InternalStakerInfoAfterUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<InternalStakerInfoAfterUpgradeFlow, TTokenState> {
    fn get_pool_address(self: InternalStakerInfoAfterUpgradeFlow) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(ref self: InternalStakerInfoAfterUpgradeFlow, ref system: SystemState<TTokenState>) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: false, :commission);

        let staker_info = system.staker_info(:staker);

        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(staker_info);

        system.advance_time(time: one_week);
    }

    fn test(
        self: InternalStakerInfoAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let internal_staker_info_after_upgrade = system
            .internal_staker_info(staker: self.staker.unwrap());
        let expected_staker_info = staker_update_rewards(
            staker_info: self.staker_info.unwrap(), global_index: system.staking.get_global_index(),
        );
        assert!(internal_staker_info_after_upgrade == expected_staker_info.into());
    }
}

/// Test InternalStakerInfo migration with internal_staker_info function.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// internal_staker_info
#[derive(Drop, Copy)]
pub(crate) struct InternalStakerInfoWithPoolAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfo>,
}
pub(crate) impl InternalStakerInfoWithPoolAfterUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<InternalStakerInfoWithPoolAfterUpgradeFlow, TTokenState> {
    fn get_pool_address(
        self: InternalStakerInfoWithPoolAfterUpgradeFlow,
    ) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(
        ref self: InternalStakerInfoWithPoolAfterUpgradeFlow, ref system: SystemState<TTokenState>,
    ) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        let staker_info = system.staker_info(:staker);

        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(staker_info);

        system.advance_time(time: one_week);
    }

    fn test(
        self: InternalStakerInfoWithPoolAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let internal_staker_info_after_upgrade = system
            .internal_staker_info(staker: self.staker.unwrap());
        let expected_staker_info = staker_update_rewards(
            staker_info: self.staker_info.unwrap(), global_index: system.staking.get_global_index(),
        );
        assert!(internal_staker_info_after_upgrade == expected_staker_info.into());
    }
}

/// Test InternalStakerInfo migration with internal_staker_info function.
/// Flow:
/// Staker stake with pool
/// Staker unstake_intent
/// Upgrade
/// internal_staker_info
#[derive(Drop, Copy)]
pub(crate) struct InternalStakerInfoUnstakeAfterUpgradeFlow {
    pub(crate) staker: Option<Staker>,
    pub(crate) staker_info: Option<StakerInfo>,
}
pub(crate) impl InternalStakerInfoUnstakeAfterUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<InternalStakerInfoUnstakeAfterUpgradeFlow, TTokenState> {
    fn get_pool_address(
        self: InternalStakerInfoUnstakeAfterUpgradeFlow,
    ) -> Option<ContractAddress> {
        Option::None
    }

    fn setup(
        ref self: InternalStakerInfoUnstakeAfterUpgradeFlow, ref system: SystemState<TTokenState>,
    ) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        system.advance_time(time: one_week);

        system.staker_exit_intent(:staker);

        let staker_info = system.staker_info(:staker);

        self.staker = Option::Some(staker);
        self.staker_info = Option::Some(staker_info);

        system.advance_time(time: one_week);
    }

    fn test(
        self: InternalStakerInfoUnstakeAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let internal_staker_info_after_upgrade = system
            .internal_staker_info(staker: self.staker.unwrap());
        let expected_staker_info = self.staker_info.unwrap();
        assert!(internal_staker_info_after_upgrade == expected_staker_info.into());
    }
}

/// Test pool upgrade flow.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// Delegator exit_intent
/// Delegator exit_action
#[derive(Drop, Copy)]
pub(crate) struct PoolUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegated_amount: Amount,
}
pub(crate) impl PoolUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<PoolUpgradeFlow, TTokenState> {
    fn get_pool_address(self: PoolUpgradeFlow) -> Option<ContractAddress> {
        self.pool_address
    }

    fn setup(ref self: PoolUpgradeFlow, ref system: SystemState<TTokenState>) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegated_amount = delegated_amount;
    }

    fn test(self: PoolUpgradeFlow, ref system: SystemState<TTokenState>, system_type: SystemType) {
        let pool = self.pool_address.unwrap();
        let delegator = self.delegator.unwrap();
        let delegated_amount = self.delegated_amount;
        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);
        system.advance_time(time: system.staking.get_exit_wait_window());
        system.delegator_exit_action(:delegator, :pool);
        assert!(system.token.balance_of(account: pool) == Zero::zero());
        assert!(system.token.balance_of(account: delegator.delegator.address) == delegated_amount);
    }
}

/// Test InternalPoolMemberInfo migration with internal_pool_member_info and
/// get_internal_pool_member_info functions.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// internal_pool_member_info & get_internal_pool_member_info
#[derive(Drop, Copy)]
pub(crate) struct InternalPoolMemberInfoAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegator_info: Option<PoolMemberInfo>,
}
pub(crate) impl InternalPoolMemberInfoAfterUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<InternalPoolMemberInfoAfterUpgradeFlow, TTokenState> {
    fn get_pool_address(self: InternalPoolMemberInfoAfterUpgradeFlow) -> Option<ContractAddress> {
        self.pool_address
    }

    fn setup(
        ref self: InternalPoolMemberInfoAfterUpgradeFlow, ref system: SystemState<TTokenState>,
    ) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        let delegator_info = system.pool_member_info(:delegator, :pool);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegator_info = Option::Some(delegator_info);

        system.advance_time(time: one_week);
    }

    fn test(
        self: InternalPoolMemberInfoAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let delegator = self.delegator.unwrap();
        let pool = self.pool_address.unwrap();
        let internal_pool_member_info_after_upgrade = system
            .internal_pool_member_info(:delegator, :pool);
        let get_internal_pool_member_info_after_upgrade = system
            .get_internal_pool_member_info(:delegator, :pool);
        let expected_pool_member_info = pool_update_rewards(
            pool_member_info: self.delegator_info.unwrap(),
            updated_index: system.staking.get_global_index(),
        );
        assert!(internal_pool_member_info_after_upgrade == expected_pool_member_info.into());
        assert!(
            get_internal_pool_member_info_after_upgrade == Option::Some(
                expected_pool_member_info.into(),
            ),
        );
    }
}

/// Test InternalPoolMemberInfo migration with internal_staker_info and
/// get_internal_pool_member_info functions.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Delegator exit_intent
/// Upgrade
/// internal_pool_member_info & get_internal_pool_member_info
#[derive(Drop, Copy)]
pub(crate) struct InternalPoolMemberInfoUndelegateAfterUpgradeFlow {
    pub(crate) pool_address: Option<ContractAddress>,
    pub(crate) delegator: Option<Delegator>,
    pub(crate) delegator_info: Option<PoolMemberInfo>,
}
pub(crate) impl InternalPoolMemberInfoUndelegateAfterUpgradeFlowImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of FlowTrait<InternalPoolMemberInfoUndelegateAfterUpgradeFlow, TTokenState> {
    fn get_pool_address(
        self: InternalPoolMemberInfoUndelegateAfterUpgradeFlow,
    ) -> Option<ContractAddress> {
        self.pool_address
    }

    fn setup(
        ref self: InternalPoolMemberInfoUndelegateAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
    ) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let staker = system.new_staker(amount: stake_amount * 2);
        let commission = 200;
        let one_week = Time::weeks(count: 1);

        system.stake(:staker, amount: stake_amount, pool_enabled: true, :commission);

        let delegated_amount = stake_amount / 2;
        let delegator = system.new_delegator(amount: delegated_amount);
        let pool = system.staking.get_pool(:staker);
        system.delegate(:delegator, :pool, amount: delegated_amount);

        system.advance_time(time: one_week);

        system.delegator_exit_intent(:delegator, :pool, amount: delegated_amount);

        let delegator_info = system.pool_member_info(:delegator, :pool);

        self.pool_address = Option::Some(pool);
        self.delegator = Option::Some(delegator);
        self.delegator_info = Option::Some(delegator_info);

        system.advance_time(time: one_week);
    }

    fn test(
        self: InternalPoolMemberInfoUndelegateAfterUpgradeFlow,
        ref system: SystemState<TTokenState>,
        system_type: SystemType,
    ) {
        let delegator = self.delegator.unwrap();
        let pool = self.pool_address.unwrap();
        let internal_pool_member_info_after_upgrade = system
            .internal_pool_member_info(:delegator, :pool);
        let get_internal_pool_member_info_after_upgrade = system
            .get_internal_pool_member_info(:delegator, :pool);
        let mut expected_pool_member_info = self.delegator_info.unwrap();
        expected_pool_member_info.index = system.staking.get_global_index();
        assert!(internal_pool_member_info_after_upgrade == expected_pool_member_info.into());
        assert!(
            get_internal_pool_member_info_after_upgrade == Option::Some(
                expected_pool_member_info.into(),
            ),
        );
    }
}
// TODO: Implement this flow test.
/// Test calling pool migration after upgrade.
/// Should do nothing because pool migration is called in the upgrade proccess.
/// Flow:
/// Staker stake with pool
/// Delegator delegate
/// Upgrade
/// Pool call pool_migration - final index and pool balance as before.


