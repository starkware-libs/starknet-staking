#[starknet::contract]
pub mod RewardSupplier {
    use core::traits::TryInto;
    use contracts::reward_supplier::interface::{IRewardSupplier, RewardSupplierInfo, Events};
    use starknet::{ContractAddress, EthAddress};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::syscalls::{send_message_to_l1_syscall};
    use starknet::{get_caller_address, get_contract_address};
    use starknet::SyscallResultTrait;
    use contracts::errors::{Error, assert_with_err, OptionAuxTrait};
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use contracts::minting_curve::interface::IMintingCurveDispatcher;
    use contracts::minting_curve::interface::IMintingCurveDispatcherTrait;
    use core::num::traits::Zero;
    use contracts::utils::{ceil_of_division, compute_threshold};
    use contracts::constants::STRK_IN_FRIS;
    use contracts::utils::CheckedIERC20DispatcherTrait;
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use contracts_commons::components::roles::RolesComponent;
    use RolesComponent::InternalTrait as RolesInternalTrait;
    use contracts::types::Amount;
    use contracts_commons::types::time::{TimeStamp, Time};
    use contracts_commons::interfaces::identity::Identity;
    pub const CONTRACT_IDENTITY: felt252 = 'Reward Supplier';
    pub const CONTRACT_VERSION: felt252 = '1.0.0';

    component!(path: ReplaceabilityComponent, storage: replaceability, event: ReplaceabilityEvent);
    component!(path: RolesComponent, storage: roles, event: RolesEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl ReplaceabilityImpl =
        ReplaceabilityComponent::ReplaceabilityImpl<ContractState>;

    #[abi(embed_v0)]
    impl RolesImpl = RolesComponent::RolesImpl<ContractState>;

    pub const SECONDS_IN_YEAR: u128 = 365 * 24 * 60 * 60;

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
        last_timestamp: TimeStamp,
        unclaimed_rewards: Amount,
        l1_pending_requested_amount: Amount,
        base_mint_amount: Amount,
        minting_curve_dispatcher: IMintingCurveDispatcher,
        staking_contract: ContractAddress,
        token_dispatcher: IERC20Dispatcher,
        l1_staking_minter: felt252,
        starkgate_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReplaceabilityEvent: ReplaceabilityComponent::Event,
        #[flat]
        RolesEvent: RolesComponent::Event,
        #[flat]
        accesscontrolEvent: AccessControlComponent::Event,
        #[flat]
        src5Event: SRC5Component::Event,
        CalculatedRewards: Events::CalculatedRewards,
        mintRequest: Events::MintRequest,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        base_mint_amount: Amount,
        minting_curve_contract: ContractAddress,
        staking_contract: ContractAddress,
        token_address: ContractAddress,
        l1_staking_minter: felt252,
        starkgate_address: ContractAddress,
        governance_admin: ContractAddress
    ) {
        self.roles.initialize(:governance_admin);
        self.staking_contract.write(staking_contract);
        self.token_dispatcher.write(IERC20Dispatcher { contract_address: token_address });
        self.last_timestamp.write(Time::now());
        // Initialize unclaimed_rewards with 1 strk to make up for round ups of pool rewards
        // calculation in the staking contract.
        self.unclaimed_rewards.write(STRK_IN_FRIS);
        self.l1_pending_requested_amount.write(Zero::zero());
        self.base_mint_amount.write(base_mint_amount);
        self
            .minting_curve_dispatcher
            .write(IMintingCurveDispatcher { contract_address: minting_curve_contract });
        self.l1_staking_minter.write(l1_staking_minter);
        self.starkgate_address.write(starkgate_address);
    }

    #[abi(embed_v0)]
    impl _Identity of Identity<ContractState> {
        fn identify(self: @ContractState) -> felt252 {
            CONTRACT_IDENTITY
        }

        fn version(self: @ContractState) -> felt252 {
            CONTRACT_VERSION
        }
    }

