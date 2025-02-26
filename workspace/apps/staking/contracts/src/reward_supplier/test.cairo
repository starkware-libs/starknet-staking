use MintingCurve::{
    CONTRACT_IDENTITY as mint_curve_identity, CONTRACT_VERSION as mint_curve_version,
};
use Pool::{CONTRACT_IDENTITY as pool_identity, CONTRACT_VERSION as pool_version};
use RewardSupplier::{
    CONTRACT_IDENTITY as reward_supplier_identity, CONTRACT_VERSION as reward_supplier_version,
};
use Staking::{CONTRACT_IDENTITY as staking_identity, CONTRACT_VERSION as staking_version};
use contracts_commons::errors::Describable;
use contracts_commons::math::utils::ceil_of_division;
use contracts_commons::test_utils::{
    assert_panic_with_error, cheat_caller_address_once, check_identity,
};
use contracts_commons::types::time::time::Time;
use core::num::traits::{Sqrt, Zero};
use core::option::OptionTrait;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::cheatcodes::message_to_l1::{
    MessageToL1, MessageToL1SpyAssertionsTrait, spy_messages_to_l1,
};
use snforge_std::{start_cheat_block_timestamp_global, test_address};
use staking::constants::STRK_IN_FRIS;
use staking::errors::GenericError;
use staking::event_test_utils::{
    assert_calculated_rewards_event, assert_mint_request_event, assert_number_of_events,
};
use staking::minting_curve::interface::{IMintingCurveDispatcher, IMintingCurveDispatcherTrait};
use staking::minting_curve::minting_curve::MintingCurve;
use staking::pool::pool::Pool;
use staking::reward_supplier::interface::{
    IRewardSupplier, IRewardSupplierDispatcher, IRewardSupplierDispatcherTrait,
    IRewardSupplierSafeDispatcher, IRewardSupplierSafeDispatcherTrait, RewardSupplierInfo,
};
use staking::reward_supplier::reward_supplier::RewardSupplier;
use staking::staking::objects::EpochInfoTrait;
use staking::staking::staking::Staking;
use staking::test_utils;
use staking::test_utils::constants::{NOT_STAKING_CONTRACT_ADDRESS, NOT_STARKGATE_ADDRESS};
use staking::types::Amount;
use staking::utils::compute_threshold;
use starknet::Store;
use test_utils::{
    StakingInitConfig, deploy_minting_curve_contract, deploy_mock_erc20_contract,
    deploy_staking_contract, fund, general_contract_system_deployment,
    initialize_reward_supplier_state_from_cfg, stake_for_testing_using_dispatcher,
};


#[test]
fn test_identity() {
    assert_eq!(staking_identity, 'Staking Core Contract');
    assert_eq!(reward_supplier_identity, 'Reward Supplier');
    assert_eq!(mint_curve_identity, 'Minting Curve');
    assert_eq!(pool_identity, 'Staking Delegation Pool');

    assert_eq!(staking_version, '1.0.0');
    assert_eq!(reward_supplier_version, '1.0.0');
    assert_eq!(mint_curve_version, '1.0.0');
    assert_eq!(pool_version, '1.0.0');

    // Test identity on deployed instances.
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);

    let minting_curve = cfg.reward_supplier.minting_curve_contract;
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let staking = cfg.test_info.staking_contract;

    check_identity(staking, staking_identity, staking_version);
    check_identity(reward_supplier, reward_supplier_identity, reward_supplier_version);
    check_identity(minting_curve, mint_curve_identity, mint_curve_version);
    // Pool contract identity checked elsewhere.
}

#[test]
fn test_reward_supplier_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    cfg.test_info.staking_contract = staking_contract;
    let state = @initialize_reward_supplier_state_from_cfg(:token_address, :cfg);
    assert_eq!(state.staking_contract.read(), cfg.test_info.staking_contract);
    assert_eq!(state.token_dispatcher.read().contract_address, token_address);
    assert_eq!(state.l1_pending_requested_amount.read(), Zero::zero());
    assert_eq!(state.base_mint_amount.read(), cfg.reward_supplier.base_mint_amount);
    assert_eq!(
        state.minting_curve_dispatcher.read().contract_address,
        cfg.reward_supplier.minting_curve_contract,
    );
    assert_eq!(state.l1_reward_supplier.read(), cfg.reward_supplier.l1_reward_supplier);
    assert_eq!(state.last_timestamp.read(), Time::now());
    assert_eq!(state.unclaimed_rewards.read(), STRK_IN_FRIS);
}

