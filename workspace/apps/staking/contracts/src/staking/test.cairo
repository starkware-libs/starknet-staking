use Staking::{COMMISSION_DENOMINATOR, InternalStakingFunctionsTrait};
use constants::{
    BTC_STAKER_ADDRESS, BTC_TOKEN_ADDRESS, BTC_TOKEN_NAME, BTC_TOKEN_NAME_2, CALLER_ADDRESS,
    DUMMY_ADDRESS, DUMMY_IDENTIFIER, EPOCH_DURATION, EPOCH_LENGTH, EPOCH_STARTING_BLOCK,
    NON_APP_GOVERNOR, NON_STAKER_ADDRESS, NON_TOKEN_ADMIN, OTHER_OPERATIONAL_ADDRESS,
    OTHER_REWARD_ADDRESS, OTHER_REWARD_SUPPLIER_CONTRACT_ADDRESS, OTHER_STAKER_ADDRESS,
    STAKER_UNCLAIMED_REWARDS, UNPOOL_TIME,
};
use core::num::traits::Zero;
use core::option::OptionTrait;
use event_test_utils::{
    assert_change_delegation_pool_intent_event, assert_change_operational_address_event,
    assert_commission_changed_event, assert_commission_commitment_set_event,
    assert_commission_initialized_event, assert_declare_operational_address_event,
    assert_delete_staker_event, assert_epoch_info_changed_event,
    assert_exit_wait_window_changed_event, assert_minimum_stake_changed_event,
    assert_new_delegation_pool_event, assert_new_staker_event, assert_number_of_events,
    assert_remove_from_delegation_pool_action_event,
    assert_remove_from_delegation_pool_intent_event, assert_reward_supplier_changed_event,
    assert_rewards_supplied_to_delegation_pool_event, assert_stake_delegated_balance_changed_event,
    assert_stake_own_balance_changed_event, assert_staker_exit_intent_event,
    assert_staker_reward_address_change_event, assert_staker_reward_claimed_event,
    assert_staker_rewards_updated_event, assert_token_added_event, assert_token_disabled_event,
    assert_token_enabled_event,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::{
    CheatSpan, TokenTrait, cheat_account_contract_address, cheat_caller_address,
    start_cheat_block_number_global, start_cheat_block_timestamp_global,
};
use staking::attestation::interface::{IAttestationDispatcher, IAttestationDispatcherTrait};
use staking::constants::{
    DEFAULT_EXIT_WAIT_WINDOW, MAX_EXIT_WAIT_WINDOW, STAKING_V2_PREV_CONTRACT_VERSION,
    V1_PREV_CONTRACT_VERSION,
};
use staking::errors::GenericError;
use staking::flow_test::utils::MainnetClassHashes::{
    MAINNET_STAKING_CLASS_HASH_V0, MAINNET_STAKING_CLASS_HASH_V1,
};
use staking::flow_test::utils::{
    declare_staking_contract, pause_staking_contract, upgrade_implementation,
};
use staking::pool::errors::Error as PoolError;
use staking::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait, PoolContractInfoV1};
use staking::pool::objects::SwitchPoolData;
use staking::reward_supplier::interface::{
    IRewardSupplierDispatcher, IRewardSupplierDispatcherTrait,
};
use staking::staking::errors::Error;
use staking::staking::interface::{
    CommissionCommitment, IStakingAttestationDispatcher, IStakingAttestationDispatcherTrait,
    IStakingAttestationSafeDispatcher, IStakingAttestationSafeDispatcherTrait,
    IStakingConfigDispatcher, IStakingConfigDispatcherTrait, IStakingConfigSafeDispatcher,
    IStakingConfigSafeDispatcherTrait, IStakingDispatcher, IStakingDispatcherTrait,
    IStakingMigrationDispatcher, IStakingMigrationDispatcherTrait, IStakingPoolDispatcher,
    IStakingPoolDispatcherTrait, IStakingPoolSafeDispatcher, IStakingPoolSafeDispatcherTrait,
    IStakingSafeDispatcher, IStakingSafeDispatcherTrait, IStakingTokenManagerDispatcher,
    IStakingTokenManagerDispatcherTrait, IStakingTokenManagerSafeDispatcher,
    IStakingTokenManagerSafeDispatcherTrait, PoolInfo, StakerInfoV1, StakerInfoV1Trait,
    StakerPoolInfoV1, StakerPoolInfoV2, StakingContractInfoV1,
};
use staking::staking::objects::{
    AttestationInfoTrait, EpochInfoTrait, InternalStakerInfoLatestTestTrait,
    InternalStakerInfoLatestTrait, InternalStakerInfoV1, InternalStakerPoolInfoV1,
    NormalizedAmountTrait, StakerInfoIntoInternalStakerInfoV1ITrait, UndelegateIntentKey,
    UndelegateIntentValue, UndelegateIntentValueTrait, UndelegateIntentValueZero,
    VersionedInternalStakerInfo, VersionedInternalStakerInfoTrait,
};
use staking::staking::staking::Staking;
use staking::staking::staking::Staking::MAX_MIGRATION_TRACE_ENTRIES;
use staking::types::{Amount, InternalStakerInfoLatest, VecIndex};
use staking::{event_test_utils, test_utils};
use starknet::class_hash::ClassHash;
use starknet::{ContractAddress, Store, get_block_number};
use starkware_utils::components::replaceability::interface::{EICData, ImplementationData};
use starkware_utils::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use starkware_utils::constants::DAY;
use starkware_utils::errors::Describable;
use starkware_utils::storage::iterable_map::{
    IterableMapIntoIterImpl, IterableMapReadAccessImpl, IterableMapWriteAccessImpl,
};
use starkware_utils::time::time::{Time, TimeDelta, Timestamp};
use starkware_utils_testing::test_utils::{
    advance_block_number_global, assert_panic_with_error, cheat_caller_address_once,
};
use test_utils::{
    StakingInitConfig, advance_block_into_attestation_window, advance_epoch_global, append_to_trace,
    approve, calculate_staker_btc_pool_rewards, calculate_staker_strk_rewards,
    cheat_reward_for_reward_supplier, cheat_target_attestation_block_hash, constants,
    custom_decimals_token, declare_pool_contract, declare_staking_eic_contract_v1_v2,
    deploy_mock_erc20_decimals_contract, deploy_reward_supplier_contract, deploy_staking_contract,
    enter_delegation_pool_for_testing_using_dispatcher, fund, general_contract_system_deployment,
    initialize_staking_state_from_cfg, load_from_simple_map, load_from_trace, load_trace_length,
    setup_btc_token, stake_for_testing_using_dispatcher, stake_from_zero_address,
    stake_with_pool_enabled, store_internal_staker_info_v0_to_map, store_to_simple_map,
    to_amount_18_decimals,
};

#[test]
fn test_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    assert!(state.min_stake.read() == cfg.staking_contract_info.min_stake);
    let staker_address = state
        .operational_address_to_staker_address
        .read(cfg.staker_info.operational_address);
    assert!(staker_address == Zero::zero());
    let staker_info = state.staker_info.read(staker_address);
    assert!(staker_info.is_none());
    assert!(
        state.pool_contract_class_hash.read() == cfg.staking_contract_info.pool_contract_class_hash,
    );
    assert!(
        state
            .reward_supplier_dispatcher
            .read()
            .contract_address == cfg
            .staking_contract_info
            .reward_supplier,
    );
    assert!(state.pool_contract_admin.read() == cfg.test_info.pool_contract_admin);
    assert!(
        state
            .prev_class_hash
            .read(STAKING_V2_PREV_CONTRACT_VERSION) == cfg
            .staking_contract_info
            .prev_staking_contract_class_hash,
    );
}

#[test]
fn test_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let mut spy = snforge_std::spy_events();
    stake_for_testing_using_dispatcher(:cfg);

    let staker_address = cfg.test_info.staker_address;
    // Check that the staker info was updated correctly.
    let mut expected_staker_info: StakerInfoV1 = cfg.staker_info.into();
    expected_staker_info.pool_info = Option::None;
    expected_staker_info.amount_own = cfg.test_info.stake_amount;
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert!(expected_staker_info == staking_dispatcher.staker_info_v1(:staker_address));

    let staker_address_from_operational_address = load_from_simple_map(
        map_selector: selector!("operational_address_to_staker_address"),
        key: cfg.staker_info.operational_address,
        contract: staking_contract,
    );
    // Check that the operational address to staker address mapping was updated correctly.
    assert!(staker_address_from_operational_address == staker_address);

    // Check that the staker's tokens were transferred to the Staking contract.
    assert!(
        token_dispatcher
            .balance_of(
                staker_address,
            ) == (cfg.test_info.staker_initial_balance - cfg.test_info.stake_amount)
            .into(),
    );
    assert!(token_dispatcher.balance_of(staking_contract) == cfg.test_info.stake_amount.into());
    assert!(staking_dispatcher.get_total_stake() == cfg.test_info.stake_amount);
    // Validate StakeBalanceChanged and NewStaker event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "stake");
    assert_new_staker_event(
        spied_event: events[0],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        self_stake: cfg.test_info.stake_amount,
    );
    assert_stake_own_balance_changed_event(
        spied_event: events[1],
        :staker_address,
        old_self_stake: Zero::zero(),
        new_self_stake: cfg.test_info.stake_amount,
    );

    // Test staker in stakers vector.
    let vec_storage = selector!("stakers");
    let vec_len: VecIndex = (*snforge_std::load(
        target: staking_contract,
        storage_address: vec_storage,
        size: Store::<VecIndex>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    assert!(vec_len == 1);
    let staker_vec_storage = snforge_std::map_entry_address(
        map_selector: vec_storage, keys: [0.into()].span(),
    );
    let staker_in_vec: ContractAddress = (*snforge_std::load(
        target: staking_contract,
        storage_address: staker_vec_storage,
        size: Store::<ContractAddress>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    assert!(staker_in_vec == staker_address);
}

// TODO: Test staker vec after stake with more than one staker.

#[test]
fn test_send_rewards_to_staker() {
    // Initialize staking state.
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    cfg.test_info.staking_contract = snforge_std::test_address();
    let token = cfg.test_info.strk_token;
    let token_dispatcher = IERC20Dispatcher { contract_address: token.contract_address() };
    // Deploy reward supplier contract.
    let reward_supplier = deploy_reward_supplier_contract(:cfg);
    cfg.staking_contract_info.reward_supplier = reward_supplier;
    state
        .reward_supplier_dispatcher
        .write(IRewardSupplierDispatcher { contract_address: reward_supplier });
    // Setup staker_info and expected results before sending rewards.
    let unclaimed_rewards_own = STAKER_UNCLAIMED_REWARDS;
    cfg.staker_info.unclaimed_rewards_own = unclaimed_rewards_own;
    let mut expected_staker_info = cfg.staker_info.clone();
    expected_staker_info.unclaimed_rewards_own = Zero::zero();
    cheat_reward_for_reward_supplier(
        :reward_supplier, expected_reward: unclaimed_rewards_own, :token,
    );
    let staker_balance_before_rewards = token_dispatcher
        .balance_of(account: cfg.staker_info.reward_address);
    // Send rewards to staker's reward address.
    state
        .send_rewards_to_staker(
            staker_address: cfg.test_info.staker_address,
            ref staker_info: cfg.staker_info,
            :token_dispatcher,
        );
    // Check that unclaimed_rewards_own is set to zero and that the staker received the rewards.
    assert!(expected_staker_info == cfg.staker_info);
    let staker_balance_after_rewards = token_dispatcher
        .balance_of(account: cfg.staker_info.reward_address);
    assert!(
        staker_balance_after_rewards == staker_balance_before_rewards
            + unclaimed_rewards_own.into(),
    );
}

#[test]
#[should_panic(expected: "Staker already exists, use increase_stake instead")]
fn test_stake_from_same_staker_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);

    // Second stake from cfg.test_info.staker_address.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.test_info.stake_amount,
        );
}

#[test]
#[should_panic(expected: "Staker address is a token address")]
fn test_stake_with_token_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;

    // Only add the token but not enable it.
    let disabled_btc_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME_2(),
        decimals: constants::TEST_BTC_DECIMALS,
    );
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    staking_token_dispatcher.add_token(token_address: disabled_btc_token_address);

    // Stake from the token address.
    let caller_address = disabled_btc_token_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .stake(
            reward_address: DUMMY_ADDRESS(),
            operational_address: DUMMY_ADDRESS(),
            amount: cfg.test_info.stake_amount,
        );
}

#[test]
#[should_panic(expected: "Operational address already exists")]
fn test_stake_with_same_operational_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);

    let caller_address = OTHER_STAKER_ADDRESS();
    assert!(cfg.test_info.staker_address != caller_address);
    // Change staker address.
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    // Second stake with the same operational address.
    staking_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.test_info.stake_amount,
        );
}

#[test]
#[should_panic(expected: "Amount is less than min stake - try again with enough funds")]
fn test_stake_with_less_than_min_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.test_info.stake_amount = cfg.staking_contract_info.min_stake - 1;
    general_contract_system_deployment(ref :cfg);
    stake_for_testing_using_dispatcher(:cfg);
}

#[test]
#[should_panic(expected: "Staker address is already used")]
fn test_stake_with_staker_address_already_used() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    stake_for_testing_using_dispatcher(:cfg);

    // Exit intent.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let unstake_time = staking_dispatcher.unstake_intent();

    // Advance time to enable unstake_action.
    start_cheat_block_timestamp_global(
        block_timestamp: unstake_time.add(delta: Time::seconds(count: 1)).into(),
    );

    // Exit action.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_action(:staker_address);

    // Second stake with the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.test_info.stake_amount,
        );
}

#[test]
fn test_contract_parameters_v1() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);

    let expected_staking_contract_info = StakingContractInfoV1 {
        min_stake: cfg.staking_contract_info.min_stake,
        token_address: cfg.test_info.strk_token.contract_address(),
        attestation_contract: cfg.test_info.attestation_contract,
        pool_contract_class_hash: cfg.staking_contract_info.pool_contract_class_hash,
        reward_supplier: cfg.staking_contract_info.reward_supplier,
        exit_wait_window: cfg.staking_contract_info.exit_wait_window,
    };
    assert!(staking_dispatcher.contract_parameters_v1() == expected_staking_contract_info);
}

#[test]
fn test_increase_stake_from_staker_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    // Set the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let staker_info_before = staking_dispatcher.staker_info_v1(:staker_address);
    let increase_amount = cfg.test_info.stake_amount;
    let expected_staker_info = StakerInfoV1 {
        amount_own: staker_info_before.amount_own + increase_amount, ..staker_info_before,
    };
    let mut spy = snforge_std::spy_events();
    // Increase stake from the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let new_self_stake = staking_dispatcher
        .increase_stake(:staker_address, amount: increase_amount);
    assert!(new_self_stake == expected_staker_info.amount_own);

    let updated_staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(expected_staker_info == updated_staker_info);
    assert!(staking_dispatcher.get_total_stake() == expected_staker_info.amount_own);
    // Validate the single StakeBalanceChanged event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "increase_stake");
    assert_stake_own_balance_changed_event(
        spied_event: events[0],
        :staker_address,
        old_self_stake: staker_info_before.amount_own,
        new_self_stake: updated_staker_info.amount_own,
    );
}

#[test]
fn test_increase_stake_from_reward_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);

    // Transfer amount to reward_address.
    fund(
        target: cfg.staker_info.reward_address,
        amount: cfg.test_info.staker_initial_balance,
        :token,
    );
    // Approve the Staking contract to spend the reward's tokens.
    approve(
        owner: cfg.staker_info.reward_address,
        spender: staking_contract,
        amount: cfg.test_info.staker_initial_balance,
        :token_address,
    );
    let staker_address = cfg.test_info.staker_address;
    let staker_info_before = staking_dispatcher.staker_info_v1(:staker_address);
    let increase_amount = cfg.test_info.stake_amount;
    let mut expected_staker_info = staker_info_before;
    expected_staker_info.amount_own += increase_amount;
    let caller_address = cfg.staker_info.reward_address;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    let new_self_stake = staking_dispatcher
        .increase_stake(:staker_address, amount: increase_amount);
    assert!(new_self_stake == expected_staker_info.amount_own);
    let updated_staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(expected_staker_info == updated_staker_info);
    assert!(staking_dispatcher.get_total_stake() == expected_staker_info.amount_own);
    // Validate the single StakeBalanceChanged event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "increase_stake");
    assert_stake_own_balance_changed_event(
        spied_event: events[0],
        :staker_address,
        old_self_stake: staker_info_before.amount_own,
        new_self_stake: expected_staker_info.amount_own,
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_increase_stake_staker_address_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher
        .increase_stake(staker_address: NON_STAKER_ADDRESS(), amount: cfg.test_info.stake_amount);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_increase_stake_unstake_in_progress() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.increase_stake(:staker_address, amount: cfg.test_info.stake_amount);
}

