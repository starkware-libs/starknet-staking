use core::option::OptionTrait;
use contracts::constants::{BASE_VALUE, SECONDS_IN_DAY};
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
use test_utils::set_account_as_operator;
use test_utils::constants;
use constants::{DUMMY_ADDRESS, POOL_CONTRACT_ADDRESS, OTHER_STAKER_ADDRESS, OTHER_REWARD_ADDRESS};
use constants::{NON_STAKER_ADDRESS, POOL_MEMBER_STAKE_AMOUNT, CALLER_ADDRESS, DUMMY_IDENTIFIER};
use constants::OTHER_OPERATIONAL_ADDRESS;
use contracts::event_test_utils;
use event_test_utils::{assert_number_of_events, assert_staker_exit_intent_event};
use event_test_utils::{assert_stake_balance_changed_event, assert_delete_staker_event};
use event_test_utils::assert_staker_reward_address_change_event;
use event_test_utils::assert_new_delegation_pool_event;
use event_test_utils::assert_change_operational_address_event;
use event_test_utils::assert_new_staker_event;
use event_test_utils::assert_global_index_updated_event;
use event_test_utils::assert_rewards_supplied_to_delegation_pool_event;
use event_test_utils::assert_staker_reward_claimed_event;
use event_test_utils::{assert_paused_event, assert_unpaused_event};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::get_block_timestamp;
use contracts::staking::objects::{UndelegateIntentKey, UndelegateIntentValue};
use contracts::staking::objects::UndelegateIntentValueZero;
use contracts::staking::interface::{IStakingPoolDispatcher};
use contracts::staking::interface::{IStakingPauseDispatcher, IStakingPoolDispatcherTrait};
use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use contracts::staking::interface::IStakingPauseDispatcherTrait;
use contracts::staking::interface::{IStakingConfigDispatcher, IStakingConfigDispatcherTrait};
use contracts::staking::Staking::COMMISSION_DENOMINATOR;
use core::num::traits::Zero;
use contracts::staking::interface::StakingContractInfo;
use snforge_std::{cheat_caller_address, CheatSpan, cheat_account_contract_address};
use snforge_std::start_cheat_block_timestamp_global;
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use contracts_commons::test_utils::cheat_caller_address_once;
use contracts::pool::Pool::SwitchPoolData;
use contracts::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait};
use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};

#[test]
fn test_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    assert_eq!(state.min_stake.read(), cfg.staking_contract_info.min_stake);
    assert_eq!(
        state.erc20_dispatcher.read().contract_address, cfg.staking_contract_info.token_address
    );
    let contract_global_index: u64 = state.global_index.read();
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
    assert_eq!(expected_staker_info, staking_dispatcher.state_of(:staker_address));

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
    assert_stake_balance_changed_event(
        spied_event: events[0],
        :staker_address,
        old_self_stake: Zero::zero(),
        old_delegated_stake: Zero::zero(),
        new_self_stake: cfg.staker_info.amount_own,
        new_delegated_stake: Zero::zero()
    );
    assert_new_staker_event(
        spied_event: events[1],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        self_stake: cfg.staker_info.amount_own,
    );
}

#[test]
fn test_calculate_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg
        .staker_info =
            StakerInfo {
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
    assert!(state.calculate_rewards(ref :staker_info));
    let staker_rewards = compute_rewards_rounded_down(amount: staker_info.amount_own, :interest);
    let pool_rewards_including_commission = compute_rewards_rounded_up(
        amount: staker_info.get_pool_info_unchecked().amount, :interest
    );
    let commission_amount = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission,
        commission: cfg.staker_info.get_pool_info_unchecked().commission
    );
    let unclaimed_rewards_own: u128 = staker_rewards + commission_amount;
    let unclaimed_rewards: u128 = pool_rewards_including_commission - commission_amount;
    let expected_staker_info = StakerInfo {
        index: staker_info.index,
        unclaimed_rewards_own,
        pool_info: Option::Some(
            StakerPoolInfo { unclaimed_rewards, ..staker_info.get_pool_info_unchecked() }
        ),
        ..staker_info
    };
    assert_eq!(staker_info, expected_staker_info);
}

#[test]
fn test_calculate_rewards_unstake_intent() {
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    let mut staker_info = StakerInfo { unstake_time: Option::Some(1), ..cfg.staker_info };
    assert!(!state.calculate_rewards(ref :staker_info));
}

