use core::option::OptionTrait;
use contracts_commons::constants::{DAY};
use contracts::constants::{BASE_VALUE};
use contracts::staking::{StakerInfo, StakerInfoTrait, StakerPoolInfo};
use contracts::staking::Staking::InternalStakingFunctionsTrait;
use contracts::utils::{compute_rewards_rounded_down, compute_rewards_rounded_up};
use contracts::utils::compute_commission_amount_rounded_down;
use contracts::test_utils;
use test_utils::{initialize_staking_state_from_cfg, deploy_mock_erc20_contract, StakingInitConfig};
use test_utils::{fund, approve, deploy_staking_contract, stake_with_pool_enabled};
use test_utils::{enter_delegation_pool_for_testing_using_dispatcher, load_option_from_simple_map};
use test_utils::{load_from_simple_map, load_one_felt, stake_for_testing_using_dispatcher};
use test_utils::{general_contract_system_deployment, cheat_reward_for_reward_supplier};
use test_utils::deploy_reward_supplier_contract;
use test_utils::constants;
use constants::{DUMMY_ADDRESS, POOL_CONTRACT_ADDRESS, OTHER_STAKER_ADDRESS, OTHER_REWARD_ADDRESS};
use constants::{NON_STAKER_ADDRESS, POOL_MEMBER_STAKE_AMOUNT, CALLER_ADDRESS, DUMMY_IDENTIFIER};
use constants::{OTHER_OPERATIONAL_ADDRESS, OTHER_REWARD_SUPPLIER_CONTRACT_ADDRESS};
use constants::{POOL_MEMBER_UNCLAIMED_REWARDS, STAKER_UNCLAIMED_REWARDS};
use contracts::event_test_utils;
use event_test_utils::{assert_number_of_events, assert_staker_exit_intent_event};
use event_test_utils::{assert_stake_balance_changed_event, assert_delete_staker_event};
use event_test_utils::assert_staker_reward_address_change_event;
use event_test_utils::{assert_new_delegation_pool_event, assert_commission_changed_event};
use event_test_utils::assert_change_operational_address_event;
use event_test_utils::assert_declare_operational_address_event;
use event_test_utils::{assert_new_staker_event, assert_minimum_stake_changed_event};
use event_test_utils::{assert_global_index_updated_event, assert_exit_wait_window_changed_event};
use event_test_utils::assert_rewards_supplied_to_delegation_pool_event;
use event_test_utils::{assert_staker_reward_claimed_event, assert_reward_supplier_changed_event};
use event_test_utils::assert_remove_from_delegation_pool_action_event;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::{get_block_timestamp, ContractAddress};
use contracts::staking::objects::{UndelegateIntentKey, UndelegateIntentValue};
use contracts::staking::objects::{UndelegateIntentValueTrait, UndelegateIntentValueZero};
use contracts::staking::objects::{InternalStakerInfo, InternalStakerInfoTrait};
use contracts::staking::interface::{IStakingPoolDispatcher};
use contracts::staking::interface::{IStakingPoolDispatcherTrait};
use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use contracts::staking::interface::{IStakingConfigDispatcher, IStakingConfigDispatcherTrait};
use contracts::staking::Staking::COMMISSION_DENOMINATOR;
use core::num::traits::Zero;
use contracts::staking::interface::StakingContractInfo;
use snforge_std::{cheat_caller_address, CheatSpan, cheat_account_contract_address};
use snforge_std::start_cheat_block_timestamp_global;
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use contracts_commons::test_utils::cheat_caller_address_once;
use contracts::pool::Pool::SwitchPoolData;
use contracts::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait, PoolContractInfo};
use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use contracts::types::{Index, Amount};
use contracts::reward_supplier::interface::IRewardSupplierDispatcher;

#[test]
fn test_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    assert_eq!(state.min_stake.read(), cfg.staking_contract_info.min_stake);
    assert_eq!(
        state.erc20_dispatcher.read().contract_address, cfg.staking_contract_info.token_address
    );
    let contract_global_index = state.global_index.read();
    assert_eq!(BASE_VALUE, contract_global_index);
    let staker_address = state
        .operational_address_to_staker_address
        .read(cfg.staker_info.operational_address);
    assert_eq!(staker_address, Zero::zero());
    let staker_info = state.staker_info.read(staker_address);
    assert!(staker_info.is_none());
    assert_eq!(
        state.pool_contract_class_hash.read(), cfg.staking_contract_info.pool_contract_class_hash
    );
    assert_eq!(
        state.reward_supplier_dispatcher.read().contract_address,
        cfg.staking_contract_info.reward_supplier
    );
    assert_eq!(state.pool_contract_admin.read(), cfg.test_info.pool_contract_admin);
}

