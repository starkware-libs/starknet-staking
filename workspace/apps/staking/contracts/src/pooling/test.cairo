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
    utils::{compute_rewards, compute_commission},
    test_utils::{
        initialize_pooling_state, deploy_mock_erc20_contract, StakingInitConfig,
        deploy_staking_contract, fund, approve,
    },
    test_utils::constants::{
        OWNER_ADDRESS, STAKER_ADDRESS, REWARD_ADDRESS, STAKE_AMOUNT, POOL_MEMBER_ADDRESS,
        STAKING_CONTRACT_ADDRESS, TOKEN_ADDRESS, INITIAL_SUPPLY, DUMMY_ADDRESS,
        OTHER_REWARD_ADDRESS, NON_POOL_MEMBER_ADDRESS, REV_SHARE
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
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        :token_address,
        rev_share: cfg.staker_info.rev_share
    );

    let pool_member_address: ContractAddress = POOL_MEMBER_ADDRESS();
    let updated_index: u64 = cfg.staker_info.index * 2;
    let mut pool_member_info = PoolMemberInfo {
        reward_address: cfg.staker_info.reward_address,
        amount: cfg.staker_info.amount_own,
        index: cfg.staker_info.index,
        unclaimed_rewards: cfg.staker_info.unclaimed_rewards_pool,
        unpool_time: Option::None,
    };
    let interest = updated_index - pool_member_info.index;
    let rewards = compute_rewards(amount: pool_member_info.amount, :interest);
    let commission = compute_commission(:rewards, rev_share: cfg.staker_info.rev_share);
    let unclaimed_rewards = rewards - commission;
    assert!(state.calculate_rewards(:pool_member_address, ref :pool_member_info, :updated_index));

    let mut expected_pool_member_info = PoolMemberInfo {
        index: cfg.staker_info.index * 2, unclaimed_rewards, ..pool_member_info
    };
    assert_eq!(pool_member_info, expected_pool_member_info);
}

// TODO(alon, 24/07/2024): Complete this function.
#[test]
fn test_enter_delegation_pool() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    // Transfer the stake amount to the pool member.
    cheat_caller_address(token_address, cfg.test_info.owner_address, CheatSpan::TargetCalls(1));
    erc20_dispatcher
        .transfer(recipient: POOL_MEMBER_ADDRESS(), amount: cfg.staker_info.amount_own.into());
    // Deploy the staking contract and initialize the pooling state.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        :staking_contract,
        :token_address,
        rev_share: cfg.staker_info.rev_share
    );
    // Approve the pooling contract to transfer the pool member's funds.
    cheat_caller_address(token_address, POOL_MEMBER_ADDRESS(), CheatSpan::TargetCalls(1));
    erc20_dispatcher.approve(spender: test_address(), amount: cfg.staker_info.amount_own.into());
    // Enter the delegation pool.
    cheat_caller_address(test_address(), POOL_MEMBER_ADDRESS(), CheatSpan::TargetCalls(1));
    assert!(
        state
            .enter_delegation_pool(
                amount: cfg.staker_info.amount_own, reward_address: cfg.staker_info.reward_address
            )
    );
    // Check that the pool member info was updated correctly.
    let expected_pool_member_info: PoolMemberInfo = PoolMemberInfo {
        amount: cfg.staker_info.amount_own,
        index: cfg.staker_info.index,
        unpool_time: Option::None,
        reward_address: cfg.staker_info.reward_address,
        unclaimed_rewards: cfg.staker_info.unclaimed_rewards_pool,
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
        staker_address: STAKER_ADDRESS(),
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: TOKEN_ADDRESS(),
        rev_share: REV_SHARE
    );
    assert!(state.final_staker_index.read().is_none());
    state.assert_staker_is_active();
}

#[test]
#[should_panic(expected: ("Staker is inactive.",))]
fn test_assert_staker_is_active_panic() {
    let mut state = initialize_pooling_state(
        staker_address: STAKER_ADDRESS(),
        staking_contract: STAKING_CONTRACT_ADDRESS(),
        token_address: TOKEN_ADDRESS(),
        rev_share: REV_SHARE
    );
    state.final_staker_index.write(Option::Some(5));
    state.assert_staker_is_active();
}

#[test]
fn test_change_reward_address() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        :staking_contract,
        :token_address,
        rev_share: cfg.staker_info.rev_share
    );
    fund(
        sender: cfg.test_info.owner_address,
        recipient: POOL_MEMBER_ADDRESS(),
        amount: cfg.test_info.staker_initial_balance,
        :token_address
    );
    approve(
        owner: POOL_MEMBER_ADDRESS(),
        spender: test_address(),
        amount: cfg.test_info.staker_initial_balance,
        :token_address
    );
    cheat_caller_address(test_address(), POOL_MEMBER_ADDRESS(), CheatSpan::TargetCalls(1));
    state
        .enter_delegation_pool(
            amount: cfg.test_info.staker_initial_balance,
            reward_address: cfg.staker_info.reward_address
        );
    let pool_member_info_before_change = state
        .pool_member_address_to_info
        .read(POOL_MEMBER_ADDRESS());
    let other_reward_address = OTHER_REWARD_ADDRESS();

    cheat_caller_address(test_address(), POOL_MEMBER_ADDRESS(), CheatSpan::TargetCalls(1));
    state.change_reward_address(other_reward_address);
    let pool_member_info_after_change = state
        .pool_member_address_to_info
        .read(POOL_MEMBER_ADDRESS());
    let pool_member_info_expected = PoolMemberInfo {
        reward_address: other_reward_address, ..pool_member_info_before_change
    };
    assert_eq!(pool_member_info_after_change, pool_member_info_expected);
}


#[test]
#[should_panic(expected: "Pool member does not exist.")]
fn test_change_reward_address_pool_member_not_exist() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
    let mut state = initialize_pooling_state(
        staker_address: cfg.test_info.staker_address,
        :staking_contract,
        :token_address,
        rev_share: cfg.staker_info.rev_share
    );
    cheat_caller_address(test_address(), NON_POOL_MEMBER_ADDRESS(), CheatSpan::TargetCalls(1));
    // Reward address is arbitrary because it should fail because of the caller.
    state.change_reward_address(reward_address: DUMMY_ADDRESS());
}
