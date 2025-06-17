use staking::staking::staker_balance_trace::mock::{IMockTrace, MockTrace};
use staking::staking::staker_balance_trace::trace::StakerBalanceTrait;

fn CONTRACT_STATE() -> MockTrace::ContractState {
    MockTrace::contract_state_for_testing()
}

#[test]
fn test_insert() {
    let mut mock_trace = CONTRACT_STATE();

    let staker_balance = StakerBalanceTrait::new(amount_own: 1000);
    mock_trace.insert(key: 100, value: staker_balance);
    assert!(mock_trace.latest() == (100, staker_balance));
    assert!(mock_trace.length() == 1);

    let staker_balance = StakerBalanceTrait::new(amount_own: 2000);
    mock_trace.insert(key: 200, value: staker_balance);
    assert!(mock_trace.latest() == (200, staker_balance));
    assert!(mock_trace.length() == 2);

    let staker_balance = StakerBalanceTrait::new(amount_own: 500);
    mock_trace.insert(key: 200, value: staker_balance);
    assert!(mock_trace.latest() == (200, staker_balance));
    assert!(mock_trace.length() == 2);
}

#[test]
#[should_panic(expected: "Unordered insertion")]
fn test_insert_unordered_insertion() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(200, StakerBalanceTrait::new(amount_own: 200));
    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100)); // This should panic
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

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    mock_trace.insert(200, StakerBalanceTrait::new(amount_own: 200));

    let (key, value) = mock_trace.latest();
    assert!(key == 200);
    assert!(value == StakerBalanceTrait::new(amount_own: 200));
}

#[test]
fn test_penultimate() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    mock_trace.insert(200, StakerBalanceTrait::new(amount_own: 200));

    let (key, value) = mock_trace.penultimate();
    assert!(key == 100);
    assert!(value == StakerBalanceTrait::new(amount_own: 100));
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

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    assert!(mock_trace.length() == 1);

    mock_trace.insert(200, StakerBalanceTrait::new(amount_own: 200));
    assert!(mock_trace.length() == 2);
}

#[test]
fn test_length_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    assert!(mock_trace.length_mutable() == 0);

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    assert!(mock_trace.length_mutable() == 1);

    mock_trace.insert(200, StakerBalanceTrait::new(amount_own: 200));
    assert!(mock_trace.length_mutable() == 2);
}

#[test]
fn test_latest_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    mock_trace.insert(200, StakerBalanceTrait::new(amount_own: 200));

    let (key, value) = mock_trace.latest_mutable();
    assert!(key == 200);
    assert!(value == StakerBalanceTrait::new(amount_own: 200));
}

#[test]
fn test_staker_balance_new() {
    let mut staker_balance = StakerBalanceTrait::new(amount_own: 100);
    assert!(staker_balance.amount_own() == 100);
    assert!(staker_balance.total_amount() == 100);
    assert!(staker_balance.pool_amount() == 0);
}

#[test]
fn test_staker_balance_increase_own_amount() {
    let mut staker_balance = StakerBalanceTrait::new(amount_own: 100);
    staker_balance.increase_own_amount(amount: 200);
    assert!(staker_balance.amount_own() == 300);
    assert!(staker_balance.total_amount() == 300);
    assert!(staker_balance.pool_amount() == 0);
}

#[test]
fn test_staker_balance_update_pool_amount() {
    let mut staker_balance = StakerBalanceTrait::new(amount_own: 100);
    staker_balance.update_pool_amount(new_amount: 200);
    assert!(staker_balance.amount_own() == 100);
    assert!(staker_balance.total_amount() == 300);
    assert!(staker_balance.pool_amount() == 200);

    staker_balance.update_pool_amount(new_amount: 50);
    assert!(staker_balance.amount_own() == 100);
    assert!(staker_balance.total_amount() == 150);
    assert!(staker_balance.pool_amount() == 50);
}

#[test]
fn test_is_non_empty() {
    let mut mock_trace = CONTRACT_STATE();
    assert!(!mock_trace.is_non_empty());

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    assert!(mock_trace.is_non_empty());
}

#[test]
fn test_is_non_empty_mutable() {
    let mut mock_trace = CONTRACT_STATE();
    assert!(!mock_trace.is_non_empty_mutable());

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    assert!(mock_trace.is_non_empty_mutable());
}

#[test]
fn test_is_empty() {
    let mut mock_trace = CONTRACT_STATE();
    assert!(mock_trace.is_empty());

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    assert!(!mock_trace.is_empty());
}

#[test]
fn test_is_empty_mutable() {
    let mut mock_trace = CONTRACT_STATE();
    assert!(mock_trace.is_empty_mutable());

    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    assert!(!mock_trace.is_empty_mutable());
}

#[test]
fn test_at_mutable() {
    let mut mock_trace = CONTRACT_STATE();
    mock_trace.insert(100, StakerBalanceTrait::new(amount_own: 100));
    mock_trace.insert(200, StakerBalanceTrait::new(amount_own: 200));
    mock_trace.insert(300, StakerBalanceTrait::new(amount_own: 300));
    let (key, value) = mock_trace.at_mutable(0);
    assert!(key == 100);
    assert!(value == StakerBalanceTrait::new(amount_own: 100));

    let (key, value) = mock_trace.at_mutable(1);
    assert!(key == 200);
    assert!(value == StakerBalanceTrait::new(amount_own: 200));

    let (key, value) = mock_trace.at_mutable(2);
    assert!(key == 300);
    assert!(value == StakerBalanceTrait::new(amount_own: 300));
}

#[test]
#[should_panic(expected: "Index out of bounds")]
fn test_at_mutable_out_of_bounds() {
    let mut mock_trace = CONTRACT_STATE();
    mock_trace.at_mutable(0);
}
