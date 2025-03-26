use Staking::ContractState;
use constants::{
    APP_GOVERNOR, APP_ROLE_ADMIN, ATTESTATION_CONTRACT_ADDRESS, BASE_MINT_AMOUNT, BUFFER,
    COMMISSION, DEFAULT_EPOCH_INFO, DUMMY_CLASS_HASH, EPOCH_LENGTH, EPOCH_STARTING_BLOCK,
    GOVERNANCE_ADMIN, INITIAL_SUPPLY, L1_REWARD_SUPPLIER, MINTING_CONTRACT_ADDRESS, MIN_STAKE,
    OPERATIONAL_ADDRESS, OWNER_ADDRESS, POOL_CONTRACT_ADDRESS, POOL_CONTRACT_ADMIN,
    POOL_MEMBER_ADDRESS, POOL_MEMBER_INITIAL_BALANCE, POOL_MEMBER_REWARD_ADDRESS,
    POOL_MEMBER_STAKE_AMOUNT, REWARD_SUPPLIER_CONTRACT_ADDRESS, SECURITY_ADMIN, SECURITY_AGENT,
    STAKER_ADDRESS, STAKER_INITIAL_BALANCE, STAKER_REWARD_ADDRESS, STAKE_AMOUNT,
    STAKING_CONTRACT_ADDRESS, STARKGATE_ADDRESS, TOKEN_ADDRESS, TOKEN_ADMIN, UPGRADE_GOVERNOR,
};
use core::hash::HashStateTrait;
use core::num::traits::zero::Zero;
use core::poseidon::PoseidonTrait;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, start_cheat_block_number_global, test_address,
};
use staking::constants::{C_DENOM, DEFAULT_C_NUM, DEFAULT_EXIT_WAIT_WINDOW, MIN_ATTESTATION_WINDOW};
use staking::errors::GenericError;
use staking::minting_curve::interface::{
    IMintingCurveDispatcher, IMintingCurveDispatcherTrait, MintingCurveContractInfo,
};
use staking::minting_curve::minting_curve::MintingCurve;
use staking::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait, PoolMemberInfo};
use staking::pool::pool::Pool;
use staking::reward_supplier::reward_supplier::RewardSupplier;
use staking::staking::interface::{
    IStaking, IStakingDispatcher, IStakingDispatcherTrait, IStakingPauseDispatcher,
    IStakingPauseDispatcherTrait, StakerInfo, StakerInfoTrait, StakerPoolInfo, StakerPoolInfoTrait,
};
use staking::staking::objects::{EpochInfo, EpochInfoTrait, InternalStakerInfoLatestTrait};
use staking::staking::staking::Staking;
use staking::types::{
    Amount, Commission, Index, InternalPoolMemberInfoLatest, InternalStakerInfoLatest,
};
use staking::utils::{
    compute_commission_amount_rounded_down, compute_commission_amount_rounded_up,
    compute_rewards_rounded_down, compute_rewards_rounded_up,
};
use starknet::{ClassHash, ContractAddress, Store};
use starkware_utils::constants::{NAME, SYMBOL};
use starkware_utils::errors::OptionAuxTrait;
use starkware_utils::math::utils::mul_wide_and_div;
use starkware_utils::types::time::time::{TimeDelta, Timestamp};
use starkware_utils_testing::test_utils::{
    advance_block_number_global, cheat_caller_address_once, set_account_as_app_governor,
    set_account_as_app_role_admin, set_account_as_security_admin, set_account_as_security_agent,
    set_account_as_token_admin, set_account_as_upgrade_governor,
};

pub(crate) mod constants {
    use core::cmp::max;
    use staking::constants::STRK_IN_FRIS;
    use staking::staking::objects::{EpochInfo, EpochInfoTrait};
    use staking::types::{Amount, Commission, Index};
    use starknet::class_hash::ClassHash;
    use starknet::{ContractAddress, get_block_number};

