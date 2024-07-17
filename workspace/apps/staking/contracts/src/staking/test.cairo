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
        }
    },
    test_utils::{
        initalize_staking_state, init_stake, deploy_mock_erc20_contract, StakingInitConfig,
        constants::{
            TOKEN_ADDRESS, DUMMY_ADDRESS, POOLING_ADDRESS, MAX_LEVERAGE, MIN_STAKE, OWNER_ADDRESS,
            INITIAL_SUPPLY
        }
    }
};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
use starknet::{ContractAddress, contract_address_const};

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
fn test_calculate_rewards() {
    let mut state = initalize_staking_state();

    let dummy_address: ContractAddress = DUMMY_ADDRESS();

    let mut staker_info = StakerInfo {
        amount_own: BASE_VALUE.into(),
        amount_pool: BASE_VALUE.into(),
        pooling_contract: Option::Some(POOLING_ADDRESS()),
        ..Default::default()
    };

    Staking::InternalStakingFunctionsTrait::calculate_rewards(
        ref state, dummy_address, ref staker_info
    );
    let new_staker_info = state.staker_address_to_info.read(dummy_address);
    assert_eq!(new_staker_info.unclaimed_rewards_own, BASE_VALUE.into());
    assert_eq!(new_staker_info.index, BASE_VALUE);
    assert_eq!(new_staker_info.unclaimed_rewards_pool, BASE_VALUE.into());
}

// TODO: Remove this test when test_stake is merged.
#[test]
fn test_staking_test_utils() {
    let owner_address = OWNER_ADDRESS();
    let token_address = deploy_mock_erc20_contract(INITIAL_SUPPLY, owner_address);
    let (_, _) = init_stake(token_address, Default::default());
}
