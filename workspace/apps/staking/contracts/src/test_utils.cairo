use contracts::{BASE_VALUE, staking::Staking, pooling::Pooling, minting_curve::MintingCurve};
use core::traits::Into;
use contracts::staking::interface::{IStaking, StakerInfo, StakingContractInfo};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::{ContractAddress, contract_address_const, get_caller_address};
use starknet::syscalls::deploy_syscall;
use starknet::ClassHash;
use snforge_std::{declare, ContractClassTrait};
use contracts::staking::Staking::ContractState;
use constants::{
    NAME, SYMBOL, INITIAL_SUPPLY, OWNER_ADDRESS, MIN_STAKE, MAX_LEVERAGE, STAKER_INITIAL_BALANCE,
    STAKE_AMOUNT, STAKER_ADDRESS, OPERATIONAL_ADDRESS, REWARD_ADDRESS, TOKEN_ADDRESS, REV_SHARE,
    POOLING_CONTRACT_ADDRESS, POOL_AMOUNT, DUMMY_CLASS_HASH
};
use snforge_std::{ContractClass, CheatSpan, cheat_caller_address, test_address};
pub(crate) mod constants {
    use starknet::{ContractAddress, contract_address_const};
    use starknet::class_hash::{ClassHash, class_hash_const};

    pub const STAKER_INITIAL_BALANCE: u128 = 10000000000;
    pub const INITIAL_SUPPLY: u256 = 10000000000000000;
    pub const MAX_LEVERAGE: u64 = 100;
    pub const MIN_STAKE: u128 = 100000;
    pub const STAKE_AMOUNT: u128 = 200000;
    pub const POOL_AMOUNT: u128 = 100000;
    pub const REV_SHARE: u16 = 500;

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
    pub fn NON_POOL_MEMBER_ADDRESS() -> ContractAddress {
        contract_address_const::<'NON_POOL_MEMBER_ADDRESS'>()
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

    pub fn DUMMY_CLASS_HASH() -> ClassHash {
        class_hash_const::<'DUMMY'>()
    }
}
pub(crate) fn initialize_staking_state_from_cfg(
    token_address: ContractAddress, cfg: StakingInitConfig
) -> Staking::ContractState {
    initialize_staking_state(
        :token_address,
        min_stake: cfg.staking_contract_info.min_stake,
        max_leverage: cfg.staking_contract_info.max_leverage,
        pool_contract_class_hash: cfg.test_info.pool_contract_class_hash
    )
}
pub(crate) fn initialize_staking_state(
    token_address: ContractAddress,
    min_stake: u128,
    max_leverage: u64,
    pool_contract_class_hash: ClassHash
) -> Staking::ContractState {
    let mut state = Staking::contract_state_for_testing();
    Staking::constructor(
        ref state, token_address, min_stake, max_leverage, pool_contract_class_hash
    );
    state
}


pub(crate) fn initialize_pooling_state(
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    token_address: ContractAddress,
    rev_share: u16
) -> Pooling::ContractState {
    let mut state = Pooling::contract_state_for_testing();
    Pooling::constructor(ref state, :staker_address, :staking_contract, :token_address, :rev_share);
    state
}

pub(crate) fn initialize_minting_curve_state(
    staking_contract: ContractAddress, total_supply: u128
) -> MintingCurve::ContractState {
    let mut state = MintingCurve::contract_state_for_testing();
    MintingCurve::constructor(ref state, staking_contract, total_supply);
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
    cfg.staking_contract_info.min_stake.serialize(ref calldata);
    cfg.staking_contract_info.max_leverage.serialize(ref calldata);
    cfg.test_info.pool_contract_class_hash.serialize(ref calldata);
    let staking_contract = snforge_std::declare("Staking").unwrap();
    let (staking_contract_address, _) = staking_contract.deploy(@calldata).unwrap();
    staking_contract_address
}

pub(crate) fn declare_pool_contract() -> ClassHash {
    snforge_std::declare("Pooling").unwrap().class_hash
}

pub(crate) fn fund(
    sender: ContractAddress,
    recipient: ContractAddress,
    amount: u128,
    token_address: ContractAddress
) {
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    cheat_caller_address(token_address, sender, CheatSpan::TargetCalls(1));
    erc20_dispatcher.transfer(:recipient, amount: amount.into());
}

pub(crate) fn approve(
    owner: ContractAddress, spender: ContractAddress, amount: u128, token_address: ContractAddress
) {
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    cheat_caller_address(token_address, owner, CheatSpan::TargetCalls(1));
    erc20_dispatcher.approve(:spender, amount: amount.into());
}

// Stake according to the given configuration, the staker is cfg.test_info.staker_address.
pub(crate) fn stake_for_testing(
    ref state: ContractState, cfg: StakingInitConfig, token_address: ContractAddress
) {
    fund(
        sender: cfg.test_info.owner_address,
        recipient: cfg.test_info.staker_address,
        amount: cfg.test_info.staker_initial_balance,
        :token_address
    );
    approve(
        owner: cfg.test_info.staker_address,
        spender: test_address(),
        amount: cfg.test_info.staker_initial_balance,
        :token_address
    );
    cheat_caller_address(test_address(), cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    state
        .stake(
            cfg.staker_info.reward_address,
            cfg.staker_info.operational_address,
            cfg.staker_info.amount_own,
            cfg.test_info.pooling_enabled,
            cfg.staker_info.rev_share
        );
}

#[derive(Drop, Copy)]
pub(crate) struct TestInfo {
    pub staker_address: ContractAddress,
    pub owner_address: ContractAddress,
    pub initial_supply: u256,
    pub staker_initial_balance: u128,
    pub pooling_enabled: bool,
    pub pool_contract_class_hash: ClassHash,
}

#[derive(Drop, Copy)]
pub(crate) struct StakingInitConfig {
    pub staker_info: StakerInfo,
    pub staking_contract_info: StakingContractInfo,
    pub test_info: TestInfo,
}

impl StakingInitConfigDefault of Default<StakingInitConfig> {
    fn default() -> StakingInitConfig {
        let staker_info = StakerInfo {
            reward_address: REWARD_ADDRESS(),
            operational_address: OPERATIONAL_ADDRESS(),
            pooling_contract: Option::None,
            unstake_time: Option::None,
            amount_own: STAKE_AMOUNT,
            amount_pool: 0,
            index: BASE_VALUE,
            unclaimed_rewards_own: 0,
            unclaimed_rewards_pool: 0,
            rev_share: REV_SHARE,
        };
        let staking_contract_info = StakingContractInfo {
            max_leverage: MAX_LEVERAGE,
            min_stake: MIN_STAKE,
            token_address: TOKEN_ADDRESS(),
            global_index: BASE_VALUE,
        };
        let test_info = TestInfo {
            staker_address: STAKER_ADDRESS(),
            owner_address: OWNER_ADDRESS(),
            initial_supply: INITIAL_SUPPLY,
            staker_initial_balance: STAKER_INITIAL_BALANCE,
            pooling_enabled: false,
            pool_contract_class_hash: DUMMY_CLASS_HASH(),
        };
        StakingInitConfig { staker_info, staking_contract_info, test_info, }
    }
}
