mod ReplaceabilityTests {
    use contracts_commons::components::replaceability::interface::IReplaceableDispatcher;
    use contracts_commons::components::replaceability::interface::IReplaceableDispatcherTrait;
    use contracts_commons::components::replaceability::interface::ImplementationData;
    use contracts_commons::components::replaceability::interface::ImplementationAdded;
    use contracts_commons::components::replaceability::ReplaceabilityComponent;
    use contracts_commons::components::replaceability::mock::ReplaceabilityMock;
    use contracts_commons::components::replaceability::test_utils::deploy_replaceability_mock;
    use contracts_commons::components::replaceability::test_utils::get_upgrade_governor_account;
    use contracts_commons::components::replaceability::test_utils::Constants::DEFAULT_UPGRADE_DELAY;
    use contracts_commons::components::replaceability::test_utils::Constants::DUMMY_NONFINAL_IMPLEMENTATION_DATA;
    use contracts_commons::components::replaceability::test_utils::Constants::NOT_UPGRADE_GOVERNOR_ACCOUNT;
    use contracts_commons::components::replaceability::test_utils::Errors::INCORRECT_ACTIVATION_TIME_ERROR;
    use contracts_commons::components::replaceability::test_utils::Errors::UPGRADE_DELAY_ERROR;
    use snforge_std::{spy_events, EventSpyAssertionsTrait, cheat_caller_address, CheatSpan};

    #[test]
    fn test_get_upgrade_delay() {
        let replaceable_dispatcher = deploy_replaceability_mock();
        assert(
            replaceable_dispatcher.get_upgrade_delay() == DEFAULT_UPGRADE_DELAY, UPGRADE_DELAY_ERROR
        );
    }

    #[test]
    fn test_add_new_implementation() {
        let replaceable_dispatcher = deploy_replaceability_mock();
        let contract_address = replaceable_dispatcher.contract_address;
        let implementation_data = DUMMY_NONFINAL_IMPLEMENTATION_DATA();

        // Check implementation time pre addition.
        assert(
            replaceable_dispatcher.get_impl_activation_time(:implementation_data) == 0,
            INCORRECT_ACTIVATION_TIME_ERROR
        );
        cheat_caller_address(
            contract_address,
            get_upgrade_governor_account(:contract_address),
            CheatSpan::TargetCalls(1)
        );
        let mut spy = spy_events();
        replaceable_dispatcher.add_new_implementation(:implementation_data);

        assert(
            replaceable_dispatcher
                .get_impl_activation_time(:implementation_data) == DEFAULT_UPGRADE_DELAY,
            INCORRECT_ACTIVATION_TIME_ERROR
        );

        // Validate event emission.
        spy
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        ReplaceabilityMock::Event::ReplaceabilityEvent(
                            ReplaceabilityComponent::Event::ImplementationAdded(
                                ImplementationAdded { implementation_data: implementation_data }
                            )
                        )
                    )
                ]
            );
    }

    #[test]
    #[should_panic(expected: ('ONLY_UPGRADE_GOVERNOR',))]
    fn test_add_new_implementation_not_upgrade_governor() {
        let replaceable_dispatcher = deploy_replaceability_mock();
        let contract_address = replaceable_dispatcher.contract_address;
        let implementation_data = DUMMY_NONFINAL_IMPLEMENTATION_DATA();

        // Invoke not as an Upgrade Governor.
        cheat_caller_address(
            contract_address, NOT_UPGRADE_GOVERNOR_ACCOUNT(), CheatSpan::TargetCalls(1)
        );
        replaceable_dispatcher.add_new_implementation(:implementation_data);
    }
}
