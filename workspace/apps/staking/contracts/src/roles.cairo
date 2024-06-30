pub mod roles_component {
    use super::super::roles_interface::{
        IRoles, APP_GOVERNOR, APP_ROLE_ADMIN, GOVERNANCE_ADMIN, OPERATOR, TOKEN_ADMIN,
        UPGRADE_GOVERNOR, SECURITY_ADMIN, SECURITY_AGENT, SecurityAdminAdded, SecurityAdminRemoved,
        SecurityAgentAdded, SecurityAgentRemoved, AppGovernorAdded, AppGovernorRemoved,
        AppRoleAdminAdded, AppRoleAdminRemoved, GovernanceAdminAdded, GovernanceAdminRemoved,
        OperatorAdded, OperatorRemoved, TokenAdminAdded, TokenAdminRemoved, UpgradeGovernorAdded,
        UpgradeGovernorRemoved,
    };


    #[storage]
    struct Storage {
    }

    #[event]
    #[derive(Copy, Drop, PartialEq, starknet::Event)]
    pub enum Event {
        AppGovernorAdded: AppGovernorAdded,
        AppGovernorRemoved: AppGovernorRemoved,
        AppRoleAdminAdded: AppRoleAdminAdded,
        AppRoleAdminRemoved: AppRoleAdminRemoved,
        GovernanceAdminAdded: GovernanceAdminAdded,
        GovernanceAdminRemoved: GovernanceAdminRemoved,
        OperatorAdded: OperatorAdded,
        OperatorRemoved: OperatorRemoved,
        SecurityAdminAdded: SecurityAdminAdded,
        SecurityAdminRemoved: SecurityAdminRemoved,
        SecurityAgentAdded: SecurityAgentAdded,
        SecurityAgentRemoved: SecurityAgentRemoved,
        TokenAdminAdded: TokenAdminAdded,
        TokenAdminRemoved: TokenAdminRemoved,
        UpgradeGovernorAdded: UpgradeGovernorAdded,
        UpgradeGovernorRemoved: UpgradeGovernorRemoved,
    }


    #[external(v0)]
    impl RolesImpl of IRoles<ContractState> {
        fn is_app_governor(self: @ContractState, account: ContractAddress) -> bool {
            self.has_role(role: APP_GOVERNOR, :account)
        }

        fn is_app_role_admin(self: @ContractState, account: ContractAddress) -> bool {
            self.has_role(role: APP_ROLE_ADMIN, :account)
        }

        fn is_governance_admin(self: @ContractState, account: ContractAddress) -> bool {
            self.has_role(role: GOVERNANCE_ADMIN, :account)
        }

        fn is_operator(self: @ContractState, account: ContractAddress) -> bool {
            self.has_role(role: OPERATOR, :account)
        }

        fn is_token_admin(self: @ContractState, account: ContractAddress) -> bool {
            self.has_role(role: TOKEN_ADMIN, :account)
        }

        fn is_upgrade_governor(self: @ContractState, account: ContractAddress) -> bool {
            self.has_role(role: UPGRADE_GOVERNOR, :account)
        }

        fn is_security_admin(self: @ContractState, account: ContractAddress) -> bool {
            self.has_role(role: SECURITY_ADMIN, :account)
        }

        fn is_security_agent(self: @ContractState, account: ContractAddress) -> bool {
            self.has_role(role: SECURITY_AGENT, :account)
        }

        fn register_app_governor(ref self: ContractState, account: ContractAddress) {
            let event = Event::AppGovernorAdded(
                AppGovernorAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: APP_GOVERNOR, :account, :event);
        }

        fn remove_app_governor(ref self: ContractState, account: ContractAddress) {
            let event = Event::AppGovernorRemoved(
                AppGovernorRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: APP_GOVERNOR, :account, :event);
        }

        fn register_app_role_admin(ref self: ContractState, account: ContractAddress) {
            let event = Event::AppRoleAdminAdded(
                AppRoleAdminAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: APP_ROLE_ADMIN, :account, :event);
        }

        fn remove_app_role_admin(ref self: ContractState, account: ContractAddress) {
            let event = Event::AppRoleAdminRemoved(
                AppRoleAdminRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: APP_ROLE_ADMIN, :account, :event);
        }

        fn register_security_admin(ref self: ContractState, account: ContractAddress) {
            let event = Event::SecurityAdminAdded(
                SecurityAdminAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: SECURITY_ADMIN, :account, :event);
        }

        fn remove_security_admin(ref self: ContractState, account: ContractAddress) {
            let event = Event::SecurityAdminRemoved(
                SecurityAdminRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: SECURITY_ADMIN, :account, :event);
        }

        fn register_security_agent(ref self: ContractState, account: ContractAddress) {
            let event = Event::SecurityAgentAdded(
                SecurityAgentAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: SECURITY_AGENT, :account, :event);
        }

        fn remove_security_agent(ref self: ContractState, account: ContractAddress) {
            let event = Event::SecurityAgentRemoved(
                SecurityAgentRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: SECURITY_AGENT, :account, :event);
        }


        fn register_governance_admin(ref self: ContractState, account: ContractAddress) {
            let event = Event::GovernanceAdminAdded(
                GovernanceAdminAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: GOVERNANCE_ADMIN, :account, :event);
        }

        fn remove_governance_admin(ref self: ContractState, account: ContractAddress) {
            let event = Event::GovernanceAdminRemoved(
                GovernanceAdminRemoved {
                    removed_account: account, removed_by: get_caller_address()
                }
            );
            self._revoke_role_and_emit(role: GOVERNANCE_ADMIN, :account, :event);
        }

        fn register_operator(ref self: ContractState, account: ContractAddress) {
            let event = Event::OperatorAdded(
                OperatorAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: OPERATOR, :account, :event);
        }

        fn remove_operator(ref self: ContractState, account: ContractAddress) {
            let event = Event::OperatorRemoved(
                OperatorRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: OPERATOR, :account, :event);
        }

        fn register_token_admin(ref self: ContractState, account: ContractAddress) {
            let event = Event::TokenAdminAdded(
                TokenAdminAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: TOKEN_ADMIN, :account, :event);
        }

        fn remove_token_admin(ref self: ContractState, account: ContractAddress) {
            let event = Event::TokenAdminRemoved(
                TokenAdminRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: TOKEN_ADMIN, :account, :event);
        }

        fn register_upgrade_governor(ref self: ContractState, account: ContractAddress) {
            let event = Event::UpgradeGovernorAdded(
                UpgradeGovernorAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: UPGRADE_GOVERNOR, :account, :event);
        }

        fn remove_upgrade_governor(ref self: ContractState, account: ContractAddress) {
            let event = Event::UpgradeGovernorRemoved(
                UpgradeGovernorRemoved {
                    removed_account: account, removed_by: get_caller_address()
                }
            );
            self._revoke_role_and_emit(role: UPGRADE_GOVERNOR, :account, :event);
        }

        // TODO -  change the fn name to renounce_role when we can have modularity.
        // TODO -  change to GOVERNANCE_ADMIN_CANNOT_SELF_REMOVE when the 32 characters limitations
        // is off.
        fn renounce(ref self: ContractState, role: RoleId) {
            assert(role != GOVERNANCE_ADMIN, GOV_ADMIN_CANNOT_RENOUNCE);
            self.renounce_role(:role, account: get_caller_address())
        // TODO add another event? Currently there are two events when a role is removed but
        // only one if it was renounced.
        }
    }


    #[generate_trait]
    impl RolesInternal of _RolesInternal {
        // TODO -  change the fn name to _grant_role when we can have modularity.
        fn _grant_role_and_emit(
            ref self: ContractState, role: RoleId, account: ContractAddress, event: Event
        ) {
            if !self.has_role(:role, :account) {
                assert(account.is_non_zero(), ZERO_ADDRESS);
                self.grant_role(:role, :account);
                self.emit(event);
            }
        }

        // TODO -  change the fn name to _revoke_role when we can have modularity.
        fn _revoke_role_and_emit(
            ref self: ContractState, role: RoleId, account: ContractAddress, event: Event
        ) {
            if self.has_role(:role, :account) {
                self.revoke_role(:role, :account);
                self.emit(event);
            }
        }
        //
        // WARNING
        // The following internal method is unprotected and should not be used outside of a
        // contract's constructor.
        //
        // TODO -  This function should be under initialize function under roles contract.

        fn _initialize_roles(ref self: ContractState) {
            let provisional_governance_admin = get_caller_address();
            let un_initialized = self.get_role_admin(role: GOVERNANCE_ADMIN) == 0;
            assert(un_initialized, ALREADY_INITIALIZED);
            self._grant_role(role: GOVERNANCE_ADMIN, account: provisional_governance_admin);
            self._set_role_admin(role: APP_GOVERNOR, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin(role: APP_ROLE_ADMIN, admin_role: GOVERNANCE_ADMIN);
            self._set_role_admin(role: GOVERNANCE_ADMIN, admin_role: GOVERNANCE_ADMIN);
            self._set_role_admin(role: OPERATOR, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin(role: TOKEN_ADMIN, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin(role: UPGRADE_GOVERNOR, admin_role: GOVERNANCE_ADMIN);

            self._grant_role(role: SECURITY_ADMIN, account: provisional_governance_admin);
            self._set_role_admin(role: SECURITY_ADMIN, admin_role: SECURITY_ADMIN);
            self._set_role_admin(role: SECURITY_AGENT, admin_role: SECURITY_ADMIN);
        }

        fn only_app_governor(self: @ContractState) {
            assert(self.is_app_governor(get_caller_address()), ONLY_APP_GOVERNOR);
        }
        fn only_operator(self: @ContractState) {
            assert(self.is_operator(get_caller_address()), ONLY_OPERATOR);
        }
        fn only_token_admin(self: @ContractState) {
            assert(self.is_token_admin(get_caller_address()), ONLY_TOKEN_ADMIN);
        }
        fn only_upgrade_governor(self: @ContractState) {
            assert(self.is_upgrade_governor(get_caller_address()), ONLY_UPGRADE_GOVERNOR);
        }

        fn only_security_admin(self: @ContractState) {
            assert(self.is_security_admin(get_caller_address()), ONLY_SECURITY_ADMIN);
        }

        fn only_security_agent(self: @ContractState) {
            assert(self.is_security_agent(get_caller_address()), ONLY_SECURITY_AGENT);
        }
   }
}
