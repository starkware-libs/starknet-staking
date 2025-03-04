use Pool::{
    CONTRACT_IDENTITY as pool_identity, CONTRACT_VERSION as pool_version,
    InternalPoolFunctionsTrait,
};
use constants::{
    COMMISSION, DUMMY_ADDRESS, NON_POOL_MEMBER_ADDRESS, NOT_STAKING_CONTRACT_ADDRESS,
    OTHER_OPERATIONAL_ADDRESS, OTHER_REWARD_ADDRESS, OTHER_STAKER_ADDRESS, POOL_CONTRACT_ADMIN,
    POOL_MEMBER_ADDRESS, POOL_MEMBER_UNCLAIMED_REWARDS, STAKER_ADDRESS, STAKER_FINAL_INDEX,
    STAKING_CONTRACT_ADDRESS, TOKEN_ADDRESS,
};
use contracts_commons::components::replaceability::interface::{EICData, ImplementationData};
use contracts_commons::errors::Describable;
use contracts_commons::test_utils::{
    assert_panic_with_error, cheat_caller_address_once, check_identity,
    set_account_as_upgrade_governor,
};
use contracts_commons::types::time::time::Time;
use core::num::traits::zero::Zero;
use core::option::OptionTrait;
use core::serde::Serde;
use event_test_utils::{
    assert_delegation_pool_member_balance_changed_event, assert_delete_pool_member_event,
    assert_new_pool_member_event, assert_number_of_events, assert_pool_member_exit_action_event,
    assert_pool_member_exit_intent_event, assert_pool_member_reward_address_change_event,
    assert_pool_member_reward_claimed_event, assert_staker_removed_event,
    assert_switch_delegation_pool_event,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_block_timestamp_global, test_address,
};
use staking::constants::BASE_VALUE;
use staking::errors::GenericError;
use staking::flow_test::utils::MainnetClassHashes::MAINNET_POOL_CLASS_HASH_V0;
use staking::flow_test::utils::upgrade_implementation;
use staking::pool::errors::Error;
use staking::pool::interface::{
    IPool, IPoolDispatcher, IPoolDispatcherTrait, IPoolMigrationDispatcher,
    IPoolMigrationDispatcherTrait, IPoolSafeDispatcher, IPoolSafeDispatcherTrait, PoolContractInfo,
    PoolMemberInfo,
};
use staking::pool::objects::{
    InternalPoolMemberInfoTestTrait, InternalPoolMemberInfoV1, SwitchPoolData,
    VInternalPoolMemberInfo, VInternalPoolMemberInfoTestTrait, VInternalPoolMemberInfoTrait,
    VStorageContractTest,
};
use staking::pool::pool::Pool;
use staking::staking::interface::{
    IStakingDispatcher, IStakingDispatcherTrait, StakerInfo, StakerInfoTrait, StakerPoolInfo,
};
use staking::staking::objects::{
    InternalStakerInfoLatestTrait, UndelegateIntentKey, UndelegateIntentValue,
    UndelegateIntentValueZero,
};
use staking::types::{Index, InternalPoolMemberInfoLatest};
use staking::{event_test_utils, test_utils};
use starknet::Store;
use starknet::class_hash::ClassHash;
use test_utils::{
    StakingInitConfig, approve, cheat_reward_for_reward_supplier, constants, declare_pool_contract,
    declare_pool_eic_contract, deploy_mock_erc20_contract, deploy_staking_contract,
    deserialize_option, enter_delegation_pool_for_testing_using_dispatcher, fund,
    general_contract_system_deployment, initialize_pool_state, load_from_simple_map,
    load_pool_member_info_from_map, stake_with_pool_enabled,
};

#[test]
fn test_identity() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    check_identity(pool_contract, pool_identity, pool_version);
}

#[test]
fn test_send_rewards_to_member() {
    // Initialize pool state.
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address,
    );
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        :token_address,
        commission: cfg.staker_info.get_pool_info().commission,
        governance_admin: cfg.test_info.pool_contract_admin,
    );
    // Setup pool_member_info and expected results before sending rewards.
    let unclaimed_rewards = POOL_MEMBER_UNCLAIMED_REWARDS;
    cfg.pool_member_info.unclaimed_rewards = unclaimed_rewards;
    fund(
        sender: cfg.test_info.owner_address,
        recipient: test_address(),
        amount: unclaimed_rewards,
        :token_address,
    );
    let member_balance_before_rewards = token_dispatcher
        .balance_of(account: cfg.pool_member_info.reward_address);
    let expected_pool_member_info = InternalPoolMemberInfoLatest {
        unclaimed_rewards: Zero::zero(), ..cfg.pool_member_info,
    };
    // Send rewards to pool member's reward address.
    state
        .send_rewards_to_member(
            ref pool_member_info: cfg.pool_member_info,
            pool_member: cfg.test_info.pool_member_address,
            :token_dispatcher,
        );
    // Check that unclaimed_rewards_own is set to zero and that the staker received the rewards.
    assert_eq!(expected_pool_member_info, cfg.pool_member_info);
    let member_balance_after_rewards = token_dispatcher
        .balance_of(account: cfg.pool_member_info.reward_address);
    assert_eq!(
        member_balance_after_rewards, member_balance_before_rewards + unclaimed_rewards.into(),
    );
}