    pub const STAKER_INITIAL_BALANCE: Amount = 1000000 * STRK_IN_FRIS;
    pub const POOL_MEMBER_INITIAL_BALANCE: Amount = 10000 * STRK_IN_FRIS;
    pub const INITIAL_SUPPLY: Amount = 10000000000 * STRK_IN_FRIS;
    pub const MIN_STAKE: Amount = 20000 * STRK_IN_FRIS;
    pub const STAKE_AMOUNT: Amount = 100000 * STRK_IN_FRIS;
    pub const POOL_MEMBER_STAKE_AMOUNT: Amount = 1000 * STRK_IN_FRIS;
    pub const COMMISSION: Commission = 500;
    pub const STAKER_FINAL_INDEX: Index = 10;
    pub const BASE_MINT_AMOUNT: Amount = 1_300_000 * STRK_IN_FRIS;
    pub const BUFFER: Amount = 1000000000000;
    pub const L1_REWARD_SUPPLIER: felt252 = 'L1_REWARD_SUPPLIER';
    pub const DUMMY_IDENTIFIER: felt252 = 'DUMMY_IDENTIFIER';
    pub const POOL_MEMBER_UNCLAIMED_REWARDS: u128 = 10000000;
    pub const STAKER_UNCLAIMED_REWARDS: u128 = 10000000;
    pub const EPOCH_LENGTH: u16 = 300;
    pub const EPOCH_STARTING_BLOCK: u64 = 463476;
    pub const BLOCK_DURATION: u16 = 30;
    pub const STARTING_BLOCK_OFFSET: u64 = 0;

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
            block_duration: BLOCK_DURATION,
            epoch_length: EPOCH_LENGTH,
            starting_block: max(EPOCH_STARTING_BLOCK, get_block_number()),
        )
    }
}
pub(crate) fn initialize_staking_state_from_cfg(
    ref cfg: StakingInitConfig,
) -> Staking::ContractState {
    let token_address = deploy_mock_erc20_contract(
        cfg.test_info.initial_supply, cfg.test_info.owner_address,
    );
    cfg.staking_contract_info.token_address = token_address;
    initialize_staking_state(
        :token_address,
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
    token_address: ContractAddress,
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
        :token_address,
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
    token_address: ContractAddress, cfg: StakingInitConfig,
) -> RewardSupplier::ContractState {
    initialize_reward_supplier_state(
        base_mint_amount: cfg.reward_supplier.base_mint_amount,
        minting_curve_contract: cfg.reward_supplier.minting_curve_contract,
        staking_contract: cfg.test_info.staking_contract,
        :token_address,
        l1_reward_supplier: cfg.reward_supplier.l1_reward_supplier,
        starkgate_address: cfg.reward_supplier.starkgate_address,
        governance_admin: cfg.test_info.governance_admin,
    )
}
pub(crate) fn initialize_reward_supplier_state(
    base_mint_amount: Amount,
    minting_curve_contract: ContractAddress,
    staking_contract: ContractAddress,
    token_address: ContractAddress,
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
        :token_address,
        :l1_reward_supplier,
        :starkgate_address,
        :governance_admin,
    );
    state
}

pub(crate) fn deploy_mock_erc20_contract(
    initial_supply: u256, owner_address: ContractAddress,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    NAME().serialize(ref calldata);
    SYMBOL().serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    owner_address.serialize(ref calldata);
    let erc20_contract = snforge_std::declare("DualCaseERC20Mock").unwrap().contract_class();
    let (token_address, _) = erc20_contract.deploy(@calldata).unwrap();
    token_address
}

pub(crate) fn deploy_staking_contract(
    token_address: ContractAddress, cfg: StakingInitConfig,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    token_address.serialize(ref calldata);
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
    cfg.staking_contract_info.token_address.serialize(ref calldata);
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

pub(crate) fn declare_pool_eic_contract() -> ClassHash {
    *snforge_std::declare("PoolEIC").unwrap().contract_class().class_hash
}

pub(crate) fn fund(
    sender: ContractAddress,
    recipient: ContractAddress,
    amount: Amount,
    token_address: ContractAddress,
) {
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    cheat_caller_address_once(contract_address: token_address, caller_address: sender);
    token_dispatcher.transfer(:recipient, amount: amount.into());
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
        sender: cfg.test_info.owner_address,
        recipient: cfg.test_info.staker_address,
        amount: cfg.test_info.staker_initial_balance,
        :token_address,
    );
    approve(
        owner: cfg.test_info.staker_address,
        spender: staking_contract,
        amount: cfg.test_info.staker_initial_balance,
        :token_address,
    );
}

