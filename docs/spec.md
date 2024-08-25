# Spec <!-- omit from toc -->
<details>
    <summary><strong style="font-size: 1.5em;">Table of contents</strong></summary>

- [Diagrams](#diagrams)
  - [Contracts block diagram](#contracts-block-diagram)
  - [Enter protocol flow diagram](#enter-protocol-flow-diagram)
  - [Exit protocol flow diagram](#exit-protocol-flow-diagram)
  - [Rewards claim flow diagram](#rewards-claim-flow-diagram)
  - [Delegation pool switching flow diagram](#delegation-pool-switching-flow-diagram)
- [Staking contract](#staking-contract)
  - [Functions](#functions)
    - [stake](#stake)
    - [increase\_stake](#increase_stake)
    - [unstake\_intent](#unstake_intent)
    - [unstake\_action](#unstake_action)
    - [claim\_rewards](#claim_rewards)
    - [add\_to\_delegation\_pool](#add_to_delegation_pool)
    - [remove\_from\_delegation\_pool\_intent](#remove_from_delegation_pool_intent)
    - [remove\_from\_delegation\_pool\_action](#remove_from_delegation_pool_action)
    - [switch\_staking\_delegation\_pool](#switch_staking_delegation_pool)
    - [change\_reward\_address](#change_reward_address)
    - [set\_open\_for\_delegation](#set_open_for_delegation)
    - [claim\_delegation\_pool\_rewards](#claim_delegation_pool_rewards)
    - [state\_of](#state_of)
    - [contract\_parameters](#contract_parameters)
    - [total\_staked\_tokens](#total_staked_tokens)
    - [calculate\_rewards](#calculate_rewards)
    - [change\_operational\_address](#change_operational_address)
    - [update\_commission](#update_commission)
  - [Events](#events)
    - [Stake Balance Changed](#stake-balance-changed)
    - [New Delegation Pool](#new-delegation-pool)
    - [Staker Exit intent](#staker-exit-intent)
- [Delegation pooling contract](#delegation-pooling-contract)
  - [Functions](#functions-1)
    - [enter\_delegation\_pool](#enter_delegation_pool)
    - [add\_to\_delegation\_pool](#add_to_delegation_pool-1)
    - [exit\_delegation\_pool\_intent](#exit_delegation_pool_intent)
    - [exit\_delegaition\_pool\_action](#exit_delegaition_pool_action)
    - [claim\_rewards](#claim_rewards-1)
    - [switch\_delegation\_pool](#switch_delegation_pool)
    - [enter\_from\_staking\_contract](#enter_from_staking_contract)
    - [staker\_left](#staker_left)
    - [calculate\_rewards](#calculate_rewards-1)
    - [update\_commission](#update_commission-1)
  - [Events](#events-1)
    - [New Staking Delegation Pool Member](#new-staking-delegation-pool-member)
    - [Delegation Balance Change](#delegation-balance-change)
    - [Delegation Pool Member Exit intent](#delegation-pool-member-exit-intent)
    - [Final Index Set](#final-index-set)

</details>

<!--
function info template:
#### description
#### parameters
| name | type |
| ---- | ---- |
#### return 
#### emits
#### errors
#### pre-condition
#### access control
#### logic
-->
# Diagrams
## Contracts block diagram
```mermaid
classDiagram
  class StakingContract{
    map < staker_address, StakerInfo >
    map < operational_address, StakerInfo >
    global_index
    min_stake
    stake()
    increase_stake()
    unstake_intent()
    unstake_action()
    claim_rewards()
    add_to_delegation_pool()
    remove_from_delegation_pool_intent()
    remove_from_delegation_pool_action()
    switch_staking_delegation_pool()
    change_reward_address()
    set_open_for_delegation()
    claim_delegation_pool_rewards()
    state_of()
    contract_parameters()
    calsulate_rewards()

  }
  class DelegationPoolingContract{
    map < pool_member_address, PoolMemberInfo >
    staker_address
    staker_final_index
    enter_delegation_pool()
    add_to_delegation_pool()
    exit_delegation_pool_intent()
    exit_delegation_pool_action()
    claim_rewards()
    switch_delegation_pool()
    enter_from_stakin_contract()
    calculate_rewards()
  }
  class StakerInfo{
    own_amount
    pooled_amount
    index
    own_unclaimed_rewards
    pooled_unclaimed_rewards
    exit_pooled_amnt: Map < felt, (amnt, time) >
    reward_address
    option < unstake_time >
    operational_address
    option < PoollingContract >
    commission
  }
  class PoolMemberInfo{
    amount
    index
    unclaimed_rewards
    reward_address
    option < unpool_time >
  }
  StakingContract o-- StakerInfo
  DelegationPoolingContract o-- PoolMemberInfo
```

## Enter protocol flow diagram
```mermaid
sequenceDiagram
  actor staker
  participant StakingContract
  participant DelegationPoolingContract
  actor pool member
  staker ->>+ StakingContract: stake<br/>(pooling enabled = true)
  StakingContract -->> DelegationPoolingContract: deploy delegation pool contract
  par
    loop
      staker ->> StakingContract: increase_stake
    end
  and
    loop
      pool member ->>+ DelegationPoolingContract: enter_delegation_pool
      DelegationPoolingContract ->>- StakingContract: add_to_delegation_pool
      loop
        pool member ->>+ DelegationPoolingContract: add_to_delegation_pool
        DelegationPoolingContract ->>- StakingContract: add_to_delegation_pool
      end
    end
  end
```

## Exit protocol flow diagram
```mermaid
sequenceDiagram
  actor staker
  participant StakingContract
  participant DelegationPoolingContract
  actor pool member
  opt Loop
    pool member ->>+ DelegationPoolingContract: exit_delegation_pool_intent
    DelegationPoolingContract ->>- StakingContract: remove_from_delegation_pool_intent
    pool member ->>+ DelegationPoolingContract: exit_delegation_pool_action
    DelegationPoolingContract ->>- StakingContract: remove_from_delegation_pool_action
  end
  staker ->> StakingContract: unstake_intent
  staker ->> StakingContract: unstake_action
  opt Loop
    pool member ->>+ DelegationPoolingContract: exit_delegation_pool_intent
    DelegationPoolingContract ->>- StakingContract: remove_from_delegation_pool_intent
    pool member ->>+ DelegationPoolingContract: exit_delegation_pool_action
    DelegationPoolingContract ->>- StakingContract: remove_from_delegation_pool_action
  end
```

## Rewards claim flow diagram
```mermaid
sequenceDiagram
  actor staker
  participant StakingContract
  participant DelegationPoolingContract
  actor pool memberopt 
  Loop
    staker ->> StakingContract: claim_rewards
  end
  opt Loop
    pool member ->>+ DelegationPoolingContract: claim_rewards
    DelegationPoolingContract ->>- StakingContract: claim_delegation_pool_rewards
  end
```

## Delegation pool switching flow diagram
```mermaid
sequenceDiagram
  participant DelegationPoolingContract B
  participant StakingContract
  participant DelegationPoolingContract A
  actor pool member
  pool member ->>+ DelegationPoolingContract A: exit_delegation_pool_intent
  DelegationPoolingContract A ->>- StakingContract: remove_from_delegation_pool_intent
  pool member ->>+ DelegationPoolingContract A: switch_delegation_pool
  DelegationPoolingContract A ->>+ StakingContract: switch_staking_delegation_pool
  StakingContract ->>- DelegationPoolingContract B: enter_from_staking_contract
  deactivate DelegationPoolingContract A
  loop 
    Note left of StakingContract:  optional for switching some<br/> of the funds but keeping the rest<br/> with the original stakeror splitting<br/> between multiple stakers
    pool member ->>+ DelegationPoolingContract A: switch_delegation_pool
    DelegationPoolingContract A ->> StakingContract: switch_staking_delegation_pool
    StakingContract ->> DelegationPoolingContract B: enter_from_staking_contract
    deactivate DelegationPoolingContract A
  end
```


# Staking contract
## Functions
### stake
#### description <!-- omit from toc -->
Add a new staker to the stake.
#### parameters <!-- omit from toc -->
| name            | type       |
| --------------- | ---------- |
| reward          | address    |
| operational     | address    |
| amount          | u128       |
| pooling_enabled | boolean    |
| commission      | Option<u8> |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
[Balance Changed](#balance-changed)  
[New Staking Delegation Pool](#new-staking-delegation-pool) - if pooling_enabled
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. caller address (staker) is not listed in the contract.
2. Operational address is not listed in the contract.
#### logic  <!-- omit from toc -->
1. Validate amount is above the minimum amount for staking.
2. Transfer amount from staker to be locked in the contract.
3. Create a new registry for the staker (caller).
4. Set:
   1. Staker index = current global index.
   2. unclaimed_amount = 0.
   3. amount = given amount.
5. if pooling_enabled then deploy a pooling contract instance.

### increase_stake
#### description <!-- omit from toc -->
Increase the amount staked for an existing staker.
#### parameters <!-- omit from toc -->
| name   | type    |
| ------ | ------- |
| staker | address |
| amount | u128    |
#### return <!-- omit from toc -->
amount: u128 - updated total amount
#### emits <!-- omit from toc -->
[Balance Changed](#balance-changed)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Staker is listed in the contract.
2. Staker is not in an exit window.
#### access control <!-- omit from toc -->
Only the staker address or rewards address for which the change is requested for.
#### logic <!-- omit from toc -->
1. Validate amount is above the minimum set threshold.
2. Validate staker is not in an exit window.
3. [Calculate rewards](#calculate_rewards).
4. Increase staked amount.

### unstake_intent
#### description <!-- omit from toc -->
Inform of the intent to exit the stake. 
This will remove the funds from the stake, pausing rewards collection for the staker and it's pool members (if exist).
This will also start the exit window timeout.
#### parameters <!-- omit from toc -->
| name | type |
| ---- | ---- |
|      |      |
#### return <!-- omit from toc -->
unstake_time: time - when will the staker be able to unstake.
#### emits <!-- omit from toc -->
[Staker Exit Intent](#staker-exit-intent)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Staker (caller) is listed in the contract.
2. Staker (caller) is not in an exit window.
#### access control <!-- omit from toc -->
Only the staker address for which the operation is requested for.
#### logic <!-- omit from toc -->
1. Validate staker is not in an exit window.
2. performs [Calculate rewards](#calculate_rewards).
3. Set unstake_time.

### unstake_action
#### description <!-- omit from toc -->
Executes the intent to exit the stake if enough time have passed.
Transfers the funds back to the staker.
#### parameters <!-- omit from toc -->
| name   | type    |
| ------ | ------- |
| staker | address |
#### return <!-- omit from toc -->
amount: u128 - amount of tokens transferred back to the staker.
#### emits <!-- omit from toc -->
[Balance Changed](#balance-changed)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Staker exist and requested to unstake.
2. Enough time have passed from the unstake intent call.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. Validate enough time have passed from the unstake intent.
2. claim rewards.
3. remove funds and transfer to staker.
4. transfer pool unclaimed rewards and stake to delegation pool contract.
5. call [staker_left](#staker-left) on the delegation_pool_contract.
6. delete staker record.

### claim_rewards
#### description <!-- omit from toc -->
Calculate rewards and transfer them to the reward address.
#### parameters <!-- omit from toc -->
| name   | type    |
| ------ | ------- |
| staker | address |
#### return <!-- omit from toc -->
amount: u128 - amount of tokens transferred to the reward address.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### access control <!-- omit from toc -->
Only staking address or reward address can execute.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards).
2. Transfer unclaimed_rewards
3. Set unclaimed_rewards = 0.

### add_to_delegation_pool
#### description <!-- omit from toc -->
Delegation pooling contract's way to add funds to the staking pool.
#### parameters <!-- omit from toc -->
| name          | type    |
| ------------- | ------- |
| pooled_staker | address |
| amount        | u128    |
#### return <!-- omit from toc -->
pool_amount: u128 - total pool amount after addition.
index: u64 - updated index
#### emits <!-- omit from toc -->
[Balance Changed](#balance-changed)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Staker is not in an exit window.
2. Staker enabled pooling.
#### access control <!-- omit from toc -->
Only pooling contract for the given staker can execute.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards)
2. transfer funds from pooling contract to staking contract.
3. Add amount to staker's pooled amount

### remove_from_delegation_pool_intent
#### description <!-- omit from toc -->
Inform the staker that an amount will be reduced from the delegation pool.
#### parameters <!-- omit from toc -->
| name       | type            |
| ---------- | --------------- |
| staker     | address         |
| identifier | felt252         |
| amount     | u128            |
#### return <!-- omit from toc -->
unstake_time: time - when will the pool member be able to exit.
index: u64 - updated index
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Staker has a pool.
#### access control <!-- omit from toc -->
Only pooling contract for the given staker can execute.
#### logic <!-- omit from toc -->
1. Validate pooled amount is greater or equal then amount requested to remove.
2. [Calculate rewards](#calculate_rewards).
3. Remove amount from staker's pooled amount.
4. Register intent with given identifier, amount and unstake_time.

### remove_from_delegation_pool_action
#### description <!-- omit from toc -->
Execute the intent to remove funds from pool if enough time have passed.
Transfers the funds to the pooling contract.
#### parameters <!-- omit from toc -->
| name       | type            |
| ---------- | --------------- |
| staker     | address         |
| identifier | Span\<felt252\> |
#### return <!-- omit from toc -->
amount: felt252 - amount being transferred to the pooling contract.
#### emits <!-- omit from toc -->
[Balance Changed](#balance-changed)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. A removal intent request with this identifier have been sent before.
2. Enough time have passed since the intent request.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. Validate enough time have passed since remove from pool intent.
2. Transfer funds from staking contract to pooling contract.
3. Remove intent from staker's list.

### switch_staking_delegation_pool
#### description <!-- omit from toc -->
Execute a pool member request to move from one staker's delegation pool to another staker's delegation pool.
#### parameters <!-- omit from toc -->
| name        | type            |
| ----------- | --------------- |
| from_staker | address         |
| to_staker   | address         |
| to_pool     | address         |
| amount      | u128            |
| data        | Span\<felt252\> |
| identifier  | felt252         |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Enough funds are available in `from_staker` pool.
2. `to_staker` exist in the contract and is not in exit window.
3. `to_pool` is the delegation pool contract for `to_staker`.
#### access control <!-- omit from toc -->
Only pooling contract for the given staker can execute.
#### logic <!-- omit from toc -->
1. Remove requested amount from `from_staker`'s pool amount.
2. Add requested amount to `to_staker`'s pool with pool contract address `to_pool`.
3. move amount balance from original pool to new pool's behalf.
4. Call new pool's [enter_from_staking_contract](#enter_from_staking_contract) function.

### change_reward_address
#### description <!-- omit from toc -->
Change the reward address for a staker.
#### parameters <!-- omit from toc -->
| name    | type    |
| ------- | ------- |
| address | address |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Staker exist in the contract.
#### access control <!-- omit from toc -->
Only staking address.
#### logic <!-- omit from toc -->
1. change registered `reward_address` for the staker.

### set_open_for_delegation
#### description <!-- omit from toc -->
Creates a staking delegation pool for a staker that doesn't have one.
#### parameters <!-- omit from toc -->
| name       | type |
| ---------- | ---- |
| commission | u16  |
#### return <!-- omit from toc -->
pool: address
#### emits <!-- omit from toc -->
[New Delegation Pool](#new-delegation-pool)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Staker exist in the contract.
2. Staker has no pool.
#### access control <!-- omit from toc -->
Only staking address.
#### logic <!-- omit from toc -->
1. generate pooling contract for staker.
2. register pool.

### claim_delegation_pool_rewards
#### description <!-- omit from toc -->
Calculate rewards and transfer the delegation pool rewards to the delegation pool contract.
#### parameters <!-- omit from toc -->
| name   | type    |
| ------ | ------- |
| staker | address |
#### return <!-- omit from toc -->
index: u64 - updated index
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. staker exist in the contract
2. delegation pool exist for the staker.
#### access control <!-- omit from toc -->
Staker or delegation pool contract for this staker.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards)
2. Transfer rewards to pool contract.

### state_of
#### description <!-- omit from toc -->
return the state of a staker
#### parameters <!-- omit from toc -->
| name   | type    |
| ------ | ------- |
| staker | address |
#### return <!-- omit from toc -->
own_amount
pooled_amount
pooling_contract_address
operational_address
reward_address
staker_unclaimed_rewards
pool_unclaimed_rewards
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
#### logic <!-- omit from toc -->

### contract_parameters
#### description <!-- omit from toc -->
Return general parameters of the contract.
#### parameters <!-- omit from toc -->
| name | type |
| ---- | ---- |
#### return <!-- omit from toc -->
minimum_stake
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
#### logic <!-- omit from toc -->

### total_staked_tokens
#### description <!-- omit from toc -->
Returns the total amount of staked tokens.
#### parameters <!-- omit from toc -->
| name | type |
| ---- | ---- |
#### return <!-- omit from toc -->
total_staked: u128
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
#### logic <!-- omit from toc -->


### calculate_rewards
>**note:** internal logic
#### description <!-- omit from toc -->
Calculate rewards, add amount to unclaimed_rewards, update index.
#### parameters <!-- omit from toc -->
| name   | type    |
| ------ | ------- |
| staker | address |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
internal function.
#### logic <!-- omit from toc -->
1. Calculate rewards for `own_amount`.
2. Calculate rewards for `pooled_amount`.
3. Update `own_unclaimed_rewards` with own rewards + pooled rewards commission.
4. Update `pooled_unclaimed_rewards` with pooled rewards without commission. 
5. Update index.

### change_operational_address
#### description <!-- omit from toc -->
Change the operational address for a staker.
#### parameters <!-- omit from toc -->
| name                | type    |
| ------------------- | ------- |
| operational_address | address |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Staker exist in the contract.
#### access control <!-- omit from toc -->
Only staking address.
#### logic <!-- omit from toc -->
1. change registered `operational_address` for the staker.

### update_commission
#### description <!-- omit from toc -->
Update commission. 
#### parameters <!-- omit from toc -->
| name           | type |
| -----          | ---- |
| commission     | u16  |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. only staker can call.
2. staker have pooling contract.
3. given commission is lower or equal to staker current commission
#### access control <!-- omit from toc -->
#### logic <!-- omit from toc -->
1. Update staker's commission to be the given commission.

## Events
### Stake Balance Changed
| data                | type            | keyed  |
| ------              | -------         | -----  |
| staker_address      | address         | ✅     |
| old_self_stake      | u128            | ❌     |
| old_delegated_stake | u128            | ❌     |
| new_self_stake      | u128            | ❌     |
| new_delegated_stake | u128            | ❌     |

### New Delegation Pool
| data           | type    | keyed |
| -------------- | ------- | ----- |
| staker_address | address | ✅    |
| pool_contract  | address | ✅    |
| commission     | u16     | ❌    |


### Staker Exit intent
| data    | type    | keyed |
| ------- | ------- | ----- |
| staker  | address | ✅     |
| exit_at | time    | ❌     |

# Delegation pooling contract

## Functions
### enter_delegation_pool
#### description <!-- omit from toc -->
Add a new pool member to the delegation pool.
#### parameters <!-- omit from toc -->
| name   | type    |
| ------ | ------- |
| reward | address |
| amount | u128    |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
[Delegation Balance Changed](#delegation-balance-change)
[Stake Balance Changed](#stake-balance-changed)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. caller address (pool member) is not listed in the contract.
#### logic <!-- omit from toc -->
1. Transfer funds from pool member to pooling contract.
2. Approve transferal from pooling contract to staking contract.
3. Call staking contract's [add_to_delegation_pool](#add_to_delegation_pool-).
4. Get current index from staking contract.
5. Create entry for pool member.

### add_to_delegation_pool
#### description <!-- omit from toc -->
Increase the funds for an existing pool member.
#### parameters <!-- omit from toc -->
| name   | type |
| ------ | ---- |
| amount | u128 |
#### return <!-- omit from toc -->
amount: u128 - updated total amount for the caller.
#### emits <!-- omit from toc -->
[Delegation Balance Changed](#delegation-balance-change)
[Stake Balance Changed](#stake-balance-changed)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. caller is a pool member listed in the contract.
#### access control <!-- omit from toc -->
only a listed pool member address.
#### logic <!-- omit from toc -->
1. Check that staker for this pool instance is not in exit window.
2. [Calculate rewards](#calculate_rewards-1)
3. Transfer funds from caller to the contract.
4. Call staking contract's [add_to_delegation_pool](#add_to_delegation_pool).
5. Get current index from staking contract.
6. Update pool memeber entry with
   1. index
   2. amount
   3. unclaimed rewards

### exit_delegation_pool_intent
#### description <!-- omit from toc -->
Inform of the intent to exit the stake. This will remove the funds from the stake, pausing rewards collection for the pool member. This will also start the exit window timeout.
#### parameters <!-- omit from toc -->
| name | type |
| ---- | ---- |
#### return <!-- omit from toc -->
#### emits <!-- omit from toc -->
[Delegation Pool Member Exit Intent](#delegation-pool-member-exit-intent)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Pool member (caller) is listed in the contract.
2. Pool member (caller) is not in an exit window.
#### access control <!-- omit from toc -->
Only the pool member address for which the operation is requested for.
#### logic <!-- omit from toc -->
1. Validate pool member is not in exit window.
2. [Calculate rewards](#calculate_rewards-1)
3. If staker is in exit window set it's unstake time as the pool member exit_pool_time.
4. Else set exit_pool_time to the configured value.
5. [Inform staking contract](#remove_from_delegation_pool_intent)

### exit_delegaition_pool_action
#### description <!-- omit from toc -->
Executes the intent to exit the stake if enough time have passed. Transfers the funds back to the pool member.
#### parameters <!-- omit from toc -->
| name        | type    |
| ----------- | ------- |
| pool_member | address |
#### return <!-- omit from toc -->
amount: u128 - amount of tokens transferred back to the pool member.
#### emits <!-- omit from toc -->
[Delegation Balance Changed](#delegation-balance-change)
[Stake Balance Changed](#stake-balance-changed)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. Pool member exist and requested to unstake.
2. Enough time have passed from the delegation pool exit intent call.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. Validate enough time have passed from the exit intent.
2. [claim rewards](#claim_rewards--1).
3. [Remove from delegation pool action](#remove_from_delegation_pool_action).
4. Transfer funds to pool member.


### claim_rewards
#### description <!-- omit from toc -->
Calculate rewards and transfer them to the reward address.
#### parameters <!-- omit from toc -->
| name        | type    |
| ----------- | ------- |
| pool_member | address |
#### return <!-- omit from toc -->
amount: u128 - amount of tokens transferred to the reward address.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
Only pool member address or reward address can execute.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards-1).
2. Transfer unclaimed_rewards
3. Set unclaimed_rewards = 0.

### switch_delegation_pool
#### description <!-- omit from toc -->
Request the staking contract to move a pool member to another pool contract.
#### parameters <!-- omit from toc -->
| name      | type    |
| --------- | ------- |
| to_staker | address |
| to_pool   | address |
| amount    | u128    |
#### return <!-- omit from toc -->
amount: u128 - amount left in exit window for the pool member in this pool.
#### emits <!-- omit from toc -->
[Delegation Balance Changed](#delegation-balance-change)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. pool member (caller) is in exit window.
2. pool member's amount is greater or equal to the amount requested.
#### access control <!-- omit from toc -->
Only pool member can call.
#### logic <!-- omit from toc -->
1. Compose and serialize data: pool member address and reward address.
2. Call staking contract's [switch delegation pool](#switch_staking_delegation_pool).

### enter_from_staking_contract
#### description <!-- omit from toc -->
Entry point for staking contract to inform pool of a pool member being moved from another pool to this one.
No funds need to be transferred since staking contract holds the pool funds.
#### parameters <!-- omit from toc -->
| name   | type          |
| ------ | ------------- |
| amount | u128          |
| index  | u64           |
| data   | Span<felt252> |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
[Delegation Balance Changed](#delegation-balance-change)
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
Only staking contract can call.
#### logic <!-- omit from toc -->
1. Check that staker for this pool instance is not in exit window.
2. Deserialize data, get pool_member and rewrad addresses.
3. If pool member is listed in the contract:
   1. validate that pool member is not in exit window.
   2. [Calculate rewards](#calculate_rewards-1)
   3. Update pool member entry
4. Else
   1. Create an entry for the pool member.

### staker_left
#### description <!-- omit from toc -->
Informs the delegation pool contract that the staker has left and the contract is now detached from the staking contract.
#### parameters <!-- omit from toc -->
| name  | type |
| ----- | ---- |
| index | u64  |
#### return <!-- omit from toc -->
sucess: bool
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
only staking contract can call
#### logic <!-- omit from toc -->
1. set staker final index to the provided index.

### calculate_rewards
>**note:** internal logic
#### description <!-- omit from toc -->
Calculate rewards, add amount to unclaimed_rewards, update index.
Assumes this function call is after an one of the interactions with the staking contract:
1. [add to delegation pool](#add_to_delegation_pool)
2. [claim delegation pool rewards](#claim_delegation_pool_rewards)
3. [exit delegation pool intent](#exit_delegation_pool_intent)
that perform rewards calculation and index update on the staker and returns the updated index.
#### parameters <!-- omit from toc -->
| name  | type |
| ----- | ---- |
| index | u64  |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
internal function.
#### logic <!-- omit from toc -->
1. Calculate rewards for pool member (caller).
2. Update `unclaimed_rewards`.
3. Update index.

### update_commission
#### description <!-- omit from toc -->
Update commission. 
#### parameters <!-- omit from toc -->
| name           | type |
| -----          | ---- |
| commission     | u16  |
#### return <!-- omit from toc -->
success: bool
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
1. only staking contract can call.
2. given commission is lower or equal to pool contract's commission.
#### access control <!-- omit from toc -->
#### logic <!-- omit from toc -->
1. Update `commission` to be the given commission.

## Events
### New Staking Delegation Pool Member
| data        | type    | keyed |
| ----------- | ------- | ----- |
| staker      | address | ✅     |
| pool_member | address | ✅     |
| amount      | u128    | ❌     |

### Delegation Balance Change
| data                | type    | keyed |
| ------------------- | ------- | ----- |
| pool_member         | address | ✅    |
| old_delegated_stake | u128    | ❌    |
| new_delegated_stake | u128    | ❌    |

### Delegation Pool Member Exit intent
| data        | type    | keyed |
| ----------- | ------- | ----- |
| pool_member | address | ✅     |
| exit_at     | time    | ❌     |

### Final Index Set
| data               | type    | keyed |
| ------------------ | ------- | ----- |
| staker_address     | address | ✅    |
| final_staker_index | u64     | ❌    |
