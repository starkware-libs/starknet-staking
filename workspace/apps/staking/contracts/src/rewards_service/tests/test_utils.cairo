use core::num::traits::Zero;
use snforge_std::{ContractClassTrait, DeclareResultTrait};
use staking::rewards_service::rewards_service::RewardsService::BLOCK_TIME_SCALE;
use staking::test_utils::constants::{CALLER_ADDRESS, OWNER_ADDRESS, STAKING_CONTRACT_ADDRESS};
use staking::test_utils::{
    StakingInitConfig, advance_time_global, general_contract_system_deployment,
};
use starknet::{ContractAddress, SyscallResult, get_block_number, get_block_timestamp};
use starkware_utils::time::time::TimeDelta;
use starkware_utils_testing::test_utils::advance_block_number_global;

#[derive(Drop, Copy)]
pub(crate) struct RewardsServiceConfig {
    pub(crate) rewards_service_address: ContractAddress,
    pub(crate) staking_address: ContractAddress,
    pub(crate) permissioned_caller: ContractAddress,
    pub(crate) last_update_block_number: u64,
    pub(crate) last_update_block_timestamp: u64,
    pub(crate) owner: ContractAddress,
}

impl RewardsServiceConfigDefault of Default<RewardsServiceConfig> {
    fn default() -> RewardsServiceConfig {
        RewardsServiceConfig {
            rewards_service_address: Zero::zero(),
            staking_address: STAKING_CONTRACT_ADDRESS,
            permissioned_caller: CALLER_ADDRESS,
            last_update_block_number: get_block_number(),
            last_update_block_timestamp: get_block_timestamp(),
            owner: OWNER_ADDRESS,
        }
    }
}

pub(crate) fn deploy_rewards_service(
    cfg: RewardsServiceConfig,
) -> SyscallResult<(ContractAddress, Span<felt252>)> {
    let mut calldata = ArrayTrait::new();
    cfg.staking_address.serialize(ref calldata);
    cfg.permissioned_caller.serialize(ref calldata);
    cfg.last_update_block_number.serialize(ref calldata);
    cfg.last_update_block_timestamp.serialize(ref calldata);
    cfg.owner.serialize(ref calldata);
    let rewards_service_contract = snforge_std::declare("RewardsService").unwrap().contract_class();
    rewards_service_contract.deploy(@calldata)
}

pub(crate) fn generic_test_fixture() -> (StakingInitConfig, RewardsServiceConfig) {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    advance_blocks(blocks: 1, time_per_block: 2 * BLOCK_TIME_SCALE);
    let mut rewards_service_cfg: RewardsServiceConfig = Default::default();
    rewards_service_cfg.staking_address = cfg.test_info.staking_contract;
    rewards_service_cfg.owner = cfg.test_info.app_governor;
    let (rewards_service_contract_address, _) = deploy_rewards_service(rewards_service_cfg)
        .unwrap();
    rewards_service_cfg.rewards_service_address = rewards_service_contract_address;
    (cfg, rewards_service_cfg)
}

/// Advance the block number by the given `blocks` and the timestamp by the given `time_per_block`
/// in 1/BLOCK_TIME_SCALE (1/100) seconds * `blocks`.
pub(crate) fn advance_blocks(blocks: u64, time_per_block: u64) {
    advance_block_number_global(:blocks);
    advance_time_global(
        time: TimeDelta { seconds: time_per_block * blocks / BLOCK_TIME_SCALE.try_into().unwrap() },
    );
}

/// Mock contract to declare a mock class hash for testing upgrade.
#[starknet::contract]
pub(crate) mod MockContract {
    #[storage]
    struct Storage {}
}
