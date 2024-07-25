#[starknet::contract]
pub mod MintingCurve {
    use core::traits::TryInto;
    use contracts::minting_curve::interface::IMintingCurve;
    use contracts::staking::interface::IStaking;
    use contracts::staking::interface::{IStakingDispatcherTrait, IStakingDispatcher};
    use contracts::errors::{Error, expect_with_err};
    use starknet::{ContractAddress, contract_address_const};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use core::integer::u256_sqrt;

    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    pub const C_nom: u8 = 2;
    pub const C_denom: u8 = 1;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        staking_contract: ContractAddress,
        total_supply: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event
    }


    #[constructor]
    pub fn constructor(
        ref self: ContractState, staking_contract: ContractAddress, total_supply: u128,
    ) {
        self.staking_contract.write(staking_contract);
        self.total_supply.write(total_supply);
    }

    #[l1_handler]
    fn update_total_supply(ref self: ContractState, from_address: felt252, total_supply: felt252) {
        let total_supply: u128 = expect_with_err(
            total_supply.try_into(), Error::TOTAL_SUPPLY_NOT_U128
        );
        self.total_supply.write(total_supply);
    }


    #[abi(embed_v0)]
    impl MintingImpl of IMintingCurve<ContractState> {
        /// Calculate the yearly minted tokens from the formula:
        /// $$M = {C \over 10} * \sqrt S$$
        /// where:
        /// - \(M\) calculated yearly mint
        /// - \(C\) maximal theoretical inflation in percentage
        /// - \(S\) 100 * (total_stake / total_supply)
        fn yearly_mint(self: @ContractState) -> u128 {
            let total_supply = self.total_supply.read();
            let staking_dispatcher = IStakingDispatcher {
                contract_address: self.staking_contract.read(),
            };
            let total_stake = staking_dispatcher.get_total_stake();
            // This is the same as: M = C\10 * sqrt(S)
            let mint: u128 = C_nom.into()
                * (u256_sqrt(total_stake.into() * total_supply.into()))
                / C_denom.into();
            mint
        }
    }
}