#[test]
fn test_enter_delegation_pool() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let mut spy = snforge_std::spy_events();
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    // Check that the pool member info was updated correctly.
    let expected_pool_member_info: PoolMemberInfo = PoolMemberInfo {
        amount: cfg.pool_member_info._deprecated_amount,
        index: cfg.pool_member_info._deprecated_index,
        unpool_time: Option::None,
        reward_address: cfg.pool_member_info.reward_address,
        commission: cfg.pool_member_info.commission,
        unclaimed_rewards: cfg.pool_member_info.unclaimed_rewards,
        unpool_amount: Zero::zero(),
    };
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    assert_eq!(
        pool_dispatcher.pool_member_info(cfg.test_info.pool_member_address),
        expected_pool_member_info,
    );

    // Check that all the pool amount was transferred to the staking contract.
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = token_dispatcher.balance_of(staking_contract);
    assert_eq!(
        balance,
        cfg.staker_info._deprecated_amount_own.into()
            + cfg.pool_member_info._deprecated_amount.into(),
    );
    let balance = token_dispatcher.balance_of(pool_contract);
    assert_eq!(balance, 0);
    // Check that the staker info was updated correctly.
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let expected_staker_info = StakerInfo {
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        unstake_time: Option::None,
        amount_own: cfg.staker_info._deprecated_amount_own,
        index: cfg.staker_info.index,
        unclaimed_rewards_own: 0,
        pool_info: Option::Some(
            StakerPoolInfo {
                pool_contract,
                amount: cfg.pool_member_info._deprecated_amount,
                unclaimed_rewards: Zero::zero(),
                commission: cfg.staker_info.get_pool_info().commission,
            },
        ),
    };
    assert_eq!(staking_dispatcher.staker_info(cfg.test_info.staker_address), expected_staker_info);

    // Validate NewPoolMember and PoolMemberBalanceChanged events.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "enter_delegation_pool");
    assert_new_pool_member_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        staker_address: cfg.test_info.staker_address,
        reward_address: cfg.pool_member_info.reward_address,
        amount: cfg.pool_member_info._deprecated_amount,
    );
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[1],
        pool_member: cfg.test_info.pool_member_address,
        old_delegated_stake: Zero::zero(),
        new_delegated_stake: cfg.pool_member_info._deprecated_amount,
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_enter_delegation_pool_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_safe_dispatcher = IPoolSafeDispatcher { contract_address: pool_contract };
    let pool_member = cfg.test_info.pool_member_address;
    let reward_address = cfg.pool_member_info.reward_address;
    let amount = cfg.pool_member_info._deprecated_amount;

    // Catch STAKER_INACTIVE.
    snforge_std::store(pool_contract, selector!("staker_removed"), array![true.into()].span());
    let result = pool_safe_dispatcher.enter_delegation_pool(:reward_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::STAKER_INACTIVE.describe());
    snforge_std::store(pool_contract, selector!("staker_removed"), array![false.into()].span());

    // Catch AMOUNT_IS_ZERO.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    let result = pool_safe_dispatcher.enter_delegation_pool(:reward_address, amount: Zero::zero());
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_IS_ZERO.describe());

    // Catch POOL_MEMBER_EXISTS.
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    let result = pool_safe_dispatcher.enter_delegation_pool(:reward_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::POOL_MEMBER_EXISTS.describe());
}

#[test]
fn test_add_to_delegation_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };

    // Enter pool member to the delegation pool.
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let pool_member = cfg.test_info.pool_member_address;
    let pool_member_info = cfg.pool_member_info;
    let staker_info_before = staking_dispatcher
        .staker_info(staker_address: cfg.test_info.staker_address);

    // First pool member adds to the delegation pool.
    let pool_member_info_before_add = pool_dispatcher.pool_member_info(:pool_member);
    let delegate_amount = pool_member_info._deprecated_amount;
    approve(owner: pool_member, spender: pool_contract, amount: delegate_amount, :token_address);
    let mut spy = snforge_std::spy_events();
    let unclaimed_rewards_member =
        Zero::zero(); // TODO: Change this after implement calculate_rewards.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    pool_dispatcher.add_to_delegation_pool(:pool_member, amount: delegate_amount);
    let pool_member_info_after_add = pool_dispatcher.pool_member_info(:pool_member);
    let pool_member_info_expected = PoolMemberInfo {
        amount: pool_member_info_before_add.amount + delegate_amount,
        index: cfg.staking_contract_info.global_index,
        unclaimed_rewards: unclaimed_rewards_member,
        ..pool_member_info_before_add,
    };
    assert_eq!(pool_member_info_after_add, pool_member_info_expected);

    // Validate the single PoolMemberBalanceChanged event.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "add_to_delegation_pool");
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[0],
        pool_member: pool_member,
        old_delegated_stake: pool_member_info_before_add.amount,
        new_delegated_stake: pool_member_info_after_add.amount,
    );

    // Check staker info after first add to delegation pool.
    let staker_info_after = staking_dispatcher
        .staker_info(staker_address: cfg.test_info.staker_address);
    let mut expected_pool_info = staker_info_before.get_pool_info();
    expected_pool_info.amount += delegate_amount;
    expected_pool_info.unclaimed_rewards = Zero::zero();
    assert_eq!(expected_pool_info, staker_info_after.get_pool_info());
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let pool_balance = token_dispatcher.balance_of(pool_contract);
    assert!(pool_balance >= unclaimed_rewards_member.into());
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_to_delegation_pool_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let pool_safe_dispatcher = IPoolSafeDispatcher { contract_address: pool_contract };
    let pool_member = cfg.test_info.pool_member_address;
    let amount = 1;

    // Catch STAKER_INACTIVE.
    snforge_std::store(pool_contract, selector!("staker_removed"), array![true.into()].span());
    let result = pool_safe_dispatcher.add_to_delegation_pool(:pool_member, :amount);
    assert_panic_with_error(:result, expected_error: Error::STAKER_INACTIVE.describe());
    snforge_std::store(pool_contract, selector!("staker_removed"), array![false.into()].span());

    // Catch POOL_MEMBER_DOES_NOT_EXIST.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    let result = pool_safe_dispatcher
        .add_to_delegation_pool(pool_member: NON_POOL_MEMBER_ADDRESS(), :amount);
    assert_panic_with_error(:result, expected_error: Error::POOL_MEMBER_DOES_NOT_EXIST.describe());

    // Catch CALLER_CANNOT_ADD_TO_POOL.
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: NON_POOL_MEMBER_ADDRESS(),
    );
    let result = pool_safe_dispatcher.add_to_delegation_pool(:pool_member, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_CANNOT_ADD_TO_POOL.describe());

    // Catch AMOUNT_IS_ZERO.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    let result = pool_safe_dispatcher.add_to_delegation_pool(:pool_member, amount: Zero::zero());
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_IS_ZERO.describe());
}

#[test]
fn test_add_to_delegation_pool_from_reward_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };

    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let pool_member = cfg.test_info.pool_member_address;
    let pool_member_info = cfg.pool_member_info;

    let pool_member_info_before_add = pool_dispatcher.pool_member_info(:pool_member);
    let unclaimed_rewards_member =
        Zero::zero(); // TODO: Change this after implement calculate_rewards.

    let delegate_amount = pool_member_info._deprecated_amount;
    fund(
        sender: cfg.test_info.owner_address,
        recipient: cfg.pool_member_info.reward_address,
        amount: delegate_amount,
        :token_address,
    );
    approve(
        owner: cfg.pool_member_info.reward_address,
        spender: pool_contract,
        amount: delegate_amount,
        :token_address,
    );
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.pool_member_info.reward_address,
    );
    pool_dispatcher.add_to_delegation_pool(:pool_member, amount: delegate_amount);

    let pool_member_info_after_add = pool_dispatcher.pool_member_info(:pool_member);
    let pool_member_info_expected = PoolMemberInfo {
        amount: pool_member_info_before_add.amount + delegate_amount,
        index: Zero::zero(),
        unclaimed_rewards: unclaimed_rewards_member,
        ..pool_member_info_before_add,
    };
    assert_eq!(pool_member_info_after_add, pool_member_info_expected);
}

