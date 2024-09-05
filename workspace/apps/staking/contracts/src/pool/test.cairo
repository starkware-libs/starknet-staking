use core::num::traits::zero::Zero;
use core::serde::Serde;
use core::option::OptionTrait;
use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use contracts::staking::interface::{StakerInfo, StakerInfoTrait, StakerPoolInfo};
use contracts::pool::interface::{IPool, IPoolDispatcher, IPoolDispatcherTrait, PoolContractInfo};
use contracts::pool::{PoolMemberInfo, Pool::{SwitchPoolData, InternalPoolFunctionsTrait}};
use contracts::utils::{compute_rewards_rounded_down, compute_commission_amount_rounded_up};
use contracts::test_utils;
use test_utils::{initialize_pool_state, deploy_mock_erc20_contract, StakingInitConfig};
use test_utils::{deploy_staking_contract, approve};
use test_utils::{stake_with_pool_enabled, load_from_simple_map, load_option_from_simple_map};
use test_utils::{general_contract_system_deployment, cheat_reward_for_reward_supplier};
use test_utils::{create_rewards_for_pool_member, load_pool_member_info_from_map};
use test_utils::{set_account_as_operator, enter_delegation_pool_for_testing_using_dispatcher};
use contracts::test_utils::constants;
use constants::{STAKER_ADDRESS, STAKING_CONTRACT_ADDRESS, TOKEN_ADDRESS, DUMMY_ADDRESS};
use constants::{OTHER_REWARD_ADDRESS, NON_POOL_MEMBER_ADDRESS, COMMISSION, STAKER_FINAL_INDEX};
use constants::{NOT_STAKING_CONTRACT_ADDRESS, OTHER_STAKER_ADDRESS, OTHER_POOL_MEMBER_ADDRESS};
use constants::OTHER_OPERATIONAL_ADDRESS;
use contracts::staking::objects::{UndelegateIntentKey, UndelegateIntentValue};
use contracts::staking::objects::UndelegateIntentValueZero;
use contracts::event_test_utils;
use event_test_utils::assert_pool_member_reward_claimed_event;
use event_test_utils::{assert_final_index_set_event, assert_new_pool_member_event};
use event_test_utils::assert_pool_member_exit_intent_event;
use event_test_utils::assert_delete_pool_member_event;
use event_test_utils::assert_number_of_events;
use event_test_utils::assert_delegation_pool_member_balance_changed_event;
use event_test_utils::assert_pool_member_reward_address_change_event;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::get_block_timestamp;
use snforge_std::{cheat_caller_address, CheatSpan};
use snforge_std::{test_address, start_cheat_block_timestamp_global};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use contracts_commons::test_utils::cheat_caller_address_once;


#[test]
fn test_calculate_rewards() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        :token_address,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );

    let updated_index: u64 = cfg.staker_info.index * 2;
    let mut pool_member_info = PoolMemberInfo {
        reward_address: cfg.staker_info.reward_address,
        amount: cfg.staker_info.amount_own,
        index: cfg.staker_info.index,
        unclaimed_rewards: cfg.staker_info.get_pool_info_unchecked().unclaimed_rewards,
        unpool_time: Option::None,
        unpool_amount: Zero::zero(),
    };
    let interest = updated_index - pool_member_info.index;
    let rewards_including_commission = compute_rewards_rounded_down(
        amount: pool_member_info.amount, :interest
    );
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let unclaimed_rewards = rewards_including_commission - commission_amount;
    assert!(state.calculate_rewards(ref :pool_member_info, :updated_index));

    let mut expected_pool_member_info = PoolMemberInfo {
        index: cfg.staker_info.index * 2, unclaimed_rewards, ..pool_member_info
    };
    assert_eq!(pool_member_info, expected_pool_member_info);
}

