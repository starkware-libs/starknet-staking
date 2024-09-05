#[starknet::component]
pub mod RolesComponent {
    use core::num::traits::Zero;
    use contracts_commons::components::roles::interface as RolesInterface;
    use RolesInterface::{RoleId, IRoles, APP_GOVERNOR, APP_ROLE_ADMIN, GOVERNANCE_ADMIN, OPERATOR};
    use RolesInterface::{SECURITY_ADMIN, SECURITY_AGENT, TOKEN_ADMIN, UPGRADE_GOVERNOR};
    use RolesInterface::{AppGovernorAdded, AppGovernorRemoved, AppRoleAdminAdded};
    use RolesInterface::{AppRoleAdminRemoved, GovernanceAdminAdded, GovernanceAdminRemoved};
    use RolesInterface::{OperatorAdded, OperatorRemoved, SecurityAdminAdded, SecurityAdminRemoved};
    use RolesInterface::{SecurityAgentAdded, SecurityAgentRemoved, TokenAdminAdded};
    use RolesInterface::{TokenAdminRemoved, UpgradeGovernorAdded, UpgradeGovernorRemoved};
    use starknet::{ContractAddress, get_caller_address};
    use contracts_commons::errors::AccessErrors;
    use AccessErrors::{GOV_ADMIN_CANNOT_RENOUNCE, ZERO_ADDRESS, ALREADY_INITIALIZED};
    use AccessErrors::{ONLY_APP_GOVERNOR, ONLY_OPERATOR, ONLY_TOKEN_ADMIN};
    use AccessErrors::{ONLY_UPGRADE_GOVERNOR, ONLY_SECURITY_ADMIN, ONLY_SECURITY_AGENT};

    #[storage]
    struct Storage {}

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

    use openzeppelin::access::accesscontrol::interface::IAccessControl;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::AccessControlComponent::AccessControlImpl;
    use openzeppelin::access::accesscontrol::AccessControlComponent::InternalTrait as AccessInternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;

