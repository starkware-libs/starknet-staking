use contracts_commons::trace::mock::{IMockTrace, MockTrace};

fn CONTRACT_STATE() -> MockTrace::ContractState {
    MockTrace::contract_state_for_testing()
}

#[test]
fn test_push() {
    let mut mock_trace = CONTRACT_STATE();

    let (prev, new) = mock_trace.push(100, 1000);
    assert_eq!(prev, 0);
    assert_eq!(new, 1000);

    let (prev, new) = mock_trace.push(200, 2000);
    assert_eq!(prev, 1000);
    assert_eq!(new, 2000);
    assert_eq!(mock_trace.length(), 2);

    let (prev, new) = mock_trace.push(200, 500);
    assert_eq!(prev, 2000);
    assert_eq!(new, 500);
    assert_eq!(mock_trace.length(), 2);
}

#[test]
#[should_panic(expected: "Unordered insertion")]
fn test_push_unordered_insertion() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.push(200, 2000);
    mock_trace.push(100, 1000); // This should panic
}

#[test]
fn test_latest() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.push(100, 1000);
    mock_trace.push(200, 2000);

    let latest = mock_trace.latest();
    assert_eq!(latest, 2000);
}

#[test]
fn test_latest_checkpoint() {
    let mut mock_trace = CONTRACT_STATE();

    let (has_checkpoint, _, _) = mock_trace.latest_checkpoint();
    assert_eq!(has_checkpoint, false);

    mock_trace.push(100, 1000);
    mock_trace.push(200, 2000);

    let (has_checkpoint, key, value) = mock_trace.latest_checkpoint();
    assert_eq!(has_checkpoint, true);
    assert_eq!(key, 200);
    assert_eq!(value, 2000);
}

#[test]
fn test_length() {
    let mut mock_trace = CONTRACT_STATE();

    assert_eq!(mock_trace.length(), 0);

    mock_trace.push(100, 1000);
    assert_eq!(mock_trace.length(), 1);

    mock_trace.push(200, 2000);
    assert_eq!(mock_trace.length(), 2);
}

#[test]
fn test_upper_lookup() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.push(100, 1000);
    mock_trace.push(200, 2000);

    assert_eq!(mock_trace.upper_lookup(100), 1000);
    assert_eq!(mock_trace.upper_lookup(150), 1000);
    assert_eq!(mock_trace.upper_lookup(200), 2000);
    assert_eq!(mock_trace.upper_lookup(250), 2000);
}

#[test]
fn test_latest_mutable() {
    let mut mock_trace = CONTRACT_STATE();

    mock_trace.push(100, 1000);
    mock_trace.push(200, 2000);

    let latest = mock_trace.latest_mutable();
    assert_eq!(latest, 2000);
}
