use Staking::{COMMISSION_DENOMINATOR, InternalStakingFunctionsTrait};
use constants::{
    CALLER_ADDRESS, DUMMY_ADDRESS, DUMMY_IDENTIFIER, EPOCH_LENGTH, EPOCH_STARTING_BLOCK,
    NON_STAKER_ADDRESS, NON_TOKEN_ADMIN, OTHER_OPERATIONAL_ADDRESS, OTHER_REWARD_ADDRESS,
    OTHER_REWARD_SUPPLIER_CONTRACT_ADDRESS, OTHER_STAKER_ADDRESS, POOL_CONTRACT_ADDRESS,
    POOL_MEMBER_STAKE_AMOUNT, POOL_MEMBER_UNCLAIMED_REWARDS, STAKER_ADDRESS,
    STAKER_UNCLAIMED_REWARDS,
};
use contracts_commons::components::replaceability::interface::{EICData, ImplementationData};
use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use contracts_commons::constants::DAY;
use contracts_commons::errors::Describable;
use contracts_commons::test_utils::{
    advance_block_number_global, assert_panic_with_error, cheat_caller_address_once,
};
use contracts_commons::types::time::time::{Time, TimeDelta, Timestamp};
use core::num::traits::Zero;
use core::option::OptionTrait;
use event_test_utils::{
    assert_change_delegation_pool_intent_event, assert_change_operational_address_event,
    assert_commission_changed_event, assert_declare_operational_address_event,
    assert_delete_staker_event, assert_exit_wait_window_changed_event,
    assert_global_index_updated_event, assert_minimum_stake_changed_event,
    assert_new_delegation_pool_event, assert_new_staker_event, assert_number_of_events,
    assert_remove_from_delegation_pool_action_event,
    assert_remove_from_delegation_pool_intent_event, assert_reward_supplier_changed_event,
    assert_rewards_supplied_to_delegation_pool_event, assert_stake_balance_changed_event,
    assert_staker_exit_intent_event, assert_staker_reward_address_change_event,
    assert_staker_reward_claimed_event,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::{
    CheatSpan, cheat_account_contract_address, cheat_caller_address,
    start_cheat_block_number_global, start_cheat_block_timestamp_global,
};
use staking::constants::{BASE_VALUE, DEFAULT_EXIT_WAIT_WINDOW, MAX_EXIT_WAIT_WINDOW};
use staking::errors::GenericError;
use staking::flow_test::utils::MainnetClassHashes::MAINNET_STAKING_CLASS_HASH_V0;
use staking::flow_test::utils::{declare_staking_contract, upgrade_implementation};
use staking::pool::errors::Error as PoolError;
use staking::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait, PoolContractInfo};
use staking::pool::objects::SwitchPoolData;
use staking::reward_supplier::interface::IRewardSupplierDispatcher;
use staking::staking::errors::Error;
use staking::staking::interface::{
    IStakingConfigDispatcher, IStakingConfigDispatcherTrait, IStakingDispatcher,
    IStakingDispatcherTrait, IStakingMigrationDispatcher, IStakingMigrationDispatcherTrait,
    IStakingPoolDispatcher, IStakingPoolDispatcherTrait, IStakingPoolSafeDispatcher,
    IStakingPoolSafeDispatcherTrait, IStakingSafeDispatcher, IStakingSafeDispatcherTrait,
    StakerInfo, StakerInfoTrait, StakerPoolInfo, StakingContractInfo,
};
use staking::staking::objects::{
    EpochInfo, EpochInfoTrait, InternalStakerInfoLatestTrait, InternalStakerInfoTestTrait,
    InternalStakerInfoV1, UndelegateIntentKey, UndelegateIntentValue, UndelegateIntentValueTrait,
    UndelegateIntentValueZero, VersionedInternalStakerInfo, VersionedInternalStakerInfoTestTrait,
    VersionedInternalStakerInfoTrait, VersionedStorageContractTest,
};
use staking::staking::staking::Staking;
use staking::types::{Amount, Index, InternalStakerInfoLatest};
use staking::utils::{
    compute_commission_amount_rounded_down, compute_rewards_rounded_down,
    compute_rewards_rounded_up,
};
use staking::{event_test_utils, test_utils};
use starknet::class_hash::ClassHash;
use starknet::{ContractAddress, Store, get_block_number};
use test_utils::{
    StakingInitConfig, approve, cheat_reward_for_reward_supplier, constants,
    declare_staking_eic_contract, deploy_mock_erc20_contract, deploy_reward_supplier_contract,
    deploy_staking_contract, enter_delegation_pool_for_testing_using_dispatcher, fund,
    general_contract_system_deployment, initialize_staking_state_from_cfg, load_from_simple_map,
    load_one_felt, load_staker_info_from_map, stake_for_testing_using_dispatcher,
    stake_from_zero_address, stake_with_pool_enabled, store_to_simple_map,
};

#[test]
fn test_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    assert_eq!(state.min_stake.read(), cfg.staking_contract_info.min_stake);
    assert_eq!(
        state.token_dispatcher.read().contract_address, cfg.staking_contract_info.token_address,
    );
    let contract_global_index = state.global_index.read();
    assert_eq!(Zero::zero(), contract_global_index);
    let staker_address = state
        .operational_address_to_staker_address
        .read(cfg.staker_info.operational_address);
    assert_eq!(staker_address, Zero::zero());
    let staker_info = state.staker_info.read(staker_address);
    assert!(staker_info.is_none());
    assert_eq!(
        state.pool_contract_class_hash.read(), cfg.staking_contract_info.pool_contract_class_hash,
    );
    assert_eq!(
        state.reward_supplier_dispatcher.read().contract_address,
        cfg.staking_contract_info.reward_supplier,
    );
    assert_eq!(state.pool_contract_admin.read(), cfg.test_info.pool_contract_admin);
    assert_eq!(
        state.prev_class_hash.read(0), cfg.staking_contract_info.prev_staking_contract_class_hash,
    );
}

#[test]
fn test_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let mut spy = snforge_std::spy_events();
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);

    let staker_address = cfg.test_info.staker_address;
    // Check that the staker info was updated correctly.
    let mut expected_staker_info = cfg.staker_info;
    expected_staker_info.pool_info = Option::None;
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert_eq!(expected_staker_info.into(), staking_dispatcher.staker_info(:staker_address));

    let staker_address_from_operational_address = load_from_simple_map(
        map_selector: selector!("operational_address_to_staker_address"),
        key: cfg.staker_info.operational_address,
        contract: staking_contract,
    );
    // Check that the operational address to staker address mapping was updated correctly.
    assert_eq!(staker_address_from_operational_address, staker_address);

    // Check that the staker's tokens were transferred to the Staking contract.
    assert_eq!(
        token_dispatcher.balance_of(staker_address),
        (cfg.test_info.staker_initial_balance - cfg.staker_info.amount_own).into(),
    );
    assert_eq!(token_dispatcher.balance_of(staking_contract), cfg.staker_info.amount_own.into());
    assert_eq!(staking_dispatcher.get_total_stake(), cfg.staker_info.amount_own);
    // Validate StakeBalanceChanged and NewStaker event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "stake");
    assert_new_staker_event(
        spied_event: events[0],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        self_stake: cfg.staker_info.amount_own,
    );
    assert_stake_balance_changed_event(
        spied_event: events[1],
        :staker_address,
        old_self_stake: Zero::zero(),
        old_delegated_stake: Zero::zero(),
        new_self_stake: cfg.staker_info.amount_own,
        new_delegated_stake: Zero::zero(),
    );
}

#[test]
fn test_update_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg
        .staker_info
        .pool_info =
            Option::Some(
                StakerPoolInfo {
                    pool_contract: POOL_CONTRACT_ADDRESS(),
                    amount: POOL_MEMBER_STAKE_AMOUNT,
                    ..cfg.staker_info.get_pool_info(),
                },
            );
    cfg.staker_info.index = 0;

    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    let mut staker_info = cfg.staker_info;
    let interest = state.global_index.read() - staker_info.index;
    state.update_rewards(ref :staker_info);
    let staker_rewards = compute_rewards_rounded_down(amount: staker_info.amount_own, :interest);
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: staker_info.get_pool_info().amount, :interest,
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info().commission,
    );
    let unclaimed_rewards_own: Amount = staker_rewards + commission_amount;
    let unclaimed_rewards: Amount = pool_rewards_including_commission - commission_amount;
    let mut expected_staker_info = staker_info.clone();
    expected_staker_info.unclaimed_rewards_own = unclaimed_rewards_own;
    expected_staker_info
        .pool_info =
            Option::Some(StakerPoolInfo { unclaimed_rewards, ..staker_info.get_pool_info() });
    assert_eq!(staker_info, expected_staker_info);
}


