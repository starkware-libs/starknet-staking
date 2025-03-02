use contracts_commons::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum AccessErrors {
    INVALID_MINTER,
    INVALID_TOKEN,
    CALLER_MISSING_ROLE,
    ZERO_ADDRESS,
    ALREADY_INITIALIZED,
    ZERO_ADDRESS_GOV_ADMIN,
    ONLY_APP_GOVERNOR,
    ONLY_OPERATOR,
    ONLY_TOKEN_ADMIN,
    ONLY_UPGRADE_GOVERNOR,
    ONLY_SECURITY_ADMIN,
    ONLY_SECURITY_AGENT,
    ONLY_MINTER,
    ONLY_SELF_CAN_RENOUNCE,
    GOV_ADMIN_CANNOT_RENOUNCE,
    MISSING_ROLE,
}

impl DescribableError of Describable<AccessErrors> {
    fn describe(self: @AccessErrors) -> ByteArray {
        match self {
            AccessErrors::INVALID_MINTER => "INVALID_MINTER_ADDRESS",
            AccessErrors::INVALID_TOKEN => "INVALID_TOKEN_ADDRESS",
            AccessErrors::CALLER_MISSING_ROLE => "CALLER_IS_MISSING_ROLE",
            AccessErrors::ZERO_ADDRESS => "INVALID_ZERO_ACCOUNT_ADDRESS",
            AccessErrors::ALREADY_INITIALIZED => "ROLES_ALREADY_INITIALIZED",
            AccessErrors::ZERO_ADDRESS_GOV_ADMIN => "INVALID_ZERO_ADDRESS_GOV_ADMIN",
            AccessErrors::ONLY_APP_GOVERNOR => "ONLY_APP_GOVERNOR",
            AccessErrors::ONLY_OPERATOR => "ONLY_OPERATOR",
            AccessErrors::ONLY_TOKEN_ADMIN => "ONLY_TOKEN_ADMIN",
            AccessErrors::ONLY_UPGRADE_GOVERNOR => "ONLY_UPGRADE_GOVERNOR",
            AccessErrors::ONLY_SECURITY_ADMIN => "ONLY_SECURITY_ADMIN",
            AccessErrors::ONLY_SECURITY_AGENT => "ONLY_SECURITY_AGENT",
            AccessErrors::ONLY_MINTER => "MINTER_ONLY",
            AccessErrors::ONLY_SELF_CAN_RENOUNCE => "ONLY_SELF_CAN_RENOUNCE",
            AccessErrors::GOV_ADMIN_CANNOT_RENOUNCE => "GOV_ADMIN_CANNOT_SELF_REMOVE",
            AccessErrors::MISSING_ROLE => "Caller is missing role",
        }
    }
}
