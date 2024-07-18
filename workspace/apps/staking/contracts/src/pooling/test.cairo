use contracts::{
    BASE_VALUE,
    pooling::{
        Pooling, PoolMemberInfo,
        Pooling::{
            // TODO(Nir, 15/07/2024): Remove member module use's when possible
            __member_module_staker_address::InternalContractMemberStateTrait as StakerAddressMemberModule,
            __member_module_pool_member_address_to_info::InternalContractMemberStateTrait as PoolMemberToInfoModule,
            __member_module_final_staker_index::InternalContractMemberStateTrait as StakerFinalIndexModule,
            InternalPoolingFunctionsTrait
        }
    },
    test_utils::initialize_pooling_state,
    test_utils::constants::{DUMMY_ADDRESS, REWARD_ADDRESS, STAKE_AMOUNT}
};
use contracts::pooling::interface::IPooling;
use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
use starknet::{ContractAddress, contract_address_const};

#[test]
fn test_calculate_rewards() {
    let mut state = initialize_pooling_state();
    let dummy_address: ContractAddress = DUMMY_ADDRESS();

    let updated_index: u64 = BASE_VALUE * 2;
    let mut pool_member_info = PoolMemberInfo {
        amount: BASE_VALUE.into(), index: BASE_VALUE, ..Default::default()
    };
    state.calculate_rewards(dummy_address, ref pool_member_info, updated_index);
    let new_pool_member_info = state.pool_member_address_to_info.read(dummy_address);
    assert_eq!(new_pool_member_info.unclaimed_rewards, BASE_VALUE.into());
    assert_eq!(new_pool_member_info.index, BASE_VALUE * 2)
}

// TODO(alon, 24/07/2024): Complete this function.
#[test]
fn test_enter_delegation_pool() {
    let mut state = initialize_pooling_state();
    assert!(state.enter_delegation_pool(amount: STAKE_AMOUNT, reward_address: REWARD_ADDRESS()));
}

#[test]
fn test_assert_staker_is_active() {
    let mut state = initialize_pooling_state();
    assert!(state.final_staker_index.read().is_none());
    state.assert_staker_is_active();
}

#[test]
#[should_panic(expected: ("Staker is inactive.",))]
fn test_assert_staker_is_active_panic() {
    let mut state = initialize_pooling_state();
    state.final_staker_index.write(Option::Some(5));
    state.assert_staker_is_active();
}