#[test]
#[should_panic(expected: "Amount is zero")]
fn test_increase_stake_amount_is_zero() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.increase_stake(:staker_address, amount: Zero::zero());
}

#[test]
#[should_panic(expected: "Caller address should be staker address or reward address")]
fn test_increase_stake_caller_cannot_increase() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .increase_stake(
            staker_address: cfg.test_info.staker_address, amount: cfg.test_info.stake_amount,
        );
}

#[test]
fn test_change_reward_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let staker_info_before_change = staking_dispatcher.staker_info_v1(:staker_address);
    let other_reward_address = OTHER_REWARD_ADDRESS();

    // Set the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let mut spy = snforge_std::spy_events();
    staking_dispatcher.change_reward_address(reward_address: other_reward_address);
    let staker_info_after_change = staking_dispatcher.staker_info_v1(:staker_address);
    let staker_info_expected = StakerInfoV1 {
        reward_address: other_reward_address, ..staker_info_before_change,
    };
    assert!(staker_info_after_change == staker_info_expected);
    // Validate the single StakerRewardAddressChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "change_reward_address");
    assert_staker_reward_address_change_event(
        spied_event: events[0],
        :staker_address,
        new_address: other_reward_address,
        old_address: cfg.staker_info.reward_address,
    );
}


#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_change_reward_address_staker_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    // Reward address is arbitrary because it should fail because of the caller.
    staking_dispatcher.change_reward_address(reward_address: DUMMY_ADDRESS());
}

#[test]
fn test_claim_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let staker_address = cfg.test_info.staker_address;
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };

    // Stake.
    stake_for_testing_using_dispatcher(:cfg);

    // Advance the epoch to ensure the total stake in the current epoch is nonzero, preventing a
    // division by zero when calculating rewards.
    advance_epoch_global();
    advance_block_into_attestation_window(:cfg, stake: cfg.test_info.stake_amount);

    // Calculate the expected staker rewards.
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let (expected_staker_rewards, expected_pool_rewards) = calculate_staker_strk_rewards(
        :staker_info, :staking_contract, :minting_curve_contract,
    );
    assert!(expected_pool_rewards.is_zero());

    // Funds reward supplier.
    fund(target: reward_supplier, amount: expected_staker_rewards, :token);

    let block_hash = Zero::zero();
    cheat_target_attestation_block_hash(:cfg, :block_hash);
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: cfg.staker_info.operational_address,
    );
    attestation_dispatcher.attest(:block_hash);

    // Claim rewards and validate the results.
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let staker_rewards = staking_dispatcher.claim_rewards(:staker_address);
    assert!(staker_rewards == expected_staker_rewards);

    let staker_info_after_claim = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info_after_claim.unclaimed_rewards_own == Zero::zero());

    let staker_reward_address_balance = token_dispatcher
        .balance_of(account: cfg.staker_info.reward_address);
    assert!(staker_reward_address_balance == staker_rewards.into());
    // Validate the single StakerRewardClaimed event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "claim_rewards");
    assert_staker_reward_claimed_event(
        spied_event: events[0],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        amount: staker_rewards,
    );
}

#[test]
#[should_panic(expected: "Claim rewards must be called from staker address or reward address")]
fn test_claim_rewards_panic_unauthorized() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = DUMMY_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher.claim_rewards(staker_address: cfg.test_info.staker_address);
}


#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_claim_rewards_panic_staker_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher.claim_rewards(staker_address: DUMMY_ADDRESS());
}

#[test]
fn test_unstake_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let mut spy = snforge_std::spy_events();
    let unstake_time = staking_dispatcher.unstake_intent();
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let expected_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters_v1().exit_wait_window);
    assert!(staker_info.unstake_time.unwrap() == unstake_time);
    assert!(unstake_time == expected_time);
    assert!(staking_dispatcher.get_total_stake() == Zero::zero());
    // Validate StakerExitIntent and StakeBalanceChanged events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "unstake_intent");
    assert_staker_exit_intent_event(
        spied_event: events[0], :staker_address, exit_timestamp: expected_time,
    );
    assert_stake_own_balance_changed_event(
        spied_event: events[1],
        :staker_address,
        old_self_stake: cfg.test_info.stake_amount,
        new_self_stake: 0,
    );
}

#[test]
fn test_unstake_intent_with_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    stake_with_pool_enabled(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let mut spy = snforge_std::spy_events();
    let unstake_time = staking_dispatcher.unstake_intent();
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let expected_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters_v1().exit_wait_window);
    assert!(staker_info.unstake_time.unwrap() == unstake_time);
    assert!(unstake_time == expected_time);
    assert!(staking_dispatcher.get_total_stake() == Zero::zero());
    // Validate StakerExitIntent and StakeBalanceChanged events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 3, message: "unstake_intent");
    assert_stake_delegated_balance_changed_event(
        spied_event: events[0],
        :staker_address,
        :token_address,
        old_delegated_stake: 0,
        new_delegated_stake: 0,
    );
    assert_staker_exit_intent_event(
        spied_event: events[1], :staker_address, exit_timestamp: expected_time,
    );
    assert_stake_own_balance_changed_event(
        spied_event: events[2],
        :staker_address,
        old_self_stake: cfg.test_info.stake_amount,
        new_self_stake: 0,
    );
}

#[test]
fn test_unstake_intent_with_multiple_pools() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    // Open STRK pool with delegated balance.
    let pool_contract = stake_with_pool_enabled(:cfg);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token);
    let strk_delegated_balance = cfg.pool_member_info._deprecated_amount;
    // Open BTC pool.
    let btc_token_address = cfg.test_info.btc_token.contract_address();
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_open_for_delegation(token_address: btc_token_address);
    // Unstake intent.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let mut spy = snforge_std::spy_events();
    let unstake_time = staking_dispatcher.unstake_intent();
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let expected_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters_v1().exit_wait_window);
    assert!(staker_info.unstake_time.unwrap() == unstake_time);
    assert!(unstake_time == expected_time);
    assert!(staking_dispatcher.get_total_stake() == Zero::zero());
    // Validate StakerExitIntent and StakeBalanceChanged events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 4, message: "unstake_intent");
    assert_stake_delegated_balance_changed_event(
        spied_event: events[0],
        :staker_address,
        :token_address,
        old_delegated_stake: strk_delegated_balance,
        new_delegated_stake: 0,
    );
    assert_stake_delegated_balance_changed_event(
        spied_event: events[1],
        :staker_address,
        token_address: btc_token_address,
        old_delegated_stake: 0,
        new_delegated_stake: 0,
    );
    assert_staker_exit_intent_event(
        spied_event: events[2], :staker_address, exit_timestamp: expected_time,
    );
    assert_stake_own_balance_changed_event(
        spied_event: events[3],
        :staker_address,
        old_self_stake: cfg.test_info.stake_amount,
        new_self_stake: 0,
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_unstake_intent_staker_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher.unstake_intent();
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_unstake_intent_unstake_in_progress() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: cfg.test_info.staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    cheat_account_contract_address(
        contract_address: staking_contract,
        account_contract_address: cfg.test_info.staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    staking_dispatcher.unstake_intent();
    staking_dispatcher.unstake_intent();
}

#[test]
fn test_unstake_action() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;

    // Stake.
    let pool_contract = stake_with_pool_enabled(:cfg);

    // Set commission commitment.
    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let max_commission = staker_info.get_pool_info().commission;
    let expiration_epoch = staking_dispatcher.get_current_epoch() + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission_commitment(:max_commission, :expiration_epoch);

    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let unstake_time = staking_dispatcher.unstake_intent();
    // Advance time to enable unstake_action.
    start_cheat_block_timestamp_global(
        block_timestamp: unstake_time.add(delta: Time::seconds(count: 1)).into(),
    );
    let unclaimed_rewards_own = staking_dispatcher
        .staker_info_v1(:staker_address)
        .unclaimed_rewards_own;
    let mut spy = snforge_std::spy_events();
    let staker_amount = staking_dispatcher.unstake_action(:staker_address);
    assert!(staker_amount == cfg.test_info.stake_amount);
    let actual_staker_info = staking_dispatcher.get_staker_info_v1(:staker_address);
    assert!(actual_staker_info.is_none());
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    // StakerRewardClaimed, RewardsSuppliedToDelegationPool and DeleteStaker
    // events.
    assert_number_of_events(actual: events.len(), expected: 2, message: "unstake_action");
    // Validate StakerRewardClaimed event.
    assert_staker_reward_claimed_event(
        spied_event: events[0],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        amount: unclaimed_rewards_own,
    );
    // Validate DeleteStaker event.
    assert_delete_staker_event(
        spied_event: events[1],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        pool_contracts: [pool_contract].span(),
    );
}

#[test]
fn test_unstake_action_multiple_pools() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and open STRK pool.
    let strk_pool_contract = stake_with_pool_enabled(:cfg);
    // Open BTC pool.
    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let btc_token = cfg.test_info.btc_token;
    let btc_token_address = btc_token.contract_address();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let btc_pool_contract = staking_dispatcher
        .set_open_for_delegation(token_address: btc_token_address);
    // Enter STRK pool.
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: strk_pool_contract, :cfg, :token,
    );
    // Enter BTC pool.
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: btc_pool_contract, :cfg, token: btc_token,
    );
    // Set commission commitment.
    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let max_commission = staker_info.get_pool_info().commission;
    let expiration_epoch = staking_dispatcher.get_current_epoch() + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission_commitment(:max_commission, :expiration_epoch);

    // Unstake intent.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let unstake_time = staking_dispatcher.unstake_intent();
    // Advance time to enable unstake_action.
    start_cheat_block_timestamp_global(
        block_timestamp: unstake_time.add(delta: Time::seconds(count: 1)).into(),
    );
    let unclaimed_rewards_own = staking_dispatcher
        .staker_info_v1(:staker_address)
        .unclaimed_rewards_own;
    let mut spy = snforge_std::spy_events();

    // Current balance of pools is zero.
    let strk_token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let btc_token_dispatcher = IERC20Dispatcher { contract_address: btc_token_address };
    assert!(strk_token_dispatcher.balance_of(strk_pool_contract) == Zero::zero());
    assert!(btc_token_dispatcher.balance_of(btc_pool_contract) == Zero::zero());
    // No rewards transferred to pool.
    assert!(strk_token_dispatcher.balance_of(btc_pool_contract) == Zero::zero());

    let staker_balance_before = strk_token_dispatcher.balance_of(staker_address);
    let staker_reward_balance_before = strk_token_dispatcher
        .balance_of(cfg.staker_info.reward_address);
    // Unstake action.
    let staker_amount = staking_dispatcher.unstake_action(:staker_address);
    assert!(staker_amount == cfg.test_info.stake_amount);
    let actual_staker_info = staking_dispatcher.get_staker_info_v1(:staker_address);
    assert!(actual_staker_info.is_none());
    // Assert stake amount transferred to staker.
    assert!(
        strk_token_dispatcher.balance_of(staker_address) == staker_balance_before
            + cfg.test_info.stake_amount.into(),
    );
    // Assert rewards transferred to staker.
    assert!(
        strk_token_dispatcher
            .balance_of(cfg.staker_info.reward_address) == staker_reward_balance_before
            + unclaimed_rewards_own.into(),
    );
    // Assert delegated balance transferred to both pools.
    let expected_delegated_balance = cfg.pool_member_info._deprecated_amount;
    assert!(
        strk_token_dispatcher.balance_of(strk_pool_contract) == expected_delegated_balance.into(),
    );
    assert!(
        btc_token_dispatcher.balance_of(btc_pool_contract) == expected_delegated_balance.into(),
    );
    // Assert staker removed in both pools.
    let strk_pool_dispatcher = IPoolDispatcher { contract_address: strk_pool_contract };
    let btc_pool_dispatcher = IPoolDispatcher { contract_address: btc_pool_contract };
    assert!(strk_pool_dispatcher.contract_parameters_v1().staker_removed);
    assert!(btc_pool_dispatcher.contract_parameters_v1().staker_removed);

    // Validate events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "unstake_action");
    // Validate StakerRewardClaimed event.
    assert_staker_reward_claimed_event(
        spied_event: events[0],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        amount: unclaimed_rewards_own,
    );
    // Validate DeleteStaker event.
    assert_delete_staker_event(
        spied_event: events[1],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        pool_contracts: [strk_pool_contract, btc_pool_contract].span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_unstake_action_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_safe_dispatcher = IStakingSafeDispatcher { contract_address: staking_contract };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;

    // Catch STAKER_NOT_EXISTS.
    let result = staking_safe_dispatcher.unstake_action(:staker_address);
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());
    stake_with_pool_enabled(:cfg);

    // Catch MISSING_UNSTAKE_INTENT.
    let result = staking_safe_dispatcher.unstake_action(:staker_address);
    assert_panic_with_error(:result, expected_error: Error::MISSING_UNSTAKE_INTENT.describe());

    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_intent();

    // Catch INTENT_WINDOW_NOT_FINISHED.
    let result = staking_safe_dispatcher.unstake_action(:staker_address);
    assert_panic_with_error(
        :result, expected_error: GenericError::INTENT_WINDOW_NOT_FINISHED.describe(),
    );
}

#[test]
fn test_get_total_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    assert!(staking_dispatcher.get_current_epoch() == Zero::zero());
    assert!(staking_dispatcher.get_total_stake() == Zero::zero());
    stake_for_testing_using_dispatcher(:cfg);
    assert!(staking_dispatcher.get_total_stake() == cfg.test_info.stake_amount);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    // Set the same staker address.
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let amount = cfg.test_info.stake_amount;
    staking_dispatcher.increase_stake(:staker_address, :amount);
    assert!(
        staking_dispatcher
            .get_total_stake() == staking_dispatcher
            .staker_info_v1(:staker_address)
            .amount_own,
    );
}

#[test]
fn test_add_stake_from_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };

    let pool_contract = stake_with_pool_enabled(:cfg);
    let pool_amount = cfg.test_info.staker_initial_balance;
    // Fund pool contract.
    fund(target: pool_contract, amount: pool_amount, :token);
    // Approve the Staking contract to spend the pool's tokens.
    approve(owner: pool_contract, spender: staking_contract, amount: pool_amount, :token_address);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let pool_balance_before = token_dispatcher.balance_of(pool_contract);
    let total_stake_before = staking_dispatcher.get_total_stake();
    let staker_info_before = staking_dispatcher.staker_info_v1(:staker_address);
    let pool_info_before = staker_info_before.get_pool_info();
    let mut spy = snforge_std::spy_events();
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher.add_stake_from_pool(:staker_address, amount: pool_amount);

    // Validate total stake.
    assert!(staking_dispatcher.get_total_stake() == total_stake_before + pool_amount);

    // Validate pool balance.
    let pool_balance_after = token_dispatcher.balance_of(pool_contract);
    assert!(pool_balance_after == pool_balance_before - pool_amount.into());

    // Validate staker info.
    let mut expected_pool_info = StakerPoolInfoV1 { amount: pool_amount, ..pool_info_before };
    let expected_staker_info = StakerInfoV1 {
        pool_info: Option::Some(expected_pool_info), ..staker_info_before,
    };
    let staker_info_after = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info_after == expected_staker_info);

    // Validate `StakeBalanceChanged` event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "add_stake_from_pool");
    assert_stake_delegated_balance_changed_event(
        spied_event: events[0],
        staker_address: cfg.test_info.staker_address,
        :token_address,
        old_delegated_stake: Zero::zero(),
        new_delegated_stake: pool_amount,
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_stake_from_pool_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pool_safe_dispatcher = IStakingPoolSafeDispatcher {
        contract_address: staking_contract,
    };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let amount = cfg.pool_member_info._deprecated_amount;

    // Should catch CALLER_IS_ZERO_ADDRESS.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: Zero::zero());
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_IS_ZERO_ADDRESS.describe());

    // Should catch STAKER_NOT_EXISTS.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());

    // Should catch UNSTAKE_IN_PROGRESS.
    let token_address = cfg.test_info.strk_token.contract_address();
    let pool_contract = stake_with_pool_enabled(:cfg);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let unstake_time = staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::UNSTAKE_IN_PROGRESS.describe());

    // Should catch CALLER_IS_NOT_POOL_CONTRACT.
    start_cheat_block_timestamp_global(
        block_timestamp: unstake_time.add(delta: Time::seconds(count: 1)).into(),
    );
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_action(:staker_address);
    cfg.test_info.staker_address = OTHER_STAKER_ADDRESS();
    let staker_address = cfg.test_info.staker_address;
    stake_for_testing_using_dispatcher(:cfg);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_IS_NOT_POOL_CONTRACT.describe());

    // Should catch CALLER_IS_NOT_POOL_CONTRACT.
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    staking_dispatcher.set_commission(:commission);
    staking_dispatcher.set_open_for_delegation(:token_address);
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_IS_NOT_POOL_CONTRACT.describe());
}

