#[starknet::contract]
pub mod MintingCurve {
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use contracts_commons::components::roles::RolesComponent;
    use contracts_commons::interfaces::identity::Identity;
    use core::num::traits::{Sqrt, WideMul};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use staking::constants::{C_DENOM, DEFAULT_C_NUM, MAX_C_NUM};
    use staking::minting_curve::errors::Error;
    use staking::minting_curve::interface::{
        ConfigEvents, Events, IMintingCurve, IMintingCurveConfig, MintingCurveContractInfo,
    };
    use staking::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
    use staking::types::{Amount, Inflation};
    use starknet::ContractAddress;
    pub const CONTRACT_IDENTITY: felt252 = 'Minting Curve';
    pub const CONTRACT_VERSION: felt252 = '1.0.0';

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
        // Total supply of the token in L1. This is updated by the L1 reward supplier.
        total_supply: Amount,
        // L1 reward supplier.
        l1_reward_supplier: felt252,
        // The numerator of the inflation rate. The denominator is C_DENOM. C_NUM / C_DENOM is the
        // fraction of the total supply that can be minted in a year.
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
        self.staking_dispatcher.write(IStakingDispatcher { contract_address: staking_contract });
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

    // Message updating the total supply, sent by the L1 reward supplier.
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
        /// Return yearly mint amount (M * total_supply).
        /// To calculate the amount, we utilize the minting curve formula (which is in percentage):
        ///   M = (C / 10) * sqrt(S),
        /// where:
        /// - M: Yearly mint rate (%)
        /// - C: Max theoretical inflation (%)
        /// - S: Staking rate of total supply (%)
        ///
        /// If C, S and M are given as a fractions (instead of percentages), we get:
        ///   M = C * sqrt(S).
        fn yearly_mint(self: @ContractState) -> Amount {
            let total_supply = self.total_supply.read();
            let staking_dispatcher = self.staking_dispatcher.read();
            let total_stake = staking_dispatcher.get_total_stake();
            let yearly_mint = self.compute_yearly_mint(:total_stake, :total_supply);
            yearly_mint
        }

        fn contract_parameters(self: @ContractState) -> MintingCurveContractInfo {
            MintingCurveContractInfo { c_num: self.c_num.read(), c_denom: C_DENOM }
        }
    }

    #[abi(embed_v0)]
    impl IMintingCurveConfigImpl of IMintingCurveConfig<ContractState> {
        // Set the maximum inflation rate that can be minted in a year.
        // c_num is the numerator of the fraction c_num / C_DENOM (currently C_DENOM = 10,000).
        // If you wish to set the inflation rate to 1.7%, you should set c_num to 170.
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
