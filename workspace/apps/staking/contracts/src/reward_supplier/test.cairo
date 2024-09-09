use core::option::OptionTrait;
use contracts::reward_supplier::interface::{IRewardSupplier, RewardSupplierStatus};
use contracts::reward_supplier::interface::IRewardSupplierDispatcher;
use contracts::reward_supplier::interface::IRewardSupplierDispatcherTrait;
use starknet::get_block_timestamp;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use contracts::test_utils;
use contracts::test_utils::constants::NOT_STARKGATE_ADDRESS;
use test_utils::{deploy_mock_erc20_contract, StakingInitConfig, deploy_staking_contract};
use test_utils::{stake_for_testing_using_dispatcher, initialize_reward_supplier_state_from_cfg};
use test_utils::{deploy_minting_curve_contract, fund, general_contract_system_deployment};
use contracts::reward_supplier::RewardSupplier::SECONDS_IN_YEAR;
use snforge_std::{start_cheat_block_timestamp_global, test_address};
use core::num::traits::{Zero, Sqrt};
use contracts_commons::test_utils::{cheat_caller_address_once};
use contracts::utils::{ceil_of_division, compute_threshold};
use contracts::event_test_utils::assert_calculated_rewards_event;
use contracts::event_test_utils::{assert_number_of_events, assert_mint_request_event};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::cheatcodes::message_to_l1::{spy_messages_to_l1, MessageToL1};
use snforge_std::cheatcodes::message_to_l1::MessageToL1SpyAssertionsTrait;
use contracts::constants::STRK_IN_FRIS;

#[test]
fn test_reward_supplier_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    cfg.test_info.staking_contract = staking_contract;
    let state = @initialize_reward_supplier_state_from_cfg(:token_address, :cfg);
    assert_eq!(state.staking_contract.read(), cfg.test_info.staking_contract);
    assert_eq!(state.erc20_dispatcher.read().contract_address, token_address);
    assert_eq!(state.l1_pending_requested_amount.read(), Zero::zero());
    assert_eq!(state.base_mint_amount.read(), cfg.reward_supplier.base_mint_amount);
    assert_eq!(state.base_mint_msg.read(), cfg.reward_supplier.base_mint_msg);
    assert_eq!(
        state.minting_curve_dispatcher.read().contract_address,
        cfg.reward_supplier.minting_curve_contract
    );
    assert_eq!(state.l1_staking_minter.read(), cfg.reward_supplier.l1_staking_minter);
    assert_eq!(state.last_timestamp.read(), get_block_timestamp());
    assert_eq!(state.unclaimed_rewards.read(), STRK_IN_FRIS);
}

#[test]
fn test_claim_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract and stake.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    cfg.test_info.staking_contract = staking_contract;
    let amount = (cfg.test_info.initial_supply / 2).try_into().expect('amount does not fit in');
    cfg.test_info.staker_initial_balance = amount;
    cfg.staker_info.amount_own = amount;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    // Deploy the minting curve contract.
    let minting_curve_contract = deploy_minting_curve_contract(:cfg);
    cfg.reward_supplier.minting_curve_contract = minting_curve_contract;
    // Use the reward supplier contract state to claim rewards.
    let mut state = initialize_reward_supplier_state_from_cfg(:token_address, :cfg);
    // Fund the the reward supplier contract.
    fund(sender: cfg.test_info.owner_address, recipient: test_address(), :amount, :token_address);
    // Update the unclaimed rewards for testing purposes.
    state.unclaimed_rewards.write(amount);
    // Claim the rewards from the reward supplier contract.
    cheat_caller_address_once(contract_address: test_address(), caller_address: staking_contract);
    state.claim_rewards(:amount);
    // Validate that the rewards were claimed.
    assert_eq!(state.unclaimed_rewards.read(), Zero::zero());
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_balance = erc20_dispatcher.balance_of(account: staking_contract);
    assert_eq!(staking_balance, amount.into() * 2);
    let reward_supplier_balance = erc20_dispatcher.balance_of(account: test_address());
    assert_eq!(reward_supplier_balance, Zero::zero());
}

