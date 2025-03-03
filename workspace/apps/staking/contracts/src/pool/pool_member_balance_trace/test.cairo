use core::num::traits::Zero;
use staking::pool::pool_member_balance_trace::mock::{IMockTrace, MockTrace};
use staking::pool::pool_member_balance_trace::trace::{PoolMemberBalanceTrait};

fn CONTRACT_STATE() -> MockTrace::ContractState {
    MockTrace::contract_state_for_testing()
}

#[test]
fn test_insert() {
    let mut mock_trace = CONTRACT_STATE();

    let (prev, new) = mock_trace
        .insert(key: 100, value: PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));
    assert_eq!(prev, Zero::zero());
    assert_eq!(new, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));

    let (prev, new) = mock_trace
        .insert(key: 200, value: PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));
    assert_eq!(prev, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));
    assert_eq!(new, PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));
    assert_eq!(mock_trace.length(), 2);

    let (prev, new) = mock_trace
        .insert(key: 200, value: PoolMemberBalanceTrait::new(balance: 500, rewards_info_idx: 5));
    assert_eq!(prev, PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));
    assert_eq!(new, PoolMemberBalanceTrait::new(balance: 500, rewards_info_idx: 5));
    assert_eq!(mock_trace.length(), 2);
}

#[test]
#[should_panic(expected: "Unordered insertion")]
fn test_insert_unordered_insertion() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(200, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));
    mock_trace
        .insert(
            100, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1),
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

    mock_trace.insert(100, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));
    mock_trace.insert(200, PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));

    let (key, value) = mock_trace.latest();
    assert_eq!(key, 200);
    assert_eq!(value, PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));
}

#[test]
fn test_length() {
    let mut mock_trace = CONTRACT_STATE();

    assert_eq!(mock_trace.length(), 0);

    mock_trace.insert(100, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));
    assert_eq!(mock_trace.length(), 1);

    mock_trace.insert(200, PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));
    assert_eq!(mock_trace.length(), 2);
}

#[test]
fn test_upper_lookup() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(100, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));
    mock_trace.insert(200, PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));

    assert_eq!(
        mock_trace.upper_lookup(100),
        PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1),
    );
    assert_eq!(
        mock_trace.upper_lookup(150),
        PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1),
    );
    assert_eq!(
        mock_trace.upper_lookup(200),
        PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2),
    );
    assert_eq!(
        mock_trace.upper_lookup(250),
        PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2),
    );
}

#[test]
fn test_latest_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(100, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));
    mock_trace.insert(200, PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));

    let latest = mock_trace.latest_mutable();
    assert_eq!(latest, PoolMemberBalanceTrait::new(balance: 2000, rewards_info_idx: 2));
}

#[test]
fn test_balance() {
    let trace = PoolMemberBalanceTrait::new(balance: 5, rewards_info_idx: 10);
    assert_eq!(trace.balance(), 5);
}

#[test]
fn test_rewards_info_idx() {
    let trace = PoolMemberBalanceTrait::new(balance: 5, rewards_info_idx: 10);
    assert_eq!(trace.rewards_info_idx(), 10);
}

#[test]
fn test_is_initialized() {
    let mut mock_trace = CONTRACT_STATE();
    assert_eq!(mock_trace.is_initialized(), false);

    mock_trace.insert(100, PoolMemberBalanceTrait::new(balance: 1000, rewards_info_idx: 1));
    assert_eq!(mock_trace.is_initialized(), true);
}

