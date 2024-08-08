use core::serde::Serde;
use core::option::OptionTrait;
use contracts::staking::interface::{IStaking, IStakingDispatcher, IStakingDispatcherTrait};
use contracts::pooling::interface::{IPooling, IPoolingDispatcher, IPoolingDispatcherTrait};
use contracts::{
    constants::{BASE_VALUE, EXIT_WAITING_WINDOW},
    pooling::{
        Pooling, PoolMemberInfo,
        Pooling::{
            // TODO(Nir, 15/07/2024): Remove member module use's when possible
            __member_module_staker_address::InternalContractMemberStateTrait as StakerAddressMemberModule,
            __member_module_pool_member_info::InternalContractMemberStateTrait as PoolMemberToInfoModule,
            __member_module_final_staker_index::InternalContractMemberStateTrait as StakerFinalIndexModule,
            InternalPoolingFunctionsTrait
        }
    },
    staking::interface::StakerInfo,
    staking::Staking::{
        __member_module_global_index::InternalContractMemberStateTrait as GlobalIndexMemberModule,
        UndelegateIntentKey, UndelegateIntentValue
    },
    utils::{compute_rewards, compute_commission},
    test_utils::{
        initialize_pooling_state, deploy_mock_erc20_contract, StakingInitConfig,
        deploy_staking_contract, fund, approve, initialize_staking_state_from_cfg,
        stake_for_testing_using_dispatcher, enter_delegation_pool_for_testing_using_dispatcher,
        stake_with_pooling_enabled, load_from_simple_map, load_option_from_simple_map,
    },
    test_utils::constants::{
        OWNER_ADDRESS, STAKER_ADDRESS, STAKER_REWARD_ADDRESS, STAKE_AMOUNT, POOL_MEMBER_ADDRESS,
        STAKING_CONTRACT_ADDRESS, TOKEN_ADDRESS, INITIAL_SUPPLY, DUMMY_ADDRESS,
        OTHER_REWARD_ADDRESS, NON_POOL_MEMBER_ADDRESS, REV_SHARE, POOL_MEMBER_REWARD_ADDRESS,
        STAKER_FINAL_INDEX, NOT_STAKING_CONTRACT_ADDRESS, OTHER_STAKER_ADDRESS,
        OTHER_POOL_CONTRACT_ADDRESS,
    }
};
use contracts::event_test_utils::{assert_number_of_events, assert_pool_member_exit_intent_event,};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp, Store};
use snforge_std::{cheat_caller_address, CheatSpan, test_address};
use snforge_std::cheatcodes::events::{
    Event, Events, EventSpy, EventSpyTrait, is_emitted, EventsFilterTrait
};


#[test]
fn test_calculate_rewards() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        :token_address,
        rev_share: cfg.staker_info.rev_share
    );

    let updated_index: u64 = cfg.staker_info.index * 2;
    let mut pool_member_info = PoolMemberInfo {
        reward_address: cfg.staker_info.reward_address,
        amount: cfg.staker_info.amount_own,
        index: cfg.staker_info.index,
        unclaimed_rewards: cfg.staker_info.unclaimed_rewards_pool,
        unpool_time: Option::None,
    };
    let interest = updated_index - pool_member_info.index;
    let rewards = compute_rewards(amount: pool_member_info.amount, :interest);
    let commission = compute_commission(:rewards, rev_share: cfg.staker_info.rev_share);
    let unclaimed_rewards = rewards - commission;
    assert!(state.calculate_rewards(ref :pool_member_info, :updated_index));

    let mut expected_pool_member_info = PoolMemberInfo {
        index: cfg.staker_info.index * 2, unclaimed_rewards, ..pool_member_info
    };
    assert_eq!(pool_member_info, expected_pool_member_info);
}

