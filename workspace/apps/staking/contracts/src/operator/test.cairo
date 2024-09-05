use contracts::operator::staking_mock::StakingForOperatorMock::IStakingMockSetterDispatcher;
use contracts::operator::staking_mock::StakingForOperatorMock::IStakingMockSetterDispatcherTrait;
use contracts::operator::interface::{IOperatorDispatcher, IOperatorDispatcherTrait};
use contracts::operator::Operator::MAX_WHITELIST_SIZE;
use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use contracts::test_utils::constants::{DUMMY_ADDRESS, CALLER_ADDRESS};
use contracts::test_utils::deploy_operator_contract;
use snforge_std::ContractClassTrait;
use snforge_std::{CheatSpan, cheat_caller_address, cheat_account_contract_address};
use starknet::ContractAddress;
use contracts::test_utils::StakingInitConfig;
use contracts_commons::test_utils::cheat_caller_address_once;
use core::num::traits::zero::Zero;
use core::num::traits::one::One;

fn deploy_mock_staking_contract() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let staking_mock_contract = snforge_std::declare("StakingForOperatorMock").unwrap();
    let (staking_mock_contract_address, _) = staking_mock_contract.deploy(@calldata).unwrap();
    staking_mock_contract_address
}

fn setup(
    ref cfg: StakingInitConfig
) -> (IStakingDispatcher, IStakingDispatcher, IOperatorDispatcher, ContractAddress) {
    let staking_mock_contract_address = deploy_mock_staking_contract();
    cfg.test_info.staking_contract = staking_mock_contract_address;
    let operator_contract_address = deploy_operator_contract(:cfg);
    let caller_account_address = CALLER_ADDRESS();
    IStakingMockSetterDispatcher { contract_address: staking_mock_contract_address }
        .set_addresses(
            caller_address: operator_contract_address,
            account_contract_address: caller_account_address
        );
    cheat_caller_address(
        contract_address: staking_mock_contract_address,
        caller_address: operator_contract_address,
        span: CheatSpan::TargetCalls(1)
    );
    cheat_account_contract_address(
        contract_address: staking_mock_contract_address,
        account_contract_address: caller_account_address,
        span: CheatSpan::TargetCalls(1)
    );
    (
        IStakingDispatcher { contract_address: staking_mock_contract_address },
        IStakingDispatcher { contract_address: operator_contract_address },
        IOperatorDispatcher { contract_address: operator_contract_address },
        caller_account_address
    )
}

#[test]
fn test_stake_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher
        .stake(
            reward_address: DUMMY_ADDRESS(),
            operational_address: DUMMY_ADDRESS(),
            amount: 0,
            pool_enabled: false,
            commission: 0
        );
}

#[test]
fn test_increase_stake_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher
        .increase_stake(staker_address: DUMMY_ADDRESS(), amount: 0,);
}

#[test]
fn test_claim_rewards_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.claim_rewards(staker_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_unstake_intent_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.unstake_intent();
}

#[test]
fn test_unstake_action_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.unstake_action(staker_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_change_reward_address_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.change_reward_address(reward_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_set_open_for_delegation_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.set_open_for_delegation(commission: 0);
}

#[test]
fn test_state_of_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.state_of(staker_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_contract_parameters_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.contract_parameters();
}

#[test]
fn test_get_total_stake_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.get_total_stake();
}

#[test]
fn test_update_global_index_if_needed_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.update_global_index_if_needed();
}

#[test]
fn test_change_operational_address_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher
        .change_operational_address(operational_address: DUMMY_ADDRESS(),);
}

// #[test]
// fn test_update_commission_from_operator() {
//     let mut cfg: StakingInitConfig = Default::default();
//     let (
//         _staking_mock_contract_dispatcher,
//         operator_staking_contract_dispatcher,
//         _operator_contract_dispatcher,
//         _caller_account_address
//     ) =
//         setup(
//         ref :cfg
//     );
//     operator_staking_contract_dispatcher.update_commission(commission: 0);
// }

