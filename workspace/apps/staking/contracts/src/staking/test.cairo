use core::option::OptionTrait;
use contracts::{
    constants::{BASE_VALUE, EXIT_WAITING_WINDOW},
    staking::{
        StakerInfo, Staking,
        Staking::{
            // TODO(Nir, 15/07/2024): Remove member module use's when possible
            __member_module_min_stake::InternalContractMemberStateTrait as MinStakeMemberModule,
            __member_module_staker_info::InternalContractMemberStateTrait as StakerAddressToStakerInfoMemberModule,
            __member_module_operational_address_to_staker_address::InternalContractMemberStateTrait as OperationalAddressToStakerAddressMemberModule,
            __member_module_token_address::InternalContractMemberStateTrait as TokenAddressMemberModule,
            __member_module_global_index::InternalContractMemberStateTrait as GlobalIndexMemberModule,
            InternalStakingFunctionsTrait
        }
    },
    utils::{compute_rewards, compute_commission},
    test_utils::{
        initialize_staking_state_from_cfg, deploy_mock_erc20_contract, StakingInitConfig,
        stake_for_testing, fund, approve, deploy_staking_contract, stake_with_pooling_enabled,
        enter_delegation_pool_for_testing_using_dispatcher, load_option_from_simple_map,
        constants::{
            TOKEN_ADDRESS, DUMMY_ADDRESS, POOLING_CONTRACT_ADDRESS, MIN_STAKE, OWNER_ADDRESS,
            INITIAL_SUPPLY, STAKER_REWARD_ADDRESS, OPERATIONAL_ADDRESS, STAKER_ADDRESS,
            STAKE_AMOUNT, STAKER_INITIAL_BALANCE, REV_SHARE, OTHER_STAKER_ADDRESS,
            OTHER_REWARD_ADDRESS, NON_STAKER_ADDRESS, DUMMY_CLASS_HASH, POOL_MEMBER_STAKE_AMOUNT
        }
    }
};
use contracts::event_test_utils::{
    assert_number_of_events, assert_staker_exit_intent_event, assert_staker_balance_changed_event
};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::{ContractAddress, contract_address_const, get_caller_address, get_block_timestamp};
use starknet::syscalls::deploy_syscall;
use snforge_std::{declare, ContractClassTrait};
use contracts::staking::staking::Staking::ContractState;
use contracts::staking::interface::{IStaking, IStakingDispatcher, IStakingDispatcherTrait};
use contracts::staking::Staking::{REV_SHARE_DENOMINATOR, MIN_INCREASE_STAKE};
use core::num::traits::Zero;
use contracts::staking::interface::StakingContractInfo;
use snforge_std::{cheat_caller_address, CheatSpan, test_address, cheat_block_timestamp};
use snforge_std::cheatcodes::events::{
    Event, Events, EventSpy, EventSpyTrait, is_emitted, EventsFilterTrait
};

#[test]
fn test_constructor() {
    let token_address: ContractAddress = TOKEN_ADDRESS();
    let dummy_address: ContractAddress = DUMMY_ADDRESS();
    let mut state = Staking::contract_state_for_testing();
    Staking::constructor(ref state, token_address, MIN_STAKE, DUMMY_CLASS_HASH());
    let contract_min_stake: u128 = state.min_stake.read();
    assert_eq!(MIN_STAKE, contract_min_stake);
    let contract_token_address: ContractAddress = state.token_address.read();
    assert_eq!(token_address, contract_token_address);
    let contract_global_index: u64 = state.global_index.read();
    assert_eq!(BASE_VALUE, contract_global_index);
    let staker_address = state.operational_address_to_staker_address.read(dummy_address);
    assert_eq!(staker_address, Zero::zero());
    let staker_info = state.staker_info.read(dummy_address);
    assert!(staker_info.is_none());
}

#[test]
fn test_stake() {
    // TODO(Nir, 01/08/2024): add initial supply and owner address to StakingInitConfig.
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    let mut spy = snforge_std::spy_events();
    stake_for_testing(ref state, :cfg, :token_address);

    let staker_address = cfg.test_info.staker_address;
    // Check that the staker info was updated correctly.
    let expected_staker_info = cfg.staker_info;
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert_eq!(expected_staker_info, state.get_staker_info(:staker_address));

    // Check that the operational address to staker address mapping was updated correctly.
    assert_eq!(
        staker_address,
        state.operational_address_to_staker_address.read(cfg.staker_info.operational_address)
    );

    // Check that the staker's tokens were transferred to the Staking contract.
    assert_eq!(
        erc20_dispatcher.balance_of(staker_address),
        (cfg.test_info.staker_initial_balance - cfg.staker_info.amount_own).into()
    );
    let staking_contract_address = test_address();
    assert_eq!(
        erc20_dispatcher.balance_of(staking_contract_address), cfg.staker_info.amount_own.into()
    );

    // Validate the single BalanceChanged event.
    let events = spy.get_events().emitted_by(test_address()).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "stake");
    assert_staker_balance_changed_event(
        spied_event: events[0], :staker_address, amount: cfg.staker_info.amount_own
    );
}