#[test]
fn test_claim_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy the staking contract and stake.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    cfg.test_info.staking_contract = staking_contract;
    let amount = (cfg.test_info.initial_supply / 2).try_into().expect('amount does not fit in');
    cfg.test_info.staker_initial_balance = amount;
    cfg.staker_info._deprecated_amount_own = amount;
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
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_balance = token_dispatcher.balance_of(account: staking_contract);
    assert_eq!(staking_balance, amount.into() * 2);
    let reward_supplier_balance = token_dispatcher.balance_of(account: test_address());
    assert_eq!(reward_supplier_balance, Zero::zero());
}

#[test]
fn test_calculate_staking_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Deploy the staking contract and stake.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    cfg.test_info.staking_contract = staking_contract;
    let amount = (cfg.test_info.initial_supply / 2).try_into().expect('amount does not fit in');
    cfg.test_info.staker_initial_balance = amount;
    cfg.staker_info._deprecated_amount_own = amount;
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
        :token_address,
    );
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 365)).into(),
    );
    cheat_caller_address_once(contract_address: test_address(), caller_address: staking_contract);
    let mut spy = snforge_std::spy_events();
    let mut msgs_to_l1 = spy_messages_to_l1();
    let rewards = state.calculate_staking_rewards();
    // Validate the rewards, unclaimed rewards and l1_pending_requested_amount.
    let unadjusted_expected_rewards: Amount = (cfg.test_info.initial_supply * amount.into()).sqrt();
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
        actual: events.len(), expected: 2, message: "calculate_staking_rewards",
    );
    assert_mint_request_event(
        spied_event: events[0], total_amount: expected_l1_pending_requested_amount, :num_msgs,
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
                            .l1_reward_supplier
                            .try_into()
                            .expect('not EthAddress'),
                        payload: array![base_mint_amount.into()],
                    },
                ),
            ],
        );
}

#[test]
#[should_panic(expected: "Caller is not staking contract")]
fn test_calculate_staking_rewards_caller_not_staking() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier_contract = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier_contract,
    };
    let not_staking_contract = NOT_STAKING_CONTRACT_ADDRESS();
    cheat_caller_address_once(
        contract_address: reward_supplier_contract, caller_address: not_staking_contract,
    );
    reward_supplier_dispatcher.calculate_staking_rewards();
}

#[test]
fn test_contract_parameters() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    // Change the block_timestamp so the contract_parameters() won't return zero for all fields.
    let block_timestamp = Time::now().add(delta: Time::seconds(count: 1));
    start_cheat_block_timestamp_global(block_timestamp: block_timestamp.into());
    let state = initialize_reward_supplier_state_from_cfg(:token_address, :cfg);
    let expected_info = RewardSupplierInfo {
        last_timestamp: block_timestamp,
        unclaimed_rewards: STRK_IN_FRIS,
        l1_pending_requested_amount: Zero::zero(),
    };
    assert_eq!(state.contract_parameters(), expected_info);
}

#[test]
fn test_on_receive() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier_contract = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier_contract,
    };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let balance = Zero::zero();
    let credit = balance
        + reward_supplier_dispatcher.contract_parameters().l1_pending_requested_amount;
    start_cheat_block_timestamp_global(
        block_timestamp: Time::now().add(delta: Time::days(count: 365)).into(),
    );
    cheat_caller_address_once(
        contract_address: reward_supplier_contract, caller_address: staking_contract,
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
        reward_supplier_dispatcher.contract_parameters().l1_pending_requested_amount,
        expected_l1_pending_requested_amount,
    );
    for _ in 0..num_msgs {
        cheat_caller_address_once(
            contract_address: reward_supplier_contract,
            caller_address: cfg.reward_supplier.starkgate_address,
        );
        assert!(
            reward_supplier_dispatcher
                .on_receive(
                    l2_token: token_address,
                    amount: base_mint_amount.into(),
                    depositor: cfg
                        .reward_supplier
                        .l1_reward_supplier
                        .try_into()
                        .expect('not EthAddress'),
                    message: array![].span(),
                ),
        );
        expected_l1_pending_requested_amount -= base_mint_amount;
        assert_eq!(
            reward_supplier_dispatcher.contract_parameters().l1_pending_requested_amount,
            expected_l1_pending_requested_amount,
        );
    };

    // One more time to cover an amount that's bigger than requested amount.
    cheat_caller_address_once(
        contract_address: reward_supplier_contract,
        caller_address: cfg.reward_supplier.starkgate_address,
    );
    assert!(
        reward_supplier_dispatcher
            .on_receive(
                l2_token: token_address,
                amount: 10 * base_mint_amount.into(),
                depositor: cfg
                    .reward_supplier
                    .l1_reward_supplier
                    .try_into()
                    .expect('not EthAddress'),
                message: array![].span(),
            ),
    );
    assert_eq!(
        reward_supplier_dispatcher.contract_parameters().l1_pending_requested_amount, Zero::zero(),
    );
}

