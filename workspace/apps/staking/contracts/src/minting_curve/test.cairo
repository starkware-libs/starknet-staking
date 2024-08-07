use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use contracts::minting_curve::interface::IMintingCurve;
use contracts::minting_curve::MintingCurve;
use contracts::minting_curve::MintingCurve::compute_yearly_mint;
use contracts::test_utils::{
    initialize_minting_curve_state, deploy_staking_contract, deploy_mock_erc20_contract, fund,
    approve, StakingInitConfig, constants::{L1_STAKING_MINTER_ADDRESS},
};
use snforge_std::{cheat_caller_address, CheatSpan, test_address};
use core::integer::u256_sqrt;

#[test]
fn test_yearly_mint() {
    let cfg: StakingInitConfig = Default::default();
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address
    );

    let staking_contract = deploy_staking_contract(token_address, cfg);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let total_supply: u128 = 10000000000;
    let mut state = initialize_minting_curve_state(
        :staking_contract, :total_supply, l1_staking_minter_address: L1_STAKING_MINTER_ADDRESS
    );
    fund(
        sender: cfg.test_info.owner_address,
        recipient: cfg.test_info.staker_address,
        amount: cfg.test_info.staker_initial_balance,
        :token_address
    );
    approve(
        owner: cfg.test_info.staker_address,
        spender: staking_contract,
        amount: cfg.test_info.staker_initial_balance,
        :token_address
    );
    cheat_caller_address(staking_contract, cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    staking_dispatcher
        .stake(
            reward_address: cfg.staker_info.reward_address,
            operational_address: cfg.staker_info.operational_address,
            amount: cfg.staker_info.amount_own,
            pooling_enabled: cfg.test_info.pooling_enabled,
            rev_share: cfg.staker_info.rev_share
        );

    let expected_minted_tokens: u128 = compute_yearly_mint(
        total_stake: cfg.staker_info.amount_own, :total_supply
    );
    let minted_tokens = state.yearly_mint();
    assert_eq!(minted_tokens, expected_minted_tokens);
}
