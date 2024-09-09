use contracts::minting_curve::interface::{IMintingCurveDispatcher, IMintingCurveDispatcherTrait};
use contracts::minting_curve::interface::IMintingCurveConfigDispatcher;
use contracts::minting_curve::interface::IMintingCurveConfigDispatcherTrait;
use contracts::minting_curve::interface::MintingCurveContractInfo;
use core::num::traits::{WideMul, Sqrt};
use contracts::test_utils::{general_contract_system_deployment, stake_for_testing_using_dispatcher};
use contracts::test_utils::StakingInitConfig;
use contracts::test_utils::constants::NON_APP_GOVERNOR;
use contracts_commons::test_utils::cheat_caller_address_once;

#[test]
fn test_yearly_mint() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: minting_curve_contract
    };
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let total_stake = cfg.staker_info.amount_own;
    let total_supply: u128 = cfg
        .test_info
        .initial_supply
        .try_into()
        .expect('total_supply doesn\'t fit u128');
    let product: u256 = total_stake.wide_mul(total_supply);
    let unadjusted_mint_amount: u128 = product.sqrt();
    let expected_minted_tokens: u128 = cfg.minting_curve_contract_info.c_num.into()
        * unadjusted_mint_amount
        / cfg.minting_curve_contract_info.c_denom.into();
    let minted_tokens = minting_curve_dispatcher.yearly_mint();
    assert_eq!(minted_tokens, expected_minted_tokens);
}

#[test]
fn test_set_c_num() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: minting_curve_contract
    };
    let minting_curve_config_dispatcher = IMintingCurveConfigDispatcher {
        contract_address: minting_curve_contract
    };
    let old_c_num = cfg.minting_curve_contract_info.c_num;
    assert_eq!(old_c_num, minting_curve_dispatcher.contract_parameters().c_num);
    let new_c_num = old_c_num * 2;
    cheat_caller_address_once(
        contract_address: minting_curve_contract, caller_address: cfg.test_info.app_governer
    );
    minting_curve_config_dispatcher.set_c_num(c_num: new_c_num);
    assert_eq!(new_c_num, minting_curve_dispatcher.contract_parameters().c_num);
}

#[test]
#[should_panic(expected: 'ONLY_APP_GOVERNOR')]
fn test_set_c_num_unauthorized() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_config_dispatcher = IMintingCurveConfigDispatcher {
        contract_address: minting_curve_contract
    };
    let new_c_num = cfg.minting_curve_contract_info.c_num * 2;
    cheat_caller_address_once(
        contract_address: minting_curve_contract, caller_address: NON_APP_GOVERNOR()
    );
    minting_curve_config_dispatcher.set_c_num(c_num: new_c_num);
}

#[test]
#[should_panic(expected: "C numerator is out of range, expected to be 0-10000.")]
fn test_set_invalid_c_num() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_config_dispatcher = IMintingCurveConfigDispatcher {
        contract_address: minting_curve_contract
    };
    let new_c_num = cfg.minting_curve_contract_info.c_denom + 1;
    cheat_caller_address_once(
        contract_address: minting_curve_contract, caller_address: cfg.test_info.app_governer
    );
    minting_curve_config_dispatcher.set_c_num(c_num: new_c_num);
}
#[test]
fn test_contract_parameters() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let minting_curve_contract = cfg.reward_supplier.minting_curve_contract;
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: minting_curve_contract
    };
    let expected_contract_parameters = MintingCurveContractInfo {
        c_num: cfg.minting_curve_contract_info.c_num,
        c_denom: cfg.minting_curve_contract_info.c_denom
    };
    assert_eq!(expected_contract_parameters, minting_curve_dispatcher.contract_parameters());
}