// TODO(alon, 24/07/2024): Complete this function.
#[test]
fn test_enter_delegation_pool() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let mut spy = snforge_std::spy_events();
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    // Check that the pool member info was updated correctly.
    let expected_pool_member_info: PoolMemberInfo = PoolMemberInfo {
        amount: cfg.pool_member_info.amount,
        index: cfg.pool_member_info.index,
        unpool_time: Option::None,
        reward_address: cfg.pool_member_info.reward_address,
        unclaimed_rewards: cfg.pool_member_info.unclaimed_rewards,
        unpool_amount: Zero::zero(),
    };
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    assert_eq!(
        pool_dispatcher.state_of(cfg.test_info.pool_member_address), expected_pool_member_info
    );
    // Check that all the pool amount was transferred to the staking contract.
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = erc20_dispatcher.balance_of(staking_contract);
    assert_eq!(balance, cfg.staker_info.amount_own.into() + cfg.pool_member_info.amount.into());
    let balance = erc20_dispatcher.balance_of(pool_contract);
    assert_eq!(balance, 0);
    // Check that the staker info was updated correctly.
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let expected_staker_info = StakerInfo {
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        unstake_time: Option::None,
        amount_own: cfg.staker_info.amount_own,
        index: cfg.staker_info.index,
        unclaimed_rewards_own: 0,
        pool_info: Option::Some(
            StakerPoolInfo {
                pool_contract,
                amount: cfg.pool_member_info.amount,
                unclaimed_rewards: Zero::zero(),
                commission: cfg.staker_info.get_pool_info_unchecked().commission,
            }
        ),
    };
    assert_eq!(staking_dispatcher.state_of(cfg.test_info.staker_address), expected_staker_info);

    // Validate NewPoolMember and DelegationPoolMemberBalanceChanged events.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "enter_delegation_pool");
    assert_new_pool_member_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        staker_address: cfg.test_info.staker_address,
        reward_address: cfg.pool_member_info.reward_address,
        amount: cfg.pool_member_info.amount
    );
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[1],
        pool_member: cfg.test_info.pool_member_address,
        old_delegated_stake: Zero::zero(),
        new_delegated_stake: cfg.pool_member_info.amount
    );
}

#[test]
fn test_add_to_delegation_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );

    // Deploy the staking contract and stake.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };

    // Enter first pool member to the delegation pool.
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let first_pool_member = cfg.test_info.pool_member_address;
    let first_pool_member_info = cfg.pool_member_info;

    // Enter second pool member to the delegation pool.
    cfg.test_info.pool_member_address = OTHER_POOL_MEMBER_ADDRESS();
    cfg.pool_member_info.reward_address = OTHER_REWARD_ADDRESS();
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let second_pool_member = cfg.test_info.pool_member_address;
    let second_pool_member_info = cfg.pool_member_info;
    let staker_info_before = staking_dispatcher
        .state_of(staker_address: cfg.test_info.staker_address);

    // Change global index.
    let index_before = first_pool_member_info.index;
    let updated_index = first_pool_member_info.index * 2;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span()
    );

    // First pool member adds to the delegation pool.
    let first_pool_member_info_before_add = pool_dispatcher
        .state_of(pool_member: first_pool_member);
    let delegate_amount = first_pool_member_info.amount;
    approve(
        owner: first_pool_member, spender: pool_contract, amount: delegate_amount, :token_address
    );
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: pool_contract, caller_address: first_pool_member);
    pool_dispatcher.add_to_delegation_pool(pool_member: first_pool_member, amount: delegate_amount);
    let pool_member_info_after_add = pool_dispatcher.state_of(pool_member: first_pool_member);
    let rewards_including_commission = compute_rewards_rounded_down(
        amount: delegate_amount, interest: updated_index - index_before
    );
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let unclaimed_rewards_member = rewards_including_commission - commission_amount;
    let pool_member_info_expected = PoolMemberInfo {
        amount: first_pool_member_info_before_add.amount + delegate_amount,
        index: updated_index,
        unclaimed_rewards: unclaimed_rewards_member,
        ..first_pool_member_info_before_add
    };
    assert_eq!(pool_member_info_after_add, pool_member_info_expected);

    // Validate the single DelegationPoolMemberBalanceChanged event.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "add_to_delegation_pool");
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[0],
        pool_member: first_pool_member,
        old_delegated_stake: first_pool_member_info_before_add.amount,
        new_delegated_stake: pool_member_info_after_add.amount
    );

    // Check staker info after first add to delegation pool.
    let staker_info_after = staking_dispatcher
        .state_of(staker_address: cfg.test_info.staker_address);
    let unclaimed_rewards_own = compute_rewards_rounded_down(
        amount: staker_info_before.amount_own, interest: updated_index - index_before
    );
    let mut staker_info_expected = StakerInfo {
        index: updated_index,
        unclaimed_rewards_own: unclaimed_rewards_own + (commission_amount * 2),
        ..staker_info_before
    };
    let mut expected_pool_info = staker_info_expected.get_pool_info_unchecked();
    expected_pool_info.amount = staker_info_before.get_pool_info_unchecked().amount
        + delegate_amount;
    expected_pool_info.unclaimed_rewards = unclaimed_rewards_member * 2;
    staker_info_expected.pool_info = Option::Some(expected_pool_info);
    assert_eq!(staker_info_expected, staker_info_after);

    // Second pool member adds to the delegation pool.
    let second_pool_member_info_before_add = pool_dispatcher
        .state_of(pool_member: second_pool_member);
    let delegate_amount = second_pool_member_info.amount;
    approve(
        owner: second_pool_member, spender: pool_contract, amount: delegate_amount, :token_address
    );
    cheat_caller_address_once(contract_address: pool_contract, caller_address: second_pool_member);
    pool_dispatcher
        .add_to_delegation_pool(pool_member: second_pool_member, amount: delegate_amount);
    let pool_member_info_after_add = pool_dispatcher.state_of(pool_member: second_pool_member);
    let rewards_including_commission = compute_rewards_rounded_down(
        amount: delegate_amount, interest: updated_index - index_before
    );
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let unclaimed_rewards_member = rewards_including_commission - commission_amount;
    let pool_member_info_expected = PoolMemberInfo {
        amount: second_pool_member_info_before_add.amount + delegate_amount,
        index: updated_index,
        unclaimed_rewards: unclaimed_rewards_member,
        ..second_pool_member_info_before_add
    };
    assert_eq!(pool_member_info_after_add, pool_member_info_expected);

    // Check staker info after second add to delegation pool.
    let staker_info_after = staking_dispatcher
        .state_of(staker_address: cfg.test_info.staker_address);
    if let Option::Some(mut pool_info) = staker_info_expected.pool_info {
        pool_info.amount += delegate_amount;
        staker_info_expected.pool_info = Option::Some(pool_info);
    }
    assert_eq!(staker_info_expected, staker_info_after);
}


