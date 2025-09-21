use constants::{
    APP_GOVERNOR, APP_ROLE_ADMIN, ATTESTATION_CONTRACT_ADDRESS, BASE_MINT_AMOUNT, BTC_BASE_VALUE_18,
    BTC_BASE_VALUE_8, BTC_DECIMALS_18, BTC_DECIMALS_8, BTC_POOL_MEMBER_STAKE_AMOUNT,
    BTC_TOKEN_ADDRESS, BTC_TOKEN_NAME, BUFFER, COMMISSION, DEFAULT_EPOCH_INFO, DUMMY_CLASS_HASH,
    EPOCH_LENGTH, EPOCH_STARTING_BLOCK, GOVERNANCE_ADMIN, INITIAL_SUPPLY, L1_REWARD_SUPPLIER,
    MINTING_CONTRACT_ADDRESS, MIN_BTC_FOR_REWARDS_18, MIN_BTC_FOR_REWARDS_8, MIN_STAKE,
    OPERATIONAL_ADDRESS, OWNER_ADDRESS, POOL_CONTRACT_ADDRESS, POOL_CONTRACT_ADMIN,
    POOL_MEMBER_ADDRESS, POOL_MEMBER_INITIAL_BALANCE, POOL_MEMBER_REWARD_ADDRESS,
    POOL_MEMBER_STAKE_AMOUNT, PUBLIC_KEY, REWARD_SUPPLIER_CONTRACT_ADDRESS, SECURITY_ADMIN,
    SECURITY_AGENT, STAKER_ADDRESS, STAKER_INITIAL_BALANCE, STAKER_REWARD_ADDRESS, STAKE_AMOUNT,
    STAKING_CONTRACT_ADDRESS, STARKGATE_ADDRESS, STRK_BASE_VALUE, TOKEN_ADMIN, UPGRADE_GOVERNOR,
};
use core::hash::HashStateTrait;
use core::num::traits::Pow;
use core::num::traits::zero::Zero;
use core::panics::panic_with_byte_array;
use core::poseidon::PoseidonTrait;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use snforge_std::{
    CheatSpan, ContractClassTrait, CustomToken, DeclareResultTrait, Token, TokenImpl, TokenTrait,
    cheat_caller_address, set_balance, start_cheat_block_hash_global,
    start_cheat_block_number_global, test_address,
};
use staking::attestation::attestation::Attestation::MIN_ATTESTATION_WINDOW;
use staking::attestation::interface::{IAttestationDispatcher, IAttestationDispatcherTrait};
use staking::constants::{K, STARTING_EPOCH, STRK_IN_FRIS, STRK_TOKEN_ADDRESS};
use staking::errors::GenericError;
use staking::minting_curve::interface::{
    IMintingCurveDispatcher, IMintingCurveDispatcherTrait, MintingCurveContractInfo,
};
use staking::minting_curve::minting_curve::MintingCurve;
use staking::minting_curve::minting_curve::MintingCurve::{C_DENOM, DEFAULT_C_NUM};
use staking::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait};
use staking::pool::interface_v0::PoolMemberInfo;
use staking::pool::pool::Pool;
use staking::pool::pool::Pool::STRK_CONFIG;
use staking::pool::pool_member_balance_trace::trace::PoolMemberCheckpointTrait;
use staking::reward_supplier::reward_supplier::RewardSupplier;
use staking::staking::errors::Error as StakingError;
use staking::staking::interface::{
    IStakingDispatcher, IStakingDispatcherTrait, IStakingPauseDispatcher,
    IStakingPauseDispatcherTrait, IStakingTokenManagerDispatcher,
    IStakingTokenManagerDispatcherTrait, StakerInfoV1, StakerInfoV1Trait, StakerPoolInfoV1,
};
use staking::staking::objects::{
    EpochInfo, EpochInfoTrait, InternalStakerInfoLatestTestTrait, NormalizedAmount,
    NormalizedAmountTrait,
};
use staking::staking::staking::Staking;
use staking::staking::staking::Staking::DEFAULT_EXIT_WAIT_WINDOW;
use staking::types::{
    Amount, Commission, Index, InternalPoolMemberInfoLatest, InternalStakerInfoLatest,
    InternalStakerPoolInfoLatest, PublicKey,
};
use staking::utils::{
    compute_commission_amount_rounded_down, compute_commission_amount_rounded_up,
    compute_rewards_rounded_down,
};
use starknet::{ClassHash, ContractAddress, Store};
use starkware_utils::constants::SYMBOL;
use starkware_utils::errors::{Describable, OptionAuxTrait};
use starkware_utils::math::utils::mul_wide_and_div;
use starkware_utils::time::time::{TimeDelta, Timestamp};
use starkware_utils_testing::test_utils::{
    advance_block_number_global, cheat_caller_address_once, set_account_as_app_governor,
    set_account_as_app_role_admin, set_account_as_security_admin, set_account_as_security_agent,
    set_account_as_token_admin, set_account_as_upgrade_governor,
};

pub(crate) mod constants {
    use core::cmp::max;
    use core::num::traits::ops::pow::Pow;
    use staking::constants::STRK_IN_FRIS;
    use staking::staking::objects::{EpochInfo, EpochInfoTrait};
    use staking::types::{Amount, BlockNumber, Commission, Index, PublicKey};
    use starknet::class_hash::ClassHash;
    use starknet::{ContractAddress, get_block_number};
    use starkware_utils::time::time::Timestamp;

    /// STRK rewards constants.
    pub const STRK_BASE_VALUE: Index = 10_000_000_000_000_000_000_000_000_000; // 10**28
    pub const STRK_DECIMALS: u8 = 18;

    /// BTC (decimals = 8) rewards constants.
    pub const BTC_DECIMALS_8: u8 = 8;
    pub const MIN_BTC_FOR_REWARDS_8: Amount = 10_u128.pow(3);
    pub const BTC_BASE_VALUE_8: Index = 10_u128.pow(13);

    /// BTC (decimals = 18) rewards constants.
    pub const BTC_DECIMALS_18: u8 = 18;
    pub const MIN_BTC_FOR_REWARDS_18: Amount = 10_u128.pow(13);
    pub const BTC_BASE_VALUE_18: Index = 10_u128.pow(23);

    pub const TEST_BTC_DECIMALS: u8 = BTC_DECIMALS_8;
    pub const TEST_BTC_BASE_VALUE: u128 = BTC_BASE_VALUE_8;
    pub const TEST_MIN_BTC_FOR_REWARDS: Amount = MIN_BTC_FOR_REWARDS_8;
    pub const STAKER_INITIAL_BALANCE: Amount = 1000000 * STRK_IN_FRIS;
    pub const POOL_MEMBER_INITIAL_BALANCE: Amount = 10000 * STRK_IN_FRIS;
    pub const INITIAL_SUPPLY: Amount = 10000000000 * STRK_IN_FRIS;
    pub const MIN_STAKE: Amount = 20000 * STRK_IN_FRIS;
    pub const STAKE_AMOUNT: Amount = 100000 * STRK_IN_FRIS;
    pub const POOL_MEMBER_STAKE_AMOUNT: Amount = 1000 * STRK_IN_FRIS;
    pub const BTC_POOL_MEMBER_STAKE_AMOUNT: Amount = 1000 * TEST_MIN_BTC_FOR_REWARDS;
    pub const COMMISSION: Commission = 500;
    pub const STAKER_FINAL_INDEX: Index = 10;
    pub const BASE_MINT_AMOUNT: Amount = 1_300_000 * STRK_IN_FRIS;
    pub const BUFFER: Amount = 1000000000000;
    pub const L1_REWARD_SUPPLIER: felt252 = 'L1_REWARD_SUPPLIER';
    pub const DUMMY_IDENTIFIER: felt252 = 'DUMMY_IDENTIFIER';
    pub const POOL_MEMBER_UNCLAIMED_REWARDS: u128 = 10000000;
    pub const STAKER_UNCLAIMED_REWARDS: u128 = 10000000;
    /// number of blocks in one epoch
    pub const EPOCH_LENGTH: u32 = 300;
    pub const EPOCH_STARTING_BLOCK: BlockNumber = 463476;
    /// duration of  one epoch in seconds
    pub const EPOCH_DURATION: u32 = 9000;
    pub const STARTING_BLOCK_OFFSET: u64 = 0;
    pub(crate) const UNPOOL_TIME: Timestamp = Timestamp { seconds: 1 };
    pub(crate) const TEST_ONE_BTC: Amount = 10_u128.pow(TEST_BTC_DECIMALS.into());