#[test]
fn test_stake() {
    // TODO(Nir, 01/08/2024): add initial supply and owner address to StakingInitConfig.
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
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert_eq!(expected_staker_info.into(), staking_dispatcher.staker_info(:staker_address));

    let staker_address_from_operational_address = load_from_simple_map(
        map_selector: selector!("operational_address_to_staker_address"),
        key: cfg.staker_info.operational_address,
        contract: staking_contract
    );
    // Check that the operational address to staker address mapping was updated correctly.
    assert_eq!(staker_address_from_operational_address, staker_address);

    // Check that the staker's tokens were transferred to the Staking contract.
    assert_eq!(
        erc20_dispatcher.balance_of(staker_address),
        (cfg.test_info.staker_initial_balance - cfg.staker_info.amount_own).into()
    );
    assert_eq!(erc20_dispatcher.balance_of(staking_contract), cfg.staker_info.amount_own.into());
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
        new_delegated_stake: Zero::zero()
    );
}

#[test]
fn test_update_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg
        .staker_info =
            InternalStakerInfo {
                pool_info: Option::Some(
                    StakerPoolInfo {
                        pool_contract: POOL_CONTRACT_ADDRESS(),
                        amount: POOL_MEMBER_STAKE_AMOUNT,
                        ..cfg.staker_info.get_pool_info_unchecked()
                    }
                ),
                index: 0,
                ..cfg.staker_info
            };

    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    let mut staker_info = cfg.staker_info;
    let interest = state.global_index.read() - staker_info.index;
    state.update_rewards(ref :staker_info);
    let staker_rewards = compute_rewards_rounded_down(amount: staker_info.amount_own, :interest);
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: staker_info.get_pool_info_unchecked().amount, :interest
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let unclaimed_rewards_own: Amount = staker_rewards + commission_amount;
    let unclaimed_rewards: Amount = pool_rewards_including_commission - commission_amount;
    let expected_staker_info = InternalStakerInfo {
        unclaimed_rewards_own,
        pool_info: Option::Some(
            StakerPoolInfo { unclaimed_rewards, ..staker_info.get_pool_info_unchecked() }
        ),
        ..staker_info
    };
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
    let erc20_dispatcher = IERC20Dispatcher {
        contract_address: cfg.staking_contract_info.token_address
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
                    pool_contract, unclaimed_rewards, ..cfg.staker_info.get_pool_info_unchecked()
                }
            );
    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards, :token_address
    );
    let pool_balance_before_rewards = erc20_dispatcher.balance_of(account: pool_contract);
    let expected_staker_info = InternalStakerInfo {
        pool_info: Option::Some(
            StakerPoolInfo {
                unclaimed_rewards: Zero::zero(), ..cfg.staker_info.get_pool_info_unchecked()
            }
        ),
        ..cfg.staker_info
    };
    // Send rewards to pool contract.
    state
        .send_rewards_to_delegation_pool(
            staker_address: cfg.test_info.staker_address,
            ref staker_info: cfg.staker_info,
            :erc20_dispatcher
        );
    // Check that unclaimed_rewards_own is set to zero and that the staker received the rewards.
    assert_eq!(expected_staker_info, cfg.staker_info);
    let pool_balance_after_rewards = erc20_dispatcher.balance_of(account: pool_contract);
    assert_eq!(pool_balance_after_rewards, pool_balance_before_rewards + unclaimed_rewards.into());
}


