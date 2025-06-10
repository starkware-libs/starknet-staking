# BTC Staking - Breaking Changes
<details>
    <summary><strong style="font-size: 3em;">Table of contents</strong></summary>

- [Staking Contract](#staking-contract)
  - [Functions](#functions)
    - [stake](#stake)
    - [update_commission](#update_commission)
    - [set_open_for_delegation](#set_open_for_delegation)
    - [get_pool_exit_intent](#get_pool_exit_intent)
  - [Events](#events)
    - [CommissionChanged](#commissionchanged)
    - [DeleteStaker](#deletestaker)
</details>

## Staking Contract
### Functions
#### stake
Before:
```rust
fn stake(
       ref self: TContractState,
       reward_address: ContractAddress,
       operational_address: ContractAddress,
       amount: Amount,
       pool_enabled: bool,
       commission: Commission,
   );
```
After:
```rust
fn stake(
       ref self: TContractState,
       reward_address: ContractAddress,
       operational_address: ContractAddress,
       amount: Amount,
   );
```
Changes:
1. Remove `pool_enabled` and `commission` parameters - cant open pool in stake, must call `set_open_for_delegation`

#### update_commission
Before: 
```rust
fn update_commission(ref self: TContractState, commission: Commission);
```
After:
```rust
fn set_commission(ref self: TContractState, commission: Commission);
```
Changes:
1. Rename from `update_commission` to `set_commission` - if commission is not initialized - initialize it with the given commission. Else, update the commission with the same behavior as `update_commission` from prev version.
Note: The same commission applies to all pools per staker.

#### set_open_for_delegation
Before: 
   ```rust
   fn set_open_for_delegation(ref self: TContractState, commission: Commission) -> ContractAddress;
   ```
After:
   ```rust
   fn set_open_for_delegation(ref self: TContractState) -> ContractAddress;
   ```
Changes:
1. Remove `commission` parameter - must initialize commission with `set_commission` before open a pool.
Note: If staker already has a commission from the prev version (of the STRK pool), he shouldnt reinitialize it. The same commission applies to all pools per staker.

#### get_pool_exit_intent
Before:
```rust
fn get_pool_exit_intent(
       self: @TContractState, undelegate_intent_key: UndelegateIntentKey,
   ) -> UndelegateIntentValue;
```
```rust
pub(crate) struct UndelegateIntentValue {
   pub unpool_time: Timestamp,
   pub amount: Amount,
}
```
After:
```rust
fn get_pool_exit_intent(
       self: @TContractState, undelegate_intent_key: UndelegateIntentKey,
   ) -> UndelegateIntentValue;
```
```rust
pub(crate) struct UndelegateIntentValue {
   pub unpool_time: Timestamp,
   pub amount: Amount,
   pub staker_address: ContractAddress,
}
```
Changes:
1. Add `staker_address` to `UndelegateIntentValue`.

### Events
#### CommissionChanged
Before:
```rust
pub struct CommissionChanged {
       #[key]
       pub staker_address: ContractAddress,
       #[key]
       pub pool_contract: ContractAddress,
       pub new_commission: Commission,
       pub old_commission: Commission,
   }
```
After:
```rust
pub struct CommissionChanged {
       #[key]
       pub staker_address: ContractAddress,
       pub new_commission: Commission,
       pub old_commission: Commission,
   }
```
Changes:
1. Remove `pool_comtract` (key) - commission can be set even before a staker opens a pool.

#### DeleteStaker
Before:
```rust
pub struct DeleteStaker {
       #[key]
       pub staker_address: ContractAddress,
       pub reward_address: ContractAddress,
       pub operational_address: ContractAddress,
       pub pool_contract: Option<ContractAddress>,
   }
```
After:
```rust
pub struct DeleteStaker {
       #[key]
       pub staker_address: ContractAddress,
       pub reward_address: ContractAddress,
       pub operational_address: ContractAddress,
       pub pool_contracts: Span<ContractAddress>,
   }
```
Changes:
1. Rename `pool_contract` to `pool_contracts`.
2. Change type from `Option<ContractAddress>` to `Span<ContractAddress>` - staker may have more than one pool.