// Stake according to the given configuration, the staker is cfg.test_info.staker_address.
pub(crate) fn stake_for_testing(
    ref state: ContractState, cfg: StakingInitConfig, token_address: ContractAddress,
) {
    let staking_contract = test_address();
    fund_and_approve_for_stake(:cfg, :staking_contract, :token_address);
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    state
        .stake(
            cfg.staker_info.reward_address,
            cfg.staker_info.operational_address,
            cfg.test_info.stake_amount,
            cfg.test_info.pool_enabled,
            cfg.staker_info.get_pool_info().commission,
        );
}

pub(crate) fn stake_for_testing_using_dispatcher(
    cfg: StakingInitConfig, token_address: ContractAddress, staking_contract: ContractAddress,
) {
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
            cfg.test_info.pool_enabled,
            cfg.staker_info.get_pool_info().commission,
        );
}

pub(crate) fn stake_from_zero_address(
    cfg: StakingInitConfig, token_address: ContractAddress, staking_contract: ContractAddress,
) {
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.staker_address,
    );
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher
        .stake(
            cfg.staker_info.reward_address,
            cfg.staker_info.operational_address,
            cfg.test_info.stake_amount,
            cfg.test_info.pool_enabled,
            cfg.staker_info.get_pool_info().commission,
        );
}

pub(crate) fn stake_with_pool_enabled(
    mut cfg: StakingInitConfig, token_address: ContractAddress, staking_contract: ContractAddress,
) -> ContractAddress {
    cfg.test_info.pool_enabled = true;
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let pool_contract = staking_dispatcher
        .staker_info(cfg.test_info.staker_address)
        .get_pool_info()
        .pool_contract;
    pool_contract
}