#[test]
fn test_send_rewards_to_staker() {
    // Initialize staking state.
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    cfg.test_info.staking_contract = snforge_std::test_address();
    let token_address = cfg.staking_contract_info.token_address;
    let erc20_dispatcher = IERC20Dispatcher {
        contract_address: cfg.staking_contract_info.token_address
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
    let expected_staker_info = InternalStakerInfo {
        unclaimed_rewards_own: Zero::zero(), ..cfg.staker_info
    };
    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards_own, :token_address
    );
    let staker_balance_before_rewards = erc20_dispatcher
        .balance_of(account: cfg.staker_info.reward_address);
    // Send rewards to staker's reward address.
    state
        .send_rewards_to_staker(
            staker_address: cfg.test_info.staker_address,
            ref staker_info: cfg.staker_info,
            :erc20_dispatcher
        );
    // Check that unclaimed_rewards_own is set to zero and that the staker received the rewards.
    assert_eq!(expected_staker_info, cfg.staker_info);
    let staker_balance_after_rewards = erc20_dispatcher
        .balance_of(account: cfg.staker_info.reward_address);
    assert_eq!(
        staker_balance_after_rewards, staker_balance_before_rewards + unclaimed_rewards_own.into()
    );
}


#[test]
fn test_update_rewards_unstake_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    let staker_info_expected = InternalStakerInfo {
        unstake_time: Option::Some(1), ..cfg.staker_info
    };
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
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.staker_info.amount_own,
            pool_enabled: cfg.test_info.pool_enabled,
            commission: cfg.staker_info.get_pool_info_unchecked().commission
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
            commission: cfg.staker_info.get_pool_info_unchecked().commission,
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
    let mut pool_info = cfg.staker_info.get_pool_info_unchecked();
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
    let updated_index = cfg.staker_info.index * 2;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span()
    );
    // Funds reward supplier and set his unclaimed rewards.
    let interest = updated_index - cfg.staker_info.index;
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: cfg.staker_info.get_pool_info_unchecked().amount, :interest
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let unclaimed_rewards_pool = pool_rewards_including_commission - commission_amount;

    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards_pool, :token_address
    );

    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    staking_pool_dispatcher
        .claim_delegation_pool_rewards(staker_address: cfg.test_info.staker_address);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert_eq!(erc20_dispatcher.balance_of(pool_contract), unclaimed_rewards_pool.into());

    // Validate the single RewardsSuppliedToDelegationPool event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "claim_delegation_pool_rewards"
    );
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[0],
        staker_address: cfg.test_info.staker_address,
        pool_address: pool_contract,
        amount: unclaimed_rewards_pool
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
        exit_wait_window: cfg.staking_contract_info.exit_wait_window
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
        amount_own: staker_info_before.amount_own + increase_amount, ..staker_info_before
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
        :new_delegated_stake
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
#[should_panic(expected: "Caller is not pool contract")]
fn test_claim_delegation_pool_rewards_unauthorized_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    // TODO: Set the contract address to the actual pool contract address.
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
        :token_address
    );
    // Approve the Staking contract to spend the reward's tokens.
    approve(
        owner: cfg.staker_info.reward_address,
        spender: staking_contract,
        amount: cfg.test_info.staker_initial_balance,
        :token_address
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
        new_delegated_stake: Zero::zero()
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
fn test_increase_stake_amount_is_zero() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let staker_info_before = staking_dispatcher.staker_info(:staker_address);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.increase_stake(:staker_address, amount: Zero::zero());
    let staker_info_after = staking_dispatcher.staker_info(:staker_address);
    assert_eq!(staker_info_before, staker_info_after);
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
            staker_address: cfg.test_info.staker_address, amount: cfg.staker_info.amount_own
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
        reward_address: other_reward_address, ..staker_info_before_change
    };
    assert_eq!(staker_info_after_change, staker_info_expected);
    // Validate the single StakerRewardAddressChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "change_reward_address");
    assert_staker_reward_address_change_event(
        spied_event: events[0],
        :staker_address,
        new_address: other_reward_address,
        old_address: cfg.staker_info.reward_address
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
        serialized_value: array![(cfg.staker_info.index).into() * 2].span()
    );
    // Funds reward supplier and set his unclaimed rewards.
    let expected_reward = cfg.staker_info.amount_own;
    cheat_reward_for_reward_supplier(:cfg, :reward_supplier, :expected_reward, :token_address);
    // Claim rewards and validate the results.
    let mut spy = snforge_std::spy_events();
    let staking_disaptcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let reward = staking_disaptcher.claim_rewards(:staker_address);
    assert_eq!(reward, expected_reward);

    let new_staker_info = staking_disaptcher.staker_info(:staker_address);
    assert_eq!(new_staker_info.unclaimed_rewards_own, 0);

    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = erc20_dispatcher.balance_of(cfg.staker_info.reward_address);
    assert_eq!(balance, reward.into());
    // Validate the single StakerRewardClaimed event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "claim_rewards");
    assert_staker_reward_claimed_event(
        spied_event: events[0],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        amount: reward
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
    let expected_time = get_block_timestamp()
        + staking_dispatcher.contract_parameters().exit_wait_window;
    assert_eq!((staker_info.unstake_time).unwrap(), unstake_time);
    assert_eq!(unstake_time, expected_time);
    assert_eq!(staking_dispatcher.get_total_stake(), Zero::zero());
    // Validate StakerExitIntent and StakeBalanceChanged events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "unstake_intent");
    assert_staker_exit_intent_event(
        spied_event: events[0],
        :staker_address,
        exit_timestamp: expected_time,
        amount: cfg.staker_info.amount_own
    );
    assert_stake_balance_changed_event(
        spied_event: events[1],
        :staker_address,
        old_self_stake: cfg.staker_info.amount_own,
        old_delegated_stake: 0,
        new_self_stake: 0,
        new_delegated_stake: 0
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
        span: CheatSpan::TargetCalls(2)
    );
    cheat_account_contract_address(
        contract_address: staking_contract,
        account_contract_address: cfg.test_info.staker_address,
        span: CheatSpan::TargetCalls(2)
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
    start_cheat_block_timestamp_global(block_timestamp: unstake_time + 1);
    let unclaimed_rewards_own = staking_dispatcher
        .staker_info(:staker_address)
        .unclaimed_rewards_own;
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    let mut spy = snforge_std::spy_events();
    let staker_amount = staking_dispatcher.unstake_action(:staker_address);
    assert_eq!(staker_amount, cfg.staker_info.amount_own);
    let actual_staker_info: Option<InternalStakerInfo> = load_option_from_simple_map(
        map_selector: selector!("staker_info"), key: staker_address, contract: staking_contract
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
        amount: unclaimed_rewards_own
    );
    // Validate RewardsSuppliedToDelegationPool event.
    assert_rewards_supplied_to_delegation_pool_event(
        spied_event: events[2],
        staker_address: cfg.test_info.staker_address,
        pool_address: pool_contract,
        amount: Zero::zero()
    );
    // Validate DeleteStaker event.
    assert_delete_staker_event(
        spied_event: events[3],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        pool_contract: Option::Some(pool_contract)
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
        staking_dispatcher.staker_info(:staker_address).amount_own
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
    let pool_info = cfg.staker_info.get_pool_info_unchecked();
    assert_new_delegation_pool_event(
        spied_event: events[0],
        :staker_address,
        pool_contract: pool_info.pool_contract,
        commission: pool_info.commission
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
        new_delegated_stake: Zero::zero()
    );
}

// TODO: Create tests that cover all panic scenarios for add_stake_from_pool.
// TODO: Implement the following test.
//       Note: The happy flow is also tested in test_enter_delegation_pool.
//       in pool/test.cairo.
#[test]
fn test_add_stake_from_pool() {
    assert!(true);
}

// TODO: Create tests that cover all panic scenarios for remove_from_delegation_pool_intent.
// This test should pass upon correct implementation of remove_from_delegation_pool_intent.
#[test]
#[ignore]
fn test_remove_from_delegation_pool_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);

    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let old_delegated_stake = staking_dispatcher
        .staker_info(cfg.test_info.staker_address)
        .get_pool_info_unchecked()
        .amount;
    let old_total_stake = staking_dispatcher.get_total_stake();
    let mut spy = snforge_std::spy_events();
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    let intent_amount = cfg.pool_member_info.amount / 2;

    // Change global index.
    let global_index = cfg.staker_info.index * 2;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![global_index.into()].span()
    );

    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: intent_amount
        );

    // Validate that the staker info is updated.
    let interest = global_index - cfg.staker_info.index;
    let staker_rewards = compute_rewards_rounded_down(
        amount: cfg.staker_info.amount_own, :interest
    );
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: old_delegated_stake, :interest
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let staker_unclaimed_rewards = staker_rewards + commission_amount;
    let pool_unclaimed_rewards = pool_rewards_including_commission - commission_amount;
    let new_delegated_stake = old_delegated_stake - intent_amount;
    let expected_staker_info = InternalStakerInfo {
        unclaimed_rewards_own: staker_unclaimed_rewards,
        index: global_index,
        pool_info: Option::Some(
            StakerPoolInfo {
                pool_contract,
                amount: new_delegated_stake,
                unclaimed_rewards: pool_unclaimed_rewards,
                ..cfg.staker_info.get_pool_info_unchecked()
            }
        ),
        ..cfg.staker_info
    };
    assert_eq!(
        staking_dispatcher.staker_info(cfg.test_info.staker_address), expected_staker_info.into()
    );

    // Validate that the total stake is updated.
    let expected_total_stake = old_total_stake - intent_amount;
    assert_eq!(staking_dispatcher.get_total_stake(), expected_total_stake);

    // Validate that the data written in the exit intents map is updated.
    let undelegate_intent_key = UndelegateIntentKey {
        pool_contract: pool_contract, identifier: cfg.test_info.pool_member_address.into(),
    };
    let actual_undelegate_intent_value = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract
    );
    let expected_unpool_time = get_block_timestamp()
        + staking_dispatcher.contract_parameters().exit_wait_window;
    let expected_undelegate_intent_value = UndelegateIntentValue {
        unpool_time: expected_unpool_time, amount: intent_amount
    };
    assert_eq!(actual_undelegate_intent_value, expected_undelegate_intent_value);

    // Validate StakeBalanceChanged event.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "remove_from_delegation_pool_intent"
    );
    assert_stake_balance_changed_event(
        spied_event: events[0],
        staker_address: cfg.test_info.staker_address,
        old_self_stake: cfg.staker_info.amount_own,
        :old_delegated_stake,
        new_self_stake: cfg.staker_info.amount_own,
        :new_delegated_stake
    );
}

