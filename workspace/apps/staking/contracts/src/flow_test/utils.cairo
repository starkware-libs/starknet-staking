use MainnetClassHashes::{
    MAINNET_ATTESTATION_CLASS_HASH_V1, MAINNET_MINTING_CURVE_CLASS_HASH_V0,
    MAINNET_POOL_CLASS_HASH_V0, MAINNET_POOL_CLASS_HASH_V1, MAINNET_REWARD_SUPPLIER_CLASS_HASH_V0,
    MAINNET_REWARD_SUPPLIER_CLASS_HASH_V1, MAINNET_STAKING_CLASS_HASH_V0,
    MAINNET_STAKING_CLASS_HASH_V1,
};
use core::num::traits::zero::Zero;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, Token, TokenImpl, TokenTrait,
    cheat_caller_address, start_cheat_block_hash_global, start_cheat_block_number_global,
    start_cheat_block_timestamp_global,
};
use staking_test::attestation::interface::{
    IAttestationDispatcher, IAttestationDispatcherTrait, IAttestationSafeDispatcher,
    IAttestationSafeDispatcherTrait,
};
use staking_test::constants::{BTC_18D_CONFIG, DEFAULT_C_NUM, MIN_ATTESTATION_WINDOW};
use staking_test::minting_curve::interface::{
    IMintingCurveConfigDispatcher, IMintingCurveConfigDispatcherTrait, IMintingCurveDispatcher,
};
use staking_test::pool::interface::{
    IPoolDispatcher, IPoolDispatcherTrait, IPoolMigrationDispatcher, IPoolMigrationDispatcherTrait,
    IPoolSafeDispatcher, IPoolSafeDispatcherTrait, PoolContractInfoV1, PoolMemberInfoV1,
};
use staking_test::pool::interface_v0::{IPoolV0Dispatcher, IPoolV0DispatcherTrait, PoolMemberInfo};
use staking_test::reward_supplier::interface::{
    IRewardSupplierDispatcher, IRewardSupplierDispatcherTrait,
};
use staking_test::staking::interface::{
    CommissionCommitment, IStakingConfigDispatcher, IStakingConfigDispatcherTrait,
    IStakingDispatcher, IStakingDispatcherTrait, IStakingMigrationDispatcher,
    IStakingMigrationDispatcherTrait, IStakingPauseDispatcher, IStakingPauseDispatcherTrait,
    IStakingPoolDispatcher, IStakingPoolSafeDispatcher, IStakingSafeDispatcher,
    IStakingSafeDispatcherTrait, IStakingTokenManagerDispatcher,
    IStakingTokenManagerDispatcherTrait, IStakingTokenManagerSafeDispatcher,
    IStakingTokenManagerSafeDispatcherTrait, StakerInfoV1, StakerInfoV1Trait, StakerPoolInfoV2,
};
use staking_test::staking::interface_v0::{
    IStakingV0ForTestsDispatcher, IStakingV0ForTestsDispatcherTrait, StakerInfo, StakerInfoTrait,
};
use staking_test::staking::interface_v1::{
    IStakingV1ForTestsDispatcher, IStakingV1ForTestsDispatcherTrait,
};
use staking_test::staking::objects::{EpochInfo, EpochInfoTrait, NormalizedAmount};
use staking_test::test_utils::constants::{
    BTC_TOKEN_NAME, BTC_TOKEN_NAME_2, EPOCH_DURATION, EPOCH_LENGTH, EPOCH_STARTING_BLOCK,
    INITIAL_SUPPLY, MAINNET_SECURITY_COUNSEL_ADDRESS, OWNER_ADDRESS, STARTING_BLOCK_OFFSET,
    TEST_BTC_DECIMALS, UPGRADE_GOVERNOR,
};
use staking_test::test_utils::{
    StakingInitConfig, approve, calculate_block_offset, custom_decimals_token,
    declare_pool_contract, declare_pool_eic_contract, declare_staking_eic_contract_v0_v1,
    declare_staking_eic_contract_v1_v2, deploy_mock_erc20_decimals_contract, fund,
};
use staking_test::types::{
    Amount, Commission, Epoch, Index, Inflation, InternalPoolMemberInfoLatest,
    InternalStakerInfoLatest, VecIndex,
};
use starknet::syscalls::deploy_syscall;
use starknet::{ClassHash, ContractAddress, Store, SyscallResultTrait, get_block_number};
use starkware_utils::components::replaceability::interface::{
    EICData, IReplaceableDispatcher, IReplaceableDispatcherTrait, ImplementationData,
};
use starkware_utils::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
use starkware_utils::constants::SYMBOL;
use starkware_utils::time::time::{Time, TimeDelta, Timestamp};
use starkware_utils_testing::test_utils::{
    TokenConfig, advance_block_number_global, cheat_caller_address_once,
    set_account_as_app_governor, set_account_as_app_role_admin, set_account_as_security_admin,
    set_account_as_security_agent, set_account_as_token_admin, set_account_as_upgrade_governor,
};

mod MainnetAddresses {
    use starknet::ContractAddress;

    pub fn MAINNET_L2_BRIDGE_ADDRESS() -> ContractAddress {
        0x0594c1582459ea03f77deaf9eb7e3917d6994a03c13405ba42867f83d85f085d.try_into().unwrap()
    }
}

/// Contains class hashes of mainnet contracts.
pub mod MainnetClassHashes {
    use starknet::class_hash::ClassHash;

    /// Class hash of the first staking contract deployed on mainnet.
    pub fn MAINNET_STAKING_CLASS_HASH_V0() -> ClassHash {
        0x31578ba8535c5be427c03412d596fe17d3cecfc2b4a3040b841c009fe4ac5f5.try_into().unwrap()
    }

    /// Class hash of the second staking contract deployed on mainnet (upgraded in V1).
    pub fn MAINNET_STAKING_CLASS_HASH_V1() -> ClassHash {
        0x03f85b23fd3c13e55134f583f22f3046d0e2cc2e6a6c61431137cee9d55deaf7.try_into().unwrap()
    }

    /// Class hash of the first reward supplier contract deployed on mainnet.
    pub fn MAINNET_REWARD_SUPPLIER_CLASS_HASH_V0() -> ClassHash {
        0x7cbbebcdbbce7bd45611d8b679e524b63586429adee0f858b7f0994d709d648.try_into().unwrap()
    }

    /// Class hash of the second reward supplier contract deployed on mainnet (upgraded in V1).
    pub fn MAINNET_REWARD_SUPPLIER_CLASS_HASH_V1() -> ClassHash {
        0x7dbce96b61d0195129103eca514936992f290062bcb95c7528f7383b062cde7.try_into().unwrap()
    }

    /// Class hash of the first minting curve contract deployed on mainnet.
    pub fn MAINNET_MINTING_CURVE_CLASS_HASH_V0() -> ClassHash {
        0xb00a4f0a3ba3f266837da66c0c3053c4676046a2d621e80d1f822fe9c9b5f6.try_into().unwrap()
    }

    /// Class hash of the first pool contract deployed on mainnet.
    pub fn MAINNET_POOL_CLASS_HASH_V0() -> ClassHash {
        0x072ddc6cc22fb26453334e9cf1cbb92f12d2946d058e2b2b571c65d0f23d6516.try_into().unwrap()
    }

    /// Class hash of the second pool contract deployed on mainnet (upgraded in V1).
    pub fn MAINNET_POOL_CLASS_HASH_V1() -> ClassHash {
        0x05f6abc83b23af3af179388e1e2bf93096047ba6d8c480360d3c88f7d175bdef.try_into().unwrap()
    }

    /// Class hash of the first attestation contract deployed on mainnet (deployed in V1).
    pub fn MAINNET_ATTESTATION_CLASS_HASH_V1() -> ClassHash {
        0x06f9f82c74ee893a56f12480fac55ff89855e38cd132ee50ac11cb51f83623d3.try_into().unwrap()
    }
}

/// The `StakingRoles` struct represents the various roles involved in the staking contract.
/// It includes addresses for different administrative and security roles.
#[derive(Drop, Copy)]
pub struct StakingRoles {
    pub upgrade_governor: ContractAddress,
    pub security_admin: ContractAddress,
    pub security_agent: ContractAddress,
    pub app_role_admin: ContractAddress,
    pub token_admin: ContractAddress,
    pub app_governor: ContractAddress,
}