#[test]
fn test_calculate_staking_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract and stake.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    cfg.test_info.staking_contract = staking_contract;
    let amount = (cfg.test_info.initial_supply / 2).try_into().expect('amount does not fit in');
    cfg.test_info.staker_initial_balance = amount;
    cfg.staker_info.amount_own = amount;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    // Deploy the minting curve contract.
    let minting_curve_contract = deploy_minting_curve_contract(:cfg);
    cfg.reward_supplier.minting_curve_contract = minting_curve_contract;
    // Use the reward supplier contract state to claim rewards.
    let mut state = initialize_reward_supplier_state_from_cfg(:token_address, :cfg);
    let last_timestamp = state.last_timestamp.read();
    // Fund the the reward supplier contract.
    let balance = 1000;
    fund(
        sender: cfg.test_info.owner_address,
        recipient: test_address(),
        amount: balance,
        :token_address
    );
    start_cheat_block_timestamp_global(
        block_timestamp: get_block_timestamp()
            + SECONDS_IN_YEAR.try_into().expect('does not fit in')
    );
    cheat_caller_address_once(contract_address: test_address(), caller_address: staking_contract);
    let mut spy = snforge_std::spy_events();
    let mut msgs_to_l1 = spy_messages_to_l1();
    let rewards = state.calculate_staking_rewards();
    // Validate the rewards, unclaimed rewards and l1_pending_requested_amount.
    let unadjusted_expected_rewards: u128 = (cfg.test_info.initial_supply * amount.into()).sqrt();
    // Multiply by max inflation.
    let expected_rewards = cfg.minting_curve_contract_info.c_num.into()
        * unadjusted_expected_rewards
        / cfg.minting_curve_contract_info.c_denom.into();
    assert_eq!(rewards, expected_rewards);
    let expected_unclaimed_rewards = rewards + STRK_IN_FRIS;
    assert_eq!(state.unclaimed_rewards.read(), expected_unclaimed_rewards);
    let base_mint_amount = cfg.reward_supplier.base_mint_amount;
    let diff = expected_unclaimed_rewards + compute_threshold(base_mint_amount) - balance;
    let num_msgs = ceil_of_division(dividend: diff, divisor: base_mint_amount);
    let expected_l1_pending_requested_amount = num_msgs * base_mint_amount;
    assert_eq!(state.l1_pending_requested_amount.read(), expected_l1_pending_requested_amount);
    // Validate MintRequest and CalculatedRewards events.
    let events = spy.get_events().emitted_by(contract_address: test_address()).events;
    assert_number_of_events(
        actual: events.len(), expected: 2, message: "calculate_staking_rewards"
    );
    assert_mint_request_event(
        spied_event: events[0], total_amount: expected_l1_pending_requested_amount, :num_msgs
    );
    assert_calculated_rewards_event(
        spied_event: events[1],
        :last_timestamp,
        new_timestamp: state.last_timestamp.read(),
        rewards_calculated: rewards,
    );
    msgs_to_l1
        .assert_sent(
            messages: @array![
                (
                    test_address(),
                    MessageToL1 {
                        to_address: cfg
                            .reward_supplier
                            .l1_staking_minter
                            .try_into()
                            .expect('not EthAddress'),
                        payload: array![base_mint_amount.into()]
                    }
                )
            ]
        );
}

#[test]
fn test_state_of() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Change the block_timestamp so the state_of() won't return zero for all fields.
    let block_timestamp = get_block_timestamp() + 1;
    start_cheat_block_timestamp_global(:block_timestamp);
    let state = initialize_reward_supplier_state_from_cfg(:token_address, :cfg);
    let expected_status = RewardSupplierStatus {
        last_timestamp: block_timestamp,
        unclaimed_rewards: STRK_IN_FRIS,
        l1_pending_requested_amount: Zero::zero(),
    };
    assert_eq!(state.state_of(), expected_status);
}

#[test]
fn test_on_receive() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.test_info.initial_supply *= 1000;
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier_contract = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier_contract
    };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let balance = Zero::zero();
    let credit = balance + reward_supplier_dispatcher.state_of().l1_pending_requested_amount;
    start_cheat_block_timestamp_global(
        block_timestamp: get_block_timestamp()
            + SECONDS_IN_YEAR.try_into().expect('does not fit in')
    );
    cheat_caller_address_once(
        contract_address: reward_supplier_contract, caller_address: staking_contract
    );
    let rewards = reward_supplier_dispatcher.calculate_staking_rewards();
    let unclaimed_rewards = rewards + STRK_IN_FRIS;
    let base_mint_amount = cfg.reward_supplier.base_mint_amount;
    let debit = unclaimed_rewards;
    let threshold = compute_threshold(base_mint_amount);
    let diff = debit + threshold - credit;
    let num_msgs = ceil_of_division(dividend: diff, divisor: base_mint_amount);
    let mut expected_l1_pending_requested_amount = num_msgs * base_mint_amount;
    assert_eq!(
        reward_supplier_dispatcher.state_of().l1_pending_requested_amount,
        expected_l1_pending_requested_amount
    );
    for _ in 0
        ..num_msgs {
            // Transfer base_mint_amount to the reward supplier contract as it received from l1
            // staking minter.
            fund(
                sender: cfg.test_info.owner_address,
                recipient: reward_supplier_contract,
                amount: base_mint_amount,
                :token_address
            );
            cheat_caller_address_once(
                contract_address: reward_supplier_contract,
                caller_address: cfg.reward_supplier.starkgate_address
            );
            reward_supplier_dispatcher
                .on_receive(
                    l2_token: token_address,
                    amount: base_mint_amount.into(),
                    depositor: cfg
                        .reward_supplier
                        .l1_staking_minter
                        .try_into()
                        .expect('not EthAddress'),
                    message: array![].span()
                );
            expected_l1_pending_requested_amount -= base_mint_amount;
            assert_eq!(
                reward_supplier_dispatcher.state_of().l1_pending_requested_amount,
                expected_l1_pending_requested_amount
            );
        };
}

#[test]
#[should_panic(expected: "Only StarkGate can call on_receive.")]
fn test_on_receive_caller_not_starkgate() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier_contract = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier_contract
    };
    cheat_caller_address_once(
        contract_address: reward_supplier_contract, caller_address: NOT_STARKGATE_ADDRESS()
    );
    reward_supplier_dispatcher
        .on_receive(
            l2_token: cfg.staking_contract_info.token_address,
            amount: cfg.reward_supplier.base_mint_amount.into(),
            depositor: cfg.reward_supplier.l1_staking_minter.try_into().expect('not EthAddress'),
            message: array![].span()
        );
}