#[test]
fn test_remove_from_delegation_pool_action() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;

    // Stake and enter delegation pool.
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    enter_delegation_pool_for_testing_using_dispatcher(:pool_contract, :cfg, :token_address);
    // Remove from delegation pool intent, and then check that the intent was added correctly.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    staking_pool_dispatcher
        .remove_from_delegation_pool_intent(
            staker_address: cfg.test_info.staker_address,
            identifier: cfg.test_info.pool_member_address.into(),
            amount: cfg.pool_member_info.amount
        );
    // Remove from delegation pool action, and then check that the intent was removed correctly.
    start_cheat_block_timestamp_global(
        block_timestamp: get_block_timestamp()
            + staking_dispatcher.contract_parameters().exit_wait_window
    );
    let pool_balance_before_action = erc20_dispatcher.balance_of(pool_contract);

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
        contract: staking_contract
    );
    assert_eq!(actual_undelegate_intent_value_after_action, Zero::zero());
    // Check that the amount was transferred correctly.
    let pool_balance_after_action = erc20_dispatcher.balance_of(pool_contract);
    assert_eq!(
        pool_balance_after_action, pool_balance_before_action + cfg.pool_member_info.amount.into()
    );
    // Validate RemoveFromDelegationPoolAction event, the second one is UpdateGlobalIndex.
    let events = spy.get_events().emitted_by(staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "remove_from_delegation_pool_action"
    );
    assert_remove_from_delegation_pool_action_event(
        spied_event: events[1],
        :pool_contract,
        identifier: cfg.test_info.pool_member_address.into(),
        amount: cfg.pool_member_info.amount
    );
}

