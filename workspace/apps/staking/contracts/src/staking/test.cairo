use contracts::{
    BASE_VALUE,
    staking::{
        StakerInfo, Staking,
        Staking::{
            // TODO(Nir, 15/07/2024): Remove member module use's when possible
            __member_module_min_stake::InternalContractMemberStateTrait as MinStakeMemberModule,
            __member_module_staker_info::InternalContractMemberStateTrait as StakerAddressToStakerInfoMemberModule,
            __member_module_operational_address_to_staker_address::InternalContractMemberStateTrait as OperationalAddressToStakerAddressMemberModule,
            __member_module_token_address::InternalContractMemberStateTrait as TokenAddressMemberModule,
            __member_module_max_leverage::InternalContractMemberStateTrait as MaxLeverageMemberModule,
            __member_module_global_index::InternalContractMemberStateTrait as GlobalIndexMemberModule,
            InternalStakingFunctionsTrait
        }
    },
    test_utils::{
        initialize_staking_state, deploy_mock_erc20_contract, StakingInitConfig, stake_for_testing,
        fund, approve,
        constants::{
            TOKEN_ADDRESS, DUMMY_ADDRESS, POOLING_CONTRACT_ADDRESS, MAX_LEVERAGE, MIN_STAKE,
            OWNER_ADDRESS, INITIAL_SUPPLY, REWARD_ADDRESS, OPERATIONAL_ADDRESS, STAKER_ADDRESS,
            STAKE_AMOUNT, STAKER_INITIAL_BALANCE, REV_SHARE, OTHER_STAKER_ADDRESS,
            OTHER_REWARD_ADDRESS, NON_STAKER_ADDRESS,
        }
    }
};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
use contracts::staking::interface::IStaking;
use starknet::{ContractAddress, contract_address_const, get_caller_address};
use starknet::syscalls::deploy_syscall;
use snforge_std::{declare, ContractClassTrait};
use contracts::staking::staking::Staking::ContractState;
use contracts::staking::Staking::{REV_SHARE_DENOMINATOR, EXIT_WAITING_WINDOW, MIN_INCREASE_STAKE};
use core::num::traits::Zero;
use contracts::staking::interface::StakingContractInfo;
use snforge_std::{cheat_caller_address, CheatSpan, test_address};


#[test]
fn test_constructor() {
    let token_address: ContractAddress = TOKEN_ADDRESS();
    let dummy_address: ContractAddress = DUMMY_ADDRESS();
    let mut state = Staking::contract_state_for_testing();
    Staking::constructor(ref state, token_address, MIN_STAKE, MAX_LEVERAGE);

    let contract_min_stake: u128 = state.min_stake.read();
    assert_eq!(MIN_STAKE, contract_min_stake);
    let contract_token_address: ContractAddress = state.token_address.read();
    assert_eq!(token_address, contract_token_address);
    let contract_global_index: u64 = state.global_index.read();
    assert_eq!(BASE_VALUE, contract_global_index);
    let contract_operational_address_to_staker_address: ContractAddress = state
        .operational_address_to_staker_address
        .read(dummy_address);
    assert_eq!(contract_operational_address_to_staker_address, Default::default());
    let contract_staker_address_to_operational_address: StakerInfo = state
        .staker_info
        .read(dummy_address);
    assert_eq!(contract_staker_address_to_operational_address, Default::default());
}

#[test]
fn test_stake() {
    // TODO(Nir, 01/08/2024): add initial supply and owner address to StakingInitConfig.
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);

    // Check that the staker info was updated correctly.
    let expected_staker_info = cfg.staker_info;
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert_eq!(expected_staker_info, state.staker_info.read(cfg.test_info.staker_address));

    // Check that the operational address to staker address mapping was updated correctly.
    assert_eq!(
        cfg.test_info.staker_address,
        state.operational_address_to_staker_address.read(cfg.staker_info.operational_address)
    );

    // Check that the staker's tokens were transferred to the Staking contract.
    assert_eq!(
        erc20_dispatcher.balance_of(cfg.test_info.staker_address),
        (cfg.test_info.staker_initial_balance - cfg.staker_info.amount_own).into()
    );
    let staking_contract_address = test_address();
    assert_eq!(
        erc20_dispatcher.balance_of(staking_contract_address), cfg.staker_info.amount_own.into()
    );
}

