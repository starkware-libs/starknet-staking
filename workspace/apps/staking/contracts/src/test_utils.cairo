use contracts::{
    staking::Staking, pooling::Pooling, minting_curve::MintingCurve, reward_supplier::RewardSupplier
};
use contracts::constants::BASE_VALUE;
use core::traits::Into;
use contracts::staking::interface::{
    IStaking, StakerInfo, StakingContractInfo, IStakingDispatcher, IStakingDispatcherTrait
};
use contracts::pooling::interface::{
    IPooling, PoolMemberInfo, IPoolingDispatcher, IPoolingDispatcherTrait
};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::{ContractAddress, contract_address_const, get_caller_address};
use starknet::syscalls::deploy_syscall;
use starknet::ClassHash;
use starknet::Store;
use snforge_std::{declare, ContractClassTrait};
use contracts::staking::Staking::ContractState;
use constants::{
    NAME, SYMBOL, INITIAL_SUPPLY, OWNER_ADDRESS, MIN_STAKE, STAKER_INITIAL_BALANCE, STAKE_AMOUNT,
    STAKER_ADDRESS, OPERATIONAL_ADDRESS, STAKER_REWARD_ADDRESS, TOKEN_ADDRESS, REV_SHARE,
    POOLING_CONTRACT_ADDRESS, POOL_MEMBER_STAKE_AMOUNT, DUMMY_CLASS_HASH, POOL_MEMBER_ADDRESS,
    POOL_MEMBER_REWARD_ADDRESS, POOL_MEMBER_INITIAL_BALANCE, BASE_MINT_AMOUNT, BUFFER,
    L1_STAKING_MINTER_ADDRESS, BASE_MINT_MSG, STAKING_CONTRACT_ADDRESS, MINTING_CONTRACT_ADDRESS
};
use snforge_std::{ContractClass, CheatSpan, cheat_caller_address, test_address};
pub(crate) mod constants {
    use starknet::{ContractAddress, contract_address_const};
    use starknet::class_hash::{ClassHash, class_hash_const};

    pub const STAKER_INITIAL_BALANCE: u128 = 10000000000;
    pub const POOL_MEMBER_INITIAL_BALANCE: u128 = 10000000000;
    pub const INITIAL_SUPPLY: u256 = 10000000000000000;
    pub const MIN_STAKE: u128 = 100000;
    pub const STAKE_AMOUNT: u128 = 200000;
    pub const POOL_MEMBER_STAKE_AMOUNT: u128 = 100000;
    pub const REV_SHARE: u16 = 500;
    pub const STAKER_FINAL_INDEX: u64 = 10;
    pub const BASE_MINT_AMOUNT: u128 = 800000000000;
    pub const BUFFER: u128 = 1000000000000;
    pub const L1_STAKING_MINTER_ADDRESS: felt252 = 'L1_STAKING_MINTER_ADDRESS';
    pub const BASE_MINT_MSG: felt252 = 'base_mint_msg';


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
    pub fn NOT_STAKING_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<'NOT_STAKING_CONTRACT_ADDRESS'>()
    }
    pub fn POOLING_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<'POOLING_CONTRACT_ADDRESS'>()
    }
    pub fn OTHER_POOL_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<'OTHER_POOL_CONTRACT_ADDRESS'>()
    }
    pub fn MINTING_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<'MINTING_CONTRACT_ADDRESS'>()
    }
    pub fn REWARD_SUPPLIER_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<'REWARD_SUPPLIER_ADDRESS'>()
    }
    pub fn RECIPIENT_ADDRESS() -> ContractAddress {
        contract_address_const::<'RECIPIENT_ADDRESS'>()
    }
    pub fn STAKER_REWARD_ADDRESS() -> ContractAddress {
        contract_address_const::<'STAKER_REWARD_ADDRESS'>()
    }
    pub fn POOL_MEMBER_REWARD_ADDRESS() -> ContractAddress {
        contract_address_const::<'POOL_MEMBER_REWARD_ADDRESS'>()
    }
    pub fn POOLING_REWARD_ADDRESS() -> ContractAddress {
        contract_address_const::<'POOLING_REWARD_ADDRESS'>()
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
        pool_contract_class_hash: cfg.test_info.pool_contract_class_hash
    )
}
pub(crate) fn initialize_staking_state(
    token_address: ContractAddress, min_stake: u128, pool_contract_class_hash: ClassHash
) -> Staking::ContractState {
    let mut state = Staking::contract_state_for_testing();
    Staking::constructor(ref state, token_address, min_stake, pool_contract_class_hash);
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
    staking_contract: ContractAddress, total_supply: u128, l1_staking_minter_address: felt252
) -> MintingCurve::ContractState {
    let mut state = MintingCurve::contract_state_for_testing();
    MintingCurve::constructor(
        ref state, :staking_contract, :total_supply, :l1_staking_minter_address
    );
    state
}