#[test]
fn test_send_rewards_to_delegation_pool() {
    // Initialize staking state.
    let mut cfg: StakingInitConfig = Default::default();
    let pool_contract = POOL_CONTRACT_ADDRESS();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    cfg.test_info.staking_contract = snforge_std::test_address();
    let token_address = cfg.staking_contract_info.token_address;
    let token_dispatcher = IERC20Dispatcher {
        contract_address: cfg.staking_contract_info.token_address,
    };
    // Deploy reward supplier contract.
    let reward_supplier = deploy_reward_supplier_contract(:cfg);
    cfg.staking_contract_info.reward_supplier = reward_supplier;
    state
        .reward_supplier_dispatcher
        .write(IRewardSupplierDispatcher { contract_address: reward_supplier });
    // Setup staker_info and expected results before sending rewards.
    let unclaimed_rewards = POOL_MEMBER_UNCLAIMED_REWARDS;
    cfg
        .staker_info
        .pool_info =
            Option::Some(
                StakerPoolInfo {
                    pool_contract, unclaimed_rewards, ..cfg.staker_info.get_pool_info(),
                },
            );
    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards, :token_address,
    );
    let pool_balance_before_rewards = token_dispatcher.balance_of(account: pool_contract);
    let mut expected_staker_info = cfg.staker_info.clone();
    expected_staker_info
        .pool_info =
            Option::Some(
                StakerPoolInfo {
                    unclaimed_rewards: Zero::zero(), ..cfg.staker_info.get_pool_info(),
                },
            );
    // Send rewards to pool contract.
    state
        .send_rewards_to_delegation_pool(
            staker_address: cfg.test_info.staker_address,
            ref staker_info: cfg.staker_info,
            :token_dispatcher,
        );
    // Check that unclaimed_rewards_own is set to zero and that the staker received the rewards.
    assert_eq!(expected_staker_info, cfg.staker_info);
    let pool_balance_after_rewards = token_dispatcher.balance_of(account: pool_contract);
    assert_eq!(pool_balance_after_rewards, pool_balance_before_rewards + unclaimed_rewards.into());
}


#[test]
fn test_send_rewards_to_staker() {
    // Initialize staking state.
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    cfg.test_info.staking_contract = snforge_std::test_address();
    let token_address = cfg.staking_contract_info.token_address;
    let token_dispatcher = IERC20Dispatcher {
        contract_address: cfg.staking_contract_info.token_address,
    };
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
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards_own, :token_address,
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
    assert_eq!(expected_staker_info, cfg.staker_info);
    let staker_balance_after_rewards = token_dispatcher
        .balance_of(account: cfg.staker_info.reward_address);
    assert_eq!(
        staker_balance_after_rewards, staker_balance_before_rewards + unclaimed_rewards_own.into(),
    );
}


#[test]
fn test_update_rewards_unstake_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    let mut staker_info_expected = cfg.staker_info.clone();
    staker_info_expected.unstake_time = Option::Some(Timestamp { seconds: 1 });
    let mut staker_info = staker_info_expected;
    state.update_rewards(ref :staker_info);
    assert_eq!(staker_info, staker_info_expected);
}

#[test]
#[should_panic(expected: "Staker already exists, use increase_stake instead")]
fn test_stake_from_same_staker_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);

    // Second stake from cfg.test_info.staker_address.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.staker_info.amount_own,
            pool_enabled: cfg.test_info.pool_enabled,
            commission: cfg.staker_info.get_pool_info().commission,
        );
}

#[test]
#[should_panic(expected: "Operational address already exists")]
fn test_stake_with_same_operational_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);

    let caller_address = OTHER_STAKER_ADDRESS();
    assert!(cfg.test_info.staker_address != caller_address);
    // Change staker address.
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    // Second stake with the same operational address.
    staking_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.staker_info.amount_own,
            pool_enabled: cfg.test_info.pool_enabled,
            commission: cfg.staker_info.get_pool_info().commission,
        );
}

#[test]
#[should_panic(expected: "Amount is less than min stake - try again with enough funds")]
fn test_stake_with_less_than_min_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.staker_info.amount_own = cfg.staking_contract_info.min_stake - 1;
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
}

#[test]
#[should_panic(expected: "Commission is out of range, expected to be 0-10000")]
fn test_stake_with_commission_out_of_range() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let mut pool_info = cfg.staker_info.get_pool_info();
    pool_info.commission = COMMISSION_DENOMINATOR + 1;
    cfg.staker_info.pool_info = Option::Some(pool_info);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
}

#[test]
fn test_claim_delegation_pool_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    // Stake with pool enabled.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    // Update index in staking contract.
    let updated_index = cfg.staker_info.index + BASE_VALUE;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span(),
    );
    // Funds reward supplier and set his unclaimed rewards.
    let interest = updated_index - cfg.staker_info.index;
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: cfg.staker_info.get_pool_info().amount, :interest,
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info().commission,
    );
    let unclaimed_rewards_pool = pool_rewards_including_commission - commission_amount;

    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards_pool, :token_address,
    );

    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    staking_pool_dispatcher
        .claim_delegation_pool_rewards(staker_address: cfg.test_info.staker_address);
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert_eq!(token_dispatcher.balance_of(pool_contract), unclaimed_rewards_pool.into());

    // Validate the single RewardsSuppliedToDelegationPool event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "claim_delegation_pool_rewards",
    );
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[0],
        staker_address: cfg.test_info.staker_address,
        pool_address: pool_contract,
        amount: unclaimed_rewards_pool,
    );
}

#[test]
fn test_contract_parameters() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);

    let expected_staking_contract_info = StakingContractInfo {
        min_stake: cfg.staking_contract_info.min_stake,
        token_address: cfg.staking_contract_info.token_address,
        global_index: cfg.staking_contract_info.global_index,
        pool_contract_class_hash: cfg.staking_contract_info.pool_contract_class_hash,
        reward_supplier: cfg.staking_contract_info.reward_supplier,
        exit_wait_window: cfg.staking_contract_info.exit_wait_window,
    };
    assert_eq!(staking_dispatcher.contract_parameters(), expected_staking_contract_info);
}

#[test]
fn test_increase_stake_from_staker_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    // Set the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let staker_info_before = staking_dispatcher.staker_info(:staker_address);
    let increase_amount = cfg.staker_info.amount_own;
    let expected_staker_info = StakerInfo {
        amount_own: staker_info_before.amount_own + increase_amount, ..staker_info_before,
    };
    let mut spy = snforge_std::spy_events();
    // Increase stake from the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.increase_stake(:staker_address, amount: increase_amount);

    let updated_staker_info = staking_dispatcher.staker_info(:staker_address);
    assert_eq!(expected_staker_info, updated_staker_info);
    assert_eq!(staking_dispatcher.get_total_stake(), expected_staker_info.amount_own);
    // Validate the single StakeBalanceChanged event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "increase_stake");
    let mut new_delegated_stake = Zero::zero();
    if let Option::Some(pool_info) = expected_staker_info.pool_info {
        new_delegated_stake = pool_info.amount;
    }
    assert_stake_balance_changed_event(
        spied_event: events[0],
        :staker_address,
        old_self_stake: staker_info_before.amount_own,
        old_delegated_stake: 0,
        new_self_stake: updated_staker_info.amount_own,
        :new_delegated_stake,
    );
}

#[test]
#[should_panic(expected: "Staker does not have a pool contract")]
fn test_claim_delegation_pool_rewards_pool_address_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.test_info.pool_enabled = false;
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_pool_dispatcher.claim_delegation_pool_rewards(:staker_address);
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_claim_delegation_pool_rewards_staker_does_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    staking_pool_dispatcher.claim_delegation_pool_rewards(staker_address: NON_STAKER_ADDRESS());
}

#[test]
#[should_panic(expected: "Caller is not pool contract")]
fn test_claim_delegation_pool_rewards_unauthorized_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    // Update staker info for the test.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_pool_dispatcher.claim_delegation_pool_rewards(:staker_address);
}

#[test]
fn test_increase_stake_from_reward_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);

    // Transfer amount from initial_owner to reward_address.
    fund(
        sender: cfg.test_info.owner_address,
        recipient: cfg.staker_info.reward_address,
        amount: cfg.test_info.staker_initial_balance,
        :token_address,
    );
    // Approve the Staking contract to spend the reward's tokens.
    approve(
        owner: cfg.staker_info.reward_address,
        spender: staking_contract,
        amount: cfg.test_info.staker_initial_balance,
        :token_address,
    );
    let staker_address = cfg.test_info.staker_address;
    let staker_info_before = staking_dispatcher.staker_info(:staker_address);
    let increase_amount = cfg.staker_info.amount_own;
    let mut expected_staker_info = staker_info_before;
    expected_staker_info.amount_own += increase_amount;
    let caller_address = cfg.staker_info.reward_address;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher.increase_stake(:staker_address, amount: increase_amount);
    let updated_staker_info = staking_dispatcher.staker_info(:staker_address);
    assert_eq!(expected_staker_info, updated_staker_info);
    assert_eq!(staking_dispatcher.get_total_stake(), expected_staker_info.amount_own);
    // Validate the single StakeBalanceChanged event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "increase_stake");
    assert_stake_balance_changed_event(
        spied_event: events[0],
        :staker_address,
        old_self_stake: staker_info_before.amount_own,
        old_delegated_stake: Zero::zero(),
        new_self_stake: expected_staker_info.amount_own,
        new_delegated_stake: Zero::zero(),
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_increase_stake_staker_address_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher
        .increase_stake(staker_address: NON_STAKER_ADDRESS(), amount: cfg.staker_info.amount_own);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_increase_stake_unstake_in_progress() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.increase_stake(:staker_address, amount: cfg.staker_info.amount_own);
}