// The following test checks that the remove_from_delegation_pool_action function works when there
// is no intent, but simply returns 0 and does not transfer any funds.
#[test]
fn test_remove_from_delegation_pool_action_intent_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy staking contract.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_pool_dispatcher = IStakingPoolDispatcher { contract_address: staking_contract };
    let caller_address = CALLER_ADDRESS();
    // Remove from delegation pool action, and check it returns 0 and does not change balance.
    let staking_balance_before_action = erc20_dispatcher.balance_of(staking_contract);
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_pool_dispatcher.remove_from_delegation_pool_action(identifier: DUMMY_IDENTIFIER);
    // TODO: Test event emitted.
    let staking_balance_after_action = erc20_dispatcher.balance_of(staking_contract);
    assert_eq!(staking_balance_after_action, staking_balance_before_action);
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
        pool_contract: from_pool_contract, :cfg, :token_address
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
        pool_member, reward_address: cfg.pool_member_info.reward_address
    };
    let mut serialized_data = array![];
    switch_pool_data.serialize(ref output: serialized_data);

    let switched_amount = cfg.pool_member_info.amount / 2;
    let updated_index = cfg.staker_info.index * 2;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span()
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
            identifier: pool_member.into()
        );
    let interest = updated_index - cfg.staker_info.index;
    let staker_rewards = compute_rewards_rounded_down(
        amount: cfg.staker_info.amount_own, :interest
    );
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: cfg.staker_info.get_pool_info_unchecked().amount, :interest
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let unclaimed_rewards_own = staker_rewards + commission_amount;
    let unclaimed_rewards_pool = pool_rewards_including_commission - commission_amount;
    let amount = cfg.staker_info.get_pool_info_unchecked().amount + switched_amount;
    let mut expected_staker_info = StakerInfo {
        index: updated_index, unclaimed_rewards_own, ..to_staker_info
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
        pool_contract: from_pool_contract, identifier: pool_member.into()
    };
    let actual_undelegate_intent_value: UndelegateIntentValue = load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract
    );
    assert_eq!(actual_undelegate_intent_value.amount, expected_undelegate_intent_value_amount);
    assert!(actual_undelegate_intent_value.unpool_time.is_non_zero());
    assert_eq!(to_pool_dispatcher.pool_member_info(:pool_member).amount, switched_amount);
    let caller_address = from_pool_contract;
    // Switch again with the rest of the amount, and verify the intent is removed.
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    cheat_reward_for_reward_supplier(
        :cfg, :reward_supplier, expected_reward: unclaimed_rewards_pool, :token_address
    );
    staking_pool_dispatcher
        .switch_staking_delegation_pool(
            :to_staker,
            to_pool: to_pool_contract,
            :switched_amount,
            data: serialized_data.span(),
            identifier: pool_member.into()
        );
    let actual_undelegate_intent_value_after_switching: UndelegateIntentValue =
        load_from_simple_map(
        map_selector: selector!("pool_exit_intents"),
        key: undelegate_intent_key,
        contract: staking_contract
    );
    assert_eq!(actual_undelegate_intent_value_after_switching, Zero::zero());
    // Validate events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "switch_staking_delegation_pool"
    );
    let self_stake = to_staker_info.amount_own;
    assert_stake_balance_changed_event(
        spied_event: events[0],
        staker_address: to_staker,
        old_self_stake: self_stake,
        old_delegated_stake: Zero::zero(),
        new_self_stake: self_stake,
        new_delegated_stake: switched_amount
    );
    assert_stake_balance_changed_event(
        spied_event: events[1],
        staker_address: to_staker,
        old_self_stake: self_stake,
        old_delegated_stake: switched_amount,
        new_self_stake: self_stake,
        new_delegated_stake: switched_amount * 2
    );
}