#[test]
fn test_calculate_rewards() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );

    let mut staker_info = StakerInfo {
        pooling_contract: Option::Some(POOLING_CONTRACT_ADDRESS()),
        index: 0,
        rev_share: 0,
        amount_pool: cfg.staker_info.amount_own,
        ..cfg.staker_info
    };
    assert!(state.calculate_rewards(cfg.test_info.staker_address, ref :staker_info));
    let new_staker_info = state.staker_info.read(cfg.test_info.staker_address);
    assert_eq!(new_staker_info.unclaimed_rewards_own, cfg.staker_info.amount_own);
    assert_eq!(new_staker_info.index, cfg.staker_info.index);
    assert_eq!(new_staker_info.unclaimed_rewards_pool, cfg.staker_info.amount_own);
}

#[test]
#[should_panic(expected: "Staker already exists, use increase_stake instead.")]
fn test_stake_from_same_staker_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);

    // Second stake from cfg.test_info.staker_address.
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    cfg.staker_info.amount_own = cfg.staking_contract_info.min_stake - 1;
    stake_for_testing(ref state, :cfg, :token_address);
}

#[test]
#[should_panic(expected: "Rev share is out of range, expected to be 0-100.")]
fn test_stake_with_rev_share_out_of_range() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    cfg.staker_info.rev_share = REV_SHARE_DENOMINATOR + 1;
    stake_for_testing(ref state, :cfg, :token_address);
}

// TODO: when pooling enabled = true is supported, change this test.
// #[test]
// #[should_panic(expected: "Pooling is not implemented.")]
// fn test_stake_with_pooling_enabled() {
//     let mut cfg: StakingInitConfig = Default::default();
//     let token_address = deploy_mock_erc20_contract(
//         initial_supply: INITIAL_SUPPLY, owner_address: OWNER_ADDRESS()
//     );
//     cfg.test_info.pooling_enabled, = true;
//     init_stake(:token_address, :cfg);
// }

#[test]
fn test_claim_delegation_pool_rewards() {
    let pooling_contract = POOLING_CONTRACT_ADDRESS();
    let mut cfg: StakingInitConfig = Default::default();
    cfg.staker_info.pooling_contract = Option::Some(pooling_contract);
    cfg.test_info.pooling_enabled = true;
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);

    // Update staker info for the test.
    let staker_info = StakerInfo {
        index: 0, amount_pool: cfg.staker_info.amount_own, ..cfg.staker_info
    };
    state.staker_info.write(cfg.test_info.staker_address, staker_info);

    cheat_caller_address(test_address(), pooling_contract, CheatSpan::TargetCalls(1));
    state.claim_delegation_pool_rewards(cfg.test_info.staker_address);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    assert_eq!(
        erc20_dispatcher.balance_of(pooling_contract),
        cfg.staker_info.amount_own.into() * (100 - cfg.staker_info.rev_share.into()) / 100
    );
}

#[test]
fn test_contract_parameters() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);
    let expected_staking_contract_info = StakingContractInfo {
        max_leverage: cfg.staking_contract_info.max_leverage,
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);

    // Set the same staker address.
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    let staker_info_before = state.staker_info.read(cfg.test_info.staker_address);
    let increase_amount = cfg.staker_info.amount_own;
    let expected_staker_info = StakerInfo {
        amount_own: staker_info_before.amount_own + increase_amount, ..staker_info_before
    };
    // Increase stake from the same staker address.
    state.increase_stake(staker_address: cfg.test_info.staker_address, amount: increase_amount,);

    let updated_staker_info = state.staker_info.read(cfg.test_info.staker_address);
    assert_eq!(expected_staker_info, updated_staker_info);
}

