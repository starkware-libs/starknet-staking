#[starknet::contract]
pub mod MintingCurve {
    use core::num::traits::{WideMul, Sqrt};
    use contracts::minting_curve::interface::{IMintingCurve, Events, ConfigEvents};
    use contracts::minting_curve::interface::{IMintingCurveConfig, MintingCurveContractInfo};
    use contracts::staking::interface::{IStakingDispatcherTrait, IStakingDispatcher};
    use contracts::errors::{Error, assert_with_err};
    use starknet::{ContractAddress};
    use contracts_commons::components::roles::RolesComponent;
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use contracts::constants::{DEFAULT_C_NUM, C_DENOM};
    use contracts::types::{Inflation, Amount};

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
        total_supply: Amount,
        l1_staking_minter_address: felt252,
        c_num: Inflation
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        TotalSupplyChanged: Events::TotalSupplyChanged,
        MintingCapChanged: ConfigEvents::MintingCapChanged
    }


    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        staking_contract: ContractAddress,
        total_supply: Amount,
        l1_staking_minter_address: felt252,
        governance_admin: ContractAddress
    ) {
        self.accesscontrol.initializer();
        self.roles.initializer(:governance_admin);
        self.staking_dispatcher.write(IStakingDispatcher { contract_address: staking_contract });
        self.total_supply.write(total_supply);
        self.l1_staking_minter_address.write(l1_staking_minter_address);
        self.c_num.write(DEFAULT_C_NUM);
    }

    #[l1_handler]
    fn update_total_supply(ref self: ContractState, from_address: felt252, total_supply: Amount) {
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
        fn set_c_num(ref self: ContractState, c_num: Inflation) {
            self.roles.only_token_admin();
            assert_with_err(c_num <= C_DENOM, Error::C_NUM_OUT_OF_RANGE);
            let old_c = self.c_num.read();
            self.c_num.write(c_num);
            self.emit(ConfigEvents::MintingCapChanged { old_c, new_c: c_num });
        }
    }

    #[generate_trait]
    impl InternalMintingCurveImpl of InternalMintingCurveTrait {
        /// yearly_mint = (M / 100) * total_supply
        /// Equivalent to: C / 100 * sqrt(total_stake * total_supply)
        /// Note: Differences are negligible at this scale.
        fn compute_yearly_mint(
            self: @ContractState, total_stake: Amount, total_supply: Amount
        ) -> Amount {
            let product: u256 = total_stake.wide_mul(total_supply);
            let unadjusted_mint_amount: Amount = product.sqrt();
            self.multiply_by_max_inflation(amount: unadjusted_mint_amount)
        }

        fn multiply_by_max_inflation(self: @ContractState, amount: Amount) -> Amount {
            self.c_num.read().into() * amount / C_DENOM.into()
        }
    }
}
