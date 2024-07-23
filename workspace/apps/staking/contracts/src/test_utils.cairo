use contracts::{BASE_VALUE, staking::Staking, pooling::Pooling};
use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
use core::traits::Into;
use contracts::staking::interface::IStaking;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::{ContractAddress, contract_address_const, get_caller_address};
use starknet::syscalls::deploy_syscall;
use snforge_std::{declare, ContractClassTrait};
use contracts::staking::Staking::ContractState;
use constants::{
    NAME, SYMBOL, INITIAL_SUPPLY, OWNER_ADDRESS, MIN_STAKE, MAX_LEVERAGE, STAKER_INITIAL_BALANCE,
    STAKE_AMOUNT, STAKER_ADDRESS, OPERATIONAL_ADDRESS, REWARD_ADDRESS, TOKEN_ADDRESS, REV_SHARE,
    POOLING_CONTRACT_ADDRESS
};

pub(crate) mod constants {
    use starknet::{ContractAddress, contract_address_const};

    pub const STAKER_INITIAL_BALANCE: u128 = 10000000000;
    pub const INITIAL_SUPPLY: u256 = 10000000000000000;
    pub const MAX_LEVERAGE: u64 = 100;
    pub const MIN_STAKE: u128 = 100000;
    pub const STAKE_AMOUNT: u128 = 200000;
    pub const REV_SHARE: u8 = 5;

    pub fn CALLER_ADDRESS() -> ContractAddress {
        contract_address_const::<'CALLER_ADDRESS'>()
    }
    pub fn DUMMY_ADDRESS() -> ContractAddress {
        contract_address_const::<'DUMMY_ADDRESS'>()
    }
    pub fn STAKER_ADDRESS() -> ContractAddress {
        contract_address_const::<'STAKER_ADDRESS'>()
    }
    pub fn NON_STAKER_ADDRESS() -> ContractAddress {
        contract_address_const::<'NON_STAKER_ADDRESS'>()
    }
    pub fn POOL_MEMBER_ADDRESS() -> ContractAddress {
        contract_address_const::<'POOL_MEMBER_ADDRESS'>()
    }
    pub fn OTHER_STAKER_ADDRESS() -> ContractAddress {
        contract_address_const::<'OTHER_STAKER_ADDRESS'>()
    }
    pub fn OPERATIONAL_ADDRESS() -> ContractAddress {
        contract_address_const::<'OPERATIONAL_ADDRESS'>()
    }
    pub fn OWNER_ADDRESS() -> ContractAddress {
        contract_address_const::<'OWNER_ADDRESS'>()
    }
    pub fn STAKING_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<'STAKING_CONTRACT_ADDRESS'>()
    }
    pub fn POOLING_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<'POOLING_CONTRACT_ADDRESS'>()
    }
    pub fn RECIPIENT_ADDRESS() -> ContractAddress {
        contract_address_const::<'RECIPIENT_ADDRESS'>()
    }
    pub fn REWARD_ADDRESS() -> ContractAddress {
        contract_address_const::<'REWARD_ADDRESS'>()
    }
    pub fn OTHER_REWARD_ADDRESS() -> ContractAddress {
        contract_address_const::<'OTHER_REWARD_ADDRESS'>()
    }
    pub fn SPENDER_ADDRESS() -> ContractAddress {
        contract_address_const::<'SPENDER_ADDRESS'>()
    }
    pub fn STRK_TOKEN_ADDRESS() -> ContractAddress {
        contract_address_const::<
            0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
        >()
    }
    pub fn TOKEN_ADDRESS() -> ContractAddress {
        contract_address_const::<'TOKEN_ADDRESS'>()
    }
    pub fn NAME() -> ByteArray {
        "NAME"
    }

    pub fn SYMBOL() -> ByteArray {
        "SYMBOL"
    }
}

pub(crate) fn initialize_staking_state(
    token_address: ContractAddress, min_stake: u128, max_leverage: u64
) -> Staking::ContractState {
    let mut state = Staking::contract_state_for_testing();
    Staking::constructor(ref state, token_address, min_stake, max_leverage);
    state
}


