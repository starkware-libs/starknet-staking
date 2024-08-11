#[starknet::contract]
pub mod RewardSupplier {
    use contracts::reward_supplier::interface::IRewardSupplier;
    use starknet::{ContractAddress, EthAddress};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::get_block_timestamp;

    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);


    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        last_timestamp: u64,
        unclaimed_rewards: u128,
        buffer: u128,
        base_mint_amount: u128,
        base_mint_msg: felt252,
        minting_curve_contract: ContractAddress,
        staking_contract: ContractAddress,
        token_address: ContractAddress,
        l1_staking_minter: felt252,
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
        base_mint_amount: u128,
        base_mint_msg: felt252,
        minting_curve_contract: ContractAddress,
        staking_contract: ContractAddress,
        token_address: ContractAddress,
        l1_staking_minter: felt252,
        buffer: u128,
    ) {
        self.staking_contract.write(staking_contract);
        self.token_address.write(token_address);
        self.last_timestamp.write(get_block_timestamp());
        self.unclaimed_rewards.write(0);
        self.buffer.write(buffer);
        self.base_mint_amount.write(base_mint_amount);
        self.base_mint_msg.write(base_mint_msg);
        self.minting_curve_contract.write(minting_curve_contract);
        self.l1_staking_minter.write(l1_staking_minter);
    }

    #[abi(embed_v0)]
    impl RewardSupplierImpl of IRewardSupplier<ContractState> {
        fn calculate_staking_rewards(ref self: ContractState, base_value: u64) -> u128 {
            0_u128
        }

        fn claim_rewards(ref self: ContractState, amount: u128) {}

        fn on_receive(
            self: @ContractState,
            l2_token: ContractAddress,
            amount: u256,
            depositor: EthAddress,
            message: Span<felt252>
        ) -> bool {
            true
        }
    }
}
