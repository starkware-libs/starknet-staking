use staking::staking::staker_balance_trace::mock::{IMockTrace, MockTrace};
use staking::staking::staker_balance_trace::trace::StakerBalanceTrait;

fn CONTRACT_STATE() -> MockTrace::ContractState {
    MockTrace::contract_state_for_testing()
}

#[test]
fn test_insert() {
    let mut mock_trace = CONTRACT_STATE();

    let staker_balance = StakerBalanceTrait::new(amount: 1000);
    mock_trace.insert(key: 100, value: staker_balance);
    assert!(mock_trace.latest() == (100, staker_balance));
    assert!(mock_trace.length() == 1);

    let staker_balance = StakerBalanceTrait::new(amount: 2000);
    mock_trace.insert(key: 200, value: staker_balance);
    assert!(mock_trace.latest() == (200, staker_balance));
    assert!(mock_trace.length() == 2);

    let staker_balance = StakerBalanceTrait::new(amount: 500);
    mock_trace.insert(key: 200, value: staker_balance);
    assert!(mock_trace.latest() == (200, staker_balance));
    assert!(mock_trace.length() == 2);
}

#[test]
#[should_panic(expected: "Unordered insertion")]
fn test_insert_unordered_insertion() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(200, StakerBalanceTrait::new(amount: 200));
    mock_trace.insert(100, StakerBalanceTrait::new(amount: 100)); // This should panic
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

    mock_trace.insert(100, StakerBalanceTrait::new(amount: 100));
    mock_trace.insert(200, StakerBalanceTrait::new(amount: 200));

    let (key, value) = mock_trace.latest();
    assert!(key == 200);
    assert!(value == StakerBalanceTrait::new(amount: 200));
}

#[test]
fn test_length() {
    let mut mock_trace = CONTRACT_STATE();

    assert!(mock_trace.length() == 0);

    mock_trace.insert(100, StakerBalanceTrait::new(amount: 100));
    assert!(mock_trace.length() == 1);

    mock_trace.insert(200, StakerBalanceTrait::new(amount: 200));
    assert!(mock_trace.length() == 2);
}

#[test]
fn test_upper_lookup() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(100, StakerBalanceTrait::new(amount: 100));
    mock_trace.insert(200, StakerBalanceTrait::new(amount: 200));

    assert!(mock_trace.upper_lookup(100) == StakerBalanceTrait::new(amount: 100));
    assert!(mock_trace.upper_lookup(150) == StakerBalanceTrait::new(amount: 100));
    assert!(mock_trace.upper_lookup(200) == StakerBalanceTrait::new(amount: 200));
    assert!(mock_trace.upper_lookup(250) == StakerBalanceTrait::new(amount: 200));
}

#[test]
fn test_latest_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(100, StakerBalanceTrait::new(amount: 100));
    mock_trace.insert(200, StakerBalanceTrait::new(amount: 200));

    let (key, value) = mock_trace.latest_mutable();
    assert!(key == 200);
    assert!(value == StakerBalanceTrait::new(amount: 200));
}

#[test]
fn test_staker_balance_new() {
    let mut staker_balance = StakerBalanceTrait::new(amount: 100);
    assert!(staker_balance.amount_own() == 100);
    assert!(staker_balance.total_amount() == 100);
    assert!(staker_balance.pool_amount() == 0);
}

#[test]
fn test_staker_balance_increase_own_amount() {
    let mut staker_balance = StakerBalanceTrait::new(amount: 100);
    staker_balance.increase_own_amount(amount: 200);
    assert!(staker_balance.amount_own() == 300);
    assert!(staker_balance.total_amount() == 300);
    assert!(staker_balance.pool_amount() == 0);
}

#[test]
fn test_staker_balance_update_pool_amount() {
    let mut staker_balance = StakerBalanceTrait::new(amount: 100);
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
fn test_is_initialized() {
    let mut mock_trace = CONTRACT_STATE();
    assert!(mock_trace.is_initialized() == false);

    mock_trace.insert(100, StakerBalanceTrait::new(amount: 100));
    assert!(mock_trace.is_initialized() == true);
}