#[test]
fn test_is_paused_from_operator() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        _operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    operator_staking_contract_dispatcher.is_paused();
}

#[test]
fn test_enable_whitelist() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        _operator_staking_contract_dispatcher,
        operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    assert!(!operator_contract_dispatcher.is_whitelist_enabled());
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.security_agent
    );
    operator_contract_dispatcher.enable_whitelist();
    assert!(operator_contract_dispatcher.is_whitelist_enabled());
}

#[test]
fn test_disable_whitelist() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        _operator_staking_contract_dispatcher,
        operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.security_agent
    );
    operator_contract_dispatcher.enable_whitelist();
    assert!(operator_contract_dispatcher.is_whitelist_enabled());
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.security_admin
    );
    operator_contract_dispatcher.disable_whitelist();
    assert!(!operator_contract_dispatcher.is_whitelist_enabled());
}

#[test]
fn test_add_to_whitelist() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        _operator_staking_contract_dispatcher,
        operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    let addresses = operator_contract_dispatcher.get_whitelist_addresses();
    assert_eq!(addresses.len(), Zero::zero());
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.security_admin
    );
    operator_contract_dispatcher.add_to_whitelist(address: DUMMY_ADDRESS(),);
    let addresses = operator_contract_dispatcher.get_whitelist_addresses();
    assert_eq!(addresses.len(), One::one());
}

#[test]
#[should_panic(expected: "Whitelist is limited to 100 addresses.")]
fn test_add_too_many_to_whitelist() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        _operator_staking_contract_dispatcher,
        operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    for i in 0
        ..MAX_WHITELIST_SIZE
            + 1_u64 {
                let addresses = operator_contract_dispatcher.get_whitelist_addresses();
                assert_eq!(addresses.len().into(), i);
                cheat_caller_address_once(
                    contract_address: operator_contract_dispatcher.contract_address,
                    caller_address: cfg.test_info.security_admin
                );
                let address: felt252 = i.into();
                operator_contract_dispatcher
                    .add_to_whitelist(address: address.try_into().expect('not ContractAddress'));
            };
}

#[test]
#[should_panic(expected: 'ONLY_SECURITY_AGENT')]
fn test_enable_whitelist_from_unauthorized_address() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        _operator_staking_contract_dispatcher,
        operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: DUMMY_ADDRESS()
    );
    operator_contract_dispatcher.enable_whitelist();
}

#[test]
fn test_stake_from_operator_with_whitelist() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.security_agent
    );
    operator_contract_dispatcher.enable_whitelist();
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.security_admin
    );
    operator_contract_dispatcher.add_to_whitelist(address: cfg.test_info.staker_address);
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.staker_address
    );
    operator_staking_contract_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: 0,
            pool_enabled: false,
            commission: 0
        );
}


#[test]
#[should_panic(expected: "Caller is not in whitelist.")]
fn test_stake_from_operator_with_whitelist_caller_not_whitelisted() {
    let mut cfg: StakingInitConfig = Default::default();
    let (
        _staking_mock_contract_dispatcher,
        operator_staking_contract_dispatcher,
        operator_contract_dispatcher,
        _caller_account_address
    ) =
        setup(
        ref :cfg
    );
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.security_agent
    );
    operator_contract_dispatcher.enable_whitelist();
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: cfg.test_info.security_admin
    );
    operator_contract_dispatcher.add_to_whitelist(address: cfg.test_info.staker_address);
    cheat_caller_address_once(
        contract_address: operator_contract_dispatcher.contract_address,
        caller_address: DUMMY_ADDRESS()
    );
    operator_staking_contract_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: 0,
            pool_enabled: false,
            commission: 0
        );
}

// TODO: implement
#[test]
#[ignore]
fn test_whitelist_disable_and_enable() {
    assert!(true);
}
