use contracts_commons::components::nonce::interface::INonce;
use contracts_commons::components::nonce::mock_contract::NonceMock;
use contracts_commons::components::nonce::nonce::NonceComponent;
use contracts_commons::components::nonce::nonce::NonceComponent::InternalTrait;
use core::num::traits::Zero;

type ComponentState = NonceComponent::ComponentState<NonceMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    NonceComponent::component_state_for_testing()
}

#[test]
fn test_nonce_getter() {
    let state = COMPONENT_STATE();
    let nonce = state.nonce();
    assert!(nonce.is_zero());
}

#[test]
fn test_use_nonce() {
    let mut state = COMPONENT_STATE();
    let nonce = state.use_next_nonce();
    assert!(nonce.is_zero());

    let nonce = state.nonce();
    assert_eq!(nonce, 1, "use_next_nonce should increment the nonce by 1");
}

#[test]
fn test_use_checked_nonce() {
    let mut state = COMPONENT_STATE();
    let nonce = state.use_checked_nonce(0);
    assert!(nonce.is_zero());

    let nonce = state.nonce();
    assert_eq!(nonce, 1, "use_checked_nonce should increment the nonce by 1");
}

#[test]
#[should_panic(expected: "INVALID_NONCE: current!=received 0!=15")]
fn test_use_checked_nonce_invalid_current() {
    let mut state = COMPONENT_STATE();
    state.use_checked_nonce(15);
}