#[test]
fn test_assert_staker_is_active() {
    let mut state = initialize_pool_state(
        staker_address: STAKER_ADDRESS(),
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: TOKEN_ADDRESS(),
        commission: COMMISSION,
        governance_admin: POOL_CONTRACT_ADMIN(),
    );
    assert!(state.staker_removed.read() == false);
    state.assert_staker_is_active();
}

#[test]
#[should_panic(expected: "Staker inactive")]
fn test_assert_staker_is_active_panic() {
    let mut state = initialize_pool_state(
        staker_address: STAKER_ADDRESS(),
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: TOKEN_ADDRESS(),
        commission: COMMISSION,
        governance_admin: POOL_CONTRACT_ADMIN(),
    );
    state.staker_removed.write(true);
    state.assert_staker_is_active();
}

#[test]
fn test_set_final_staker_index() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        commission: cfg.staker_info.get_pool_info().commission,
        governance_admin: cfg.test_info.pool_contract_admin,
    );
    cheat_caller_address_once(
        contract_address: test_address(), caller_address: STAKING_CONTRACT_ADDRESS(),
    );
    assert!(state.final_staker_index.read().is_none()); // TODO: Remove
    let mut spy = snforge_std::spy_events();
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
    assert_eq!(state.final_staker_index.read().unwrap(), STAKER_FINAL_INDEX); // TODO: Remove
    assert_eq!(state.staker_removed.read(), true);
    // Validate the single StakerRemoved event.
    let events = spy.get_events().emitted_by(contract_address: test_address()).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_final_staker_index");
    assert_staker_removed_event(
        spied_event: events[0], staker_address: cfg.test_info.staker_address,
    );
}

#[test]
#[should_panic(expected: "Caller is not staking contract")]
fn test_set_final_staker_index_caller_is_not_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        commission: cfg.staker_info.get_pool_info().commission,
        governance_admin: cfg.test_info.pool_contract_admin,
    );
    cheat_caller_address_once(
        contract_address: test_address(), caller_address: NOT_STAKING_CONTRACT_ADDRESS(),
    );
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
}

#[test]
#[should_panic(expected: "Staker already removed")]
fn test_set_final_staker_index_already_removed() {
    let cfg: StakingInitConfig = Default::default();
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: cfg.staking_contract_info.token_address,
        commission: cfg.staker_info.get_pool_info().commission,
        governance_admin: cfg.test_info.pool_contract_admin,
    );
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: STAKING_CONTRACT_ADDRESS(),
        span: CheatSpan::TargetCalls(2),
    );
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
    state.set_final_staker_index(final_staker_index: STAKER_FINAL_INDEX);
}

#[test]
fn test_change_reward_address() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let pool_member_info_before_change = pool_dispatcher
        .pool_member_info(cfg.test_info.pool_member_address);
    let other_reward_address = OTHER_REWARD_ADDRESS();

    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address,
    );
    let mut spy = snforge_std::spy_events();
    pool_dispatcher.change_reward_address(other_reward_address);
    let pool_member_info_after_change = pool_dispatcher
        .pool_member_info(cfg.test_info.pool_member_address);
    let pool_member_info_expected = PoolMemberInfo {
        reward_address: other_reward_address, ..pool_member_info_before_change,
    };
    assert_eq!(pool_member_info_after_change, pool_member_info_expected);
    // Validate the single PoolMemberRewardAddressChanged event.
    let events = spy.get_events().emitted_by(contract_address: pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "change_reward_address");
    assert_pool_member_reward_address_change_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        new_address: other_reward_address,
        old_address: cfg.pool_member_info.reward_address,
    );
}