#[test]
#[should_panic(expected: "Amount is zero")]
fn test_increase_stake_amount_is_zero() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .increase_stake(
            staker_address: cfg.test_info.staker_address, amount: cfg.staker_info.amount_own,
        );
}

#[test]
fn test_change_reward_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let staker_info_before_change = staking_dispatcher.staker_info(:staker_address);
    let other_reward_address = OTHER_REWARD_ADDRESS();

    // Set the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let mut spy = snforge_std::spy_events();
    staking_dispatcher.change_reward_address(reward_address: other_reward_address);
    let staker_info_after_change = staking_dispatcher.staker_info(:staker_address);
    let staker_info_expected = StakerInfo {
        reward_address: other_reward_address, ..staker_info_before_change,
    };
    assert_eq!(staker_info_after_change, staker_info_expected);
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier = cfg.staking_contract_info.reward_supplier;

    // Stake.
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    // Update index in staking contract.
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![(cfg.staker_info.index + BASE_VALUE).into()].span(),
    );
    // Funds reward supplier and set his unclaimed rewards.
    let expected_reward = cfg.staker_info.amount_own;
    cheat_reward_for_reward_supplier(:cfg, :reward_supplier, :expected_reward, :token_address);
    // Claim rewards and validate the results.
    let mut spy = snforge_std::spy_events();
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let reward = staking_dispatcher.claim_rewards(:staker_address);
    assert_eq!(reward, expected_reward);

    let new_staker_info = staking_dispatcher.staker_info(:staker_address);
    assert_eq!(new_staker_info.unclaimed_rewards_own, 0);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = token_dispatcher.balance_of(cfg.staker_info.reward_address);
    assert_eq!(balance, reward.into());
    // Validate the single StakerRewardClaimed event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "claim_rewards");
    assert_staker_reward_claimed_event(
        spied_event: events[0],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        amount: reward,
    );
}

#[test]
#[should_panic(expected: "Claim rewards must be called from staker address or reward address")]
fn test_claim_rewards_panic_unauthorized() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher.claim_rewards(staker_address: DUMMY_ADDRESS());
}

#[test]
fn test_unstake_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let mut spy = snforge_std::spy_events();
    let unstake_time = staking_dispatcher.unstake_intent();
    let staker_info = staking_dispatcher.staker_info(:staker_address);
    let expected_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters().exit_wait_window);
    assert_eq!(staker_info.unstake_time.unwrap(), unstake_time);
    assert_eq!(unstake_time, expected_time);
    assert_eq!(staking_dispatcher.get_total_stake(), Zero::zero());
    // Validate StakerExitIntent and StakeBalanceChanged events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "unstake_intent");
    assert_staker_exit_intent_event(
        spied_event: events[0],
        :staker_address,
        exit_timestamp: expected_time,
        amount: cfg.staker_info.amount_own,
    );
    assert_stake_balance_changed_event(
        spied_event: events[1],
        :staker_address,
        old_self_stake: cfg.staker_info.amount_own,
        old_delegated_stake: 0,
        new_self_stake: 0,
        new_delegated_stake: 0,
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_unstake_intent_staker_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;

    // Stake.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);

    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let unstake_time = staking_dispatcher.unstake_intent();
    // Advance time to enable unstake_action.
    start_cheat_block_timestamp_global(
        block_timestamp: unstake_time.add(delta: Time::seconds(count: 1)).into(),
    );
    let unclaimed_rewards_own = staking_dispatcher
        .staker_info(:staker_address)
        .unclaimed_rewards_own;
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    let mut spy = snforge_std::spy_events();
    let staker_amount = staking_dispatcher.unstake_action(:staker_address);
    assert_eq!(staker_amount, cfg.staker_info.amount_own);
    let actual_staker_info: VersionedInternalStakerInfo = load_staker_info_from_map(
        staker_address: staker_address, contract: staking_contract,
    );
    assert!(actual_staker_info.is_none());
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    // GlobalIndexUpdated, StakerRewardClaimed, RewardsSuppliedToDelegationPool and DeleteStaker
    // events.
    assert_number_of_events(actual: events.len(), expected: 4, message: "unstake_action");
    // Validate StakerRewardClaimed event.
    assert_staker_reward_claimed_event(
        spied_event: events[1],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        amount: unclaimed_rewards_own,
    );
    // Validate RewardsSuppliedToDelegationPool event.
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[2],
        staker_address: cfg.test_info.staker_address,
        pool_address: pool_contract,
        amount: Zero::zero(),
    );
    // Validate DeleteStaker event.
    assert_delete_staker_event(
        spied_event: events[3],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        pool_contract: Option::Some(pool_contract),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_unstake_action_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_safe_dispatcher = IStakingSafeDispatcher { contract_address: staking_contract };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;

    // Catch STAKER_NOT_EXISTS.
    let result = staking_safe_dispatcher.unstake_action(:staker_address);
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);

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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    assert_eq!(staking_dispatcher.get_total_stake(), Zero::zero());
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    assert_eq!(staking_dispatcher.get_total_stake(), cfg.staker_info.amount_own);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    // Set the same staker address.
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let amount = cfg.staker_info.amount_own;
    staking_dispatcher.increase_stake(:staker_address, :amount);
    assert_eq!(
        staking_dispatcher.get_total_stake(),
        staking_dispatcher.staker_info(:staker_address).amount_own,
    );
}

#[test]
fn test_stake_pool_enabled() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let mut spy = snforge_std::spy_events();
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    if let Option::Some(mut pool_info) = cfg.staker_info.pool_info {
        pool_info
            .pool_contract = staking_dispatcher
            .staker_info(:staker_address)
            .pool_info
            .unwrap()
            .pool_contract;
        cfg.staker_info.pool_info = Option::Some(pool_info);
    };
    let expected_staker_info = cfg.staker_info.into();
    // Check that the staker info was updated correctly.
    assert_eq!(expected_staker_info, staking_dispatcher.staker_info(:staker_address));
    // Validate events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    // There are three events: NewDelegationPool, StakeBalanceChange, NewStaker.
    assert_number_of_events(actual: events.len(), expected: 3, message: "stake_pool_enabled");
    let pool_info = cfg.staker_info.get_pool_info();
    assert_new_delegation_pool_event(
        spied_event: events[0],
        :staker_address,
        pool_contract: pool_info.pool_contract,
        commission: pool_info.commission,
    );
    assert_new_staker_event(
        spied_event: events[1],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        self_stake: cfg.staker_info.amount_own,
    );
    assert_stake_balance_changed_event(
        spied_event: events[2],
        :staker_address,
        old_self_stake: Zero::zero(),
        old_delegated_stake: Zero::zero(),
        new_self_stake: cfg.staker_info.amount_own,
        new_delegated_stake: Zero::zero(),
    );
}