    pub fn CALLER_ADDRESS() -> ContractAddress {
        'CALLER_ADDRESS'.try_into().unwrap()
    }
    pub fn DUMMY_ADDRESS() -> ContractAddress {
        'DUMMY_ADDRESS'.try_into().unwrap()
    }
    pub fn STAKER_ADDRESS() -> ContractAddress {
        'STAKER_ADDRESS'.try_into().unwrap()
    }
    pub fn NON_STAKER_ADDRESS() -> ContractAddress {
        'NON_STAKER_ADDRESS'.try_into().unwrap()
    }
    pub fn POOL_MEMBER_ADDRESS() -> ContractAddress {
        'POOL_MEMBER_ADDRESS'.try_into().unwrap()
    }
    pub fn OTHER_POOL_MEMBER_ADDRESS() -> ContractAddress {
        'OTHER_POOL_MEMBER_ADDRESS'.try_into().unwrap()
    }
    pub fn NON_POOL_MEMBER_ADDRESS() -> ContractAddress {
        'NON_POOL_MEMBER_ADDRESS'.try_into().unwrap()
    }
    pub fn OTHER_STAKER_ADDRESS() -> ContractAddress {
        'OTHER_STAKER_ADDRESS'.try_into().unwrap()
    }
    pub fn BTC_STAKER_ADDRESS() -> ContractAddress {
        'BTC_STAKER_ADDRESS'.try_into().unwrap()
    }
    pub fn OPERATIONAL_ADDRESS() -> ContractAddress {
        'OPERATIONAL_ADDRESS'.try_into().unwrap()
    }
    pub fn OTHER_OPERATIONAL_ADDRESS() -> ContractAddress {
        'OTHER_OPERATIONAL_ADDRESS'.try_into().unwrap()
    }
    pub fn OWNER_ADDRESS() -> ContractAddress {
        'OWNER_ADDRESS'.try_into().unwrap()
    }
    pub fn GOVERNANCE_ADMIN() -> ContractAddress {
        'GOVERNANCE_ADMIN'.try_into().unwrap()
    }
    pub fn STAKING_CONTRACT_ADDRESS() -> ContractAddress {
        'STAKING_CONTRACT_ADDRESS'.try_into().unwrap()
    }
    pub fn NOT_STAKING_CONTRACT_ADDRESS() -> ContractAddress {
        'NOT_STAKING_CONTRACT_ADDRESS'.try_into().unwrap()
    }
    pub fn POOL_CONTRACT_ADDRESS() -> ContractAddress {
        'POOL_CONTRACT_ADDRESS'.try_into().unwrap()
    }
    pub fn OTHER_POOL_CONTRACT_ADDRESS() -> ContractAddress {
        'OTHER_POOL_CONTRACT_ADDRESS'.try_into().unwrap()
    }
    pub fn MINTING_CONTRACT_ADDRESS() -> ContractAddress {
        'MINTING_CONTRACT_ADDRESS'.try_into().unwrap()
    }
    pub fn REWARD_SUPPLIER_CONTRACT_ADDRESS() -> ContractAddress {
        'REWARD_SUPPLIER_ADDRESS'.try_into().unwrap()
    }
    pub fn OTHER_REWARD_SUPPLIER_CONTRACT_ADDRESS() -> ContractAddress {
        'OTHER_REWARD_SUPPLIER_ADDRESS'.try_into().unwrap()
    }
    pub fn RECIPIENT_ADDRESS() -> ContractAddress {
        'RECIPIENT_ADDRESS'.try_into().unwrap()
    }
    pub fn STAKER_REWARD_ADDRESS() -> ContractAddress {
        'STAKER_REWARD_ADDRESS'.try_into().unwrap()
    }
    pub fn POOL_MEMBER_REWARD_ADDRESS() -> ContractAddress {
        'POOL_MEMBER_REWARD_ADDRESS'.try_into().unwrap()
    }
    pub fn POOL_REWARD_ADDRESS() -> ContractAddress {
        'POOL_REWARD_ADDRESS'.try_into().unwrap()
    }
    pub fn OTHER_REWARD_ADDRESS() -> ContractAddress {
        'OTHER_REWARD_ADDRESS'.try_into().unwrap()
    }
    pub fn SPENDER_ADDRESS() -> ContractAddress {
        'SPENDER_ADDRESS'.try_into().unwrap()
    }
    pub fn NON_TOKEN_ADMIN() -> ContractAddress {
        'NON_TOKEN_ADMIN'.try_into().unwrap()
    }
    pub fn NON_SECURITY_ADMIN() -> ContractAddress {
        'NON_SECURITY_ADMIN'.try_into().unwrap()
    }
    pub fn NON_SECURITY_AGENT() -> ContractAddress {
        'NON_SECURITY_AGENT'.try_into().unwrap()
    }
    pub fn NON_APP_GOVERNOR() -> ContractAddress {
        'NON_APP_GOVERNOR'.try_into().unwrap()
    }
    pub fn STRK_TOKEN_ADDRESS() -> ContractAddress {
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d.try_into().unwrap()
    }
    pub fn TOKEN_ADDRESS() -> ContractAddress {
        'TOKEN_ADDRESS'.try_into().unwrap()
    }
    pub fn DUMMY_CLASS_HASH() -> ClassHash {
        'DUMMY'.try_into().unwrap()
    }
    pub fn POOL_CONTRACT_ADMIN() -> ContractAddress {
        'POOL_CONTRACT_ADMIN'.try_into().unwrap()
    }
    pub fn SECURITY_ADMIN() -> ContractAddress {
        'SECURITY_ADMIN'.try_into().unwrap()
    }
    pub fn SECURITY_AGENT() -> ContractAddress {
        'SECURITY_AGENT'.try_into().unwrap()
    }
    pub fn TOKEN_ADMIN() -> ContractAddress {
        'TOKEN_ADMIN'.try_into().unwrap()
    }
    pub fn APP_ROLE_ADMIN() -> ContractAddress {
        'APP_ROLE_ADMIN'.try_into().unwrap()
    }
    pub fn UPGRADE_GOVERNOR() -> ContractAddress {
        'UPGRADE_GOVERNOR'.try_into().unwrap()
    }
    pub fn APP_GOVERNOR() -> ContractAddress {
        'APP_GOVERNOR'.try_into().unwrap()
    }
    pub fn STARKGATE_ADDRESS() -> ContractAddress {
        'STARKGATE_ADDRESS'.try_into().unwrap()
    }
    pub fn NOT_STARKGATE_ADDRESS() -> ContractAddress {
        'NOT_STARKGATE_ADDRESS'.try_into().unwrap()
    }
    pub fn ATTESTATION_CONTRACT_ADDRESS() -> ContractAddress {
        'ATTESTATION_CONTRACT_ADDRESS'.try_into().unwrap()
    }
    pub fn DEFAULT_EPOCH_INFO() -> EpochInfo {
        EpochInfoTrait::new(
            epoch_duration: EPOCH_DURATION,
            epoch_length: EPOCH_LENGTH,
            starting_block: max(EPOCH_STARTING_BLOCK, get_block_number()),
        )
    }
    pub(crate) fn MAINNET_SECURITY_COUNSEL_ADDRESS() -> ContractAddress {
        0x663cc699d9c51b7d4d434e06f5982692167546ce525d9155edb476ac9a117d6.try_into().unwrap()
    }
    pub fn BTC_TOKEN_ADDRESS() -> ContractAddress {
        'BTC_TOKEN_ADDRESS'.try_into().unwrap()
    }
    pub fn STRK_TOKEN_NAME() -> ByteArray {
        "STRK_TOKEN_NAME"
    }
    pub fn BTC_TOKEN_NAME() -> ByteArray {
        "BTC_TOKEN_NAME"
    }
    pub fn BTC_TOKEN_NAME_2() -> ByteArray {
        "BTC_TOKEN_NAME_2"
    }
    pub fn DUMMY_BTC_TOKEN_ADDRESS() -> ContractAddress {
        'DUMMY_BTC_TOKEN_ADDRESS'.try_into().unwrap()
    }
    pub fn PUBLIC_KEY() -> PublicKey {
        'PUBLIC_KEY'
    }
}
pub(crate) fn initialize_staking_state_from_cfg(
    ref cfg: StakingInitConfig,
) -> Staking::ContractState {
    initialize_staking_state(
        min_stake: cfg.staking_contract_info.min_stake,
        pool_contract_class_hash: cfg.staking_contract_info.pool_contract_class_hash,
        reward_supplier: cfg.staking_contract_info.reward_supplier,
        pool_contract_admin: cfg.test_info.pool_contract_admin,
        governance_admin: cfg.test_info.governance_admin,
        prev_class_hash: cfg.staking_contract_info.prev_staking_contract_class_hash,
        epoch_info: cfg.staking_contract_info.epoch_info,
        attestation_contract: cfg.test_info.attestation_contract,
    )
}
pub(crate) fn initialize_staking_state(
    min_stake: Amount,
    pool_contract_class_hash: ClassHash,
    reward_supplier: ContractAddress,
    pool_contract_admin: ContractAddress,
    governance_admin: ContractAddress,
    prev_class_hash: ClassHash,
    epoch_info: EpochInfo,
    attestation_contract: ContractAddress,
) -> Staking::ContractState {
    let mut state = Staking::contract_state_for_testing();
    cheat_caller_address_once(contract_address: test_address(), caller_address: test_address());
    Staking::constructor(
        ref state,
        :min_stake,
        :pool_contract_class_hash,
        :reward_supplier,
        :pool_contract_admin,
        :governance_admin,
        :prev_class_hash,
        :epoch_info,
        :attestation_contract,
    );
    state
}


