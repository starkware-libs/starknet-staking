use contracts::staking::Staking;
// TODO(Nir, 15/07/2024): Remove member module use's when 2.7.0-rc.1 is released
use contracts::staking::Staking::__member_module_min_stake::InternalContractMemberStateTrait as MinStakeMemberModule;
use contracts::staking::Staking::__member_module_staker_address_to_info::InternalContractMemberStateTrait as StakerAddressToStakerInfoMemberModule;
use contracts::staking::Staking::__member_module_operational_address_to_staker_address::InternalContractMemberStateTrait as OperationalAddressToStakerAddressMemberModule;
use contracts::staking::Staking::__member_module_token_address::InternalContractMemberStateTrait as TokenAddressMemberModule;
use contracts::staking::Staking::__member_module_max_leverage::InternalContractMemberStateTrait as MaxLeverageMemberModule;
use contracts::staking::Staking::__member_module_global_index::InternalContractMemberStateTrait as GlobalIndexMemberModule;

use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
use contracts::staking::StakerInfo;
use starknet::{ContractAddress, contract_address_const};
use contracts::BASE_VALUE;

#[test]
fn test_constructor() {
    let mut state = Staking::contract_state_for_testing();
    let token_address: ContractAddress = contract_address_const::<
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
    >();
    let dummy_address: ContractAddress = contract_address_const::<0xdeadbeef>();
    let min_stake: u128 = 100000;
    let max_leverage: u64 = 100;
    Staking::constructor(ref state, token_address, min_stake, max_leverage);

    let contract_min_stake: u128 = state.min_stake.read();
    assert_eq!(min_stake, contract_min_stake);
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
