pub mod StakerErrors {
    pub const STAKER_EXISTS: felt252 = 'Staker already exists';
    pub const STAKER_NOT_EXISTS: felt252 = 'Staker not exists';
    pub const OPERATIONAL_EXISTS: felt252 = 'Operational already exists';
    pub const AMOUNT_LESS_THAN_MIN_STAKE: felt252 = 'Amount is less than min stake';
}

pub mod PoolerErrors {
    pub const POOLER_NOT_EXISTS: felt252 = 'Pooler not exists';
}