pub(crate) fn initialize_pool_state(
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    token_address: ContractAddress,
    governance_admin: ContractAddress,
) -> Pool::ContractState {
    let mut state = Pool::contract_state_for_testing();
    Pool::constructor(
        ref state, :staker_address, :staking_contract, :token_address, :governance_admin,
    );
    state
}

pub(crate) fn initialize_minting_curve_state(
    staking_contract: ContractAddress,
    total_supply: Amount,
    l1_reward_supplier: felt252,
    governance_admin: ContractAddress,
) -> MintingCurve::ContractState {
    let mut state = MintingCurve::contract_state_for_testing();
    MintingCurve::constructor(
        ref state, :staking_contract, :total_supply, :l1_reward_supplier, :governance_admin,
    );
    state
}

pub(crate) fn initialize_reward_supplier_state_from_cfg(
    cfg: StakingInitConfig,
) -> RewardSupplier::ContractState {
    initialize_reward_supplier_state(
        base_mint_amount: cfg.reward_supplier.base_mint_amount,
        minting_curve_contract: cfg.reward_supplier.minting_curve_contract,
        staking_contract: cfg.test_info.staking_contract,
        l1_reward_supplier: cfg.reward_supplier.l1_reward_supplier,
        starkgate_address: cfg.reward_supplier.starkgate_address,
        governance_admin: cfg.test_info.governance_admin,
    )
}
pub(crate) fn initialize_reward_supplier_state(
    base_mint_amount: Amount,
    minting_curve_contract: ContractAddress,
    staking_contract: ContractAddress,
    l1_reward_supplier: felt252,
    starkgate_address: ContractAddress,
    governance_admin: ContractAddress,
) -> RewardSupplier::ContractState {
    let mut state = RewardSupplier::contract_state_for_testing();
    RewardSupplier::constructor(
        ref state,
        :base_mint_amount,
        :minting_curve_contract,
        :staking_contract,
        :l1_reward_supplier,
        :starkgate_address,
        :governance_admin,
    );
    state
}

pub(crate) fn deploy_mock_erc20_contract(
    initial_supply: u256, owner_address: ContractAddress, name: ByteArray,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    name.serialize(ref calldata);
    SYMBOL().serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    owner_address.serialize(ref calldata);
    let erc20_contract = snforge_std::declare("DualCaseERC20Mock").unwrap().contract_class();
    let (token_address, _) = erc20_contract.deploy(@calldata).unwrap();
    token_address
}

pub(crate) fn deploy_mock_erc20_decimals_contract(
    initial_supply: u256, owner_address: ContractAddress, name: ByteArray, decimals: u8,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    name.serialize(ref calldata);
    SYMBOL().serialize(ref calldata);
    decimals.serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    owner_address.serialize(ref calldata);
    let erc20_contract = snforge_std::declare("ERC20DecimalsMock").unwrap().contract_class();
    let (token_address, _) = erc20_contract.deploy(@calldata).unwrap();
    token_address
}

pub(crate) fn deploy_staking_contract(cfg: StakingInitConfig) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    cfg.staking_contract_info.min_stake.serialize(ref calldata);
    cfg.staking_contract_info.pool_contract_class_hash.serialize(ref calldata);
    cfg.staking_contract_info.reward_supplier.serialize(ref calldata);
    cfg.test_info.pool_contract_admin.serialize(ref calldata);
    cfg.test_info.governance_admin.serialize(ref calldata);
    cfg.staking_contract_info.prev_staking_contract_class_hash.serialize(ref calldata);
    cfg.staking_contract_info.epoch_info.serialize(ref calldata);
    cfg.test_info.attestation_contract.serialize(ref calldata);
    let staking_contract = snforge_std::declare("Staking").unwrap().contract_class();
    let (staking_contract_address, _) = staking_contract.deploy(@calldata).unwrap();
    set_default_roles(staking_contract: staking_contract_address, :cfg);
    start_cheat_block_number_global(block_number: EPOCH_STARTING_BLOCK);
    staking_contract_address
}

pub(crate) fn set_default_roles(staking_contract: ContractAddress, cfg: StakingInitConfig) {
    set_account_as_security_admin(
        contract: staking_contract,
        account: cfg.test_info.security_admin,
        governance_admin: cfg.test_info.governance_admin,
    );
    set_account_as_security_agent(
        contract: staking_contract,
        account: cfg.test_info.security_agent,
        security_admin: cfg.test_info.security_admin,
    );
    set_account_as_app_role_admin(
        contract: staking_contract,
        account: cfg.test_info.app_role_admin,
        governance_admin: cfg.test_info.governance_admin,
    );
    set_account_as_token_admin(
        contract: staking_contract,
        account: cfg.test_info.token_admin,
        app_role_admin: cfg.test_info.app_role_admin,
    );
    set_account_as_upgrade_governor(
        contract: staking_contract,
        account: cfg.test_info.upgrade_governor,
        governance_admin: cfg.test_info.governance_admin,
    );
    set_account_as_app_governor(
        contract: staking_contract,
        account: cfg.test_info.app_governor,
        app_role_admin: cfg.test_info.app_role_admin,
    );
}

pub(crate) fn deploy_minting_curve_contract(cfg: StakingInitConfig) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let initial_supply: Amount = cfg
        .test_info
        .initial_supply
        .try_into()
        .expect('initial supply does not fit');
    cfg.test_info.staking_contract.serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    cfg.reward_supplier.l1_reward_supplier.serialize(ref calldata);
    cfg.test_info.governance_admin.serialize(ref calldata);
    let minting_curve_contract = snforge_std::declare("MintingCurve").unwrap().contract_class();
    let (minting_curve_contract_address, _) = minting_curve_contract.deploy(@calldata).unwrap();
    set_account_as_app_role_admin(
        contract: minting_curve_contract_address,
        account: cfg.test_info.app_role_admin,
        governance_admin: cfg.test_info.governance_admin,
    );
    set_account_as_token_admin(
        contract: minting_curve_contract_address,
        account: cfg.test_info.token_admin,
        app_role_admin: cfg.test_info.app_role_admin,
    );
    minting_curve_contract_address
}

pub(crate) fn deploy_reward_supplier_contract(cfg: StakingInitConfig) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    cfg.reward_supplier.base_mint_amount.serialize(ref calldata);
    cfg.reward_supplier.minting_curve_contract.serialize(ref calldata);
    cfg.test_info.staking_contract.serialize(ref calldata);
    cfg.reward_supplier.l1_reward_supplier.serialize(ref calldata);
    cfg.reward_supplier.starkgate_address.serialize(ref calldata);
    cfg.test_info.governance_admin.serialize(ref calldata);
    let reward_supplier_contract = snforge_std::declare("RewardSupplier").unwrap().contract_class();
    let (reward_supplier_contract_address, _) = reward_supplier_contract.deploy(@calldata).unwrap();
    reward_supplier_contract_address
}