#[test]
#[should_panic(expected: "Staker already exists, use increase_stake instead.")]
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
#[should_panic(expected: "Operational address already exists.")]
fn test_stake_with_same_operational_address() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);

    let caller_address = OTHER_STAKER_ADDRESS();
    assert!(cfg.test_info.staker_address != caller_address);
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
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
#[should_panic(expected: "Amount is less than min stake - try again with enough funds.")]
fn test_stake_with_less_than_min_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.staker_info.amount_own = cfg.staking_contract_info.min_stake - 1;
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
}

#[test]
#[should_panic(expected: "Commission is out of range, expected to be 0-10000.")]
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
    let staker_info_before = staking_dispatcher.state_of(:staker_address);
    let increase_amount = cfg.staker_info.amount_own;
    let expected_staker_info = StakerInfo {
        amount_own: staker_info_before.amount_own + increase_amount, ..staker_info_before
    };
    let mut spy = snforge_std::spy_events();
    // Increase stake from the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.increase_stake(:staker_address, amount: increase_amount);

    let updated_staker_info = staking_dispatcher.state_of(:staker_address);
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
#[should_panic(expected: "Staker does not have a pool contract.")]
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
#[should_panic(expected: "Caller is not pool contract.")]
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
    let staker_info_before = staking_dispatcher.state_of(:staker_address);
    let increase_amount = cfg.staker_info.amount_own;
    let mut expected_staker_info = staker_info_before;
    expected_staker_info.amount_own += increase_amount;
    let caller_address = cfg.staker_info.reward_address;
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher.increase_stake(:staker_address, amount: increase_amount);
    let updated_staker_info = staking_dispatcher.state_of(:staker_address);
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
#[should_panic(expected: "Staker does not exist.")]
fn test_increase_stake_staker_address_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    // Use the default operator.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher
        .increase_stake(staker_address: NON_STAKER_ADDRESS(), amount: cfg.staker_info.amount_own);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window.")]
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
    let staker_info_before = staking_dispatcher.state_of(:staker_address);
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    staking_dispatcher.increase_stake(:staker_address, amount: Zero::zero());
    let staker_info_after = staking_dispatcher.state_of(:staker_address);
    assert_eq!(staker_info_before, staker_info_after);
}

#[test]
#[should_panic(expected: "Caller address should be staker address or reward address.")]
fn test_increase_stake_caller_cannot_increase() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
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
    let staker_info_before_change = staking_dispatcher.state_of(:staker_address);
    let other_reward_address = OTHER_REWARD_ADDRESS();

    // Set the same staker address.
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let mut spy = snforge_std::spy_events();
    staking_dispatcher.change_reward_address(reward_address: other_reward_address);
    let staker_info_after_change = staking_dispatcher.state_of(:staker_address);
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
#[should_panic(expected: "Staker does not exist.")]
fn test_change_reward_address_staker_not_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
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

    let new_staker_info = staking_disaptcher.state_of(:staker_address);
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
#[should_panic(expected: ("Claim rewards must be called from staker address or reward address.",))]
fn test_claim_rewards_panic_unauthorized() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = DUMMY_ADDRESS();
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher.claim_rewards(staker_address: cfg.test_info.staker_address);
}


