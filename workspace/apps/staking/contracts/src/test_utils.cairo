use contracts::{BASE_VALUE, staking::Staking, pooling::Pooling};
use starknet::{ContractAddress, contract_address_const};

pub(crate) mod constants {
    use starknet::{ContractAddress, contract_address_const};

    pub const MIN_STAKE: u128 = 100000;
    pub const MAX_LEVERAGE: u64 = 100;

    pub fn STAKER_ADDRESS() -> ContractAddress {
        contract_address_const::<'STAKER'>()
    }

    pub fn DUMMY_ADDRESS() -> ContractAddress {
        contract_address_const::<'DUMMY_ADDRESS'>()
    }

    pub fn TOKEN_ADDRESS() -> ContractAddress {
        contract_address_const::<'TOKEN_ADDRESS'>()
    }

    pub fn POOLING_ADDRESS() -> ContractAddress {
        contract_address_const::<'POOLING_ADDRESS'>()
    }
}

pub(crate) fn initalize_staking_state() -> Staking::ContractState {
    let mut state = Staking::contract_state_for_testing();
    let token_address: ContractAddress = constants::TOKEN_ADDRESS();
    Staking::constructor(ref state, token_address, constants::MIN_STAKE, constants::MAX_LEVERAGE);
    state
}


pub(crate) fn initalize_pooling_state() -> Pooling::ContractState {
    let staker_address: ContractAddress = constants::STAKER_ADDRESS();
    let mut state = Pooling::contract_state_for_testing();
    Pooling::constructor(ref state, staker_address);
    state
}

