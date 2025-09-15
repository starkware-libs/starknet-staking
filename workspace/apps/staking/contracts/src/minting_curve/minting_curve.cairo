#[starknet::contract]
pub mod MintingCurve {
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use core::num::traits::{Sqrt, WideMul};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use staking::minting_curve::errors::Error;
    use staking::minting_curve::interface::{
        ConfigEvents, Events, IMintingCurve, IMintingCurveConfig, MintingCurveContractInfo,
    };
    use staking::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use staking::staking::objects::NormalizedAmountTrait;
    use staking::types::{Amount, Inflation};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starkware_utils::components::replaceability::ReplaceabilityComponent;
    use starkware_utils::components::roles::RolesComponent;
    use starkware_utils::interfaces::identity::Identity;
    pub const CONTRACT_IDENTITY: felt252 = 'Minting Curve';
    pub const CONTRACT_VERSION: felt252 = '2.0.0';

    // === Reward Distribution - Important Note ===
    //
    // Previous version:
    // - Minting coefficient C = 1.60 (160 / 10,000).
    // - 100% of minted rewards allocated to STRK stakers.
    //
    // Current version:
    // - Rewards split: 75% to STRK stakers, 25% to BTC stakers, using alpha = 0.25 (25 / 100).
    // - To keep STRK rewards nearly unchanged, minting increased to C = 2.13 (213 / 10,000)
    //   — slightly less than 2.13333... for an exact match.
    //
    // Implications:
    // - STRK stakers receive ~1/40,000 (0.00333...% * 0.75) less rewards than before.
    // - Additional minor rounding differences may occur in reward calculations.
    pub(crate) const DEFAULT_C_NUM: Inflation = 213;
    pub(crate) const MAX_C_NUM: Inflation = 500;
    pub(crate) const C_DENOM: Inflation = 10_000;

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ReplaceabilityImpl =
        ReplaceabilityComponent::ReplaceabilityImpl<ContractState>;

    #[abi(embed_v0)]
    impl RolesImpl = RolesComponent::RolesImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        replaceability: ReplaceabilityComponent::Storage,
        #[substorage(v0)]
        roles: RolesComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        staking_dispatcher: IStakingDispatcher,
        /// Total supply of the token in L1. This is updated by the L1 reward supplier.
        total_supply: Amount,
        /// L1 reward supplier.
        l1_reward_supplier: felt252,
        /// The numerator of the inflation rate. The denominator is C_DENOM.
        /// Yearly mint is (C_NUM / C_DENOM) * sqrt(total_stake * total_supply).
        c_num: Inflation,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        TotalSupplyChanged: Events::TotalSupplyChanged,
        MintingCapChanged: ConfigEvents::MintingCapChanged,
    }


    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        staking_contract: ContractAddress,
        total_supply: Amount,
        l1_reward_supplier: felt252,
        governance_admin: ContractAddress,
    ) {
        self.roles.initialize(:governance_admin);
        self.staking_dispatcher.contract_address.write(staking_contract);
        self.total_supply.write(total_supply);
        self.l1_reward_supplier.write(l1_reward_supplier);
        self.c_num.write(DEFAULT_C_NUM);
    }

    #[abi(embed_v0)]
    impl _Identity of Identity<ContractState> {
        fn identify(self: @ContractState) -> felt252 nopanic {
            CONTRACT_IDENTITY
        }

        fn version(self: @ContractState) -> felt252 nopanic {
            CONTRACT_VERSION
        }
    }

    /// Message updating the total supply, sent by the L1 reward supplier.
    #[l1_handler]
    fn update_total_supply(ref self: ContractState, from_address: felt252, total_supply: Amount) {
        assert!(
            from_address == self.l1_reward_supplier.read(),
            "{}",
            Error::UNAUTHORIZED_MESSAGE_SENDER,
        );
        let old_total_supply = self.total_supply.read();
        // Note that the total supply may only increase.
        // Check that total_supply > old_total_supply to handle possible message reordering.
        if total_supply > old_total_supply {
            self.total_supply.write(total_supply);
            self
                .emit(
                    Events::TotalSupplyChanged { old_total_supply, new_total_supply: total_supply },
                );
        }
    }

    #[abi(embed_v0)]
    impl MintingImpl of IMintingCurve<ContractState> {
        fn yearly_mint(self: @ContractState) -> Amount {
            let total_supply = self.total_supply.read();
            let staking_dispatcher = self.staking_dispatcher.read();
            let (total_stake, _) = staking_dispatcher.get_current_total_staking_power();
            let yearly_mint = self
                .compute_yearly_mint(
                    total_stake: total_stake.to_strk_native_amount(), :total_supply,
                );
            yearly_mint
        }

        fn contract_parameters(self: @ContractState) -> MintingCurveContractInfo {
            MintingCurveContractInfo { c_num: self.c_num.read(), c_denom: C_DENOM }
        }
    }

    #[abi(embed_v0)]
    impl IMintingCurveConfigImpl of IMintingCurveConfig<ContractState> {
        fn set_c_num(ref self: ContractState, c_num: Inflation) {
            self.roles.only_token_admin();
            assert!(c_num <= MAX_C_NUM, "{}", Error::C_NUM_OUT_OF_RANGE);

            let old_c = self.c_num.read();
            self.c_num.write(c_num);

            self.emit(ConfigEvents::MintingCapChanged { old_c, new_c: c_num });
        }
    }

    #[generate_trait]
    impl InternalMintingCurveImpl of InternalMintingCurveTrait {
        /// Returns the yearly mint (see comment in `yearly_mint`):
        ///   yearly_mint = M * total_supply = C * sqrt(total_stake * total_supply),
        /// where M and C are given as fractions.
        /// Note: Differences are negligible at this scale.
        fn compute_yearly_mint(
            self: @ContractState, total_stake: Amount, total_supply: Amount,
        ) -> Amount {
            let stake_times_supply: u256 = total_stake.wide_mul(total_supply);
            self.c_num.read().into() * stake_times_supply.sqrt() / C_DENOM.into()
        }
    }
}
