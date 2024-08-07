#[starknet::contract]
pub mod MintingCurve {
    use contracts::minting_curve::interface::IMintingCurve;
    use contracts::staking::interface::{IStakingDispatcherTrait, IStakingDispatcher};
    use contracts::errors::{Error, OptionAuxTrait, assert_with_err};
    use starknet::{ContractAddress, contract_address_const};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use core::integer::u256_sqrt;

    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    pub const C_nom: u16 = 200;
    pub const C_denom: u16 = 10_000;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        staking_contract: ContractAddress,
        total_supply: u128,
        l1_staking_minter_address: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event
    }


    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        staking_contract: ContractAddress,
        total_supply: u128,
        l1_staking_minter_address: felt252
    ) {
        self.staking_contract.write(staking_contract);
        self.total_supply.write(total_supply);
        self.l1_staking_minter_address.write(l1_staking_minter_address)
    }

    #[l1_handler]
    fn update_total_supply(ref self: ContractState, from_address: felt252, total_supply: felt252) {
        assert_with_err(
            from_address == self.l1_staking_minter_address.read(),
            Error::UNAUTHORIZED_MESSAGE_SENDER
        );
        let total_supply: u128 = total_supply
            .try_into()
            .expect_with_err(Error::TOTAL_SUPPLY_NOT_U128);
        self.total_supply.write(total_supply);
    }

    /// yearly_mint = (M / 100) * total_supply
    /// Equivalent to: C / 100 * sqrt(total_stake * total_supply)
    /// Note: Differences are negligible at this scale.        
    pub(crate) fn compute_yearly_mint(total_stake: u128, total_supply: u128) -> u128 {
        let unadjusted_mint_amount = u256_sqrt(total_stake.into() * total_supply.into());
        multiply_by_max_inflation(amount: unadjusted_mint_amount)
    }

    pub(crate) fn multiply_by_max_inflation(amount: u128) -> u128 {
        C_nom.into() * amount / C_denom.into()
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
            let staking_dispatcher = IStakingDispatcher {
                contract_address: self.staking_contract.read(),
            };
            let total_stake = staking_dispatcher.get_total_stake();
            let yearly_mint: u128 = compute_yearly_mint(:total_stake, :total_supply);
            yearly_mint
        }
    }
}