#[test]
fn test_add_stake_from_pool() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };

    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_amount = cfg.test_info.staker_initial_balance;
    // Fund pool contract.
    fund(
        sender: cfg.test_info.owner_address,
        recipient: pool_contract,
        amount: pool_amount,
        :token_address,
    );
    // Approve the Staking contract to spend the pool's tokens.
    approve(owner: pool_contract, spender: staking_contract, amount: pool_amount, :token_address);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let pool_balance_before = token_dispatcher.balance_of(pool_contract);
    let total_stake_before = staking_dispatcher.get_total_stake();
    let staker_info_before = staking_dispatcher.staker_info(:staker_address);
    let mut spy = snforge_std::spy_events();
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    let returned_index = staking_pool_dispatcher
        .add_stake_from_pool(:staker_address, amount: pool_amount);

    // Validate returned index.
    let global_index = staking_dispatcher.contract_parameters().global_index;
    assert_eq!(returned_index, global_index);

    // Validate total stake.
    assert_eq!(staking_dispatcher.get_total_stake(), total_stake_before + pool_amount);

    // Validate pool balance.
    let pool_balance_after = token_dispatcher.balance_of(pool_contract);
    assert_eq!(pool_balance_after, pool_balance_before - pool_amount.into());

    // Validate staker info.
    let interest = global_index - cfg.staker_info.index;
    let staker_rewards = compute_rewards_rounded_down(
        amount: cfg.staker_info.amount_own, :interest,
    );
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: Zero::zero(), :interest,
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info().commission,
    );
    let mut staker_unclaimed_rewards = staker_rewards + commission_amount;
    let mut pool_unclaimed_rewards = pool_rewards_including_commission - commission_amount;
    let expected_staker_info = VersionedInternalStakerInfoTrait::new_latest(
        reward_address: staker_info_before.reward_address,
        operational_address: staker_info_before.operational_address,
        unstake_time: staker_info_before.unstake_time,
        amount_own: staker_info_before.amount_own,
        index: staking_dispatcher.contract_parameters().global_index,
        unclaimed_rewards_own: staker_unclaimed_rewards,
        pool_info: Option::Some(
            StakerPoolInfo {
                pool_contract: pool_contract,
                amount: pool_amount,
                unclaimed_rewards: pool_unclaimed_rewards,
                commission: staker_info_before.get_pool_info().commission,
            },
        ),
    );
    let loaded_staker_info_after = load_staker_info_from_map(
        :staker_address, contract: staking_contract,
    );
    assert_eq!(loaded_staker_info_after, expected_staker_info);

    // Validate `GlobalIndexUpdated` and `StakeBalanceChanged` events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "add_stake_from_pool");
    assert_global_index_updated_event(
        spied_event: events[0],
        old_index: cfg.staking_contract_info.global_index,
        new_index: global_index,
        global_index_last_update_timestamp: Zero::zero(),
        global_index_current_update_timestamp: Time::now(),
    );
    assert_stake_balance_changed_event(
        spied_event: events[1],
        staker_address: cfg.test_info.staker_address,
        old_self_stake: cfg.staker_info.amount_own,
        old_delegated_stake: Zero::zero(),
        new_self_stake: cfg.staker_info.amount_own,
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
    let amount = cfg.pool_member_info.amount;

    // Should catch CALLER_IS_ZERO_ADDRESS.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: Zero::zero());
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_IS_ZERO_ADDRESS.describe());

    // Should catch STAKER_NOT_EXISTS.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());

    // Should catch UNSTAKE_IN_PROGRESS.
    let token_address = cfg.staking_contract_info.token_address;
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let unstake_time = staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::UNSTAKE_IN_PROGRESS.describe());

    // Should catch MISSING_POOL_CONTRACT.
    start_cheat_block_timestamp_global(
        block_timestamp: unstake_time.add(delta: Time::seconds(count: 1)).into(),
    );
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_action(:staker_address);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::MISSING_POOL_CONTRACT.describe());

    // Should catch CALLER_IS_NOT_POOL_CONTRACT.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let commission = cfg.staker_info.get_pool_info().commission;
    staking_dispatcher.set_open_for_delegation(:commission);
    let result = staking_pool_safe_dispatcher.add_stake_from_pool(:staker_address, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_IS_NOT_POOL_CONTRACT.describe());
}

#[test]
fn test_remove_from_delegation_pool_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let initial_delegated_stake = staking_dispatcher
        .staker_info(cfg.test_info.staker_address)
        .get_pool_info()
        .amount;
    let old_total_stake = staking_dispatcher.get_total_stake();
    let mut spy = snforge_std::spy_events();
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    let mut intent_amount = cfg.pool_member_info.amount / 2;

    // Increase index.
    let mut global_index = cfg.staker_info.index + BASE_VALUE;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![global_index.into()].span(),
    );

    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: intent_amount,
        );

    // Validate that the staker info is updated.
    let interest = global_index - cfg.staker_info.index;
    let staker_rewards = compute_rewards_rounded_down(
        amount: cfg.staker_info.amount_own, :interest,
    );
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: initial_delegated_stake, :interest,
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info().commission,
    );
    let mut staker_unclaimed_rewards = staker_rewards + commission_amount;
    let mut pool_unclaimed_rewards = pool_rewards_including_commission - commission_amount;
    let mut cur_delegated_stake = initial_delegated_stake - intent_amount;
    let mut expected_staker_info = cfg.staker_info.clone();
    expected_staker_info.unclaimed_rewards_own = staker_unclaimed_rewards;
    expected_staker_info.index = global_index;
    expected_staker_info
        .pool_info =
            Option::Some(
                StakerPoolInfo {
                    pool_contract,
                    amount: cur_delegated_stake,
                    unclaimed_rewards: pool_unclaimed_rewards,
                    ..cfg.staker_info.get_pool_info(),
                },
            );
    assert_eq!(
        staking_dispatcher.staker_info(cfg.test_info.staker_address), expected_staker_info.into(),
    );

    // Validate that the total stake is updated.
    let expected_total_stake = old_total_stake - intent_amount;
    assert_eq!(staking_dispatcher.get_total_stake(), expected_total_stake);

    // Validate that the data written in the exit intents map is updated.
    let identifier: felt252 = cfg.test_info.pool_member_address.into();
    let undelegate_intent_key = UndelegateIntentKey { pool_contract, identifier };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    let expected_unpool_time = Time::now()
        .add(delta: staking_dispatcher.contract_parameters().exit_wait_window);
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_unpool_time, amount: intent_amount,
    };
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);

    // Validate StakeBalanceChanged and RemoveFromDelegationPoolIntent events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "remove_from_delegation_pool_intent",
    );
    assert_remove_from_delegation_pool_intent_event(
        spied_event: events[0],
        staker_address: cfg.test_info.staker_address,
        :pool_contract,
        :identifier,
        old_intent_amount: Zero::zero(),
        new_intent_amount: intent_amount,
    );
    assert_stake_balance_changed_event(
        spied_event: events[1],
        staker_address: cfg.test_info.staker_address,
        old_self_stake: cfg.staker_info.amount_own,
        old_delegated_stake: initial_delegated_stake,
        new_self_stake: cfg.staker_info.amount_own,
        new_delegated_stake: cur_delegated_stake,
    );

    // Decrease intent amount.
    let old_intent_amount = intent_amount;
    let new_intent_amount = old_intent_amount / 2;

    // Increase index.
    global_index = global_index + BASE_VALUE;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![global_index.into()].span(),
    );

    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: new_intent_amount,
        );

    // Validate that the staker info is updated.
    let interest = global_index - expected_staker_info.index;
    let staker_rewards = compute_rewards_rounded_down(
        amount: expected_staker_info.amount_own, :interest,
    );
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: cur_delegated_stake, :interest,
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: expected_staker_info.get_pool_info().commission,
    );
    staker_unclaimed_rewards = staker_unclaimed_rewards + staker_rewards + commission_amount;
    pool_unclaimed_rewards = pool_unclaimed_rewards
        + pool_rewards_including_commission
        - commission_amount;
    let prev_delegated_stake = cur_delegated_stake;
    cur_delegated_stake = initial_delegated_stake - new_intent_amount;
    expected_staker_info.unclaimed_rewards_own = staker_unclaimed_rewards;
    expected_staker_info.index = global_index;
    expected_staker_info
        .pool_info =
            Option::Some(
                StakerPoolInfo {
                    pool_contract,
                    amount: cur_delegated_stake,
                    unclaimed_rewards: pool_unclaimed_rewards,
                    ..expected_staker_info.get_pool_info(),
                },
            );
    assert_eq!(
        staking_dispatcher.staker_info(cfg.test_info.staker_address), expected_staker_info.into(),
    );

    // Validate that the total stake is updated.
    let expected_total_stake = old_total_stake - new_intent_amount;
    assert_eq!(staking_dispatcher.get_total_stake(), expected_total_stake);

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
        .add(delta: staking_dispatcher.contract_parameters().exit_wait_window);
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_unpool_time, amount: new_intent_amount,
    };
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);

    // Validate StakeBalanceChanged and RemoveFromDelegationPoolIntent events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 4, message: "remove_from_delegation_pool_intent",
    );
    assert_remove_from_delegation_pool_intent_event(
        spied_event: events[2],
        staker_address: cfg.test_info.staker_address,
        :pool_contract,
        :identifier,
        :old_intent_amount,
        :new_intent_amount,
    );
    assert_stake_balance_changed_event(
        spied_event: events[3],
        staker_address: cfg.test_info.staker_address,
        old_self_stake: cfg.staker_info.amount_own,
        old_delegated_stake: prev_delegated_stake,
        new_self_stake: expected_staker_info.amount_own,
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

    // Should catch MISSING_POOL_CONTRACT.
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let result = staking_pool_safe_dispatcher
        .remove_from_delegation_pool_intent(:staker_address, :identifier, :amount);
    assert_panic_with_error(:result, expected_error: Error::MISSING_POOL_CONTRACT.describe());

    // Should catch CALLER_IS_NOT_POOL_CONTRACT.
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let commission = cfg.staker_info.get_pool_info().commission;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let pool_contract = staking_dispatcher.set_open_for_delegation(:commission);
    let result = staking_pool_safe_dispatcher
        .remove_from_delegation_pool_intent(:staker_address, :identifier, :amount);
    assert_panic_with_error(:result, expected_error: Error::CALLER_IS_NOT_POOL_CONTRACT.describe());

    // Should catch INVALID_UNDELEGATE_INTENT_VALUE.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let invalid_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: Timestamp { seconds: 1 }, amount: 0,
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    // Remove from delegation pool intent, and then check that the intent was added correctly.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: cfg.pool_member_info.amount,
        );
    // Remove from delegation pool action, and then check that the intent was removed correctly.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now()
            .add(delta: staking_dispatcher.contract_parameters().exit_wait_window)
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
    assert_eq!(actual_undelegate_intent_value_after_action, Zero::zero());
    // Check that the amount was transferred correctly.
    let pool_balance_after_action = token_dispatcher.balance_of(pool_contract);
    assert_eq!(
        pool_balance_after_action, pool_balance_before_action + cfg.pool_member_info.amount.into(),
    );
    // Validate RemoveFromDelegationPoolAction event, the second one is UpdateGlobalIndex.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "remove_from_delegation_pool_action",
    );
    assert_remove_from_delegation_pool_action_event(
        spied_event: events[1],
        :pool_contract,
        identifier: cfg.test_info.pool_member_address.into(),
        amount: cfg.pool_member_info.amount,
    );
}