#[test]
fn test_remove_from_delegation_pool_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token);

    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let initial_delegated_stake = cfg.pool_member_info._deprecated_amount;
    let old_total_stake = staking_dispatcher.get_total_stake();
    let mut spy = snforge_std::spy_events();
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    let mut intent_amount = cfg.pool_member_info._deprecated_amount / 2;

    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: intent_amount,
        );

    // Validate that the staker info is updated.
    let mut cur_delegated_stake = initial_delegated_stake - intent_amount;
    let mut expected_staker_info: StakerInfoV1 = cfg.staker_info.into();
    expected_staker_info.amount_own = cfg.test_info.stake_amount;
    let mut internal_pool_info = cfg.staker_info._deprecated_get_pool_info();
    expected_staker_info
        .pool_info =
            Option::Some(
                StakerPoolInfoV1 {
                    pool_contract,
                    amount: cur_delegated_stake,
                    commission: internal_pool_info._deprecated_commission,
                },
            );
    assert!(
        staking_dispatcher.staker_info_v1(cfg.test_info.staker_address) == expected_staker_info,
    );

    // Validate that the total stake is updated.
    let expected_total_stake = old_total_stake - intent_amount;
    assert!(staking_dispatcher.get_total_stake() == expected_total_stake);

    // Validate that the data written in the exit intents map is updated.
    let identifier: felt252 = cfg.test_info.pool_member_address.into();
    let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    let expected_unpool_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters_v1().exit_wait_window);
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_unpool_time,
        amount: NormalizedAmountTrait::from_strk_native_amount(intent_amount),
        token_address,
    };
    assert!(actual_undelegate_intent_value == expected_undelegate_intent_value);

    // Validate StakeBalanceChanged and RemoveFromDelegationPoolIntent events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "remove_from_delegation_pool_intent",
    );
    assert_remove_from_delegation_pool_intent_event(
        spied_event: events[0],
        staker_address: cfg.test_info.staker_address,
        :pool_contract,
        :token_address,
        :identifier,
        old_intent_amount: Zero::zero(),
        new_intent_amount: intent_amount,
    );
    assert_stake_delegated_balance_changed_event(
        spied_event: events[1],
        staker_address: cfg.test_info.staker_address,
        :token_address,
        old_delegated_stake: initial_delegated_stake,
        new_delegated_stake: cur_delegated_stake,
    );

    // Decrease intent amount.
    let old_intent_amount = intent_amount;
    let new_intent_amount = old_intent_amount / 2;

    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: new_intent_amount,
        );

    // Validate that the staker info is updated.
    // TODO: Ensure there are flow tests that attempt to update validator and delegator rewards
    // while in intent.
    let prev_delegated_stake = cur_delegated_stake;
    cur_delegated_stake = initial_delegated_stake - new_intent_amount;
    let mut expected_pool_info = expected_staker_info.get_pool_info();
    expected_pool_info.amount = cur_delegated_stake;
    expected_staker_info.pool_info = Option::Some(expected_pool_info);
    assert!(
        staking_dispatcher.staker_info_v1(cfg.test_info.staker_address) == expected_staker_info,
    );

    // Validate that the total stake is updated.
    let expected_total_stake = old_total_stake - new_intent_amount;
    assert!(staking_dispatcher.get_total_stake() == expected_total_stake);

    // Validate that the data written in the exit intents map is updated.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    let expected_unpool_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters_v1().exit_wait_window);
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_unpool_time,
        amount: NormalizedAmountTrait::from_strk_native_amount(new_intent_amount),
        token_address,
    };
    assert!(actual_undelegate_intent_value == expected_undelegate_intent_value);

    // Validate StakeBalanceChanged and RemoveFromDelegationPoolIntent events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 4, message: "remove_from_delegation_pool_intent",
    );
    assert_remove_from_delegation_pool_intent_event(
        spied_event: events[2],
        staker_address: cfg.test_info.staker_address,
        :pool_contract,
        :token_address,
        :identifier,
        :old_intent_amount,
        :new_intent_amount,
    );
    assert_stake_delegated_balance_changed_event(
        spied_event: events[3],
        staker_address: cfg.test_info.staker_address,
        :token_address,
        old_delegated_stake: prev_delegated_stake,
        new_delegated_stake: cur_delegated_stake,
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_remove_from_delegation_pool_intent_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pool_safe_dispatcher = IStakingPoolSafeDispatcher {
        contract_address: staking_contract,
    };
    let staker_address = cfg.test_info.staker_address;
    let identifier = cfg.test_info.pool_member_address.into();
    let amount = 1;

    // Should catch STAKER_NOT_EXISTS.
    let result = staking_pool_safe_dispatcher
        .remove_from_delegation_pool_intent(:staker_address, :identifier, :amount);
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());

    // Should catch CALLER_IS_NOT_POOL_CONTRACT.
    let token_address = cfg.test_info.strk_token.contract_address();
    stake_for_testing_using_dispatcher(:cfg);
    let result = staking_pool_safe_dispatcher
        .remove_from_delegation_pool_intent(:staker_address, :identifier, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_IS_NOT_POOL_CONTRACT.describe());

    // Should catch CALLER_IS_NOT_POOL_CONTRACT.
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    staking_dispatcher.set_commission(:commission);
    let pool_contract = staking_dispatcher.set_open_for_delegation(:token_address);
    let result = staking_pool_safe_dispatcher
        .remove_from_delegation_pool_intent(:staker_address, :identifier, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_IS_NOT_POOL_CONTRACT.describe());

    // Should catch INVALID_UNDELEGATE_INTENT_VALUE.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let invalid_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: Timestamp { seconds: 1 },
        amount: NormalizedAmountTrait::from_strk_native_amount(0),
        token_address,
    };
    store_to_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
        value: invalid_undelegate_intent_value,
    );
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    let result = staking_pool_safe_dispatcher
        .remove_from_delegation_pool_intent(:staker_address, :identifier, :amount);
    assert_panic_with_error(
        :result, expected_error: Error::INVALID_UNDELEGATE_INTENT_VALUE.describe(),
    );

    // Should catch AMOUNT_TOO_HIGH.
    let valid_undelegate_intent_value: UndelegateIntentValue = Zero::zero();
    store_to_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
        value: valid_undelegate_intent_value,
    );
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    let result = staking_pool_safe_dispatcher
        .remove_from_delegation_pool_intent(:staker_address, :identifier, :amount);
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_TOO_HIGH.describe());
}

#[test]
fn test_remove_from_delegation_pool_action() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token);
    // Remove from delegation pool intent, and then check that the intent was added correctly.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: cfg.pool_member_info._deprecated_amount,
        );
    // Remove from delegation pool action, and then check that the intent was removed correctly.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now()
            .add(delta: staking_dispatcher.contract_parameters_v1().exit_wait_window)
            .into(),
    );
    let pool_balance_before_action = token_dispatcher.balance_of(pool_contract);

    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_action(identifier: cfg.test_info.pool_member_address.into());
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let actual_undelegate_intent_value_after_action: UndelegateIntentValue = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    assert!(actual_undelegate_intent_value_after_action == Zero::zero());
    // Check that the amount was transferred correctly.
    let pool_balance_after_action = token_dispatcher.balance_of(pool_contract);
    assert!(
        pool_balance_after_action == pool_balance_before_action
            + cfg.pool_member_info._deprecated_amount.into(),
    );
    // Validate RemoveFromDelegationPoolAction event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "remove_from_delegation_pool_action",
    );
    assert_remove_from_delegation_pool_action_event(
        spied_event: events[0],
        :pool_contract,
        :token_address,
        identifier: cfg.test_info.pool_member_address.into(),
        amount: cfg.pool_member_info._deprecated_amount,
    );
}

// The following test checks that the remove_from_delegation_pool_action function works when there
// is no intent, but simply returns 0 and does not transfer any funds.
#[test]
fn test_remove_from_delegation_pool_action_intent_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = cfg.test_info.strk_token.contract_address();
    // Deploy staking contract.
    let staking_contract = deploy_staking_contract(:cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    let caller_address = CALLER_ADDRESS();
    // Remove from delegation pool action, and check it returns 0 and does not change balance.
    let staking_balance_before_action = token_dispatcher.balance_of(staking_contract);
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_pool_dispatcher.remove_from_delegation_pool_action(identifier: DUMMY_IDENTIFIER);
    let staking_balance_after_action = token_dispatcher.balance_of(staking_contract);
    assert!(staking_balance_after_action == staking_balance_before_action);
}

#[test]
#[should_panic(expected: "Intent window is not finished")]
fn test_remove_from_delegation_pool_action_intent_not_finished() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg);
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token);
    // Intent.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: cfg.pool_member_info._deprecated_amount,
        );
    // Try to action before the intent window is finished.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_action(identifier: cfg.test_info.pool_member_address.into());
}

#[test]
fn test_switch_staking_delegation_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;

    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    // Initialize from_staker.
    let from_pool_contract = stake_with_pool_enabled(:cfg);
    let from_pool_dispatcher = IPoolDispatcher { contract_address: from_pool_contract };
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: from_pool_contract, :cfg, :token,
    );
    // Initialize to_staker.
    let to_staker = OTHER_STAKER_ADDRESS();
    cfg.test_info.staker_address = to_staker;
    cfg.staker_info.operational_address = OTHER_OPERATIONAL_ADDRESS();
    let to_pool_contract = stake_with_pool_enabled(:cfg);
    let to_pool_dispatcher = IPoolDispatcher { contract_address: to_pool_contract };
    let to_staker_info = staking_dispatcher.staker_info_v1(staker_address: to_staker);
    // Pool member remove_from_delegation_pool_intent.
    let pool_member = cfg.test_info.pool_member_address;
    cheat_caller_address_once(contract_address: from_pool_contract, caller_address: pool_member);
    from_pool_dispatcher
        .exit_delegation_pool_intent(amount: cfg.pool_member_info._deprecated_amount);
    let total_stake_before_switching = staking_dispatcher.get_total_stake();
    // Initialize SwitchPoolData.
    let switch_pool_data = SwitchPoolData {
        pool_member, reward_address: cfg.pool_member_info.reward_address,
    };
    let mut serialized_data = array![];
    switch_pool_data.serialize(ref output: serialized_data);

    let switched_amount = cfg.pool_member_info._deprecated_amount / 2;
    let mut spy = snforge_std::spy_events();
    let caller_address = from_pool_contract;
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_pool_dispatcher
        .switch_staking_delegation_pool(
            :to_staker,
            to_pool: to_pool_contract,
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into(),
        );
    let mut expected_staker_info = to_staker_info;
    let mut expected_pool_info = expected_staker_info.get_pool_info();
    expected_pool_info.amount = switched_amount;
    expected_staker_info.pool_info = Option::Some(expected_pool_info);
    let actual_staker_info = staking_dispatcher.staker_info_v1(staker_address: to_staker);
    assert!(actual_staker_info == expected_staker_info);
    // Check total_stake was updated.
    let expected_total_stake = total_stake_before_switching + switched_amount;
    let actual_total_stake = staking_dispatcher.get_total_stake();
    assert!(actual_total_stake == expected_total_stake);
    // Check that the pool member's intent amount was decreased.
    let expected_undelegate_intent_value_amount = cfg.pool_member_info._deprecated_amount
        - switched_amount;
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: from_pool_contract, identifier: pool_member.into(),
    };
    let actual_undelegate_intent_value: UndelegateIntentValue = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    assert!(
        actual_undelegate_intent_value
            .amount
            .to_strk_native_amount() == expected_undelegate_intent_value_amount,
    );
    assert!(actual_undelegate_intent_value.unpool_time.is_non_zero());
    assert!(to_pool_dispatcher.pool_member_info_v1(:pool_member).amount == switched_amount);
    let caller_address = from_pool_contract;
    // Switch again with the rest of the amount, and verify the intent is removed.
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_pool_dispatcher
        .switch_staking_delegation_pool(
            :to_staker,
            to_pool: to_pool_contract,
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into(),
        );
    let actual_undelegate_intent_value_after_switching: UndelegateIntentValue =
        load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    assert!(actual_undelegate_intent_value_after_switching == Zero::zero());
    // Validate events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 4, message: "switch_staking_delegation_pool",
    );
    assert_stake_delegated_balance_changed_event(
        spied_event: events[0],
        staker_address: to_staker,
        :token_address,
        old_delegated_stake: Zero::zero(),
        new_delegated_stake: switched_amount,
    );
    assert_change_delegation_pool_intent_event(
        spied_event: events[1],
        pool_contract: from_pool_contract,
        :token_address,
        identifier: pool_member.into(),
        old_intent_amount: cfg.pool_member_info._deprecated_amount,
        new_intent_amount: cfg.pool_member_info._deprecated_amount - switched_amount,
    );
    assert_stake_delegated_balance_changed_event(
        spied_event: events[2],
        staker_address: to_staker,
        :token_address,
        old_delegated_stake: switched_amount,
        new_delegated_stake: switched_amount * 2,
    );
    assert_change_delegation_pool_intent_event(
        spied_event: events[3],
        pool_contract: from_pool_contract,
        :token_address,
        identifier: pool_member.into(),
        old_intent_amount: cfg.pool_member_info._deprecated_amount - switched_amount,
        new_intent_amount: Zero::zero(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_switch_staking_delegation_pool_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pool_safe_dispatcher = IStakingPoolSafeDispatcher {
        contract_address: staking_contract,
    };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let switched_amount = 1;

    // Initialize from_staker.
    let from_pool = stake_with_pool_enabled(:cfg);
    let from_pool_dispatcher = IPoolDispatcher { contract_address: from_pool };
    enter_delegation_pool_for_testing_using_dispatcher(pool_contract: from_pool, :cfg, :token);

    // Initialize to_staker.
    let to_staker = OTHER_STAKER_ADDRESS();
    cfg.test_info.staker_address = to_staker;
    cfg.staker_info.operational_address = OTHER_OPERATIONAL_ADDRESS();
    let to_pool = stake_with_pool_enabled(:cfg);

    // Initialize SwitchPoolData.
    let pool_member = cfg.test_info.pool_member_address;
    let switch_pool_data = SwitchPoolData {
        pool_member, reward_address: cfg.pool_member_info.reward_address,
    };
    let mut serialized_data = array![];
    switch_pool_data.serialize(ref output: serialized_data);

    // Catch MISSING_UNDELEGATE_INTENT.
    let result = staking_pool_safe_dispatcher
        .switch_staking_delegation_pool(
            :to_staker,
            :to_pool,
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into(),
        );
    assert_panic_with_error(
        :result, expected_error: PoolError::MISSING_UNDELEGATE_INTENT.describe(),
    );

    cheat_caller_address_once(contract_address: from_pool, caller_address: pool_member);
    from_pool_dispatcher
        .exit_delegation_pool_intent(amount: cfg.pool_member_info._deprecated_amount);

    // Catch AMOUNT_TOO_HIGH.
    let switched_amount = cfg.pool_member_info._deprecated_amount + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: from_pool);
    let result = staking_pool_safe_dispatcher
        .switch_staking_delegation_pool(
            :to_staker,
            :to_pool,
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into(),
        );
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_TOO_HIGH.describe());

    // Catch SELF_SWITCH_NOT_ALLOWED.
    let switched_amount = 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: from_pool);
    let result = staking_pool_safe_dispatcher
        .switch_staking_delegation_pool(
            :to_staker,
            to_pool: from_pool,
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into(),
        );
    assert_panic_with_error(:result, expected_error: Error::SELF_SWITCH_NOT_ALLOWED.describe());

    // Catch UNSTAKE_IN_PROGRESS.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: to_staker);
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: from_pool);
    let result = staking_pool_safe_dispatcher
        .switch_staking_delegation_pool(
            :to_staker,
            :to_pool,
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into(),
        );
    assert_panic_with_error(:result, expected_error: Error::UNSTAKE_IN_PROGRESS.describe());

    // Initialize a staker.
    let btc_staker = BTC_STAKER_ADDRESS();
    cfg.test_info.staker_address = btc_staker;
    cfg.staker_info.operational_address = DUMMY_ADDRESS();
    stake_for_testing_using_dispatcher(:cfg);

    // Catch DELEGATION_POOL_MISMATCH.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: from_pool);
    let result = staking_pool_safe_dispatcher
        .switch_staking_delegation_pool(
            to_staker: btc_staker,
            to_pool: DUMMY_ADDRESS(),
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into(),
        );
    assert_panic_with_error(:result, expected_error: Error::DELEGATION_POOL_MISMATCH.describe());

    // Open a BTC pool.
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: btc_staker);
    staking_dispatcher.set_commission(:commission);
    let btc_token_address = cfg.test_info.btc_token.contract_address();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: btc_staker);
    let btc_pool_contract = staking_dispatcher
        .set_open_for_delegation(token_address: btc_token_address);

    // Catch TOKEN_MISMATCH.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: from_pool);
    let result = staking_pool_safe_dispatcher
        .switch_staking_delegation_pool(
            to_staker: btc_staker,
            to_pool: btc_pool_contract,
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into(),
        );
    assert_panic_with_error(:result, expected_error: Error::TOKEN_MISMATCH.describe());
}