#[test]
fn test_calculate_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg
        .staker_info =
            StakerInfo {
                pooling_contract: Option::Some(POOLING_CONTRACT_ADDRESS()),
                amount_pool: POOL_MEMBER_STAKE_AMOUNT,
                index: 0,
                ..cfg.staker_info
            };

    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    let mut staker_info = cfg.staker_info;
    let interest = state.global_index.read() - staker_info.index;
    assert!(state.calculate_rewards(ref :staker_info));
    let staker_rewards = compute_rewards(amount: staker_info.amount_own, :interest);
    let pool_rewards = compute_rewards(amount: staker_info.amount_pool, :interest);
    let commission = compute_commission(
        rewards: pool_rewards, rev_share: cfg.staker_info.rev_share
    );
    let unclaimed_rewards_own: u128 = staker_rewards + commission;
    let unclaimed_rewards_pool: u128 = pool_rewards - commission;
    let expected_staker_info = StakerInfo {
        index: staker_info.index, unclaimed_rewards_own, unclaimed_rewards_pool, ..staker_info
    };
    assert_eq!(staker_info, expected_staker_info);
}

#[test]
fn test_calculate_rewards_unstake_intent() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);

    let mut staker_info = StakerInfo { unstake_time: Option::Some(1), ..cfg.staker_info };
    assert!(!state.calculate_rewards(ref :staker_info));
}

#[test]
#[should_panic(expected: "Staker already exists, use increase_stake instead.")]
fn test_stake_from_same_staker_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);

    // Second stake from cfg.test_info.staker_address.
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: cfg.test_info.staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    state
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.staker_info.amount_own,
            pooling_enabled: cfg.test_info.pooling_enabled,
            rev_share: cfg.staker_info.rev_share,
        );
}

#[test]
#[should_panic(expected: "Operational address already exists.")]
fn test_stake_with_same_operational_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);

    // Change staker address.
    cheat_caller_address(test_address(), OTHER_STAKER_ADDRESS(), CheatSpan::TargetCalls(1));
    assert!(cfg.test_info.staker_address != OTHER_STAKER_ADDRESS());
    // Second stake with the same operational address.
    state
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.staker_info.amount_own,
            pooling_enabled: cfg.test_info.pooling_enabled,
            rev_share: cfg.staker_info.rev_share,
        );
}

#[test]
#[should_panic(expected: "Amount is less than min stake - try again with enough funds.")]
fn test_stake_with_less_than_min_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    cfg.staker_info.amount_own = cfg.staking_contract_info.min_stake - 1;
    stake_for_testing(ref state, :cfg, :token_address);
}

#[test]
#[should_panic(expected: "Rev share is out of range, expected to be 0-10000.")]
fn test_stake_with_rev_share_out_of_range() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    cfg.staker_info.rev_share = REV_SHARE_DENOMINATOR + 1;
    stake_for_testing(ref state, :cfg, :token_address);
}

#[test]
fn test_claim_delegation_pool_rewards() {
    let pooling_contract = POOLING_CONTRACT_ADDRESS();
    let mut cfg: StakingInitConfig = Default::default();
    cfg.staker_info.pooling_contract = Option::Some(pooling_contract);
    // TODO: Set the contract address to the actual pool contract address.
    cfg.test_info.pooling_enabled = true;
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);

    // Update staker info for the test.
    let staker_info = StakerInfo {
        index: 0, amount_pool: cfg.staker_info.amount_own, ..cfg.staker_info
    };
    state.staker_info.write(cfg.test_info.staker_address, Option::Some(staker_info));

    cheat_caller_address(test_address(), pooling_contract, CheatSpan::TargetCalls(1));
    state.claim_delegation_pool_rewards(cfg.test_info.staker_address);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert_eq!(
        erc20_dispatcher.balance_of(pooling_contract),
        (cfg.staker_info.amount_own.into()
            * (REV_SHARE_DENOMINATOR - cfg.staker_info.rev_share).into())
            / REV_SHARE_DENOMINATOR.into()
    );
}

#[test]
fn test_contract_parameters() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    let expected_staking_contract_info = StakingContractInfo {
        min_stake: cfg.staking_contract_info.min_stake,
        token_address: token_address,
        global_index: cfg.staker_info.index,
    };
    assert_eq!(state.contract_parameters(), expected_staking_contract_info);
}