pub(crate) fn deploy_attestation_contract(cfg: StakingInitConfig) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    cfg.test_info.staking_contract.serialize(ref calldata);
    cfg.test_info.governance_admin.serialize(ref calldata);
    cfg.test_info.attestation_window.serialize(ref calldata);
    let attestation_contract = snforge_std::declare("Attestation").unwrap().contract_class();
    let (attestation_contract_address, _) = attestation_contract.deploy(@calldata).unwrap();
    set_account_as_app_role_admin(
        contract: attestation_contract_address,
        account: cfg.test_info.app_role_admin,
        governance_admin: cfg.test_info.governance_admin,
    );
    set_account_as_app_governor(
        contract: attestation_contract_address,
        account: cfg.test_info.app_governor,
        app_role_admin: cfg.test_info.app_role_admin,
    );
    attestation_contract_address
}

pub(crate) fn declare_pool_contract() -> ClassHash {
    *snforge_std::declare("Pool").unwrap().contract_class().class_hash
}

pub(crate) fn declare_staking_eic_contract() -> ClassHash {
    *snforge_std::declare("StakingEIC").unwrap().contract_class().class_hash
}

pub(crate) fn fund(target: ContractAddress, amount: Amount, token: Token) {
    let token_dispatcher = IERC20Dispatcher { contract_address: token.contract_address() };
    let curr_balance = token_dispatcher.balance_of(account: target);
    set_balance(:target, new_balance: curr_balance + amount.into(), :token);
}

pub(crate) fn approve(
    owner: ContractAddress,
    spender: ContractAddress,
    amount: Amount,
    token_address: ContractAddress,
) {
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    cheat_caller_address_once(contract_address: token_address, caller_address: owner);
    token_dispatcher.approve(:spender, amount: amount.into());
}

pub(crate) fn fund_and_approve_for_stake(
    cfg: StakingInitConfig, staking_contract: ContractAddress, token_address: ContractAddress,
) {
    fund(
        target: cfg.test_info.staker_address,
        amount: cfg.test_info.staker_initial_balance,
        token: cfg.test_info.strk_token,
    );
    approve(
        owner: cfg.test_info.staker_address,
        spender: staking_contract,
        amount: cfg.test_info.staker_initial_balance,
        :token_address,
    );
}

pub(crate) fn stake_for_testing_using_dispatcher(cfg: StakingInitConfig) {
    let token_address = cfg.test_info.strk_token.contract_address();
    let staking_contract = cfg.test_info.staking_contract;
    fund_and_approve_for_stake(:cfg, :staking_contract, :token_address);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher
        .stake(
            cfg.staker_info.reward_address,
            cfg.staker_info.operational_address,
            cfg.test_info.stake_amount,
        );
    if cfg.test_info.strk_pool_enabled {
        cheat_caller_address(
            contract_address: staking_contract,
            caller_address: cfg.test_info.staker_address,
            span: CheatSpan::TargetCalls(2),
        );
        staking_dispatcher
            .set_commission(
                commission: cfg.staker_info._deprecated_get_pool_info()._deprecated_commission,
            );
        staking_dispatcher.set_open_for_delegation(:token_address);
    }
}

pub(crate) fn stake_from_zero_address(cfg: StakingInitConfig) {
    let staking_contract = cfg.test_info.staking_contract;
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher
        .stake(
            cfg.staker_info.reward_address,
            cfg.staker_info.operational_address,
            cfg.test_info.stake_amount,
        );
}

pub(crate) fn stake_with_strk_pool_enabled(mut cfg: StakingInitConfig) -> ContractAddress {
    cfg.test_info.strk_pool_enabled = true;
    stake_for_testing_using_dispatcher(:cfg);
    let staking_dispatcher = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract,
    };
    let pool_contract = staking_dispatcher
        .staker_info_v1(cfg.test_info.staker_address)
        .get_pool_info()
        .pool_contract;
    pool_contract
}

pub(crate) fn enter_delegation_pool_for_testing_using_dispatcher(
    pool_contract: ContractAddress, cfg: StakingInitConfig, token: Token,
) {
    // Transfer the stake amount to the pool member.
    fund(
        target: cfg.test_info.pool_member_address,
        amount: cfg.test_info.pool_member_initial_balance,
        :token,
    );

    // Approve the pool contract to transfer the pool member's funds.
    approve(
        owner: cfg.test_info.pool_member_address,
        spender: pool_contract,
        amount: cfg.pool_member_info._deprecated_amount,
        token_address: token.contract_address(),
    );

    // Enter the delegation pool.
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.pool_member_address,
    );
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    pool_dispatcher
        .enter_delegation_pool(
            reward_address: cfg.pool_member_info.reward_address,
            amount: cfg.pool_member_info._deprecated_amount,
        )
}

pub(crate) fn add_to_delegation_pool_with_pool_member(
    pool_contract: ContractAddress,
    pool_member: ContractAddress,
    amount: Amount,
    token_address: ContractAddress,
) {
    approve(owner: pool_member, spender: pool_contract, :amount, :token_address);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    pool_dispatcher.add_to_delegation_pool(:pool_member, :amount);
}

pub(crate) fn claim_rewards_for_pool_member(
    pool_contract: ContractAddress, pool_member: ContractAddress,
) -> Amount {
    cheat_caller_address_once(contract_address: pool_contract, caller_address: pool_member);
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    pool_dispatcher.claim_rewards(:pool_member)
}

pub(crate) fn update_rewards_from_staking_contract_for_testing(
    cfg: StakingInitConfig, pool_contract: ContractAddress, rewards: Amount, pool_balance: Amount,
) {
    fund(target: pool_contract, amount: rewards, token: cfg.test_info.strk_token);
    cheat_caller_address_once(
        contract_address: pool_contract, caller_address: cfg.test_info.staking_contract,
    );
    let pool_dispatcher = IPoolDispatcher { contract_address: pool_contract };
    pool_dispatcher.update_rewards_from_staking_contract(:rewards, :pool_balance);
}

/// *****WARNING*****
/// This function only works on simple data types or structs that have no special implementations
/// for Hash, Store, or Serde traits. It also won't work on any standard enum.
/// This statement applies to both key and value.
/// The trait used to serialize and deserialize the key for the address calculation is Hash trait.
/// The trait used to serialize and deserialize the value for the storage is Store trait.
/// The trait used to serialize and deserialize the key and value in this function is Serde trait.
/// Note: It could work for non-simple types that implement Hash, Store and Serde the same way.
pub(crate) fn load_from_simple_map<K, +Serde<K>, +Copy<K>, +Drop<K>, V, +Serde<V>, +Store<V>>(
    map_selector: felt252, key: K, contract: ContractAddress,
) -> V {
    let mut keys = array![];
    key.serialize(ref keys);
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: keys.span());
    let serialized_value = snforge_std::load(
        target: contract, :storage_address, size: Store::<V>::size().into(),
    );
    let mut span = serialized_value.span();
    Serde::<V>::deserialize(ref span).expect('Failed deserialize')
}

/// *****WARNING*****
/// This function only works on simple data types or structs that have no special implementations
/// for Hash, Store, or Serde traits. It also won't work on any standard enum.
/// This statement applies to both key and value.
/// The trait used to serialize and deserialize the key for the address calculation is Hash trait.
/// The trait used to serialize and deserialize the value for the storage is Store trait.
/// The trait used to serialize and deserialize the key and value in this function is Serde trait.
/// Note: It could work for non-simple types that implement Hash, Store and Serde the same way.
pub(crate) fn store_to_simple_map<
    K, +Serde<K>, +Copy<K>, +Drop<K>, V, +Serde<V>, +Store<V>, +Drop<V>,
>(
    map_selector: felt252, key: K, contract: ContractAddress, value: V,
) {
    let mut keys = array![];
    key.serialize(ref keys);
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: keys.span());
    let mut serialized_value = array![];
    value.serialize(ref serialized_value);
    let serialized_value = serialized_value.span();
    snforge_std::store(target: contract, :storage_address, :serialized_value);
}