pub(crate) fn enter_delegation_pool_for_testing_using_dispatcher(
    pool_contract: ContractAddress, cfg: StakingInitConfig, token_address: ContractAddress,
) {
    // Transfer the stake amount to the pool member.
    fund(
        sender: cfg.test_info.owner_address,
        recipient: cfg.test_info.pool_member_address,
        amount: cfg.test_info.pool_member_initial_balance,
        :token_address,
    );

    // Approve the pool contract to transfer the pool member's funds.
    approve(
        owner: cfg.test_info.pool_member_address,
        spender: pool_contract,
        amount: cfg.pool_member_info._deprecated_amount,
        :token_address,
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

// This only works for shallow Option. i.e. if within V there is an Option, this will fail.
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

pub(crate) fn store_internal_staker_info_v0_to_map(
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    unstake_time: Option<Timestamp>,
    amount_own: Amount,
    index: Index,
    unclaimed_rewards_own: Amount,
    pool_info: Option<StakerPoolInfo>,
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
    if let Option::Some(info) = pool_info {
        let idx = 1;
        idx.serialize(ref serialized_enum);
        info.serialize(ref serialized_enum);
    } else {
        let idx = 0;
        idx.serialize(ref serialized_enum);
    }
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
    // Deploy contracts: ERC20, MintingCurve, RewardSupplier, Staking.
    let token_address = deploy_mock_erc20_contract(
        initial_supply: cfg.test_info.initial_supply, owner_address: cfg.test_info.owner_address,
    );
    cfg.staking_contract_info.token_address = token_address;
    // Deploy the minting_curve, with faked staking_address.
    let minting_curve = deploy_minting_curve_contract(:cfg);
    cfg.reward_supplier.minting_curve_contract = minting_curve;
    // Deploy the reward_supplier, with faked staking_address.
    let reward_supplier = deploy_reward_supplier_contract(:cfg);
    cfg.staking_contract_info.reward_supplier = reward_supplier;
    // Deploy the staking contract.
    let staking_contract = deploy_staking_contract(:token_address, :cfg);
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
}

pub(crate) fn cheat_reward_for_reward_supplier(
    cfg: StakingInitConfig,
    reward_supplier: ContractAddress,
    expected_reward: Amount,
    token_address: ContractAddress,
) {
    fund(
        sender: cfg.test_info.owner_address,
        recipient: reward_supplier,
        amount: expected_reward,
        :token_address,
    );
    snforge_std::store(
        target: reward_supplier,
        storage_address: selector!("unclaimed_rewards"),
        serialized_value: array![expected_reward.into()].span(),
    );
}

fn compute_unclaimed_rewards_member(
    amount: Amount, interest: Index, commission: Commission,
) -> Amount {
    let rewards_including_commission = compute_rewards_rounded_down(:amount, :interest);
    let commission_amount = compute_commission_amount_rounded_up(
        :rewards_including_commission, :commission,
    );
    return rewards_including_commission - commission_amount;
}

// Assumes the staking contract has already been deployed.
pub(crate) fn pause_staking_contract(cfg: StakingInitConfig) {
    let staking_contract = cfg.test_info.staking_contract;
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    cheat_caller_address_once(
        contract_address: staking_contract, caller_address: cfg.test_info.security_agent,
    );
    staking_pause_dispatcher.pause();
}

pub(crate) fn add_reward_for_reward_supplier(
    cfg: StakingInitConfig,
    reward_supplier: ContractAddress,
    reward: Amount,
    token_address: ContractAddress,
) {
    fund(
        sender: cfg.test_info.owner_address,
        recipient: reward_supplier,
        amount: reward,
        :token_address,
    );
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
    pub pool_enabled: bool,
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
}

#[derive(Drop, Copy)]
struct RewardSupplierInfo {
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
    pub reward_supplier: RewardSupplierInfo,
}

impl StakingInitConfigDefault of Default<StakingInitConfig> {
    fn default() -> StakingInitConfig {
        let staker_info = InternalStakerInfoLatest {
            reward_address: STAKER_REWARD_ADDRESS(),
            operational_address: OPERATIONAL_ADDRESS(),
            unstake_time: Option::None,
            _deprecated_index_V0: Zero::zero(),
            unclaimed_rewards_own: 0,
            pool_info: Option::Some(
                StakerPoolInfoTrait::new(
                    pool_contract: POOL_CONTRACT_ADDRESS(), commission: COMMISSION,
                ),
            ),
            commission_commitment: Option::None,
        };
        let pool_member_info = InternalPoolMemberInfoLatest {
            reward_address: POOL_MEMBER_REWARD_ADDRESS(),
            _deprecated_amount: POOL_MEMBER_STAKE_AMOUNT,
            _deprecated_index: Zero::zero(),
            _deprecated_unclaimed_rewards: Zero::zero(),
            _deprecated_commission: COMMISSION,
            unpool_time: Option::None,
            unpool_amount: Zero::zero(),
            entry_to_claim_from: Zero::zero(),
        };
        let staking_contract_info = StakingContractInfoCfg {
            min_stake: MIN_STAKE,
            token_address: TOKEN_ADDRESS(),
            global_index: Zero::zero(),
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
            pool_enabled: false,
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
        };
        let reward_supplier = RewardSupplierInfo {
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
    pub token_address: ContractAddress,
    pub global_index: Index,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
    pub exit_wait_window: TimeDelta,
    pub prev_staking_contract_class_hash: ClassHash,
    pub epoch_info: EpochInfo,
}

/// Update rewards for staker and pool.
/// **Note**: The index of the returned staker info is set to zero.
pub(crate) fn staker_update_rewards(staker_info: StakerInfo, global_index: Index) -> StakerInfo {
    let interest: Index = global_index - staker_info.index;
    let mut staker_rewards = compute_rewards_rounded_down(
        amount: staker_info.amount_own, :interest,
    );
    let mut staker_pool_info: Option<StakerPoolInfo> = Option::None;
    if let Option::Some(pool_info) = staker_info.pool_info {
        let pool_rewards_including_commission = compute_rewards_rounded_up(
            amount: pool_info._deprecated_amount(), :interest,
        );
        let commission_amount = compute_commission_amount_rounded_down(
            rewards_including_commission: pool_rewards_including_commission,
            commission: pool_info.commission,
        );
        staker_rewards += commission_amount;
        let pool_rewards = pool_rewards_including_commission - commission_amount;
        let mut staker_pool_info_internal = StakerPoolInfoTrait::new(
            pool_contract: pool_info.pool_contract, commission: pool_info.commission,
        );
        staker_pool_info_internal
            ._set_deprecated_unclaimed_rewards(unclaimed_rewards: pool_rewards);
        staker_pool_info_internal._set_deprecated_amount(pool_info._deprecated_amount());
        staker_pool_info = Option::Some(staker_pool_info_internal);
    }
    StakerInfo {
        index: Zero::zero(),
        unclaimed_rewards_own: staker_info.unclaimed_rewards_own + staker_rewards,
        pool_info: staker_pool_info,
        ..staker_info,
    }
}

/// Update rewards for pool.
pub(crate) fn pool_update_rewards(
    pool_member_info: PoolMemberInfo, updated_index: Index,
) -> PoolMemberInfo {
    let interest: Index = updated_index - pool_member_info.index;
    let rewards_including_commission = compute_rewards_rounded_down(
        amount: pool_member_info.amount, :interest,
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

pub(crate) fn calculate_staker_total_rewards(
    staker_info: StakerInfo,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
) -> Amount {
    let epoch_rewards = current_epoch_rewards(:staking_contract, :minting_curve_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    mul_wide_and_div(
        lhs: epoch_rewards,
        rhs: get_total_amount(:staker_info),
        div: staking_dispatcher.get_current_total_staking_power(),
    )
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE)
}

fn current_epoch_rewards(
    staking_contract: ContractAddress, minting_curve_contract: ContractAddress,
) -> Amount {
    let minting_curve_dispatcher = IMintingCurveDispatcher {
        contract_address: minting_curve_contract,
    };
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };

    let yearly_mint = minting_curve_dispatcher.yearly_mint();
    let epochs_in_year = staking_dispatcher.get_epoch_info().epochs_in_year();
    yearly_mint / epochs_in_year.into()
}

pub(crate) fn calculate_staker_own_rewards_including_commission(
    staker_info: StakerInfo, total_rewards: Amount,
) -> Amount {
    let own_rewards = get_staker_own_rewards(:staker_info, :total_rewards);
    let commission_rewards = get_staker_commission_rewards(
        :staker_info, pool_rewards: total_rewards - own_rewards,
    );
    own_rewards + commission_rewards
}

fn get_staker_own_rewards(staker_info: StakerInfo, total_rewards: Amount) -> Amount {
    let own_rewards = mul_wide_and_div(
        lhs: total_rewards, rhs: staker_info.amount_own, div: get_total_amount(:staker_info),
    )
        .expect_with_err(err: GenericError::REWARDS_ISNT_AMOUNT_TYPE);
    own_rewards
}

fn get_staker_commission_rewards(staker_info: StakerInfo, pool_rewards: Amount) -> Amount {
    if let Option::Some(pool_info) = staker_info.pool_info {
        return compute_commission_amount_rounded_down(
            rewards_including_commission: pool_rewards, commission: pool_info.commission,
        );
    }
    Zero::zero()
}

fn get_total_amount(staker_info: StakerInfo) -> Amount {
    if let Option::Some(pool_info) = staker_info.pool_info {
        return pool_info._deprecated_amount() + staker_info.amount_own;
    }
    (staker_info.amount_own)
}

/// Calculate pool rewards for one epoch
pub(crate) fn calculate_pool_rewards(
    staker_address: ContractAddress,
    staking_contract: ContractAddress,
    minting_curve_contract: ContractAddress,
) -> Amount {
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_info = staking_dispatcher.staker_info(:staker_address);
    let total_rewards = calculate_staker_total_rewards(
        :staker_info, :staking_contract, :minting_curve_contract,
    );
    let staker_rewards = calculate_staker_own_rewards_including_commission(
        :staker_info, :total_rewards,
    );
    let pool_rewards = total_rewards - staker_rewards;
    pool_rewards
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

pub(crate) fn advance_block_into_attestation_window(cfg: StakingInitConfig) {
    // calculate block offset and move the block number forward.
    let block_offset = calculate_block_offset(
        stake: cfg.test_info.stake_amount.into(),
        epoch_id: cfg.staking_contract_info.epoch_info.current_epoch().into(),
        staker_address: cfg.test_info.staker_address.into(),
        epoch_len: cfg.staking_contract_info.epoch_info.epoch_len_in_blocks().into(),
        attestation_window: MIN_ATTESTATION_WINDOW,
    );
    advance_block_number_global(blocks: block_offset + MIN_ATTESTATION_WINDOW.into());
}