#[test]
#[should_panic(expected: ("Staker does not exist.",))]
fn test_claim_rewards_panic_staker_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    // Use the default operator.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
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
    let staker_info = staking_dispatcher.state_of(:staker_address);
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
#[should_panic(expected: ("Staker does not exist.",))]
fn test_unstake_intent_staker_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher.unstake_intent();
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window.")]
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
    let unclaimed_rewards_own = staking_dispatcher.state_of(:staker_address).unclaimed_rewards_own;
    let caller_address = NON_STAKER_ADDRESS();
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    let mut spy = snforge_std::spy_events();
    let staker_amount = staking_dispatcher.unstake_action(:staker_address);
    assert_eq!(staker_amount, cfg.staker_info.amount_own);
    let actual_staker_info: Option<StakerInfo> = load_option_from_simple_map(
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
        staking_dispatcher.state_of(:staker_address).amount_own
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
            .state_of(:staker_address)
            .pool_info
            .unwrap()
            .pool_contract;
        cfg.staker_info.pool_info = Option::Some(pool_info);
    };
    let expected_staker_info = cfg.staker_info;
    // Check that the staker info was updated correctly.
    assert_eq!(expected_staker_info, staking_dispatcher.state_of(:staker_address));
    // Validate events.
    let events = spy.get_events().emitted_by(staking_contract).events;
    // There are five events: NewDelegationPool, StakeBalanceChange, NewStaker,
    // GovernanceAdminAdded, OperatorAdded.
    // We're checking only the first three that are from Staking and not from Roles component.
    assert_number_of_events(actual: events.len(), expected: 5, message: "stake_pool_enabled");
    let pool_info = cfg.staker_info.get_pool_info_unchecked();
    assert_new_delegation_pool_event(
        spied_event: events[0],
        :staker_address,
        pool_contract: pool_info.pool_contract,
        commission: pool_info.commission
    );
    assert_stake_balance_changed_event(
        spied_event: events[1],
        :staker_address,
        old_self_stake: Zero::zero(),
        old_delegated_stake: Zero::zero(),
        new_self_stake: cfg.staker_info.amount_own,
        new_delegated_stake: Zero::zero()
    );
    assert_new_staker_event(
        spied_event: events[2],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        operational_address: cfg.staker_info.operational_address,
        self_stake: cfg.staker_info.amount_own,
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
// TODO: Implement the following test.
//       Note: The happy flow is also tested in test_exit_delegation_pool_intent.
//       in pool/test.cairo.
#[test]
fn test_remove_from_delegation_pool_intent() {
    assert!(true);
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

    cheat_caller_address_once(contract_address: staking_contract, caller_address: pool_contract);
    let returned_amount = staking_pool_dispatcher
        .remove_from_delegation_pool_action(identifier: cfg.test_info.pool_member_address.into());
    assert_eq!(returned_amount, cfg.pool_member_info.amount);
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
    // TODO: Test event emitted.
    assert_eq!(
        pool_balance_after_action, pool_balance_before_action + cfg.pool_member_info.amount.into()
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
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
    // Remove from delegation pool action, and check it returns 0 and does not change balance.
    let staking_balance_before_action = erc20_dispatcher.balance_of(staking_contract);
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    let returned_amount = staking_pool_dispatcher
        .remove_from_delegation_pool_action(identifier: DUMMY_IDENTIFIER);
    assert_eq!(returned_amount, Zero::zero());
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
    set_account_as_operator(
        :staking_contract, account: to_staker, security_admin: cfg.test_info.security_admin
    );
    let to_pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
    let to_pool_dispatcher = IPoolDispatcher { contract_address: to_pool_contract };
    let to_staker_info = staking_dispatcher.state_of(staker_address: to_staker);
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
    let updated_index: u64 = cfg.staker_info.index * 2;
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![updated_index.into()].span()
    );
    let caller_address = from_pool_contract;
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
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
    };
    let actual_staker_info = staking_dispatcher.state_of(staker_address: to_staker);
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
    assert_eq!(to_pool_dispatcher.state_of(:pool_member).amount, switched_amount);
    let caller_address = from_pool_contract;
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
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
}


#[test]
fn test_update_global_index_if_needed() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;

    // Get the initial global index.
    let global_index_before_first_update: u64 = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index")
    )
        .try_into()
        .expect('global index not fit in u64');
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let mut spy = snforge_std::spy_events();
    // Use the default operator.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    // Try to update global index. This shouldn't update the index because a day hasn't passed.
    staking_dispatcher.update_global_index_if_needed();
    let global_index_after_first_update: u64 = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index")
    )
        .try_into()
        .expect('global index not fit in u64');
    assert_eq!(global_index_before_first_update, global_index_after_first_update);
    // Advance time by a year, update total_stake to be total_supply (which is equal to initial
    // supply), which means that max_inflation * BASE_VALUE will be added to global_index.
    let global_index_increment = (cfg.minting_curve_contract_info.c_num.into()
        * BASE_VALUE
        / cfg.minting_curve_contract_info.c_denom.into())
        .try_into()
        .expect('inflation not fit in u64');
    let global_index_last_update_timestamp = get_block_timestamp();
    let global_index_current_update_timestamp = global_index_last_update_timestamp
        + SECONDS_IN_DAY * 365;
    start_cheat_block_timestamp_global(block_timestamp: global_index_current_update_timestamp);
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("total_stake"),
        serialized_value: array![
            cfg.test_info.initial_supply.try_into().expect('intial_supply not fit in felt')
        ]
            .span()
    );
    // Use the default operator.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher.update_global_index_if_needed();
    let global_index_after_second_update: u64 = load_one_felt(
        target: staking_contract, storage_address: selector!("global_index")
    )
        .try_into()
        .expect('global index not fit in u64');
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