/// The `StakingConfig` struct represents the configuration settings for the staking contract.
/// It includes various parameters and roles required for the staking contract's operation.
///
/// # Fields
/// - `min_stake` (Amount): The minimum amount of tokens required to stake.
/// - `pool_contract_class_hash` (ClassHash): The class hash of the pool contract.
/// - `reward_supplier` (ContractAddress): The address of the reward supplier contract.
/// - `pool_contract_admin` (ContractAddress): The address of the pool contract administrator.
/// - `governance_admin` (ContractAddress): The address of the governance administrator.
#[derive(Drop, Copy)]
pub struct StakingConfig {
    pub min_stake: Amount,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
    pub pool_contract_admin: ContractAddress,
    pub governance_admin: ContractAddress,
    pub prev_staking_contract_class_hash: ClassHash,
    pub epoch_info: EpochInfo,
    pub attestation_contract: ContractAddress,
    pub roles: StakingRoles,
}

/// The `StakingState` struct represents the state of the staking contract.
/// It includes the contract address, governance administrator, and roles.
#[derive(Drop, Copy)]
pub struct StakingState {
    pub address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: StakingRoles,
}

#[generate_trait]
pub impl StakingImpl of StakingTrait {
    fn deploy(self: StakingConfig) -> StakingState {
        let mut calldata = ArrayTrait::new();
        self.min_stake.serialize(ref calldata);
        self.pool_contract_class_hash.serialize(ref calldata);
        self.reward_supplier.serialize(ref calldata);
        self.pool_contract_admin.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        self.prev_staking_contract_class_hash.serialize(ref calldata);
        self.epoch_info.serialize(ref calldata);
        self.attestation_contract.serialize(ref calldata);
        let staking_contract = snforge_std::declare("Staking").unwrap().contract_class();
        let (staking_contract_address, _) = staking_contract.deploy(@calldata).unwrap();
        let staking = StakingState {
            address: staking_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        staking.set_roles();
        staking
    }

    fn deploy_mainnet_contract_v0(
        self: StakingConfig, token_address: ContractAddress,
    ) -> StakingState {
        let mut calldata = ArrayTrait::new();
        token_address.serialize(ref calldata);
        self.min_stake.serialize(ref calldata);
        self.pool_contract_class_hash.serialize(ref calldata);
        self.reward_supplier.serialize(ref calldata);
        self.pool_contract_admin.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        let contract_address_salt: felt252 = Time::now().seconds.into();
        let (staking_contract_address, _) = deploy_syscall(
            class_hash: MAINNET_STAKING_CLASS_HASH_V0(),
            :contract_address_salt,
            calldata: calldata.span(),
            deploy_from_zero: false,
        )
            .unwrap_syscall();
        let staking = StakingState {
            address: staking_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        staking.set_roles();
        staking
    }

    fn dispatcher(self: StakingState) -> IStakingDispatcher nopanic {
        IStakingDispatcher { contract_address: self.address }
    }

    fn token_manager_dispatcher(self: StakingState) -> IStakingTokenManagerDispatcher nopanic {
        IStakingTokenManagerDispatcher { contract_address: self.address }
    }

    fn safe_token_manager_dispatcher(
        self: StakingState,
    ) -> IStakingTokenManagerSafeDispatcher nopanic {
        IStakingTokenManagerSafeDispatcher { contract_address: self.address }
    }

    fn is_v0(self: StakingState) -> bool {
        let class_hash = snforge_std::get_class_hash(self.address);
        class_hash == MAINNET_STAKING_CLASS_HASH_V0()
    }

    fn is_v1(self: StakingState) -> bool {
        let class_hash = snforge_std::get_class_hash(self.address);
        class_hash == MAINNET_STAKING_CLASS_HASH_V1()
    }

    fn safe_dispatcher(self: StakingState) -> IStakingSafeDispatcher nopanic {
        IStakingSafeDispatcher { contract_address: self.address }
    }

    fn dispatcher_v0_for_tests(self: StakingState) -> IStakingV0ForTestsDispatcher nopanic {
        IStakingV0ForTestsDispatcher { contract_address: self.address }
    }

    fn dispatcher_v1_for_tests(self: StakingState) -> IStakingV1ForTestsDispatcher nopanic {
        IStakingV1ForTestsDispatcher { contract_address: self.address }
    }

    fn migration_dispatcher(self: StakingState) -> IStakingMigrationDispatcher nopanic {
        IStakingMigrationDispatcher { contract_address: self.address }
    }

    fn pause_dispatcher(self: StakingState) -> IStakingPauseDispatcher nopanic {
        IStakingPauseDispatcher { contract_address: self.address }
    }

    fn staking_pool_dispatcher(self: StakingState) -> IStakingPoolDispatcher nopanic {
        IStakingPoolDispatcher { contract_address: self.address }
    }

    fn safe_staking_pool_dispatcher(self: StakingState) -> IStakingPoolSafeDispatcher nopanic {
        IStakingPoolSafeDispatcher { contract_address: self.address }
    }

    fn set_roles(self: StakingState) {
        set_account_as_upgrade_governor(
            contract: self.address,
            account: self.roles.upgrade_governor,
            governance_admin: self.governance_admin,
        );
        set_account_as_security_admin(
            contract: self.address,
            account: self.roles.security_admin,
            governance_admin: self.governance_admin,
        );
        set_account_as_security_agent(
            contract: self.address,
            account: self.roles.security_agent,
            security_admin: self.roles.security_admin,
        );
        set_account_as_app_role_admin(
            contract: self.address,
            account: self.roles.app_role_admin,
            governance_admin: self.governance_admin,
        );
        set_account_as_token_admin(
            contract: self.address,
            account: self.roles.token_admin,
            app_role_admin: self.roles.app_role_admin,
        );
        set_account_as_app_governor(
            contract: self.address,
            account: self.roles.app_governor,
            app_role_admin: self.roles.app_role_admin,
        );
    }

    fn get_pool(self: StakingState, staker: Staker) -> ContractAddress {
        if self.is_v0() {
            self
                .dispatcher_v0_for_tests()
                .staker_info(staker_address: staker.staker.address)
                .get_pool_info()
                .pool_contract
        } else {
            self
                .dispatcher()
                .staker_info_v1(staker_address: staker.staker.address)
                .get_pool_info()
                .pool_contract
        }
    }

    fn get_min_stake(self: StakingState) -> Amount {
        if self.is_v0() {
            self.dispatcher_v0_for_tests().contract_parameters().min_stake
        } else {
            self.dispatcher().contract_parameters_v1().min_stake
        }
    }

    fn get_token_address(self: StakingState) -> ContractAddress {
        if self.is_v0() {
            self.dispatcher_v0_for_tests().contract_parameters().token_address
        } else {
            self.dispatcher().contract_parameters_v1().token_address
        }
    }

    fn get_total_stake(self: StakingState) -> Amount {
        self.dispatcher().get_total_stake()
    }

    fn get_current_total_staking_power(self: StakingState) -> Amount {
        self.dispatcher_v1_for_tests().get_current_total_staking_power()
    }

    fn get_current_total_staking_power_v2(
        self: StakingState,
    ) -> (NormalizedAmount, NormalizedAmount) {
        self.dispatcher().get_current_total_staking_power()
    }

    fn get_exit_wait_window(self: StakingState) -> TimeDelta {
        if self.is_v0() {
            self.dispatcher_v0_for_tests().contract_parameters().exit_wait_window
        } else {
            self.dispatcher().contract_parameters_v1().exit_wait_window
        }
    }

    fn get_global_index(self: StakingState) -> Index {
        let global_index = *snforge_std::load(
            target: self.address,
            storage_address: selector!("global_index"),
            size: Store::<Index>::size().into(),
        )
            .at(0);
        global_index.try_into().unwrap()
    }

    fn get_pool_contract_admin(self: StakingState) -> ContractAddress {
        let pool_contract_admin = *snforge_std::load(
            target: self.address,
            storage_address: selector!("pool_contract_admin"),
            size: Store::<ContractAddress>::size().into(),
        )
            .at(0);
        pool_contract_admin.try_into().unwrap()
    }

    fn get_epoch_info(self: StakingState) -> EpochInfo {
        self.dispatcher().get_epoch_info()
    }

    fn get_current_epoch(self: StakingState) -> Epoch {
        self.dispatcher().get_current_epoch()
    }

    fn set_epoch_info(self: StakingState, epoch_duration: u32, epoch_length: u32) {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.app_governor,
        );
        let staking_config_dispatcher = IStakingConfigDispatcher { contract_address: self.address };
        staking_config_dispatcher.set_epoch_info(:epoch_duration, :epoch_length);
    }

    fn update_global_index_if_needed(self: StakingState) -> bool {
        self.dispatcher_v0_for_tests().update_global_index_if_needed()
    }

    fn pause(self: StakingState) {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.security_agent,
        );
        self.pause_dispatcher().pause()
    }