/// This only works for shallow Option. i.e. if within V there is an Option, this will fail.
pub(crate) fn load_option_from_simple_map<
    K, +Serde<K>, +Copy<K>, +Drop<K>, V, +Serde<V>, +Store<Option<V>>,
>(
    map_selector: felt252, key: K, contract: ContractAddress,
) -> Option<V> {
    let mut keys = array![];
    key.serialize(ref keys);
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: keys.span());
    let mut raw_serialized_value = snforge_std::load(
        target: contract, :storage_address, size: Store::<Option<V>>::size().into(),
    );
    let idx = raw_serialized_value.pop_front().expect('Failed pop_front');
    let mut span = raw_serialized_value.span();
    match idx {
        0 => Option::None,
        1 => Option::Some(Serde::<V>::deserialize(ref span).expect('Failed deserialize')),
        _ => panic!("Invalid Option loaded from map"),
    }
}

/// Store internal staker info v0 with pool_info = None.
pub(crate) fn store_internal_staker_info_v0_to_map(
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    unstake_time: Option<Timestamp>,
    amount_own: Amount,
    index: Index,
    unclaimed_rewards_own: Amount,
) {
    // Serialize the versioned internal staker info.
    let mut serialized_enum: Array<felt252> = array![];
    let version = 1; // V0
    version.serialize(ref serialized_enum);
    reward_address.serialize(ref serialized_enum);
    operational_address.serialize(ref serialized_enum);
    if let Option::Some(time) = unstake_time {
        let idx = 1;
        idx.serialize(ref serialized_enum);
        time.serialize(ref serialized_enum);
    } else {
        let idx = 0;
        idx.serialize(ref serialized_enum);
    }
    unstake_time.serialize(ref serialized_enum);
    amount_own.serialize(ref serialized_enum);
    index.serialize(ref serialized_enum);
    unclaimed_rewards_own.serialize(ref serialized_enum);
    // Serialize the pool info = None.
    let idx = 0;
    idx.serialize(ref serialized_enum);
    let mut keys = array![];
    staker_address.serialize(ref keys);
    let storage_address = snforge_std::map_entry_address(
        map_selector: selector!("staker_info"), keys: keys.span(),
    );
    let serialized_value = serialized_enum.span();
    snforge_std::store(target: staking_contract, :storage_address, :serialized_value);
}

pub(crate) fn load_one_felt(target: ContractAddress, storage_address: felt252) -> felt252 {
    let value = snforge_std::load(:target, :storage_address, size: 1);
    *value[0]
}

pub(crate) fn general_contract_system_deployment(ref cfg: StakingInitConfig) {
    // Deploy contracts: MintingCurve, RewardSupplier, Staking.
    // Deploy the minting_curve, with faked staking_address.
    let minting_curve = deploy_minting_curve_contract(:cfg);
    cfg.reward_supplier.minting_curve_contract = minting_curve;
    // Deploy the reward_supplier, with faked staking_address.
    let reward_supplier = deploy_reward_supplier_contract(:cfg);
    cfg.staking_contract_info.reward_supplier = reward_supplier;
    // Deploy the staking contract.
    let staking_contract = deploy_staking_contract(:cfg);
    cfg.test_info.staking_contract = staking_contract;
    // Deploy the attestation contract.
    let attestation_contract = deploy_attestation_contract(:cfg);
    cfg.test_info.attestation_contract = attestation_contract;
    // There are circular dependecies between the contracts, so we override the fake addresses.
    snforge_std::store(
        target: reward_supplier,
        storage_address: selector!("staking_contract"),
        serialized_value: array![staking_contract.into()].span(),
    );
    snforge_std::store(
        target: minting_curve,
        storage_address: selector!("staking_dispatcher"),
        serialized_value: array![staking_contract.into()].span(),
    );
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("attestation_contract"),
        serialized_value: array![attestation_contract.into()].span(),
    );
    // Deploy the BTC token, add it to the staking contract, and enable it.
    let btc_token_address = setup_btc_token(:cfg, name: BTC_TOKEN_NAME());
    cfg.test_info.btc_token = custom_decimals_token(token_address: btc_token_address);
}

pub(crate) fn cheat_reward_for_reward_supplier(
    reward_supplier: ContractAddress, expected_reward: Amount, token: Token,
) {
    fund(target: reward_supplier, amount: expected_reward, :token);
    snforge_std::store(
        target: reward_supplier,
        storage_address: selector!("unclaimed_rewards"),
        serialized_value: array![expected_reward.into()].span(),
    );
}

fn compute_unclaimed_rewards_member(
    amount: Amount, interest: Index, commission: Commission, base_value: Index,
) -> Amount {
    let rewards_including_commission = compute_rewards_rounded_down(
        :amount, :interest, :base_value,
    );
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission, :commission,
    );
    return rewards_including_commission - commission_amount;
}

/// Assumes the staking contract has already been deployed.
pub(crate) fn pause_staking_contract(cfg: StakingInitConfig) {
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    staking_pause_dispatcher.pause();
}

pub(crate) fn add_reward_for_reward_supplier(
    reward_supplier: ContractAddress, reward: Amount, token: Token,
) {
    fund(target: reward_supplier, amount: reward, :token);
    let current_unclaimed_rewards = *snforge_std::load(
        target: reward_supplier,
        storage_address: selector!("unclaimed_rewards"),
        size: Store::<Amount>::size().into(),
    )
        .at(0);
    snforge_std::store(
        target: reward_supplier,
        storage_address: selector!("unclaimed_rewards"),
        serialized_value: array![current_unclaimed_rewards + reward.into()].span(),
    );
}

/// Deserialize an Option<T> from the given data.
pub(crate) fn deserialize_option<T, +Serde<T>, +Drop<T>>(ref data: Span<felt252>) -> Option<T> {
    let idx = *data.pop_front().expect('Failed pop_front');
    // Deserialize consumes the data (i.e. the size of T is removed from the front of the data).
    // It's important to consume it even if the Option is None, as the calling function expects it.
    let value = Serde::<T>::deserialize(ref serialized: data).expect('Failed deserialization');
    if idx.is_zero() {
        return Option::None;
    }
    assert!(idx == 1, "Invalid Option loaded from map");
    Option::Some(value)
}

#[derive(Drop, Copy)]
pub(crate) struct TestInfo {
    pub staker_address: ContractAddress,
    pub pool_member_address: ContractAddress,
    pub owner_address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub initial_supply: u256,
    pub staker_initial_balance: Amount,
    pub pool_member_initial_balance: Amount,
    pub pool_member_btc_amount: Amount,
    pub strk_pool_enabled: bool,
    pub stake_amount: Amount,
    pub staking_contract: ContractAddress,
    pub pool_contract_admin: ContractAddress,
    pub security_admin: ContractAddress,
    pub security_agent: ContractAddress,
    pub token_admin: ContractAddress,
    pub app_role_admin: ContractAddress,
    pub upgrade_governor: ContractAddress,
    pub attestation_contract: ContractAddress,
    pub attestation_window: u16,
    pub app_governor: ContractAddress,
    pub global_index: Index,
    pub strk_token: Token,
    pub btc_token: Token,
    pub public_key: PublicKey,
}

#[derive(Drop, Copy)]
struct RewardSupplierInfoV1 {
    pub base_mint_amount: Amount,
    pub minting_curve_contract: ContractAddress,
    pub l1_reward_supplier: felt252,
    pub buffer: Amount,
    pub starkgate_address: ContractAddress,
}

#[derive(Drop, Copy)]
pub(crate) struct StakingInitConfig {
    pub staker_info: InternalStakerInfoLatest,
    pub pool_member_info: InternalPoolMemberInfoLatest,
    pub staking_contract_info: StakingContractInfoCfg,
    pub minting_curve_contract_info: MintingCurveContractInfo,
    pub test_info: TestInfo,
    pub reward_supplier: RewardSupplierInfoV1,
}

