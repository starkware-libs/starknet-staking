# BTC Staking - Breaking Changes
<details>
    <summary><strong style="font-size: 3em;">Table of contents</strong></summary>

- [Staking Contract](#staking-contract)
  - [Functions](#functions)
    - [stake](#stake)
    - [update_commission](#update_commission)
    - [set_open_for_delegation](#set_open_for_delegation)
    - [get_pool_exit_intent](#get_pool_exit_intent)
    - [increase_stake](#increase_stake)
    - [get_current_total_staking_power](#get_current_total_staking_power)
  - [Events](#events)
    - [CommissionChanged](#commissionchanged)
    - [DeleteStaker](#deletestaker)
    - [StakerRewardsUpdated](#stakerrewardsupdated)
    - [StakerExitIntent](#stakerexitintent)
    - [StakeBalanceChanged](#stakebalancechanged)
    - [NewDelegationPool](#newdelegationpool)
    - [RemoveFromDelegationPoolIntent](#removefromdelegationpoolintent)
    - [RemoveFromDelegationPoolAction](#removefromdelegationpoolaction)
    - [ChangeDelegationPoolIntent](#changedelegationpoolintent)
- [Reward Supplier Contract](#reward-supplier-contract)
  - [Functions](#functions-1)
    - [calculate_current_epoch_rewards](#calculate_current_epoch_rewards)

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
   fn set_open_for_delegation(ref self: TContractState, token_address: ContractAddress) -> ContractAddress;
   ```
Changes:
1. Remove `commission` parameter - must initialize commission with `set_commission` before open a pool.
Note: If staker already has a commission from the prev version (of the STRK pool), he shouldnt reinitialize it. The same commission applies to all pools per staker.
2. Add `token_address` parameter - open a pool for a specific supported token.

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
Changes:
1. Delete `get_pool_exit_intent` function.

#### increase_stake
Before:
```rust
fn increase_stake(ref self: TContractState, staker_address: ContractAddress, amount: Amount) -> Amount;
```
After:
```rust
fn increase_stake(ref self: TContractState, staker_address: ContractAddress, amount: Amount) -> Amount;
```
Changes:
1. Change return value - in the previous version, the return value was the new total stake amount (self + delegated) of the staker. Now, the return value is the new self stake amount.

#### get_current_total_staking_power
Before:
```rust
fn get_current_total_staking_power(self: @TContractState) -> Amount;
```
After:
```rust
fn get_current_total_staking_power(self: @TContractState) -> (Amount, Amount);
```
Changes:
1. Change return type to tuple of (Amount, Amount) - first amount is the total staking power of the STRK token (same as before), second amount is the total staking power of the BTC active tokens.

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
1. Remove `pool_contract` (key) - commission can be set even before a staker opens a pool.

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

#### StakerRewardsUpdated
Before:
```rust
pub struct StakerRewardsUpdated {
   #[key]
   pub staker_address: ContractAddress,
   pub staker_rewards: Amount,
   pub pool_rewards: Amount,
}
```
After:
```rust
pub struct StakerRewardsUpdated {
   #[key]
   pub staker_address: ContractAddress,
   pub staker_rewards: Amount,
   pub pool_rewards: Span<(ContractAddress, Amount)>,
}
```
Changes:
1. Change type of `pool_rewards` to `Span<(ContractAddress, Amount)>` - now holds tuples of (pool_contract, pool_rewards) for each pool that gets rewards.

#### StakerExitIntent
Before:
```rust
pub struct StakerExitIntent {
   #[key]
   pub staker_address: ContractAddress,
   pub exit_timestamp: Timestamp,
   pub amount: Amount,
}
```
After:
```rust
pub struct StakerExitIntent {
   #[key]
   pub staker_address: ContractAddress,
   pub exit_timestamp: Timestamp,
}
```
Changes:
1. Remove `amount` field.

#### StakeBalanceChanged
Before:
```rust
pub struct StakeBalanceChanged {
   #[key]
   pub staker_address: ContractAddress,
   pub old_self_stake: Amount,
   pub old_delegated_stake: Amount,
   pub new_self_stake: Amount,
   pub new_delegated_stake: Amount,
}
```
After:
```rust
pub struct StakeOwnBalanceChanged {
   #[key]
   pub staker_address: ContractAddress,
   pub old_self_stake: Amount,
   pub new_self_stake: Amount,
}
```
```rust
pub struct StakeDelegatedBalanceChanged {
   #[key]
   pub staker_address: ContractAddress,
   #[key]
   pub token_address: ContractAddress,
   pub old_delegated_stake: Amount,
   pub new_delegated_stake: Amount,
}
```
Changes:
1. Split `StakeBalanceChanged` event to `StakeOwnBalanceChanged` (staker self stake) and `StakeDelegatedBalanceChanged` (staker delegated stake - per token).
2. `StakeOwnBalanceChanged` holds `old_self_stake` and `new_self_stake` but not `old_delegated_stake` and `new_delegated_stake`.
3. `StakeDelegatedBalanceChanged` holds `token_address`, and `old_delegated_stake` and `new_delegated_stake` for the specific token.

#### NewDelegationPool
Before:
```rust
pub struct NewDelegationPool {
   #[key]
   pub staker_address: ContractAddress,
   #[key]
   pub pool_contract: ContractAddress,
   pub commission: Commission,
}
```
After:
```rust
pub struct NewDelegationPool {
   #[key]
   pub staker_address: ContractAddress,
   #[key]
   pub pool_contract: ContractAddress,
   #[key]
   pub token_address: ContractAddress,
   pub commission: Commission,
}
```
Changes:
1. Add `token_address` keyed field - the token address of the pool.

#### RemoveFromDelegationPoolIntent
Before:
```rust
pub struct RemoveFromDelegationPoolIntent {
   #[key]
   pub staker_address: ContractAddress,
   #[key]
   pub pool_contract: ContractAddress,
   #[key]
   pub identifier: felt252,
   pub old_intent_amount: Amount,
   pub new_intent_amount: Amount,
}
```
After:
```rust
pub struct RemoveFromDelegationPoolIntent {
   #[key]
   pub staker_address: ContractAddress,
   #[key]
   pub pool_contract: ContractAddress,
   #[key]
   pub token_address: ContractAddress,
   #[key]
   pub identifier: felt252,
   pub old_intent_amount: Amount,
   pub new_intent_amount: Amount,
}
```
Changes:
1. Add `token_address` keyed field - the token address of the pool.

#### RemoveFromDelegationPoolAction
Before:
```rust
pub struct RemoveFromDelegationPoolAction {
   #[key]
   pub pool_contract: ContractAddress,
   #[key]
   pub identifier: felt252,
   pub amount: Amount,
}
```
After:
```rust
pub struct RemoveFromDelegationPoolAction {
   #[key]
   pub pool_contract: ContractAddress,
   #[key]
   pub token_address: ContractAddress,
   #[key]
   pub identifier: felt252,
   pub amount: Amount,
}
```
Changes:
1. Add `token_address` keyed field - the token address of the pool.

#### ChangeDelegationPoolIntent
Before:
```rust
pub struct ChangeDelegationPoolIntent {
   #[key]
   pub pool_contract: ContractAddress,
   #[key]
   pub identifier: felt252,
   pub old_intent_amount: Amount,
   pub new_intent_amount: Amount,
}
```
After:
```rust
pub struct ChangeDelegationPoolIntent {
   #[key]
   pub pool_contract: ContractAddress,
   #[key]
   pub token_address: ContractAddress,
   #[key]
   pub identifier: felt252,
   pub old_intent_amount: Amount,
   pub new_intent_amount: Amount,
}
```
Changes:
1. Add `token_address` keyed field - the token address of the pool.

## Reward Supplier Contract
### Functions
#### calculate_current_epoch_rewards
Before:
```rust
fn calculate_current_epoch_rewards(self: @TContractState) -> Amount;
```
After:
```rust
fn calculate_current_epoch_rewards(self: @TContractState) -> (Amount, Amount);
```
Changes:
1. Return a tuple with the `strk_rewards` and the `btc_rewards` respectively.