#[test]
#[should_panic(expected: "Pool member does not exist")]
fn test_change_reward_address_pool_member_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        :staking_contract,
        :token_address,
        commission: cfg.staker_info.get_pool_info().commission,
        governance_admin: cfg.test_info.pool_contract_admin,
    );
    cheat_caller_address_once(
        contract_address: test_address(), caller_address: NON_POOL_MEMBER_ADDRESS(),
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
    let mut expected_pool_member_info: PoolMemberInfo = cfg.pool_member_info.into();
    assert_eq!(
        pool_dispatcher.pool_member_info(cfg.test_info.pool_member_address),
        expected_pool_member_info,
    );
    // Update index for testing.
    let updated_index: Index = cfg.staker_info.index + BASE_VALUE;
    snforge_std::store(
        staking_contract, selector!("global_index"), array![updated_index.into()].span(),
    );
    // Compute expected rewards.
    let expected_reward = Zero::zero(); // TODO: Change this after implement calculate_rewards.
    cheat_reward_for_reward_supplier(:cfg, :reward_supplier, :expected_reward, :token_address);
    // Claim rewards, and validate the results.
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address,
    );
    let mut spy = snforge_std::spy_events();
    let actual_reward = pool_dispatcher
        .claim_rewards(pool_member: cfg.test_info.pool_member_address);
    assert_eq!(actual_reward, expected_reward);
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = token_dispatcher.balance_of(cfg.pool_member_info.reward_address);
    assert_eq!(balance, actual_reward.into());
    // Validate the single PoolMemberRewardClaimed event.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "claim_rewards");
    assert_pool_member_reward_claimed_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
        amount: actual_reward,
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
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    pool_dispatcher.exit_delegation_pool_intent(amount: cfg.pool_member_info._deprecated_amount);
    // Validate the expected pool member info and staker info.
    let expected_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters().exit_wait_window);
    let mut expected_pool_member_info = InternalPoolMemberInfoLatest {
        _deprecated_amount: Zero::zero(),
        unpool_amount: cfg.pool_member_info._deprecated_amount,
        unpool_time: Option::Some(expected_time),
        ..cfg.pool_member_info,
    };
    let mut expected_pool_member_info: PoolMemberInfo = expected_pool_member_info.into();
    assert_eq!(
        pool_dispatcher.pool_member_info(cfg.test_info.pool_member_address),
        expected_pool_member_info,
    );
    let mut expected_staker_info: StakerInfo = cfg.staker_info.into();
    if let Option::Some(mut pool_info) = expected_staker_info.pool_info {
        pool_info.amount = Zero::zero();
        pool_info.pool_contract = pool_contract;
        expected_staker_info.pool_info = Option::Some(pool_info);
    }
    assert_eq!(staking_dispatcher.staker_info(cfg.test_info.staker_address), expected_staker_info);
    // Validate that the data is written in the exit intents map in staking contract.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_pool_member_info.unpool_time.expect('unpool_time is None'),
        amount: expected_pool_member_info.unpool_amount.into(),
    };
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);

    // Validate the single PoolMemberExitIntent event.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "exit_delegation_pool_intent",
    );
    assert_pool_member_exit_intent_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        exit_timestamp: expected_time,
        amount: cfg.pool_member_info._deprecated_amount,
    );
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[1],
        pool_member: cfg.test_info.pool_member_address,
        old_delegated_stake: cfg.pool_member_info._deprecated_amount,
        new_delegated_stake: Zero::zero(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_exit_delegation_pool_intent_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let pool_safe_dispatcher = IPoolSafeDispatcher { contract_address: pool_contract };
    let pool_member = cfg.test_info.pool_member_address;
    let amount = 1;

    // Catch POOL_MEMBER_DOES_NOT_EXIST.
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: NON_POOL_MEMBER_ADDRESS(),
    );
    let result = pool_safe_dispatcher.exit_delegation_pool_intent(:amount);
    assert_panic_with_error(:result, expected_error: Error::POOL_MEMBER_DOES_NOT_EXIST.describe());

    // Catch AMOUNT_TOO_HIGH.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    let result = pool_safe_dispatcher
        .exit_delegation_pool_intent(amount: cfg.pool_member_info._deprecated_amount + 1);
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_TOO_HIGH.describe());

    // Catch UNDELEGATE_IN_PROGRESS.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    pool_dispatcher.exit_delegation_pool_intent(:amount);
    snforge_std::store(pool_contract, selector!("staker_removed"), array![true.into()].span());
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    let result = pool_safe_dispatcher.exit_delegation_pool_intent(:amount);
    assert_panic_with_error(:result, expected_error: Error::UNDELEGATE_IN_PROGRESS.describe());
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
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    // Change global index and exit delegation pool intent.
    let updated_index = cfg.pool_member_info._deprecated_index + BASE_VALUE;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span(),
    );
    // Calculate the expected rewards and commission.
    let delegate_amount = cfg.pool_member_info._deprecated_amount;
    let unclaimed_rewards_member =
        Zero::zero(); // TODO: Change this after implement calculate_rewards.
    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards_member, :token_address,
    );
    // Exit delegation pool intent.
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address,
    );
    pool_dispatcher.exit_delegation_pool_intent(amount: delegate_amount);

    let balance_before_action = token_dispatcher.balance_of(cfg.test_info.pool_member_address);
    let reward_account_balance_before = token_dispatcher
        .balance_of(cfg.pool_member_info.reward_address);
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now()
            .add(delta: staking_dispatcher.contract_parameters().exit_wait_window)
            .into(),
    );
    // Exit delegation pool action and check that:
    // 1. The returned value is correct.
    // 2. The pool member is erased from the pool member info map.
    // 3. The pool amount was transferred back to the pool member.
    // 4. The unclaimed rewards were transferred to the reward account.
    let mut spy = snforge_std::spy_events();
    let returned_amount = pool_dispatcher
        .exit_delegation_pool_action(pool_member: cfg.test_info.pool_member_address);
    assert_eq!(returned_amount, cfg.pool_member_info._deprecated_amount);
    let pool_member: VInternalPoolMemberInfo = load_pool_member_info_from_map(
        key: cfg.test_info.pool_member_address, contract: pool_contract,
    );
    assert!(pool_member.is_none());
    let balance_after_action = token_dispatcher.balance_of(cfg.test_info.pool_member_address);
    let reward_account_balance_after = token_dispatcher
        .balance_of(cfg.pool_member_info.reward_address);
    assert_eq!(
        balance_after_action,
        balance_before_action + cfg.pool_member_info._deprecated_amount.into(),
    );
    assert_eq!(
        reward_account_balance_after,
        reward_account_balance_before + unclaimed_rewards_member.into(),
    );
    // Validate the PoolMemberExitAction, PoolMemberRewardClaimed and DeletePoolMember events.
    let events = spy.get_events().emitted_by(contract_address: pool_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 3, message: "exit_delegation_pool_action",
    );
    assert_pool_member_exit_action_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        unpool_amount: delegate_amount,
    );
    assert_pool_member_reward_claimed_event(
        spied_event: events[1],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
        amount: unclaimed_rewards_member,
    );
    assert_delete_pool_member_event(
        spied_event: events[2],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_exit_delegation_pool_action_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let pool_safe_dispatcher = IPoolSafeDispatcher { contract_address: pool_contract };
    let pool_member = cfg.test_info.pool_member_address;
    let amount = 1;

    // Catch POOL_MEMBER_DOES_NOT_EXIST.
    let result = pool_safe_dispatcher
        .exit_delegation_pool_action(pool_member: NON_POOL_MEMBER_ADDRESS());
    assert_panic_with_error(:result, expected_error: Error::POOL_MEMBER_DOES_NOT_EXIST.describe());

    // Catch MISSING_UNDELEGATE_INTENT.
    let result = pool_safe_dispatcher.exit_delegation_pool_action(:pool_member);
    assert_panic_with_error(:result, expected_error: Error::MISSING_UNDELEGATE_INTENT.describe());

    // Catch INTENT_WINDOW_NOT_FINISHED.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    pool_dispatcher.exit_delegation_pool_intent(:amount);
    let result = pool_safe_dispatcher.exit_delegation_pool_action(:pool_member);
    assert_panic_with_error(
        :result, expected_error: GenericError::INTENT_WINDOW_NOT_FINISHED.describe(),
    );
}

