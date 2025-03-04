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
use contracts_commons::constants::{NAME, SYMBOL};
use contracts_commons::errors::OptionAuxTrait;
use contracts_commons::math::utils::mul_wide_and_div;
use contracts_commons::test_utils::{
    advance_block_number_global, cheat_caller_address_once, set_account_as_app_governor,
    set_account_as_app_role_admin, set_account_as_security_admin, set_account_as_security_agent,
    set_account_as_token_admin, set_account_as_upgrade_governor,
};
use contracts_commons::types::time::time::{TimeDelta, Timestamp};
use core::num::traits::zero::Zero;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, start_cheat_block_number_global, test_address,
};
use staking::constants::MIN_ATTESTATION_WINDOW;
use staking::constants::{C_DENOM, DEFAULT_C_NUM, DEFAULT_EXIT_WAIT_WINDOW};
use staking::errors::GenericError;
use staking::minting_curve::interface::MintingCurveContractInfo;
use staking::minting_curve::interface::{IMintingCurveDispatcher, IMintingCurveDispatcherTrait};
use staking::minting_curve::minting_curve::MintingCurve;
use staking::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait, PoolMemberInfo};
use staking::pool::objects::{VInternalPoolMemberInfo, VInternalPoolMemberInfoTrait};
use staking::pool::pool::Pool;
use staking::reward_supplier::reward_supplier::RewardSupplier;
use staking::staking::interface::{
    IStaking, IStakingDispatcher, IStakingDispatcherTrait, IStakingPauseDispatcher,
    IStakingPauseDispatcherTrait, StakerInfo, StakerInfoTrait, StakerPoolInfo,
};
use staking::staking::objects::EpochInfoTrait;
use staking::staking::objects::{
    EpochInfo, InternalStakerInfoLatestTrait, VersionedInternalStakerInfo,
    VersionedInternalStakerInfoTrait,
};
use staking::staking::staking::Staking;
use staking::types::{
    Amount, Commission, Index, InternalPoolMemberInfoLatest, InternalStakerInfoLatest, VecIndex,
};
use staking::utils::{
    compute_commission_amount_rounded_down, compute_commission_amount_rounded_up,
    compute_rewards_rounded_down, compute_rewards_rounded_up,
};
use starknet::{ClassHash, ContractAddress, Store};

pub(crate) mod constants {
    use staking::constants::STRK_IN_FRIS;
    use staking::staking::objects::{EpochInfo, EpochInfoTrait};
    use staking::types::{Amount, Commission, Index};
    use starknet::class_hash::{ClassHash, class_hash_const};
    use starknet::{ContractAddress, contract_address_const};

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

