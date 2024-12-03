use contracts::minting_curve::interface::ConfigEvents as MintingCurveConfigEvents;
use contracts::minting_curve::minting_curve::MintingCurve;
use contracts::pool::interface::Events as PoolEvents;
use contracts::pool::pool::Pool;
use contracts::reward_supplier::interface::Events as RewardSupplierEvents;
use contracts::reward_supplier::reward_supplier::RewardSupplier;
use contracts::staking::interface::ConfigEvents as StakingConfigEvents;
use contracts::staking::interface::Events as StakingEvents;
use contracts::staking::interface::PauseEvents as StakingPauseEvents;
use contracts::staking::staking::Staking;
use contracts::types::{Amount, Commission, Index, Inflation};
use contracts_commons::types::time::{TimeDelta, Timestamp};
use snforge_std::cheatcodes::events::{Event, EventSpy, EventSpyTrait, Events, is_emitted};
use starknet::ContractAddress;

pub fn assert_number_of_events(actual: u32, expected: u32, message: ByteArray) {
    assert_eq!(
        actual, expected, "{actual} events were emitted instead of {expected}. Context: {message}",
    );
}

pub fn panic_with_event_details(expected_emitted_by: @ContractAddress, details: ByteArray) {
    let start = format!("Could not match expected event from address {:?}", *expected_emitted_by);
    panic!("{}: {}", start, details);
}