#[test]
fn test_calculate_rewards_after_unpool_intent() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        :token_address,
        rev_share: cfg.staker_info.rev_share
    );

    let updated_index: u64 = cfg.staker_info.index * 2;

    let mut pool_member_info = PoolMemberInfo {
        reward_address: cfg.staker_info.reward_address,
        amount: cfg.staker_info.amount_pool,
        index: cfg.staker_info.index,
        unclaimed_rewards: cfg.staker_info.unclaimed_rewards_pool,
        unpool_time: Option::Some(1)
    };
    assert!(!state.calculate_rewards(ref :pool_member_info, :updated_index));
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
    let pooling_contract = stake_with_pooling_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pooling_contract, :cfg, :token_address);

    // Check that the pool member info was updated correctly.
    let expected_pool_member_info: PoolMemberInfo = PoolMemberInfo {
        amount: cfg.pool_member_info.amount,
        index: cfg.pool_member_info.index,
        unpool_time: Option::None,
        reward_address: cfg.pool_member_info.reward_address,
        unclaimed_rewards: cfg.pool_member_info.unclaimed_rewards,
    };
    let pooling_dispatcher = IPoolingDispatcher { contract_address: pooling_contract };
    assert_eq!(
        pooling_dispatcher.state_of(cfg.test_info.pool_member_address), expected_pool_member_info
    );
    // Check that all the pool amount was transferred to the staking contract.
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = erc20_dispatcher.balance_of(staking_contract);
    assert_eq!(balance, cfg.staker_info.amount_own.into() + cfg.pool_member_info.amount.into());
    let balance = erc20_dispatcher.balance_of(pooling_contract);
    assert_eq!(balance, 0);
    // Check that the staker info was updated correctly.
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let expected_staker_info = StakerInfo {
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        pooling_contract: Option::Some(pooling_contract),
        unstake_time: Option::None,
        amount_own: cfg.staker_info.amount_own,
        amount_pool: cfg.pool_member_info.amount,
        index: cfg.staker_info.index,
        unclaimed_rewards_own: 0,
        unclaimed_rewards_pool: 0,
        rev_share: cfg.staker_info.rev_share,
    };
    assert_eq!(staking_dispatcher.state_of(cfg.test_info.staker_address), expected_staker_info);
}

#[test]
fn test_assert_staker_is_active() {
    let mut state = initialize_pooling_state(
        staker_address: STAKER_ADDRESS(),
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: TOKEN_ADDRESS(),
        rev_share: REV_SHARE
    );
    assert!(state.final_staker_index.read().is_none());
    state.assert_staker_is_active();
}

#[test]
#[should_panic(expected: ("Staker inactive.",))]
fn test_assert_staker_is_active_panic() {
    let mut state = initialize_pooling_state(
        staker_address: STAKER_ADDRESS(),
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: TOKEN_ADDRESS(),
        rev_share: REV_SHARE
    );
    state.final_staker_index.write(Option::Some(5));
    state.assert_staker_is_active();
}

#[test]
fn test_set_final_staker_index() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        rev_share: cfg.staker_info.rev_share
    );
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: STAKING_CONTRACT_ADDRESS(),
        span: CheatSpan::TargetCalls(1)
    );
    assert!(state.final_staker_index.read().is_none());
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
    assert_eq!(state.final_staker_index.read().unwrap(), STAKER_FINAL_INDEX);
}

#[test]
#[should_panic(expected: "Caller is not staking contract.")]
fn test_set_final_staker_index_caller_is_not_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        rev_share: cfg.staker_info.rev_share
    );
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: NOT_STAKING_CONTRACT_ADDRESS(),
        span: CheatSpan::TargetCalls(1)
    );
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
}

#[test]
#[should_panic(expected: "Final staker index already set.")]
fn test_set_final_staker_index_already_set() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        rev_share: cfg.staker_info.rev_share
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
    let pooling_contract = stake_with_pooling_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pooling_contract, :cfg, :token_address);

    let pooling_dispatcher = IPoolingDispatcher { contract_address: pooling_contract };
    let pool_member_info_before_change = pooling_dispatcher
        .state_of(cfg.test_info.pool_member_address);
    let other_reward_address = OTHER_REWARD_ADDRESS();

    cheat_caller_address(
        pooling_contract, cfg.test_info.pool_member_address, CheatSpan::TargetCalls(1)
    );
    pooling_dispatcher.change_reward_address(other_reward_address);
    let pool_member_info_after_change = pooling_dispatcher
        .state_of(cfg.test_info.pool_member_address);
    let pool_member_info_expected = PoolMemberInfo {
        reward_address: other_reward_address, ..pool_member_info_before_change
    };
    assert_eq!(pool_member_info_after_change, pool_member_info_expected);
}


#[test]
#[should_panic(expected: "Pool member does not exist.")]
fn test_change_reward_address_pool_member_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        :staking_contract,
        :token_address,
        rev_share: cfg.staker_info.rev_share
    );
    cheat_caller_address(test_address(), NON_POOL_MEMBER_ADDRESS(), CheatSpan::TargetCalls(1));
    // Reward address is arbitrary because it should fail because of the caller.
    state.change_reward_address(reward_address: DUMMY_ADDRESS());
}

#[test]
fn test_claim_rewards() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pooling_contract = stake_with_pooling_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pooling_contract, :cfg, :token_address);

    let pooling_dispatcher = IPoolingDispatcher { contract_address: pooling_contract };
    // Check that the pool member info was updated correctly.
    assert_eq!(
        pooling_dispatcher.state_of(cfg.test_info.pool_member_address), cfg.pool_member_info
    );

    // Update index for testing.
    // TODO: Wrap in a function.
    let updated_index: u64 = cfg.staker_info.index * 2;
    snforge_std::store(
        staking_contract, selector!("global_index"), array![updated_index.into()].span()
    );

    // Claim rewards, and validate the results.
    cheat_caller_address(
        pooling_contract, cfg.test_info.pool_member_address, CheatSpan::TargetCalls(1)
    );
    let actual_reward: u128 = pooling_dispatcher.claim_rewards(cfg.test_info.pool_member_address);
    let interest: u64 = updated_index - cfg.staker_info.index;
    let rewards = compute_rewards(amount: cfg.pool_member_info.amount, :interest);
    let commission = compute_commission(:rewards, rev_share: cfg.staker_info.rev_share);
    assert_eq!(actual_reward, rewards - commission);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = erc20_dispatcher.balance_of(cfg.pool_member_info.reward_address);
    assert_eq!(balance, actual_reward.into());
}