    pub fn CALLER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'CALLER_ADDRESS'>()
    }
    pub fn DUMMY_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'DUMMY_ADDRESS'>()
    }
    pub fn STAKER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'STAKER_ADDRESS'>()
    }
    pub fn NON_STAKER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'NON_STAKER_ADDRESS'>()
    }
    pub fn POOL_MEMBER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'POOL_MEMBER_ADDRESS'>()
    }
    pub fn OTHER_POOL_MEMBER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'OTHER_POOL_MEMBER_ADDRESS'>()
    }
    pub fn NON_POOL_MEMBER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'NON_POOL_MEMBER_ADDRESS'>()
    }
    pub fn OTHER_STAKER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'OTHER_STAKER_ADDRESS'>()
    }
    pub fn OPERATIONAL_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'OPERATIONAL_ADDRESS'>()
    }
    pub fn OTHER_OPERATIONAL_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'OTHER_OPERATIONAL_ADDRESS'>()
    }
    pub fn OWNER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'OWNER_ADDRESS'>()
    }
    pub fn GOVERNANCE_ADMIN() -> ContractAddress nopanic {
        contract_address_const::<'GOVERNANCE_ADMIN'>()
    }
    pub fn STAKING_CONTRACT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'STAKING_CONTRACT_ADDRESS'>()
    }
    pub fn NOT_STAKING_CONTRACT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'NOT_STAKING_CONTRACT_ADDRESS'>()
    }
    pub fn POOL_CONTRACT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'POOL_CONTRACT_ADDRESS'>()
    }
    pub fn OTHER_POOL_CONTRACT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'OTHER_POOL_CONTRACT_ADDRESS'>()
    }
    pub fn MINTING_CONTRACT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'MINTING_CONTRACT_ADDRESS'>()
    }
    pub fn REWARD_SUPPLIER_CONTRACT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'REWARD_SUPPLIER_ADDRESS'>()
    }
    pub fn OTHER_REWARD_SUPPLIER_CONTRACT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'OTHER_REWARD_SUPPLIER_ADDRESS'>()
    }
    pub fn RECIPIENT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'RECIPIENT_ADDRESS'>()
    }
    pub fn STAKER_REWARD_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'STAKER_REWARD_ADDRESS'>()
    }
    pub fn POOL_MEMBER_REWARD_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'POOL_MEMBER_REWARD_ADDRESS'>()
    }
    pub fn POOL_REWARD_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'POOL_REWARD_ADDRESS'>()
    }
    pub fn OTHER_REWARD_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'OTHER_REWARD_ADDRESS'>()
    }
    pub fn SPENDER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'SPENDER_ADDRESS'>()
    }
    pub fn NON_TOKEN_ADMIN() -> ContractAddress nopanic {
        contract_address_const::<'NON_TOKEN_ADMIN'>()
    }
    pub fn NON_SECURITY_ADMIN() -> ContractAddress nopanic {
        contract_address_const::<'NON_SECURITY_ADMIN'>()
    }
    pub fn NON_SECURITY_AGENT() -> ContractAddress nopanic {
        contract_address_const::<'NON_SECURITY_AGENT'>()
    }
    pub fn STRK_TOKEN_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<
            0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d,
        >()
    }
    pub fn TOKEN_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'TOKEN_ADDRESS'>()
    }
    pub fn DUMMY_CLASS_HASH() -> ClassHash nopanic {
        class_hash_const::<'DUMMY'>()
    }
    pub fn POOL_CONTRACT_ADMIN() -> ContractAddress nopanic {
        contract_address_const::<'POOL_CONTRACT_ADMIN'>()
    }
    pub fn SECURITY_ADMIN() -> ContractAddress nopanic {
        contract_address_const::<'SECURITY_ADMIN'>()
    }
    pub fn SECURITY_AGENT() -> ContractAddress nopanic {
        contract_address_const::<'SECURITY_AGENT'>()
    }
    pub fn TOKEN_ADMIN() -> ContractAddress nopanic {
        contract_address_const::<'TOKEN_ADMIN'>()
    }
    pub fn APP_ROLE_ADMIN() -> ContractAddress nopanic {
        contract_address_const::<'APP_ROLE_ADMIN'>()
    }
    pub fn UPGRADE_GOVERNOR() -> ContractAddress nopanic {
        contract_address_const::<'UPGRADE_GOVERNOR'>()
    }
    pub fn APP_GOVERNOR() -> ContractAddress nopanic {
        contract_address_const::<'APP_GOVERNOR'>()
    }
    pub fn STARKGATE_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'STARKGATE_ADDRESS'>()
    }
    pub fn NOT_STARKGATE_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'NOT_STARKGATE_ADDRESS'>()
    }
    pub fn ATTESTATION_CONTRACT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<'ATTESTATION_CONTRACT_ADDRESS'>()
    }
    pub fn DEFAULT_EPOCH_INFO() -> EpochInfo {
        EpochInfoTrait::new(
            block_duration: BLOCK_DURATION,
            length: EPOCH_LENGTH,
            starting_block: EPOCH_STARTING_BLOCK,
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
    commission: Commission,
    governance_admin: ContractAddress,
) -> Pool::ContractState {
    let mut state = Pool::contract_state_for_testing();
    Pool::constructor(
        ref state,
        :staker_address,
        :staking_contract,
        :token_address,
        :commission,
        :governance_admin,
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
        governance_admin: cfg.test_info.app_role_admin,
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
            cfg.staker_info._deprecated_amount_own,
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
            cfg.staker_info._deprecated_amount_own,
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
            cfg.staker_info._deprecated_amount_own,
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

pub(crate) fn load_pool_member_info_from_map<K, +Serde<K>, +Copy<K>, +Drop<K>>(
    key: K, contract: ContractAddress,
) -> VInternalPoolMemberInfo {
    let map_selector = selector!("pool_member_info");
    let mut keys = array![];
    key.serialize(ref keys);
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: keys.span());
    let mut raw_serialized_value = snforge_std::load(
        target: contract,
        :storage_address,
        size: Store::<Option<InternalPoolMemberInfoLatest>>::size().into(),
    );
    let idx = raw_serialized_value.pop_front().expect('Failed pop_front');
    if idx.is_zero() {
        return VInternalPoolMemberInfo::None;
    }
    assert!(idx == 2, "Invalid Option loaded from map");
    let mut span = raw_serialized_value.span();
    let mut pool_member_info = InternalPoolMemberInfoLatest {
        reward_address: Serde::<ContractAddress>::deserialize(ref span).expect('Failed reward'),
        _deprecated_amount: Serde::<Amount>::deserialize(ref span)
            .expect('Failed _deprecated_amount'),
        _deprecated_index: Serde::<Index>::deserialize(ref span).expect('Failed _deprecated_index'),
        _deprecated_unclaimed_rewards: Serde::<Amount>::deserialize(ref span)
            .expect('Failed _deprecated_unclaimed'),
        _deprecated_commission: Serde::<Commission>::deserialize(ref span)
            .expect('Failed _deprecated_commission'),
        unpool_amount: Serde::<Amount>::deserialize(ref span).expect('Failed unpool_amount'),
        unpool_time: Option::None,
        last_claimed_idx_in_member_vec: Zero::zero(),
    };
    let idx = *span.pop_front().expect('Failed pop_front');
    if idx.is_non_zero() {
        assert!(idx == 1, "Invalid Option loaded from map");
        pool_member_info
            .unpool_time =
                Option::Some(
                    Serde::<Timestamp>::deserialize(ref span).expect('Failed unpool_time'),
                );
    } else {
        // If idx is zero, the unpool_time is Option::None.
        // Since Option<Timestamp> takes 2 felts in storage, we need to pop both felts before
        // deserializing the next field last_claimed_idx_in_member_vec.
        let _ = span.pop_front();
    }
    pool_member_info
        .last_claimed_idx_in_member_vec = Serde::<VecIndex>::deserialize(ref span)
        .expect('Failed last_claimed');
    return VInternalPoolMemberInfoTrait::wrap_latest(pool_member_info);
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

fn change_global_index(ref cfg: StakingInitConfig, index: Index) {
    snforge_std::store(
        target: cfg.test_info.staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![index.into()].span(),
    );
    cfg.staking_contract_info.global_index = index;
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

pub(crate) fn load_staker_info_from_map(
    staker_address: ContractAddress, contract: ContractAddress,
) -> VersionedInternalStakerInfo {
    let map_selector = selector!("staker_info");
    let mut keys = array![];
    staker_address.serialize(ref keys);
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: keys.span());
    let mut raw_serialized_value = snforge_std::load(
        target: contract,
        :storage_address,
        size: Store::<VersionedInternalStakerInfo>::size().into(),
    );
    let idx = raw_serialized_value.pop_front().expect('Failed pop_front');
    if idx.is_zero() {
        return VersionedInternalStakerInfo::None;
    }
    assert!(idx == 2, "Invalid Version loaded from map");
    let mut span = raw_serialized_value.span();
    let staker_info = VersionedInternalStakerInfoTrait::new_latest(
        reward_address: Serde::<ContractAddress>::deserialize(ref span).expect('Failed reward'),
        operational_address: Serde::<ContractAddress>::deserialize(ref span)
            .expect('Failed operational'),
        unstake_time: deserialize_option(ref data: span),
        amount_own: Serde::<Amount>::deserialize(ref span).expect('Failed amount_own'),
        index: Serde::<Index>::deserialize(ref span).expect('Failed index'),
        unclaimed_rewards_own: Serde::<Amount>::deserialize(ref span)
            .expect('Failed unclaimed_rewards_own'),
        pool_info: deserialize_option(ref data: span),
    );
    return staker_info;
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
    pub staking_contract: ContractAddress,
    pub pool_contract_admin: ContractAddress,
    pub security_admin: ContractAddress,
    pub security_agent: ContractAddress,
    pub token_admin: ContractAddress,
    pub app_role_admin: ContractAddress,
    pub upgrade_governor: ContractAddress,
    pub attestation_contract: ContractAddress,
    pub attestation_window: u8,
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
            _deprecated_amount_own: STAKE_AMOUNT,
            index: Zero::zero(),
            unclaimed_rewards_own: 0,
            pool_info: Option::Some(
                StakerPoolInfo {
                    pool_contract: POOL_CONTRACT_ADDRESS(),
                    amount: Zero::zero(),
                    unclaimed_rewards: Zero::zero(),
                    commission: COMMISSION,
                },
            ),
        };
        let pool_member_info = InternalPoolMemberInfoLatest {
            reward_address: POOL_MEMBER_REWARD_ADDRESS(),
            _deprecated_amount: POOL_MEMBER_STAKE_AMOUNT,
            _deprecated_index: Zero::zero(),
            _deprecated_unclaimed_rewards: Zero::zero(),
            _deprecated_commission: COMMISSION,
            unpool_time: Option::None,
            unpool_amount: Zero::zero(),
            last_claimed_idx_in_member_vec: Zero::zero(),
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
            staking_contract: STAKING_CONTRACT_ADDRESS(),
            pool_contract_admin: POOL_CONTRACT_ADMIN(),
            security_admin: SECURITY_ADMIN(),
            security_agent: SECURITY_AGENT(),
            token_admin: TOKEN_ADMIN(),
            app_role_admin: APP_ROLE_ADMIN(),
            upgrade_governor: UPGRADE_GOVERNOR(),
            attestation_contract: ATTESTATION_CONTRACT_ADDRESS(),
            attestation_window: MIN_ATTESTATION_WINDOW + 1,
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
pub(crate) fn staker_update_rewards(staker_info: StakerInfo, global_index: Index) -> StakerInfo {
    let interest: Index = global_index - staker_info.index;
    let mut staker_rewards = compute_rewards_rounded_down(
        amount: staker_info.amount_own, :interest,
    );
    let mut staker_pool_info: Option<StakerPoolInfo> = Option::None;
    if let Option::Some(pool_info) = staker_info.pool_info {
        let pool_rewards_including_commission = compute_rewards_rounded_up(
            amount: pool_info.amount, :interest,
        );
        let commission_amount = compute_commission_amount_rounded_down(
            rewards_including_commission: pool_rewards_including_commission,
            commission: pool_info.commission,
        );
        staker_rewards += commission_amount;
        let pool_rewards = pool_rewards_including_commission - commission_amount;
        staker_pool_info =
            Option::Some(
                StakerPoolInfo {
                    unclaimed_rewards: pool_info.unclaimed_rewards + pool_rewards, ..pool_info,
                },
            );
    };
    StakerInfo {
        index: global_index,
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
        div: staking_dispatcher.get_total_stake_at_current_epoch(),
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

pub(crate) fn calculate_staker_own_rewards_include_commission(
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
        return pool_info.amount + staker_info.amount_own;
    }
    (staker_info.amount_own)
}