pub fn assert_staker_exit_intent_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    exit_timestamp: Timestamp,
    amount: Amount,
) {
    let expected_event = @Staking::Event::StakerExitIntent(
        StakingEvents::StakerExitIntent { staker_address, exit_timestamp, amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakerExitIntent{{staker_address: {:?}, exit_timestamp: {}, amount: {}}}",
            staker_address,
            exit_timestamp.seconds,
            amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_new_staker_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    self_stake: Amount,
) {
    let expected_event = @Staking::Event::NewStaker(
        StakingEvents::NewStaker {
            staker_address, reward_address, operational_address, self_stake,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "NewStaker{{staker_address: {:?}, reward_address: {:?}, operational_address: {:?}, self_stake: {}}}",
            staker_address,
            reward_address,
            operational_address,
            self_stake,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_stake_balance_changed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    old_self_stake: Amount,
    old_delegated_stake: Amount,
    new_self_stake: Amount,
    new_delegated_stake: Amount,
) {
    let expected_event = @Staking::Event::StakeBalanceChanged(
        StakingEvents::StakeBalanceChanged {
            staker_address,
            old_self_stake,
            old_delegated_stake,
            new_self_stake,
            new_delegated_stake,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakingEvents::StakeBalanceChanged{{staker_address: {:?}, old_self_stake: {}, 
                old_delegated_stake: {}, new_self_stake: {}, new_delegated_stake: {}}}",
            staker_address,
            old_self_stake,
            old_delegated_stake,
            new_self_stake,
            new_delegated_stake,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_member_exit_intent_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    exit_timestamp: Timestamp,
    amount: Amount,
) {
    let expected_event = @Pool::Event::PoolMemberExitIntent(
        PoolEvents::PoolMemberExitIntent { pool_member, exit_timestamp, amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolMemberExitIntent{{pool_member: {:?}, exit_timestamp: {}, amount: {}}}",
            pool_member,
            exit_timestamp.seconds,
            amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_member_exit_action_event(
    spied_event: @(ContractAddress, Event), pool_member: ContractAddress, unpool_amount: Amount,
) {
    let expected_event = @Pool::Event::PoolMemberExitAction(
        PoolEvents::PoolMemberExitAction { pool_member, unpool_amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolMemberExitAction{{pool_member: {:?}, unpool_amount: {}}}",
            pool_member,
            unpool_amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_member_reward_claimed_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    reward_address: ContractAddress,
    amount: Amount,
) {
    let expected_event = @Pool::Event::PoolMemberRewardClaimed(
        PoolEvents::PoolMemberRewardClaimed { pool_member, reward_address, amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolMemberRewardClaimed{{pool_member: {:?}, reward_address: {:?}, amount: {}}}",
            pool_member,
            reward_address,
            amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_delegation_pool_member_balance_changed_event(
    mut spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    old_delegated_stake: Amount,
    new_delegated_stake: Amount,
) {
    let expected_event = @Pool::Event::PoolMemberBalanceChanged(
        PoolEvents::PoolMemberBalanceChanged {
            pool_member, old_delegated_stake, new_delegated_stake,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolEvents::PoolMemberBalanceChanged{{pool_member: {:?}, old_delegated_stake: {}, new_delegated_stake: {}}}",
            pool_member,
            old_delegated_stake,
            new_delegated_stake,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_staker_reward_address_change_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = @Staking::Event::StakerRewardAddressChanged(
        StakingEvents::StakerRewardAddressChanged { staker_address, new_address, old_address },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakerRewardAddressChanged{{staker_address: {:?}, new_address: {:?}, old_address: {:?}}}",
            staker_address,
            new_address,
            old_address,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_commission_changed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_contract: ContractAddress,
    new_commission: Commission,
    old_commission: Commission,
) {
    let expected_event = @Staking::Event::CommissionChanged(
        StakingEvents::CommissionChanged {
            staker_address, pool_contract, new_commission, old_commission,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "CommissionChanged{{staker_address: {:?}, pool_contract: {:?}, new_commission: {}, old_commission: {}}}",
            staker_address,
            pool_contract,
            new_commission,
            old_commission,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_global_index_updated_event(
    spied_event: @(ContractAddress, Event),
    old_index: Index,
    new_index: Index,
    global_index_last_update_timestamp: Timestamp,
    global_index_current_update_timestamp: Timestamp,
) {
    let expected_event = @Staking::Event::GlobalIndexUpdated(
        StakingEvents::GlobalIndexUpdated {
            old_index,
            new_index,
            global_index_last_update_timestamp,
            global_index_current_update_timestamp,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "GlobalIndexUpdated{{old_index: {}, new_index: {}, global_index_last_update_timestamp: {}, global_index_current_update_timestamp: {}}}",
            old_index,
            new_index,
            global_index_last_update_timestamp.seconds,
            global_index_current_update_timestamp.seconds,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_new_delegation_pool_event(
    mut spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_contract: ContractAddress,
    commission: Commission,
) {
    let expected_event = @Staking::Event::NewDelegationPool(
        StakingEvents::NewDelegationPool { staker_address, pool_contract, commission },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakingEvents::NewDelegationPool{{staker_address: {:?}, pool_contract: {:?}, commission: {}}}",
            staker_address,
            pool_contract,
            commission,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_remove_from_delegation_pool_intent_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_contract: ContractAddress,
    identifier: felt252,
    old_intent_amount: Amount,
    new_intent_amount: Amount,
) {
    let expected_event = @Staking::Event::RemoveFromDelegationPoolIntent(
        StakingEvents::RemoveFromDelegationPoolIntent {
            staker_address, pool_contract, identifier, old_intent_amount, new_intent_amount,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "RemoveFromDelegationPoolIntent{{staker_address: {:?}, pool_contract: {:?}, identifier: {}, old_intent_amount: {}, new_intent_amount: {}}}",
            staker_address,
            pool_contract,
            identifier,
            old_intent_amount,
            new_intent_amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_remove_from_delegation_pool_action_event(
    spied_event: @(ContractAddress, Event),
    pool_contract: ContractAddress,
    identifier: felt252,
    amount: Amount,
) {
    let expected_event = @Staking::Event::RemoveFromDelegationPoolAction(
        StakingEvents::RemoveFromDelegationPoolAction { pool_contract, identifier, amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "RemoveFromDelegationPoolAction{{pool_contract: {:?}, identifier: {}, amount: {}}}",
            pool_contract,
            identifier,
            amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_member_reward_address_change_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = @Pool::Event::PoolMemberRewardAddressChanged(
        PoolEvents::PoolMemberRewardAddressChanged { pool_member, new_address, old_address },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolMemberRewardAddressChanged{{pool_member: {:?}, new_address: {:?}, old_address: {:?}}}",
            pool_member,
            new_address,
            old_address,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_staker_reward_claimed_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    amount: Amount,
) {
    let expected_event = @Staking::Event::StakerRewardClaimed(
        StakingEvents::StakerRewardClaimed { staker_address, reward_address, amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakerRewardClaimed{{staker_address: {:?}, reward_address: {:?}, amount: {}}}",
            staker_address,
            reward_address,
            amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_declare_operational_address_event(
    spied_event: @(ContractAddress, Event),
    operational_address: ContractAddress,
    staker_address: ContractAddress,
) {
    let expected_event = @Staking::Event::OperationalAddressDeclared(
        StakingEvents::OperationalAddressDeclared { operational_address, staker_address },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "OperationalAddressDeclared{{operational_address: {:?}, staker_address: {:?}}}",
            operational_address,
            staker_address,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_change_operational_address_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    new_address: ContractAddress,
    old_address: ContractAddress,
) {
    let expected_event = @Staking::Event::OperationalAddressChanged(
        StakingEvents::OperationalAddressChanged { staker_address, new_address, old_address },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "OperationalAddressChanged{{staker_address: {:?}, new_address: {:?}, old_address: {:?}}}",
            staker_address,
            new_address,
            old_address,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_final_index_set_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    final_staker_index: Index,
) {
    let expected_event = @Pool::Event::FinalIndexSet(
        PoolEvents::FinalIndexSet { staker_address, final_staker_index },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "FinalIndexSet{{staker_address: {:?}, final_staker_index: {}}}",
            staker_address,
            final_staker_index,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_calculated_rewards_event(
    spied_event: @(ContractAddress, Event),
    last_timestamp: Timestamp,
    new_timestamp: Timestamp,
    rewards_calculated: Amount,
) {
    let expected_event = @RewardSupplier::Event::CalculatedRewards(
        RewardSupplierEvents::CalculatedRewards {
            last_timestamp, new_timestamp, rewards_calculated,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "CalculatedRewards{{last_timestamp: {}, new_timestamp: {}, rewards_calculated: {}}}",
            last_timestamp.seconds,
            new_timestamp.seconds,
            rewards_calculated,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_mint_request_event(
    spied_event: @(ContractAddress, Event), total_amount: Amount, num_msgs: u128,
) {
    let expected_event = @RewardSupplier::Event::mintRequest(
        RewardSupplierEvents::MintRequest { total_amount, num_msgs },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "MintRequest{{total_amount: {:?}, num_msgs: {}}}", total_amount, num_msgs,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_delete_staker_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    operational_address: ContractAddress,
    pool_contract: Option<ContractAddress>,
) {
    let expected_event = @Staking::Event::DeleteStaker(
        StakingEvents::DeleteStaker {
            staker_address, reward_address, operational_address, pool_contract,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "DeleteStaker{{staker_address: {:?}, reward_address: {:?}, operational_address: {:?}, pool_contract: {:?}}}",
            staker_address,
            reward_address,
            operational_address,
            pool_contract,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_delete_pool_member_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    reward_address: ContractAddress,
) {
    let expected_event = @Pool::Event::DeletePoolMember(
        PoolEvents::DeletePoolMember { pool_member, reward_address },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "DeletePoolMember{{pool_member: {:?}, reward_address: {:?}}}",
            pool_member,
            reward_address,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_switch_delegation_pool_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    new_delegation_pool: ContractAddress,
    amount: Amount,
) {
    let expected_event = @Pool::Event::SwitchDelegationPool(
        PoolEvents::SwitchDelegationPool { pool_member, new_delegation_pool, amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "SwitchDelegationPool{{pool_member: {:?}, new_delegation_pool: {:?}, amount: {}}}",
            pool_member,
            new_delegation_pool,
            amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_change_delegation_pool_intent_event(
    spied_event: @(ContractAddress, Event),
    pool_contract: ContractAddress,
    identifier: felt252,
    old_intent_amount: Amount,
    new_intent_amount: Amount,
) {
    let expected_event = @Staking::Event::ChangeDelegationPoolIntent(
        StakingEvents::ChangeDelegationPoolIntent {
            pool_contract, identifier, old_intent_amount, new_intent_amount,
        },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "ChangeDelegationPoolIntent{{pool_contract: {:?}, identifier: {}, old_intent_amount: {}, new_intent_amount: {}}}",
            pool_contract,
            identifier,
            old_intent_amount,
            new_intent_amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub(crate) fn assert_new_pool_member_event(
    spied_event: @(ContractAddress, Event),
    pool_member: ContractAddress,
    staker_address: ContractAddress,
    reward_address: ContractAddress,
    amount: Amount,
) {
    let expected_event = @Pool::Event::NewPoolMember(
        PoolEvents::NewPoolMember { pool_member, staker_address, reward_address, amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "NewPoolMember{{pool_member: {:?}, staker_address: {:?}, reward_address: {:?}, amount: {}}}",
            pool_member,
            staker_address,
            reward_address,
            amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_rewards_supplied_to_delegation_pool_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    pool_address: ContractAddress,
    amount: Amount,
) {
    let expected_event = @Staking::Event::RewardsSuppliedToDelegationPool(
        StakingEvents::RewardsSuppliedToDelegationPool { staker_address, pool_address, amount },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "RewardsSuppliedToDelegationPool{{staker_address: {:?}, pool_address: {:?}, amount: {}}}",
            staker_address,
            pool_address,
            amount,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_paused_event(spied_event: @(ContractAddress, Event), account: ContractAddress) {
    let expected_event = @Staking::Event::Paused(StakingPauseEvents::Paused { account });
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!("Paused{{account: {:?}}}", account);
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_unpaused_event(spied_event: @(ContractAddress, Event), account: ContractAddress) {
    let expected_event = @Staking::Event::Unpaused(StakingPauseEvents::Unpaused { account });
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!("Unpaused{{account: {:?}}}", account);
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn debug_dump_spied_events(ref spy: EventSpy) {
    let mut serialized = array![];
    Serde::<
        Array<(starknet::ContractAddress, snforge_std::Event)>,
    >::serialize(@(spy.get_events().events), ref serialized);
    println!("{:?}", serialized);
    println!("[#events, (emitterAddress, #keys, keys..., #values, values...)...]");
}

pub fn assert_minting_cap_changed_event(
    spied_event: @(ContractAddress, Event), old_c: Inflation, new_c: Inflation,
) {
    let expected_event = @MintingCurve::Event::MintingCapChanged(
        MintingCurveConfigEvents::MintingCapChanged { old_c, new_c },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!("MintingCapChanged{{old_c: {:?}, new_c: {:?}}}", old_c, new_c);
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_minimum_stake_changed_event(
    spied_event: @(ContractAddress, Event), old_min_stake: Amount, new_min_stake: Amount,
) {
    let expected_event = @Staking::Event::MinimumStakeChanged(
        StakingConfigEvents::MinimumStakeChanged { old_min_stake, new_min_stake },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "MinimumStakeChanged{{old_min_stake: {:?}, new_min_stake: {:?}}}",
            old_min_stake,
            new_min_stake,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_exit_wait_window_changed_event(
    spied_event: @(ContractAddress, Event), old_exit_window: TimeDelta, new_exit_window: TimeDelta,
) {
    let expected_event = @Staking::Event::ExitWaitWindowChanged(
        StakingConfigEvents::ExitWaitWindowChanged { old_exit_window, new_exit_window },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "ExitWaitWindowChanged{{old_exit_window: {:?}, new_exit_window: {:?}}}",
            old_exit_window,
            new_exit_window,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_reward_supplier_changed_event(
    spied_event: @(ContractAddress, Event),
    old_reward_supplier: ContractAddress,
    new_reward_supplier: ContractAddress,
) {
    let expected_event = @Staking::Event::RewardSupplierChanged(
        StakingConfigEvents::RewardSupplierChanged { old_reward_supplier, new_reward_supplier },
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "RewardSupplierChanged{{old_reward_supplier: {:?}, new_reward_supplier: {:?}}}",
            old_reward_supplier,
            new_reward_supplier,
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}