#[test]
fn test_pool_contract_roles() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the staking contract and stake with pool enabled.
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let pool_contract = stake_with_pool_enabled(:cfg);
    // Assert the correct governance admins are set.
    let pool_contract_roles_dispatcher = IRolesDispatcher { contract_address: pool_contract };
    assert!(
        pool_contract_roles_dispatcher
            .is_governance_admin(account: cfg.test_info.pool_contract_admin),
    );
    assert!(pool_contract_roles_dispatcher.is_governance_admin(account: staking_contract));
    assert!(pool_contract_roles_dispatcher.is_upgrade_governor(account: staking_contract));
    assert!(!pool_contract_roles_dispatcher.is_governance_admin(account: DUMMY_ADDRESS()));
}

#[test]
fn test_declare_operational_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    // Check map is empty before declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: operational_address,
        contract: staking_contract,
    );
    assert!(bound_staker == Zero::zero());
    // First declare
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address,
    );
    staking_dispatcher.declare_operational_address(:staker_address);
    // Check map is updated after declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: operational_address,
        contract: staking_contract,
    );
    assert!(bound_staker == staker_address);
    // Second declare
    let other_staker_address = OTHER_STAKER_ADDRESS();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address,
    );
    staking_dispatcher.declare_operational_address(staker_address: other_staker_address);
    // Check map is updated after declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: operational_address,
        contract: staking_contract,
    );
    assert!(bound_staker == other_staker_address);
    // Third declare with same operational and staker address - should not emit event or change map
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address,
    );
    staking_dispatcher.declare_operational_address(staker_address: other_staker_address);
    // Check map is updated after declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: operational_address,
        contract: staking_contract,
    );
    assert!(bound_staker == other_staker_address);
    // Fourth declare - set to zero
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address,
    );
    staking_dispatcher.declare_operational_address(staker_address: Zero::zero());
    // Check map is updated after declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: operational_address,
        contract: staking_contract,
    );
    assert!(bound_staker == Zero::zero());
    // Validate the OperationalAddressDeclared events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 3, message: "declare_operational_address",
    );
    assert_declare_operational_address_event(
        spied_event: events[0], :operational_address, :staker_address,
    );
    assert_declare_operational_address_event(
        spied_event: events[1], :operational_address, staker_address: other_staker_address,
    );
    assert_declare_operational_address_event(
        spied_event: events[2], :operational_address, staker_address: Zero::zero(),
    );
}

#[test]
#[should_panic(expected: "Operational address is in use")]
fn test_declare_operational_address_operational_address_exists() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let operational_address = cfg.staker_info.operational_address;
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address,
    );
    staking_dispatcher.declare_operational_address(staker_address: DUMMY_ADDRESS());
}

#[test]
fn test_change_operational_address() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address,
    );
    staking_dispatcher.declare_operational_address(:staker_address);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.change_operational_address(:operational_address);
    let updated_staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let expected_staker_info = StakerInfoV1 { operational_address, ..staker_info };
    assert!(updated_staker_info == expected_staker_info);
    // Validate the OperationalAddressDeclared and OperationalAddressChanged events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "change_operational_address",
    );
    assert_declare_operational_address_event(
        spied_event: events[0], :operational_address, :staker_address,
    );
    assert_change_operational_address_event(
        spied_event: events[1],
        :staker_address,
        new_address: operational_address,
        old_address: cfg.staker_info.operational_address,
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_change_operational_address_staker_doesnt_exist() {
    let cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    staking_dispatcher.change_operational_address(:operational_address);
}

#[test]
#[should_panic(expected: "Operational address already exists")]
fn test_change_operational_address_operational_address_exists() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    let operational_address = cfg.staker_info.operational_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.change_operational_address(:operational_address);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_change_operational_address_unstake_in_progress() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.change_operational_address(:operational_address);
}

#[test]
#[should_panic(expected: "Operational address had not been declared by staker")]
fn test_change_operational_address_is_not_eligible() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.change_operational_address(:operational_address);
}

#[test]
fn test_set_commission() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let pool_contract = stake_with_pool_enabled(:cfg);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token);
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    let staker_address = cfg.test_info.staker_address;
    let staker_info_before_update = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(
        staker_info_before_update
            .get_pool_info()
            .commission == cfg
            .staker_info
            ._deprecated_get_pool_info()
            ._deprecated_commission,
    );

    // Update commission.
    let mut spy = snforge_std::spy_events();
    let old_commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    let commission = old_commission - 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission(:commission);

    // Assert commission is updated.
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info.get_pool_info().commission == commission);
    let staker_pool_info = staking_dispatcher.staker_pool_info(:staker_address);
    assert!(staker_pool_info.commission == Option::Some(commission));

    // Assert commission is updated in the pool contract.
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let pool_contracts_parameters = pool_dispatcher.contract_parameters_v1();
    let expected_pool_contracts_parameters = PoolContractInfoV1 {
        commission, ..pool_contracts_parameters,
    };
    assert!(pool_contracts_parameters == expected_pool_contracts_parameters);
    // Validate the single CommissionChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_commission");
    assert_commission_changed_event(
        spied_event: events[0], :staker_address, new_commission: commission, :old_commission,
    );

    // Assert rewards is calculated correctly.
    let pool_balance_before = token_dispatcher.balance_of(account: pool_contract);
    advance_epoch_global();
    advance_block_into_attestation_window(
        :cfg, stake: cfg.test_info.stake_amount + cfg.pool_member_info._deprecated_amount,
    );
    // Calculate rewards.
    let (expected_staker_rewards, expected_pool_rewards) = calculate_staker_strk_rewards(
        :staker_info,
        :staking_contract,
        minting_curve_contract: cfg.reward_supplier.minting_curve_contract,
    );
    assert!(expected_staker_rewards.is_non_zero());
    assert!(expected_pool_rewards.is_non_zero());
    // Funds reward supplier.
    fund(target: reward_supplier, amount: expected_staker_rewards + expected_pool_rewards, :token);
    // Attest and get rewards.
    let block_hash = Zero::zero();
    cheat_target_attestation_block_hash(:cfg, :block_hash);
    cheat_caller_address_once(
        contract_address: attestation_contract, caller_address: cfg.staker_info.operational_address,
    );
    attestation_dispatcher.attest(:block_hash);
    // Test staker rewards.
    let expected_staker_info = StakerInfoV1 {
        unclaimed_rewards_own: expected_staker_rewards, ..staker_info,
    };
    assert!(staking_dispatcher.staker_info_v1(:staker_address) == expected_staker_info);
    // Test pool rewards.
    let pool_balance_after = token_dispatcher.balance_of(account: pool_contract);
    assert!(pool_balance_after == pool_balance_before + expected_pool_rewards.into());
}

#[test]
fn test_set_commission_with_commitment() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg);

    // Set commitment.
    let staker_address = cfg.test_info.staker_address;
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let max_commission = staker_info.get_pool_info().commission + 2;
    let expiration_epoch = staking_dispatcher.get_current_epoch() + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission_commitment(:max_commission, :expiration_epoch);

    // Update commission.
    let mut commission = max_commission;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission(:commission);

    // Assert commission is updated.
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info.get_pool_info().commission == commission);

    // Advance to the expiration epoch.
    advance_epoch_global();

    // Lower commission.
    commission = commission - 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission(:commission);

    // Assert commission is updated.
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info.get_pool_info().commission == commission);
}


#[test]
#[feature("safe_dispatcher")]
fn test_set_commission_assertions_with_commitment() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_safe_dispatcher = IStakingSafeDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg);

    // Set commitment.
    let staker_address = cfg.test_info.staker_address;
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let max_commission = staker_info.get_pool_info().commission + 2;
    let expiration_epoch = staking_dispatcher.get_current_epoch() + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission_commitment(:max_commission, :expiration_epoch);

    // Should catch INVALID_COMMISSION_WITH_COMMITMENT.
    let commission = max_commission + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher.set_commission(:commission);
    assert_panic_with_error(
        :result, expected_error: GenericError::INVALID_COMMISSION_WITH_COMMITMENT.describe(),
    );

    // Should catch INVALID_SAME_COMMISSION.
    let commission = max_commission;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission(:commission);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher.set_commission(:commission);
    assert_panic_with_error(
        :result, expected_error: GenericError::INVALID_SAME_COMMISSION.describe(),
    );

    // Advance to the expiration epoch.
    advance_epoch_global();

    // Should catch COMMISSION_COMMITMENT_EXPIRED.
    let commission = max_commission;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher.set_commission(:commission);
    assert_panic_with_error(
        :result, expected_error: GenericError::COMMISSION_COMMITMENT_EXPIRED.describe(),
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_set_commission_caller_not_staker() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .set_commission(
            commission: cfg.staker_info._deprecated_get_pool_info()._deprecated_commission - 1,
        );
}

#[test]
#[should_panic(expected: "Commission can only be decreased")]
fn test_set_commission_with_higher_commission() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    stake_with_pool_enabled(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher
        .set_commission(
            commission: cfg.staker_info._deprecated_get_pool_info()._deprecated_commission + 1,
        );
}

#[test]
#[should_panic(expected: "Commission can only be decreased")]
fn test_set_commission_with_same_commission() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    stake_with_pool_enabled(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher
        .set_commission(
            commission: cfg.staker_info._deprecated_get_pool_info()._deprecated_commission,
        );
}

#[test]
fn test_set_commission_initialize_commission() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    let mut spy = snforge_std::spy_events();
    staking_dispatcher.set_commission(:commission);
    let staker_pool_info = staking_dispatcher.staker_pool_info(:staker_address);
    assert!(staker_pool_info.commission == Option::Some(commission));
    // Assert event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_commission");
    assert_commission_initialized_event(spied_event: events[0], :staker_address, :commission);
    // Assert commission in staker_info_v1 after openning a strk pool.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_open_for_delegation(:token_address);
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info.get_pool_info().commission == commission);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_set_commission_staker_in_exit_window() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher
        .set_commission(
            commission: cfg.staker_info._deprecated_get_pool_info()._deprecated_commission - 1,
        );
}

#[test]
#[should_panic(expected: "Commission is out of range, expected to be 0-10000")]
fn test_set_commission_commission_out_of_range() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let commission = COMMISSION_DENOMINATOR + 1;
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.set_commission(:commission);
}

#[test]
fn test_set_commission_commitment() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg);
    let staker_address = cfg.test_info.staker_address;
    let max_commission = COMMISSION_DENOMINATOR;
    let mut spy = snforge_std::spy_events();
    let expiration_epoch = staking_dispatcher.get_current_epoch() + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission_commitment(:max_commission, :expiration_epoch);
    let commission_commitment = staking_dispatcher
        .get_staker_commission_commitment(:staker_address);
    let expected_commission_commitment = CommissionCommitment { max_commission, expiration_epoch };
    assert!(commission_commitment == expected_commission_commitment);
    // Validate the CommissionCommitmentSet event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "set_commission_commitment",
    );
    assert_commission_commitment_set_event(
        spied_event: events[0], :staker_address, :max_commission, :expiration_epoch,
    );
}

#[test]
#[should_panic(expected: "Commission commitment not set")]
fn test_get_staker_commission_commitment_no_commitment() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg);
    let staker_address = cfg.test_info.staker_address;
    staking_dispatcher.get_staker_commission_commitment(:staker_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_set_commission_commitment_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.test_info.strk_token.contract_address();
    let staker_address = cfg.test_info.staker_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_safe_dispatcher = IStakingSafeDispatcher { contract_address: staking_contract };

    // Should catch COMMISSION_OUT_OF_RANGE.
    let max_commission = COMMISSION_DENOMINATOR + 1;
    let expiration_epoch = staking_dispatcher.get_current_epoch() + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher
        .set_commission_commitment(:max_commission, :expiration_epoch);
    assert_panic_with_error(:result, expected_error: Error::COMMISSION_OUT_OF_RANGE.describe());

    // Should catch STAKER_NOT_EXISTS.
    let result = staking_safe_dispatcher
        .set_commission_commitment(max_commission: Zero::zero(), expiration_epoch: Zero::zero());
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());

    // Should catch MISSING_POOL_CONTRACT.
    stake_for_testing_using_dispatcher(:cfg);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher
        .set_commission_commitment(max_commission: Zero::zero(), expiration_epoch: Zero::zero());
    assert_panic_with_error(:result, expected_error: Error::MISSING_POOL_CONTRACT.describe());

    // Should catch MAX_COMMISSION_TOO_LOW.
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    staking_dispatcher.set_commission(:commission);
    staking_dispatcher.set_open_for_delegation(:token_address);
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let max_commission = staker_info.get_pool_info().commission - 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher
        .set_commission_commitment(:max_commission, :expiration_epoch);
    assert_panic_with_error(:result, expected_error: Error::MAX_COMMISSION_TOO_LOW.describe());

    // Should catch EXPIRATION_EPOCH_TOO_EARLY.
    let max_commission = staker_info.get_pool_info().commission;
    let expiration_epoch = staking_dispatcher.get_current_epoch();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher
        .set_commission_commitment(:max_commission, :expiration_epoch);
    assert_panic_with_error(:result, expected_error: Error::EXPIRATION_EPOCH_TOO_EARLY.describe());

    // Should catch EXPIRATION_EPOCH_TOO_FAR.
    let expiration_epoch = staking_dispatcher.get_current_epoch()
        + staking_dispatcher.get_epoch_info().epochs_in_year()
        + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher
        .set_commission_commitment(:max_commission, :expiration_epoch);
    assert_panic_with_error(:result, expected_error: Error::EXPIRATION_EPOCH_TOO_FAR.describe());

    // Should catch COMMISSION_COMMITMENT_EXISTS.
    let expiration_epoch = staking_dispatcher.get_current_epoch() + 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_commission_commitment(:max_commission, :expiration_epoch);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher
        .set_commission_commitment(:max_commission, :expiration_epoch);
    assert_panic_with_error(
        :result, expected_error: Error::COMMISSION_COMMITMENT_EXISTS.describe(),
    );

    // Should catch UNSTAKE_IN_PROGRESS.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_safe_dispatcher
        .set_commission_commitment(:max_commission, :expiration_epoch);
    assert_panic_with_error(:result, expected_error: Error::UNSTAKE_IN_PROGRESS.describe());
}

#[test]
fn test_set_open_for_delegation() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    staking_dispatcher.set_commission(:commission);
    let mut spy = snforge_std::spy_events();
    let pool_contract = staking_dispatcher.set_open_for_delegation(:token_address);
    let pool_info = staking_dispatcher.staker_info_v1(:staker_address).get_pool_info();
    let mut expected_pool_info = StakerPoolInfoV1 {
        pool_contract, amount: Zero::zero(), commission,
    };
    assert!(pool_info == expected_pool_info);

    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_open_for_delegation");
    assert_new_delegation_pool_event(
        spied_event: events[0], :staker_address, :pool_contract, :token_address, :commission,
    );
}

