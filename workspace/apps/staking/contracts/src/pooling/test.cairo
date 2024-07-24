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
    test_utils::{
        initialize_pooling_state, deploy_mock_erc20_contract, StakingInitConfig,
        deploy_staking_contract
    },
    test_utils::constants::{
        OWNER_ADDRESS, STAKER_ADDRESS, REWARD_ADDRESS, STAKE_AMOUNT, POOL_MEMBER_ADDRESS,
        STAKING_CONTRACT_ADDRESS, TOKEN_ADDRESS, INITIAL_SUPPLY, DUMMY_ADDRESS,
    }
};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use contracts::pooling::interface::IPooling;
use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
use starknet::{ContractAddress, contract_address_const};
use snforge_std::{cheat_caller_address, CheatSpan, test_address};


#[test]
fn test_calculate_rewards() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(cfg.initial_supply, cfg.owner_address);
    let mut state = initialize_pooling_state(
        cfg.staker_address, STAKING_CONTRACT_ADDRESS(), token_address
    );

    let pool_member_address: ContractAddress = POOL_MEMBER_ADDRESS();
    let updated_index: u64 = cfg.initial_index * 2;
    let mut pool_member_info = PoolMemberInfo {
        reward_address: cfg.reward_address,
        amount: cfg.stake_amount,
        index: cfg.initial_index,
        unclaimed_rewards: cfg.pool_unclaimed_rewards,
        unpool_time: Option::None,
    };
    assert!(state.calculate_rewards(:pool_member_address, ref :pool_member_info, :updated_index));
    let new_pool_member_info = state.pool_member_address_to_info.read(pool_member_address);
    assert_eq!(new_pool_member_info.unclaimed_rewards, cfg.stake_amount);
    assert_eq!(new_pool_member_info.index, cfg.initial_index * 2)
}

// TODO(alon, 24/07/2024): Complete this function.
#[test]
fn test_enter_delegation_pool() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(cfg.initial_supply, cfg.owner_address);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    // Transfer the stake amount to the pool member.
    cheat_caller_address(token_address, cfg.owner_address, CheatSpan::TargetCalls(1));
    erc20_dispatcher.transfer(recipient: POOL_MEMBER_ADDRESS(), amount: cfg.stake_amount.into());
    // Deploy the staking contract and initialize the pooling state.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let mut state = initialize_pooling_state(cfg.staker_address, staking_contract, token_address);
    // Approve the pooling contract to transfer the pool member's funds.
    cheat_caller_address(token_address, POOL_MEMBER_ADDRESS(), CheatSpan::TargetCalls(1));
    erc20_dispatcher.approve(spender: test_address(), amount: cfg.stake_amount.into());
    // Enter the delegation pool.
    cheat_caller_address(test_address(), POOL_MEMBER_ADDRESS(), CheatSpan::TargetCalls(1));
    assert!(
        state.enter_delegation_pool(amount: cfg.stake_amount, reward_address: cfg.reward_address)
    );
    // Check that the pool member info was updated correctly.
    let expected_pool_member_info: PoolMemberInfo = PoolMemberInfo {
        amount: cfg.stake_amount,
        index: cfg.initial_index,
        unpool_time: Option::None,
        reward_address: cfg.reward_address,
        unclaimed_rewards: cfg.pool_unclaimed_rewards,
    };
    assert_eq!(
        state.pool_member_address_to_info.read(POOL_MEMBER_ADDRESS()), expected_pool_member_info
    );
// TODO: Check that the index was updated correctly.
// TODO: Check that the funds were transferred correctly.
}

#[test]
fn test_assert_staker_is_active() {
    let mut state = initialize_pooling_state(
        STAKER_ADDRESS(), STAKING_CONTRACT_ADDRESS(), TOKEN_ADDRESS()
    );
    assert!(state.final_staker_index.read().is_none());
    state.assert_staker_is_active();
}

#[test]
#[should_panic(expected: ("Staker is inactive.",))]
fn test_assert_staker_is_active_panic() {
    let mut state = initialize_pooling_state(
        STAKER_ADDRESS(), STAKING_CONTRACT_ADDRESS(), TOKEN_ADDRESS()
    );
    state.final_staker_index.write(Option::Some(5));
    state.assert_staker_is_active();
}