    fn unpause(self: StakingState) {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.security_admin,
        );
        self.pause_dispatcher().unpause()
    }

    fn get_stakers(self: StakingState) -> Span<ContractAddress> {
        let mut stakers = ArrayTrait::new();
        let vec_storage = selector!("stakers");
        let vec_len: VecIndex = (*snforge_std::load(
            target: self.address,
            storage_address: vec_storage,
            size: Store::<VecIndex>::size().into(),
        )
            .at(0))
            .try_into()
            .unwrap();
        for i in 0..vec_len {
            let staker_vec_storage = snforge_std::map_entry_address(
                map_selector: vec_storage, keys: [i.into()].span(),
            );
            let staker: ContractAddress = (*snforge_std::load(
                target: self.address,
                storage_address: staker_vec_storage,
                size: Store::<ContractAddress>::size().into(),
            )
                .at(0))
                .try_into()
                .unwrap();
            stakers.append(staker);
        }
        stakers.span()
    }

    fn add_token(self: StakingState, token_address: ContractAddress) {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.token_admin,
        );
        self.token_manager_dispatcher().add_token(:token_address);
    }

    fn enable_token(self: StakingState, token_address: ContractAddress) {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.token_admin,
        );
        self.token_manager_dispatcher().enable_token(:token_address);
    }

    fn disable_token(self: StakingState, token_address: ContractAddress) {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.security_agent,
        );
        self.token_manager_dispatcher().disable_token(:token_address);
    }

    #[feature("safe_dispatcher")]
    fn safe_disable_token(
        self: StakingState, token_address: ContractAddress,
    ) -> Result<(), Array<felt252>> {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.security_agent,
        );
        self.safe_token_manager_dispatcher().disable_token(:token_address)
    }

    #[feature("safe_dispatcher")]
    fn safe_enable_token(
        self: StakingState, token_address: ContractAddress,
    ) -> Result<(), Array<felt252>> {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.token_admin,
        );
        self.safe_token_manager_dispatcher().enable_token(:token_address)
    }
}

/// The `MintingCurveRoles` struct represents the various roles involved in the minting curve
/// contract.
/// It includes addresses for different administrative roles.
#[derive(Drop, Copy)]
pub struct MintingCurveRoles {
    pub upgrade_governor: ContractAddress,
    pub app_role_admin: ContractAddress,
    pub token_admin: ContractAddress,
}

/// The `MintingCurveConfig` struct represents the configuration settings for the minting curve
/// contract.
/// It includes various parameters and roles required for the minting curve contract's operation.
///
/// # Fields
/// - `initial_supply` (Amount): The initial supply of tokens to be minted.
/// - `governance_admin` (ContractAddress).
/// - `l1_reward_supplier` (felt252).
/// - `roles` (MintingCurveRoles).
#[derive(Drop, Copy)]
pub struct MintingCurveConfig {
    pub initial_supply: Amount,
    pub governance_admin: ContractAddress,
    pub l1_reward_supplier: felt252,
    pub roles: MintingCurveRoles,
}

/// The `MintingCurveState` struct represents the state of the minting curve contract.
/// It includes the contract address, governance administrator, and roles.
#[derive(Drop, Copy)]
pub struct MintingCurveState {
    pub address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: MintingCurveRoles,
}