#[test]
fn test_assert_staker_is_active() {
    let mut state = initialize_pool_state(
        staker_address: STAKER_ADDRESS(),
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: TOKEN_ADDRESS(),
        commission: COMMISSION
    );
    assert!(state.final_staker_index.read().is_none());
    state.assert_staker_is_active();
}

#[test]
#[should_panic(expected: ("Staker inactive.",))]
fn test_assert_staker_is_active_panic() {
    let mut state = initialize_pool_state(
        staker_address: STAKER_ADDRESS(),
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: TOKEN_ADDRESS(),
        commission: COMMISSION
    );
    state.final_staker_index.write(Option::Some(5));
    state.assert_staker_is_active();
}

#[test]
fn test_set_final_staker_index() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    cheat_caller_address_once(
        contract_address: test_address(), caller_address: STAKING_CONTRACT_ADDRESS()
    );
    assert!(state.final_staker_index.read().is_none());
    let mut spy = snforge_std::spy_events();
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
    assert_eq!(state.final_staker_index.read().unwrap(), STAKER_FINAL_INDEX);
    // Validate the single FinalIndexSet event.
    let events = spy.get_events().emitted_by(contract_address: test_address()).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_final_staker_index");
    assert_final_index_set_event(
        spied_event: events[0],
        staker_address: cfg.test_info.staker_address,
        final_staker_index: STAKER_FINAL_INDEX
    );
}

#[test]
#[should_panic(expected: "Caller is not staking contract.")]
fn test_set_final_staker_index_caller_is_not_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    cheat_caller_address_once(
        contract_address: test_address(), caller_address: NOT_STAKING_CONTRACT_ADDRESS()
    );
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
}

#[test]
#[should_panic(expected: "Final staker index already set.")]
fn test_set_final_staker_index_already_set() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: STAKING_CONTRACT_ADDRESS(),
        span: CheatSpan::TargetCalls(2)
    );
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
}

