use starknet::ContractAddress;
use core::num::traits::Zero;

#[derive(Hash, Drop, Serde, Copy, starknet::Store)]
pub struct UndelegateIntentKey {
    pub pool_contract: ContractAddress,
    // The identifier is generally the pool member address, but it can be any unique identifier,
    // depending on the logic of the pool contract.
    pub identifier: felt252
}

#[derive(Debug, PartialEq, Drop, Serde, Copy, starknet::Store)]
pub struct UndelegateIntentValue {
    pub unpool_time: u64,
    pub amount: u128
}

pub impl UndelegateIntentValueZero of core::num::traits::Zero<UndelegateIntentValue> {
    fn zero() -> UndelegateIntentValue {
        UndelegateIntentValue { unpool_time: Zero::zero(), amount: Zero::zero() }
    }
    #[inline(always)]
    fn is_zero(self: @UndelegateIntentValue) -> bool {
        *self == Self::zero()
    }
    #[inline(always)]
    fn is_non_zero(self: @UndelegateIntentValue) -> bool {
        !self.is_zero()
    }
}
