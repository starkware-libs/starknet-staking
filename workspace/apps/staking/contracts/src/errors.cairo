pub mod StakerErrors {
    // TODO(Nir, 14/07/2024) fix message error to be useful for the user e.g. 'Staker already exists, use increase_stake instead'
    pub const STAKER_EXISTS: felt252 = 'Staker already exists';
    pub const STAKER_DOES_NOT_EXISTS: felt252 = 'Staker does not exists';
    pub const OPERATIONAL_EXISTS: felt252 = 'Operational already exists';
    // TODO(Nir, 14/07/2024) fix message error to be useful for the user e.g. 'Amount is less than min stake - try again with enough funds'
    pub const AMOUNT_LESS_THAN_MIN_STAKE: felt252 = 'Amount is less than min stake';
}

pub mod PoolerErrors {
    pub const POOL_MEMBER_DOES_NOT_EXISTS: felt252 = 'Pool member does not exists';
}
