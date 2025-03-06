// An External Initializer Contract
// This EIC allows migrating between old ane new format of Roles storage.
// It sets critical role ownership in both format during the upgrade.
#[starknet::contract]
pub(crate) mod AssignRootGovernanceEIC {
    use RolesInterface::{APP_GOVERNOR, APP_ROLE_ADMIN, GOVERNANCE_ADMIN, OPERATOR, RoleId};
    use RolesInterface::{SECURITY_ADMIN, SECURITY_AGENT, TOKEN_ADMIN, UPGRADE_GOVERNOR};

    use starknet::storage::{Map, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use starkware_utils::components::replaceability::interface::IEICInitializable;
    use starkware_utils::components::roles::interface as RolesInterface;

    #[storage]
    pub struct Storage {
        role_admin: Map<RoleId, RoleId>, // Old - Pre-component compatible.
        role_members: Map<(RoleId, ContractAddress), bool>, // Old - Pre-component compatible.
        AccessControl_role_admin: Map<RoleId, RoleId>, // New - component compatible.
        AccessControl_role_member: Map<(RoleId, ContractAddress), bool> // New - comp. compatible.
    }

    #[abi(embed_v0)]
    impl EICInitializable of IEICInitializable<ContractState> {
        fn eic_initialize(ref self: ContractState, eic_init_data: Span<felt252>) {
            assert(eic_init_data.len() == 2, 'EXPECTED_DATA_LENGTH_2');
            let _assigned_gov_admin: ContractAddress = (*eic_init_data[0]).try_into().unwrap();
            let _assigned_sec_admin: ContractAddress = (*eic_init_data[1]).try_into().unwrap();
            let current_upg_gov = get_caller_address();
            self._grant_role(role: UPGRADE_GOVERNOR, account: current_upg_gov);
            self._grant_role_old(role: UPGRADE_GOVERNOR, account: current_upg_gov);

            self._grant_role(role: GOVERNANCE_ADMIN, account: _assigned_gov_admin);
            self._grant_role_old(role: GOVERNANCE_ADMIN, account: _assigned_gov_admin);

            self._grant_role(role: SECURITY_ADMIN, account: _assigned_sec_admin);
            self._grant_role_old(role: SECURITY_ADMIN, account: _assigned_sec_admin);

            self._initialize_role_heirarchy();
            self._initialize_role_heirarchy_old();
        }
    }

    #[generate_trait]
    impl internals of _internals {
        fn _initialize_role_heirarchy(ref self: ContractState) {
            self._set_role_admin(role: GOVERNANCE_ADMIN, admin_role: GOVERNANCE_ADMIN);
            self._set_role_admin(role: UPGRADE_GOVERNOR, admin_role: GOVERNANCE_ADMIN);
            self._set_role_admin(role: APP_ROLE_ADMIN, admin_role: GOVERNANCE_ADMIN);
            self._set_role_admin(role: APP_GOVERNOR, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin(role: OPERATOR, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin(role: TOKEN_ADMIN, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin(role: SECURITY_ADMIN, admin_role: SECURITY_ADMIN);
            self._set_role_admin(role: SECURITY_AGENT, admin_role: SECURITY_ADMIN);
        }

        fn _initialize_role_heirarchy_old(ref self: ContractState) {
            self._set_role_admin_old(role: GOVERNANCE_ADMIN, admin_role: GOVERNANCE_ADMIN);
            self._set_role_admin_old(role: UPGRADE_GOVERNOR, admin_role: GOVERNANCE_ADMIN);
            self._set_role_admin_old(role: APP_ROLE_ADMIN, admin_role: GOVERNANCE_ADMIN);
            self._set_role_admin_old(role: APP_GOVERNOR, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin_old(role: OPERATOR, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin_old(role: TOKEN_ADMIN, admin_role: APP_ROLE_ADMIN);
            self._set_role_admin_old(role: SECURITY_ADMIN, admin_role: SECURITY_ADMIN);
            self._set_role_admin_old(role: SECURITY_AGENT, admin_role: SECURITY_ADMIN);
        }

        fn _grant_role(ref self: ContractState, role: RoleId, account: ContractAddress) {
            self.AccessControl_role_member.write((role, account), true);
        }

        fn _grant_role_old(ref self: ContractState, role: RoleId, account: ContractAddress) {
            self.role_members.write((role, account), true);
        }

        fn _set_role_admin(ref self: ContractState, role: RoleId, admin_role: RoleId) {
            self.AccessControl_role_admin.write(role, admin_role);
        }

        fn _set_role_admin_old(ref self: ContractState, role: RoleId, admin_role: RoleId) {
            self.role_admin.write(role, admin_role);
        }
    }
}