#[test]
fn test_increase_stake_from_staker_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    let staker_address = cfg.test_info.staker_address;
    // Set the same staker address.
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    let staker_info_before = state.get_staker_info(:staker_address);
    let increase_amount = cfg.staker_info.amount_own;
    let expected_staker_info = StakerInfo {
        amount_own: staker_info_before.amount_own + increase_amount, ..staker_info_before
    };
    let mut spy = snforge_std::spy_events();
    // Increase stake from the same staker address.
    state.increase_stake(:staker_address, amount: increase_amount,);

    let updated_staker_info = state.get_staker_info(:staker_address);
    assert_eq!(expected_staker_info, updated_staker_info);

    // Validate the single BalanceChanged event.
    let events = spy.get_events().emitted_by(test_address()).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "increase_stake");
    assert_staker_balance_changed_event(
        spied_event: events[0], :staker_address, amount: expected_staker_info.amount_own
    );
}

#[test]
#[should_panic(expected: "Pool address does not exist.")]
fn test_claim_delegation_pool_rewards_pool_address_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.test_info.pooling_enabled = false;
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staker_address = cfg.test_info.staker_address;
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    state.claim_delegation_pool_rewards(:staker_address);
}


#[test]
#[should_panic(expected: "Caller is not pool contract.")]
fn test_claim_delegation_pool_rewards_unauthorized_address() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.staker_info.pooling_contract = Option::Some(POOLING_CONTRACT_ADDRESS());
    // TODO: Set the contract address to the actual pool contract address.
    cfg.test_info.pooling_enabled = true;
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    let staker_address = cfg.test_info.staker_address;
    // Update staker info for the test.
    let staker_info = StakerInfo { index: 0, ..cfg.staker_info };
    state.staker_info.write(staker_address, Option::Some(staker_info));
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    state.claim_delegation_pool_rewards(:staker_address);
}

#[test]
fn test_increase_stake_from_reward_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);

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
        spender: test_address(),
        amount: cfg.test_info.staker_initial_balance,
        :token_address
    );
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address(test_address(), cfg.staker_info.reward_address, CheatSpan::TargetCalls(1));
    let staker_info_before = state.get_staker_info(:staker_address);
    let increase_amount = cfg.staker_info.amount_own;
    let mut expected_staker_info = staker_info_before;
    expected_staker_info.amount_own += increase_amount;
    state.increase_stake(:staker_address, amount: increase_amount,);
    let updated_staker_info = state.get_staker_info(:staker_address);
    assert_eq!(expected_staker_info, updated_staker_info);
}

#[test]
#[should_panic(expected: "Staker does not exist.")]
fn test_increase_stake_staker_address_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    state.increase_stake(staker_address: NON_STAKER_ADDRESS(), amount: cfg.staker_info.amount_own);
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window.")]
fn test_increase_stake_unstake_in_progress() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staker_address = cfg.test_info.staker_address;
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    state.unstake_intent();
    state.increase_stake(:staker_address, amount: cfg.staker_info.amount_own);
}

#[test]
#[should_panic(expected: "Amount is less than min increase stake - try again with enough funds.")]
fn test_increase_stake_amount_less_than_min_increase_stake() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staker_address = cfg.test_info.staker_address;
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    state.increase_stake(:staker_address, amount: MIN_INCREASE_STAKE - 1);
}

#[test]
#[should_panic(expected: "Caller address should be staker address or reward address.")]
fn test_increase_stake_caller_cannot_increase() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(test_address(), NON_STAKER_ADDRESS(), CheatSpan::TargetCalls(1));
    state
        .increase_stake(
            staker_address: cfg.test_info.staker_address, amount: cfg.staker_info.amount_own
        );
}

#[test]
fn test_change_reward_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staker_address = cfg.test_info.staker_address;
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    let staker_info_before_change = state.get_staker_info(:staker_address);
    let other_reward_address = OTHER_REWARD_ADDRESS();

    // Set the same staker address.
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    state.change_reward_address(other_reward_address);
    let staker_info_after_change = state.get_staker_info(:staker_address);
    let staker_info_expected = StakerInfo {
        reward_address: other_reward_address, ..staker_info_before_change
    };
    assert_eq!(staker_info_after_change, staker_info_expected);
}


#[test]
#[should_panic(expected: "Staker does not exist.")]
fn test_change_reward_address_staker_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(test_address(), NON_STAKER_ADDRESS(), CheatSpan::TargetCalls(1));
    // Reward address is arbitrary because it should fail because of the caller.
    state.change_reward_address(reward_address: DUMMY_ADDRESS());
}


#[test]
fn test_claim_rewards() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);

    // update index
    state.global_index.write((cfg.staker_info.index).into() * 2);
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    let reward: u128 = state.claim_rewards(:staker_address);
    assert_eq!(reward, cfg.staker_info.amount_own);

    let new_staker_info = state.get_staker_info(:staker_address);
    assert_eq!(new_staker_info.unclaimed_rewards_own, 0);
    assert_eq!(new_staker_info.index, 2 * cfg.staker_info.index,);

    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = erc20_dispatcher.balance_of(cfg.staker_info.reward_address);
    assert_eq!(balance, reward.into());
}