#[test]
fn test_switch_delegation_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    // Create other staker with pool.
    let switch_amount = cfg.pool_member_info._deprecated_amount / 2;
    cfg.test_info.staker_address = OTHER_STAKER_ADDRESS();
    cfg.staker_info.operational_address = OTHER_OPERATIONAL_ADDRESS();
    let to_staker_pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let unclaimed_rewards_member =
        Zero::zero(); // TODO: Change this after implement calculate_rewards.
    let reward_account_balance_before = token_dispatcher
        .balance_of(cfg.pool_member_info.reward_address);
    cheat_caller_address(
        contract_address: pool_contract,
        caller_address: cfg.test_info.pool_member_address,
        span: CheatSpan::TargetCalls(5),
    );
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    pool_dispatcher.exit_delegation_pool_intent(amount: cfg.pool_member_info._deprecated_amount);
    let pool_member_info_before_switch: PoolMemberInfo = pool_dispatcher
        .pool_member_info(pool_member: cfg.test_info.pool_member_address);
    let amount_left = pool_dispatcher
        .switch_delegation_pool(
            to_staker: OTHER_STAKER_ADDRESS(),
            to_pool: to_staker_pool_contract,
            amount: switch_amount,
        );
    let actual_pool_member_info: PoolMemberInfo = pool_dispatcher
        .pool_member_info(pool_member: cfg.test_info.pool_member_address);
    let expected_pool_member_info: PoolMemberInfo = PoolMemberInfo {
        unpool_amount: cfg.pool_member_info._deprecated_amount - switch_amount,
        ..pool_member_info_before_switch,
    };
    assert_eq!(amount_left, cfg.pool_member_info._deprecated_amount - switch_amount);
    assert_eq!(actual_pool_member_info, expected_pool_member_info);
    let mut spy = snforge_std::spy_events();
    let amount_left = pool_dispatcher
        .switch_delegation_pool(
            to_staker: OTHER_STAKER_ADDRESS(),
            to_pool: to_staker_pool_contract,
            amount: switch_amount,
        );
    let actual_pool_member_info: VInternalPoolMemberInfo = load_pool_member_info_from_map(
        key: cfg.test_info.pool_member_address, contract: pool_contract,
    );
    assert_eq!(amount_left, 0);
    assert!(actual_pool_member_info.is_none());
    let reward_account_balance_after = token_dispatcher
        .balance_of(cfg.pool_member_info.reward_address);
    assert_eq!(
        reward_account_balance_after,
        reward_account_balance_before + unclaimed_rewards_member.into(),
    );
    // Validate DeletePoolMember,PoolMemberRewardClaimed and SwitchDelegationPool events emitted by
    // the from_pool.
    let events = spy.get_events().emitted_by(contract_address: pool_contract).events;
    assert_number_of_events(actual: events.len(), expected: 3, message: "switch_delegation_pool");
    assert_pool_member_reward_claimed_event(
        spied_event: events[0],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
        amount: unclaimed_rewards_member,
    );
    assert_delete_pool_member_event(
        spied_event: events[1],
        pool_member: cfg.test_info.pool_member_address,
        reward_address: cfg.pool_member_info.reward_address,
    );
    assert_switch_delegation_pool_event(
        spied_event: events[2],
        pool_member: cfg.test_info.pool_member_address,
        new_delegation_pool: to_staker_pool_contract,
        amount: switch_amount,
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_switch_delegation_pool_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let from_pool = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: from_pool, :cfg, :token_address,
    );
    // Create other staker with pool.
    cfg.test_info.staker_address = OTHER_STAKER_ADDRESS();
    cfg.staker_info.operational_address = OTHER_OPERATIONAL_ADDRESS();
    let to_pool = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let switch_amount = cfg.pool_member_info._deprecated_amount / 2;
    let pool_dispatcher = IPoolDispatcher { contract_address: from_pool };
    let pool_safe_dispatcher = IPoolSafeDispatcher { contract_address: from_pool };
    let pool_member = cfg.test_info.pool_member_address;

    // Catch AMOUNT_IS_ZERO.
    cheat_caller_address_once(contract_address: from_pool, caller_address: pool_member);
    let result = pool_safe_dispatcher
        .switch_delegation_pool(to_staker: OTHER_STAKER_ADDRESS(), :to_pool, amount: Zero::zero());
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_IS_ZERO.describe());

    // Catch POOL_MEMBER_DOES_NOT_EXIST.
    cheat_caller_address_once(
        contract_address: from_pool, caller_address: NON_POOL_MEMBER_ADDRESS(),
    );
    let result = pool_safe_dispatcher
        .switch_delegation_pool(to_staker: OTHER_STAKER_ADDRESS(), :to_pool, amount: switch_amount);
    assert_panic_with_error(:result, expected_error: Error::POOL_MEMBER_DOES_NOT_EXIST.describe());

    // Catch MISSING_UNDELEGATE_INTENT.
    cheat_caller_address_once(contract_address: from_pool, caller_address: pool_member);
    let result = pool_safe_dispatcher
        .switch_delegation_pool(to_staker: OTHER_STAKER_ADDRESS(), :to_pool, amount: switch_amount);
    assert_panic_with_error(:result, expected_error: Error::MISSING_UNDELEGATE_INTENT.describe());

    // Catch AMOUNT_TOO_HIGH.
    cheat_caller_address_once(contract_address: from_pool, caller_address: pool_member);
    pool_dispatcher.exit_delegation_pool_intent(amount: switch_amount);
    cheat_caller_address_once(contract_address: from_pool, caller_address: pool_member);
    let result = pool_safe_dispatcher
        .switch_delegation_pool(
            to_staker: OTHER_STAKER_ADDRESS(), :to_pool, amount: switch_amount + 1,
        );
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_TOO_HIGH.describe());
}

#[test]
#[should_panic(expected: "Pool member does not exist")]
fn test_claim_rewards_pool_member_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let mut state = initialize_pool_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        :token_address,
        commission: cfg.staker_info.get_pool_info().commission,
        governance_admin: cfg.test_info.pool_contract_admin,
    );
    state.claim_rewards(pool_member: NON_POOL_MEMBER_ADDRESS());
}

#[test]
#[should_panic(expected: "Claim rewards must be called from pool member address or reward address")]
fn test_claim_rewards_unauthorized_address() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: NON_POOL_MEMBER_ADDRESS(),
    );
    pool_dispatcher.claim_rewards(cfg.test_info.pool_member_address);
}