#[test]
fn test_exit_delegation_pool_intent() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pooling_contract = stake_with_pooling_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pooling_contract, :cfg, :token_address);

    // Exit delegation pool intent, and validate the results.
    let mut spy = snforge_std::spy_events();
    cheat_caller_address(
        pooling_contract, cfg.test_info.pool_member_address, CheatSpan::TargetCalls(1)
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pooling_dispatcher = IPoolingDispatcher { contract_address: pooling_contract };
    pooling_dispatcher.exit_delegation_pool_intent();
    // Validate the expected pool member info and staker info.
    let expected_time = get_block_timestamp() + EXIT_WAITING_WINDOW;
    let expected_pool_member_info = PoolMemberInfo {
        unpool_time: Option::Some(expected_time), ..cfg.pool_member_info
    };
    assert_eq!(
        pooling_dispatcher.state_of(cfg.test_info.pool_member_address), expected_pool_member_info
    );
    let expected_staker_info = StakerInfo {
        amount_pool: 0,
        amount_own: cfg.staker_info.amount_own,
        pooling_contract: Option::Some(pooling_contract),
        ..cfg.staker_info
    };
    assert_eq!(staking_dispatcher.state_of(cfg.test_info.staker_address), expected_staker_info);
    // Validate that the data is written in the exit intents map in staking contract.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pooling_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract
    );
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_pool_member_info.unpool_time.expect('unpool_time is None'),
        amount: expected_pool_member_info.amount.into()
    };
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);

    // Validate the single PoolMemberExitIntent event.
    let events = spy.get_events().emitted_by(pooling_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "exit_delegation_pool_intent"
    );
    assert_pool_member_exit_intent_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        exit_at: expected_time
    );
}

// TODO: add event test.
#[test]
fn test_switch_delegation_pool() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pooling_contract = stake_with_pooling_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pooling_contract, :cfg, :token_address);

    cheat_caller_address(
        pooling_contract, cfg.test_info.pool_member_address, CheatSpan::TargetCalls(3)
    );
    let pooling_dispatcher = IPoolingDispatcher { contract_address: pooling_contract };
    pooling_dispatcher.exit_delegation_pool_intent();
    let switch_amount = cfg.pool_member_info.amount / 2;
    let amount_left = pooling_dispatcher
        .switch_delegation_pool(
            to_staker: OTHER_STAKER_ADDRESS(),
            to_pool: OTHER_POOL_CONTRACT_ADDRESS(),
            amount: switch_amount
        );
    let actual_pool_member_info: Option<PoolMemberInfo> = load_option_from_simple_map(
        map_selector: selector!("pool_member_info"),
        key: cfg.test_info.pool_member_address,
        contract: pooling_contract
    );
    let expected_pool_member_info = PoolMemberInfo {
        amount: cfg.pool_member_info.amount - switch_amount, ..cfg.pool_member_info
    };
    assert_eq!(amount_left, cfg.pool_member_info.amount - switch_amount);
    assert_eq!(actual_pool_member_info, Option::Some(expected_pool_member_info));

    let amount_left = pooling_dispatcher
        .switch_delegation_pool(
            to_staker: OTHER_STAKER_ADDRESS(),
            to_pool: OTHER_POOL_CONTRACT_ADDRESS(),
            amount: switch_amount
        );
    let actual_pool_member_info: Option<PoolMemberInfo> = load_option_from_simple_map(
        map_selector: selector!("pool_member_info"),
        key: cfg.test_info.pool_member_address,
        contract: pooling_contract
    );
    assert_eq!(amount_left, 0);
    assert!(actual_pool_member_info.is_none());
}

#[test]
#[should_panic(expected: ("Pool member does not exist.",))]
fn test_claim_rewards_pool_member_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        :token_address,
        rev_share: cfg.staker_info.rev_share
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
    let pooling_contract = stake_with_pooling_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pooling_contract, :cfg, :token_address);

    let pooling_dispatcher = IPoolingDispatcher { contract_address: pooling_contract };
    cheat_caller_address(
        contract_address: pooling_contract,
        caller_address: NON_POOL_MEMBER_ADDRESS(),
        span: CheatSpan::TargetCalls(1)
    );
    pooling_dispatcher.claim_rewards(cfg.test_info.pool_member_address);
}