#[test]
fn test_change_reward_address() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let pool_member_info_before_change = pool_dispatcher
        .state_of(cfg.test_info.pool_member_address);
    let other_reward_address = OTHER_REWARD_ADDRESS();

    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address
    );
    let mut spy = snforge_std::spy_events();
    pool_dispatcher.change_reward_address(other_reward_address);
    let pool_member_info_after_change = pool_dispatcher.state_of(cfg.test_info.pool_member_address);
    let pool_member_info_expected = PoolMemberInfo {
        reward_address: other_reward_address, ..pool_member_info_before_change
    };
    assert_eq!(pool_member_info_after_change, pool_member_info_expected);
    // Validate the single PoolMemberRewardAddressChanged event.
    let events = spy.get_events().emitted_by(contract_address: pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "change_reward_address");
    assert_pool_member_reward_address_change_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        new_address: other_reward_address,
        old_address: cfg.pool_member_info.reward_address
    );
}


#[test]
#[should_panic(expected: "Pool member does not exist.")]
fn test_change_reward_address_pool_member_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        :staking_contract,
        :token_address,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    cheat_caller_address_once(
        contract_address: test_address(), caller_address: NON_POOL_MEMBER_ADDRESS()
    );
    // Reward address is arbitrary because it should fail because of the caller.
    state.change_reward_address(reward_address: DUMMY_ADDRESS());
}

#[test]
fn test_claim_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier = cfg.staking_contract_info.reward_supplier;

    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    // Check that the pool member info was updated correctly.
    assert_eq!(pool_dispatcher.state_of(cfg.test_info.pool_member_address), cfg.pool_member_info);
    // Update index for testing.
    // TODO: Wrap in a function.
    let updated_index: u64 = cfg.staker_info.index * 2;
    snforge_std::store(
        staking_contract, selector!("global_index"), array![updated_index.into()].span()
    );
    // Compute expected rewards.
    let interest: u64 = updated_index - cfg.staker_info.index;
    let rewards_including_commission = compute_rewards_rounded_down(
        amount: cfg.pool_member_info.amount, :interest
    );
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let expected_reward = rewards_including_commission - commission_amount;
    cheat_reward_for_reward_supplier(:cfg, :reward_supplier, :expected_reward, :token_address);
    // Claim rewards, and validate the results.
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address
    );
    let mut spy = snforge_std::spy_events();
    let actual_reward = pool_dispatcher
        .claim_rewards(pool_member: cfg.test_info.pool_member_address);
    let expected_reward = rewards_including_commission - commission_amount;
    assert_eq!(actual_reward, expected_reward);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = erc20_dispatcher.balance_of(cfg.pool_member_info.reward_address);
    assert_eq!(balance, actual_reward.into());
    // Validate the single PoolMemberRewardClaimed event.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "claim_rewards");
    assert_pool_member_reward_claimed_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
        amount: actual_reward
    );
}

#[test]
fn test_exit_delegation_pool_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    // Exit delegation pool intent, and validate the results.
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    pool_dispatcher.exit_delegation_pool_intent(amount: cfg.pool_member_info.amount);
    // Validate the expected pool member info and staker info.
    let expected_time = get_block_timestamp()
        + staking_dispatcher.contract_parameters().exit_wait_window;
    let expected_pool_member_info = PoolMemberInfo {
        amount: Zero::zero(),
        unpool_amount: cfg.pool_member_info.amount,
        unpool_time: Option::Some(expected_time),
        ..cfg.pool_member_info
    };
    assert_eq!(
        pool_dispatcher.state_of(cfg.test_info.pool_member_address), expected_pool_member_info
    );
    let mut expected_staker_info = StakerInfo {
        amount_own: cfg.staker_info.amount_own, ..cfg.staker_info
    };
    if let Option::Some(mut pool_info) = expected_staker_info.pool_info {
        pool_info.amount = Zero::zero();
        pool_info.pool_contract = pool_contract;
        expected_staker_info.pool_info = Option::Some(pool_info);
    }
    assert_eq!(staking_dispatcher.state_of(cfg.test_info.staker_address), expected_staker_info);
    // Validate that the data is written in the exit intents map in staking contract.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract
    );
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_pool_member_info.unpool_time.expect('unpool_time is None'),
        amount: expected_pool_member_info.unpool_amount.into()
    };
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);

    // Validate the single PoolMemberExitIntent event.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "exit_delegation_pool_intent"
    );
    assert_pool_member_exit_intent_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        exit_timestamp: expected_time,
        amount: cfg.pool_member_info.amount
    );
}

