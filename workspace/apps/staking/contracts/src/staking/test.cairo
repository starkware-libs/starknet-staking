use contracts::{
    BASE_VALUE,
    staking::{
        StakerInfo, Staking,
        Staking::{
            // TODO(Nir, 15/07/2024): Remove member module use's when possible
            __member_module_min_stake::InternalContractMemberStateTrait as MinStakeMemberModule,
            __member_module_staker_address_to_info::InternalContractMemberStateTrait as StakerAddressToStakerInfoMemberModule,
            __member_module_operational_address_to_staker_address::InternalContractMemberStateTrait as OperationalAddressToStakerAddressMemberModule,
            __member_module_token_address::InternalContractMemberStateTrait as TokenAddressMemberModule,
            __member_module_max_leverage::InternalContractMemberStateTrait as MaxLeverageMemberModule,
            __member_module_global_index::InternalContractMemberStateTrait as GlobalIndexMemberModule,
            InternalStakingFunctionsTrait
        }
    },
    test_utils::{
        initialize_staking_state, deploy_mock_erc20_contract, init_stake, StakingInitConfig,
        constants::{
            TOKEN_ADDRESS, DUMMY_ADDRESS, POOLING_CONTRACT_ADDRESS, MAX_LEVERAGE, MIN_STAKE,
            OWNER_ADDRESS, INITIAL_SUPPLY, REWARD_ADDRESS, OPERATIONAL_ADDRESS, STAKER_ADDRESS,
            STAKE_AMOUNT, STAKER_INITIAL_BALANCE, REV_SHARE, OTHER_STAKER_ADDRESS,
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
use contracts::staking::Staking::REV_SHARE_DENOMINATOR;

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
        .staker_address_to_info
        .read(dummy_address);
    assert_eq!(contract_staker_address_to_operational_address, Default::default());
}

#[test]
fn test_stake() {
    // TODO(Nir, 01/08/2024): add initial supply and owner address to StakingInitConfig.
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: INITIAL_SUPPLY, owner_address: OWNER_ADDRESS()
    );
    let (mut state, erc20_dispatcher) = init_stake(:token_address, :cfg);

    // Check that the staker info was updated correctly.
    let expected_staker_info = StakerInfo {
        reward_address: cfg.reward_address,
        operational_address: cfg.operational_address,
        amount_own: cfg.stake_amount,
        index: BASE_VALUE,
        rev_share: cfg.rev_share,
        ..Default::default()
    };
    assert_eq!(expected_staker_info, state.staker_address_to_info.read(cfg.staker_address));

    // Check that the operational address to staker address mapping was updated correctly.
    assert_eq!(
        cfg.staker_address,
        state.operational_address_to_staker_address.read(cfg.operational_address)
    );

    // Check that the staker's tokens were transferred to the Staking contract.
    assert_eq!(
        erc20_dispatcher.balance_of(cfg.staker_address),
        (cfg.staker_initial_balance - cfg.stake_amount).into()
    );
    let staking_contract_address = snforge_std::test_address();
    assert_eq!(erc20_dispatcher.balance_of(staking_contract_address), cfg.stake_amount.into());
}

#[test]
fn test_calculate_rewards() {
    let mut state = initialize_staking_state(TOKEN_ADDRESS(), MIN_STAKE, MAX_LEVERAGE);

    let staker_address: ContractAddress = STAKER_ADDRESS();

    let mut staker_info = StakerInfo {
        amount_own: BASE_VALUE.into(),
        amount_pool: BASE_VALUE.into(),
        pooling_contract: Option::Some(POOLING_CONTRACT_ADDRESS()),
        ..Default::default()
    };
    assert!(state.calculate_rewards(:staker_address, ref :staker_info));
    let new_staker_info = state.staker_address_to_info.read(staker_address);
    assert_eq!(new_staker_info.unclaimed_rewards_own, BASE_VALUE.into());
    assert_eq!(new_staker_info.index, BASE_VALUE);
    assert_eq!(new_staker_info.unclaimed_rewards_pool, BASE_VALUE.into());
}

#[test]
#[should_panic(expected: "Staker already exists, use increase_stake instead.")]
fn test_stake_from_same_staker_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: INITIAL_SUPPLY, owner_address: OWNER_ADDRESS()
    );
    // In init_stake function the caller_address is cheated to be cfg.staker_address.
    // First stake from cfg.staker_address.
    let (mut state, _) = init_stake(:token_address, :cfg);

    // Second stake from cfg.staker_address.
    snforge_std::cheat_caller_address_global(caller_address: cfg.staker_address);
    state
        .stake(
            reward_address: cfg.reward_address,
            operational_address: cfg.operational_address,
            amount: cfg.stake_amount,
            pooling_enabled: false,
            rev_share: cfg.rev_share
        );
}