// The following test checks that the remove_from_delegation_pool_action function works when there
// is no intent, but simply returns 0 and does not transfer any funds.
#[test]
fn test_remove_from_delegation_pool_action_intent_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy staking contract.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    let caller_address = CALLER_ADDRESS();
    // Remove from delegation pool action, and check it returns 0 and does not change balance.
    let staking_balance_before_action = token_dispatcher.balance_of(staking_contract);
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_pool_dispatcher.remove_from_delegation_pool_action(identifier: DUMMY_IDENTIFIER);
    let staking_balance_after_action = token_dispatcher.balance_of(staking_contract);
    assert_eq!(staking_balance_after_action, staking_balance_before_action);
}

#[test]
#[should_panic(expected: "Intent window is not finished")]
fn test_remove_from_delegation_pool_action_intent_not_finished() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    // Intent.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: cfg.pool_member_info.amount,
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier = cfg.staking_contract_info.reward_supplier;

    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    // Initialize from_staker.
    let from_pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let from_pool_dispatcher = IPoolDispatcher { contract_address: from_pool_contract };
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: from_pool_contract, :cfg, :token_address,
    );
    // Initialize to_staker.
    let to_staker = OTHER_STAKER_ADDRESS();
    cfg.test_info.staker_address = to_staker;
    cfg.staker_info.operational_address = OTHER_OPERATIONAL_ADDRESS();
    let to_pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let to_pool_dispatcher = IPoolDispatcher { contract_address: to_pool_contract };
    let to_staker_info = staking_dispatcher.staker_info(staker_address: to_staker);
    // Pool member remove_from_delegation_pool_intent.
    let pool_member = cfg.test_info.pool_member_address;
    cheat_caller_address_once(contract_address: from_pool_contract, caller_address: pool_member);
    from_pool_dispatcher.exit_delegation_pool_intent(amount: cfg.pool_member_info.amount);
    let total_stake_before_switching = staking_dispatcher.get_total_stake();
    // Initialize SwitchPoolData.
    let switch_pool_data = SwitchPoolData {
        pool_member, reward_address: cfg.pool_member_info.reward_address,
    };
    let mut serialized_data = array![];
    switch_pool_data.serialize(ref output: serialized_data);

    let switched_amount = cfg.pool_member_info.amount / 2;
    let updated_index = cfg.staker_info.index + BASE_VALUE;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span(),
    );
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
    let interest = updated_index - cfg.staker_info.index;
    let staker_rewards = compute_rewards_rounded_down(
        amount: cfg.staker_info.amount_own, :interest,
    );
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: cfg.staker_info.get_pool_info().amount, :interest,
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info().commission,
    );
    let unclaimed_rewards_own = staker_rewards + commission_amount;
    let unclaimed_rewards_pool = pool_rewards_including_commission - commission_amount;
    let amount = cfg.staker_info.get_pool_info().amount + switched_amount;
    let mut expected_staker_info = StakerInfo {
        index: updated_index, unclaimed_rewards_own, ..to_staker_info,
    };
    if let Option::Some(mut pool_info) = expected_staker_info.pool_info {
        pool_info.amount = amount;
        pool_info.unclaimed_rewards = unclaimed_rewards_pool;
        expected_staker_info.pool_info = Option::Some(pool_info);
    };
    let actual_staker_info = staking_dispatcher.staker_info(staker_address: to_staker);
    assert_eq!(actual_staker_info, expected_staker_info);
    // Check total_stake was updated.
    let expected_total_stake = total_stake_before_switching + switched_amount;
    let actual_total_stake = staking_dispatcher.get_total_stake();
    assert_eq!(actual_total_stake, expected_total_stake);
    // Check that the pool member's intent amount was decreased.
    let expected_undelegate_intent_value_amount = cfg.pool_member_info.amount - switched_amount;
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: from_pool_contract, identifier: pool_member.into(),
    };
    let actual_undelegate_intent_value: UndelegateIntentValue = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract,
    );
    assert_eq!(actual_undelegate_intent_value.amount, expected_undelegate_intent_value_amount);
    assert!(actual_undelegate_intent_value.unpool_time.is_non_zero());
    assert_eq!(to_pool_dispatcher.pool_member_info(:pool_member).amount, switched_amount);
    let caller_address = from_pool_contract;
    // Switch again with the rest of the amount, and verify the intent is removed.
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards_pool, :token_address,
    );
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
    assert_eq!(actual_undelegate_intent_value_after_switching, Zero::zero());
    // Validate events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 6, message: "switch_staking_delegation_pool",
    );
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[0],
        staker_address: cfg.test_info.staker_address,
        pool_address: to_pool_contract,
        amount: unclaimed_rewards_pool,
    );
    let self_stake = to_staker_info.amount_own;
    assert_stake_balance_changed_event(
        spied_event: events[1],
        staker_address: to_staker,
        old_self_stake: self_stake,
        old_delegated_stake: Zero::zero(),
        new_self_stake: self_stake,
        new_delegated_stake: switched_amount,
    );
    assert_change_delegation_pool_intent_event(
        spied_event: events[2],
        pool_contract: from_pool_contract,
        identifier: pool_member.into(),
        old_intent_amount: cfg.pool_member_info.amount,
        new_intent_amount: cfg.pool_member_info.amount - switched_amount,
    );
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[3],
        staker_address: cfg.test_info.staker_address,
        pool_address: to_pool_contract,
        amount: unclaimed_rewards_pool,
    );
    assert_stake_balance_changed_event(
        spied_event: events[4],
        staker_address: to_staker,
        old_self_stake: self_stake,
        old_delegated_stake: switched_amount,
        new_self_stake: self_stake,
        new_delegated_stake: switched_amount * 2,
    );
    assert_change_delegation_pool_intent_event(
        spied_event: events[5],
        pool_contract: from_pool_contract,
        identifier: pool_member.into(),
        old_intent_amount: cfg.pool_member_info.amount - switched_amount,
        new_intent_amount: Zero::zero(),
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_switch_staking_delegation_pool_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pool_safe_dispatcher = IStakingPoolSafeDispatcher {
        contract_address: staking_contract,
    };
    let switched_amount = 1;

    // Initialize from_staker.
    let from_pool = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let from_pool_dispatcher = IPoolDispatcher { contract_address: from_pool };
    enter_delegation_pool_for_testing_using_dispatcher(
        pool_contract: from_pool, :cfg, :token_address,
    );

    // Initialize to_staker.
    let to_staker = OTHER_STAKER_ADDRESS();
    cfg.test_info.staker_address = to_staker;
    cfg.staker_info.operational_address = OTHER_OPERATIONAL_ADDRESS();
    let to_pool = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);

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
    from_pool_dispatcher.exit_delegation_pool_intent(amount: cfg.pool_member_info.amount);

    // Catch AMOUNT_TOO_HIGH.
    let switched_amount = cfg.pool_member_info.amount + 1;
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
}


#[test]
fn test_update_global_index_if_needed() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;

    // Get the initial global index.
    let global_index_before_first_update: Index = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index"),
    )
        .try_into()
        .expect('global index not fit in Index');
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let mut spy = snforge_std::spy_events();

    // First update shouldn't change index (not enough time passed)
    staking_dispatcher.update_global_index_if_needed();
    let global_index_after_first_update: Index = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index"),
    )
        .try_into()
        .expect('global index not fit in Index');
    assert_eq!(global_index_before_first_update, global_index_after_first_update);
    // Advance time by a year, update total_stake to be total_supply (which is equal to initial
    // supply), which means that max_inflation * BASE_VALUE will be added to global_index.
    let global_index_increment = (cfg.minting_curve_contract_info.c_num.into()
        * BASE_VALUE
        / cfg.minting_curve_contract_info.c_denom.into());
    cfg
        .test_info
        .staker_initial_balance = cfg
        .test_info
        .initial_supply
        .try_into()
        .expect('intial_supply not fit in Amount');
    cfg.staker_info.amount_own = cfg.test_info.staker_initial_balance;
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let global_index_last_update_timestamp = Time::now();
    let global_index_current_update_timestamp = global_index_last_update_timestamp
        .add(delta: Time::days(count: 365));
    start_cheat_block_timestamp_global(
        block_timestamp: global_index_current_update_timestamp.into(),
    );
    staking_dispatcher.update_global_index_if_needed();
    let global_index_after_second_update: Index = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index"),
    )
        .try_into()
        .expect('global index not fit in Index');
    assert_eq!(
        global_index_after_second_update, global_index_after_first_update + global_index_increment,
    );
    // Validate `GlobalIndexUpdated` event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 3, message: "update_global_index");
    assert_global_index_updated_event(
        spied_event: events[2],
        old_index: global_index_before_first_update,
        new_index: global_index_after_second_update,
        :global_index_last_update_timestamp,
        :global_index_current_update_timestamp,
    );
}