pub(crate) fn initialize_reward_supplier_state_from_cfg(
    cfg: StakingInitConfig
) -> RewardSupplier::ContractState {
    initialize_reward_supplier_state(
        base_mint_amount: cfg.reward_supplier.base_mint_amount,
        base_mint_msg: cfg.reward_supplier.base_mint_msg,
        minting_curve_contract: cfg.reward_supplier.minting_curve_contract,
        staking_contract: cfg.test_info.staking_contract,
        l1_staking_minter: cfg.reward_supplier.l1_staking_minter,
        buffer: cfg.reward_supplier.buffer
    )
}
pub(crate) fn initialize_reward_supplier_state(
    base_mint_amount: u128,
    base_mint_msg: felt252,
    minting_curve_contract: ContractAddress,
    staking_contract: ContractAddress,
    l1_staking_minter: felt252,
    buffer: u128
) -> RewardSupplier::ContractState {
    let mut state = RewardSupplier::contract_state_for_testing();
    RewardSupplier::constructor(
        ref state,
        :base_mint_amount,
        :base_mint_msg,
        :minting_curve_contract,
        :staking_contract,
        :l1_staking_minter,
        :buffer
    );
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

pub(crate) fn fund_and_approve_for_stake(
    cfg: StakingInitConfig, staking_contract: ContractAddress, token_address: ContractAddress
) {
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
}

// Stake according to the given configuration, the staker is cfg.test_info.staker_address.
pub(crate) fn stake_for_testing(
    ref state: ContractState, cfg: StakingInitConfig, token_address: ContractAddress
) {
    let staking_contract = test_address();
    fund_and_approve_for_stake(:cfg, :staking_contract, :token_address);
    cheat_caller_address(staking_contract, cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    state
        .stake(
            cfg.staker_info.reward_address,
            cfg.staker_info.operational_address,
            cfg.staker_info.amount_own,
            cfg.test_info.pooling_enabled,
            cfg.staker_info.rev_share
        );
}

pub(crate) fn stake_for_testing_using_dispatcher(
    cfg: StakingInitConfig, token_address: ContractAddress, staking_contract: ContractAddress
) {
    fund_and_approve_for_stake(:cfg, :staking_contract, :token_address);
    cheat_caller_address(staking_contract, cfg.test_info.staker_address, CheatSpan::TargetCalls(1));
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };
    staking_dispatcher
        .stake(
            cfg.staker_info.reward_address,
            cfg.staker_info.operational_address,
            cfg.staker_info.amount_own,
            cfg.test_info.pooling_enabled,
            cfg.staker_info.rev_share
        );
}

pub(crate) fn stake_with_pooling_enabled(
    mut cfg: StakingInitConfig, token_address: ContractAddress, staking_contract: ContractAddress
) -> ContractAddress {
    cfg.test_info.pooling_enabled = true;

    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    let staking_dispatcher = IStakingDispatcher { contract_address: staking_contract };

    staking_dispatcher
        .state_of(cfg.test_info.staker_address)
        .pooling_contract
        .expect('Pool contract is none')
}

pub(crate) fn enter_delegation_pool_for_testing_using_dispatcher(
    pooling_contract: ContractAddress, cfg: StakingInitConfig, token_address: ContractAddress
) {
    // Transfer the stake amount to the pool member.
    fund(
        sender: cfg.test_info.owner_address,
        recipient: cfg.test_info.pool_member_address,
        amount: cfg.test_info.pool_member_initial_balance,
        :token_address
    );

    // Approve the pooling contract to transfer the pool member's funds.
    approve(
        owner: cfg.test_info.pool_member_address,
        spender: pooling_contract,
        amount: cfg.pool_member_info.amount,
        :token_address
    );

    // Enter the delegation pool.
    cheat_caller_address(
        pooling_contract, cfg.test_info.pool_member_address, CheatSpan::TargetCalls(1)
    );
    let pooling_dispatcher = IPoolingDispatcher { contract_address: pooling_contract };
    assert!(
        pooling_dispatcher
            .enter_delegation_pool(
                amount: cfg.pool_member_info.amount,
                reward_address: cfg.pool_member_info.reward_address
            )
    );
}

/// *****WARNING*****
/// This function only works on simple data types or structs that have no special implementations
/// for Hash, Store, or Serde traits. And won't work on any standard enum.
/// This statement applies to both key and value.
/// The trait used to serialize and deserialize the key for the address calculation is Hash trait.
/// The trait used to serialize and deserialize the value for the storage is Store trait.
/// The trait used to serialize and deserialize the key and value in this function is Serde trait.
/// Note: It could work for non-simple types that implement Hash, Store and Serde the same way.
pub(crate) fn load_from_simple_map<K, +Serde<K>, +Copy<K>, +Drop<K>, V, +Serde<V>, +Store<V>>(
    map_selector: felt252, key: K, contract: ContractAddress
) -> V {
    let mut keys = array![];
    key.serialize(ref keys);
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: keys.span());
    let serialized_value = snforge_std::load(
        target: contract, :storage_address, size: Store::<V>::size().into()
    );
    let mut span = serialized_value.span();
    Serde::<V>::deserialize(ref span).expect('Failed deserialize')
}