#[test]
fn test_set_open_for_delegation_with_btc_token() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let btc_token_address = setup_btc_token(:cfg, name: BTC_TOKEN_NAME());
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    // Open pool for the btc token.
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    staking_dispatcher.set_commission(:commission);
    let mut spy = snforge_std::spy_events();
    let pool_contract = staking_dispatcher
        .set_open_for_delegation(token_address: btc_token_address);
    // Test.
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info.pool_info.is_none());
    let staker_pool_info = staking_dispatcher.staker_pool_info(:staker_address);
    assert!(staker_pool_info.pools.len() == 1);
    let expected_pool_info = PoolInfo {
        pool_contract, token_address: btc_token_address, amount: Zero::zero(),
    };
    assert!(*staker_pool_info.pools[0] == expected_pool_info);
    // Test event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_open_for_delegation");
    assert_new_delegation_pool_event(
        spied_event: events[0],
        :staker_address,
        :pool_contract,
        token_address: btc_token_address,
        :commission,
    );
}

#[test]
fn test_set_open_for_delegation_with_disabled_btc_token() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    let disabled_btc_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME_2(),
        decimals: constants::TEST_BTC_DECIMALS,
    );
    // Only add the token but not enable it.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    staking_token_dispatcher.add_token(token_address: disabled_btc_token_address);
    // Open pool for the token.
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    staking_dispatcher.set_commission(:commission);
    let pool_contract = staking_dispatcher
        .set_open_for_delegation(token_address: disabled_btc_token_address);
    // Test.
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info.pool_info.is_none());
    let staker_pool_info = staking_dispatcher.staker_pool_info(:staker_address);
    assert!(staker_pool_info.pools.len() == 1);
    let expected_pool_info = PoolInfo {
        pool_contract, token_address: disabled_btc_token_address, amount: Zero::zero(),
    };
    assert!(*staker_pool_info.pools[0] == expected_pool_info);
}

#[test]
#[should_panic(expected: "Commission is not set")]
fn test_set_open_for_delegation_commission_not_set() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.set_open_for_delegation(:token_address);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_set_open_for_delegation_unstake_in_progress() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_open_for_delegation(:token_address);
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_set_open_for_delegation_staker_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = deploy_staking_contract(:cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher.set_open_for_delegation(:token_address);
}

#[test]
#[should_panic(expected: "Staker already has a pool")]
fn test_set_open_for_delegation_strk_token_staker_has_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.set_open_for_delegation(:token_address);
}

#[test]
#[should_panic(expected: "Staker already has a pool")]
fn test_set_open_for_delegation_btc_token_staker_has_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let btc_token_address = setup_btc_token(:cfg, name: BTC_TOKEN_NAME());
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.set_open_for_delegation(token_address: btc_token_address);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.set_open_for_delegation(token_address: btc_token_address);
}

#[test]
#[should_panic(expected: "Token does not exist")]
fn test_set_open_for_delegation_token_does_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.set_open_for_delegation(token_address: DUMMY_ADDRESS());
}

#[test]
fn test_set_min_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let old_min_stake = cfg.staking_contract_info.min_stake;
    assert!(old_min_stake == staking_dispatcher.contract_parameters_v1().min_stake);
    let new_min_stake = old_min_stake / 2;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_min_stake(min_stake: new_min_stake);
    assert!(new_min_stake == staking_dispatcher.contract_parameters_v1().min_stake);
    // Validate MinimumStakeChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_min_stake");
    assert_minimum_stake_changed_event(spied_event: events[0], :old_min_stake, :new_min_stake);
}

#[test]
#[should_panic(expected: "ONLY_TOKEN_ADMIN")]
fn test_set_min_stake_not_token_admin() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let min_stake = cfg.staking_contract_info.min_stake;
    let non_token_admin = NON_TOKEN_ADMIN();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: non_token_admin);
    staking_config_dispatcher.set_min_stake(:min_stake);
}

#[test]
fn test_set_exit_waiting_window() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let old_exit_window = cfg.staking_contract_info.exit_wait_window;
    assert!(old_exit_window == staking_dispatcher.contract_parameters_v1().exit_wait_window);
    let new_exit_window = TimeDelta { seconds: DAY * 7 };
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_exit_wait_window(exit_wait_window: new_exit_window);
    assert!(new_exit_window == staking_dispatcher.contract_parameters_v1().exit_wait_window);
    // Validate the single ExitWaitWindowChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_exit_wait_window");
    assert_exit_wait_window_changed_event(
        spied_event: events[0], :old_exit_window, :new_exit_window,
    );
}

#[test]
#[should_panic(expected: "ONLY_TOKEN_ADMIN")]
fn test_set_exit_waiting_window_not_token_admin() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let exit_wait_window = cfg.staking_contract_info.exit_wait_window;
    let non_token_admin = NON_TOKEN_ADMIN();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: non_token_admin);
    staking_config_dispatcher.set_exit_wait_window(:exit_wait_window);
}

#[test]
fn test_set_max_exit_waiting_duration() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let new_exit_window = MAX_EXIT_WAIT_WINDOW;
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_exit_wait_window(exit_wait_window: new_exit_window);
}

#[test]
#[should_panic(expected: "ILLEGAL_EXIT_DURATION")]
fn test_set_too_long_exit_duration() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let mut new_exit_window: TimeDelta = MAX_EXIT_WAIT_WINDOW;
    new_exit_window.seconds += 1;
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_exit_wait_window(exit_wait_window: new_exit_window);
}

#[test]
fn test_set_reward_supplier() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let old_reward_supplier = cfg.staking_contract_info.reward_supplier;
    assert!(old_reward_supplier == staking_dispatcher.contract_parameters_v1().reward_supplier);
    let new_reward_supplier = OTHER_REWARD_SUPPLIER_CONTRACT_ADDRESS();
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_reward_supplier(reward_supplier: new_reward_supplier);
    assert!(new_reward_supplier == staking_dispatcher.contract_parameters_v1().reward_supplier);
    // Validate the single RewardSupplierChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_reward_supplier");
    assert_reward_supplier_changed_event(
        spied_event: events[0], :old_reward_supplier, :new_reward_supplier,
    );
}

#[test]
#[should_panic(expected: "ONLY_TOKEN_ADMIN")]
fn test_set_reward_supplier_not_token_admin() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let non_token_admin = NON_TOKEN_ADMIN();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: non_token_admin);
    staking_config_dispatcher.set_reward_supplier(:reward_supplier);
}

#[test]
fn test_staker_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let mut expected_staker_info: StakerInfoV1 = cfg.staker_info.into();
    expected_staker_info.pool_info = Option::None;
    expected_staker_info.amount_own = cfg.test_info.stake_amount;
    stake_for_testing_using_dispatcher(:cfg);
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info == expected_staker_info);
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_staker_info_staker_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher.staker_info_v1(staker_address: NON_STAKER_ADDRESS());
}

#[test]
fn test_staker_pool_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let pool_contract = stake_with_pool_enabled(:cfg);
    let expected_pool_info = PoolInfo { pool_contract, token_address, amount: Zero::zero() };
    let expected_staker_pool_info = StakerPoolInfoV2 {
        commission: Option::Some(
            cfg.staker_info._deprecated_get_pool_info()._deprecated_commission,
        ),
        pools: [expected_pool_info].span(),
    };
    let staker_pool_info = staking_dispatcher.staker_pool_info(:staker_address);
    assert!(staker_pool_info == expected_staker_pool_info);
}

#[test]
fn test_staker_pool_info_with_multiple_pools() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    let strk_pool_contract = stake_with_pool_enabled(:cfg);
    let strk_delegated_amount = cfg.pool_member_info._deprecated_amount;
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: strk_pool_contract, :cfg, :token,
    );
    let btc_token = cfg.test_info.btc_token;
    let btc_token_address = btc_token.contract_address();
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let btc_pool_contract = staking_dispatcher
        .set_open_for_delegation(token_address: btc_token_address);
    let btc_delegated_amount = strk_delegated_amount * 2;
    cfg.pool_member_info._deprecated_amount = btc_delegated_amount;
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: btc_pool_contract, :cfg, token: btc_token,
    );

    let expected_strk_pool_info = PoolInfo {
        pool_contract: strk_pool_contract, token_address, amount: strk_delegated_amount,
    };
    let expected_btc_pool_info = PoolInfo {
        pool_contract: btc_pool_contract,
        token_address: btc_token_address,
        amount: btc_delegated_amount,
    };
    let expected_staker_pool_info = StakerPoolInfoV2 {
        commission: Option::Some(
            cfg.staker_info._deprecated_get_pool_info()._deprecated_commission,
        ),
        pools: [expected_strk_pool_info, expected_btc_pool_info].span(),
    };
    let staker_pool_info = staking_dispatcher.staker_pool_info(:staker_address);
    assert!(staker_pool_info == expected_staker_pool_info);
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_staker_pool_info_staker_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher.staker_pool_info(staker_address: NON_STAKER_ADDRESS());
}

#[test]
fn test_get_staker_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    // Check before staker enters.
    let option_staker_info = staking_dispatcher.get_staker_info_v1(:staker_address);
    assert!(option_staker_info.is_none());
    // Check after staker enters.
    let mut expected_staker_info: StakerInfoV1 = cfg.staker_info.into();
    expected_staker_info.pool_info = Option::None;
    expected_staker_info.amount_own = cfg.test_info.stake_amount;
    stake_for_testing_using_dispatcher(:cfg);
    let option_staker_info = staking_dispatcher.get_staker_info_v1(:staker_address);
    assert!(option_staker_info == Option::Some(expected_staker_info));
}


#[test]
#[should_panic(expected: "Zero address caller is not allowed")]
fn test_assert_caller_is_not_zero() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    cfg.test_info.staker_address = Zero::zero();
    stake_from_zero_address(:cfg);
}

#[test]
#[feature("safe_dispatcher")]
fn test_get_attestation_info_by_operational_address_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_safe_dispatcher = IStakingAttestationSafeDispatcher {
        contract_address: staking_contract,
    };
    stake_for_testing_using_dispatcher(:cfg);

    // Catch STAKER_NOT_EXISTS.
    let operational_address = DUMMY_ADDRESS();
    let result = staking_safe_dispatcher
        .get_attestation_info_by_operational_address(:operational_address);
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());
}

#[test]
fn test_get_attestation_info_by_operational_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingAttestationDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    advance_epoch_global();
    let operational_address = cfg.staker_info.operational_address;
    let mut attestation_info = staking_dispatcher
        .get_attestation_info_by_operational_address(:operational_address);
    assert!(attestation_info.staker_address() == cfg.test_info.staker_address);
    assert!(attestation_info.stake() == cfg.test_info.stake_amount);
    assert!(attestation_info.epoch_len() == EPOCH_LENGTH);
    assert!(attestation_info.epoch_id() == 1);
    assert!(
        attestation_info
            .current_epoch_starting_block() == cfg
            .staking_contract_info
            .epoch_info
            .current_epoch_starting_block(),
    );
}


#[test]
fn test_get_current_epoch() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let current_epoch = staking_dispatcher.get_current_epoch();
    assert!(current_epoch == 0);
    advance_block_number_global(blocks: EPOCH_LENGTH.into() - 1);
    let current_epoch = staking_dispatcher.get_current_epoch();
    assert!(current_epoch == 0);
    advance_block_number_global(blocks: 1);
    let current_epoch = staking_dispatcher.get_current_epoch();
    assert!(current_epoch == 1);
}

#[test]
fn test_current_epoch_starting_block() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let epoch_info = staking_dispatcher.get_epoch_info();
    assert_eq!(epoch_info.current_epoch_starting_block(), EPOCH_STARTING_BLOCK);
    advance_block_number_global(blocks: EPOCH_LENGTH.into() - 1);
    let epoch_info = staking_dispatcher.get_epoch_info();
    assert_eq!(epoch_info.current_epoch_starting_block(), EPOCH_STARTING_BLOCK);
    advance_block_number_global(blocks: 1);
    let next_epoch_starting_block = EPOCH_STARTING_BLOCK + EPOCH_LENGTH.into();
    let epoch_info = staking_dispatcher.get_epoch_info();
    assert_eq!(epoch_info.current_epoch_starting_block(), next_epoch_starting_block);

    // Update epoch len and check again.
    let new_epoch_len = EPOCH_LENGTH.into() * 15;
    let new_epoch_duration = EPOCH_DURATION / 15;
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.app_governor,
    );
    staking_config_dispatcher
        .set_epoch_info(epoch_duration: new_epoch_duration, epoch_length: new_epoch_len);
    let epoch_info = staking_dispatcher.get_epoch_info();
    // No new epoch started yet, so starting block should be the same.
    assert_eq!(epoch_info.current_epoch_starting_block(), next_epoch_starting_block);
    // Advance epoch and check again.
    advance_epoch_global();
    let epoch_info = staking_dispatcher.get_epoch_info();
    assert_eq!(
        epoch_info.current_epoch_starting_block(), next_epoch_starting_block + EPOCH_LENGTH.into(),
    );
    // Advance epoch and check again.
    advance_block_number_global(blocks: new_epoch_len.into());
    let epoch_info = staking_dispatcher.get_epoch_info();
    assert_eq!(
        epoch_info.current_epoch_starting_block(),
        next_epoch_starting_block + EPOCH_LENGTH.into() + new_epoch_len.into(),
    );
}

#[test]
fn test_update_rewards_from_attestation_contract_only_staker() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_attestation_dispatcher = IStakingAttestationDispatcher {
        contract_address: staking_contract,
    };
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier,
    };
    stake_for_testing_using_dispatcher(:cfg);
    advance_epoch_global();
    let staker_address = cfg.test_info.staker_address;
    let attestation_contract = cfg.test_info.attestation_contract;
    let staker_info_before = staking_dispatcher.staker_info_v1(:staker_address);
    let (strk_epoch_rewards, _) = reward_supplier_dispatcher.calculate_current_epoch_rewards();
    let staker_info_expected = StakerInfoV1 {
        unclaimed_rewards_own: strk_epoch_rewards, ..staker_info_before,
    };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: attestation_contract,
    );
    staking_attestation_dispatcher.update_rewards_from_attestation_contract(:staker_address);
    let staker_info_after = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info_after == staker_info_expected);
}

#[test]
fn test_update_rewards_from_attestation_contract_with_pool_member() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_attestation_dispatcher = IStakingAttestationDispatcher {
        contract_address: staking_contract,
    };
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let pool_contract = stake_with_pool_enabled(:cfg);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token);
    advance_epoch_global();
    let staker_address = cfg.test_info.staker_address;
    let attestation_contract = cfg.test_info.attestation_contract;
    let staker_info_before = staking_dispatcher.staker_info_v1(:staker_address);
    let pool_member = cfg.test_info.pool_member_address;

    // Calculate rewards.
    let (expected_staker_rewards, expected_pool_rewards) = calculate_staker_strk_rewards(
        staker_info: staker_info_before, :staking_contract, :minting_curve_contract,
    );
    // Assert staker rewards, delegator rewards, and pool balance before update.
    assert!(staker_info_before.unclaimed_rewards_own.is_zero());
    assert!(token_dispatcher.balance_of(pool_contract).is_zero());
    assert!(pool_dispatcher.pool_member_info_v1(:pool_member).unclaimed_rewards.is_zero());

    // Fund reward supplier.
    fund(target: reward_supplier, amount: expected_staker_rewards + expected_pool_rewards, :token);
    let staker_info_expected = StakerInfoV1 {
        unclaimed_rewards_own: expected_staker_rewards, ..staker_info_before,
    };
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: attestation_contract,
    );
    staking_attestation_dispatcher.update_rewards_from_attestation_contract(:staker_address);
    advance_epoch_global();

    // Assert staker rewards update.
    let staker_info_after = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info_after == staker_info_expected);

    // Assert pool and delegator rewards.
    assert!(token_dispatcher.balance_of(pool_contract) == expected_pool_rewards.into());
    // Since there is only one delegator, pool rewards should be the same as the delegator
    // rewards.
    assert!(
        pool_dispatcher
            .pool_member_info_v1(:pool_member)
            .unclaimed_rewards == expected_pool_rewards,
    );

    // Validate RewardsSuppliedToDelegationPool and StakerRewardsUpdated event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "update_rewards_from_attestation_contract",
    );
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[0],
        :staker_address,
        pool_address: pool_contract,
        amount: expected_pool_rewards,
    );
    assert_staker_rewards_updated_event(
        spied_event: events[1],
        :staker_address,
        staker_rewards: expected_staker_rewards,
        pool_rewards: [(pool_contract, expected_pool_rewards)].span(),
    );
}

