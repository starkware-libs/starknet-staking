pub mod ReplaceabilityTests {
    use contracts_commons::components::replaceability::interface::{
        IReplaceableDispatcher, IReplaceableDispatcherTrait
    };
    use contracts_commons::components::replaceability::test_utils::deploy_replaceability_mock;
    use contracts_commons::components::replaceability::test_utils::Constants::DEFAULT_UPGRADE_DELAY;
    use contracts_commons::components::replaceability::test_utils::Errors::UPGRADE_DELAY_ERROR;

    #[test]
    fn test_get_upgrade_delay() {
        let contract_address = deploy_replaceability_mock();
        let replaceable_dispatcher = IReplaceableDispatcher { contract_address };
        assert(
            replaceable_dispatcher.get_upgrade_delay() == DEFAULT_UPGRADE_DELAY, UPGRADE_DELAY_ERROR
        );
    }
}