#[generate_trait]
impl MintingCurveImpl of MintingCurveTrait {
    fn deploy(self: MintingCurveConfig, staking: StakingState) -> MintingCurveState {
        let mut calldata = ArrayTrait::new();
        staking.address.serialize(ref calldata);
        self.initial_supply.serialize(ref calldata);
        self.l1_reward_supplier.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        let minting_curve_contract = snforge_std::declare("MintingCurve").unwrap().contract_class();
        let (minting_curve_contract_address, _) = minting_curve_contract.deploy(@calldata).unwrap();
        let minting_curve = MintingCurveState {
            address: minting_curve_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        minting_curve.set_roles();
        minting_curve
    }

    fn deploy_mainnet_contract_v0(
        self: MintingCurveConfig, staking: StakingState,
    ) -> MintingCurveState {
        let mut calldata = ArrayTrait::new();
        staking.address.serialize(ref calldata);
        self.initial_supply.serialize(ref calldata);
        self.l1_reward_supplier.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        let contract_address_salt: felt252 = Time::now().seconds.into();
        let (minting_curve_contract_address, _) = deploy_syscall(
            class_hash: MAINNET_MINTING_CURVE_CLASS_HASH_V0(),
            :contract_address_salt,
            calldata: calldata.span(),
            deploy_from_zero: false,
        )
            .unwrap_syscall();
        let minting_curve = MintingCurveState {
            address: minting_curve_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        minting_curve.set_roles();
        minting_curve
    }

    fn dispatcher(self: MintingCurveState) -> IMintingCurveDispatcher nopanic {
        IMintingCurveDispatcher { contract_address: self.address }
    }

    fn config_dispatcher(self: MintingCurveState) -> IMintingCurveConfigDispatcher nopanic {
        IMintingCurveConfigDispatcher { contract_address: self.address }
    }

    fn set_roles(self: MintingCurveState) {
        set_account_as_upgrade_governor(
            contract: self.address,
            account: self.roles.upgrade_governor,
            governance_admin: self.governance_admin,
        );
        set_account_as_app_role_admin(
            contract: self.address,
            account: self.roles.app_role_admin,
            governance_admin: self.governance_admin,
        );
        set_account_as_token_admin(
            contract: self.address,
            account: self.roles.token_admin,
            app_role_admin: self.roles.app_role_admin,
        );
    }

    fn set_c_num(self: MintingCurveState, c_num: Inflation) {
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.roles.token_admin,
        );
        self.config_dispatcher().set_c_num(:c_num);
    }
}

/// The `RewardSupplierRoles` struct represents the various roles involved in the reward supplier
/// contract.
/// It includes the address for the upgrade governor role.
#[derive(Drop, Copy)]
pub struct RewardSupplierRoles {
    pub upgrade_governor: ContractAddress,
}

/// The `RewardSupplierConfig` struct represents the configuration settings for the reward supplier
/// contract.
/// It includes various parameters and roles required for the reward supplier contract's operation.
///
/// # Fields
/// - `base_mint_amount` (Amount): The base amount of tokens to be minted.
/// - `l1_reward_supplier` (felt252).
/// - `starkgate_address` (ContractAddress): The address of the StarkGate contract.
/// - `governance_admin` (ContractAddress): The address of the governance administrator.
/// - `roles` (RewardSupplierRoles): The roles involved in the reward supplier contract.
#[derive(Drop, Copy)]
pub struct RewardSupplierConfig {
    pub base_mint_amount: Amount,
    pub l1_reward_supplier: felt252,
    pub starkgate_address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: RewardSupplierRoles,
}

/// The `RewardSupplierState` struct represents the state of the reward supplier contract.
/// It includes the contract address, governance administrator, and roles.
#[derive(Drop, Copy)]
pub struct RewardSupplierState {
    pub address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: RewardSupplierRoles,
}

#[generate_trait]
pub impl RewardSupplierImpl of RewardSupplierTrait {
    fn deploy(
        self: RewardSupplierConfig,
        minting_curve: MintingCurveState,
        staking: StakingState,
        token: Token,
    ) -> RewardSupplierState {
        let mut calldata = ArrayTrait::new();
        self.base_mint_amount.serialize(ref calldata);
        minting_curve.address.serialize(ref calldata);
        staking.address.serialize(ref calldata);
        self.l1_reward_supplier.serialize(ref calldata);
        self.starkgate_address.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        let reward_supplier_contract = snforge_std::declare("RewardSupplier")
            .unwrap()
            .contract_class();
        let (reward_supplier_contract_address, _) = reward_supplier_contract
            .deploy(@calldata)
            .unwrap();
        let reward_supplier = RewardSupplierState {
            address: reward_supplier_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        reward_supplier.set_roles();
        reward_supplier
    }

    fn deploy_mainnet_contract_v0(
        self: RewardSupplierConfig,
        minting_curve: MintingCurveState,
        staking: StakingState,
        token_address: ContractAddress,
    ) -> RewardSupplierState {
        let mut calldata = ArrayTrait::new();
        self.base_mint_amount.serialize(ref calldata);
        minting_curve.address.serialize(ref calldata);
        staking.address.serialize(ref calldata);
        token_address.serialize(ref calldata);
        self.l1_reward_supplier.serialize(ref calldata);
        self.starkgate_address.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        let contract_address_salt: felt252 = Time::now().seconds.into();
        let (reward_supplier_contract_address, _) = deploy_syscall(
            class_hash: MAINNET_REWARD_SUPPLIER_CLASS_HASH_V0(),
            :contract_address_salt,
            calldata: calldata.span(),
            deploy_from_zero: false,
        )
            .unwrap_syscall();
        let reward_supplier = RewardSupplierState {
            address: reward_supplier_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        reward_supplier.set_roles();
        reward_supplier
    }

    fn dispatcher(self: RewardSupplierState) -> IRewardSupplierDispatcher nopanic {
        IRewardSupplierDispatcher { contract_address: self.address }
    }

    fn set_roles(self: RewardSupplierState) {
        set_account_as_upgrade_governor(
            contract: self.address,
            account: self.roles.upgrade_governor,
            governance_admin: self.governance_admin,
        );
    }

    fn get_unclaimed_rewards(self: RewardSupplierState) -> Amount {
        self.dispatcher().contract_parameters_v1().try_into().unwrap().unclaimed_rewards
    }

    fn calculate_current_epoch_rewards(self: RewardSupplierState) -> (Amount, Amount) {
        self.dispatcher().calculate_current_epoch_rewards()
    }
}

/// The `PoolRoles` struct represents the various roles involved in the pool contract.
/// It includes the address for the upgrade governor role.
#[derive(Drop, Copy)]
pub struct PoolRoles {
    pub upgrade_governor: ContractAddress,
}

/// The `PoolState` struct represents the state of the pool contract.
/// It includes the contract address and roles.
#[derive(Drop, Copy)]
pub struct PoolState {
    pub address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: PoolRoles,
}

#[derive(Drop, Copy)]
pub struct AttestationRoles {
    pub upgrade_governor: ContractAddress,
    pub app_governor: ContractAddress,
}

#[derive(Drop, Copy)]
struct AttestationConfig {
    pub governance_admin: ContractAddress,
    pub attestation_window: u16,
    pub roles: AttestationRoles,
}

#[derive(Drop, Copy)]
struct AttestationState {
    pub address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: AttestationRoles,
}

#[generate_trait]
pub impl AttestationImpl of AttestationTrait {
    fn deploy(self: AttestationConfig, staking: StakingState) -> AttestationState {
        let mut calldata = ArrayTrait::new();
        staking.address.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        self.attestation_window.serialize(ref calldata);
        let attestation_contract = snforge_std::declare("Attestation").unwrap().contract_class();
        let (attestation_contract_address, _) = attestation_contract.deploy(@calldata).unwrap();
        let attestation = AttestationState {
            address: attestation_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        attestation.set_roles();
        attestation
    }

    fn deploy_mainnet_contract_v1(
        self: AttestationConfig, staking: StakingState,
    ) -> AttestationState {
        let mut calldata = ArrayTrait::new();
        staking.address.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        self.attestation_window.serialize(ref calldata);
        let contract_address_salt: felt252 = Time::now().seconds.into();
        let (attestation_contract_address, _) = deploy_syscall(
            class_hash: MAINNET_ATTESTATION_CLASS_HASH_V1(),
            :contract_address_salt,
            calldata: calldata.span(),
            deploy_from_zero: false,
        )
            .unwrap_syscall();
        let attestation = AttestationState {
            address: attestation_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        attestation.set_roles();
        attestation
    }


    fn dispatcher(self: AttestationState) -> IAttestationDispatcher nopanic {
        IAttestationDispatcher { contract_address: self.address }
    }

    fn safe_dispatcher(self: AttestationState) -> IAttestationSafeDispatcher nopanic {
        IAttestationSafeDispatcher { contract_address: self.address }
    }

    fn set_roles(self: AttestationState) {
        set_account_as_upgrade_governor(
            contract: self.address,
            account: self.roles.upgrade_governor,
            governance_admin: self.governance_admin,
        );
        set_account_as_app_role_admin(
            contract: self.address,
            account: self.governance_admin,
            governance_admin: self.governance_admin,
        );
        set_account_as_app_governor(
            contract: self.address,
            account: self.roles.app_governor,
            app_role_admin: self.governance_admin,
        );
        // Remove governance admin from app role admin.
        let roles_dispatcher = IRolesDispatcher { contract_address: self.address };
        cheat_caller_address_once(
            contract_address: self.address, caller_address: self.governance_admin,
        );
        roles_dispatcher.remove_app_role_admin(account: self.governance_admin);
    }

    fn get_current_epoch_target_attestation_block(
        self: AttestationState, operational_address: ContractAddress,
    ) -> u64 {
        self.dispatcher().get_current_epoch_target_attestation_block(:operational_address)
    }
}

/// The `SystemConfig` struct represents the configuration settings for the entire system.
/// It includes configurations for the token, staking, minting curve, and reward supplier contracts.
#[derive(Drop)]
struct SystemConfig {
    btc_token: TokenConfig,
    staking: StakingConfig,
    minting_curve: MintingCurveConfig,
    reward_supplier: RewardSupplierConfig,
    attestation: AttestationConfig,
}

/// The `SystemState` struct represents the state of the entire system.
/// It includes the state for the token, staking, minting curve, and reward supplier contracts,
/// as well as a base account identifier.
#[derive(Drop, Copy)]
pub struct SystemState {
    pub token: Token,
    pub btc_token: Token,
    pub staking: StakingState,
    pub minting_curve: MintingCurveState,
    pub reward_supplier: RewardSupplierState,
    pub pool: Option<PoolState>,
    pub attestation: Option<AttestationState>,
    pub base_account: felt252,
    pub staker_address: Option<ContractAddress>,
}

#[generate_trait]
pub impl SystemConfigImpl of SystemConfigTrait {
    // TODO: new cfg - split to basic cfg and specific flow cfg.
    /// Configures the basic staking flow by initializing the system configuration with the
    /// provided staking initialization configuration.
    fn basic_stake_flow_cfg(cfg: StakingInitConfig) -> SystemConfig {
        let btc_token = TokenConfig {
            name: BTC_TOKEN_NAME(),
            symbol: SYMBOL(),
            initial_supply: cfg.test_info.initial_supply,
            owner: cfg.test_info.owner_address,
        };
        let staking = StakingConfig {
            min_stake: cfg.staking_contract_info.min_stake,
            pool_contract_class_hash: cfg.staking_contract_info.pool_contract_class_hash,
            reward_supplier: cfg.staking_contract_info.reward_supplier,
            pool_contract_admin: cfg.test_info.pool_contract_admin,
            governance_admin: cfg.test_info.governance_admin,
            prev_staking_contract_class_hash: cfg
                .staking_contract_info
                .prev_staking_contract_class_hash,
            epoch_info: cfg.staking_contract_info.epoch_info,
            attestation_contract: cfg.test_info.attestation_contract,
            roles: StakingRoles {
                upgrade_governor: cfg.test_info.upgrade_governor,
                security_admin: cfg.test_info.security_admin,
                security_agent: cfg.test_info.security_agent,
                app_role_admin: cfg.test_info.app_role_admin,
                token_admin: cfg.test_info.token_admin,
                app_governor: cfg.test_info.app_governor,
            },
        };
        let minting_curve = MintingCurveConfig {
            initial_supply: cfg.test_info.initial_supply.try_into().unwrap(),
            governance_admin: cfg.test_info.governance_admin,
            l1_reward_supplier: cfg.reward_supplier.l1_reward_supplier,
            roles: MintingCurveRoles {
                upgrade_governor: cfg.test_info.upgrade_governor,
                app_role_admin: cfg.test_info.app_role_admin,
                token_admin: cfg.test_info.token_admin,
            },
        };
        let reward_supplier = RewardSupplierConfig {
            base_mint_amount: cfg.reward_supplier.base_mint_amount,
            l1_reward_supplier: cfg.reward_supplier.l1_reward_supplier,
            starkgate_address: cfg.reward_supplier.starkgate_address,
            governance_admin: cfg.test_info.governance_admin,
            roles: RewardSupplierRoles { upgrade_governor: cfg.test_info.upgrade_governor },
        };
        let attestation = AttestationConfig {
            governance_admin: cfg.test_info.governance_admin,
            attestation_window: cfg.test_info.attestation_window,
            roles: AttestationRoles {
                upgrade_governor: cfg.test_info.upgrade_governor,
                app_governor: cfg.test_info.app_governor,
            },
        };
        SystemConfig { btc_token, staking, minting_curve, reward_supplier, attestation }
    }

    /// Deploys a BTC token with the given configuration and 8 decimals and returns the token state.
    fn deploy_btc_token(self: TokenConfig, decimals: u8) -> Token {
        let btc_token_address = deploy_mock_erc20_decimals_contract(
            initial_supply: self.initial_supply,
            owner_address: self.owner,
            name: self.name,
            :decimals,
        );
        custom_decimals_token(token_address: btc_token_address)
    }

    /// Deploys the system configuration and returns the system state.
    fn deploy(self: SystemConfig) -> SystemState {
        let token = Token::STRK;
        let btc_token = self.btc_token.deploy_btc_token(decimals: TEST_BTC_DECIMALS);
        let staking = self.staking.deploy();
        let minting_curve = self.minting_curve.deploy(:staking);
        let reward_supplier = self.reward_supplier.deploy(:minting_curve, :staking, :token);
        let attestation = self.attestation.deploy(:staking);
        snforge_std::store(
            target: staking.address,
            storage_address: selector!("attestation_contract"),
            serialized_value: array![attestation.address.into()].span(),
        );
        // Fund reward supplier
        fund(
            target: reward_supplier.address,
            amount: (self.minting_curve.initial_supply / 10).into(),
            :token,
        );
        // Set reward_supplier in staking
        let contract_address = staking.address;
        let staking_config_dispatcher = IStakingConfigDispatcher { contract_address };
        cheat_caller_address_once(:contract_address, caller_address: staking.roles.token_admin);
        staking_config_dispatcher.set_reward_supplier(reward_supplier: reward_supplier.address);
        let system_state = SystemState {
            token,
            btc_token,
            staking,
            minting_curve,
            reward_supplier,
            pool: Option::None,
            attestation: Option::Some(attestation),
            base_account: 0x100000,
            staker_address: Option::None,
        };
        system_state.advance_epoch();
        // Add BTC token to the staking contract.
        cheat_caller_address(
            contract_address: staking.address,
            caller_address: self.staking.roles.token_admin,
            span: CheatSpan::TargetCalls(2),
        );
        staking.token_manager_dispatcher().add_token(token_address: btc_token.contract_address());
        staking
            .token_manager_dispatcher()
            .enable_token(token_address: btc_token.contract_address());
        system_state
    }

    /// Deploys the system configuration with the implementation of the deployed contracts
    /// on Starknet mainnet. Returns the system state.
    fn deploy_mainnet_contracts_v0(self: SystemConfig) -> SystemState {
        let token = Token::STRK;
        let token_address = token.contract_address();
        // TODO: Change this once we have the BTC token address?
        let btc_token = self.btc_token.deploy_btc_token(decimals: TEST_BTC_DECIMALS);
        let staking = self.staking.deploy_mainnet_contract_v0(:token_address);
        let minting_curve = self.minting_curve.deploy_mainnet_contract_v0(:staking);
        let reward_supplier = self
            .reward_supplier
            .deploy_mainnet_contract_v0(:minting_curve, :staking, :token_address);
        // Fund reward supplier
        fund(
            target: reward_supplier.address,
            amount: (self.minting_curve.initial_supply / 10).into(),
            :token,
        );
        // Set reward_supplier in staking
        let staking_config_dispatcher = IStakingConfigDispatcher {
            contract_address: staking.address,
        };
        cheat_caller_address_once(
            contract_address: staking.address, caller_address: staking.roles.token_admin,
        );
        staking_config_dispatcher.set_reward_supplier(reward_supplier: reward_supplier.address);
        advance_block_number_global(blocks: EPOCH_STARTING_BLOCK);
        SystemState {
            token,
            btc_token,
            staking,
            minting_curve,
            reward_supplier,
            pool: Option::None,
            attestation: Option::None,
            base_account: 0x100000,
            staker_address: Option::None,
        }
    }
}

#[generate_trait]
pub impl SystemImpl of SystemTrait {
    /// Creates a new account with the specified amount.
    fn new_account(ref self: SystemState, amount: Amount) -> Account {
        self.base_account += 1;
        let account = AccountTrait::new(address: self.base_account, :amount);
        fund(target: account.address, :amount, token: self.token);
        account
    }

    fn new_btc_account(ref self: SystemState, amount: Amount, token: Token) -> Account {
        self.base_account += 1;
        let account = AccountTrait::new(address: self.base_account, :amount);
        fund(target: account.address, :amount, :token);
        account
    }

    /// Creates a new staker with the specified amount.
    fn new_staker(ref self: SystemState, amount: Amount) -> Staker {
        let staker = self.new_account(:amount);
        let reward = self.new_account(amount: Zero::zero());
        let operational = self.new_account(amount: Zero::zero());
        StakerTrait::new(:staker, :reward, :operational)
    }

    /// Creates a new delegator with the specified amount.
    fn new_delegator(ref self: SystemState, amount: Amount) -> Delegator {
        let delegator = self.new_account(:amount);
        let reward = self.new_account(amount: Zero::zero());
        DelegatorTrait::new(:delegator, :reward)
    }

    fn new_btc_delegator(ref self: SystemState, amount: Amount, token: Token) -> Delegator {
        let delegator = self.new_btc_account(:amount, :token);
        let reward = self.new_account(amount: Zero::zero());
        DelegatorTrait::new(:delegator, :reward)
    }

    /// Advances the block timestamp by the specified amount of time.
    fn advance_time(ref self: SystemState, time: TimeDelta) {
        start_cheat_block_timestamp_global(block_timestamp: Time::now().add(delta: time).into())
    }

    /// Advances the block number to the next epoch starting block.
    fn advance_epoch(self: SystemState) {
        let current_block = get_block_number();
        if current_block < EPOCH_STARTING_BLOCK {
            advance_block_number_global(blocks: EPOCH_STARTING_BLOCK - current_block);
        } else {
            let epoch_info = self.staking.get_epoch_info();
            /// Note: This calculation of the next epoch's starting block may be incorrect
            /// if executed within the same epoch in which the epoch length is updated.
            let next_epoch_starting_block = epoch_info.current_epoch_starting_block()
                + epoch_info.epoch_len_in_blocks().into();
            advance_block_number_global(blocks: next_epoch_starting_block - current_block);
        }
    }

    /// Advances the block timestamp by the exit wait window and advance epoch.
    ///
    /// Note: This function is built on the assumption that exit window > k epochs
    fn advance_exit_wait_window(ref self: SystemState) {
        self.advance_time(time: self.staking.get_exit_wait_window());
        if !self.staking.is_v0() {
            self.advance_epoch();
        }
    }

    fn set_pool_for_upgrade(ref self: SystemState, pool_address: ContractAddress) {
        let pool_contract_admin = self.staking.get_pool_contract_admin();
        let upgrade_governor = UPGRADE_GOVERNOR();
        set_account_as_upgrade_governor(
            contract: pool_address,
            account: upgrade_governor,
            governance_admin: pool_contract_admin,
        );
        self
            .pool =
                Option::Some(
                    PoolState {
                        address: pool_address,
                        governance_admin: pool_contract_admin,
                        roles: PoolRoles { upgrade_governor },
                    },
                );
    }

    fn set_staker_for_migration(ref self: SystemState, staker_address: ContractAddress) {
        self.staker_address = Option::Some(staker_address);
    }

    /// Advances the required block number into the attestation window.
    fn advance_block_into_attestation_window(self: SystemState, staker: Staker) {
        let staker_address = staker.staker.address;
        let stake = self.staker_total_amount(:staker);
        self.advance_block_into_attestation_window_custom_stake(:staker_address, :stake);
    }

    fn advance_block_into_attestation_window_custom_stake(
        self: SystemState, staker_address: ContractAddress, stake: Amount,
    ) {
        let block_offset_from_epoch_start = calculate_block_offset(
            :stake,
            epoch_id: self.staking.get_epoch_info().current_epoch().into(),
            staker_address: staker_address.into(),
            epoch_len: self.staking.get_epoch_info().epoch_len_in_blocks().into(),
            attestation_window: MIN_ATTESTATION_WINDOW,
        );
        let current_block = get_block_number();
        let epoch_start_block = self.staking.get_epoch_info().current_epoch_starting_block();
        let block_offset = block_offset_from_epoch_start - (current_block - epoch_start_block);
        advance_block_number_global(blocks: block_offset + MIN_ATTESTATION_WINDOW.into());
    }

    fn deploy_second_btc_token(self: SystemState) -> Token {
        self.deploy_new_btc_token(name: BTC_TOKEN_NAME_2(), decimals: BTC_18D_CONFIG.decimals)
    }

    fn deploy_new_btc_token(self: SystemState, name: ByteArray, decimals: u8) -> Token {
        let btc_token = TokenConfig {
            name, symbol: SYMBOL(), initial_supply: INITIAL_SUPPLY.into(), owner: OWNER_ADDRESS(),
        }
            .deploy_btc_token(:decimals);
        btc_token
    }
}

#[generate_trait]
impl InternalSystemImpl of InternalSystemTrait {
    fn cheat_target_attestation_block_hash(self: SystemState, staker: Staker, block_hash: felt252) {
        let target_attestation_block = self
            .attestation
            .unwrap()
            .get_current_epoch_target_attestation_block(
                operational_address: staker.operational.address,
            );
        start_cheat_block_hash_global(block_number: target_attestation_block, :block_hash);
    }
}

/// The `Account` struct represents an account in the staking system.
/// It includes the account's address, amount of tokens, token state, and staking state.
#[derive(Drop, Copy)]
pub struct Account {
    pub address: ContractAddress,
    pub amount: Amount,
}

#[generate_trait]
pub impl AccountImpl of AccountTrait {
    fn new(address: felt252, amount: Amount) -> Account {
        Account { address: address.try_into().unwrap(), amount }
    }
}

/// The `Staker` struct represents a staker in the staking system.
/// It includes the staker's account, reward account, and operational account.
#[derive(Drop, Copy)]
pub struct Staker {
    pub staker: Account,
    pub reward: Account,
    pub operational: Account,
}

#[generate_trait]
impl StakerImpl of StakerTrait {
    fn new(staker: Account, reward: Account, operational: Account) -> Staker nopanic {
        Staker { staker, reward, operational }
    }
}

#[generate_trait]
pub impl SystemStakerImpl of SystemStakerTrait {
    fn stake(
        self: SystemState,
        staker: Staker,
        amount: Amount,
        pool_enabled: bool,
        commission: Commission,
    ) {
        self.token.approve(owner: staker.staker.address, spender: self.staking.address, :amount);
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        if self.staking.is_v0() || self.staking.is_v1() {
            self
                .staking
                .dispatcher_v0_for_tests()
                .stake(
                    reward_address: staker.reward.address,
                    operational_address: staker.operational.address,
                    :amount,
                    :pool_enabled,
                    :commission,
                );
        } else {
            self
                .staking
                .dispatcher()
                .stake(
                    reward_address: staker.reward.address,
                    operational_address: staker.operational.address,
                    :amount,
                );
            if pool_enabled {
                self.set_open_for_strk_delegation(:staker, :commission);
            }
        }
    }

    #[feature("safe_dispatcher")]
    fn safe_stake(self: SystemState, staker: Staker, amount: Amount) -> Result<(), Array<felt252>> {
        self.token.approve(owner: staker.staker.address, spender: self.staking.address, :amount);
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self
            .staking
            .safe_dispatcher()
            .stake(
                reward_address: staker.reward.address,
                operational_address: staker.operational.address,
                :amount,
            )
    }

    fn increase_stake(self: SystemState, staker: Staker, amount: Amount) -> Amount {
        self.token.approve(owner: staker.staker.address, spender: self.staking.address, :amount);
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().increase_stake(staker_address: staker.staker.address, :amount)
    }

    fn staker_exit_intent(self: SystemState, staker: Staker) -> Timestamp {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().unstake_intent()
    }

    fn staker_exit_action(self: SystemState, staker: Staker) -> Amount {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().unstake_action(staker_address: staker.staker.address)
    }

    #[feature("safe_dispatcher")]
    fn safe_staker_exit_action(
        self: SystemState, staker: Staker,
    ) -> Result<Amount, Array<felt252>> {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.safe_dispatcher().unstake_action(staker_address: staker.staker.address)
    }

    fn set_open_for_strk_delegation(
        self: SystemState, staker: Staker, commission: Commission,
    ) -> ContractAddress {
        if self.staking.is_v0() || self.staking.is_v1() {
            cheat_caller_address_once(
                contract_address: self.staking.address, caller_address: staker.staker.address,
            );
            self.staking.dispatcher_v0_for_tests().set_open_for_delegation(:commission)
        } else {
            self.set_commission(:staker, :commission);
            let token_address = self.staking.dispatcher().contract_parameters_v1().token_address;
            self.set_open_for_delegation(:staker, :token_address)
        }
    }

    fn set_open_for_delegation(
        self: SystemState, staker: Staker, token_address: ContractAddress,
    ) -> ContractAddress {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().set_open_for_delegation(:token_address)
    }

    #[feature("safe_dispatcher")]
    fn safe_set_open_for_delegation(
        self: SystemState, staker: Staker, token_address: ContractAddress,
    ) -> Result<ContractAddress, Array<felt252>> {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.safe_dispatcher().set_open_for_delegation(:token_address)
    }

    fn staker_claim_rewards(self: SystemState, staker: Staker) -> Amount {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().claim_rewards(staker_address: staker.staker.address)
    }

    fn set_commission(self: SystemState, staker: Staker, commission: Commission) {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        if self.staking.is_v0() || self.staking.is_v1() {
            self.staking.dispatcher_v0_for_tests().update_commission(:commission)
        } else {
            self.staking.dispatcher().set_commission(:commission)
        }
    }

    fn set_commission_commitment(
        self: SystemState, staker: Staker, max_commission: Commission, expiration_epoch: Epoch,
    ) {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().set_commission_commitment(:max_commission, :expiration_epoch)
    }

    fn staker_info_v1(self: SystemState, staker: Staker) -> StakerInfoV1 {
        self.staking.dispatcher().staker_info_v1(staker_address: staker.staker.address)
    }

    fn staker_info(self: SystemState, staker: Staker) -> StakerInfo {
        self.staking.dispatcher_v0_for_tests().staker_info(staker_address: staker.staker.address)
    }

    fn staker_pool_info(self: SystemState, staker: Staker) -> StakerPoolInfoV2 {
        self.staking.dispatcher().staker_pool_info(staker_address: staker.staker.address)
    }

    fn get_staker_info(self: SystemState, staker: Staker) -> Option<StakerInfoV1> {
        self.staking.dispatcher().get_staker_info_v1(staker_address: staker.staker.address)
    }

    fn get_staker_commission_commitment(self: SystemState, staker: Staker) -> CommissionCommitment {
        self
            .staking
            .dispatcher()
            .get_staker_commission_commitment(staker_address: staker.staker.address)
    }

    #[feature("safe_dispatcher")]
    fn safe_get_staker_commission_commitment(
        self: SystemState, staker: Staker,
    ) -> Result<CommissionCommitment, Array<felt252>> {
        self
            .staking
            .safe_dispatcher()
            .get_staker_commission_commitment(staker_address: staker.staker.address)
    }

    fn internal_staker_info(self: SystemState, staker: Staker) -> InternalStakerInfoLatest {
        self
            .staking
            .migration_dispatcher()
            .internal_staker_info(staker_address: staker.staker.address)
    }

    fn staker_migration(self: SystemState, staker_address: ContractAddress) {
        self.staking.migration_dispatcher().staker_migration(:staker_address)
    }

    fn attest(self: SystemState, staker: Staker) {
        let block_hash = Zero::zero();
        self.cheat_target_attestation_block_hash(:staker, :block_hash);
        cheat_caller_address_once(
            contract_address: self.attestation.unwrap().address,
            caller_address: staker.operational.address,
        );
        self.attestation.unwrap().dispatcher().attest(:block_hash);
    }

    #[feature("safe_dispatcher")]
    fn safe_attest(self: SystemState, staker: Staker) -> Result<(), Array<felt252>> {
        let block_hash = Zero::zero();
        self.cheat_target_attestation_block_hash(:staker, :block_hash);
        cheat_caller_address_once(
            contract_address: self.attestation.unwrap().address,
            caller_address: staker.operational.address,
        );
        self.attestation.unwrap().safe_dispatcher().attest(:block_hash)
    }

    fn advance_epoch_and_attest(self: SystemState, staker: Staker) {
        self.advance_epoch();
        self.advance_block_into_attestation_window(:staker);
        self.attest(:staker);
    }

    fn staker_total_amount(self: SystemState, staker: Staker) -> Amount {
        let staker_info = self.staker_info_v1(:staker);
        let mut total = staker_info.amount_own;
        if let Option::Some(pool_info) = staker_info.pool_info {
            total += pool_info.amount;
        }
        total
    }

    fn change_reward_address(self: SystemState, staker: Staker, reward_address: ContractAddress) {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().change_reward_address(:reward_address)
    }
}

/// The `Delegator` struct represents a delegator in the staking system.
/// It includes the delegator's account and reward account.
#[derive(Drop, Copy)]
pub struct Delegator {
    pub delegator: Account,
    pub reward: Account,
}

#[generate_trait]
impl DelegatorImpl of DelegatorTrait {
    fn new(delegator: Account, reward: Account) -> Delegator nopanic {
        Delegator { delegator, reward }
    }
}

#[generate_trait]
pub impl SystemDelegatorImpl of SystemDelegatorTrait {
    fn delegate(self: SystemState, delegator: Delegator, pool: ContractAddress, amount: Amount) {
        self.token.approve(owner: delegator.delegator.address, spender: pool, :amount);
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        if self.staking.is_v0() {
            let pool_dispatcher = IPoolV0Dispatcher { contract_address: pool };
            pool_dispatcher.enter_delegation_pool(reward_address: delegator.reward.address, :amount)
        } else {
            let pool_dispatcher = IPoolDispatcher { contract_address: pool };
            pool_dispatcher.enter_delegation_pool(reward_address: delegator.reward.address, :amount)
        }
    }

    fn delegate_btc(
        self: SystemState,
        delegator: Delegator,
        pool: ContractAddress,
        amount: Amount,
        token: Token,
    ) {
        token.approve(owner: delegator.delegator.address, spender: pool, :amount);
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.enter_delegation_pool(reward_address: delegator.reward.address, :amount)
    }

    fn increase_delegate(
        self: SystemState, delegator: Delegator, pool: ContractAddress, amount: Amount,
    ) -> Amount {
        self.token.approve(owner: delegator.delegator.address, spender: pool, :amount);
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.add_to_delegation_pool(pool_member: delegator.delegator.address, :amount)
    }

    fn increase_delegate_btc(
        self: SystemState,
        delegator: Delegator,
        pool: ContractAddress,
        amount: Amount,
        token: Token,
    ) -> Amount {
        token.approve(owner: delegator.delegator.address, spender: pool, :amount);
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.add_to_delegation_pool(pool_member: delegator.delegator.address, :amount)
    }

    fn delegator_exit_intent(
        self: SystemState, delegator: Delegator, pool: ContractAddress, amount: Amount,
    ) {
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        if self.staking.is_v0() {
            let pool_dispatcher = IPoolV0Dispatcher { contract_address: pool };
            pool_dispatcher.exit_delegation_pool_intent(:amount)
        } else {
            let pool_dispatcher = IPoolDispatcher { contract_address: pool };
            pool_dispatcher.exit_delegation_pool_intent(:amount)
        }
    }

    #[feature("safe_dispatcher")]
    fn safe_delegator_exit_intent(
        self: SystemState, delegator: Delegator, pool: ContractAddress, amount: Amount,
    ) -> Result<(), Array<felt252>> {
        let safe_pool_dispatcher = IPoolSafeDispatcher { contract_address: pool };
        safe_pool_dispatcher.exit_delegation_pool_intent(:amount)
    }

    fn delegator_exit_action(
        self: SystemState, delegator: Delegator, pool: ContractAddress,
    ) -> Amount {
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.exit_delegation_pool_action(pool_member: delegator.delegator.address)
    }

    #[feature("safe_dispatcher")]
    fn safe_delegator_exit_action(
        self: SystemState, delegator: Delegator, pool: ContractAddress,
    ) -> Result<Amount, Array<felt252>> {
        let safe_pool_dispatcher = IPoolSafeDispatcher { contract_address: pool };
        safe_pool_dispatcher.exit_delegation_pool_action(pool_member: delegator.delegator.address)
    }

    fn switch_delegation_pool(
        self: SystemState,
        delegator: Delegator,
        from_pool: ContractAddress,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        amount: Amount,
    ) -> Amount {
        cheat_caller_address_once(
            contract_address: from_pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: from_pool };
        pool_dispatcher.switch_delegation_pool(:to_staker, :to_pool, :amount)
    }

    #[feature("safe_dispatcher")]
    fn safe_switch_delegation_pool(
        self: SystemState,
        delegator: Delegator,
        from_pool: ContractAddress,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        amount: Amount,
    ) -> Result<Amount, Array<felt252>> {
        let safe_pool_dispatcher = IPoolSafeDispatcher { contract_address: from_pool };
        safe_pool_dispatcher.switch_delegation_pool(:to_staker, :to_pool, :amount)
    }

    fn delegator_claim_rewards(
        self: SystemState, delegator: Delegator, pool: ContractAddress,
    ) -> Amount {
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.claim_rewards(pool_member: delegator.delegator.address)
    }

    fn delegator_change_reward_address(
        self: SystemState,
        delegator: Delegator,
        pool: ContractAddress,
        reward_address: ContractAddress,
    ) {
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.change_reward_address(:reward_address)
    }

    fn add_to_delegation_pool(
        self: SystemState, delegator: Delegator, pool: ContractAddress, amount: Amount,
    ) -> Amount {
        self.token.approve(owner: delegator.delegator.address, spender: pool, :amount);
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.add_to_delegation_pool(pool_member: delegator.delegator.address, :amount)
    }

    fn pool_member_info(
        self: SystemState, delegator: Delegator, pool: ContractAddress,
    ) -> PoolMemberInfo {
        let pool_dispatcher = IPoolV0Dispatcher { contract_address: pool };
        pool_dispatcher.pool_member_info(pool_member: delegator.delegator.address)
    }

    fn get_pool_member_info(
        self: SystemState, delegator: Delegator, pool: ContractAddress,
    ) -> Option<PoolMemberInfo> {
        let pool_dispatcher = IPoolV0Dispatcher { contract_address: pool };
        pool_dispatcher.get_pool_member_info(pool_member: delegator.delegator.address)
    }

    fn pool_member_info_v1(
        self: SystemState, delegator: Delegator, pool: ContractAddress,
    ) -> PoolMemberInfoV1 {
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.pool_member_info_v1(pool_member: delegator.delegator.address)
    }

    fn internal_pool_member_info(
        self: SystemState, delegator: Delegator, pool: ContractAddress,
    ) -> InternalPoolMemberInfoLatest {
        let pool_migration_dispatcher = IPoolMigrationDispatcher { contract_address: pool };
        pool_migration_dispatcher
            .internal_pool_member_info(pool_member: delegator.delegator.address)
    }

    fn get_internal_pool_member_info(
        self: SystemState, delegator: Delegator, pool: ContractAddress,
    ) -> Option<InternalPoolMemberInfoLatest> {
        let pool_migration_dispatcher = IPoolMigrationDispatcher { contract_address: pool };
        pool_migration_dispatcher
            .get_internal_pool_member_info(pool_member: delegator.delegator.address)
    }
}

#[generate_trait]
pub impl SystemPoolImpl of SystemPoolTrait {
    fn contract_parameters_v1(self: SystemState, pool: ContractAddress) -> PoolContractInfoV1 {
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.contract_parameters_v1()
    }
}

// This interface is implemented by the `STRK` token contract.
#[starknet::interface]
trait IMintableToken<TContractState> {
    fn permissioned_mint(ref self: TContractState, account: ContractAddress, amount: u256);
    fn permissioned_burn(ref self: TContractState, account: ContractAddress, amount: u256);
}

#[generate_trait]
pub impl TokenHelperImpl of TokenHelperTrait {
    fn approve(self: @Token, owner: ContractAddress, spender: ContractAddress, amount: Amount) {
        approve(:owner, :spender, :amount, token_address: self.contract_address());
    }
    fn balance_of(self: @Token, account: ContractAddress) -> Amount {
        let token_dispatcher = IERC20Dispatcher { contract_address: self.contract_address() };
        token_dispatcher.balance_of(account).try_into().unwrap()
    }
}

#[generate_trait]
/// Replaceability utils for internal use of the system. Meant to be used before running a
/// regression test.
/// This trait is used for the upgrade from V0 to V1 implementation.
pub impl SystemReplaceabilityV1Impl of SystemReplaceabilityV1Trait {
    /// Deploy attestation contract and upgrades the contracts in the system state with V1
    /// implementations.
    fn deploy_attestation_and_upgrade_contracts_implementation_v1(ref self: SystemState) {
        self.deploy_attestation_v1();
        self.upgrade_contracts_implementation_v1();
    }

    /// Deploy attestation contract.
    fn deploy_attestation_v1(ref self: SystemState) {
        let cfg: StakingInitConfig = Default::default();
        let attestation_config = AttestationConfig {
            governance_admin: cfg.test_info.governance_admin,
            attestation_window: cfg.test_info.attestation_window,
            roles: AttestationRoles {
                upgrade_governor: cfg.test_info.upgrade_governor,
                app_governor: cfg.test_info.app_governor,
            },
        };
        let attestation_state = attestation_config
            .deploy_mainnet_contract_v1(staking: self.staking);
        self.attestation = Option::Some(attestation_state);
    }

    /// Upgrades the contracts in the system state with V1 implementations.
    fn upgrade_contracts_implementation_v1(self: SystemState) {
        self.staking.pause();
        self.upgrade_staking_implementation_v1();
        self.upgrade_reward_supplier_implementation_v1();
        if let Option::Some(pool) = self.pool {
            self.upgrade_pool_implementation_v1(:pool);
        }
        if let Option::Some(staker_address) = self.staker_address {
            self.staker_migration(staker_address);
        }
        self.staking.unpause();
    }

    /// Upgrades the staking contract in the system state with V1 implementation.
    fn upgrade_staking_implementation_v1(self: SystemState) {
        let eic_data = EICData {
            eic_hash: declare_staking_eic_contract_v0_v1(),
            eic_init_data: array![
                MAINNET_STAKING_CLASS_HASH_V0().into(), EPOCH_DURATION.into(), EPOCH_LENGTH.into(),
                STARTING_BLOCK_OFFSET.into(), MAINNET_POOL_CLASS_HASH_V1().into(),
                self.attestation.unwrap().address.into(), MAINNET_SECURITY_COUNSEL_ADDRESS().into(),
            ]
                .span(),
        };
        let implementation_data = ImplementationData {
            impl_hash: MAINNET_STAKING_CLASS_HASH_V1(),
            eic_data: Option::Some(eic_data),
            final: false,
        };
        upgrade_implementation(
            contract_address: self.staking.address,
            :implementation_data,
            upgrade_governor: self.staking.roles.upgrade_governor,
        );
    }

    /// Upgrades the reward supplier contract in the system state with V1 implementation.
    fn upgrade_reward_supplier_implementation_v1(self: SystemState) {
        let implementation_data = ImplementationData {
            impl_hash: MAINNET_REWARD_SUPPLIER_CLASS_HASH_V1(),
            eic_data: Option::None,
            final: false,
        };
        upgrade_implementation(
            contract_address: self.reward_supplier.address,
            :implementation_data,
            upgrade_governor: self.reward_supplier.roles.upgrade_governor,
        );
    }

    /// Upgrades the pool contract in the system state with V1 implementation.
    fn upgrade_pool_implementation_v1(self: SystemState, pool: PoolState) {
        let eic_data = EICData {
            eic_hash: declare_pool_eic_contract(),
            eic_init_data: array![MAINNET_POOL_CLASS_HASH_V0().into()].span(),
        };
        let implementation_data = ImplementationData {
            impl_hash: MAINNET_POOL_CLASS_HASH_V1(), eic_data: Option::Some(eic_data), final: false,
        };
        upgrade_implementation(
            contract_address: pool.address,
            :implementation_data,
            upgrade_governor: pool.roles.upgrade_governor,
        );
    }
}

#[generate_trait]
/// Replaceability utils for internal use of the system. Meant to be used before running a
/// regression test.
/// This trait is used for the upgrade from V1 to V2 implementation.
pub impl SystemReplaceabilityV2Impl of SystemReplaceabilityV2Trait {
    /// Upgrades the contracts in the system state with local
    /// implementations.
    fn upgrade_contracts_implementation_v2(self: SystemState) {
        self.staking.pause();
        self.upgrade_staking_implementation_v2();
        self.upgrade_reward_supplier_implementation_v2();
        if let Option::Some(staker_address) = self.staker_address {
            self.staker_migration(staker_address);
        }
        self.staking.unpause();
        // self.minting_curve.set_c_num(DEFAULT_C_NUM);
        // Add BTC token to the staking contract.
        cheat_caller_address(
            contract_address: self.staking.address,
            caller_address: self.staking.roles.token_admin,
            span: CheatSpan::TargetCalls(2),
        );
        self
            .staking
            .token_manager_dispatcher()
            .add_token(token_address: self.btc_token.contract_address());
        self
            .staking
            .token_manager_dispatcher()
            .enable_token(token_address: self.btc_token.contract_address());
    }

    /// Upgrades the staking contract in the system state with a local implementation.
    fn upgrade_staking_implementation_v2(self: SystemState) {
        let eic_data = EICData {
            eic_hash: declare_staking_eic_contract_v1_v2(),
            eic_init_data: array![
                MAINNET_STAKING_CLASS_HASH_V1().into(), declare_pool_contract().into(),
            ]
                .span(),
        };
        let implementation_data = ImplementationData {
            impl_hash: declare_staking_contract(), eic_data: Option::Some(eic_data), final: false,
        };
        upgrade_implementation(
            contract_address: self.staking.address,
            :implementation_data,
            upgrade_governor: self.staking.roles.upgrade_governor,
        );
    }

    /// Upgrades the reward supplier contract in the system state with a local implementation.
    fn upgrade_reward_supplier_implementation_v2(self: SystemState) {
        let implementation_data = ImplementationData {
            impl_hash: declare_reward_supplier_contract(), eic_data: Option::None, final: false,
        };
        // upgrade_implementation(
        //     contract_address: self.reward_supplier.address,
        //     :implementation_data,
        //     upgrade_governor: self.reward_supplier.roles.upgrade_governor,
        // );
    }
}

pub fn declare_staking_contract() -> ClassHash {
    *snforge_std::declare("Staking").unwrap().contract_class().class_hash
}

fn declare_reward_supplier_contract() -> ClassHash {
    *snforge_std::declare("RewardSupplier").unwrap().contract_class().class_hash
}

fn declare_minting_curve_contract() -> ClassHash {
    *snforge_std::declare("MintingCurve").unwrap().contract_class().class_hash
}

pub fn pause_staking_contract(
    staking_contract: ContractAddress, security_agent: ContractAddress,
) {
    cheat_caller_address_once(contract_address: staking_contract, caller_address: security_agent);
    let staking_pause_dispatcher = IStakingPauseDispatcher { contract_address: staking_contract };
    staking_pause_dispatcher.pause();
}

/// Upgrades implementation of the given contract.
pub fn upgrade_implementation(
    contract_address: ContractAddress,
    implementation_data: ImplementationData,
    upgrade_governor: ContractAddress,
) {
    let replaceability_dispatcher = IReplaceableDispatcher { contract_address };
    cheat_caller_address_once(:contract_address, caller_address: upgrade_governor);
    replaceability_dispatcher.add_new_implementation(:implementation_data);
    cheat_caller_address_once(:contract_address, caller_address: upgrade_governor);
    replaceability_dispatcher.replace_to(:implementation_data);
}

#[generate_trait]
/// System factory for creating system states used in flow and regression tests.
pub impl SystemFactoryImpl of SystemFactoryTrait {
    // System state used for flow tests.
    fn local_system() -> SystemState {
        let cfg: StakingInitConfig = Default::default();
        SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy()
    }

    // System state used for regression tests.
    fn mainnet_system() -> SystemState {
        let mut cfg: StakingInitConfig = Default::default();
        cfg.staking_contract_info.pool_contract_class_hash = MAINNET_POOL_CLASS_HASH_V0();
        SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy_mainnet_contracts_v0()
    }
}

pub trait FlowTrait<TFlow, +Drop<TFlow>> {
    fn get_pool_address(self: TFlow) -> Option<ContractAddress> {
        Option::None
    }
    fn get_staker_address(self: TFlow) -> Option<ContractAddress> {
        Option::None
    }
    fn setup(ref self: TFlow, ref system: SystemState) {}
    fn setup_v1(ref self: TFlow, ref system: SystemState) {}
    fn test(self: TFlow, ref system: SystemState);
}

pub fn test_flow_local<TFlow, +Drop<TFlow>, +Copy<TFlow>, +FlowTrait<TFlow>>(flow: TFlow) {
    let mut system = SystemFactoryTrait::local_system();
    flow.test(ref :system);
}

pub fn test_flow_mainnet<TFlow, +Drop<TFlow>, +Copy<TFlow>, +FlowTrait<TFlow>>(
    ref flow: TFlow,
) {
    let mut system = SystemFactoryTrait::mainnet_system();
    flow.setup(ref :system);
    if let Option::Some(pool_address) = flow.get_pool_address() {
        // Pool upgrade handles the migration of internal staker info.
        system.set_pool_for_upgrade(pool_address);
    } else if let Option::Some(staker_address) = flow.get_staker_address() {
        // Need to migrate internal staker info only if there is no pool to upgrade.
        system.set_staker_for_migration(staker_address);
    }
    system.deploy_attestation_and_upgrade_contracts_implementation_v1();
    flow.setup_v1(ref :system);
    if let Option::Some(staker_address) = flow.get_staker_address() {
        system.set_staker_for_migration(staker_address);
    }
    system.upgrade_contracts_implementation_v2();
    flow.test(ref :system);
}

#[test]
fn test_advance_epoch() {
    let mut system = SystemFactoryTrait::local_system();

    start_cheat_block_number_global(block_number: EPOCH_STARTING_BLOCK - 1);
    system.advance_epoch();
    assert!(get_block_number() == EPOCH_STARTING_BLOCK);

    system.advance_epoch();
    let epoch_len_in_blocks = system.staking.get_epoch_info().epoch_len_in_blocks();
    assert!(get_block_number() == EPOCH_STARTING_BLOCK + epoch_len_in_blocks.into());

    system.advance_epoch();
    assert!(get_block_number() == EPOCH_STARTING_BLOCK + (epoch_len_in_blocks * 2).into());
}