#[test]
fn test_update_rewards_from_attestation_contract_with_both_strk_and_btc() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_attestation_dispatcher = IStakingAttestationDispatcher {
        contract_address: staking_contract,
    };
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let btc_token = cfg.test_info.btc_token;
    let btc_token_address = btc_token.contract_address();
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    // Stake and open pool for STRK.
    let strk_pool_contract = stake_with_pool_enabled(:cfg);
    let staker_address = cfg.test_info.staker_address;
    let commission = cfg.staker_info._deprecated_get_pool_info()._deprecated_commission;
    // Open pool for BTC.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let btc_pool_contract = staking_dispatcher
        .set_open_for_delegation(token_address: btc_token_address);
    // Add another BTC token.
    let btc_token_address_2 = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME_2(),
        decimals: constants::TEST_BTC_DECIMALS,
    );
    let btc_token_2 = custom_decimals_token(token_address: btc_token_address_2);
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: cfg.test_info.token_admin,
        span: CheatSpan::TargetCalls(2),
    );
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    staking_token_dispatcher.add_token(token_address: btc_token_address_2);
    staking_token_dispatcher.enable_token(token_address: btc_token_address_2);
    // Open pool for the second BTC token.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let btc_pool_contract_2 = staking_dispatcher
        .set_open_for_delegation(token_address: btc_token_address_2);
    // Enter pools.
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: strk_pool_contract, :cfg, :token,
    );
    // Set delegated amount for BTC pools.
    // TODO: Use enter_btc pool function.
    cfg.pool_member_info._deprecated_amount = cfg.test_info.pool_member_btc_amount;
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: btc_pool_contract, :cfg, token: btc_token,
    );
    // Set delegated amount for BTC pools.
    // TODO: Use enter_btc pool function.
    cfg.pool_member_info._deprecated_amount = cfg.test_info.pool_member_btc_amount;
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: btc_pool_contract_2, :cfg, token: btc_token_2,
    );
    advance_epoch_global();
    let attestation_contract = cfg.test_info.attestation_contract;
    let staker_info_before = staking_dispatcher.staker_info_v1(:staker_address);
    let pool_member = cfg.test_info.pool_member_address;
    let strk_pool_dispatcher = IPoolDispatcher { contract_address: strk_pool_contract };
    let btc_pool_dispatcher = IPoolDispatcher { contract_address: btc_pool_contract };
    let btc_pool_dispatcher_2 = IPoolDispatcher { contract_address: btc_pool_contract_2 };
    // Calculate rewards.
    let (expected_staker_strk_rewards, expected_strk_pool_rewards) = calculate_staker_strk_rewards(
        staker_info: staker_info_before, :staking_contract, :minting_curve_contract,
    );
    // Same calculation for both BTC pools (both have the same decimals).
    let (expected_staker_btc_rewards_for_pool, expected_btc_pool_rewards) =
        calculate_staker_btc_pool_rewards(
        pool_balance: cfg.pool_member_info._deprecated_amount,
        :commission,
        :staking_contract,
        :minting_curve_contract,
        token_address: btc_token_address,
    );
    // Assert staker rewards, delegator rewards, and pool balance before update.
    assert!(staker_info_before.unclaimed_rewards_own.is_zero());
    assert!(token_dispatcher.balance_of(strk_pool_contract).is_zero());
    assert!(token_dispatcher.balance_of(btc_pool_contract).is_zero());
    assert!(token_dispatcher.balance_of(btc_pool_contract_2).is_zero());
    assert!(strk_pool_dispatcher.pool_member_info_v1(:pool_member).unclaimed_rewards.is_zero());
    assert!(btc_pool_dispatcher.pool_member_info_v1(:pool_member).unclaimed_rewards.is_zero());
    assert!(btc_pool_dispatcher_2.pool_member_info_v1(:pool_member).unclaimed_rewards.is_zero());

    // Fund reward supplier.
    // Staker gets rewards from the both BTC pools.
    let expected_staker_total_rewards = expected_staker_strk_rewards
        + 2 * expected_staker_btc_rewards_for_pool;
    // Total rewards are the sum of staker rewards and pool rewards: 1 STRK pool and 2 BTC pools.
    let total_rewards = expected_staker_total_rewards
        + expected_strk_pool_rewards
        + 2 * expected_btc_pool_rewards;
    fund(target: reward_supplier, amount: total_rewards, :token);
    let staker_info_expected = StakerInfoV1 {
        unclaimed_rewards_own: expected_staker_total_rewards, ..staker_info_before,
    };
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: attestation_contract,
    );
    staking_attestation_dispatcher.update_rewards_from_attestation_contract(:staker_address);
    advance_epoch_global();

    // Assert staker rewards update.
    let staker_info_after = staking_dispatcher.staker_info_v1(:staker_address);
    assert!(staker_info_after == staker_info_expected);

    // Assert pool and delegator rewards.
    assert!(token_dispatcher.balance_of(strk_pool_contract) == expected_strk_pool_rewards.into());
    assert!(token_dispatcher.balance_of(btc_pool_contract) == expected_btc_pool_rewards.into());
    assert!(token_dispatcher.balance_of(btc_pool_contract_2) == expected_btc_pool_rewards.into());
    // Since there is only one delegator, pool rewards should be the same as the delegator
    // rewards.
    assert!(
        strk_pool_dispatcher
            .pool_member_info_v1(:pool_member)
            .unclaimed_rewards == expected_strk_pool_rewards,
    );
    assert!(
        btc_pool_dispatcher
            .pool_member_info_v1(:pool_member)
            .unclaimed_rewards == expected_btc_pool_rewards,
    );
    assert!(
        btc_pool_dispatcher_2
            .pool_member_info_v1(:pool_member)
            .unclaimed_rewards == expected_btc_pool_rewards,
    );

    // Validate RewardsSuppliedToDelegationPool and StakerRewardsUpdated events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 4, message: "update_rewards_from_attestation_contract",
    );
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[0],
        :staker_address,
        pool_address: strk_pool_contract,
        amount: expected_strk_pool_rewards,
    );
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[1],
        :staker_address,
        pool_address: btc_pool_contract,
        amount: expected_btc_pool_rewards,
    );
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[2],
        :staker_address,
        pool_address: btc_pool_contract_2,
        amount: expected_btc_pool_rewards,
    );
    assert_staker_rewards_updated_event(
        spied_event: events[3],
        :staker_address,
        staker_rewards: expected_staker_total_rewards,
        pool_rewards: [
            (strk_pool_contract, expected_strk_pool_rewards),
            (btc_pool_contract, expected_btc_pool_rewards),
            (btc_pool_contract_2, expected_btc_pool_rewards),
        ]
            .span(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_update_rewards_from_attestation_contract_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_safe_dispatcher = IStakingAttestationSafeDispatcher {
        contract_address: staking_contract,
    };
    let staker_address = cfg.test_info.staker_address;
    let attestation_contract = cfg.test_info.attestation_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);

    // Catch CALLER_IS_NOT_ATTESTATION_CONTRACT.
    let result = staking_safe_dispatcher.update_rewards_from_attestation_contract(:staker_address);
    assert_panic_with_error(
        :result, expected_error: Error::CALLER_IS_NOT_ATTESTATION_CONTRACT.describe(),
    );

    // Catch STAKER_NOT_EXISTS.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: attestation_contract,
    );
    let result = staking_safe_dispatcher
        .update_rewards_from_attestation_contract(staker_address: DUMMY_ADDRESS());
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());

    // Catch UNSTAKE_IN_PROGRESS.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: attestation_contract,
    );
    let result = staking_safe_dispatcher.update_rewards_from_attestation_contract(:staker_address);
    assert_panic_with_error(:result, expected_error: Error::UNSTAKE_IN_PROGRESS.describe());
}

#[test]
fn test_undelegate_intent_zero() {
    let d: UndelegateIntentValue = Zero::zero();
    assert!(
        d == UndelegateIntentValue {
            unpool_time: Timestamp { seconds: Zero::zero() },
            amount: Zero::zero(),
            token_address: Zero::zero(),
        },
    );
}

#[test]
fn test_undelegate_intent_is_zero() {
    let d: UndelegateIntentValue = Zero::zero();
    assert!(d.is_zero());
    assert!(!d.is_non_zero());
}

#[test]
fn test_undelegate_intent_is_non_zero() {
    let d = UndelegateIntentValue {
        unpool_time: UNPOOL_TIME,
        amount: NormalizedAmountTrait::from_strk_native_amount(1),
        token_address: Zero::zero(),
    };
    assert!(!d.is_zero());
    assert!(d.is_non_zero());
}

#[test]
fn test_undelegate_intent_is_valid() {
    let d = UndelegateIntentValue {
        unpool_time: Zero::zero(), amount: Zero::zero(), token_address: Zero::zero(),
    };
    assert!(d.is_valid());
    let d = UndelegateIntentValue {
        unpool_time: UNPOOL_TIME,
        amount: NormalizedAmountTrait::from_strk_native_amount(1),
        token_address: Zero::zero(),
    };
    assert!(d.is_valid());
    let d = UndelegateIntentValue {
        unpool_time: Zero::zero(),
        amount: NormalizedAmountTrait::from_strk_native_amount(1),
        token_address: Zero::zero(),
    };
    assert!(!d.is_valid());
    let d = UndelegateIntentValue {
        unpool_time: UNPOOL_TIME, amount: Zero::zero(), token_address: Zero::zero(),
    };
    assert!(!d.is_valid());
}

#[test]
fn test_undelegate_intent_assert_valid() {
    let d = UndelegateIntentValue {
        unpool_time: Zero::zero(), amount: Zero::zero(), token_address: Zero::zero(),
    };
    d.assert_valid();
    let d = UndelegateIntentValue {
        unpool_time: UNPOOL_TIME,
        amount: NormalizedAmountTrait::from_strk_native_amount(1),
        token_address: Zero::zero(),
    };
    d.assert_valid();
}

#[test]
#[should_panic(expected: "Invalid undelegate intent value")]
fn test_undelegate_intent_assert_valid_panic() {
    let d = UndelegateIntentValue {
        unpool_time: Zero::zero(),
        amount: NormalizedAmountTrait::from_strk_native_amount(1),
        token_address: Zero::zero(),
    };
    d.assert_valid();
}

#[test]
fn test_versioned_internal_staker_info_wrap_latest() {
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        unclaimed_rewards_own: Zero::zero(),
        _deprecated_pool_info: Option::None,
        _deprecated_commission_commitment: Option::None,
    };
    let versioned_internal_staker_info = VersionedInternalStakerInfoTrait::wrap_latest(
        internal_staker_info,
    );
    assert!(
        versioned_internal_staker_info == VersionedInternalStakerInfo::V1(internal_staker_info),
    );
}

#[test]
fn test_versioned_internal_staker_info_new_latest() {
    let internal_staker_info = VersionedInternalStakerInfoTrait::new_latest(
        reward_address: Zero::zero(), operational_address: Zero::zero(),
    );
    if let VersionedInternalStakerInfo::V1(_) = internal_staker_info {
        return;
    } else {
        panic!("Expected Version V1");
    }
}

#[test]
fn test_internal_staker_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingMigrationDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let mut expected_internal_staker_info = cfg.staker_info;
    expected_internal_staker_info._deprecated_pool_info = Option::None;
    stake_for_testing_using_dispatcher(:cfg);
    let internal_staker_info = staking_dispatcher.internal_staker_info(:staker_address);
    assert!(internal_staker_info == expected_internal_staker_info);
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_internal_staker_info_staker_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingMigrationDispatcher { contract_address: staking_contract };
    staking_dispatcher.internal_staker_info(staker_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Outdated version of Internal Staker Info")]
fn test_internal_staker_info_outdated_version() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingMigrationDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    stake_for_testing_using_dispatcher(:cfg);
    store_internal_staker_info_v0_to_map(
        :staker_address,
        :staking_contract,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        unstake_time: cfg.staker_info.unstake_time,
        amount_own: cfg.test_info.stake_amount,
        index: cfg.test_info.global_index,
        unclaimed_rewards_own: cfg.staker_info.unclaimed_rewards_own,
    );
    staking_dispatcher.internal_staker_info(:staker_address);
}

// TODO: Add test for staker migration with invalid balance trace that catches
// POOL_BALANCE_NOT_ZERO.
#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_staker_migration_staker_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingMigrationDispatcher { contract_address: staking_contract };
    staking_dispatcher.staker_migration(staker_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Staker Info is already up-to-date")]
fn test_staker_migration_up_to_date_new_staker() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingMigrationDispatcher { contract_address: staking_contract };
    staking_dispatcher.staker_migration(staker_address: cfg.test_info.staker_address);
}

#[test]
fn test_compute_unpool_time() {
    let exit_wait_window = DEFAULT_EXIT_WAIT_WINDOW;
    // Unstake_time is not set.
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        unclaimed_rewards_own: Zero::zero(),
        _deprecated_pool_info: Option::None,
        _deprecated_commission_commitment: Option::None,
    };
    assert!(
        internal_staker_info
            .compute_unpool_time(:exit_wait_window) == Time::now()
            .add(delta: exit_wait_window),
    );

    // Unstake_time is set.
    let unstake_time = Time::now().add(delta: Time::weeks(count: 1));
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::Some(unstake_time),
        unclaimed_rewards_own: Zero::zero(),
        _deprecated_pool_info: Option::None,
        _deprecated_commission_commitment: Option::None,
    };

    // Unstake time > current time.
    assert!(Time::now() == Zero::zero());
    assert!(internal_staker_info.compute_unpool_time(:exit_wait_window) == unstake_time);

    // Unstake time < current time.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: exit_wait_window).into(),
    );
    assert!(internal_staker_info.compute_unpool_time(:exit_wait_window) == Time::now());
}

#[test]
fn test_deprecated_get_pool_info() {
    let staker_pool_info = InternalStakerPoolInfoV1 {
        _deprecated_pool_contract: Zero::zero(), _deprecated_commission: Zero::zero(),
    };
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        unclaimed_rewards_own: Zero::zero(),
        _deprecated_pool_info: Option::Some(staker_pool_info),
        _deprecated_commission_commitment: Option::None,
    };
    assert!(internal_staker_info._deprecated_get_pool_info() == staker_pool_info);
}

#[test]
#[should_panic(expected: "Staker does not have a pool contract")]
fn test_get_pool_info_panic() {
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        unclaimed_rewards_own: Zero::zero(),
        _deprecated_pool_info: Option::None,
        _deprecated_commission_commitment: Option::None,
    };
    internal_staker_info._deprecated_get_pool_info();
}

#[test]
fn test_internal_staker_info_latest_into_staker_info() {
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        unclaimed_rewards_own: Zero::zero(),
        _deprecated_pool_info: Option::None,
        _deprecated_commission_commitment: Option::None,
    };
    let staker_info: StakerInfoV1 = internal_staker_info.into();
    let expected_staker_info = StakerInfoV1 {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    assert!(staker_info == expected_staker_info);
}