#[test]
fn test_pool_contract_admin_role() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy the staking contract and stake with pool enabled.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    // Assert the correct governance admins are set.
    let pool_contract_roles_dispatcher = IRolesDispatcher { contract_address: pool_contract };
    assert!(
        pool_contract_roles_dispatcher
            .is_governance_admin(account: cfg.test_info.pool_contract_admin),
    );
    assert!(!pool_contract_roles_dispatcher.is_governance_admin(account: DUMMY_ADDRESS()));
}

#[test]
fn test_declare_operational_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    // Check map is empty before declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: operational_address,
        contract: staking_contract,
    );
    assert_eq!(bound_staker, Zero::zero());
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
    assert_eq!(bound_staker, staker_address);
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
    assert_eq!(bound_staker, other_staker_address);
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
    assert_eq!(bound_staker, other_staker_address);
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
    assert_eq!(bound_staker, Zero::zero());
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
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let operational_address = cfg.staker_info.operational_address;
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address,
    );
    staking_dispatcher.declare_operational_address(staker_address: DUMMY_ADDRESS());
}

#[test]
fn test_change_operational_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let staker_info = staking_dispatcher.staker_info(:staker_address);
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address,
    );
    staking_dispatcher.declare_operational_address(:staker_address);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.change_operational_address(:operational_address);
    let updated_staker_info = staking_dispatcher.staker_info(:staker_address);
    let expected_staker_info = StakerInfo { operational_address, ..staker_info };
    assert_eq!(updated_staker_info, expected_staker_info);
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
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
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
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
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
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
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
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.change_operational_address(:operational_address);
}

// The following test is failing due to a bug in update_commission.
// This test should pass upon correct implementation of update_commission.
// #[test]
// fn test_update_commission_with_claiming_rewards() {
//     let mut cfg: StakingInitConfig = Default::default();
//     let mut pool_info = cfg.staker_info.get_pool_info();
//     pool_info.commission = max(1, pool_info.commission);
//     cfg.staker_info.pool_info = Option::Some(pool_info);
//     let mut commission = pool_info.commission;

//     general_contract_system_deployment(ref :cfg);
//     let token_address = cfg.staking_contract_info.token_address;
//     let staking_contract = cfg.test_info.staking_contract;
//     let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
//     let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
//     let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
//     let staker_address = cfg.test_info.staker_address;
//     let pool_member = cfg.test_info.pool_member_address;
//     enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

//     let mut expected_unclaimed_rewards = create_rewards_for_pool_member(ref :cfg);

//     // Update commission.
//     commission -= 1;
//     cheat_caller_address_once(contract_address: staking_contract, caller_address:
//     staker_address);
//     staking_dispatcher.update_commission(:commission);
//     let mut pool_info = cfg.staker_info.get_pool_info();
//     pool_info.commission = commission;
//     cfg.staker_info.pool_info = Option::Some(pool_info);

//     expected_unclaimed_rewards += create_rewards_for_pool_member(ref :cfg);

//     cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
//     let claimed_rewards = pool_dispatcher.claim_rewards(:pool_member);
//     assert_eq!(claimed_rewards, expected_unclaimed_rewards);
// }

#[test]
fn test_update_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let interest = cfg.staking_contract_info.global_index - cfg.staker_info.index;
    let staker_address = cfg.test_info.staker_address;
    let staker_info_before_update = staking_dispatcher.staker_info(:staker_address);
    assert_eq!(
        staker_info_before_update.get_pool_info().commission,
        cfg.staker_info.get_pool_info().commission,
    );

    // Update commission.
    let mut spy = snforge_std::spy_events();
    let old_commission = cfg.staker_info.get_pool_info().commission;
    let commission = old_commission - 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.update_commission(:commission);

    // Assert rewards is updated.
    let staker_info = staking_dispatcher.staker_info(:staker_address);
    let staker_rewards = compute_rewards_rounded_down(amount: staker_info.amount_own, :interest);
    let pool_info = staker_info.get_pool_info();
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: pool_info.amount, :interest,
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: pool_info.commission,
    );
    let unclaimed_rewards_own = staker_rewards + commission_amount;
    let unclaimed_rewards_pool = pool_rewards_including_commission - commission_amount;

    // Assert rewards and commission are updated in the staker info.
    let expected_staker_info = StakerInfo {
        unclaimed_rewards_own,
        pool_info: Option::Some(
            StakerPoolInfo {
                unclaimed_rewards: unclaimed_rewards_pool,
                commission,
                ..staker_info.get_pool_info(),
            },
        ),
        ..staker_info,
    };
    assert_eq!(staker_info, expected_staker_info);

    // Assert commission is updated in the pool contract.
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let pool_contracts_parameters = pool_dispatcher.contract_parameters();
    let expected_pool_contracts_parameters = PoolContractInfo {
        commission, ..pool_contracts_parameters,
    };
    assert_eq!(pool_contracts_parameters, expected_pool_contracts_parameters);
    // Validate the single CommissionChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "update_commission");
    assert_commission_changed_event(
        spied_event: events[0],
        :staker_address,
        :pool_contract,
        new_commission: commission,
        :old_commission,
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_update_commission_caller_not_staker() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info().commission - 1);
}

#[test]
#[should_panic(expected: "Commission can only be decreased")]
fn test_update_commission_with_higher_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info().commission + 1);
}

#[test]
#[should_panic(expected: "Commission can only be decreased")]
fn test_update_commission_with_same_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.update_commission(commission: cfg.staker_info.get_pool_info().commission);
}

#[test]
#[should_panic(expected: "Staker does not have a pool contract")]
fn test_update_commission_with_no_pool() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher.update_commission(commission: cfg.staker_info.get_pool_info().commission);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_update_commission_staker_in_exit_window() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info().commission - 1);
}

#[test]
fn test_set_open_for_delegation() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let commission = cfg.staker_info.get_pool_info().commission;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let pool_contract = staking_dispatcher.set_open_for_delegation(:commission);
    let pool_info = staking_dispatcher.staker_info(:staker_address).get_pool_info();
    let expected_pool_info = StakerPoolInfo {
        commission, pool_contract, ..cfg.staker_info.get_pool_info(),
    };
    assert_eq!(pool_info, expected_pool_info);

    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_open_for_delegation");
    assert_new_delegation_pool_event(
        spied_event: events[0], :staker_address, pool_contract: pool_contract, :commission,
    );
}

#[test]
#[should_panic(expected: "Commission is out of range, expected to be 0-10000")]
fn test_set_open_for_delegation_commission_out_of_range() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher.set_open_for_delegation(commission: COMMISSION_DENOMINATOR + 1);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_set_open_for_delegation_unstake_in_progress() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.set_open_for_delegation(commission: COMMISSION_DENOMINATOR - 1);
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_set_open_for_delegation_staker_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .set_open_for_delegation(commission: cfg.staker_info.get_pool_info().commission);
}

#[test]
#[should_panic(expected: "Staker already has a pool")]
fn test_set_open_for_delegation_staker_has_pool() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    staking_dispatcher
        .set_open_for_delegation(commission: cfg.staker_info.get_pool_info().commission);
}

#[test]
fn test_set_min_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let old_min_stake = cfg.staking_contract_info.min_stake;
    assert_eq!(old_min_stake, staking_dispatcher.contract_parameters().min_stake);
    let new_min_stake = old_min_stake / 2;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_min_stake(min_stake: new_min_stake);
    assert_eq!(new_min_stake, staking_dispatcher.contract_parameters().min_stake);
    // Validate the single MinimumStakeChanged event.
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
    assert_eq!(old_exit_window, staking_dispatcher.contract_parameters().exit_wait_window);
    let new_exit_window = TimeDelta { seconds: DAY * 7 };
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_exit_wait_window(exit_wait_window: new_exit_window);
    assert_eq!(new_exit_window, staking_dispatcher.contract_parameters().exit_wait_window);
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
    assert_eq!(old_reward_supplier, staking_dispatcher.contract_parameters().reward_supplier);
    let new_reward_supplier = OTHER_REWARD_SUPPLIER_CONTRACT_ADDRESS();
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_reward_supplier(reward_supplier: new_reward_supplier);
    assert_eq!(new_reward_supplier, staking_dispatcher.contract_parameters().reward_supplier);
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
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let mut expected_staker_info = cfg.staker_info;
    expected_staker_info.pool_info = Option::None;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staker_info = staking_dispatcher.staker_info(:staker_address);
    assert_eq!(staker_info, expected_staker_info.into());
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_staker_info_staker_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher.staker_info(staker_address: NON_STAKER_ADDRESS());
}

