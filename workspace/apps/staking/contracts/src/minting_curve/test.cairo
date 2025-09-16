use core::num::traits::{Sqrt, WideMul};
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use staking::event_test_utils::assert_minting_cap_changed_event;
use staking::minting_curve::interface::{
    IMintingCurveConfigDispatcher, IMintingCurveConfigDispatcherTrait, IMintingCurveDispatcher,
    IMintingCurveDispatcherTrait, MintingCurveContractInfo,
};
use staking::minting_curve::minting_curve::MintingCurve::{
    CONTRACT_IDENTITY as mint_curve_identity, CONTRACT_VERSION as mint_curve_version, MAX_C_NUM,
};
use staking::test_utils::constants::NON_TOKEN_ADMIN;
use staking::test_utils::{
    StakingInitConfig, advance_epoch_global, general_contract_system_deployment,
    stake_for_testing_using_dispatcher,
};
use staking::types::Amount;
use starkware_utils_testing::event_test_utils::assert_number_of_events;
use starkware_utils_testing::test_utils::{cheat_caller_address_once, check_identity};

#[test]
fn test_identity() {
    assert!(mint_curve_identity == 'Minting Curve');
    assert!(mint_curve_version == '2.0.0');

    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    check_identity(minting_curve_contract, mint_curve_identity, mint_curve_version);
}

#[test]
fn test_yearly_mint() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: minting_curve_contract,
    };
    stake_for_testing_using_dispatcher(:cfg);
    let total_stake = cfg.test_info.stake_amount;
    let total_supply: Amount = cfg
        .test_info
        .initial_supply
        .try_into()
        .expect('total_supply doesn\'t fit u128');
    let product: u256 = total_stake.wide_mul(total_supply);
    let unadjusted_mint_amount: Amount = product.sqrt();
    let expected_minted_tokens: Amount = cfg.minting_curve_contract_info.c_num.into()
        * unadjusted_mint_amount
        / cfg.minting_curve_contract_info.c_denom.into();

    // Current stake power is 0, so no minting.
    let minted_tokens = minting_curve_dispatcher.yearly_mint();
    assert!(minted_tokens == 0);

    // After advancing epoch, the stake power is not 0, so we expect minting.
    advance_epoch_global();
    let minted_tokens = minting_curve_dispatcher.yearly_mint();
    assert!(minted_tokens == expected_minted_tokens);
}

#[test]
fn test_set_c_num() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: minting_curve_contract,
    };
    let minting_curve_config_dispatcher = IMintingCurveConfigDispatcher {
        contract_address: minting_curve_contract,
    };
    let old_c = cfg.minting_curve_contract_info.c_num;
    assert!(old_c == minting_curve_dispatcher.contract_parameters().c_num);
    let new_c = old_c * 2;
    let mut spy = snforge_std::spy_events();
    cheat_caller_address_once(
        contract_address: minting_curve_contract, caller_address: cfg.test_info.token_admin,
    );
    minting_curve_config_dispatcher.set_c_num(c_num: new_c);
    assert!(new_c == minting_curve_dispatcher.contract_parameters().c_num);
    // Validate the single MintingCapChanged event.
    let events = spy.get_events().emitted_by(contract_address: minting_curve_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "set_c_num");
    assert_minting_cap_changed_event(spied_event: events[0], :old_c, :new_c);
}

#[test]
#[should_panic(expected: "ONLY_TOKEN_ADMIN")]
fn test_set_c_num_unauthorized() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_config_dispatcher = IMintingCurveConfigDispatcher {
        contract_address: minting_curve_contract,
    };
    let new_c_num = cfg.minting_curve_contract_info.c_num * 2;
    cheat_caller_address_once(
        contract_address: minting_curve_contract, caller_address: NON_TOKEN_ADMIN(),
    );
    minting_curve_config_dispatcher.set_c_num(c_num: new_c_num);
}

#[test]
#[should_panic(expected: "C Numerator out of range (0-500)")]
fn test_set_invalid_c_num() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_config_dispatcher = IMintingCurveConfigDispatcher {
        contract_address: minting_curve_contract,
    };
    let new_c_num = cfg.minting_curve_contract_info.c_denom + 1;
    cheat_caller_address_once(
        contract_address: minting_curve_contract, caller_address: cfg.test_info.token_admin,
    );
    minting_curve_config_dispatcher.set_c_num(c_num: new_c_num);
}

#[test]
#[should_panic(expected: "C Numerator out of range (0-500)")]
fn test_set_c_num_over_limit() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_config_dispatcher = IMintingCurveConfigDispatcher {
        contract_address: minting_curve_contract,
    };
    let new_c_num = MAX_C_NUM + 1;
    cheat_caller_address_once(
        contract_address: minting_curve_contract, caller_address: cfg.test_info.token_admin,
    );
    minting_curve_config_dispatcher.set_c_num(c_num: new_c_num);
}

#[test]
fn test_set_max_c_num() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_config_dispatcher = IMintingCurveConfigDispatcher {
        contract_address: minting_curve_contract,
    };
    let new_c_num = MAX_C_NUM;
    cheat_caller_address_once(
        contract_address: minting_curve_contract, caller_address: cfg.test_info.token_admin,
    );
    minting_curve_config_dispatcher.set_c_num(c_num: new_c_num);
}

#[test]
fn test_contract_parameters() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: minting_curve_contract,
    };
    let expected_contract_parameters = MintingCurveContractInfo {
        c_num: cfg.minting_curve_contract_info.c_num,
        c_denom: cfg.minting_curve_contract_info.c_denom,
    };
    assert!(expected_contract_parameters == minting_curve_dispatcher.contract_parameters());
}