#[test]
fn test_exit_delegation_pool_action() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    // Change global index and exit delegation pool intent.
    let index_before = cfg.pool_member_info.index;
    let updated_index = cfg.pool_member_info.index * 2;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span()
    );
    // Calculate the expected rewards and commission.
    let delegate_amount = cfg.pool_member_info.amount;
    let rewards_including_commission = compute_rewards_rounded_down(
        amount: delegate_amount, interest: updated_index - index_before
    );
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let unclaimed_rewards_member = rewards_including_commission - commission_amount;
    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards_member, :token_address
    );
    // Exit delegation pool intent.
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address
    );
    pool_dispatcher.exit_delegation_pool_intent(amount: delegate_amount);

    let balance_before_action = erc20_dispatcher.balance_of(cfg.test_info.pool_member_address);
    let reward_account_balance_before = erc20_dispatcher
        .balance_of(cfg.pool_member_info.reward_address);
    start_cheat_block_timestamp_global(
        block_timestamp: get_block_timestamp()
            + staking_dispatcher.contract_parameters().exit_wait_window
    );
    // Exit delegation pool action and check that:
    // 1. The returned value is correct.
    // 2. The pool member is erased from the pool member info map.
    // 3. The pool amount was transferred back to the pool member.
    // 4. The unclaimed rewards were transferred to the reward account.
    let mut spy = snforge_std::spy_events();
    let returned_amount = pool_dispatcher
        .exit_delegation_pool_action(pool_member: cfg.test_info.pool_member_address);
    assert_eq!(returned_amount, cfg.pool_member_info.amount);
    let pool_member: Option<PoolMemberInfo> = load_option_from_simple_map(
        map_selector: selector!("pool_member_info"),
        key: cfg.test_info.pool_member_address,
        contract: pool_contract
    );
    assert!(pool_member.is_none());
    let balance_after_action = erc20_dispatcher.balance_of(cfg.test_info.pool_member_address);
    let reward_account_balance_after = erc20_dispatcher
        .balance_of(cfg.pool_member_info.reward_address);
    assert_eq!(balance_after_action, balance_before_action + cfg.pool_member_info.amount.into());
    assert_eq!(
        reward_account_balance_after,
        reward_account_balance_before + unclaimed_rewards_member.into()
    );
    // Validate the PoolMemberRewardClaimed and DeletePoolMember event.
    let events = spy.get_events().emitted_by(contract_address: pool_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "exit_delegation_pool_action"
    );
    assert_pool_member_reward_claimed_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
        amount: unclaimed_rewards_member
    );
    assert_delete_pool_member_event(
        spied_event: events[1],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
    );
}

// TODO: add event test.
#[test]
fn test_switch_delegation_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    // Create other staker with pool.
    let switch_amount = cfg.pool_member_info.amount / 2;
    cfg.test_info.staker_address = OTHER_STAKER_ADDRESS();
    cfg.staker_info.operational_address = OTHER_OPERATIONAL_ADDRESS();
    set_account_as_operator(
        :staking_contract,
        account: cfg.test_info.staker_address,
        security_admin: cfg.test_info.security_admin
    );
    let to_staker_pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);

    let (unclaimed_rewards_member, updated_index) = create_rewards_for_pool_member(ref :cfg);
    let reward_account_balance_before = erc20_dispatcher
        .balance_of(cfg.pool_member_info.reward_address);

    cheat_caller_address(
        contract_address: pool_contract,
        caller_address: cfg.test_info.pool_member_address,
        span: CheatSpan::TargetCalls(3)
    );
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    pool_dispatcher.exit_delegation_pool_intent(amount: cfg.pool_member_info.amount);
    let amount_left = pool_dispatcher
        .switch_delegation_pool(
            to_staker: OTHER_STAKER_ADDRESS(),
            to_pool: to_staker_pool_contract,
            amount: switch_amount
        );
    let actual_pool_member_info: Option<PoolMemberInfo> = load_option_from_simple_map(
        map_selector: selector!("pool_member_info"),
        key: cfg.test_info.pool_member_address,
        contract: pool_contract
    );
    let expected_pool_member_info = PoolMemberInfo {
        amount: Zero::zero(),
        unpool_amount: cfg.pool_member_info.amount - switch_amount,
        unclaimed_rewards: unclaimed_rewards_member,
        index: updated_index,
        ..cfg.pool_member_info
    };
    assert_eq!(amount_left, cfg.pool_member_info.amount - switch_amount);
    assert_eq!(actual_pool_member_info, Option::Some(expected_pool_member_info));
    let mut spy = snforge_std::spy_events();
    let amount_left = pool_dispatcher
        .switch_delegation_pool(
            to_staker: OTHER_STAKER_ADDRESS(),
            to_pool: to_staker_pool_contract,
            amount: switch_amount
        );
    let actual_pool_member_info: Option<PoolMemberInfo> = load_option_from_simple_map(
        map_selector: selector!("pool_member_info"),
        key: cfg.test_info.pool_member_address,
        contract: pool_contract
    );
    assert_eq!(amount_left, 0);
    assert!(actual_pool_member_info.is_none());
    let reward_account_balance_after = erc20_dispatcher
        .balance_of(cfg.pool_member_info.reward_address);
    assert_eq!(
        reward_account_balance_after,
        reward_account_balance_before + unclaimed_rewards_member.into()
    );
    // Validate the single DeletePoolMember event emitted by the from_pool.
    let events = spy.get_events().emitted_by(contract_address: pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "switch_delegation_pool");
    assert_delete_pool_member_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
    );
}