impl StakingInitConfigDefault of Default<StakingInitConfig> {
    fn default() -> StakingInitConfig {
        let staker_info = InternalStakerInfoLatest {
            reward_address: STAKER_REWARD_ADDRESS(),
            operational_address: OPERATIONAL_ADDRESS(),
            unstake_time: Option::None,
            unclaimed_rewards_own: 0,
            _deprecated_pool_info: Option::Some(
                InternalStakerPoolInfoLatest {
                    _deprecated_pool_contract: POOL_CONTRACT_ADDRESS(),
                    _deprecated_commission: COMMISSION,
                },
            ),
            _deprecated_commission_commitment: Option::None,
        };
        let pool_member_info = InternalPoolMemberInfoLatest {
            reward_address: POOL_MEMBER_REWARD_ADDRESS(),
            _deprecated_amount: POOL_MEMBER_STAKE_AMOUNT,
            _deprecated_index: Zero::zero(),
            _unclaimed_rewards_from_v0: Zero::zero(),
            _deprecated_commission: COMMISSION,
            unpool_time: Option::None,
            unpool_amount: Zero::zero(),
            entry_to_claim_from: Zero::zero(),
            reward_checkpoint: PoolMemberCheckpointTrait::new(
                epoch: STARTING_EPOCH,
                balance: Zero::zero(),
                cumulative_rewards_trace_idx: Zero::zero(),
            ),
        };
        let staking_contract_info = StakingContractInfoCfg {
            min_stake: MIN_STAKE,
            attestation_contract: ATTESTATION_CONTRACT_ADDRESS(),
            pool_contract_class_hash: declare_pool_contract(),
            reward_supplier: REWARD_SUPPLIER_CONTRACT_ADDRESS(),
            exit_wait_window: DEFAULT_EXIT_WAIT_WINDOW,
            prev_staking_contract_class_hash: DUMMY_CLASS_HASH(),
            epoch_info: DEFAULT_EPOCH_INFO(),
        };
        let minting_curve_contract_info = MintingCurveContractInfo {
            c_num: DEFAULT_C_NUM, c_denom: C_DENOM,
        };
        let test_info = TestInfo {
            staker_address: STAKER_ADDRESS(),
            pool_member_address: POOL_MEMBER_ADDRESS(),
            owner_address: OWNER_ADDRESS(),
            governance_admin: GOVERNANCE_ADMIN(),
            initial_supply: INITIAL_SUPPLY.into(),
            staker_initial_balance: STAKER_INITIAL_BALANCE,
            pool_member_initial_balance: POOL_MEMBER_INITIAL_BALANCE,
            pool_member_btc_amount: BTC_POOL_MEMBER_STAKE_AMOUNT,
            strk_pool_enabled: false,
            stake_amount: STAKE_AMOUNT,
            staking_contract: STAKING_CONTRACT_ADDRESS(),
            pool_contract_admin: POOL_CONTRACT_ADMIN(),
            security_admin: SECURITY_ADMIN(),
            security_agent: SECURITY_AGENT(),
            token_admin: TOKEN_ADMIN(),
            app_role_admin: APP_ROLE_ADMIN(),
            upgrade_governor: UPGRADE_GOVERNOR(),
            attestation_contract: ATTESTATION_CONTRACT_ADDRESS(),
            attestation_window: MIN_ATTESTATION_WINDOW,
            app_governor: APP_GOVERNOR(),
            global_index: Zero::zero(),
            strk_token: Token::STRK,
            btc_token: custom_decimals_token(token_address: BTC_TOKEN_ADDRESS()),
            public_key: PUBLIC_KEY(),
        };
        let reward_supplier = RewardSupplierInfoV1 {
            base_mint_amount: BASE_MINT_AMOUNT,
            minting_curve_contract: MINTING_CONTRACT_ADDRESS(),
            l1_reward_supplier: L1_REWARD_SUPPLIER,
            buffer: BUFFER,
            starkgate_address: STARKGATE_ADDRESS(),
        };
        StakingInitConfig {
            staker_info,
            pool_member_info,
            staking_contract_info,
            minting_curve_contract_info,
            test_info,
            reward_supplier,
        }
    }
}

#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub struct StakingContractInfoCfg {
    pub min_stake: Amount,
    pub attestation_contract: ContractAddress,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
    pub exit_wait_window: TimeDelta,
    pub prev_staking_contract_class_hash: ClassHash,
    pub epoch_info: EpochInfo,
}

// TODO: rename to v1.
/// Update rewards for STRK pool.
pub(crate) fn strk_pool_update_rewards(
    pool_member_info: PoolMemberInfo, updated_index: Index,
) -> PoolMemberInfo {
    let interest: Index = updated_index - pool_member_info.index;
    let rewards_including_commission = compute_rewards_rounded_down(
        amount: pool_member_info.amount, :interest, base_value: STRK_BASE_VALUE,
    );
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission, commission: pool_member_info.commission,
    );
    let rewards = rewards_including_commission - commission_amount;
    PoolMemberInfo {
        unclaimed_rewards: pool_member_info.unclaimed_rewards + rewards,
        index: updated_index,
        ..pool_member_info,
    }
}

/// Advance one epoch.
pub(crate) fn advance_epoch_global() {
    advance_block_number_global(blocks: EPOCH_LENGTH.into());
}

/// Advance `K` epochs.
pub(crate) fn advance_k_epochs_global() {
    for _ in 0..K {
        advance_epoch_global();
    }
}

// TODO: rename to v2.
/// Return staker own rewards and STRK pool rewards.
///
/// Precondition: `strk_curr_total_stake` is not zero.
pub(crate) fn calculate_staker_strk_rewards(
    staker_info: StakerInfoV1,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
) -> (Amount, Amount) {
    calculate_staker_strk_rewards_with_amount_and_pool_info(
        amount_own: staker_info.amount_own,
        pool_info: staker_info.pool_info,
        :staking_contract,
        :minting_curve_contract,
    )
}

// TODO: rename to v2.
pub(crate) fn calculate_staker_strk_rewards_with_amount_and_pool_info(
    amount_own: Amount,
    pool_info: Option<StakerPoolInfoV1>,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
) -> (Amount, Amount) {
    let (pool_amount, commission) = if let Option::Some(pool_info) = pool_info {
        (pool_info.amount, pool_info.commission)
    } else {
        (Zero::zero(), Zero::zero())
    };
    calculate_staker_strk_rewards_with_balances_v2(
        :amount_own, :pool_amount, :commission, :staking_contract, :minting_curve_contract,
    )
}