#[test]
#[should_panic(expected: "Operational address already exists.")]
fn test_stake_with_same_operational_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: INITIAL_SUPPLY, owner_address: OWNER_ADDRESS()
    );
    // In init_stake function the caller_address is cheated to be cfg.staker_address.
    // First stake from cfg.staker_address.
    let (mut state, _) = init_stake(:token_address, :cfg);

    // Change staker address.
    snforge_std::cheat_caller_address_global(caller_address: OTHER_STAKER_ADDRESS());
    assert!(cfg.staker_address != OTHER_STAKER_ADDRESS());
    // Second stake with the same operational address.
    state
        .stake(
            reward_address: cfg.reward_address,
            operational_address: cfg.operational_address,
            amount: cfg.stake_amount,
            pooling_enabled: false,
            rev_share: cfg.rev_share
        );
}

#[test]
#[should_panic(expected: "Amount is less than min stake - try again with enough funds.")]
fn test_stake_with_less_than_min_stake() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: INITIAL_SUPPLY, owner_address: OWNER_ADDRESS()
    );
    cfg.stake_amount = cfg.min_stake - 1;
    init_stake(:token_address, :cfg);
}

#[test]
#[should_panic(expected: "Rev share is out of range, expected to be 0-100.")]
fn test_stake_with_rev_share_out_of_range() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: INITIAL_SUPPLY, owner_address: OWNER_ADDRESS()
    );
    cfg.rev_share = REV_SHARE_DENOMINATOR + 1;
    init_stake(:token_address, :cfg);
}

// TODO: when pooling enabled = true is supported, change this test.
#[test]
#[should_panic(expected: "Pooling is not implemented.")]
fn test_stake_with_pooling_enabled() {
    let mut cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: INITIAL_SUPPLY, owner_address: OWNER_ADDRESS()
    );
    cfg.pooling_enabled = true;
    init_stake(:token_address, :cfg);
}

#[test]
fn test_increase_stake_from_staker_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: INITIAL_SUPPLY, owner_address: OWNER_ADDRESS()
    );
    // In init_stake function the caller_address is cheated to be cfg.staker_address.
    // First stake from cfg.staker_address
    let (mut state, _) = init_stake(:token_address, :cfg);

    // Set the same staker address.
    snforge_std::start_cheat_caller_address(
        contract_address: snforge_std::test_address(), caller_address: cfg.staker_address
    );
    let staker_info_before = state.staker_address_to_info.read(cfg.staker_address);
    let increase_amount = cfg.stake_amount;
    let expected_staker_info = StakerInfo {
        amount_own: staker_info_before.amount_own + increase_amount, ..staker_info_before
    };
    // Increase stake from the same staker address.
    state.increase_stake(staker_address: cfg.staker_address, amount: increase_amount,);

    let updated_staker_info = state.staker_address_to_info.read(cfg.staker_address);
    assert_eq!(expected_staker_info, updated_staker_info);
}

// TODO: Implement.
#[test]
fn test_increase_stake_from_reward_address() {
    assert!(true);
}

// TODO: Implement.
#[test]
fn test_increase_stake_staker_address_not_exist() {
    assert!(true);
}

// TODO: Implement.
#[test]
fn test_increase_stake_unstake_in_progress() {
    assert!(true);
}

// TODO: Implement.
#[test]
fn test_increase_stake_amount_less_than_min_increase_stake() {
    assert!(true);
}

// TODO: Implement.
#[test]
fn test_increase_stake_caller_is_not_staker_or_rewarder() {
    assert!(true);
}