pub(crate) fn initialize_pooling_state(
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    token_address: ContractAddress
) -> Pooling::ContractState {
    let mut state = Pooling::contract_state_for_testing();
    Pooling::constructor(ref state, :staker_address, :staking_contract, :token_address);
    state
}

pub(crate) fn deploy_mock_erc20_contract(
    initial_supply: u256, owner_address: ContractAddress
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    NAME().serialize(ref calldata);
    SYMBOL().serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    owner_address.serialize(ref calldata);
    let erc20_contract = snforge_std::declare("DualCaseERC20Mock").unwrap();
    let (token_address, _) = erc20_contract.deploy(@calldata).unwrap();
    token_address
}

pub(crate) fn deploy_staking_contract(
    token_address: ContractAddress, cfg: StakingInitConfig
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    token_address.serialize(ref calldata);
    cfg.min_stake.serialize(ref calldata);
    cfg.max_leverage.serialize(ref calldata);
    let staking_contract = snforge_std::declare("Staking").unwrap();
    let (staking_contract_address, _) = staking_contract.deploy(@calldata).unwrap();
    staking_contract_address
}

pub(crate) fn init_stake(
    token_address: ContractAddress, cfg: StakingInitConfig
) -> (ContractState, IERC20Dispatcher) {
    // Use state for the Staking contract (the contract we are testing)
    // The address of this contract will always be `test_address` which is a constant.
    let mut state = Staking::contract_state_for_testing();
    let test_address: ContractAddress = snforge_std::test_address();
    // Initialize Staking contract.
    Staking::constructor(ref state, token_address, cfg.min_stake, cfg.max_leverage);
    // Transfer amount from initial_owner to staker.
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    snforge_std::cheat_caller_address_global(cfg.owner_address);
    erc20_dispatcher
        .transfer(recipient: cfg.staker_address, amount: cfg.staker_initial_balance.into());
    // Approve the Staking contract to spend the staker's tokens.
    snforge_std::cheat_caller_address_global(cfg.staker_address);
    erc20_dispatcher.approve(spender: test_address, amount: cfg.staker_initial_balance.into());
    snforge_std::stop_cheat_caller_address_global(); // STOP GLOBAL CALLER CHEAT
    // Cheat the caller address only for the Staking contract (which is test_address), to be the
    // staker, and then stake.
    snforge_std::cheat_caller_address(
        test_address, cfg.staker_address, snforge_std::CheatSpan::Indefinite
    );
    let result = state
        .stake(
            cfg.reward_address,
            cfg.operational_address,
            cfg.stake_amount,
            cfg.pooling_enabled,
            cfg.rev_share
        );
    snforge_std::stop_cheat_caller_address(test_address); // STOP CALLER CHEAT
    assert_eq!(result, true);
    (state, erc20_dispatcher)
}

#[derive(Drop, Copy)]
pub(crate) struct StakingInitConfig {
    pub staker_address: ContractAddress,
    pub owner_address: ContractAddress,
    pub reward_address: ContractAddress,
    pub operational_address: ContractAddress,
    pub min_stake: u128,
    pub max_leverage: u64,
    pub staker_initial_balance: u128,
    pub stake_amount: u128,
    pub rev_share: u8,
    pub pooling_enabled: bool,
    pub pooling_address: Option<ContractAddress>,
}

impl StakingInitConfigDefault of Default<StakingInitConfig> {
    fn default() -> StakingInitConfig {
        StakingInitConfig {
            staker_address: STAKER_ADDRESS(),
            owner_address: OWNER_ADDRESS(),
            reward_address: REWARD_ADDRESS(),
            operational_address: OPERATIONAL_ADDRESS(),
            min_stake: MIN_STAKE,
            max_leverage: MAX_LEVERAGE,
            staker_initial_balance: STAKER_INITIAL_BALANCE,
            stake_amount: STAKE_AMOUNT,
            rev_share: REV_SHARE,
            pooling_enabled: false,
            pooling_address: Option::None
        }
    }
}

