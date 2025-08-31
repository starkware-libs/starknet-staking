use starknet::{ContractAddress, ClassHash};
use staking_test::types::{
    Amount, Commission, Index, InternalPoolMemberInfoLatest, InternalStakerInfoLatest,
    InternalStakerPoolInfoLatest,
};
use starkware_utils::time::time::{TimeDelta, Timestamp};
use staking_test::staking::objects::{EpochInfo, EpochInfoTrait, InternalStakerInfoLatestTestTrait};
use staking_test::minting_curve::interface::{
    IMintingCurveDispatcher, IMintingCurveDispatcherTrait, MintingCurveContractInfo,
};
use snforge_std::{
    CheatSpan, ContractClassTrait, CustomToken, DeclareResultTrait, Token, TokenImpl, TokenTrait,
    cheat_caller_address, set_balance, start_cheat_block_hash_global,
    start_cheat_block_number_global, test_address,
};
use core::num::traits::zero::Zero;

#[derive(Drop, Copy)]
pub struct TestInfo {
    // pub staker_address: ContractAddress,
    // pub pool_member_address: ContractAddress,
    // pub owner_address: ContractAddress,
    // pub governance_admin: ContractAddress,
    // pub initial_supply: u256,
    // pub staker_initial_balance: Amount,
    // pub pool_member_initial_balance: Amount,
    // pub pool_member_btc_amount: Amount,
    // pub strk_pool_enabled: bool,
    // pub stake_amount: Amount,
    // pub staking_contract: ContractAddress,
    // pub pool_contract_admin: ContractAddress,
    // pub security_admin: ContractAddress,
    // pub security_agent: ContractAddress,
    // pub token_admin: ContractAddress,
    // pub app_role_admin: ContractAddress,
    // pub upgrade_governor: ContractAddress,
    // pub attestation_contract: ContractAddress,
    // pub attestation_window: u16,
    pub app_governor: ContractAddress,
    pub global_index: Index,
    pub strk_token: Token,
    pub btc_token: Token,
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

#[derive(Drop, Copy)]
struct RewardSupplierInfoV1 {
    pub base_mint_amount: Amount,
    pub minting_curve_contract: ContractAddress,
    pub l1_reward_supplier: felt252,
    pub buffer: Amount,
    pub starkgate_address: ContractAddress,
}

#[derive(Drop, Copy)]
pub struct StakingInitConfig {
    pub staker_info: InternalStakerInfoLatest,
    pub pool_member_info: InternalPoolMemberInfoLatest,
    pub staking_contract_info: StakingContractInfoCfg,
    pub minting_curve_contract_info: MintingCurveContractInfo,
    pub test_info: TestInfo,
    pub reward_supplier: RewardSupplierInfoV1,
}

// impl StakingInitConfigDefault of Default<StakingInitConfig> {
//     fn default() -> StakingInitConfig {
//         let staker_info = InternalStakerInfoLatest {
//             reward_address: STAKER_REWARD_ADDRESS(),
//             operational_address: OPERATIONAL_ADDRESS(),
//             unstake_time: Option::None,
//             unclaimed_rewards_own: 0,
//             _deprecated_pool_info: Option::Some(
//                 InternalStakerPoolInfoLatest {
//                     _deprecated_pool_contract: POOL_CONTRACT_ADDRESS(),
//                     _deprecated_commission: COMMISSION,
//                 },
//             ),
//             _deprecated_commission_commitment: Option::None,
//         };
//         let pool_member_info = InternalPoolMemberInfoLatest {
//             reward_address: POOL_MEMBER_REWARD_ADDRESS(),
//             _deprecated_amount: POOL_MEMBER_STAKE_AMOUNT,
//             _deprecated_index: Zero::zero(),
//             _unclaimed_rewards_from_v0: Zero::zero(),
//             _deprecated_commission: COMMISSION,
//             unpool_time: Option::None,
//             unpool_amount: Zero::zero(),
//             entry_to_claim_from: Zero::zero(),
//             reward_checkpoint: PoolMemberCheckpointTrait::new(
//                 epoch: STARTING_EPOCH,
//                 balance: Zero::zero(),
//                 cumulative_rewards_trace_idx: Zero::zero(),
//             ),
//         };
//         let staking_contract_info = StakingContractInfoCfg {
//             min_stake: MIN_STAKE,
//             attestation_contract: ATTESTATION_CONTRACT_ADDRESS(),
//             pool_contract_class_hash: declare_pool_contract(),
//             reward_supplier: REWARD_SUPPLIER_CONTRACT_ADDRESS(),
//             exit_wait_window: DEFAULT_EXIT_WAIT_WINDOW,
//             prev_staking_contract_class_hash: DUMMY_CLASS_HASH(),
//             epoch_info: DEFAULT_EPOCH_INFO(),
//         };
//         let minting_curve_contract_info = MintingCurveContractInfo {
//             c_num: DEFAULT_C_NUM, c_denom: C_DENOM,
//         };
//         let test_info = TestInfo {
//             staker_address: STAKER_ADDRESS(),
//             pool_member_address: POOL_MEMBER_ADDRESS(),
//             owner_address: OWNER_ADDRESS(),
//             governance_admin: GOVERNANCE_ADMIN(),
//             initial_supply: INITIAL_SUPPLY.into(),
//             staker_initial_balance: STAKER_INITIAL_BALANCE,
//             pool_member_initial_balance: POOL_MEMBER_INITIAL_BALANCE,
//             pool_member_btc_amount: BTC_POOL_MEMBER_STAKE_AMOUNT,
//             strk_pool_enabled: false,
//             stake_amount: STAKE_AMOUNT,
//             staking_contract: STAKING_CONTRACT_ADDRESS(),
//             pool_contract_admin: POOL_CONTRACT_ADMIN(),
//             security_admin: SECURITY_ADMIN(),
//             security_agent: SECURITY_AGENT(),
//             token_admin: TOKEN_ADMIN(),
//             app_role_admin: APP_ROLE_ADMIN(),
//             upgrade_governor: UPGRADE_GOVERNOR(),
//             attestation_contract: ATTESTATION_CONTRACT_ADDRESS(),
//             attestation_window: MIN_ATTESTATION_WINDOW,
//             app_governor: APP_GOVERNOR(),
//             global_index: Zero::zero(),
//             strk_token: Token::STRK,
//             btc_token: custom_decimals_token(token_address: BTC_TOKEN_ADDRESS()),
//         };
//         let reward_supplier = RewardSupplierInfoV1 {
//             base_mint_amount: BASE_MINT_AMOUNT,
//             minting_curve_contract: MINTING_CONTRACT_ADDRESS(),
//             l1_reward_supplier: L1_REWARD_SUPPLIER,
//             buffer: BUFFER,
//             starkgate_address: STARKGATE_ADDRESS(),
//         };
//         StakingInitConfig {
//             staker_info,
//             pool_member_info,
//             staking_contract_info,
//             minting_curve_contract_info,
//             test_info,
//             reward_supplier,
//         }
//     }
// }