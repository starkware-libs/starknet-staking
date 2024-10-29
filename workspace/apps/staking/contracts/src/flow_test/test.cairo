use contracts::errors::{Error, OptionAuxTrait};
use core::array::ArrayTrait;
use contracts::test_utils::{StakingInitConfig, general_contract_system_deployment};
use contracts::event_test_utils::assert_number_of_events;
use contracts::message_to_l1_test_utils::assert_number_of_messages_to_l1;
use snforge_std::cheatcodes::events::EventSpyTrait;
use snforge_std::cheatcodes::message_to_l1::MessageToL1SpyTrait;
use starknet::get_block_timestamp;
use contracts::staking::interface::{IStakingDispatcherTrait, IStakingDispatcher};
use contracts::flow_test::utils as flow_test_utils;
use flow_test_utils::{SystemTrait, StakerTrait, StakingTrait, RewardSupplierTrait};
use flow_test_utils::{TokenTrait, DelegatorTrait};
use contracts_commons::constants::{SECONDS_IN_DAY, DAYS_IN_WEEK};
use contracts::constants::{STRK_IN_FRIS};
use contracts::test_utils::constants::BASE_MINT_AMOUNT;
use core::num::traits::Zero;
use contracts::utils::{ceil_of_division, compute_threshold};

#[test]
fn test_l2_initialization_flow() {
    // The default StakingInitConfig also declares the pooling contract.
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy a system, set the resulted addresses in cfg.
    general_contract_system_deployment(ref cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    };

    // TODO: Should we also check the deployments events?
    let mut spy_events = snforge_std::spy_events();
    // TODO: Should we also look for messages_to_l1 initiated in the deployment?
    let mut spy_messages_to_l1 = snforge_std::spy_messages_to_l1();

    // Keep the initial global_index for result validation.
    let initial_global_index = staking_dispatcher.contract_parameters().global_index;

    // Waits 5 days (+ epsilon).
    let mut block_timestamp = get_block_timestamp();
    block_timestamp += 5 * SECONDS_IN_DAY + 360;
    snforge_std::start_cheat_block_timestamp_global(:block_timestamp);

    // Update global index.
    staking_dispatcher.update_global_index_if_needed();

    // For several additional days calls update_global_index_if_needed once a day (+- epsilon).
    let waits = @array![
        SECONDS_IN_DAY + 300,
        SECONDS_IN_DAY + 20,
        SECONDS_IN_DAY + 200,
        SECONDS_IN_DAY - 50,
        SECONDS_IN_DAY
    ];
    for i in 0
        ..waits
            .len() {
                block_timestamp += *waits.at(i);
                snforge_std::start_cheat_block_timestamp_global(:block_timestamp);
                staking_dispatcher.update_global_index_if_needed();
            };

    // Read the final global_index for result validation.
    let final_global_index = staking_dispatcher.contract_parameters().global_index;

    // Because there was no staking, global index should not be changed.
    assert_eq!(final_global_index, initial_global_index);

    // Asserts number of emitted events:
    // * 1 initial MintRequest from RewardSupplier.
    // * For each of the 3 actual update_global_index 2 events:
    //   * CalculatedRewards from RewardSupplier.
    //   * GlobalIndexUpdated from Staking.
    // Total 1 + 3 * 2 = 7.
    // This should be changed if the deployment events are included..
    // This should be changed if the "if_needed" logic is changed.
    let events = spy_events.get_events().events;
    assert_number_of_events(actual: events.len(), expected: 7, message: "l2 initialization");

    // Asserts number of sent messages to l1.
    // 1 STRK for rounding up + additional threshold.
    let number_of_expected_minting_messages: u32 = ceil_of_division(
        dividend: STRK_IN_FRIS + compute_threshold(BASE_MINT_AMOUNT), divisor: BASE_MINT_AMOUNT
    )
        .try_into()
        .expect_with_err(Error::MESSAGES_COUNT_ISNT_U32);
    let messages_to_l1 = spy_messages_to_l1.get_messages().messages;
    assert_number_of_messages_to_l1(
        actual: messages_to_l1.len(),
        expected: number_of_expected_minting_messages,
        message: "l2 initialization"
    );
}


/// Flow - Basic Stake:
/// Staker - Stake with pool - cover if pool_enabled=true
/// Staker increase_stake - cover if pool amount=0 in calc_rew
/// Delegator delegate (and create) to Staker
/// Staker increase_stake - cover pool amount > 0 in calc_rew
/// Delegator increase_delegate
/// Exit and check

#[test]
fn basic_stake_flow_test() {
    // TODO: new cfg - split to basic cfg and specific flow cfg.
    let cfg: StakingInitConfig = Default::default();
    let mut system = SystemTrait::basic_stake_flow_cfg(:cfg).deploy();
    let min_stake = system.staking.get_min_stake();
    let stake_amount = min_stake * 2;
    let one_week = SECONDS_IN_DAY * DAYS_IN_WEEK;
    let staker = system.new_staker(amount: stake_amount * 2);
    staker.stake(amount: stake_amount, pool_enabled: true, commission: 200);
    system.advance_time(time: one_week);

    staker.increase_stake(amount: stake_amount / 2);
    system.advance_time(time: one_week);

    let pool = system.staking.get_pool(:staker);
    let delegator = system.new_delegator(amount: stake_amount);
    delegator.delegate(:pool, amount: stake_amount / 2);
    system.advance_time(time: one_week);

    staker.increase_stake(amount: stake_amount / 4);
    system.advance_time(time: one_week);

    delegator.increase_delegate(:pool, amount: stake_amount / 4);
    system.advance_time(time: one_week);

    delegator.exit_intent(:pool, amount: stake_amount * 3 / 4);
    system.advance_time(time: one_week);

    staker.exit_intent();
    system.advance_time(time: 3 * one_week);

    delegator.exit_action(:pool);
    staker.exit_action();

    assert!(system.token.balance_of(account: system.staking.address).is_zero());
    assert!(system.token.balance_of(account: pool) < 100);
    assert_eq!(system.token.balance_of(account: staker.staker.address), stake_amount * 2);
    assert_eq!(system.token.balance_of(account: delegator.delegator.address), stake_amount);
    assert!(system.token.balance_of(account: staker.reward.address).is_non_zero());
    assert!(system.token.balance_of(account: delegator.reward.address).is_non_zero());
    assert!(system.reward_supplier.get_unclaimed_rewards() - STRK_IN_FRIS < 100);
}
