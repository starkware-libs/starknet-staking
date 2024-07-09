pub mod ERC20Errors {
    pub const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
    pub const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
    pub const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
    pub const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
    pub const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
    pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
    pub const ERC20_ALLOWANCE_INSUFFICIENT: felt252 = 'ERC20 allowance is insufficient';
    pub const ERC20_BALANCE_INSUFFICIENT: felt252 = 'ERC20 balance is insufficient';
}


pub mod AccessErrors {
    pub const INVALID_MINTER: felt252 = 'INVALID_MINTER_ADDRESS';
    pub const INVALID_TOKEN: felt252 = 'INVALID_TOKEN_ADDRESS';
    pub const CALLER_MISSING_ROLE: felt252 = 'CALLER_IS_MISSING_ROLE';
    pub const ZERO_ADDRESS: felt252 = 'INVALID_ACCOUNT_ADDRESS';
    pub const ALREADY_INITIALIZED: felt252 = 'ROLES_ALREADY_INITIALIZED';
    pub const ZERO_ADDRESS_GOV_ADMIN: felt252 = 'ZERO_PROVISIONAL_GOV_ADMIN';
    pub const ONLY_APP_GOVERNOR: felt252 = 'ONLY_APP_GOVERNOR';
    pub const ONLY_OPERATOR: felt252 = 'ONLY_OPERATOR';
    pub const ONLY_TOKEN_ADMIN: felt252 = 'ONLY_TOKEN_ADMIN';
    pub const ONLY_UPGRADE_GOVERNOR: felt252 = 'ONLY_UPGRADE_GOVERNOR';
    pub const ONLY_SECURITY_ADMIN: felt252 = 'ONLY_SECURITY_ADMIN';
    pub const ONLY_SECURITY_AGENT: felt252 = 'ONLY_SECURITY_AGENT';
    pub const ONLY_MINTER: felt252 = 'MINTER_ONLY';
    pub const ONLY_SELF_CAN_RENOUNCE: felt252 = 'ONLY_SELF_CAN_RENOUNCE';
    pub const GOV_ADMIN_CANNOT_RENOUNCE: felt252 = 'GOV_ADMIN_CANNOT_SELF_REMOVE';
}

pub mod ReplaceErrors {
    pub const FINALIZED: felt252 = 'FINALIZED';
    pub const UNKNOWN_IMPLEMENTATION: felt252 = 'UNKNOWN_IMPLEMENTATION';
    pub const NOT_ENABLED_YET: felt252 = 'NOT_ENABLED_YET';
    pub const IMPLEMENTATION_EXPIRED: felt252 = 'IMPLEMENTATION_EXPIRED';
    pub const EIC_LIB_CALL_FAILED: felt252 = 'EIC_LIB_CALL_FAILED';
    pub const REPLACE_CLASS_HASH_FAILED: felt252 = 'REPLACE_CLASS_HASH_FAILED';
}