// This only works for shallow Option. i.e. if within V there is an Option, this will fail.
pub(crate) fn load_option_from_simple_map<
    K, +Serde<K>, +Copy<K>, +Drop<K>, V, +Serde<V>, +Store<Option<V>>
>(
    map_selector: felt252, key: K, contract: ContractAddress
) -> Option<V> {
    let mut keys = array![];
    key.serialize(ref keys);
    let storage_address = snforge_std::map_entry_address(:map_selector, keys: keys.span());
    let mut raw_serialized_value = snforge_std::load(
        target: contract, :storage_address, size: Store::<Option<V>>::size().into()
    );
    let idx = raw_serialized_value.pop_front().expect('Failed pop_front');
    let mut span = raw_serialized_value.span();
    match idx {
        0 => Option::None,
        1 => Option::Some(Serde::<V>::deserialize(ref span).expect('Failed deserialize')),
        _ => panic!("Invalid Option loaded from map"),
    }
}

#[derive(Drop, Copy)]
pub(crate) struct TestInfo {
    pub staker_address: ContractAddress,
    pub pool_member_address: ContractAddress,
    pub owner_address: ContractAddress,
    pub initial_supply: u256,
    pub staker_initial_balance: u128,
    pub pool_member_initial_balance: u128,
    pub pooling_enabled: bool,
    pub pool_contract_class_hash: ClassHash,
    pub staking_contract: ContractAddress,
}

#[derive(Drop, Copy)]
struct RewardSupplierInfo {
    pub base_mint_amount: u128,
    pub base_mint_msg: felt252,
    pub minting_curve_contract: ContractAddress,
    pub l1_staking_minter: felt252,
    pub buffer: u128,
}

#[derive(Drop, Copy)]
pub(crate) struct StakingInitConfig {
    pub staker_info: StakerInfo,
    pub pool_member_info: PoolMemberInfo,
    pub staking_contract_info: StakingContractInfo,
    pub test_info: TestInfo,
    pub reward_supplier: RewardSupplierInfo,
}

impl StakingInitConfigDefault of Default<StakingInitConfig> {
    fn default() -> StakingInitConfig {
        let staker_info = StakerInfo {
            reward_address: STAKER_REWARD_ADDRESS(),
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
        let pool_member_info = PoolMemberInfo {
            reward_address: POOL_MEMBER_REWARD_ADDRESS(),
            amount: POOL_MEMBER_STAKE_AMOUNT,
            index: BASE_VALUE,
            unclaimed_rewards: 0,
            unpool_time: Option::None,
        };
        let staking_contract_info = StakingContractInfo {
            min_stake: MIN_STAKE, token_address: TOKEN_ADDRESS(), global_index: BASE_VALUE,
        };
        let test_info = TestInfo {
            staker_address: STAKER_ADDRESS(),
            pool_member_address: POOL_MEMBER_ADDRESS(),
            owner_address: OWNER_ADDRESS(),
            initial_supply: INITIAL_SUPPLY,
            staker_initial_balance: STAKER_INITIAL_BALANCE,
            pool_member_initial_balance: POOL_MEMBER_INITIAL_BALANCE,
            pooling_enabled: false,
            pool_contract_class_hash: declare_pool_contract(),
            staking_contract: STAKING_CONTRACT_ADDRESS(),
        };
        let reward_supplier = RewardSupplierInfo {
            base_mint_amount: BASE_MINT_AMOUNT,
            base_mint_msg: BASE_MINT_MSG,
            minting_curve_contract: MINTING_CONTRACT_ADDRESS(),
            l1_staking_minter: L1_STAKING_MINTER_ADDRESS,
            buffer: BUFFER,
        };
        StakingInitConfig {
            staker_info, pool_member_info, staking_contract_info, test_info, reward_supplier
        }
    }
}