#[test]
#[should_panic(expected: ("Claim rewards must be called from staker address or reward address.",))]
fn test_claim_rewards_panic_unauthorized() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(test_address(), DUMMY_ADDRESS(), CheatSpan::TargetCalls(1));
    state.claim_rewards(cfg.test_info.staker_address);
}


#[test]
#[should_panic(expected: ("Staker does not exist.",))]
fn test_claim_rewards_panic_staker_doesnt_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    state.claim_rewards(DUMMY_ADDRESS());
}

#[test]
fn test_unstake_intent() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staker_address = cfg.test_info.staker_address;
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    let mut spy = snforge_std::spy_events();
    let unstake_time = state.unstake_intent();
    let staker_info = state.get_staker_info(:staker_address);
    let expected_time = get_block_timestamp() + EXIT_WAITING_WINDOW;
    assert_eq!((staker_info.unstake_time).unwrap(), unstake_time);
    assert_eq!(unstake_time, expected_time);
    // Validate the single StakerExitIntent event.
    let events = spy.get_events().emitted_by(test_address()).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "unstake_intent");
    assert_staker_exit_intent_event(
        spied_event: events[0], :staker_address, exit_at: expected_time
    );
}

#[test]
#[should_panic(expected: ("Staker does not exist.",))]
fn test_unstake_intent_staker_doesnt_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    cheat_caller_address(test_address(), NON_STAKER_ADDRESS(), CheatSpan::TargetCalls(1));
    state.unstake_intent();
}

#[test]
#[should_panic(expected: "Unstake is in progress, staker is in an exit window.")]
fn test_unstake_intent_unstake_in_progress() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(2));
    state.unstake_intent();
    state.unstake_intent();
}

// TODO: test event.
#[test]
fn test_unstake_action() {
    let cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    stake_with_pooling_enabled(:cfg, :token_address, :staking_contract);

    let staker_address = cfg.test_info.staker_address;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    let unstake_time = staking_dispatcher.unstake_intent();
    // Advance time to enable unstake_action.
    cheat_block_timestamp(
        contract_address: staking_contract,
        block_timestamp: unstake_time + 1,
        span: CheatSpan::Indefinite
    );
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: NON_STAKER_ADDRESS(),
        span: CheatSpan::TargetCalls(1)
    );
    let staker_amount = staking_dispatcher.unstake_action(:staker_address);
    assert_eq!(staker_amount, cfg.staker_info.amount_own);
    let actual_staker_info: Option<StakerInfo> = load_option_from_simple_map(
        map_selector: selector!("staker_info"), key: staker_address, contract: staking_contract
    );
    assert!(actual_staker_info.is_none());
}

// TODO: test unstake_action.

#[test]
fn test_get_total_stake() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);
    assert_eq!(state.get_total_stake(), 0);
    stake_for_testing(ref state, :cfg, :token_address);
    assert_eq!(state.get_total_stake(), cfg.staker_info.amount_own);
    // Set the same staker address.
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address(
        contract_address: test_address(),
        caller_address: staker_address,
        span: CheatSpan::TargetCalls(1)
    );
    let amount = cfg.staker_info.amount_own;
    state.increase_stake(:staker_address, :amount,);
    assert_eq!(state.get_total_stake(), state.get_staker_info(:staker_address).amount_own);
}

#[test]
fn test_stake_pooling_enabled() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );

    let mut state = initialize_staking_state_from_cfg(:token_address, :cfg);

    // Stake with pooling enabled.
    cfg.test_info.pooling_enabled = true;
    stake_for_testing(ref state, :cfg, :token_address);
    let staker_address = cfg.test_info.staker_address;
    // Read and set pool contract address.
    // TODO: If used again, add the following logic (at least partly) to a function.
    cfg.staker_info.pooling_contract = state.get_staker_info(:staker_address).pooling_contract;
    let expected_staker_info = cfg.staker_info;
    // Check that the staker info was updated correctly.
    assert_eq!(expected_staker_info, state.get_staker_info(:staker_address));
}

// TODO: Create tests that cover all panic scenarios for add_to_delegation_pool.
// TODO: Implement the following test.
//       Note: The happy flow is also tested in test_enter_delegation_pool.
//       in pooling/test.cairo.      
#[test]
fn test_add_to_delegation_pool() {
    assert!(true);
}

// TODO: Create tests that cover all panic scenarios for remove_from_delegation_pool_intent.
// TODO: Implement the following test.
//       Note: The happy flow is also tested in test_exit_delegation_pool_intent.
//       in pooling/test.cairo.      
#[test]
fn test_remove_from_delegation_pool_intent() {
    assert!(true);
}
