use core::num::traits::Zero;
use staking_test::pool::pool_member_balance_trace::mock::{IMockTrace, MockTrace};
use staking_test::pool::pool_member_balance_trace::trace::{
    PoolMemberBalanceTrait, PoolMemberCheckpointTrait,
};

fn CONTRACT_STATE() -> MockTrace::ContractState {
    MockTrace::contract_state_for_testing()
}

#[test]
fn test_insert() {
    let mut mock_trace = CONTRACT_STATE();

    let (prev, new) = mock_trace
        .insert(
            key: 100,
            value: PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1),
        );
    assert!(prev == Zero::zero());
    assert!(new == PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));

    let (prev, new) = mock_trace
        .insert(
            key: 200,
            value: PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2),
        );
    assert!(prev == PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    assert!(new == PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));
    assert!(mock_trace.length() == 2);

    let (prev, new) = mock_trace
        .insert(
            key: 200,
            value: PoolMemberBalanceTrait::new(balance: 500, cumulative_rewards_trace_idx: 5),
        );
    assert!(prev == PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));
    assert!(new == PoolMemberBalanceTrait::new(balance: 500, cumulative_rewards_trace_idx: 5));
    assert!(mock_trace.length() == 2);
}

#[test]
#[should_panic(expected: "Unordered insertion")]
fn test_insert_unordered_insertion() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace
        .insert(200, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    mock_trace
        .insert(
            100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1),
        ); // This should panic
}

#[test]
#[should_panic(expected: "Empty trace")]
fn test_latest_empty_trace() {
    let mut mock_trace = CONTRACT_STATE();

    let _ = mock_trace.latest();
}

#[test]
fn test_latest() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace
        .insert(100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    mock_trace
        .insert(200, PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));

    let (key, value) = mock_trace.latest();
    assert!(key == 200);
    assert!(value == PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));
}

#[test]
fn test_penultimate() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace
        .insert(100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    mock_trace
        .insert(200, PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));

    let (key, value) = mock_trace.penultimate();
    assert!(key == 100);
    assert!(value == PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
}

#[test]
#[should_panic(expected: "Penultimate does not exist")]
fn test_penultimate_not_exist() {
    let mut mock_trace = CONTRACT_STATE();

    let _ = mock_trace.penultimate();
}

#[test]
fn test_length() {
    let mut mock_trace = CONTRACT_STATE();

    assert!(mock_trace.length() == 0);

    mock_trace
        .insert(100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    assert!(mock_trace.length() == 1);

    mock_trace
        .insert(200, PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));
    assert!(mock_trace.length() == 2);
}

#[test]
fn test_latest_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace
        .insert(100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    mock_trace
        .insert(200, PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));

    let (key, value) = mock_trace.latest();
    assert!(key == 200);
    assert!(value == PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));
}

#[test]
fn test_length_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    assert!(mock_trace.length_mutable() == 0);

    mock_trace
        .insert(100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    assert!(mock_trace.length_mutable() == 1);

    mock_trace
        .insert(200, PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));
    assert!(mock_trace.length_mutable() == 2);
}

#[test]
fn test_balance() {
    let trace = PoolMemberBalanceTrait::new(balance: 5, cumulative_rewards_trace_idx: 10);
    assert!(trace.balance() == 5);
}

#[test]
fn test_cumulative_rewards_trace_idx() {
    let trace = PoolMemberBalanceTrait::new(balance: 5, cumulative_rewards_trace_idx: 10);
    assert!(trace.cumulative_rewards_trace_idx() == 10);
}

#[test]
fn test_is_non_empty() {
    let mut mock_trace = CONTRACT_STATE();
    assert!(!mock_trace.is_non_empty());

    mock_trace
        .insert(100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    assert!(mock_trace.is_non_empty());
}

fn test_is_non_empty_mutable() {
    let mut mock_trace = CONTRACT_STATE();
    assert_eq!(mock_trace.is_non_empty(), false);

    mock_trace
        .insert(100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    assert_eq!(mock_trace.is_non_empty(), true);
}

#[test]
fn test_at() {
    let mut mock_trace = CONTRACT_STATE();
    mock_trace
        .insert(100, PoolMemberBalanceTrait::new(balance: 1000, cumulative_rewards_trace_idx: 1));
    mock_trace
        .insert(200, PoolMemberBalanceTrait::new(balance: 2000, cumulative_rewards_trace_idx: 2));

    let pool_member_checkpoint = mock_trace.at(0);
    assert!(pool_member_checkpoint.epoch() == 100);
    assert!(pool_member_checkpoint.balance() == 1000);
    assert!(pool_member_checkpoint.cumulative_rewards_trace_idx() == 1);

    let pool_member_checkpoint = mock_trace.at(1);
    assert!(pool_member_checkpoint.epoch() == 200);
    assert!(pool_member_checkpoint.balance() == 2000);
    assert!(pool_member_checkpoint.cumulative_rewards_trace_idx() == 2);
}

#[test]
#[should_panic(expected: "Index out of bounds")]
fn test_at_out_of_bounds() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.at(0);
}

#[test]
fn test_pool_member_checkpoint_getters() {
    let trace = PoolMemberCheckpointTrait::new(
        epoch: 100, balance: 5, cumulative_rewards_trace_idx: 10,
    );
    assert!(trace.epoch() == 100);
    assert!(trace.balance() == 5);
    assert!(trace.cumulative_rewards_trace_idx() == 10);
}