#[test]
fn test_staker_info_into_internal_staker_info_v1() {
    let staker_info = StakerInfoV1 {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    let internal_staker_info: InternalStakerInfoV1 = staker_info.to_internal();
    let expected_internal_staker_info = InternalStakerInfoV1 {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        unclaimed_rewards_own: Zero::zero(),
        _deprecated_pool_info: Option::None,
        _deprecated_commission_commitment: Option::None,
    };
    assert!(internal_staker_info == expected_internal_staker_info);
}

#[test]
#[should_panic(expected: "Invalid epoch length, must be greater than 0")]
fn test_epoch_info_new_invalid_length() {
    EpochInfoTrait::new(
        epoch_duration: EPOCH_DURATION,
        epoch_length: Zero::zero(),
        starting_block: get_block_number(),
    );
}

#[test]
#[should_panic(expected: "Invalid epoch duration, must be greater than 0")]
fn test_epoch_info_new_invalid_epoch_duration() {
    EpochInfoTrait::new(
        epoch_duration: Zero::zero(),
        epoch_length: EPOCH_LENGTH,
        starting_block: get_block_number(),
    );
}

#[test]
fn test_epoch_info_current_epoch() {
    let block_number = EPOCH_STARTING_BLOCK;
    let epoch_length = EPOCH_LENGTH;
    let epoch_duration = EPOCH_DURATION;
    start_cheat_block_number_global(:block_number);
    let epoch_info = EpochInfoTrait::new(
        :epoch_duration, :epoch_length, starting_block: get_block_number(),
    );
    assert!(epoch_info.current_epoch() == Zero::zero());
    advance_block_number_global(blocks: epoch_length.into() - 1);
    assert!(epoch_info.current_epoch() == Zero::zero());
    advance_block_number_global(blocks: 1);
    assert!(epoch_info.current_epoch() == 1);
}

#[test]
fn test_epoch_info_update_only_length() {
    let block_number = EPOCH_STARTING_BLOCK;
    let epoch_length = EPOCH_LENGTH;
    let epoch_duration = EPOCH_DURATION;
    start_cheat_block_number_global(:block_number);
    let mut epoch_info = EpochInfoTrait::new(
        :epoch_duration, :epoch_length, starting_block: get_block_number(),
    );
    let first_epoch = 10;
    advance_block_number_global(blocks: first_epoch * epoch_length.into());
    assert!(epoch_info.current_epoch() == first_epoch);
    advance_epoch_global();
    assert!(epoch_info.current_epoch() == first_epoch + 1);

    // Update epoch_length in the first block of the epoch.
    let new_epoch_length = epoch_length + 1;
    epoch_info.update(:epoch_duration, epoch_length: new_epoch_length);
    assert!(epoch_info.current_epoch() == first_epoch + 1);
    // Still the same epoch_length.
    advance_block_number_global(blocks: epoch_length.into() - 1);
    assert!(epoch_info.current_epoch() == first_epoch + 1);
    advance_block_number_global(blocks: 1);
    assert!(epoch_info.current_epoch() == first_epoch + 2);
    // Different epoch_length.
    advance_block_number_global(blocks: epoch_length.into());
    assert!(epoch_info.current_epoch() == first_epoch + 2);
    advance_block_number_global(blocks: 1);
    assert!(epoch_info.current_epoch() == first_epoch + 3);
    advance_epoch_global();

    // Update epoch_length in the last block of the epoch.
    advance_block_number_global(blocks: epoch_length.into());
    epoch_info.update(:epoch_duration, epoch_length: EPOCH_LENGTH - 1);
    assert!(epoch_info.current_epoch() == first_epoch + 4);
    advance_block_number_global(blocks: 1);
    assert!(epoch_info.current_epoch() == first_epoch + 4);
    advance_block_number_global(blocks: epoch_length.into() - 2);
    assert!(epoch_info.current_epoch() == first_epoch + 5);
    advance_block_number_global(blocks: 1);
    assert!(epoch_info.current_epoch() == first_epoch + 5);
}

#[test]
fn test_epoch_info_update_only_epoch_duration() {
    let block_number = EPOCH_STARTING_BLOCK;
    let epoch_length = EPOCH_LENGTH;
    let epoch_duration = EPOCH_DURATION;
    start_cheat_block_number_global(:block_number);
    let mut epoch_info = EpochInfoTrait::new(
        :epoch_duration, :epoch_length, starting_block: get_block_number(),
    );
    let first_epoch = 10;
    advance_block_number_global(blocks: first_epoch * epoch_length.into());
    assert!(epoch_info.current_epoch() == first_epoch);

    let epoch_duration = EPOCH_DURATION / 10;
    let epochs_in_year_before = epoch_info.epochs_in_year();
    let expected_epochs_in_year = epochs_in_year_before * 10;
    epoch_info.update(:epoch_duration, :epoch_length);
    assert!(epochs_in_year_before == epoch_info.epochs_in_year());
    advance_epoch_global();
    assert!(expected_epochs_in_year == epoch_info.epochs_in_year());
}

#[test]
#[should_panic(expected: "Epoch info can not be updated in the first epoch")]
fn test_epoch_info_update_in_first_epoch() {
    let block_number = EPOCH_STARTING_BLOCK;
    let epoch_length = EPOCH_LENGTH;
    let epoch_duration = EPOCH_DURATION;
    start_cheat_block_number_global(:block_number);
    let mut epoch_info = EpochInfoTrait::new(
        :epoch_duration, :epoch_length, starting_block: get_block_number(),
    );
    epoch_info.update(:epoch_duration, :epoch_length);
}

#[test]
#[should_panic(expected: "Epoch info already updated in this epoch")]
fn test_epoch_info_update_already_updated() {
    let block_number = EPOCH_STARTING_BLOCK;
    let epoch_length = EPOCH_LENGTH;
    let epoch_duration = EPOCH_DURATION;
    start_cheat_block_number_global(:block_number);
    let mut epoch_info = EpochInfoTrait::new(
        :epoch_duration, :epoch_length, starting_block: get_block_number(),
    );
    advance_epoch_global();
    epoch_info.update(:epoch_duration, :epoch_length);
    epoch_info.update(:epoch_duration, :epoch_length);
}


#[test]
fn test_epoch_info_len_kept_after_update() {
    let block_number = EPOCH_STARTING_BLOCK;
    let epoch_length = EPOCH_LENGTH;
    let epoch_duration = EPOCH_DURATION;
    start_cheat_block_number_global(:block_number);
    let mut epoch_info = EpochInfoTrait::new(
        :epoch_duration, :epoch_length, starting_block: get_block_number(),
    );
    advance_epoch_global();
    let current_epoch = epoch_info.current_epoch();
    epoch_info.update(:epoch_duration, epoch_length: epoch_length + 1);
    assert!(epoch_info.current_epoch() == current_epoch);
    assert!(epoch_info.epoch_len_in_blocks() == epoch_length);
    advance_epoch_global();
    assert!(epoch_info.current_epoch() == current_epoch + 1);
    assert!(epoch_info.epoch_len_in_blocks() == epoch_length + 1);
}

#[test]
fn test_set_epoch_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let new_epoch_duration = EPOCH_DURATION / 2;
    let new_length = 2 * EPOCH_LENGTH;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.app_governor,
    );
    advance_epoch_global();
    staking_config_dispatcher
        .set_epoch_info(epoch_duration: new_epoch_duration, epoch_length: new_length);
    advance_block_number_global(blocks: EPOCH_LENGTH.into() - 1);
    assert!(staking_dispatcher.get_current_epoch() == 1);
    advance_block_number_global(blocks: 1);
    assert!(staking_dispatcher.get_current_epoch() == 2);
    advance_block_number_global(blocks: EPOCH_LENGTH.into());
    assert!(staking_dispatcher.get_current_epoch() == 2);
    advance_block_number_global(blocks: EPOCH_LENGTH.into() - 1);
    assert!(staking_dispatcher.get_current_epoch() == 2);
    advance_block_number_global(blocks: 1);
    assert!(staking_dispatcher.get_current_epoch() == 3);
    // Validate the single EpochInfoChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_epoch_info");
    assert_epoch_info_changed_event(
        spied_event: events[0], epoch_duration: new_epoch_duration, epoch_length: new_length,
    );
}

#[test]
#[should_panic(expected: "ONLY_APP_GOVERNOR")]
fn test_set_epoch_info_not_app_governor() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let non_app_governor = NON_APP_GOVERNOR();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: non_app_governor);
    staking_config_dispatcher
        .set_epoch_info(epoch_duration: EPOCH_DURATION, epoch_length: EPOCH_LENGTH);
}

#[test]
#[feature("safe_dispatcher")]
fn test_set_epoch_info_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_safe_dispatcher = IStakingConfigSafeDispatcher {
        contract_address: staking_contract,
    };
    let epoch_duration = EPOCH_DURATION;
    let epoch_length = EPOCH_LENGTH;

    // Catch INVALID_EPOCH_LENGTH.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.app_governor,
    );
    let result = staking_safe_dispatcher
        .set_epoch_info(:epoch_duration, epoch_length: Zero::zero());
    assert_panic_with_error(:result, expected_error: Error::INVALID_EPOCH_LENGTH.describe());

    // Catch INVALID_EPOCH_DURATION.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.app_governor,
    );
    let result = staking_safe_dispatcher
        .set_epoch_info(epoch_duration: Zero::zero(), :epoch_length);
    assert_panic_with_error(:result, expected_error: Error::INVALID_EPOCH_DURATION.describe());
}

#[test]
fn test_staking_eic() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let upgrade_governor = cfg.test_info.upgrade_governor;
    let security_agent = cfg.test_info.security_agent;
    // Store the exist prev_class_hash.
    let storage_address = snforge_std::map_entry_address(
        map_selector: selector!("prev_class_hash"), keys: [V1_PREV_CONTRACT_VERSION].span(),
    );
    snforge_std::store(
        target: staking_contract,
        :storage_address,
        serialized_value: [MAINNET_STAKING_CLASS_HASH_V0().into()].span(),
    );
    // Store `MAX_MIGRATION_TRACE_ENTRIES` checkpoints in total stake trace.
    let trace_address = selector!("total_stake_trace");
    let total_stake_0: Amount = cfg.test_info.stake_amount;
    let total_stake_1: Amount = total_stake_0 + cfg.test_info.stake_amount;
    let total_stake_2: Amount = total_stake_1 + cfg.test_info.stake_amount;
    append_to_trace(
        contract_address: staking_contract, :trace_address, key: 0, value: total_stake_0,
    );
    append_to_trace(
        contract_address: staking_contract, :trace_address, key: 1, value: total_stake_1,
    );
    append_to_trace(
        contract_address: staking_contract, :trace_address, key: 2, value: total_stake_2,
    );

    // Upgrade.
    let new_pool_contract_class_hash = declare_pool_contract();
    let eic_data = EICData {
        eic_hash: declare_staking_eic_contract_v1_v2(),
        eic_init_data: [MAINNET_STAKING_CLASS_HASH_V1().into(), new_pool_contract_class_hash.into()]
            .span(),
    };
    let implementation_data = ImplementationData {
        impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    pause_staking_contract(:staking_contract, :security_agent);
    upgrade_implementation(
        contract_address: staking_contract, :implementation_data, :upgrade_governor,
    );
    // Test.
    // Test prev_class_hash.
    let map_selector = selector!("prev_class_hash");
    let storage_address = snforge_std::map_entry_address(
        :map_selector, keys: [STAKING_V2_PREV_CONTRACT_VERSION].span(),
    );
    let prev_class_hash = *snforge_std::load(
        target: staking_contract, :storage_address, size: Store::<ClassHash>::size().into(),
    )
        .at(0);
    assert!(prev_class_hash.try_into().unwrap() == MAINNET_STAKING_CLASS_HASH_V1());
    // Test prev_class_hash from v1.
    let storage_address = snforge_std::map_entry_address(
        :map_selector, keys: [V1_PREV_CONTRACT_VERSION].span(),
    );
    let v1_prev_class_hash = *snforge_std::load(
        target: staking_contract, :storage_address, size: Store::<ClassHash>::size().into(),
    )
        .at(0);
    assert!(v1_prev_class_hash.try_into().unwrap() == MAINNET_STAKING_CLASS_HASH_V0());
    // Test pool contract class hash.
    let pool_contract_class_hash = *snforge_std::load(
        target: staking_contract,
        storage_address: selector!("pool_contract_class_hash"),
        size: Store::<ClassHash>::size().into(),
    )
        .at(0);
    assert!(pool_contract_class_hash.try_into().unwrap() == new_pool_contract_class_hash);
    // Test total stake trace.
    let strk_token_address = cfg.test_info.strk_token.contract_address();
    let trace_address = snforge_std::map_entry_address(
        map_selector: selector!("tokens_total_stake_trace"),
        keys: [strk_token_address.into()].span(),
    );
    let trace_length = load_trace_length(contract_address: staking_contract, :trace_address);
    assert!(trace_length == MAX_MIGRATION_TRACE_ENTRIES);
    let (key_0, value_0) = load_from_trace(
        contract_address: staking_contract, :trace_address, index: 0,
    );
    assert!(key_0 == 0);
    assert!(value_0 == total_stake_0);
    let (key_1, value_1) = load_from_trace(
        contract_address: staking_contract, :trace_address, index: 1,
    );
    assert!(key_1 == 1);
    assert!(value_1 == total_stake_1);
    let (key_2, value_2) = load_from_trace(
        contract_address: staking_contract, :trace_address, index: 2,
    );
    assert!(key_2 == 2);
    assert!(value_2 == total_stake_2);
}

// TODO: Find another way to test specific errors in EIC.
// #[test]
// #[feature("safe_dispatcher")]
// fn test_staking_eic_assertions() {
//     let eic_library_safe_dispatcher = IEICInitializableSafeLibraryDispatcher {
//         class_hash: declare_staking_eic_contract_v1_v2(),
//     };
//     // Catch EXPECTED_DATA_LENGTH_2.
//     let result = eic_library_safe_dispatcher.eic_initialize(eic_init_data: [].span());
//     assert_panic_with_felt_error(:result, expected_error: 'EXPECTED_DATA_LENGTH_2');

//     // Catch Class hash is zero - prev class hash.
//     let result = eic_library_safe_dispatcher
//         .eic_initialize(eic_init_data: [Zero::zero(), declare_pool_contract().into()].span());
//     assert_panic_with_error(:result, expected_error: GenericError::ZERO_CLASS_HASH.describe());

//     // Catch Class hash is zero - pool contract class hash.
//     let result = eic_library_safe_dispatcher
//         .eic_initialize(
//             eic_init_data: [MAINNET_STAKING_CLASS_HASH_V1().into(), Zero::zero()].span(),
//         );
//     assert_panic_with_error(:result, expected_error: GenericError::ZERO_CLASS_HASH.describe());
//     // TODO: Catch empty trace.
// }

#[test]
#[should_panic(expected: "EIC_LIB_CALL_FAILED")]
fn test_staking_eic_without_pause() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let upgrade_governor = cfg.test_info.upgrade_governor;
    // Upgrade.
    let eic_data = EICData {
        eic_hash: declare_staking_eic_contract_v1_v2(),
        eic_init_data: [MAINNET_STAKING_CLASS_HASH_V1().into(), declare_pool_contract().into()]
            .span(),
    };
    let implementation_data = ImplementationData {
        impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    let trace_address = selector!("total_stake_trace");
    let total_stake_0: Amount = cfg.test_info.stake_amount;
    let total_stake_1: Amount = total_stake_0 + cfg.test_info.stake_amount;
    let total_stake_2: Amount = total_stake_1 + cfg.test_info.stake_amount;
    append_to_trace(
        contract_address: staking_contract, :trace_address, key: 0, value: total_stake_0,
    );
    append_to_trace(
        contract_address: staking_contract, :trace_address, key: 1, value: total_stake_1,
    );
    append_to_trace(
        contract_address: staking_contract, :trace_address, key: 2, value: total_stake_2,
    );
    // Cheat block timestamp to enable upgrade eligibility.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    upgrade_implementation(
        contract_address: staking_contract, :implementation_data, :upgrade_governor,
    );
}

#[test]
#[should_panic(expected: "EIC_LIB_CALL_FAILED")]
fn test_staking_eic_with_wrong_number_of_data_elemnts() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let upgrade_governor = cfg.test_info.upgrade_governor;
    let security_agent = cfg.test_info.security_agent;
    // Upgrade.
    let eic_data = EICData {
        eic_hash: declare_staking_eic_contract_v1_v2(), eic_init_data: [].span(),
    };
    let implementation_data = ImplementationData {
        impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    // Cheat block timestamp to enable upgrade eligibility.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    // Pause the staking contract.
    pause_staking_contract(:staking_contract, :security_agent);
    upgrade_implementation(
        contract_address: staking_contract, :implementation_data, :upgrade_governor,
    );
}

#[test]
#[should_panic(expected: "EIC_LIB_CALL_FAILED")]
fn test_staking_eic_total_stake_trace_empty() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let upgrade_governor = cfg.test_info.upgrade_governor;
    let security_agent = cfg.test_info.security_agent;
    // Upgrade.
    let eic_data = EICData {
        eic_hash: declare_staking_eic_contract_v1_v2(),
        eic_init_data: [MAINNET_STAKING_CLASS_HASH_V1().into(), declare_pool_contract().into()]
            .span(),
    };
    let implementation_data = ImplementationData {
        impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    // Pause the staking contract.
    pause_staking_contract(:staking_contract, :security_agent);
    upgrade_implementation(
        contract_address: staking_contract, :implementation_data, :upgrade_governor,
    );
}