#[test]
fn test_update_global_index_if_needed() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;

    // Get the initial global index.
    let global_index_before_first_update: Index = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index")
    )
        .try_into()
        .expect('global index not fit in Index');
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let mut spy = snforge_std::spy_events();

    // Update global index (if enough time passed since last update).
    staking_dispatcher.update_global_index_if_needed();
    let global_index_after_first_update: Index = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index")
    )
        .try_into()
        .expect('global index not fit in Index');
    assert_eq!(global_index_before_first_update, global_index_after_first_update);
    // Advance time by a year, update total_stake to be total_supply (which is equal to initial
    // supply), which means that max_inflation * BASE_VALUE will be added to global_index.
    let global_index_increment = (cfg.minting_curve_contract_info.c_num.into()
        * BASE_VALUE
        / cfg.minting_curve_contract_info.c_denom.into())
        .try_into()
        .expect('inflation not fit in u64');
    let global_index_last_update_timestamp = get_block_timestamp();
    let global_index_current_update_timestamp = global_index_last_update_timestamp + DAY * 365;
    start_cheat_block_timestamp_global(block_timestamp: global_index_current_update_timestamp);
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("total_stake"),
        serialized_value: array![
            cfg.test_info.initial_supply.try_into().expect('intial_supply not fit in felt')
        ]
            .span()
    );
    staking_dispatcher.update_global_index_if_needed();
    let global_index_after_second_update: Index = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index")
    )
        .try_into()
        .expect('global index not fit in Index');
    assert_eq!(
        global_index_after_second_update, global_index_after_first_update + global_index_increment
    );
    // Validate events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "update_global_index");
    assert_global_index_updated_event(
        spied_event: events[0],
        old_index: global_index_before_first_update,
        new_index: global_index_after_second_update,
        :global_index_last_update_timestamp,
        :global_index_current_update_timestamp
    );
}

