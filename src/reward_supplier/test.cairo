use RewardSupplier::{
    CONTRACT_IDENTITY as reward_supplier_identity, CONTRACT_VERSION as reward_supplier_version,
};
use core::num::traits::Zero;
use core::option::OptionTrait;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use snforge_std::{TokenTrait, start_cheat_block_timestamp_global, test_address};
use staking::constants::{ALPHA, ALPHA_DENOMINATOR, STRK_IN_FRIS};
use staking::errors::GenericError;
use staking::minting_curve::interface::{IMintingCurveDispatcher, IMintingCurveDispatcherTrait};
use staking::reward_supplier::interface::{
    IRewardSupplier, IRewardSupplierDispatcher, IRewardSupplierDispatcherTrait,
    IRewardSupplierSafeDispatcher, IRewardSupplierSafeDispatcherTrait, RewardSupplierInfoV1,
};
use staking::reward_supplier::reward_supplier::RewardSupplier;
use staking::reward_supplier::utils::compute_threshold;
use staking::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use staking::staking::objects::EpochInfoTrait;
use staking::test_utils;
use staking::test_utils::constants::{NOT_STAKING_CONTRACT_ADDRESS, NOT_STARKGATE_ADDRESS};
use staking::types::Amount;
use starknet::{ContractAddress, Store};
use starkware_utils::errors::Describable;
use starkware_utils::math::utils::{ceil_of_division, mul_wide_and_div};
use starkware_utils::time::time::Time;
use starkware_utils_testing::event_test_utils::assert_number_of_events;
use starkware_utils_testing::test_utils::{
    assert_panic_with_error, cheat_caller_address_once, check_identity,
};
use test_utils::{
    StakingInitConfig, advance_epoch_global, fund, general_contract_system_deployment,
    initialize_reward_supplier_state_from_cfg, load_one_felt, stake_for_testing_using_dispatcher,
};


#[test]
fn test_identity() {
    assert!(reward_supplier_identity == 'Reward Supplier');
    assert!(reward_supplier_version == '3.0.0');

    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    check_identity(reward_supplier, reward_supplier_identity, reward_supplier_version);
}

#[test]
fn test_reward_supplier_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier,
    };
    let contract_parameters = reward_supplier_dispatcher.contract_parameters_v1();
    let staking_contract: ContractAddress = load_one_felt(
        target: reward_supplier, storage_address: selector!("staking_contract"),
    )
        .try_into()
        .unwrap();
    let token_address: ContractAddress = load_one_felt(
        target: reward_supplier, storage_address: selector!("token_dispatcher"),
    )
        .try_into()
        .unwrap();
    let base_mint_amount: Amount = load_one_felt(
        target: reward_supplier, storage_address: selector!("base_mint_amount"),
    )
        .try_into()
        .unwrap();
    let minting_curve_contract: ContractAddress = load_one_felt(
        target: reward_supplier, storage_address: selector!("minting_curve_dispatcher"),
    )
        .try_into()
        .unwrap();
    let l1_reward_supplier = load_one_felt(
        target: reward_supplier, storage_address: selector!("l1_reward_supplier"),
    );
    assert!(staking_contract == cfg.test_info.staking_contract);
    assert!(token_address == cfg.test_info.strk_token.contract_address());
    assert!(contract_parameters.l1_pending_requested_amount == Zero::zero());
    assert!(base_mint_amount == cfg.reward_supplier.base_mint_amount);
    assert!(minting_curve_contract == cfg.reward_supplier.minting_curve_contract);
    assert!(l1_reward_supplier == cfg.reward_supplier.l1_reward_supplier);
    assert!(contract_parameters.unclaimed_rewards == STRK_IN_FRIS);
}

#[test]
fn test_claim_rewards() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token = cfg.test_info.strk_token;
    let token_address = token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier,
    };
    let amount = cfg.test_info.stake_amount;
    stake_for_testing_using_dispatcher(:cfg);
    // Fund the the reward supplier contract.
    fund(target: reward_supplier, :amount, :token);
    // Update the unclaimed rewards for testing purposes.
    snforge_std::store(
        target: reward_supplier,
        storage_address: selector!("unclaimed_rewards"),
        serialized_value: [amount.into()].span(),
    );
    // Claim the rewards from the reward supplier contract.
    cheat_caller_address_once(contract_address: reward_supplier, caller_address: staking_contract);
    reward_supplier_dispatcher.claim_rewards(:amount);
    // Validate that the rewards were claimed.
    let contract_parameters = reward_supplier_dispatcher.contract_parameters_v1();
    assert!(contract_parameters.unclaimed_rewards == Zero::zero());
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_balance = token_dispatcher.balance_of(account: staking_contract);
    assert!(staking_balance == amount.into() * 2);
    let reward_supplier_balance = token_dispatcher.balance_of(account: test_address());
    assert!(reward_supplier_balance == Zero::zero());
}

