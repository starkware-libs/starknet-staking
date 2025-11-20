#[starknet::contract]
pub mod RewardsService {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use staking::rewards_service::errors::Errors;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::{ClassHash, ContractAddress, get_block_number, get_block_timestamp};
    use starkware_utils::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};
    use starkware_utils::constants::{HOUR, WEEK};
    use starkware_utils::time::time::Seconds;

    /// Default value for the minimum time between updates.
    pub(crate) const DEFAULT_MIN_TIME_BETWEEN_UPDATES: Seconds = 12 * HOUR;
    /// Default value for the maximum time between updates.
    pub(crate) const DEFAULT_MAX_TIME_BETWEEN_UPDATES: Seconds = 2 * WEEK;

    /// Scale factor for block time measurements.
    pub(crate) const BLOCK_TIME_SCALE: u64 = 100;
    /// Minimum time per block, measured in 1/BLOCK_TIME_SCALE seconds (1/100 seconds).
    pub(crate) const MIN_BLOCK_TIME: u32 = 180; // 1.8 sec/block.
    /// Maximum time per block, measured in 1/BLOCK_TIME_SCALE seconds (1/100 seconds).
    pub(crate) const MAX_BLOCK_TIME: u32 = 900; // 9 sec/block.

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[storage]
    struct Storage {
        /// Ownable component storage.
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        /// Upgradeable component storage.
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        /// The address of the staking contract.
        staking_address: ContractAddress,
        /// The address of the permissioned caller to `trigger_set_epoch_info`.
        permissioned_caller: ContractAddress,
        /// `(block_number, block_timestamp)` of the block where the `EpochInfo` was last updated.
        last_update_info: (u64, u64),
        /// (min_update_interval, max_update_interval) in seconds. e.g. the minimum and maximum time
        /// between epoch_info updates.
        update_interval_bounds: (Seconds, Seconds),
        /// (min_block_time, max_block_time) in 1/BLOCK_TIME_SCALE seconds.
        block_time_bounds: (u32, u32),
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OwnableEvent: OwnableComponent::Event,
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        staking_address: ContractAddress,
        permissioned_caller: ContractAddress,
        last_update_block_number: u64,
        last_update_block_timestamp: u64,
        owner: ContractAddress,
    ) {
        let staking_roles = IRolesDispatcher { contract_address: staking_address };
        assert(staking_roles.is_app_governor(account: owner), Errors::OWNER_NOT_APP_GOVERNOR);
        assert(
            last_update_block_number.is_non_zero()
                && last_update_block_number <= get_block_number(),
            Errors::INVALID_BLOCK_NUMBER,
        );
        assert(
            last_update_block_timestamp.is_non_zero()
                && last_update_block_timestamp <= get_block_timestamp(),
            Errors::INVALID_BLOCK_TIMESTAMP,
        );
        self.staking_address.write(staking_address);
        self.permissioned_caller.write(permissioned_caller);
        self.last_update_info.write((last_update_block_number, last_update_block_timestamp));
        self
            .update_interval_bounds
            .write((DEFAULT_MIN_TIME_BETWEEN_UPDATES, DEFAULT_MAX_TIME_BETWEEN_UPDATES));
        self.block_time_bounds.write((MIN_BLOCK_TIME, MAX_BLOCK_TIME));
        self.ownable.initializer(:owner);
    }

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(:new_class_hash);
        }
    }
}
