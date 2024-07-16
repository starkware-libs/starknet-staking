use contracts::{BASE_VALUE, staking::Staking, pooling::Pooling};
use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
use core::traits::Into;
use contracts::staking::interface::IStaking;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::{ContractAddress, contract_address_const, get_caller_address};
use starknet::syscalls::deploy_syscall;
use snforge_std::{declare, ContractClassTrait};
use contracts::staking::staking::Staking::ContractState;
use constants::{
    NAME, SYMBOL, INITIAL_SUPPLY, OWNER_ADDRESS, MIN_STAKE, MAX_LEVERAGE, AMOUNT_TO_STAKER,
    STAKE_AMOUNT, STAKER_ADDRESS, OPERATIONAL_ADDRESS, REWARD_ADDRESS, TOKEN_ADDRESS, REV_SHARE,
};

pub(crate) mod constants {
    use starknet::{ContractAddress, contract_address_const};

    pub const AMOUNT_TO_STAKER: u128 = 10000000000;
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
    pub fn OPERATIONAL_ADDRESS() -> ContractAddress {
        contract_address_const::<'OPERATIONAL_ADDRESS'>()
    }
    pub fn OWNER_ADDRESS() -> ContractAddress {
        contract_address_const::<'OWNER_ADDRESS'>()
    }
    pub fn POOLING_ADDRESS() -> ContractAddress {
        contract_address_const::<'POOLING_ADDRESS'>()
    }
    pub fn RECIPIENT_ADDRESS() -> ContractAddress {
        contract_address_const::<'RECIPIENT_ADDRESS'>()
    }
    pub fn REWARD_ADDRESS() -> ContractAddress {
        contract_address_const::<'REWARD_ADDRESS'>()
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

pub(crate) fn initalize_staking_state() -> Staking::ContractState {
    let mut state = Staking::contract_state_for_testing();
    let token_address: ContractAddress = constants::TOKEN_ADDRESS();
    Staking::constructor(ref state, token_address, constants::MIN_STAKE, constants::MAX_LEVERAGE);
    state
}


pub(crate) fn initalize_pooling_state() -> Pooling::ContractState {
    let staker_address: ContractAddress = constants::STAKER_ADDRESS();
    let mut state = Pooling::contract_state_for_testing();
    Pooling::constructor(ref state, staker_address);
    state
}

pub(crate) fn deploy_mock_erc20_contract() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    NAME().serialize(ref calldata);
    SYMBOL().serialize(ref calldata);
    INITIAL_SUPPLY.serialize(ref calldata);
    OWNER_ADDRESS().serialize(ref calldata);

    let erc20_contract = snforge_std::declare("DualCaseERC20Mock").unwrap();
    let (token_address, _) = erc20_contract.deploy(@calldata).unwrap();
    token_address
}

pub(crate) fn init_default_stake(
    token_address: ContractAddress, pooling_enabled: bool
) -> (ContractState, IERC20Dispatcher) {
    // Use state for the Staking contract (the contract we are testing)
    // The address of this contract will always be `test_address` which is a constant.
    let mut state = Staking::contract_state_for_testing();
    let test_address: ContractAddress = snforge_std::test_address();

    // Initialize Staking contract.
    Staking::constructor(ref state, token_address, MIN_STAKE, MAX_LEVERAGE);

    // Transfer amount from initial_owner to staker.
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    snforge_std::cheat_caller_address_global(OWNER_ADDRESS());
    erc20_dispatcher.transfer(recipient: STAKER_ADDRESS(), amount: AMOUNT_TO_STAKER.into());

    // Approve the Staking contract to spend the staker's tokens.
    snforge_std::cheat_caller_address_global(STAKER_ADDRESS());
    erc20_dispatcher.approve(spender: test_address, amount: AMOUNT_TO_STAKER.into());
    snforge_std::stop_cheat_caller_address_global(); // STOP GLOBAL CALLER CHEAT

    // Cheat the caller address only for the Staking contract (which is test_address), to be the 
    // staker, and then stake.
    snforge_std::cheat_caller_address(
        test_address, STAKER_ADDRESS(), snforge_std::CheatSpan::Indefinite
    );
    let result = state
        .stake(REWARD_ADDRESS(), OPERATIONAL_ADDRESS(), STAKE_AMOUNT, pooling_enabled, REV_SHARE);
    assert_eq!(result, true);
    (state, erc20_dispatcher)
}

