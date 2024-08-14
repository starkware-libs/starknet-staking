#[starknet::contract]
pub mod RewardSupplier {
    use contracts::reward_supplier::interface::IRewardSupplier;
    use starknet::{ContractAddress, EthAddress};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{get_block_timestamp, get_caller_address};
    use contracts::errors::{Error, assert_with_err};
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};

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

        fn claim_rewards(ref self: ContractState, amount: u128) {
            let staking_contract = self.staking_contract.read();
            assert_with_err(
                get_caller_address() == staking_contract, Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            let unclaimed_rewards = self.unclaimed_rewards.read();
            assert_with_err(unclaimed_rewards >= amount, Error::AMOUNT_TOO_HIGH);
            self.unclaimed_rewards.write(unclaimed_rewards - amount);
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher.transfer(recipient: staking_contract, amount: amount.into());
        }

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