#[test]
fn test_get_staker_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    // Check before staker enters.
    let option_staker_info = staking_dispatcher.get_staker_info(:staker_address);
    assert!(option_staker_info.is_none());
    // Check after staker enters.
    let mut expected_staker_info = cfg.staker_info;
    expected_staker_info.pool_info = Option::None;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let option_staker_info = staking_dispatcher.get_staker_info(:staker_address);
    assert_eq!(option_staker_info, Option::Some(expected_staker_info.into()));
}


#[test]
#[should_panic(expected: "Zero address caller is not allowed")]
fn test_assert_caller_is_not_zero() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    cfg.test_info.staker_address = Zero::zero();
    stake_from_zero_address(:cfg, :token_address, :staking_contract);
}

#[test]
fn test_get_pool_exit_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let pool_member = cfg.test_info.pool_member_address;
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    let exit_wait_window = staking_dispatcher.contract_parameters().exit_wait_window;
    // Before intent
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract, identifier: pool_member.into(),
    };
    let undelegate_intent_value = staking_dispatcher.get_pool_exit_intent(:undelegate_intent_key);
    assert_eq!(undelegate_intent_value, Zero::zero());
    // After intent
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    pool_dispatcher.exit_delegation_pool_intent(amount: 2);
    let undelegate_intent_value = staking_dispatcher.get_pool_exit_intent(:undelegate_intent_key);
    let expected = UndelegateIntentValue {
        unpool_time: Time::now().add(delta: exit_wait_window), amount: 2,
    };
    assert_eq!(undelegate_intent_value, expected);
    // Edit intent
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    pool_dispatcher.exit_delegation_pool_intent(amount: 1);
    let undelegate_intent_value = staking_dispatcher.get_pool_exit_intent(:undelegate_intent_key);
    let expected = UndelegateIntentValue {
        unpool_time: Time::now().add(delta: exit_wait_window), amount: 1,
    };
    assert_eq!(undelegate_intent_value, expected);
    // Cancel intent
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    pool_dispatcher.exit_delegation_pool_intent(amount: 0);
    let undelegate_intent_value = staking_dispatcher.get_pool_exit_intent(:undelegate_intent_key);
    assert_eq!(undelegate_intent_value, Zero::zero());
}

#[test]
fn test_get_staker_address_by_operational() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let operational_address = cfg.staker_info.operational_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: DUMMY_ADDRESS());
    let staker_address = staking_dispatcher.get_staker_address_by_operational(:operational_address);
    assert_eq!(staker_address, cfg.test_info.staker_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_get_staker_address_by_operational_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_safe_dispatcher = IStakingSafeDispatcher { contract_address: staking_contract };
    let operational_address = cfg.staker_info.operational_address;

    // Catch STAKER_NOT_EXISTS.
    let result = staking_safe_dispatcher.get_staker_address_by_operational(:operational_address);
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());
}

#[test]
fn test_get_current_epoch() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let current_epoch = staking_dispatcher.get_current_epoch();
    assert_eq!(current_epoch, 0);
    advance_block_number_global(blocks: EPOCH_LENGTH.into() - 1);
    let current_epoch = staking_dispatcher.get_current_epoch();
    assert_eq!(current_epoch, 0);
    advance_block_number_global(blocks: 1);
    let current_epoch = staking_dispatcher.get_current_epoch();
    assert_eq!(current_epoch, 1);
}

#[test]
fn test_update_rewards_from_attestation_contract() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let token_address = cfg.staking_contract_info.token_address;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staker_address = cfg.test_info.staker_address;
    let attestation_contract = cfg.test_info.attestation_contract;
    let staker_info_before = staking_dispatcher.staker_info(:staker_address);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: attestation_contract,
    );
    staking_dispatcher.update_rewards_from_attestation_contract(:staker_address);
    let staker_info_after = staking_dispatcher.staker_info(:staker_address);
    assert_eq!(staker_info_after, staker_info_before);
}

#[test]
#[feature("safe_dispatcher")]
fn test_update_rewards_from_attestation_contract_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_safe_dispatcher = IStakingSafeDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let attestation_contract = cfg.test_info.attestation_contract;

    // Catch CALLER_IS_NOT_ATTESTATION_CONTRACT.
    let result = staking_safe_dispatcher.update_rewards_from_attestation_contract(:staker_address);
    assert_panic_with_error(
        :result, expected_error: Error::CALLER_IS_NOT_ATTESTATION_CONTRACT.describe(),
    );
    // Catch STAKER_NOT_EXISTS.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: attestation_contract,
    );
    let result = staking_safe_dispatcher.update_rewards_from_attestation_contract(:staker_address);
    assert_panic_with_error(:result, expected_error: GenericError::STAKER_NOT_EXISTS.describe());
}

const UNPOOL_TIME: Timestamp = Timestamp { seconds: 1 };

#[test]
fn test_undelegate_intent_zero() {
    let d: UndelegateIntentValue = Zero::zero();
    assert_eq!(
        d,
        UndelegateIntentValue {
            unpool_time: Timestamp { seconds: Zero::zero() }, amount: Zero::zero(),
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
    let d = UndelegateIntentValue { unpool_time: UNPOOL_TIME, amount: 1 };
    assert!(!d.is_zero());
    assert!(d.is_non_zero());
}

#[test]
fn test_undelegate_intent_is_valid() {
    let d = UndelegateIntentValue { unpool_time: Zero::zero(), amount: Zero::zero() };
    assert!(d.is_valid());
    let d = UndelegateIntentValue { unpool_time: UNPOOL_TIME, amount: 1 };
    assert!(d.is_valid());
    let d = UndelegateIntentValue { unpool_time: Zero::zero(), amount: 1 };
    assert!(!d.is_valid());
    let d = UndelegateIntentValue { unpool_time: UNPOOL_TIME, amount: Zero::zero() };
    assert!(!d.is_valid());
}

#[test]
fn test_undelegate_intent_assert_valid() {
    let d = UndelegateIntentValue { unpool_time: Zero::zero(), amount: Zero::zero() };
    d.assert_valid();
    let d = UndelegateIntentValue { unpool_time: UNPOOL_TIME, amount: 1 };
    d.assert_valid();
}

#[test]
#[should_panic(expected: "Invalid undelegate intent value")]
fn test_undelegate_intent_assert_valid_panic() {
    let d = UndelegateIntentValue { unpool_time: Zero::zero(), amount: 1 };
    d.assert_valid();
}

#[test]
fn test_versioned_internal_staker_info_wrap_latest() {
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    let versioned_internal_staker_info = VersionedInternalStakerInfoTrait::wrap_latest(
        internal_staker_info,
    );
    assert_eq!(
        versioned_internal_staker_info, VersionedInternalStakerInfo::V1(internal_staker_info),
    );
}

#[test]
fn test_versioned_internal_staker_info_new_latest() {
    let internal_staker_info = VersionedInternalStakerInfoTrait::new_latest(
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    );
    if let VersionedInternalStakerInfo::V1(_) = internal_staker_info {
        return;
    } else {
        panic!("Expected Version V1");
    }
}

#[test]
fn test_versioned_internal_staker_info_is_none() {
    let versioned_none = VersionedInternalStakerInfo::None;
    let versioned_v0 = VersionedInternalStakerInfoTestTrait::new_v0(
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    );
    let versioned_latest = VersionedInternalStakerInfoTrait::new_latest(
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    );
    assert!(versioned_none.is_none());
    assert!(!versioned_v0.is_none());
    assert!(!versioned_latest.is_none());
}

#[test]
fn test_internal_staker_info() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingMigrationDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let mut expected_internal_staker_info = cfg.staker_info;
    expected_internal_staker_info.pool_info = Option::None;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let internal_staker_info = staking_dispatcher.internal_staker_info(:staker_address);
    assert_eq!(internal_staker_info, expected_internal_staker_info);
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
fn test_compute_unpool_time() {
    let exit_wait_window = DEFAULT_EXIT_WAIT_WINDOW;
    // Unstake_time is not set.
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    assert_eq!(
        internal_staker_info.compute_unpool_time(:exit_wait_window),
        Time::now().add(delta: exit_wait_window),
    );

    // Unstake_time is set.
    let unstake_time = Time::now().add(delta: Time::weeks(count: 1));
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::Some(unstake_time),
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };

    // Unstake time > current time.
    assert_eq!(Time::now(), Zero::zero());
    assert_eq!(internal_staker_info.compute_unpool_time(:exit_wait_window), unstake_time);

    // Unstake time < current time.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: exit_wait_window).into(),
    );
    assert_eq!(internal_staker_info.compute_unpool_time(:exit_wait_window), Time::now());
}

#[test]
fn test_get_pool_info() {
    let staker_pool_info = StakerPoolInfo {
        pool_contract: Zero::zero(),
        amount: Zero::zero(),
        unclaimed_rewards: Zero::zero(),
        commission: Zero::zero(),
    };
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::Some(staker_pool_info),
    };
    assert_eq!(internal_staker_info.get_pool_info(), staker_pool_info);
}

