use contracts::operator::staking_mock::StakingForOperatorMock::{
    IStakingMockSetterDispatcher, IStakingMockSetterDispatcherTrait
};
use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use contracts::test_utils::constants::{DUMMY_ADDRESS, CALLER_ADDRESS};
use snforge_std::ContractClassTrait;
use snforge_std::{CheatSpan, cheat_caller_address, cheat_account_contract_address};
use starknet::ContractAddress;

fn deploy_mock_staking_contract() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let staking_mock_contract = snforge_std::declare("StakingForOperatorMock").unwrap();
    let (staking_mock_contract_address, _) = staking_mock_contract.deploy(@calldata).unwrap();
    staking_mock_contract_address
}

fn deploy_operator_contract(staking_mock_contract_address: ContractAddress) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    staking_mock_contract_address.serialize(ref calldata);
    let operator_contract = snforge_std::declare("Operator").unwrap();
    let (operator_contract_address, _) = operator_contract.deploy(@calldata).unwrap();
    operator_contract_address
}
fn setup() -> (IStakingDispatcher, IStakingDispatcher, ContractAddress) {
    let staking_mock_contract_address = deploy_mock_staking_contract();
    let operator_contract_address = deploy_operator_contract(staking_mock_contract_address);
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
        caller_account_address
    )
}

#[test]
fn test_stake_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher
        .stake(
            reward_address: DUMMY_ADDRESS(),
            operational_address: DUMMY_ADDRESS(),
            amount: 0,
            pooling_enabled: false,
            commission: 0
        );
}

#[test]
fn test_increase_stake_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.increase_stake(staker_address: DUMMY_ADDRESS(), amount: 0,);
}

#[test]
fn test_claim_rewards_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.claim_rewards(staker_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_unstake_intent_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.unstake_intent();
}

#[test]
fn test_unstake_action_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.unstake_action(staker_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_change_reward_address_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.change_reward_address(reward_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_set_open_for_delegation_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.set_open_for_delegation(commission: 0);
}

#[test]
fn test_state_of_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.state_of(staker_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_contract_parameters_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.contract_parameters();
}

#[test]
fn test_get_total_stake_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.get_total_stake();
}

#[test]
fn test_update_global_index_if_needed_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.update_global_index_if_needed();
}

#[test]
fn test_change_operational_address_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.change_operational_address(operational_address: DUMMY_ADDRESS(),);
}

#[test]
fn test_update_commission_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.update_commission(commission: 0);
}

#[test]
fn test_is_paused_from_operator() {
    let (_staking_mock_contract_dispatcher, operator_contract_dispatcher, _caller_account_address) =
        setup();
    operator_contract_dispatcher.is_paused();
}