#[test]
#[should_panic(expected: "EIC_LIB_CALL_FAILED")]
fn test_staking_eic_prev_class_hash_zero_class_hash() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let upgrade_governor = cfg.test_info.upgrade_governor;
    let security_agent = cfg.test_info.security_agent;
    // Upgrade.
    let eic_data = EICData {
        eic_hash: declare_staking_eic_contract_v1_v2(),
        eic_init_data: [Zero::zero(), declare_pool_contract().into()].span(),
    };
    let implementation_data = ImplementationData {
        impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    // Cheat block timestamp to enable upgrade eligibility.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    // Pause the staking contract.
    pause_staking_contract(:staking_contract, :security_agent);
    upgrade_implementation(
        contract_address: staking_contract, :implementation_data, :upgrade_governor,
    );
}

#[test]
#[should_panic(expected: "EIC_LIB_CALL_FAILED")]
fn test_staking_eic_pool_contract_zero_class_hash() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let upgrade_governor = cfg.test_info.upgrade_governor;
    let security_agent = cfg.test_info.security_agent;
    // Upgrade.
    let eic_data = EICData {
        eic_hash: declare_staking_eic_contract_v1_v2(),
        eic_init_data: [MAINNET_STAKING_CLASS_HASH_V1().into(), Zero::zero()].span(),
    };
    let implementation_data = ImplementationData {
        impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    // Cheat block timestamp to enable upgrade eligibility.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    // Pause the staking contract.
    pause_staking_contract(:staking_contract, :security_agent);
    upgrade_implementation(
        contract_address: staking_contract, :implementation_data, :upgrade_governor,
    );
}

#[test]
fn test_get_current_total_staking_power() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    let btc_token = cfg.test_info.btc_token;
    let btc_token_address = btc_token.contract_address();
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    staking_dispatcher.set_commission(commission: Zero::zero());
    let pool_contract = staking_dispatcher
        .set_open_for_delegation(token_address: btc_token_address);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, token: btc_token);
    let strk_total_stake = staking_dispatcher.staker_info_v1(:staker_address).amount_own;
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let pool_member = cfg.test_info.pool_member_address;
    let btc_total_stake = to_amount_18_decimals(
        amount: pool_dispatcher.pool_member_info_v1(:pool_member).amount,
        token_address: btc_token_address,
    );
    advance_epoch_global();
    assert!(
        staking_dispatcher.get_current_total_staking_power() == (strk_total_stake, btc_total_stake),
    );

    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    staking_token_dispatcher.disable_token(token_address: btc_token_address);
    assert!(
        staking_dispatcher.get_current_total_staking_power() == (strk_total_stake, btc_total_stake),
    );
    advance_epoch_global();
    assert!(
        staking_dispatcher.get_current_total_staking_power() == (strk_total_stake, Zero::zero()),
    );

    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_token_dispatcher.enable_token(token_address: btc_token_address);
    assert!(
        staking_dispatcher.get_current_total_staking_power() == (strk_total_stake, Zero::zero()),
    );
    advance_epoch_global();
    assert!(
        staking_dispatcher.get_current_total_staking_power() == (strk_total_stake, btc_total_stake),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_token_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    stake_for_testing_using_dispatcher(:cfg);
    let staker_address = cfg.test_info.staker_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_token_manager_safe_dispatcher = IStakingTokenManagerSafeDispatcher {
        contract_address: staking_contract,
    };
    // Catch ONLY_SECURITY_ADMIN.
    let result = staking_token_manager_safe_dispatcher
        .add_token(token_address: BTC_TOKEN_ADDRESS());
    assert_panic_with_error(:result, expected_error: "ONLY_TOKEN_ADMIN");

    // Catch ZERO_ADDRESS.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let result = staking_token_manager_safe_dispatcher.add_token(token_address: Zero::zero());
    assert_panic_with_error(:result, expected_error: GenericError::ZERO_ADDRESS.describe());

    // Catch TOKEN_IS_STAKER.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let result = staking_token_manager_safe_dispatcher.add_token(token_address: staker_address);
    assert_panic_with_error(:result, expected_error: Error::TOKEN_IS_STAKER.describe());

    // Catch INVALID_TOKEN_ADDRESS - STRK token.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let result = staking_token_manager_safe_dispatcher
        .add_token(token_address: cfg.test_info.strk_token.contract_address());
    assert_panic_with_error(:result, expected_error: Error::INVALID_TOKEN_ADDRESS.describe());

    // Catch INVALID_TOKEN_ADDRESS - decimals.
    let invalid_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME(),
        decimals: 4,
    );
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let result = staking_token_manager_safe_dispatcher
        .add_token(token_address: invalid_token_address);
    assert_panic_with_error(:result, expected_error: Error::INVALID_TOKEN_ADDRESS.describe());
    let invalid_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME(),
        decimals: 19,
    );
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let result = staking_token_manager_safe_dispatcher
        .add_token(token_address: invalid_token_address);
    assert_panic_with_error(:result, expected_error: Error::INVALID_TOKEN_ADDRESS.describe());

    // Catch TOKEN_ALREADY_EXISTS.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let result = staking_token_manager_safe_dispatcher
        .add_token(token_address: cfg.test_info.btc_token.contract_address());
    assert_panic_with_error(:result, expected_error: Error::TOKEN_ALREADY_EXISTS.describe());
}

#[test]
fn test_get_active_tokens() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let strk_token_address = cfg.test_info.strk_token.contract_address();
    let btc_token_address = cfg.test_info.btc_token.contract_address();

    // Test when both tokens are active.
    advance_epoch_global();
    let expected_active_tokens = [strk_token_address, btc_token_address].span();
    let active_tokens = staking_dispatcher.get_active_tokens();
    assert!(active_tokens == expected_active_tokens);

    // Disable the BTC token.
    let security_agent = cfg.test_info.security_agent;
    let token_manager_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    cheat_caller_address_once(contract_address: staking_contract, caller_address: security_agent);
    token_manager_dispatcher.disable_token(token_address: btc_token_address);

    // Test when only the STRK token is active.
    advance_epoch_global();
    let expected_active_tokens = [strk_token_address].span();
    let active_tokens = staking_dispatcher.get_active_tokens();
    assert!(active_tokens == expected_active_tokens);
}

#[test]
fn test_get_tokens() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    // Assert STRK and BTC tokens.
    let tokens = staking_dispatcher.get_tokens();
    assert!(tokens.len() == 2);
    assert!(*tokens[0] == (cfg.test_info.strk_token.contract_address(), true));
    assert!(*tokens[1] == (cfg.test_info.btc_token.contract_address(), false));
    // Disable the BTC token.
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    staking_token_dispatcher
        .disable_token(token_address: cfg.test_info.btc_token.contract_address());
    let tokens = staking_dispatcher.get_tokens();
    assert!(tokens.len() == 2);
    assert!(*tokens[0] == (cfg.test_info.strk_token.contract_address(), true));
    assert!(*tokens[1] == (cfg.test_info.btc_token.contract_address(), true));
    advance_epoch_global();
    let tokens = staking_dispatcher.get_tokens();
    assert!(tokens.len() == 2);
    assert!(*tokens[0] == (cfg.test_info.strk_token.contract_address(), true));
    assert!(*tokens[1] == (cfg.test_info.btc_token.contract_address(), false));
}

#[test]
fn test_add_token() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    let btc_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME(),
        decimals: constants::TEST_BTC_DECIMALS,
    );
    // The STRK token is active and test_info.btc_token will be active in the next epoch.
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let active_tokens = staking_dispatcher.get_active_tokens();
    assert!(active_tokens.len() == 1);

    // Advance epoch.
    advance_epoch_global();
    let active_tokens = staking_dispatcher.get_active_tokens();
    assert!(active_tokens.len() == 2);
    assert!(*active_tokens[0] == cfg.test_info.strk_token.contract_address());
    assert!(*active_tokens[1] == cfg.test_info.btc_token.contract_address());
    // Add the BTC token.
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_token_dispatcher.add_token(token_address: btc_token_address);
    let active_tokens = staking_dispatcher.get_active_tokens();
    // The STRK token is always active.
    // The BTC token is not active yet, so same as before the add_token call.
    assert!(active_tokens.len() == 2);
    assert!(*active_tokens[0] == cfg.test_info.strk_token.contract_address());
    assert!(*active_tokens[1] == cfg.test_info.btc_token.contract_address());
    // Assert the event was emitted.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "add_token");
    assert_token_added_event(spied_event: events[0], token_address: btc_token_address);
}

#[test]
fn test_enable_token() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    let btc_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME(),
        decimals: constants::TEST_BTC_DECIMALS,
    );
    // Add and enable the BTC token.
    let token_admin = cfg.test_info.token_admin;
    advance_epoch_global();
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(contract_address: staking_contract, caller_address: token_admin);
    staking_token_dispatcher.add_token(token_address: btc_token_address);
    assert!(staking_dispatcher.get_active_tokens().len() == 2);
    advance_epoch_global();
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: token_admin);
    staking_token_dispatcher.enable_token(token_address: btc_token_address);
    assert!(staking_dispatcher.get_active_tokens().len() == 2);
    advance_epoch_global();
    let active_tokens = staking_dispatcher.get_active_tokens();
    assert!(active_tokens.len() == 3);
    assert!(*active_tokens[0] == cfg.test_info.strk_token.contract_address());
    assert!(*active_tokens[1] == cfg.test_info.btc_token.contract_address());
    assert!(*active_tokens[2] == btc_token_address);
    // Assert the event was emitted.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "enable_token");
    assert_token_enabled_event(spied_event: events[0], token_address: btc_token_address);
}

#[test]
fn test_disable_token() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    let btc_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME(),
        decimals: constants::TEST_BTC_DECIMALS,
    );
    // Add and enable the BTC token.
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: cfg.test_info.token_admin,
        span: CheatSpan::TargetCalls(2),
    );
    staking_token_dispatcher.add_token(token_address: btc_token_address);
    advance_epoch_global();
    staking_token_dispatcher.enable_token(token_address: btc_token_address);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    assert!(staking_dispatcher.get_active_tokens().len() == 2);
    advance_epoch_global();
    // Active tokens: STRK, BTC.
    assert!(staking_dispatcher.get_active_tokens().len() == 3);
    // Disable the BTC token.
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    staking_token_dispatcher.disable_token(token_address: btc_token_address);
    assert!(staking_dispatcher.get_active_tokens().len() == 3);
    advance_epoch_global();
    let active_tokens = staking_dispatcher.get_active_tokens();
    // Only the STRK token is active.
    assert!(active_tokens.len() == 2);
    assert!(*active_tokens[0] == cfg.test_info.strk_token.contract_address());
    assert!(*active_tokens[1] == cfg.test_info.btc_token.contract_address());
    // Assert the event was emitted.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "disable_token");
    assert_token_disabled_event(spied_event: events[0], token_address: btc_token_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_enable_token_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_token_manager_safe_dispatcher = IStakingTokenManagerSafeDispatcher {
        contract_address: staking_contract,
    };
    // Catch ONLY_TOKEN_ADMIN.
    let result = staking_token_manager_safe_dispatcher
        .enable_token(token_address: BTC_TOKEN_ADDRESS());
    assert_panic_with_error(:result, expected_error: "ONLY_TOKEN_ADMIN");

    // Catch TOKEN_NOT_EXISTS.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let result = staking_token_manager_safe_dispatcher
        .enable_token(token_address: BTC_TOKEN_ADDRESS());
    assert_panic_with_error(:result, expected_error: Error::TOKEN_NOT_EXISTS.describe());

    // Catch INVALID_EPOCH.
    let btc_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME(),
        decimals: constants::TEST_BTC_DECIMALS,
    );
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: cfg.test_info.token_admin,
        span: CheatSpan::TargetCalls(3),
    );
    let _ = staking_token_manager_safe_dispatcher.add_token(token_address: btc_token_address);
    let _ = staking_token_manager_safe_dispatcher.enable_token(token_address: btc_token_address);
    let result = staking_token_manager_safe_dispatcher
        .enable_token(token_address: btc_token_address);
    assert_panic_with_error(:result, expected_error: Error::INVALID_EPOCH.describe());

    // Catch TOKEN_ALREADY_ENABLED.
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let result = staking_token_manager_safe_dispatcher
        .enable_token(token_address: btc_token_address);
    assert_panic_with_error(:result, expected_error: Error::TOKEN_ALREADY_ENABLED.describe());
}

#[test]
#[feature("safe_dispatcher")]
fn test_disable_token_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_token_manager_safe_dispatcher = IStakingTokenManagerSafeDispatcher {
        contract_address: staking_contract,
    };
    // Catch ONLY_SECURITY_AGENT.
    let result = staking_token_manager_safe_dispatcher
        .disable_token(token_address: BTC_TOKEN_ADDRESS());
    assert_panic_with_error(:result, expected_error: "ONLY_SECURITY_AGENT");

    // Catch TOKEN_NOT_EXISTS.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    let result = staking_token_manager_safe_dispatcher
        .disable_token(token_address: BTC_TOKEN_ADDRESS());
    assert_panic_with_error(:result, expected_error: Error::TOKEN_NOT_EXISTS.describe());

    // Catch TOKEN_ALREADY_DISABLED.
    let btc_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        name: BTC_TOKEN_NAME(),
        decimals: constants::TEST_BTC_DECIMALS,
    );
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let _ = staking_token_manager_safe_dispatcher.add_token(token_address: btc_token_address);
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    let result = staking_token_manager_safe_dispatcher
        .disable_token(token_address: btc_token_address);
    assert_panic_with_error(:result, expected_error: Error::TOKEN_ALREADY_DISABLED.describe());
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let _ = staking_token_manager_safe_dispatcher.enable_token(token_address: btc_token_address);
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    let _ = staking_token_manager_safe_dispatcher.disable_token(token_address: btc_token_address);
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    let result = staking_token_manager_safe_dispatcher
        .disable_token(token_address: btc_token_address);
    assert_panic_with_error(:result, expected_error: Error::TOKEN_ALREADY_DISABLED.describe());
    // Catch INVALID_EPOCH.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    let _ = staking_token_manager_safe_dispatcher.enable_token(token_address: btc_token_address);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    let result = staking_token_manager_safe_dispatcher
        .disable_token(token_address: btc_token_address);
    assert_panic_with_error(:result, expected_error: Error::INVALID_EPOCH.describe());
}

#[test]
fn test_get_total_stake_for_token() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let token_address = cfg.test_info.strk_token.contract_address();
    let btc_token = cfg.test_info.btc_token;
    let btc_token_address = btc_token.contract_address();
    // Test when zero stake.
    let total_strk_stake = staking_dispatcher.get_total_stake_for_token(:token_address);
    advance_epoch_global();
    let total_btc_stake = staking_dispatcher
        .get_total_stake_for_token(token_address: btc_token_address);
    assert!(total_strk_stake.is_zero());
    assert!(total_btc_stake.is_zero());
    // Test when non-zero stake.
    stake_for_testing_using_dispatcher(:cfg);
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: cfg.test_info.staker_address,
        span: CheatSpan::TargetCalls(2),
    );
    staking_dispatcher.set_commission(commission: Zero::zero());
    let btc_pool_contract = staking_dispatcher
        .set_open_for_delegation(token_address: btc_token_address);
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: btc_pool_contract, :cfg, token: btc_token,
    );
    let total_strk_stake = staking_dispatcher.get_total_stake_for_token(:token_address);
    let total_btc_stake = staking_dispatcher
        .get_total_stake_for_token(token_address: btc_token_address);
    assert!(total_strk_stake == cfg.test_info.stake_amount);
    assert!(total_btc_stake == cfg.pool_member_info._deprecated_amount);
}

#[test]
#[should_panic(expected: "Invalid token address")]
fn test_get_total_stake_for_token_not_exists() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher.get_total_stake_for_token(token_address: DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Token is not active")]
fn test_get_total_stake_for_token_not_active() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let btc_token_address = cfg.test_info.btc_token.contract_address();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    let staking_token_dispatcher = IStakingTokenManagerDispatcher {
        contract_address: staking_contract,
    };
    advance_epoch_global();
    staking_token_dispatcher.disable_token(token_address: btc_token_address);
    advance_epoch_global();
    staking_dispatcher.get_total_stake_for_token(token_address: btc_token_address);
}
