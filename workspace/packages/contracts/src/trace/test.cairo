use contracts_commons::trace::mock::{IMockTrace, MockTrace};

fn CONTRACT_STATE() -> MockTrace::ContractState {
    MockTrace::contract_state_for_testing()
}

#[test]
fn test_insert() {
    let mut mock_trace = CONTRACT_STATE();

    let (prev, new) = mock_trace.insert(100, 1000);
    assert_eq!(prev, 0);
    assert_eq!(new, 1000);

    let (prev, new) = mock_trace.insert(200, 2000);
    assert_eq!(prev, 1000);
    assert_eq!(new, 2000);
    assert_eq!(mock_trace.length(), 2);

    let (prev, new) = mock_trace.insert(200, 500);
    assert_eq!(prev, 2000);
    assert_eq!(new, 500);
    assert_eq!(mock_trace.length(), 2);
}

#[test]
#[should_panic(expected: "Unordered insertion")]
fn test_insert_unordered_insertion() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(200, 2000);
    mock_trace.insert(100, 1000); // This should panic
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

    mock_trace.insert(100, 1000);
    mock_trace.insert(200, 2000);

    let (key, value) = mock_trace.latest();
    assert_eq!(key, 200);
    assert_eq!(value, 2000);
}

#[test]
fn test_length() {
    let mut mock_trace = CONTRACT_STATE();

    assert_eq!(mock_trace.length(), 0);

    mock_trace.insert(100, 1000);
    assert_eq!(mock_trace.length(), 1);

    mock_trace.insert(200, 2000);
    assert_eq!(mock_trace.length(), 2);
}

#[test]
fn test_upper_lookup() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(100, 1000);
    mock_trace.insert(200, 2000);

    assert_eq!(mock_trace.upper_lookup(100), 1000);
    assert_eq!(mock_trace.upper_lookup(150), 1000);
    assert_eq!(mock_trace.upper_lookup(200), 2000);
    assert_eq!(mock_trace.upper_lookup(250), 2000);
}

#[test]
fn test_latest_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.insert(100, 1000);
    mock_trace.insert(200, 2000);

    let latest = mock_trace.latest_mutable();
    assert_eq!(latest, 2000);
}

#[test]
fn test_length_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    assert_eq!(mock_trace.length_mutable(), 0);

    mock_trace.insert(100, 1000);
    assert_eq!(mock_trace.length_mutable(), 1);

    mock_trace.insert(200, 2000);
    assert_eq!(mock_trace.length_mutable(), 2);
}

#[test]
fn test_is_empty() {
    let mut mock_trace = CONTRACT_STATE();

    assert!(mock_trace.is_empty());

    mock_trace.insert(100, 1000);

    assert!(!mock_trace.is_empty());
}