pub(crate) fn calculate_staker_strk_rewards_with_balances_v2(
    amount_own: Amount,
    pool_amount: Amount,
    commission: Commission,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
) -> (Amount, Amount) {
    let (strk_epoch_rewards, _) = calculate_current_epoch_rewards(
        :staking_contract, :minting_curve_contract,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let (strk_curr_total_stake, _) = staking_dispatcher.get_current_total_staking_power();
    // Calculate staker own rewards.
    let mut staker_rewards = mul_wide_and_div(
        lhs: strk_epoch_rewards,
        rhs: amount_own,
        div: strk_curr_total_stake.to_strk_native_amount(),
    )
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
    // Calculate staker STRK pool rewards.
    let pool_rewards = {
        if pool_amount.is_non_zero() {
            let pool_rewards_including_commission = mul_wide_and_div(
                lhs: strk_epoch_rewards,
                rhs: pool_amount,
                div: strk_curr_total_stake.to_strk_native_amount(),
            )
                .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
            let commission_rewards = compute_commission_amount_rounded_down(
                rewards_including_commission: pool_rewards_including_commission, :commission,
            );
            let pool_rewards = pool_rewards_including_commission - commission_rewards;
            staker_rewards += commission_rewards;
            pool_rewards
        } else {
            Zero::zero()
        }
    };
    (staker_rewards, pool_rewards)
}

/// Returns (staker_rewards, pool_rewards) for the given balances and commission.
pub(crate) fn calculate_staker_strk_rewards_with_balances_v3(
    amount_own: Amount,
    pool_amount: Amount,
    commission: Commission,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
) -> (Amount, Amount) {
    let (strk_block_rewards, _) = calculate_current_block_rewards(
        :staking_contract, :minting_curve_contract,
    );
    let total_stake = amount_own + pool_amount;
    // Calculate staker own rewards.
    let mut staker_rewards = mul_wide_and_div(
        lhs: strk_block_rewards, rhs: amount_own, div: total_stake,
    )
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
    // Calculate staker STRK pool rewards.
    let pool_rewards = {
        if pool_amount.is_non_zero() {
            let pool_rewards_including_commission = mul_wide_and_div(
                lhs: strk_block_rewards, rhs: pool_amount, div: total_stake,
            )
                .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
            let commission_rewards = compute_commission_amount_rounded_down(
                rewards_including_commission: pool_rewards_including_commission, :commission,
            );
            let pool_rewards = pool_rewards_including_commission - commission_rewards;
            staker_rewards += commission_rewards;
            pool_rewards
        } else {
            Zero::zero()
        }
    };
    (staker_rewards, pool_rewards)
}

// TODO: rename to v2.
/// Return staker commission rewards and BTC pool rewards for the specified `pool_balance` and
/// `commission`.
/// This function expects the `pool_balance` to be in native decimals.
///
/// Precondition: `pool_balance` and `btc_curr_total_stake` are not zero.
pub(crate) fn calculate_staker_btc_pool_rewards(
    pool_balance: Amount,
    commission: Commission,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
    token_address: ContractAddress,
) -> (Amount, Amount) {
    let pool_balance = to_amount_18_decimals(amount: pool_balance, :token_address);
    let (_, btc_epoch_rewards) = calculate_current_epoch_rewards(
        :staking_contract, :minting_curve_contract,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let (_, btc_curr_total_stake) = staking_dispatcher.get_current_total_staking_power();
    // Calculate pool rewards including commission.
    let pool_rewards_including_commission = mul_wide_and_div(
        lhs: btc_epoch_rewards,
        rhs: pool_balance,
        div: btc_curr_total_stake.to_amount_18_decimals(),
    )
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
    // Split rewards into commission and pool rewards.
    let commission_rewards = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission, :commission,
    );
    let pool_rewards = pool_rewards_including_commission - commission_rewards;
    (commission_rewards, pool_rewards)
}

/// Returns (staker_commission_rewards, BTC_pool_rewards) for the specified
/// `normalized_pool_balance`, `normalized_staker_total_btc_balance` and `commission`.
///
/// Precondition: `normalized_pool_balance` and `normalized_staker_total_btc_balance` are not zero.
pub(crate) fn calculate_staker_btc_pool_rewards_v3(
    normalized_pool_balance: NormalizedAmount,
    normalized_staker_total_btc_balance: NormalizedAmount,
    commission: Commission,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
    token_address: ContractAddress,
) -> (Amount, Amount) {
    let (_, btc_block_rewards) = calculate_current_block_rewards(
        :staking_contract, :minting_curve_contract,
    );
    // Calculate pool rewards including commission.
    let pool_rewards_including_commission = mul_wide_and_div(
        lhs: btc_block_rewards,
        rhs: normalized_pool_balance.to_amount_18_decimals(),
        div: normalized_staker_total_btc_balance.to_amount_18_decimals(),
    )
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
    // Split rewards into commission and pool rewards.
    let commission_rewards = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission, :commission,
    );
    let pool_rewards = pool_rewards_including_commission - commission_rewards;
    (commission_rewards, pool_rewards)
}

fn calculate_current_epoch_rewards(
    staking_contract: ContractAddress, minting_curve_contract: ContractAddress,
) -> (Amount, Amount) {
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: minting_curve_contract,
    };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };

    let yearly_mint = minting_curve_dispatcher.yearly_mint();
    let epochs_in_year = staking_dispatcher.get_epoch_info().epochs_in_year();
    let total_rewards = yearly_mint / epochs_in_year.into();
    let btc_rewards = calculate_btc_rewards(:total_rewards);
    let strk_rewards = total_rewards - btc_rewards;

    (strk_rewards, btc_rewards)
}

