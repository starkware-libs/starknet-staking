use contracts::errors::{Error, OptionAuxTrait};
use core::array::ArrayTrait;
use contracts::test_utils::{StakingInitConfig, general_contract_system_deployment};
use contracts::event_test_utils::assert_number_of_events;
use contracts::message_to_l1_test_utils::assert_number_of_messages_to_l1;
use snforge_std::cheatcodes::events::EventSpyTrait;
use snforge_std::cheatcodes::message_to_l1::MessageToL1SpyTrait;
use starknet::get_block_timestamp;
use contracts::staking::interface::{IStakingDispatcherTrait, IStakingDispatcher};

use contracts::constants::{SECONDS_IN_DAY, STRK_IN_FRIS};
use contracts::test_utils::constants::BASE_MINT_AMOUNT;
use contracts::utils::{ceil_of_division, compute_threshold};

#[test]
fn test_l2_initialization_flow() {
    // The default StakingInitConfig also declares the pooling contract.
    let mut cfg: StakingInitConfig = Default::default();
    // Deploy a system, set the resulted addresses in cfg.
    general_contract_system_deployment(ref cfg);

    // TODO: Should we also check the deployments events?
    let mut spy_events = snforge_std::spy_events();
    // TODO: Should we also look for messages_to_l1 initiated in the deployment?
    let mut spy_messages_to_l1 = snforge_std::spy_messages_to_l1();

    // Keep the initial global_index for result validation.
    let initial_global_index = IStakingDispatcher {
        contract_address: cfg.test_info.staking_contract
    }
        .contract_parameters()
        .global_index;

    // Waits 5 days (+ epsilon).
    let mut block_timestamp = get_block_timestamp();
    block_timestamp += 5 * SECONDS_IN_DAY + 360;
    snforge_std::start_cheat_block_timestamp_global(:block_timestamp);

    // Update global index, using the operator.
    IStakingDispatcher { contract_address: cfg.test_info.operator_contract }
        .update_global_index_if_needed();

    // For several additional days calls update_global_index_if_needed once a day (+- epsilon).
    let waits = @array![
        SECONDS_IN_DAY + 300,
        SECONDS_IN_DAY + 20,
        SECONDS_IN_DAY + 200,
        SECONDS_IN_DAY - 50,
        SECONDS_IN_DAY
    ];
    for i in 0
        ..waits
            .len() {
                block_timestamp += *waits.at(i);
                snforge_std::start_cheat_block_timestamp_global(:block_timestamp);
                // Update global index, using the operator.
                IStakingDispatcher { contract_address: cfg.test_info.operator_contract }
                    .update_global_index_if_needed();
            };

    // Read the final global_index for result validation.
    let final_global_index = IStakingDispatcher { contract_address: cfg.test_info.staking_contract }
        .contract_parameters()
        .global_index;

    // Because there was no staking, global index should not be changed.
    assert_eq!(final_global_index, initial_global_index);

    // Asserts number of emitted events:
    // * 1 initial MintRequest from RewardSupplier.
    // * For each of the 3 actual update_global_index 2 events:
    //   * CalculatedRewards from RewardSupplier.
    //   * GlobalIndexUpdated from Staking.
    // Total 1 + 3 * 2 = 7.
    // This should be changed if the deployment events are included..
    // This should be changed if the "if_needed" logic is changed.
    let events = spy_events.get_events().events;
    assert_number_of_events(actual: events.len(), expected: 7, message: "l2 initialization");

    // Asserts number of sent messages to l1.
    // 1 STRK for rounding up + additional threshold.
    let number_of_expected_minting_messages: u32 = ceil_of_division(
        dividend: STRK_IN_FRIS + compute_threshold(BASE_MINT_AMOUNT), divisor: BASE_MINT_AMOUNT
    )
        .try_into()
        .expect_with_err(Error::MESSAGES_COUNT_ISNT_U32);
    let messages_to_l1 = spy_messages_to_l1.get_messages().messages;
    assert_number_of_messages_to_l1(
        actual: messages_to_l1.len(),
        expected: number_of_expected_minting_messages,
        message: "l2 initialization"
    );
}
