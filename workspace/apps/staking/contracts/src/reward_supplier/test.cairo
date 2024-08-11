use starknet::get_block_timestamp;
use contracts::test_utils::{
    deploy_mock_erc20_contract, StakingInitConfig, deploy_staking_contract,
    stake_for_testing_using_dispatcher, initialize_reward_supplier_state_from_cfg
};
use contracts::reward_supplier::RewardSupplier;
use contracts::reward_supplier::RewardSupplier::{
    __member_module_staking_contract::InternalContractMemberStateTrait as MinStakeMemberModule,
    __member_module_last_timestamp::InternalContractMemberStateTrait as LastTSMemberModule,
    __member_module_unclaimed_rewards::InternalContractMemberStateTrait as UnclaimedMemberModule,
    __member_module_buffer::InternalContractMemberStateTrait as BufferMemberModule,
    __member_module_base_mint_amount::InternalContractMemberStateTrait as MintAmountMemberModule,
    __member_module_base_mint_msg::InternalContractMemberStateTrait as MintMsgMemberModule,
    __member_module_minting_curve_contract::InternalContractMemberStateTrait as CurveMemberModule,
    __member_module_staking_contract::InternalContractMemberStateTrait as StakingMemberModule,
    __member_module_token_address::InternalContractMemberStateTrait as TokenMemberModule,
    __member_module_l1_staking_minter::InternalContractMemberStateTrait as L1MinterMemberModule,
};


#[test]
fn test_reward_supplier_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy the token contract.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address
    );
    // Deploy the staking contract, stake, and enter delegation pool.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    cfg.test_info.staking_contract = staking_contract;
    let state = initialize_reward_supplier_state_from_cfg(:token_address, :cfg);
    assert_eq!(state.staking_contract.read(), cfg.test_info.staking_contract);
    assert_eq!(state.token_address.read(), token_address);
    assert_eq!(state.buffer.read(), cfg.reward_supplier.buffer);
    assert_eq!(state.base_mint_amount.read(), cfg.reward_supplier.base_mint_amount);
    assert_eq!(state.base_mint_msg.read(), cfg.reward_supplier.base_mint_msg);
    assert_eq!(state.minting_curve_contract.read(), cfg.reward_supplier.minting_curve_contract);
    assert_eq!(state.l1_staking_minter.read(), cfg.reward_supplier.l1_staking_minter);
    assert_eq!(state.last_timestamp.read(), get_block_timestamp());
    assert_eq!(state.unclaimed_rewards.read(), 0_u128);
}
