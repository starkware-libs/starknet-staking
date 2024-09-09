#[starknet::contract]
pub mod MintingCurve {
    use core::num::traits::{WideMul, Sqrt};
    use contracts::minting_curve::interface::{IMintingCurve, Events};
    use contracts::minting_curve::interface::{IMintingCurveConfig, MintingCurveContractInfo};
    use contracts::staking::interface::{IStakingDispatcherTrait, IStakingDispatcher};
    use contracts::errors::{Error, assert_with_err};
    use starknet::{ContractAddress};
    use contracts_commons::components::roles::RolesComponent;
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use contracts_commons::components::roles::interface::{APP_GOVERNOR, GOVERNANCE_ADMIN};
    use contracts::constants::{DEFAULT_C_NUM, C_DENOM};

    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl RolesImpl = RolesComponent::RolesImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        roles: RolesComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        staking_dispatcher: IStakingDispatcher,
        total_supply: u128,
        l1_staking_minter_address: felt252,
        c_num: u16
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        TotalSupplyChanged: Events::TotalSupplyChanged
    }


    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        staking_contract: ContractAddress,
        total_supply: u128,
        l1_staking_minter_address: felt252
    ) {
        self.accesscontrol.initializer();
        self.roles.initializer();
        // Override default role admins.
        self.accesscontrol.set_role_admin(role: APP_GOVERNOR, admin_role: GOVERNANCE_ADMIN);
        self.staking_dispatcher.write(IStakingDispatcher { contract_address: staking_contract });
        self.total_supply.write(total_supply);
        self.l1_staking_minter_address.write(l1_staking_minter_address);
        self.c_num.write(DEFAULT_C_NUM);
    }

    #[l1_handler]
    fn update_total_supply(ref self: ContractState, from_address: felt252, total_supply: u128) {
        assert_with_err(
            from_address == self.l1_staking_minter_address.read(),
            Error::UNAUTHORIZED_MESSAGE_SENDER
        );
        let old_total_supply = self.total_supply.read();
        self.total_supply.write(total_supply);
        self.emit(Events::TotalSupplyChanged { old_total_supply, new_total_supply: total_supply });
    }

    #[abi(embed_v0)]
    impl MintingImpl of IMintingCurve<ContractState> {
        /// Return yearly mint amount.
        /// To calculate the amount, we utilize the minting curve formula (which is in percentage):
        /// M = (C / 10) * sqrt(S)
        /// where:
        /// - M: Yearly mint rate (%)
        /// - C: Max theoretical inflation (%)
        /// - S: Staking rate of total supply (%)
        fn yearly_mint(self: @ContractState) -> u128 {
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
        fn set_c_num(ref self: ContractState, c_num: u16) {
            self.roles.only_app_governor();
            assert_with_err(c_num <= C_DENOM, Error::C_NUM_OUT_OF_RANGE);
            self.c_num.write(c_num);
        }
    }

    #[generate_trait]
    impl InternalMintingCurveImpl of InternalMintingCurveTrait {
        /// yearly_mint = (M / 100) * total_supply
        /// Equivalent to: C / 100 * sqrt(total_stake * total_supply)
        /// Note: Differences are negligible at this scale.
        fn compute_yearly_mint(
            self: @ContractState, total_stake: u128, total_supply: u128
        ) -> u128 {
            let product: u256 = total_stake.wide_mul(total_supply);
            let unadjusted_mint_amount: u128 = product.sqrt();
            self.multiply_by_max_inflation(amount: unadjusted_mint_amount)
        }

        fn multiply_by_max_inflation(self: @ContractState, amount: u128) -> u128 {
            self.c_num.read().into() * amount / C_DENOM.into()
        }
    }
}
