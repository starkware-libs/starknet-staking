use starknet::{ContractAddress};
use contracts::staking::interface;
use contracts::staking::Events as StakingEvents;
use contracts::pooling::Events as PoolEvents;
use snforge_std::cheatcodes::events::{Event, Events, EventSpy, EventSpyTrait, is_emitted};

pub fn assert_number_of_events(actual: u32, expected: u32, message: ByteArray) {
    assert_eq!(
        actual, expected, "{actual} events were emitted instead of {expected}. Context: {message}"
    );
}

pub fn panic_with_event_details(expected_emitted_by: @ContractAddress, details: ByteArray) {
    let start = format!("Could not match expected event from address {:?}", *expected_emitted_by);
    panic!("{}: {}", start, details);
}

pub fn assert_staker_exit_intent_event(
    spied_event: @(ContractAddress, Event), staker_address: ContractAddress, exit_at: u64,
) {
    let expected_event = @contracts::staking::Staking::Event::StakerExitIntent(
        StakingEvents::StakerExitIntent { staker_address, exit_at }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakerExitIntent{{staker_address: {:?}, exit_at: {}}}", staker_address, exit_at
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_staker_balance_changed_event(
    spied_event: @(ContractAddress, Event), staker_address: ContractAddress, amount: u128,
) {
    let expected_event = @contracts::staking::Staking::Event::BalanceChanged(
        StakingEvents::BalanceChanged { staker_address, amount }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "StakingEvents::BalanceChanged{{staker_address: {:?}, amount: {}}}",
            staker_address,
            amount
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_member_exit_intent_event(
    spied_event: @(ContractAddress, Event), pool_member: ContractAddress, exit_at: u64,
) {
    let expected_event = @contracts::pooling::Pooling::Event::PoolMemberExitIntent(
        PoolEvents::PoolMemberExitIntent { pool_member, exit_at }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolMemberExitIntent{{pool_member: {:?}, exit_at: {}}}", pool_member, exit_at
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn assert_pool_balance_changed_event(
    mut spied_event: @(ContractAddress, Event), pool_member: ContractAddress, amount: u128,
) {
    let expected_event = @contracts::pooling::Pooling::Event::BalanceChanged(
        PoolEvents::BalanceChanged { pool_member, amount }
    );
    let (expected_emitted_by, raw_event) = spied_event;
    let wrapped_spied_event = Events { events: array![(*expected_emitted_by, raw_event.clone())] };
    let emitted = is_emitted(self: @wrapped_spied_event, :expected_emitted_by, :expected_event);
    if !emitted {
        let details = format!(
            "PoolEvents::BalanceChanged{{pool_member: {:?}, amount: {}}}", pool_member, amount
        );
        panic_with_event_details(:expected_emitted_by, :details);
    }
}

pub fn debug_dump_spied_events(ref spy: EventSpy) {
    let mut serialized = array![];
    Serde::<
        Array<(starknet::ContractAddress, snforge_std::Event)>
    >::serialize(@(spy.get_events().events), ref serialized);
    println!("{:?}", serialized);
    println!("[#events, (emitterAddress, #keys, keys..., #values, values...)...]");
}