    #[abi(embed_v0)]
    impl RewardSupplierImpl of IRewardSupplier<ContractState> {
        fn calculate_staking_rewards(ref self: ContractState) -> Amount {
            let staking_contract = self.staking_contract.read();
            assert_with_err(
                get_caller_address() == staking_contract, Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            let last_timestamp = self.last_timestamp.read();
            let rewards = self.update_rewards();
            let new_timestamp = self.last_timestamp.read();
            let unclaimed_rewards = self.update_unclaimed_rewards(:rewards);
            self.request_funds_if_needed(:unclaimed_rewards);
            self
                .emit(
                    Events::CalculatedRewards {
                        last_timestamp, new_timestamp, rewards_calculated: rewards,
                    }
                );
            rewards
        }

        fn claim_rewards(ref self: ContractState, amount: Amount) {
            let staking_contract = self.staking_contract.read();
            assert_with_err(
                get_caller_address() == staking_contract, Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            let unclaimed_rewards = self.unclaimed_rewards.read();
            assert_with_err(unclaimed_rewards >= amount, Error::AMOUNT_TOO_HIGH);
            self.unclaimed_rewards.write(unclaimed_rewards - amount);
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher.checked_transfer(recipient: staking_contract, amount: amount.into());
        }

        fn on_receive(
            ref self: ContractState,
            l2_token: ContractAddress,
            amount: u256,
            depositor: EthAddress,
            message: Span<felt252>
        ) {
            // These messages accepted only from the token bridge.
            assert_with_err(
                get_caller_address() == self.starkgate_address.read(),
                Error::ON_RECEIVE_NOT_FROM_STARKGATE
            );
            // The bridge may serve multiple tokens, only the correct token may be received.
            assert_with_err(
                l2_token == self.token_dispatcher.read().contract_address, Error::UNEXPECTED_TOKEN
            );
            let amount_low: Amount = amount.try_into().expect_with_err(Error::AMOUNT_TOO_HIGH);
            let mut l1_pending_requested_amount = self.l1_pending_requested_amount.read();
            if amount_low > l1_pending_requested_amount {
                self.l1_pending_requested_amount.write(Zero::zero());
                return;
            }
            l1_pending_requested_amount -= amount_low;
            self.l1_pending_requested_amount.write(l1_pending_requested_amount);
        }

        fn contract_parameters(self: @ContractState) -> RewardSupplierInfo {
            RewardSupplierInfo {
                last_timestamp: self.last_timestamp.read(),
                unclaimed_rewards: self.unclaimed_rewards.read(),
                l1_pending_requested_amount: self.l1_pending_requested_amount.read(),
            }
        }
    }

    #[generate_trait]
    pub impl InternalRewardSupplierFunctions of InternalRewardSupplierFunctionsTrait {
        fn update_rewards(ref self: ContractState) -> Amount {
            let minting_curve_dispatcher = self.minting_curve_dispatcher.read();
            let yearly_mint = minting_curve_dispatcher.yearly_mint();
            let last_timestamp = self.last_timestamp.read();
            let current_time = Time::now();
            self.last_timestamp.write(current_time);
            let seconds_diff: u64 = current_time.sub(last_timestamp).into();
            yearly_mint * seconds_diff.into() / SECONDS_IN_YEAR
        }

        fn update_unclaimed_rewards(ref self: ContractState, rewards: Amount) -> Amount {
            let mut unclaimed_rewards = self.unclaimed_rewards.read();
            unclaimed_rewards += rewards;
            self.unclaimed_rewards.write(unclaimed_rewards);
            unclaimed_rewards
        }

        fn request_funds_if_needed(ref self: ContractState, unclaimed_rewards: Amount) {
            let token_dispatcher = self.token_dispatcher.read();
            let balance: Amount = token_dispatcher
                .balance_of(account: get_contract_address())
                .try_into()
                .expect_with_err(Error::BALANCE_ISNT_AMOUNT_TYPE);
            let mut l1_pending_requested_amount = self.l1_pending_requested_amount.read();
            let credit = balance + l1_pending_requested_amount;
            let debit = unclaimed_rewards;
            let base_mint_amount = self.base_mint_amount.read();
            let threshold = compute_threshold(base_mint_amount);
            if credit < debit + threshold {
                let diff = debit + threshold - credit;
                let num_msgs = ceil_of_division(dividend: diff, divisor: base_mint_amount);
                let total_amount = num_msgs * base_mint_amount;
                for _ in 0..num_msgs {
                    self.send_mint_request_to_l1_staking_minter();
                };
                self.emit(Events::MintRequest { total_amount, num_msgs });
                l1_pending_requested_amount += total_amount;
            }
            self.l1_pending_requested_amount.write(l1_pending_requested_amount);
        }

        fn send_mint_request_to_l1_staking_minter(self: @ContractState) {
            let payload = array![self.base_mint_amount.read().into()].span();
            let to_address = self.l1_staking_minter.read();
            send_message_to_l1_syscall(:to_address, :payload).unwrap_syscall();
        }
    }
}