#[test]
fn test_pool_contract_admin_role() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract and stake with pool enabled.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    // Assert the correct governance admins are set.
    let pool_contract_roles_dispatcher = IRolesDispatcher { contract_address: pool_contract };
    assert!(
        pool_contract_roles_dispatcher
            .is_governance_admin(account: cfg.test_info.pool_contract_admin)
    );
    assert!(pool_contract_roles_dispatcher.is_governance_admin(account: staking_contract));
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
    let operational_address = cfg.staker_info.operational_address;
    // Check map is empty before declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: cfg.staker_info.operational_address,
        contract: staking_contract
    );
    assert_eq!(bound_staker, Zero::zero());
    // First declare
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address
    );
    staking_dispatcher.declare_operational_address(:staker_address);
    // Check map is updated after declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: cfg.staker_info.operational_address,
        contract: staking_contract
    );
    assert_eq!(bound_staker, staker_address);
    // Second declare
    let other_staker_address = OTHER_STAKER_ADDRESS();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address
    );
    staking_dispatcher.declare_operational_address(staker_address: other_staker_address);
    // Check map is updated after declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: cfg.staker_info.operational_address,
        contract: staking_contract
    );
    assert_eq!(bound_staker, other_staker_address);
    // Third declare with same operational and staker address - should not emit event or change map
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address
    );
    staking_dispatcher.declare_operational_address(staker_address: other_staker_address);
    // Check map is updated after declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: cfg.staker_info.operational_address,
        contract: staking_contract
    );
    assert_eq!(bound_staker, other_staker_address);
    // Fourth declare - set to zero
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address
    );
    staking_dispatcher.declare_operational_address(staker_address: Zero::zero());
    // Check map is updated after declare.
    let bound_staker: ContractAddress = load_from_simple_map(
        map_selector: selector!("eligible_operational_addresses"),
        key: cfg.staker_info.operational_address,
        contract: staking_contract
    );
    assert_eq!(bound_staker, Zero::zero());
    // Validate the OperationalAddressDeclared events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 3, message: "declare_operational_address"
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
fn test_change_operational_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let staker_info = staking_dispatcher.staker_info(:staker_address);
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: operational_address
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
        actual: events.len(), expected: 2, message: "change_operational_address"
    );
    assert_declare_operational_address_event(
        spied_event: events[0], :operational_address, :staker_address,
    );
    assert_change_operational_address_event(
        spied_event: events[1],
        :staker_address,
        new_address: operational_address,
        old_address: cfg.staker_info.operational_address
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_change_operational_address_staker_doesnt_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
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
//     let mut pool_info = cfg.staker_info.get_pool_info_unchecked();
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
//     let mut pool_info = cfg.staker_info.get_pool_info_unchecked();
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
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let interest = cfg.staking_contract_info.global_index - cfg.staker_info.index;
    let staker_address = cfg.test_info.staker_address;
    let staker_info_before_update = staking_dispatcher.staker_info(:staker_address);
    assert_eq!(
        staker_info_before_update.get_pool_info_unchecked().commission,
        cfg.staker_info.get_pool_info_unchecked().commission
    );

    // Update commission.
    let mut spy = snforge_std::spy_events();
    let old_commission = cfg.staker_info.get_pool_info_unchecked().commission;
    let commission = old_commission - 1;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.update_commission(:commission);

    // Assert rewards is updated.
    let staker_info = staking_dispatcher.staker_info(:staker_address);
    let staker_rewards = compute_rewards_rounded_down(amount: staker_info.amount_own, :interest);
    let pool_info = staker_info.get_pool_info_unchecked();
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: pool_info.amount, :interest
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: pool_info.commission
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
                ..staker_info.get_pool_info_unchecked()
            }
        ),
        ..staker_info
    };
    assert_eq!(staker_info, expected_staker_info);

    // Assert commission is updated in the pool contract.
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    let pool_contracts_parameters = pool_dispatcher.contract_parameters();
    let expected_pool_contracts_parameters = PoolContractInfo {
        commission, ..pool_contracts_parameters
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
        :old_commission
    );
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_update_commission_caller_not_staker() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission - 1);
}