#[test]
fn test_contract_parameters_v1() {
    let mut cfg: StakingInitConfig = Default::default();
    // Change the block_timestamp so the contract_parameters_v1() won't return zero for all fields.
    let block_timestamp = Time::now().add(delta: Time::seconds(count: 1));
    start_cheat_block_timestamp_global(block_timestamp: block_timestamp.into());
    let state = initialize_reward_supplier_state_from_cfg(:cfg);
    let expected_info = RewardSupplierInfoV1 {
        unclaimed_rewards: STRK_IN_FRIS, l1_pending_requested_amount: Zero::zero(),
    };
    assert!(state.contract_parameters_v1() == expected_info);
}

#[test]
fn test_on_receive() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let reward_supplier_contract = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier_contract,
    };
    stake_for_testing_using_dispatcher(:cfg);
    let balance = Zero::zero();
    let credit = balance
        + reward_supplier_dispatcher.contract_parameters_v1().l1_pending_requested_amount;
    let epochs_in_year = staking_dispatcher.get_epoch_info().epochs_in_year();
    advance_epoch_global();
    cheat_caller_address_once(
        contract_address: reward_supplier_contract, caller_address: staking_contract,
    );
    let (strk_rewards, _) = reward_supplier_dispatcher.calculate_current_epoch_rewards();
    let rewards = strk_rewards * epochs_in_year.into();
    cheat_caller_address_once(
        contract_address: reward_supplier_contract, caller_address: staking_contract,
    );
    reward_supplier_dispatcher.update_unclaimed_rewards_from_staking_contract(:rewards);
    let unclaimed_rewards = rewards + STRK_IN_FRIS;
    let base_mint_amount = cfg.reward_supplier.base_mint_amount;
    let debit = unclaimed_rewards;
    let threshold = compute_threshold(base_mint_amount);
    let diff = debit + threshold - credit;
    let num_msgs = ceil_of_division(dividend: diff, divisor: base_mint_amount);
    let mut expected_l1_pending_requested_amount = num_msgs * base_mint_amount;
    assert!(
        reward_supplier_dispatcher
            .contract_parameters_v1()
            .l1_pending_requested_amount == expected_l1_pending_requested_amount,
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
        assert!(
            reward_supplier_dispatcher
                .contract_parameters_v1()
                .l1_pending_requested_amount == expected_l1_pending_requested_amount,
        );
    }

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
    assert!(
        reward_supplier_dispatcher
            .contract_parameters_v1()
            .l1_pending_requested_amount == Zero::zero(),
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
        contract_address: reward_supplier_contract, caller_address: NOT_STARKGATE_ADDRESS,
    );
    reward_supplier_dispatcher
        .on_receive(
            l2_token: cfg.test_info.strk_token.contract_address(),
            amount: cfg.reward_supplier.base_mint_amount.into(),
            depositor: cfg.reward_supplier.l1_reward_supplier.try_into().expect('not EthAddress'),
            message: array![].span(),
        );
}

#[test]
#[should_panic(expected: "Unexpected token")]
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
    let not_staking_contract = NOT_STAKING_CONTRACT_ADDRESS;
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
fn test_calculate_current_epoch_rewards() {
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
    let (strk_rewards, btc_rewards) = reward_supplier_dispatcher.calculate_current_epoch_rewards();

    // Expected rewards are computed by dividing the yearly mint by the number of epochs in a year.
    let epochs_in_year = cfg.staking_contract_info.epoch_info.epochs_in_year();
    let expected_rewards = yearly_mint / epochs_in_year.into();
    let expected_btc_rewards = mul_wide_and_div(
        lhs: expected_rewards, rhs: ALPHA, div: ALPHA_DENOMINATOR,
    )
        .unwrap();
    let expected_strk_rewards = expected_rewards - expected_btc_rewards;
    assert!(strk_rewards == expected_strk_rewards);
    assert!(btc_rewards == expected_btc_rewards);
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
    assert!(unclaimed_rewards_after == unclaimed_rewards_before + amount.into());
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
    let not_staking_contract = NOT_STAKING_CONTRACT_ADDRESS;
    cheat_caller_address_once(
        contract_address: reward_supplier, caller_address: not_staking_contract,
    );
    reward_supplier_dispatcher
        .update_unclaimed_rewards_from_staking_contract(rewards: STRK_IN_FRIS);
}

#[test]
fn test_get_alpha() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let reward_supplier = cfg.staking_contract_info.reward_supplier;
    let reward_supplier_dispatcher = IRewardSupplierDispatcher {
        contract_address: reward_supplier,
    };
    assert!(ALPHA == reward_supplier_dispatcher.get_alpha());
}