#[test]
#[should_panic(expected: ("Pool member does not exist.",))]
fn test_claim_rewards_pool_member_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        :token_address,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    state.claim_rewards(pool_member: NON_POOL_MEMBER_ADDRESS());
}

#[test]
#[should_panic(
    expected: ("Claim rewards must be called from pool member address or reward address.",)
)]
fn test_claim_rewards_unauthorized_address() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: NON_POOL_MEMBER_ADDRESS()
    );
    pool_dispatcher.claim_rewards(cfg.test_info.pool_member_address);
}

#[test]
fn test_enter_delegation_pool_from_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let mut spy = snforge_std::spy_events();
    let pool_member = cfg.test_info.pool_member_address;
    let reward_address = cfg.pool_member_info.reward_address;

    // Serialize the switch pool data.
    let switch_pool_data = SwitchPoolData { pool_member, reward_address };
    let mut data = array![];
    switch_pool_data.serialize(ref data);
    let data = data.span();

    // Enter with a new pool member.
    let amount = cfg.pool_member_info.amount;
    let index = cfg.pool_member_info.index;
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    assert!(pool_dispatcher.enter_delegation_pool_from_staking_contract(:amount, :index, :data));

    let pool_member_info = pool_dispatcher.state_of(:pool_member);
    let expected_pool_member_info = PoolMemberInfo {
        reward_address,
        amount,
        index,
        unclaimed_rewards: Zero::zero(),
        unpool_time: Option::None,
        unpool_amount: Zero::zero(),
    };
    assert_eq!(pool_member_info, expected_pool_member_info);

    // Enter with an existing pool member.
    let updated_index = index * 2;
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    assert!(
        pool_dispatcher
            .enter_delegation_pool_from_staking_contract(:amount, index: updated_index, :data)
    );
    let pool_member_info = pool_dispatcher.state_of(:pool_member);
    let updated_amount = amount * 2;
    let interest = updated_index - index;
    let rewards_including_commission = compute_rewards_rounded_down(:amount, :interest);
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let expected_pool_member_info = PoolMemberInfo {
        reward_address,
        amount: updated_amount,
        index: updated_index,
        unclaimed_rewards: rewards_including_commission - commission_amount,
        unpool_time: Option::None,
        unpool_amount: Zero::zero(),
    };
    assert_eq!(pool_member_info, expected_pool_member_info);

    // Validate two DelegationPoolMemberBalanceChanged events.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "enter_delegation_pool_from_staking_contract"
    );
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[0],
        :pool_member,
        old_delegated_stake: Zero::zero(),
        new_delegated_stake: amount
    );
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[1],
        :pool_member,
        old_delegated_stake: amount,
        new_delegated_stake: updated_amount
    );
}

#[test]
fn test_contract_parameters() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let expected_pool_contract_info = PoolContractInfo {
        staker_address: cfg.test_info.staker_address,
        final_staker_index: Option::None,
        staking_contract,
        token_address,
        commission: cfg.staker_info.get_pool_info_unchecked().commission,
    };
    assert_eq!(pool_dispatcher.contract_parameters(), expected_pool_contract_info);
}