    #[embeddable_as(RolesImpl)]
    pub impl Roles<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Access: AccessControlComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>
    > of IRoles<ComponentState<TContractState>> {
        fn is_app_governor(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> bool {
            get_dep_component!(self, Access).has_role(role: APP_GOVERNOR, :account)
        }

        fn is_app_role_admin(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> bool {
            let access_comp = get_dep_component!(self, Access);
            access_comp.has_role(role: APP_ROLE_ADMIN, :account)
        }

        fn is_governance_admin(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> bool {
            let access_comp = get_dep_component!(self, Access);
            access_comp.has_role(role: GOVERNANCE_ADMIN, :account)
        }

        fn is_operator(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            let access_comp = get_dep_component!(self, Access);
            access_comp.has_role(role: OPERATOR, :account)
        }

        fn is_security_admin(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> bool {
            let access_comp = get_dep_component!(self, Access);
            access_comp.has_role(role: SECURITY_ADMIN, :account)
        }

        fn is_security_agent(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> bool {
            let access_comp = get_dep_component!(self, Access);
            access_comp.has_role(role: SECURITY_AGENT, :account)
        }

        fn is_token_admin(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            let access_comp = get_dep_component!(self, Access);
            access_comp.has_role(role: TOKEN_ADMIN, :account)
        }

        fn is_upgrade_governor(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> bool {
            let access_comp = get_dep_component!(self, Access);
            access_comp.has_role(role: UPGRADE_GOVERNOR, :account)
        }

        fn register_app_governor(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::AppGovernorAdded(
                AppGovernorAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: APP_GOVERNOR, :account, :event);
        }

        fn remove_app_governor(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let event = Event::AppGovernorRemoved(
                AppGovernorRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: APP_GOVERNOR, :account, :event);
        }

        fn register_app_role_admin(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::AppRoleAdminAdded(
                AppRoleAdminAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: APP_ROLE_ADMIN, :account, :event);
        }

        fn remove_app_role_admin(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::AppRoleAdminRemoved(
                AppRoleAdminRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: APP_ROLE_ADMIN, :account, :event);
        }

        fn register_security_admin(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::SecurityAdminAdded(
                SecurityAdminAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: SECURITY_ADMIN, :account, :event);
        }

        fn remove_security_admin(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::SecurityAdminRemoved(
                SecurityAdminRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: SECURITY_ADMIN, :account, :event);
        }

        fn register_security_agent(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::SecurityAgentAdded(
                SecurityAgentAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: SECURITY_AGENT, :account, :event);
        }

        fn remove_security_agent(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::SecurityAgentRemoved(
                SecurityAgentRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: SECURITY_AGENT, :account, :event);
        }


        fn register_governance_admin(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::GovernanceAdminAdded(
                GovernanceAdminAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: GOVERNANCE_ADMIN, :account, :event);
        }

        fn remove_governance_admin(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::GovernanceAdminRemoved(
                GovernanceAdminRemoved {
                    removed_account: account, removed_by: get_caller_address()
                }
            );
            self._revoke_role_and_emit(role: GOVERNANCE_ADMIN, :account, :event);
        }

        fn register_operator(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let event = Event::OperatorAdded(
                OperatorAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: OPERATOR, :account, :event);
        }

        fn remove_operator(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let event = Event::OperatorRemoved(
                OperatorRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: OPERATOR, :account, :event);
        }

        fn register_token_admin(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::TokenAdminAdded(
                TokenAdminAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: TOKEN_ADMIN, :account, :event);
        }

        fn remove_token_admin(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let event = Event::TokenAdminRemoved(
                TokenAdminRemoved { removed_account: account, removed_by: get_caller_address() }
            );
            self._revoke_role_and_emit(role: TOKEN_ADMIN, :account, :event);
        }

        fn register_upgrade_governor(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            let event = Event::UpgradeGovernorAdded(
                UpgradeGovernorAdded { added_account: account, added_by: get_caller_address() }
            );
            self._grant_role_and_emit(role: UPGRADE_GOVERNOR, :account, :event);
        }

        fn remove_upgrade_governor(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
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
        fn renounce(ref self: ComponentState<TContractState>, role: RoleId) {
            assert(role != GOVERNANCE_ADMIN, GOV_ADMIN_CANNOT_RENOUNCE);
            let mut access_comp = get_dep_component_mut!(ref self, Access);
            access_comp.renounce_role(:role, account: get_caller_address())
            // TODO add another event? Currently there are two events when a role is removed but
        // only one if it was renounced.
        }
    }


    #[generate_trait]
    pub impl RolesInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Access: AccessControlComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        // TODO -  change the fn name to _grant_role when we can have modularity.
        fn _grant_role_and_emit(
            ref self: ComponentState<TContractState>,
            role: RoleId,
            account: ContractAddress,
            event: Event
        ) {
            let mut access_comp = get_dep_component_mut!(ref self, Access);
            if !access_comp.has_role(:role, :account) {
                assert(account.is_non_zero(), ZERO_ADDRESS);
                access_comp.grant_role(:role, :account);
                self.emit(event);
            }
        }

        // TODO -  change the fn name to _revoke_role when we can have modularity.
        fn _revoke_role_and_emit(
            ref self: ComponentState<TContractState>,
            role: RoleId,
            account: ContractAddress,
            event: Event
        ) {
            let mut access_comp = get_dep_component_mut!(ref self, Access);
            if access_comp.has_role(:role, :account) {
                access_comp.revoke_role(:role, :account);
                self.emit(event);
            }
        }

        // WARNING
        // The following internal method is unprotected and should only be used from the containing
        // contract's constructor (or, in context of tests, from the setup method).
        // It should be called after the initialization of the access_control component.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut access_comp = get_dep_component_mut!(ref self, Access);
            let governance_admin = get_caller_address();
            let un_initialized = access_comp.get_role_admin(role: GOVERNANCE_ADMIN).is_zero();
            assert(un_initialized, ALREADY_INITIALIZED);
            access_comp._grant_role(role: GOVERNANCE_ADMIN, account: governance_admin);
            access_comp.set_role_admin(role: APP_GOVERNOR, admin_role: APP_ROLE_ADMIN);
            access_comp.set_role_admin(role: APP_ROLE_ADMIN, admin_role: GOVERNANCE_ADMIN);
            access_comp.set_role_admin(role: GOVERNANCE_ADMIN, admin_role: GOVERNANCE_ADMIN);
            access_comp.set_role_admin(role: OPERATOR, admin_role: APP_ROLE_ADMIN);
            access_comp.set_role_admin(role: TOKEN_ADMIN, admin_role: APP_ROLE_ADMIN);
            access_comp.set_role_admin(role: UPGRADE_GOVERNOR, admin_role: GOVERNANCE_ADMIN);

            access_comp._grant_role(role: SECURITY_ADMIN, account: governance_admin);
            access_comp.set_role_admin(role: SECURITY_ADMIN, admin_role: SECURITY_ADMIN);
            access_comp.set_role_admin(role: SECURITY_AGENT, admin_role: SECURITY_ADMIN);
        }

        fn only_app_governor(self: @ComponentState<TContractState>) {
            assert(self.is_app_governor(get_caller_address()), ONLY_APP_GOVERNOR);
        }
        fn only_operator(self: @ComponentState<TContractState>) {
            assert(self.is_operator(get_caller_address()), ONLY_OPERATOR);
        }
        fn only_token_admin(self: @ComponentState<TContractState>) {
            assert(self.is_token_admin(get_caller_address()), ONLY_TOKEN_ADMIN);
        }
        fn only_upgrade_governor(self: @ComponentState<TContractState>) {
            assert(self.is_upgrade_governor(get_caller_address()), ONLY_UPGRADE_GOVERNOR);
        }

        fn only_security_admin(self: @ComponentState<TContractState>) {
            assert(self.is_security_admin(get_caller_address()), ONLY_SECURITY_ADMIN);
        }

        fn only_security_agent(self: @ComponentState<TContractState>) {
            assert(self.is_security_agent(get_caller_address()), ONLY_SECURITY_AGENT);
        }
    }
}