#[test]
#[should_panic(expected: "Staker does not have a pool contract")]
fn test_get_pool_info_panic() {
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    internal_staker_info.get_pool_info();
}

#[test]
fn test_internal_staker_info_latest_into_staker_info() {
    let internal_staker_info = InternalStakerInfoLatest {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    let staker_info: StakerInfo = internal_staker_info.into();
    let expected_staker_info = StakerInfo {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    assert_eq!(staker_info, expected_staker_info);
}

#[test]
fn test_sanity_storage_versioned_internal_staker_info() {
    let mut state = VersionedStorageContractTest::contract_state_for_testing();
    state
        .staker_info
        .write(
            STAKER_ADDRESS(),
            Option::Some(
                InternalStakerInfoTestTrait::new(
                    reward_address: Zero::zero(),
                    operational_address: Zero::zero(),
                    unstake_time: Option::None,
                    amount_own: Zero::zero(),
                    index: Zero::zero(),
                    unclaimed_rewards_own: Zero::zero(),
                    pool_info: Option::None,
                ),
            ),
        );
    assert_eq!(
        state.new_staker_info.read(STAKER_ADDRESS()),
        VersionedInternalStakerInfoTestTrait::new_v0(
            reward_address: Zero::zero(),
            operational_address: Zero::zero(),
            unstake_time: Option::None,
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: Zero::zero(),
            pool_info: Option::None,
        ),
    );
}

#[test]
fn test_sanity_serde_versioned_internal_staker_info() {
    let option_internal_staker_info = Option::Some(
        InternalStakerInfoTestTrait::new(
            reward_address: Zero::zero(),
            operational_address: Zero::zero(),
            unstake_time: Option::None,
            amount_own: Zero::zero(),
            index: Zero::zero(),
            unclaimed_rewards_own: Zero::zero(),
            pool_info: Option::None,
        ),
    );
    let mut arr = array![];
    option_internal_staker_info.serialize(ref arr);
    let mut span = arr.span();
    let versioned_staker_info: VersionedInternalStakerInfo = Serde::<
        VersionedInternalStakerInfo,
    >::deserialize(ref span)
        .unwrap();
    let expected_versioned_staker_info = VersionedInternalStakerInfoTestTrait::new_v0(
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    );
    assert_eq!(versioned_staker_info, expected_versioned_staker_info);
}

#[test]
fn test_staker_info_into_internal_staker_info_v1() {
    let staker_info = StakerInfo {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    let internal_staker_info: InternalStakerInfoV1 = staker_info.into();
    let expected_internal_staker_info = InternalStakerInfoV1 {
        reward_address: Zero::zero(),
        operational_address: Zero::zero(),
        unstake_time: Option::None,
        amount_own: Zero::zero(),
        index: Zero::zero(),
        unclaimed_rewards_own: Zero::zero(),
        pool_info: Option::None,
    };
    assert_eq!(internal_staker_info, expected_internal_staker_info);
}

#[test]
#[should_panic(expected: "Invalid epoch length, must be greater than 0")]
fn test_epoch_info_new_invalid_length() {
    EpochInfoTrait::new(length: Zero::zero(), starting_block: get_block_number());
}

#[test]
fn test_epoch_info_current_epoch() {
    let block_number = EPOCH_STARTING_BLOCK;
    let length = EPOCH_LENGTH;
    start_cheat_block_number_global(:block_number);
    let epoch_info = EpochInfoTrait::new(:length, starting_block: get_block_number());
    assert_eq!(epoch_info.current_epoch(), Zero::zero());
    advance_block_number_global(blocks: length.into() - 1);
    assert_eq!(epoch_info.current_epoch(), Zero::zero());
    advance_block_number_global(blocks: 1);
    assert_eq!(epoch_info.current_epoch(), 1);
}

#[test]
fn test_epoch_info_update() {
    let block_number = EPOCH_STARTING_BLOCK;
    let length = EPOCH_LENGTH;
    start_cheat_block_number_global(:block_number);
    let mut epoch_info = EpochInfoTrait::new(:length, starting_block: get_block_number());
    let first_epoch = 10;
    advance_block_number_global(blocks: first_epoch * length.into());
    assert_eq!(epoch_info.current_epoch(), first_epoch);

    // Update in the first block of the epoch.
    let new_epoch_length = length + 1;
    epoch_info.update(epoch_length: new_epoch_length);
    assert_eq!(epoch_info.current_epoch(), first_epoch);
    // Still the same length.
    advance_block_number_global(blocks: length.into() - 1);
    assert_eq!(epoch_info.current_epoch(), first_epoch);
    advance_block_number_global(blocks: 1);
    assert_eq!(epoch_info.current_epoch(), first_epoch + 1);
    // Different length.
    advance_block_number_global(blocks: length.into());
    assert_eq!(epoch_info.current_epoch(), first_epoch + 1);
    advance_block_number_global(blocks: 1);
    assert_eq!(epoch_info.current_epoch(), first_epoch + 2);

    // Update in the last block of the epoch.
    advance_block_number_global(blocks: length.into());
    epoch_info.update(epoch_length: EPOCH_LENGTH - 1);
    assert_eq!(epoch_info.current_epoch(), first_epoch + 2);
    advance_block_number_global(blocks: 1);
    assert_eq!(epoch_info.current_epoch(), first_epoch + 3);
    advance_block_number_global(blocks: length.into() - 2);
    assert_eq!(epoch_info.current_epoch(), first_epoch + 3);
    advance_block_number_global(blocks: 1);
    assert_eq!(epoch_info.current_epoch(), first_epoch + 4);
}

#[test]
fn test_set_epoch_length() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let new_length = 2 * EPOCH_LENGTH;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin,
    );
    staking_config_dispatcher.set_epoch_length(epoch_length: new_length);
    advance_block_number_global(blocks: EPOCH_LENGTH.into() - 1);
    assert_eq!(staking_dispatcher.get_current_epoch(), 0);
    advance_block_number_global(blocks: 1);
    assert_eq!(staking_dispatcher.get_current_epoch(), 1);
    advance_block_number_global(blocks: EPOCH_LENGTH.into());
    assert_eq!(staking_dispatcher.get_current_epoch(), 1);
    advance_block_number_global(blocks: EPOCH_LENGTH.into() - 1);
    assert_eq!(staking_dispatcher.get_current_epoch(), 1);
    advance_block_number_global(blocks: 1);
    assert_eq!(staking_dispatcher.get_current_epoch(), 2);
    // Events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 0, message: "set_epoch_length");
}

#[test]
#[should_panic(expected: "ONLY_TOKEN_ADMIN")]
fn test_set_epoch_length_not_token_admin() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let non_token_admin = NON_TOKEN_ADMIN();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: non_token_admin);
    staking_config_dispatcher.set_epoch_length(epoch_length: EPOCH_LENGTH);
}

#[test]
fn test_staking_eic() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let upgrade_governor = cfg.test_info.upgrade_governor;
    let expected_total_stake: Amount = 123;

    // Upgrade.
    let eic_data = EICData {
        eic_hash: declare_staking_eic_contract(),
        eic_init_data: [
            MAINNET_STAKING_CLASS_HASH_V0().into(), EPOCH_LENGTH.into(),
            expected_total_stake.into(),
        ]
            .span(),
    };
    let implementation_data = ImplementationData {
        impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    upgrade_implementation(
        contract_address: staking_contract, :implementation_data, :upgrade_governor,
    );
    // Test.
    let map_selector = selector!("prev_class_hash");
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: [0].span());
    let prev_class_hash = *snforge_std::load(
        target: staking_contract, :storage_address, size: Store::<ClassHash>::size().into(),
    )
        .at(0);
    assert_eq!(prev_class_hash.try_into().unwrap(), MAINNET_STAKING_CLASS_HASH_V0());

    let mut loaded_value = snforge_std::load(
        target: staking_contract,
        storage_address: selector!("epoch_info"),
        size: Store::<EpochInfo>::size().into(),
    )
        .span();
    let loaded_epoch_info = Serde::<EpochInfo>::deserialize(ref loaded_value).unwrap();
    let expected_epoch_info = EpochInfoTrait::new(
        length: EPOCH_LENGTH, starting_block: get_block_number(),
    );
    assert_eq!(expected_epoch_info, loaded_epoch_info);

    let actual_total_stake = staking_dispatcher.get_total_stake();
    assert_eq!(expected_total_stake, actual_total_stake);
}

#[test]
#[should_panic(expected: 'EXPECTED_DATA_LENGTH_3')]
fn test_staking_eic_with_wrong_number_of_data_elemnts() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let upgrade_governor = cfg.test_info.upgrade_governor;
    // Upgrade.
    let eic_data = EICData { eic_hash: declare_staking_eic_contract(), eic_init_data: [].span() };
    let implementation_data = ImplementationData {
        impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
    };
    // Cheat block timestamp to enable upgrade eligibility.
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 1)).into(),
    );
    upgrade_implementation(
        contract_address: staking_contract, :implementation_data, :upgrade_governor,
    );
}
