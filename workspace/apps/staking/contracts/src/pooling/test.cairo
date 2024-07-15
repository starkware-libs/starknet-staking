use contracts::{
    BASE_VALUE,
    pooling::{
        Pooling, PoolMemberInfo,
        Pooling::{
            // TODO(Nir, 15/07/2024): Remove member module use's when possible
            __member_module_staker_address::InternalContractMemberStateTrait as StakerAddressMemberModule,
            __member_module_pool_member_address_to_info::InternalContractMemberStateTrait as PoolMemberToInfoModule
        }
    },
    test_utils::{initalize_pooling_state, constants::DUMMY_ADDRESS}
};
use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
use starknet::{ContractAddress, contract_address_const};

#[test]
fn test_calculate_rewards() {
    let mut state = initalize_pooling_state();
    let dummy_address: ContractAddress = DUMMY_ADDRESS();

    let updated_index: u64 = BASE_VALUE * 2;
    let mut pool_member_info = PoolMemberInfo {
        amount: BASE_VALUE.into(), index: BASE_VALUE, ..Default::default()
    };
    Pooling::InternalPoolingFunctionsTrait::calculate_rewards(
        ref state, dummy_address, ref pool_member_info, updated_index
    );
    let new_pool_member_info = state.pool_member_address_to_info.read(dummy_address);
    assert_eq!(new_pool_member_info.unclaimed_rewards, BASE_VALUE.into());
    assert_eq!(new_pool_member_info.index, BASE_VALUE * 2)
}