#[test]
#[should_panic(expected: "Pool address does not exist.")]
fn test_claim_delegation_pool_rewards_pool_address_doesnt_exist() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.staker_info.pooling_contract = Option::Some(POOLING_CONTRACT_ADDRESS());
    cfg.test_info.pooling_enabled = true;
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    state.claim_delegation_pool_rewards(cfg.test_info.staker_address);
}


#[test]
#[should_panic(
    expected: "Claim delegation pool rewards must be called from delegation pooling contract."
)]
fn test_claim_delegation_pool_rewards_unauthorized_address() {
    let mut cfg: StakingInitConfig = Default::default();
    cfg.staker_info.pooling_contract = Option::Some(POOLING_CONTRACT_ADDRESS());
    cfg.test_info.pooling_enabled = true;
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);

    // Update staker info for the test.
    let staker_info = StakerInfo { index: 0, ..cfg.staker_info };
    state.staker_info.write(cfg.test_info.staker_address, staker_info);
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    state.claim_delegation_pool_rewards(cfg.test_info.staker_address);
}

#[test]
fn test_increase_stake_from_reward_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
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

    cheat_caller_address(test_address(), cfg.staker_info.reward_address, CheatSpan::TargetCalls(1));
    let staker_info_before = state.staker_info.read(cfg.test_info.staker_address);
    let increase_amount = cfg.staker_info.amount_own;
    let mut expected_staker_info = staker_info_before;
    expected_staker_info.amount_own += increase_amount;
    state.increase_stake(staker_address: cfg.test_info.staker_address, amount: increase_amount,);
    let updated_staker_info = state.staker_info.read(cfg.test_info.staker_address);
    assert_eq!(expected_staker_info, updated_staker_info);
}

#[test]
#[should_panic(expected: "Staker does not exist.")]
fn test_increase_stake_staker_address_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    state.unstake_intent();
    state
        .increase_stake(
            staker_address: cfg.test_info.staker_address, amount: cfg.staker_info.amount_own
        );
}

#[test]
#[should_panic(expected: "Amount is less than min increase stake - try again with enough funds.")]
fn test_increase_stake_amount_less_than_min_increase_stake() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    state
        .increase_stake(
            staker_address: cfg.test_info.staker_address, amount: MIN_INCREASE_STAKE - 1
        );
}

#[test]
#[should_panic(expected: "Caller address should be staker address or reward address.")]
fn test_increase_stake_caller_cannot_increase() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);
    let staker_info_before_change = state.staker_info.read(cfg.test_info.staker_address);
    let other_reward_address = OTHER_REWARD_ADDRESS();

    // Set the same staker address.
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    state.change_reward_address(other_reward_address);
    let staker_info_after_change = state.staker_info.read(cfg.test_info.staker_address);
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);

    // update index
    state.global_index.write((cfg.staker_info.index).into() * 2);

    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    let reward: u128 = state.claim_rewards(cfg.test_info.staker_address);
    assert_eq!(reward, cfg.staker_info.amount_own);

    let new_staker_info = state.state_of(cfg.test_info.staker_address);
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
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
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);
    state.claim_rewards(DUMMY_ADDRESS());
}

#[test]
fn test_unstake_intent() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    stake_for_testing(ref state, :cfg, :token_address);
    let unstake_time = state.unstake_intent();
    let staker_info = state.staker_info.read(cfg.test_info.staker_address);
    let expected_time = EXIT_WAITING_WINDOW; // 3 weeks
    assert_eq!((staker_info.unstake_time).unwrap(), unstake_time);
    assert_eq!(unstake_time, expected_time);
}

#[test]
fn test_unstake_intent_staker_doesnt_exist() {
    assert!(true);
}

#[test]
fn test_unstake_action_unstake_in_progress() {
    assert!(true);
}

#[test]
fn test_get_total_stake() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_staking_state(
        token_address, cfg.staking_contract_info.min_stake, cfg.staking_contract_info.max_leverage
    );
    assert_eq!(state.get_total_stake(), 0);
    stake_for_testing(ref state, :cfg, :token_address);
    assert_eq!(state.get_total_stake(), cfg.staker_info.amount_own);
}