fn calculate_current_block_rewards(
    staking_contract: ContractAddress, minting_curve_contract: ContractAddress,
) -> (Amount, Amount) {
    let (strk_epoch_rewards, btc_epoch_rewards) = calculate_current_epoch_rewards(
        :staking_contract, :minting_curve_contract,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let epoch_len_in_blocks = staking_dispatcher.get_epoch_info().epoch_len_in_blocks();
    let strk_block_rewards = strk_epoch_rewards / epoch_len_in_blocks.into();
    let btc_block_rewards = btc_epoch_rewards / epoch_len_in_blocks.into();
    (strk_block_rewards, btc_block_rewards)
}

fn calculate_btc_rewards(total_rewards: Amount) -> Amount {
    mul_wide_and_div(
        lhs: total_rewards, rhs: RewardSupplier::ALPHA, div: RewardSupplier::ALPHA_DENOMINATOR,
    )
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
}

// TODO: rename to v2.
/// Calculate pool rewards for one epoch
pub(crate) fn calculate_strk_pool_rewards(
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
) -> Amount {
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let pool_balance = staker_info.pool_info.unwrap().amount;
    calculate_strk_pool_rewards_with_pool_balance(
        :staker_address, :staking_contract, :minting_curve_contract, :pool_balance,
    )
}

// TODO: rename to v2.
/// Calculate strk pool rewards for one epoch for the given pool balance and staker balance.
pub(crate) fn calculate_strk_pool_rewards_with_pool_balance(
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
    pool_balance: Amount,
) -> Amount {
    // Get epoch rewards.
    let (strk_epoch_rewards, _) = calculate_current_epoch_rewards(
        :staking_contract, :minting_curve_contract,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    // Get current total STRK stake.
    let (strk_curr_total_stake, _) = staking_dispatcher.get_current_total_staking_power();
    let staker_info = staking_dispatcher.staker_info_v1(:staker_address);
    let commission = staker_info.pool_info.unwrap().commission;
    let pool_rewards_including_commission = mul_wide_and_div(
        lhs: strk_epoch_rewards,
        rhs: pool_balance,
        div: strk_curr_total_stake.to_strk_native_amount(),
    )
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
    let commission_rewards = compute_commission_amount_rounded_down(
        rewards_including_commission: pool_rewards_including_commission, :commission,
    );
    pool_rewards_including_commission - commission_rewards
}

/// Calculate pool member rewards given the pool rewards, pool member balance and pool balance.
pub(crate) fn calculate_pool_member_rewards(
    pool_rewards: Amount, pool_member_balance: Amount, pool_balance: Amount,
) -> Amount {
    mul_wide_and_div(lhs: pool_member_balance, rhs: pool_rewards, div: pool_balance)
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
}

/// Compute the rewards for the pool trace.
///
/// Precondition: decimals must be either `STRK_DECIMALS` or valid `BTC_DECIMALS`.
pub(crate) fn compute_rewards_per_unit(
    staking_rewards: Amount, total_stake: Amount, token_address: ContractAddress,
) -> Index {
    let (min_amount_for_rewards, base_value) = get_reward_calculation_params(:token_address);
    if total_stake < min_amount_for_rewards {
        return Zero::zero();
    }
    mul_wide_and_div(lhs: staking_rewards, rhs: base_value, div: total_stake)
        .expect_with_err(err: StakingError::REWARDS_COMPUTATION_OVERFLOW)
}

fn get_reward_calculation_params(token_address: ContractAddress) -> (Amount, Amount) {
    let token_dispatcher = IERC20MetadataDispatcher { contract_address: token_address };
    if token_dispatcher.contract_address == STRK_TOKEN_ADDRESS {
        (STRK_IN_FRIS, STRK_BASE_VALUE)
    } else {
        let decimals = token_dispatcher.decimals();
        if decimals == BTC_DECIMALS_8 {
            (MIN_BTC_FOR_REWARDS_8, BTC_BASE_VALUE_8)
        } else if decimals == BTC_DECIMALS_18 {
            (MIN_BTC_FOR_REWARDS_18, BTC_BASE_VALUE_18)
        } else {
            panic_with_byte_array(err: @StakingError::INVALID_TOKEN_ADDRESS.describe())
        }
    }
}

#[cfg(test)]
mod tests {
    use core::num::traits::zero::Zero;
    use staking::constants::STRK_TOKEN_ADDRESS;
    use super::{
        BTC_BASE_VALUE_18, BTC_BASE_VALUE_8, BTC_DECIMALS_18, BTC_DECIMALS_8, BTC_TOKEN_NAME,
        MIN_BTC_FOR_REWARDS_18, MIN_BTC_FOR_REWARDS_8, OWNER_ADDRESS, STRK_BASE_VALUE, STRK_IN_FRIS,
        compute_rewards_per_unit, deploy_mock_erc20_decimals_contract,
    };

    #[test]
    fn test_compute_rewards_per_unit() {
        let btc_token_address_8 = deploy_mock_erc20_decimals_contract(
            initial_supply: Zero::zero(),
            owner_address: OWNER_ADDRESS(),
            name: BTC_TOKEN_NAME(),
            decimals: BTC_DECIMALS_8,
        );
        let btc_token_address_18 = deploy_mock_erc20_decimals_contract(
            initial_supply: Zero::zero(),
            owner_address: OWNER_ADDRESS(),
            name: BTC_TOKEN_NAME(),
            decimals: BTC_DECIMALS_18,
        );
        assert!(
            compute_rewards_per_unit(
                STRK_IN_FRIS, STRK_IN_FRIS, STRK_TOKEN_ADDRESS,
            ) == STRK_BASE_VALUE,
        );
        assert!(
            compute_rewards_per_unit(
                STRK_IN_FRIS, STRK_IN_FRIS - 1, STRK_TOKEN_ADDRESS,
            ) == Zero::zero(),
        );
        assert!(
            compute_rewards_per_unit(
                MIN_BTC_FOR_REWARDS_8, MIN_BTC_FOR_REWARDS_8, btc_token_address_8,
            ) == BTC_BASE_VALUE_8,
        );
        assert!(
            compute_rewards_per_unit(
                MIN_BTC_FOR_REWARDS_8, MIN_BTC_FOR_REWARDS_8 - 1, btc_token_address_8,
            ) == Zero::zero(),
        );
        assert!(
            compute_rewards_per_unit(
                BTC_BASE_VALUE_18, BTC_BASE_VALUE_18, btc_token_address_18,
            ) == BTC_BASE_VALUE_18,
        );
        assert!(
            compute_rewards_per_unit(
                MIN_BTC_FOR_REWARDS_18, MIN_BTC_FOR_REWARDS_18 - 1, btc_token_address_18,
            ) == Zero::zero(),
        );
    }
}

/// Calculates the block offset required to advance from the starting block into the attestation
/// window.
pub(crate) fn calculate_block_offset(
    stake: Amount,
    epoch_id: u64,
    staker_address: ContractAddress,
    epoch_len: u64,
    attestation_window: u16,
) -> u64 {
    let hash = PoseidonTrait::new()
        .update(stake.into())
        .update(epoch_id.into())
        .update(staker_address.into())
        .finalize();

    let block_offset: u256 = hash.into() % (epoch_len - attestation_window.into()).into();
    block_offset.try_into().unwrap()
}

pub(crate) fn advance_block_into_attestation_window(cfg: StakingInitConfig, stake: Amount) {
    // calculate block offset and move the block number forward.
    let block_offset = calculate_block_offset(
        :stake,
        epoch_id: cfg.staking_contract_info.epoch_info.current_epoch().into(),
        staker_address: cfg.test_info.staker_address.into(),
        epoch_len: cfg.staking_contract_info.epoch_info.epoch_len_in_blocks().into(),
        attestation_window: MIN_ATTESTATION_WINDOW,
    );
    advance_block_number_global(blocks: block_offset + MIN_ATTESTATION_WINDOW.into());
}

pub(crate) fn cheat_target_attestation_block_hash(cfg: StakingInitConfig, block_hash: felt252) {
    let attestation_contract = cfg.test_info.attestation_contract;
    let attestation_dispatcher = IAttestationDispatcher { contract_address: attestation_contract };
    let operational_address = cfg.staker_info.operational_address;
    let target_attestation_block = attestation_dispatcher
        .get_current_epoch_target_attestation_block(:operational_address);

    start_cheat_block_hash_global(block_number: target_attestation_block, :block_hash);
}

// TODO: Make checkpoint public (in utils-trace) and remove this.
#[derive(Copy, Drop, Serde, starknet::Store)]
struct Checkpoint {
    key: u64,
    value: u128,
}

/// Append a new checkpoint with the given `key`, `value` to the trace.
pub(crate) fn append_to_trace(
    contract_address: ContractAddress, trace_address: felt252, key: u64, value: u128,
) {
    let current_length = load_trace_length(:contract_address, :trace_address);
    let new_length = current_length + 1;
    // Store new length.
    let vector_storage_address = snforge_std::map_entry_address(
        map_selector: trace_address, keys: [selector!("checkpoints")].span(),
    );
    snforge_std::store(
        target: contract_address,
        storage_address: vector_storage_address,
        serialized_value: [new_length.into()].span(),
    );
    // Store checkpoint.
    let checkpoint = Checkpoint { key, value };
    let storage_address = snforge_std::map_entry_address(
        map_selector: vector_storage_address, keys: [current_length.into()].span(),
    );
    let mut serialized_value = array![];
    checkpoint.serialize(ref serialized_value);
    snforge_std::store(
        target: contract_address, :storage_address, serialized_value: serialized_value.span(),
    );
}

/// Load a (key, value) pair from the trace at the given `index`.
pub(crate) fn load_from_trace(
    contract_address: ContractAddress, trace_address: felt252, index: u64,
) -> (u64, u128) {
    let vector_storage_address = snforge_std::map_entry_address(
        map_selector: trace_address, keys: [selector!("checkpoints")].span(),
    );
    let storage_address = snforge_std::map_entry_address(
        map_selector: vector_storage_address, keys: [index.into()].span(),
    );
    let mut serialized_checkpoint = snforge_std::load(
        target: contract_address, :storage_address, size: Store::<Checkpoint>::size().into(),
    )
        .span();
    let checkpoint = Serde::<Checkpoint>::deserialize(ref serialized_checkpoint)
        .expect('Failed deserialize');
    (checkpoint.key, checkpoint.value)
}

/// Load the length of the trace.
pub(crate) fn load_trace_length(contract_address: ContractAddress, trace_address: felt252) -> u64 {
    let vector_storage_address = snforge_std::map_entry_address(
        map_selector: trace_address, keys: [selector!("checkpoints")].span(),
    );
    let length: u64 = (*snforge_std::load(
        target: contract_address,
        storage_address: vector_storage_address,
        size: Store::<u64>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    length
}

/// Load from iterable map.
pub(crate) fn load_from_iterable_map<
    K, +Serde<K>, +Copy<K>, +Drop<K>, V, +Serde<V>, +Store<Option<V>>,
>(
    contract_address: ContractAddress, map_address: felt252, key: K,
) -> Option<V> {
    let map_storage_address = snforge_std::map_entry_address(
        map_selector: map_address, keys: [selector!("_inner_map")].span(),
    );
    load_option_from_simple_map(map_selector: map_storage_address, :key, contract: contract_address)
}

pub(crate) fn setup_btc_token(cfg: StakingInitConfig, name: ByteArray) -> ContractAddress {
    let btc_token_address = deploy_mock_erc20_decimals_contract(
        initial_supply: cfg.test_info.initial_supply,
        owner_address: cfg.test_info.owner_address,
        :name,
        decimals: constants::TEST_BTC_DECIMALS,
    );
    let staking_contract = cfg.test_info.staking_contract;
    let token_manager = IStakingTokenManagerDispatcher { contract_address: staking_contract };
    cheat_caller_address(
        contract_address: staking_contract,
        caller_address: cfg.test_info.token_admin,
        span: CheatSpan::TargetCalls(2),
    );
    token_manager.add_token(token_address: btc_token_address);
    token_manager.enable_token(token_address: btc_token_address);
    btc_token_address
}

pub(crate) fn custom_decimals_token(token_address: ContractAddress) -> Token {
    Token::Custom(
        CustomToken {
            contract_address: token_address,
            balances_variable_selector: selector!("ERC20_balances"),
        },
    )
}

fn get_token_decimals(token_address: ContractAddress) -> u8 {
    let token_dispatcher = IERC20MetadataDispatcher { contract_address: token_address };
    token_dispatcher.decimals()
}

pub(crate) fn to_amount_18_decimals(amount: Amount, token_address: ContractAddress) -> Amount {
    let decimals = get_token_decimals(:token_address);
    amount * 10_u128.pow(STRK_CONFIG.decimals.into() - decimals.into())
}

pub(crate) fn to_native_amount(amount: Amount, token_address: ContractAddress) -> Amount {
    let decimals = get_token_decimals(:token_address);
    amount / 10_u128.pow(STRK_CONFIG.decimals.into() - decimals.into())
}