fn test_change_operational_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    let staker_info = staking_dispatcher.state_of(:staker_address);
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let mut spy = snforge_std::spy_events();
    staking_dispatcher.change_operational_address(:operational_address);
    let updated_staker_info = staking_dispatcher.state_of(:staker_address);
    let expected_staker_info = StakerInfo { operational_address, ..staker_info };
    assert_eq!(updated_staker_info, expected_staker_info);
    // Validate the single OperationalAddressChanged event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "change_operational_address"
    );
    assert_change_operational_address_event(
        spied_event: events[0],
        :staker_address,
        new_address: operational_address,
        old_address: cfg.staker_info.operational_address
    );
}

#[test]
#[should_panic(expected: ("Staker does not exist.",))]
fn test_change_operational_address_staker_doesnt_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let operational_address = OTHER_OPERATIONAL_ADDRESS();
    // Use the default operator.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address
    );
    staking_dispatcher.change_operational_address(:operational_address);
}

// #[test]
// fn test_update_commission() {
//     let cfg: StakingInitConfig = Default::default();
//     let token_address = deploy_mock_erc20_contract(
//         initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
//     );
//     let staking_contract = deploy_staking_contract(:token_address, :cfg);
//     let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
//     let pool_contract = stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
//     let interest = cfg.staking_contract_info.global_index - cfg.staker_info.index;
//     let staker_address = cfg.test_info.staker_address;
//     let staker_info_before_update = staking_dispatcher.state_of(:staker_address);
//     assert_eq!(
//         staker_info_before_update.get_pool_info_unchecked().commission,
//         cfg.staker_info.get_pool_info_unchecked().commission
//     );

//     // Update commission.
//     let mut spy = snforge_std::spy_events();
//     let old_commission = cfg.staker_info.get_pool_info_unchecked().commission;
//     let commission = old_commission - 1;
//     cheat_caller_address_once(contract_address: staking_contract,
//      caller_address: staker_address);
//     assert!(staking_dispatcher.update_commission(:commission));

//     // Assert rewards is updated.
//     let staker_info = staking_dispatcher.state_of(:staker_address);
//     let staker_rewards = compute_rewards_rounded_down(amount: staker_info.amount_own, :interest);
//     let pool_info = staker_info.get_pool_info_unchecked();
//     let pool_rewards_including_commission = compute_rewards_rounded_up(
//         amount: pool_info.amount, :interest
//     );
//     let commission_amount = compute_commission_amount_rounded_down(
//         rewards_including_commission: pool_rewards_including_commission,
//         commission: pool_info.commission
//     );
//     let unclaimed_rewards_own = staker_rewards + commission_amount;
//     let unclaimed_rewards_pool = pool_rewards_including_commission - commission_amount;

//     // Assert rewards and commission are updated in the staker info.
//     let expected_staker_info = StakerInfo {
//         unclaimed_rewards_own,
//         pool_info: Option::Some(
//             StakerPoolInfo {
//                 unclaimed_rewards: unclaimed_rewards_pool,
//                 commission,
//                 ..staker_info.get_pool_info_unchecked()
//             }
//         ),
//         ..staker_info
//     };
//     assert_eq!(staker_info, expected_staker_info);

//     // Assert commission is updated in the pool contract.
//     let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
//     let pool_contracts_parameters = pool_dispatcher.contract_parameters();
//     let expected_pool_contracts_parameters = PoolContractInfo {
//         commission, ..pool_contracts_parameters
//     };
//     assert_eq!(pool_contracts_parameters, expected_pool_contracts_parameters);
//     // Validate the single CommissionChanged event.
//     let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
//     assert_number_of_events(actual: events.len(), expected: 1, message: "update_commission");
//     assert_commission_changed_event(
//         spied_event: events[0],
//         :staker_address,
//         :pool_contract,
//         new_commission: commission,
//         :old_commission
//     );
// }