#[test]
fn test_enter_delegation_pool_from_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
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
    let amount = cfg.pool_member_info._deprecated_amount;
    let index = cfg.pool_member_info._deprecated_index;
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    pool_dispatcher.enter_delegation_pool_from_staking_contract(:amount, :index, :data);

    let pool_member_info = pool_dispatcher.pool_member_info(:pool_member);
    let expected_pool_member_info = PoolMemberInfo {
        reward_address,
        amount,
        index,
        unclaimed_rewards: Zero::zero(),
        commission: cfg.pool_member_info.commission,
        unpool_time: Option::None,
        unpool_amount: Zero::zero(),
    };
    assert_eq!(pool_member_info, expected_pool_member_info);

    // Enter with an existing pool member.
    let updated_index = index + BASE_VALUE;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span(),
    );
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    pool_dispatcher
        .enter_delegation_pool_from_staking_contract(:amount, index: updated_index, :data);
    let pool_member_info = pool_dispatcher.pool_member_info(:pool_member);
    let updated_amount = amount * 2;
    let expected_reward = Zero::zero(); // TODO: Change this after implement calculate_rewards.
    let expected_pool_member_info = PoolMemberInfo {
        reward_address,
        amount: updated_amount,
        index,
        unclaimed_rewards: expected_reward,
        commission: cfg.pool_member_info.commission,
        unpool_time: Option::None,
        unpool_amount: Zero::zero(),
    };
    assert_eq!(pool_member_info, expected_pool_member_info);

    // Validate two PoolMemberBalanceChanged events.
    let events = spy.get_events().emitted_by(pool_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "enter_delegation_pool_from_staking_contract",
    );
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[0],
        :pool_member,
        old_delegated_stake: Zero::zero(),
        new_delegated_stake: amount,
    );
    assert_delegation_pool_member_balance_changed_event(
        spied_event: events[1],
        :pool_member,
        old_delegated_stake: amount,
        new_delegated_stake: updated_amount,
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_enter_delegation_pool_from_staking_contract_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Stake, and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let pool_safe_dispatcher = IPoolSafeDispatcher { contract_address: pool_contract };
    let pool_member = cfg.test_info.pool_member_address;
    let reward_address = cfg.pool_member_info.reward_address;
    let index = cfg.pool_member_info._deprecated_index;
    let switch_amount = cfg.pool_member_info._deprecated_amount / 2;

    // Serialize the switch pool data.
    let switch_pool_data = SwitchPoolData { pool_member, reward_address };
    let mut data = array![];
    switch_pool_data.serialize(ref data);
    let data = data.span();

    // Catch AMOUNT_IS_ZERO.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    let result = pool_safe_dispatcher
        .enter_delegation_pool_from_staking_contract(amount: Zero::zero(), :index, :data);
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_IS_ZERO.describe());

    // Catch CALLER_IS_NOT_STAKING_CONTRACT.
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: NOT_STAKING_CONTRACT_ADDRESS(),
    );
    let result = pool_safe_dispatcher
        .enter_delegation_pool_from_staking_contract(amount: switch_amount, :index, :data);
    assert_panic_with_error(
        :result, expected_error: GenericError::CALLER_IS_NOT_STAKING_CONTRACT.describe(),
    );

    // Catch SWITCH_POOL_DATA_DESERIALIZATION_FAILED.
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    let data = array![].span();
    let result = pool_safe_dispatcher
        .enter_delegation_pool_from_staking_contract(amount: switch_amount, :index, :data);
    assert_panic_with_error(
        :result, expected_error: Error::SWITCH_POOL_DATA_DESERIALIZATION_FAILED.describe(),
    );

    // Catch REWARD_ADDRESS_MISMATCH.
    let wrong_reward_address = DUMMY_ADDRESS();
    let switch_pool_data = SwitchPoolData { pool_member, reward_address: wrong_reward_address };
    let mut data = array![];
    switch_pool_data.serialize(ref data);
    let data = data.span();
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    let result = pool_safe_dispatcher
        .enter_delegation_pool_from_staking_contract(amount: switch_amount, :index, :data);
    assert_panic_with_error(:result, expected_error: Error::REWARD_ADDRESS_MISMATCH.describe());
}

#[test]
fn test_contract_parameters() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let expected_pool_contract_info = PoolContractInfo {
        staker_address: cfg.test_info.staker_address,
        final_staker_index: Option::None,
        staking_contract,
        token_address,
        commission: cfg.staker_info.get_pool_info().commission,
        staker_removed: false,
    };
    assert_eq!(pool_dispatcher.contract_parameters(), expected_pool_contract_info);
}

#[test]
fn test_update_commission_from_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };

    let parameters_before_update = pool_dispatcher.contract_parameters();
    let ecpected_parameters_before_update = PoolContractInfo {
        commission: cfg.staker_info.get_pool_info().commission, ..parameters_before_update,
    };
    assert_eq!(parameters_before_update, ecpected_parameters_before_update);

    let commission = cfg.staker_info.get_pool_info().commission - 1;
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    pool_dispatcher.update_commission_from_staking_contract(:commission);

    let parameters_after_update = pool_dispatcher.contract_parameters();
    let expected_parameters_after_update = PoolContractInfo {
        commission, ..parameters_before_update,
    };
    assert_eq!(parameters_after_update, expected_parameters_after_update);
}

#[test]
#[should_panic(expected: "Caller is not staking contract")]
fn test_update_commission_caller_not_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let commission = cfg.staker_info.get_pool_info().commission - 1;
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: NOT_STAKING_CONTRACT_ADDRESS(),
    );
    pool_dispatcher.update_commission_from_staking_contract(:commission);
}

#[test]
#[should_panic(expected: "Commission can only be decreased")]
fn test_update_commission_with_higher_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    pool_dispatcher
        .update_commission_from_staking_contract(
            commission: cfg.staker_info.get_pool_info().commission + 1,
        );
}

#[test]
#[should_panic(expected: "Commission can only be decreased")]
fn test_update_commission_with_same_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let parameters_before_update = pool_dispatcher.contract_parameters();
    cheat_caller_address_once(contract_address: pool_contract, caller_address: staking_contract);
    pool_dispatcher
        .update_commission_from_staking_contract(
            commission: cfg.staker_info.get_pool_info().commission,
        );
    let parameters_after_update = pool_dispatcher.contract_parameters();
    let expected_parameters_after_update = PoolContractInfo {
        commission: cfg.staker_info.get_pool_info().commission, ..parameters_before_update,
    };
    assert_eq!(parameters_after_update, expected_parameters_after_update);
}