#[test]
#[should_panic(expected: "Commission cannot be increased")]
fn test_update_commission_with_higher_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission + 1);
}

#[test]
fn test_update_commission_with_same_commission() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission);
}

#[test]
#[should_panic(expected: "Staker does not have a pool contract")]
fn test_update_commission_with_no_pool() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window")]
fn test_update_commission_staker_in_exit_window() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher.unstake_intent();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher
        .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission - 1);
}

#[test]
fn test_set_open_for_delegation() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let commission = cfg.staker_info.get_pool_info_unchecked().commission;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let pool_contract = staking_dispatcher.set_open_for_delegation(:commission);
    let pool_info = staking_dispatcher.staker_info(:staker_address).get_pool_info_unchecked();
    let expected_pool_info = StakerPoolInfo {
        commission, pool_contract, ..cfg.staker_info.get_pool_info_unchecked()
    };
    assert_eq!(pool_info, expected_pool_info);

    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_open_for_delegation");
    assert_new_delegation_pool_event(
        spied_event: events[0], :staker_address, pool_contract: pool_contract, :commission
    );
}

#[test]
#[should_panic(expected: "Commission is out of range, expected to be 0-10000")]
fn test_set_open_for_delegation_commission_out_of_range() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher.set_open_for_delegation(commission: COMMISSION_DENOMINATOR + 1);
}

#[test]
#[should_panic(expected: "Staker does not exist")]
fn test_set_open_for_delegation_staker_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .set_open_for_delegation(commission: cfg.staker_info.get_pool_info_unchecked().commission);
}

#[test]
#[should_panic(expected: "Staker already has a pool")]
fn test_set_open_for_delegation_staker_has_pool() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher
        .set_open_for_delegation(commission: cfg.staker_info.get_pool_info_unchecked().commission);
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
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin
    );
    staking_config_dispatcher.set_min_stake(min_stake: new_min_stake);
    assert_eq!(new_min_stake, staking_dispatcher.contract_parameters().min_stake);
    // Validate the single MinimumStakeChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_min_stake");
    assert_minimum_stake_changed_event(spied_event: events[0], :old_min_stake, :new_min_stake);
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
    let new_exit_window = DAY * 7;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin
    );
    staking_config_dispatcher.set_exit_wait_window(exit_wait_window: new_exit_window);
    assert_eq!(new_exit_window, staking_dispatcher.contract_parameters().exit_wait_window);
    // Validate the single ExitWaitWindowChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_exit_wait_window");
    assert_exit_wait_window_changed_event(
        spied_event: events[0], :old_exit_window, :new_exit_window
    );
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
        contract_address: staking_contract, caller_address: cfg.test_info.token_admin
    );
    staking_config_dispatcher.set_reward_supplier(reward_supplier: new_reward_supplier);
    assert_eq!(new_reward_supplier, staking_dispatcher.contract_parameters().reward_supplier);
    // Validate the single RewardSupplierChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_reward_supplier");
    assert_reward_supplier_changed_event(
        spied_event: events[0], :old_reward_supplier, :new_reward_supplier
    );
}

#[test]
fn test_undelegate_intent_value_is_valid() {
    let mut undelegate_intent_value = UndelegateIntentValue { unpool_time: 0, amount: 0 };
    assert_eq!(undelegate_intent_value.is_valid(), true);

    undelegate_intent_value = UndelegateIntentValue { unpool_time: 0, amount: 1 };
    assert_eq!(undelegate_intent_value.is_valid(), false);

    undelegate_intent_value = UndelegateIntentValue { unpool_time: 1, amount: 0 };
    assert_eq!(undelegate_intent_value.is_valid(), false);

    undelegate_intent_value = UndelegateIntentValue { unpool_time: 1, amount: 1 };
    assert_eq!(undelegate_intent_value.is_valid(), true);
}
