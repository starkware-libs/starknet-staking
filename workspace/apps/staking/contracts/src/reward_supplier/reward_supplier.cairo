#[starknet::contract]
pub mod RewardSupplier {
    use core::traits::TryInto;
    use contracts::reward_supplier::interface::{IRewardSupplier, RewardSupplierStatus, Events};
    use starknet::{ContractAddress, EthAddress};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::syscalls::{send_message_to_l1_syscall};
    use starknet::{get_block_timestamp, get_caller_address, get_contract_address};
    use starknet::SyscallResultTrait;
    use contracts::errors::{Error, assert_with_err, OptionAuxTrait};
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use contracts::minting_curve::interface::IMintingCurveDispatcher;
    use contracts::minting_curve::interface::IMintingCurveDispatcherTrait;
    use core::num::traits::Zero;
    use contracts::utils::{ceil_of_division, compute_threshold};
    use contracts::constants::STRK_IN_FRIS;
    use contracts::utils::CheckedIERC20DispatcherTrait;


    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    pub const SECONDS_IN_YEAR: u128 = 365 * 24 * 60 * 60;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        last_timestamp: u64,
        unclaimed_rewards: u128,
        l1_pending_requested_amount: u128,
        base_mint_amount: u128,
        base_mint_msg: felt252,
        minting_curve_dispatcher: IMintingCurveDispatcher,
        staking_contract: ContractAddress,
        erc20_dispatcher: IERC20Dispatcher,
        l1_staking_minter: felt252,
        starkgate_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
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
        base_mint_amount: u128,
        base_mint_msg: felt252,
        minting_curve_contract: ContractAddress,
        staking_contract: ContractAddress,
        token_address: ContractAddress,
        l1_staking_minter: felt252,
        starkgate_address: ContractAddress,
    ) {
        self.staking_contract.write(staking_contract);
        self.erc20_dispatcher.write(IERC20Dispatcher { contract_address: token_address });
        self.last_timestamp.write(get_block_timestamp());
        // Initialize unclaimed_rewards with 1 strk to make up for round ups of pool rewards
        // calculation in the staking contract.
        self.unclaimed_rewards.write(STRK_IN_FRIS);
        self.l1_pending_requested_amount.write(Zero::zero());
        self.base_mint_amount.write(base_mint_amount);
        self.base_mint_msg.write(base_mint_msg);
        self
            .minting_curve_dispatcher
            .write(IMintingCurveDispatcher { contract_address: minting_curve_contract });
        self.l1_staking_minter.write(l1_staking_minter);
        self.starkgate_address.write(starkgate_address);
    }

    #[abi(embed_v0)]
    impl RewardSupplierImpl of IRewardSupplier<ContractState> {
        fn calculate_staking_rewards(ref self: ContractState) -> u128 {
            let staking_contract = self.staking_contract.read();
            assert_with_err(
                get_caller_address() == staking_contract, Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            let last_timestamp = self.last_timestamp.read();
            let rewards = self.calculate_rewards();
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

        fn claim_rewards(ref self: ContractState, amount: u128) {
            let staking_contract = self.staking_contract.read();
            assert_with_err(
                get_caller_address() == staking_contract, Error::CALLER_IS_NOT_STAKING_CONTRACT
            );
            let unclaimed_rewards = self.unclaimed_rewards.read();
            assert_with_err(unclaimed_rewards >= amount, Error::AMOUNT_TOO_HIGH);
            self.unclaimed_rewards.write(unclaimed_rewards - amount);
            let erc20_dispatcher = self.erc20_dispatcher.read();
            erc20_dispatcher.checked_transfer(recipient: staking_contract, amount: amount.into());
        }

        fn on_receive(
            ref self: ContractState,
            l2_token: ContractAddress,
            amount: u256,
            depositor: EthAddress,
            message: Span<felt252>
        ) -> bool {
            assert_with_err(
                get_caller_address() == self.starkgate_address.read(),
                Error::ON_RECEIVE_NOT_FROM_STARKGATE
            );
            let amount_low: u128 = amount.try_into().expect_with_err(Error::AMOUNT_TOO_HIGH);
            let mut l1_pending_requested_amount = self.l1_pending_requested_amount.read();
            if amount_low > l1_pending_requested_amount {
                self.l1_pending_requested_amount.write(Zero::zero());
                return true;
            }
            l1_pending_requested_amount -= amount_low;
            self.l1_pending_requested_amount.write(l1_pending_requested_amount);
            true
        }

        fn state_of(self: @ContractState) -> RewardSupplierStatus {
            RewardSupplierStatus {
                last_timestamp: self.last_timestamp.read(),
                unclaimed_rewards: self.unclaimed_rewards.read(),
                l1_pending_requested_amount: self.l1_pending_requested_amount.read(),
            }
        }
    }

    #[generate_trait]
    pub impl InternalRewardSupplierFunctions of InternalRewardSupplierFunctionsTrait {
        fn calculate_rewards(ref self: ContractState) -> u128 {
            let minting_curve_dispatcher = self.minting_curve_dispatcher.read();
            let yearly_mint = minting_curve_dispatcher.yearly_mint();
            let last_timestamp = self.last_timestamp.read();
            let current_time = get_block_timestamp();
            self.last_timestamp.write(current_time);
            let seconds_diff = current_time - last_timestamp;
            yearly_mint * seconds_diff.into() / SECONDS_IN_YEAR
        }

        fn update_unclaimed_rewards(ref self: ContractState, rewards: u128) -> u128 {
            let mut unclaimed_rewards = self.unclaimed_rewards.read();
            unclaimed_rewards += rewards;
            self.unclaimed_rewards.write(unclaimed_rewards);
            unclaimed_rewards
        }

        fn request_funds_if_needed(ref self: ContractState, unclaimed_rewards: u128) {
            let mut l1_pending_requested_amount = self.l1_pending_requested_amount.read();
            let base_mint_amount = self.base_mint_amount.read();
            let erc20_dispatcher = self.erc20_dispatcher.read();
            let balance: u128 = erc20_dispatcher
                .balance_of(account: get_contract_address())
                .try_into()
                .expect_with_err(Error::BALANCE_ISNT_U128);
            let credit = balance + l1_pending_requested_amount;
            let debit = unclaimed_rewards;
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