#[test]
#[should_panic(expected: "Caller is not staking contract")]
fn test_update_rewards_from_staking_contract_caller_not_staking_contract() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: NOT_STAKING_CONTRACT_ADDRESS(),
    );
    pool_dispatcher.update_rewards_from_staking_contract(rewards: 1, pool_balance: 1000);
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
    let total_pool_member_amount = cfg.pool_member_info._deprecated_amount;
    // Make sure the pool member has unclaimed rewards to see it's updated.
    let unclaimed_rewards_member =
        Zero::zero(); // TODO: Change this after implement calculate_rewards.
    cheat_caller_address(
        contract_address: pool_contract,
        caller_address: cfg.test_info.pool_member_address,
        span: CheatSpan::TargetCalls(3),
    );
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };

    // Intent half the amount.
    let intent_amount = cfg.pool_member_info._deprecated_amount / 2;
    pool_dispatcher.exit_delegation_pool_intent(amount: intent_amount);
    cfg.pool_member_info.unpool_amount = intent_amount;
    cfg.pool_member_info._deprecated_amount = total_pool_member_amount - intent_amount;
    let actual_pool_member_info: PoolMemberInfo = pool_dispatcher
        .pool_member_info(pool_member: cfg.test_info.pool_member_address);
    let expected_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters().exit_wait_window);
    let expected_pool_member_info: PoolMemberInfo = InternalPoolMemberInfoLatest {
        unclaimed_rewards: unclaimed_rewards_member,
        unpool_time: Option::Some(expected_time),
        ..cfg.pool_member_info,
    }
        .into();
    assert_eq!(actual_pool_member_info, expected_pool_member_info);
    // Validate that the data is written in the exit intents map in staking contract.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_pool_member_info.unpool_time.expect('unpool_time is None'),
        amount: expected_pool_member_info.unpool_amount,
    };
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);

    let staker_info = staking_dispatcher.staker_info(cfg.test_info.staker_address);
    assert_eq!(staker_info.get_pool_info().amount, cfg.pool_member_info._deprecated_amount);

    // Intent 0 and see that the unpool_time is now optional.
    let intent_amount = Zero::zero();
    pool_dispatcher.exit_delegation_pool_intent(amount: intent_amount);
    cfg.pool_member_info.unpool_amount = intent_amount;
    cfg.pool_member_info._deprecated_amount = total_pool_member_amount - intent_amount;
    let actual_pool_member_info: PoolMemberInfo = pool_dispatcher
        .pool_member_info(pool_member: cfg.test_info.pool_member_address);
    let expected_pool_member_info: PoolMemberInfo = InternalPoolMemberInfoLatest {
        unclaimed_rewards: unclaimed_rewards_member,
        unpool_time: Option::None,
        ..cfg.pool_member_info,
    }
        .into();
    assert_eq!(actual_pool_member_info, expected_pool_member_info);
    // Validate that the intent is removed from the exit intents map in staking contract.
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    let expected_undelegate_intent_value: UndelegateIntentValue = Zero::zero();
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);
    let staker_info = staking_dispatcher.staker_info(cfg.test_info.staker_address);
    assert_eq!(staker_info.get_pool_info().amount, cfg.pool_member_info._deprecated_amount);
}

#[test]
fn test_get_pool_member_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Check before enter the pool.
    let pool_member = cfg.test_info.pool_member_address;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let option_pool_member_info = pool_dispatcher.get_pool_member_info(:pool_member);
    assert!(option_pool_member_info.is_none());
    // Check after enter the pool.
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let mut expected_pool_member_info: PoolMemberInfo = cfg.pool_member_info.into();
    let option_pool_member_info = pool_dispatcher.get_pool_member_info(:pool_member);
    assert_eq!(option_pool_member_info, Option::Some(expected_pool_member_info));
}

#[test]
fn test_pool_member_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let pool_member = cfg.test_info.pool_member_address;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let mut expected_pool_member_info: PoolMemberInfo = cfg.pool_member_info.into();
    let pool_member_info = pool_dispatcher.pool_member_info(:pool_member);
    assert_eq!(pool_member_info, expected_pool_member_info);

    // Check after staker exits.
    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let unstake_time = staking_dispatcher.unstake_intent();
    start_cheat_block_timestamp_global(block_timestamp: unstake_time.into());
    staking_dispatcher.unstake_action(:staker_address);
    let pool_member_info = pool_dispatcher.pool_member_info(:pool_member);
    assert_eq!(pool_member_info, expected_pool_member_info);
}

#[test]
#[should_panic(expected: "Pool member does not exist")]
fn test_pool_member_info_pool_member_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    pool_dispatcher.pool_member_info(pool_member: NON_POOL_MEMBER_ADDRESS());
}

#[test]
fn test_v_internal_pool_member_info_wrap_latest() {
    let internal_pool_member_info_latest = InternalPoolMemberInfoLatest {
        reward_address: Zero::zero(),
        _deprecated_amount: Zero::zero(),
        _deprecated_index: Zero::zero(),
        unclaimed_rewards: Zero::zero(),
        commission: Zero::zero(),
        unpool_amount: Zero::zero(),
        unpool_time: Option::None,
        last_claimed_idx_in_member_vec: Zero::zero(),
    };
    let v_internal_pool_member_info = VInternalPoolMemberInfoTrait::wrap_latest(
        internal_pool_member_info_latest,
    );
    assert_eq!(
        v_internal_pool_member_info, VInternalPoolMemberInfo::V1(internal_pool_member_info_latest),
    );
}

#[test]
fn test_v_internal_pool_member_info_new_latest() {
    let v_internal_pool_member_info = VInternalPoolMemberInfoTrait::new_latest(
        reward_address: Zero::zero(),
        unclaimed_rewards: Zero::zero(),
        unpool_amount: Zero::zero(),
        unpool_time: Option::None,
        last_claimed_idx_in_member_vec: Zero::zero(),
    );
    let expected_v_internal_pool_member_info = VInternalPoolMemberInfo::V1(
        InternalPoolMemberInfoLatest {
            reward_address: Zero::zero(),
            _deprecated_amount: Zero::zero(),
            _deprecated_index: Zero::zero(),
            unclaimed_rewards: Zero::zero(),
            commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
            last_claimed_idx_in_member_vec: Zero::zero(),
        },
    );
    assert_eq!(v_internal_pool_member_info, expected_v_internal_pool_member_info);
}

#[test]
fn test_v_internal_pool_member_info_is_none() {
    let v_none = VInternalPoolMemberInfo::None;
    let v_v0 = VInternalPoolMemberInfoTestTrait::new_v0(
        reward_address: Zero::zero(),
        amount: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards: Zero::zero(),
        commission: Zero::zero(),
        unpool_amount: Zero::zero(),
        unpool_time: Option::None,
    );
    let v_latest = VInternalPoolMemberInfoTrait::new_latest(
        reward_address: Zero::zero(),
        unclaimed_rewards: Zero::zero(),
        unpool_amount: Zero::zero(),
        unpool_time: Option::None,
        last_claimed_idx_in_member_vec: Zero::zero(),
    );
    assert!(v_none.is_none());
    assert!(!v_v0.is_none());
    assert!(!v_latest.is_none());
}

#[test]
fn test_pool_member_info_into_internal_pool_member_info_v1() {
    let pool_member_info = PoolMemberInfo {
        reward_address: Zero::zero(),
        amount: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards: Zero::zero(),
        commission: Zero::zero(),
        unpool_amount: Zero::zero(),
        unpool_time: Option::None,
    };
    let internal_pool_mamber_info: InternalPoolMemberInfoV1 = pool_member_info.into();
    let expected_internal_pool_member_info = InternalPoolMemberInfoV1 {
        reward_address: Zero::zero(),
        _deprecated_amount: Zero::zero(),
        _deprecated_index: Zero::zero(),
        unclaimed_rewards: Zero::zero(),
        commission: Zero::zero(),
        unpool_amount: Zero::zero(),
        unpool_time: Option::None,
        last_claimed_idx_in_member_vec: Zero::zero(),
    };
    assert_eq!(internal_pool_mamber_info, expected_internal_pool_member_info);
}

