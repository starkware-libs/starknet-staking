use contracts_commons::test_utils::TokenTrait;
use contracts_commons::types::time::time::Time;
use core::num::traits::Zero;
use staking::flow_test::utils::SystemState;
use staking::flow_test::utils::{FlowTrait, SystemStakerTrait, SystemType};
use staking::flow_test::utils::{StakingTrait, SystemDelegatorTrait, SystemTrait};

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
    fn test(self: BasicStakeFlow, ref system: SystemState<TTokenState>, system_type: SystemType) {
        let min_stake = system.staking.get_min_stake();
        let stake_amount = min_stake * 2;
        let one_week = Time::weeks(count: 1);
        let initial_reward_supplier_balance = system
            .token
            .balance_of(account: system.reward_supplier.address);
        let staker = system.new_staker(amount: stake_amount * 2);
        system.stake(:staker, amount: stake_amount, pool_enabled: true, commission: 200);
        system.advance_time(time: one_week);

        system.increase_stake(:staker, amount: stake_amount / 2);
        system.advance_time(time: one_week);

        let pool = system.staking.get_pool(:staker);
        let delegator = system.new_delegator(amount: stake_amount);
        system.delegate(:delegator, :pool, amount: stake_amount / 2);
        system.advance_time(time: one_week);

        system.increase_stake(:staker, amount: stake_amount / 4);
        system.advance_time(time: one_week);

        system.increase_delegate(:delegator, :pool, amount: stake_amount / 4);
        system.advance_time(time: one_week);

        system.delegator_exit_intent(:delegator, :pool, amount: stake_amount * 3 / 4);
        system.advance_time(time: one_week);

        system.staker_exit_intent(:staker);
        system.advance_time(time: system.staking.get_exit_wait_window());

        system.delegator_exit_action(:delegator, :pool);
        system.staker_exit_action(:staker);

        assert!(system.token.balance_of(account: pool) < 100);
        assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount * 2);
        assert_eq!(system.token.balance_of(account: delegator.delegator.address), stake_amount);
        assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
        assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
        assert_eq!(
            initial_reward_supplier_balance,
            system.token.balance_of(account: system.reward_supplier.address)
                + system.token.balance_of(account: staker.reward.address)
                + system.token.balance_of(account: delegator.reward.address)
                + system.token.balance_of(account: pool),
        );
    }
}