#[test]
#[should_panic(expected: "Only StarkGate can call on_receive")]
fn test_on_receive_caller_not_starkgate() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier_contract = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier_contract,
    };
    cheat_caller_address_once(
        contract_address: reward_supplier_contract, caller_address: NOT_STARKGATE_ADDRESS(),
    );
    reward_supplier_dispatcher
        .on_receive(
            l2_token: cfg.staking_contract_info.token_address,
            amount: cfg.reward_supplier.base_mint_amount.into(),
            depositor: cfg.reward_supplier.l1_reward_supplier.try_into().expect('not EthAddress'),
            message: array![].span(),
        );
}

#[test]
#[should_panic(expected: "UNEXPECTED_TOKEN")]
fn test_on_receive_unexpected_token() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier_contract = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier_contract,
    };
    cheat_caller_address_once(
        contract_address: reward_supplier_contract,
        caller_address: cfg.reward_supplier.starkgate_address,
    );

    // We assign a different address to the l2_token field.
    let not_l2_token = cfg.reward_supplier.minting_curve_contract;
    reward_supplier_dispatcher
        .on_receive(
            l2_token: not_l2_token,
            amount: cfg.reward_supplier.base_mint_amount.into(),
            depositor: cfg.reward_supplier.l1_reward_supplier.try_into().expect('not EthAddress'),
            message: array![].span(),
        );
}

#[test]
#[feature("safe_dispatcher")]
fn test_claim_rewards_assertions() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_safe_dispatcher = IRewardSupplierSafeDispatcher {
        contract_address: reward_supplier,
    };

    // Catch CALLER_IS_NOT_STAKING_CONTRACT.
    let not_staking_contract = NOT_STAKING_CONTRACT_ADDRESS();
    let amount = Zero::zero();
    cheat_caller_address_once(
        contract_address: reward_supplier, caller_address: not_staking_contract,
    );
    let result = reward_supplier_safe_dispatcher.claim_rewards(:amount);
    assert_panic_with_error(
        :result, expected_error: GenericError::CALLER_IS_NOT_STAKING_CONTRACT.describe(),
    );

    // Catch AMOUNT_TOO_HIGH.
    let staking_contract = cfg.test_info.staking_contract;
    let amount = STRK_IN_FRIS + 1;
    cheat_caller_address_once(contract_address: reward_supplier, caller_address: staking_contract);
    let result = reward_supplier_safe_dispatcher.claim_rewards(:amount);
    assert_panic_with_error(:result, expected_error: GenericError::AMOUNT_TOO_HIGH.describe());
}

#[test]
fn test_current_epoch_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier,
    };
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: cfg.reward_supplier.minting_curve_contract,
    };
    let yearly_mint = minting_curve_dispatcher.yearly_mint();
    let rewards = reward_supplier_dispatcher.current_epoch_rewards();

    // Expected rewards are computed by dividing the yearly mint by the number of epochs in a year.
    let epochs_in_year = cfg.staking_contract_info.epoch_info.epochs_in_year();
    let expected_rewards = yearly_mint / epochs_in_year.into();
    assert_eq!(rewards, expected_rewards);
}

#[test]
fn test_update_unclaimed_rewards_from_staking_contract() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier,
    };
    let mut spy = snforge_std::spy_events();
    let staking_contract = cfg.test_info.staking_contract;
    let amount = STRK_IN_FRIS;
    let unclaimed_rewards_before = *snforge_std::load(
        target: reward_supplier,
        storage_address: selector!("unclaimed_rewards"),
        size: Store::<Amount>::size().into(),
    )
        .at(0);
    cheat_caller_address_once(contract_address: reward_supplier, caller_address: staking_contract);
    reward_supplier_dispatcher.update_unclaimed_rewards_from_staking_contract(rewards: amount);
    let unclaimed_rewards_after = *snforge_std::load(
        target: reward_supplier,
        storage_address: selector!("unclaimed_rewards"),
        size: Store::<Amount>::size().into(),
    )
        .at(0);
    assert_eq!(unclaimed_rewards_after, unclaimed_rewards_before + amount.into());
    // Asserts events, the only one is the mint request.
    let events = spy.get_events().emitted_by(contract_address: reward_supplier).events;
    assert_number_of_events(
        actual: events.len(),
        expected: 1,
        message: "update_unclaimed_rewards_from_staking_contract",
    );
}

#[test]
#[should_panic(expected: "Caller is not staking contract")]
fn test_update_unclaimed_rewards_from_staking_contract_caller_not_staking() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier,
    };
    let not_staking_contract = NOT_STAKING_CONTRACT_ADDRESS();
    cheat_caller_address_once(
        contract_address: reward_supplier, caller_address: not_staking_contract,
    );
    reward_supplier_dispatcher
        .update_unclaimed_rewards_from_staking_contract(rewards: STRK_IN_FRIS);
}