// #[test]
// #[should_panic(expected: ("Staker does not exist.",))]
// fn test_update_commission_caller_not_staker() {
//     let cfg: StakingInitConfig = Default::default();
//     let token_address = deploy_mock_erc20_contract(
//         initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
//     );
//     let staking_contract = deploy_staking_contract(:token_address, :cfg);
//     let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
//     let caller_address = NON_STAKER_ADDRESS();
//     set_account_as_operator(
//         :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
//     );
//     cheat_caller_address_once(contract_address: staking_contract, :caller_address);
//     staking_dispatcher
//         .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission - 1);
// }

// #[test]
// #[should_panic(expected: ("Commission cannot be increased.",))]
// fn test_update_commission_with_higher_commission() {
//     let cfg: StakingInitConfig = Default::default();
//     let token_address = deploy_mock_erc20_contract(
//         initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
//     );
//     let staking_contract = deploy_staking_contract(:token_address, :cfg);
//     stake_with_pool_enabled(:cfg, :token_address, :staking_contract);
//     let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
//     cheat_caller_address_once(
//         contract_address: staking_contract, caller_address: cfg.test_info.staker_address
//     );
//     staking_dispatcher
//         .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission + 1);
// }

// #[test]
// #[should_panic(expected: ("Staker does not have a pool contract.",))]
// fn test_update_commission_with_no_pool() {
//     let cfg: StakingInitConfig = Default::default();
//     let token_address = deploy_mock_erc20_contract(
//         initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
//     );
//     let staking_contract = deploy_staking_contract(:token_address, :cfg);
//     stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
//     cheat_caller_address_once(
//         contract_address: staking_contract, caller_address: cfg.test_info.staker_address
//     );
//     let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
//     staking_dispatcher
//         .update_commission(commission: cfg.staker_info.get_pool_info_unchecked().commission);
// }

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
    let pool_info = staking_dispatcher.state_of(:staker_address).get_pool_info_unchecked();
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
#[should_panic(expected: ("Commission is out of range, expected to be 0-10000.",))]
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
#[should_panic(expected: ("Staker does not exist.",))]
fn test_set_open_for_delegation_staker_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let caller_address = NON_STAKER_ADDRESS();
    set_account_as_operator(
        :staking_contract, account: caller_address, security_admin: cfg.test_info.security_admin
    );
    cheat_caller_address_once(contract_address: staking_contract, :caller_address);
    staking_dispatcher
        .set_open_for_delegation(commission: cfg.staker_info.get_pool_info_unchecked().commission);
}

#[test]
#[should_panic(expected: ("Staker already has a pool.",))]
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
fn test_pause() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    let is_paused = load_one_felt(
        target: staking_contract, storage_address: selector!("is_paused")
    );
    assert_eq!(is_paused, 0);
    assert!(!staking_dispatcher.is_paused());
    let mut spy = snforge_std::spy_events();
    // Pause with security agent.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent
    );
    staking_pause_dispatcher.pause();
    let is_paused = load_one_felt(
        target: staking_contract, storage_address: selector!("is_paused")
    );
    assert_ne!(is_paused, 0);
    assert!(staking_dispatcher.is_paused());
    // Unpause with security admin.
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_admin
    );
    staking_pause_dispatcher.unpause();
    assert!(!staking_dispatcher.is_paused());
    // Validate Paused and Unpaused events.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 2, message: "pause");
    assert_paused_event(spied_event: events[0], account: cfg.test_info.security_agent);
    assert_unpaused_event(spied_event: events[1], account: cfg.test_info.security_admin);
}

#[test]
#[should_panic(expected: ("Contract is paused.",))]
fn test_stake_when_paused() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent
    );
    staking_pause_dispatcher.pause();
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
}
// TODO: test thatonly security admin can unpause
// TODO: test thatonly security agent can pause
// TODO: test pause and unpause events
// TODO: test all functions that should panic when paused

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
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.app_governer
    );
    staking_config_dispatcher.set_min_stake(min_stake: new_min_stake);
    assert_eq!(new_min_stake, staking_dispatcher.contract_parameters().min_stake);
}

#[test]
fn test_set_exit_waiting_window() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: staking_contract };
    let old_exit_wait_window = cfg.staking_contract_info.exit_wait_window;
    assert_eq!(old_exit_wait_window, staking_dispatcher.contract_parameters().exit_wait_window);
    let new_exit_wait_window = SECONDS_IN_DAY * 7;
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.app_governer
    );
    staking_config_dispatcher.set_exit_wait_window(exit_wait_window: new_exit_wait_window);
    assert_eq!(new_exit_wait_window, staking_dispatcher.contract_parameters().exit_wait_window);
}