#[test]
fn test_update_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };

    let parameters_before_update = pool_dispatcher.contract_parameters();
    let ecpected_parameters_before_update = PoolContractInfo {
        commission: cfg.staker_info.get_pool_info_unchecked().commission, ..parameters_before_update
    };
    assert_eq!(parameters_before_update, ecpected_parameters_before_update);

    let commission = cfg.staker_info.get_pool_info_unchecked().commission - 1;
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    assert!(pool_dispatcher.update_commission(:commission));

    let parameters_after_update = pool_dispatcher.contract_parameters();
    let expected_parameters_after_update = PoolContractInfo {
        commission, ..parameters_before_update
    };
    assert_eq!(parameters_after_update, expected_parameters_after_update);
}

#[test]
#[should_panic(expected: ("Caller is not staking contract.",))]
fn test_update_commission_caller_not_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: NOT_STAKING_CONTRACT_ADDRESS()
    );
    pool_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission);
}

#[test]
#[should_panic(expected: ("Commission cannot be increased.",))]
fn test_update_commission_with_higher_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    pool_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission + 1);
}

#[test]
fn test_partial_undelegate() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    // Create a variable that will be constant throughout the test, and will be the sum of the pool
    // member's amount and unpool amount.
    let total_pool_member_amount = cfg.pool_member_info.amount;
    // Make sure the pool member has unclaimed rewards to see it's updated.
    let (unclaimed_rewards_member, updated_index) = create_rewards_for_pool_member(ref :cfg);
    cheat_caller_address(
        contract_address: pool_contract,
        caller_address: cfg.test_info.pool_member_address,
        span: CheatSpan::TargetCalls(3)
    );
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };

    // Intent half the amount.
    let intent_amount = cfg.pool_member_info.amount / 2;
    pool_dispatcher.exit_delegation_pool_intent(amount: intent_amount);
    cfg.pool_member_info.unpool_amount = intent_amount;
    cfg.pool_member_info.amount = total_pool_member_amount - intent_amount;
    let actual_pool_member_info: Option<PoolMemberInfo> = load_pool_member_info_from_map(
        key: cfg.test_info.pool_member_address, contract: pool_contract
    );
    let expected_time = get_block_timestamp()
        + staking_dispatcher.contract_parameters().exit_wait_window;
    let expected_pool_member_info = PoolMemberInfo {
        unclaimed_rewards: unclaimed_rewards_member,
        index: updated_index,
        unpool_time: Option::Some(expected_time),
        ..cfg.pool_member_info
    };
    assert_eq!(actual_pool_member_info, Option::Some(expected_pool_member_info));
    // Validate that the data is written in the exit intents map in staking contract.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract
    );
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_pool_member_info.unpool_time.expect('unpool_time is None'),
        amount: expected_pool_member_info.unpool_amount
    };
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);

    let staker_info = staking_dispatcher.state_of(cfg.test_info.staker_address);
    assert_eq!(staker_info.get_pool_info_unchecked().amount, cfg.pool_member_info.amount);

    // Intent 0 and see that the unpool_time is now optional.
    let intent_amount = Zero::zero();
    pool_dispatcher.exit_delegation_pool_intent(amount: intent_amount);
    cfg.pool_member_info.unpool_amount = intent_amount;
    cfg.pool_member_info.amount = total_pool_member_amount - intent_amount;
    let actual_pool_member_info: Option<PoolMemberInfo> = load_pool_member_info_from_map(
        key: cfg.test_info.pool_member_address, contract: pool_contract
    );
    let expected_pool_member_info = PoolMemberInfo {
        unclaimed_rewards: unclaimed_rewards_member,
        index: updated_index,
        unpool_time: Option::None,
        ..cfg.pool_member_info
    };
    assert_eq!(actual_pool_member_info, Option::Some(expected_pool_member_info));
    // Validate that the intent is removed from the exit intents map in staking contract.
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract
    );
    let expected_undelegate_intent_value: UndelegateIntentValue = Zero::zero();
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);
    let staker_info = staking_dispatcher.state_of(cfg.test_info.staker_address);
    assert_eq!(staker_info.get_pool_info_unchecked().amount, cfg.pool_member_info.amount);
}