#[test]
fn test_sanity_storage_versioned_internal_pool_member_info() {
    let mut state = VStorageContractTest::contract_state_for_testing();
    state
        .pool_member_info
        .write(
            POOL_MEMBER_ADDRESS(),
            Option::Some(
                InternalPoolMemberInfoTestTrait::new(
                    reward_address: Zero::zero(),
                    amount: Zero::zero(),
                    index: Zero::zero(),
                    unclaimed_rewards: Zero::zero(),
                    commission: Zero::zero(),
                    unpool_amount: Zero::zero(),
                    unpool_time: Option::None,
                ),
            ),
        );
    assert_eq!(
        state.new_pool_member_info.read(POOL_MEMBER_ADDRESS()),
        VInternalPoolMemberInfoTestTrait::new_v0(
            reward_address: Zero::zero(),
            amount: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards: Zero::zero(),
            commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
        ),
    );
}

#[test]
fn test_sanity_serde_versioned_internal_staker_info() {
    let option_internal_pool_member_info = Option::Some(
        InternalPoolMemberInfoTestTrait::new(
            reward_address: Zero::zero(),
            amount: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards: Zero::zero(),
            commission: Zero::zero(),
            unpool_amount: Zero::zero(),
            unpool_time: Option::None,
        ),
    );
    let mut arr = array![];
    option_internal_pool_member_info.serialize(ref arr);
    let mut span = arr.span();
    let v_pool_member_info: VInternalPoolMemberInfo = Serde::<
        VInternalPoolMemberInfo,
    >::deserialize(ref span)
        .unwrap();
    let expected_v_pool_member_info = VInternalPoolMemberInfoTestTrait::new_v0(
        reward_address: Zero::zero(),
        amount: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards: Zero::zero(),
        commission: Zero::zero(),
        unpool_amount: Zero::zero(),
        unpool_time: Option::None,
    );
    assert_eq!(v_pool_member_info, expected_v_pool_member_info);
}

#[test]
fn test_pool_eic() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let upgrade_governor = cfg.test_info.upgrade_governor;

    set_account_as_upgrade_governor(
        contract: pool_contract,
        account: upgrade_governor,
        governance_admin: cfg.test_info.pool_contract_admin,
    );

    let final_index: Index = staking_dispatcher.contract_parameters().global_index;

    // Upgrade.
    let eic_data = EICData {
        eic_hash: declare_pool_eic_contract(),
        eic_init_data: [MAINNET_POOL_CLASS_HASH_V0().into()].span(),
    };
    let implementation_data = ImplementationData {
        impl_hash: declare_pool_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    upgrade_implementation(
        contract_address: pool_contract, :implementation_data, :upgrade_governor,
    );
    // Test.
    let map_selector = selector!("prev_class_hash");
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: [0].span());
    let prev_class_hash = *snforge_std::load(
        target: pool_contract, :storage_address, size: Store::<ClassHash>::size().into(),
    )
        .at(0);
    assert_eq!(prev_class_hash.try_into().unwrap(), MAINNET_POOL_CLASS_HASH_V0());

    let mut span_final_staker_index = snforge_std::load(
        target: pool_contract,
        storage_address: selector!("final_staker_index"),
        size: Store::<Option<Index>>::size().into(),
    )
        .span();
    let final_staker_index: Option<Index> = deserialize_option(ref span_final_staker_index);
    assert_eq!(final_staker_index, Option::Some(final_index));
}

#[test]
#[should_panic(expected: 'EXPECTED_DATA_LENGTH_1')]
fn test_pool_eic_with_wrong_number_of_data_elements() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let upgrade_governor = cfg.test_info.pool_contract_admin;

    set_account_as_upgrade_governor(
        contract: pool_contract,
        account: upgrade_governor,
        governance_admin: cfg.test_info.pool_contract_admin,
    );

    // Upgrade.
    let eic_data = EICData { eic_hash: declare_pool_eic_contract(), eic_init_data: [].span() };
    let implementation_data = ImplementationData {
        impl_hash: declare_pool_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    // Cheat block timestamp to enable upgrade eligibility.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    upgrade_implementation(
        contract_address: pool_contract, :implementation_data, :upgrade_governor,
    );
}

#[test]
fn test_internal_pool_member_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let pool_member = cfg.test_info.pool_member_address;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolMigrationDispatcher { contract_address: pool_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let mut expected_pool_member_info: InternalPoolMemberInfoLatest = cfg.pool_member_info;
    expected_pool_member_info._deprecated_amount = Zero::zero();
    expected_pool_member_info.commission = Zero::zero();
    let pool_member_info = pool_dispatcher.internal_pool_member_info(:pool_member);
    assert_eq!(pool_member_info, expected_pool_member_info);

    // Check after staker exits.
    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let unstake_time = staking_dispatcher.unstake_intent();
    start_cheat_block_timestamp_global(block_timestamp: unstake_time.into());
    staking_dispatcher.unstake_action(:staker_address);
    let pool_member_info = pool_dispatcher.internal_pool_member_info(:pool_member);
    assert_eq!(pool_member_info, expected_pool_member_info);
}

#[test]
#[should_panic(expected: "Pool member does not exist")]
fn test_internal_pool_member_info_pool_member_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolMigrationDispatcher { contract_address: pool_contract };
    pool_dispatcher.internal_pool_member_info(pool_member: NON_POOL_MEMBER_ADDRESS());
}

#[test]
fn test_get_internal_pool_member_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    // Check before enter the pool.
    let pool_member = cfg.test_info.pool_member_address;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolMigrationDispatcher { contract_address: pool_contract };
    let option_pool_member_info = pool_dispatcher.get_internal_pool_member_info(:pool_member);
    assert!(option_pool_member_info.is_none());
    // Check after enter the pool.
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let mut expected_pool_member_info: InternalPoolMemberInfoLatest = cfg.pool_member_info;
    expected_pool_member_info._deprecated_amount = Zero::zero();
    expected_pool_member_info.commission = Zero::zero();
    let option_pool_member_info = pool_dispatcher.get_internal_pool_member_info(:pool_member);
    assert_eq!(option_pool_member_info, Option::Some(expected_pool_member_info));
}
