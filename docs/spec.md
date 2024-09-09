# Spec <!-- omit from toc -->
<details>
    <summary><strong style="font-size: 1.5em;">Table of contents</strong></summary>

- [Diagrams](#diagrams)
  - [L2 Contracts block diagram](#l2-contracts-block-diagram)
  - [L1 Contracts block diagram](#l1-contracts-block-diagram)
  - [Enter protocol flow diagram](#enter-protocol-flow-diagram)
  - [Exit protocol flow diagram](#exit-protocol-flow-diagram)
  - [Rewards claim flow diagram](#rewards-claim-flow-diagram)
  - [Delegation pool switching flow diagram](#delegation-pool-switching-flow-diagram)
  - [L1 Mint \& transfer flow diagram](#l1-mint--transfer-flow-diagram)
  - [L2 Rewards calculation and minting request flow diagram](#l2-rewards-calculation-and-minting-request-flow-diagram)
- [Staking contract](#staking-contract)
  - [Functions](#functions)
    - [stake](#stake)
    - [increase\_stake](#increase_stake)
    - [unstake\_intent](#unstake_intent)
    - [unstake\_action](#unstake_action)
    - [claim\_rewards](#claim_rewards)
    - [add\_stake\_from\_pool](#add_stake_from_pool)
    - [remove\_from\_delegation\_pool\_intent](#remove_from_delegation_pool_intent)
    - [remove\_from\_delegation\_pool\_action](#remove_from_delegation_pool_action)
    - [switch\_staking\_delegation\_pool](#switch_staking_delegation_pool)
    - [change\_reward\_address](#change_reward_address)
    - [set\_open\_for\_delegation](#set_open_for_delegation)
    - [claim\_delegation\_pool\_rewards](#claim_delegation_pool_rewards)
    - [state\_of](#state_of)
    - [contract\_parameters](#contract_parameters)
    - [get\_total\_stake](#get_total_stake)
    - [calculate\_rewards](#calculate_rewards)
    - [change\_operational\_address](#change_operational_address)
    - [update\_global\_index\_if\_needed](#update_global_index_if_needed)
    - [is\_paused](#is_paused)
    - [pause](#pause)
    - [unpause](#unpause)
  - [Events](#events)
    - [Stake Balance Changed](#stake-balance-changed)
    - [New Delegation Pool](#new-delegation-pool)
    - [New Staker](#new-staker)
    - [Staker Exit intent](#staker-exit-intent)
    - [Rewards Supplied To Delegation Pool](#rewards-supplied-to-delegation-pool)
    - [Delete Staker](#delete-staker)
    - [Staker Reward Claimed](#staker-reward-claimed)
    - [Staker Reward Address Changed](#staker-reward-address-changed)
    - [Operational Address Changed](#operational-address-changed)
    - [Global Index Updated](#global-index-updated)
    - [Paused](#paused)
    - [Unpaused](#unpaused)
- [Delegation pool contract](#delegation-pool-contract)
  - [Functions](#functions-1)
    - [enter\_delegation\_pool](#enter_delegation_pool)
    - [add\_to\_delegation\_pool](#add_to_delegation_pool)
    - [exit\_delegation\_pool\_intent](#exit_delegation_pool_intent)
    - [exit\_delegation\_pool\_action](#exit_delegation_pool_action)
    - [claim\_rewards](#claim_rewards-1)
    - [switch\_delegation\_pool](#switch_delegation_pool)
    - [enter\_delegation\_pool\_from\_staking\_contract](#enter_delegation_pool_from_staking_contract)
    - [set\_final\_staker\_index](#set_final_staker_index)
    - [change\_reward\_address](#change_reward_address-1)
    - [state\_of](#state_of-1)
    - [contract\_parameters](#contract_parameters-1)
    - [calculate\_rewards](#calculate_rewards-1)
  - [Events](#events-1)
    - [New Staking Delegation Pool Member](#new-staking-delegation-pool-member)
    - [Delegation Pool Member Balance Changed](#delegation-pool-member-balance-changed)
    - [Pool Member Exit Intent](#pool-member-exit-intent)
    - [Final Index Set](#final-index-set)
    - [New Pool Member](#new-pool-member)
    - [Delete Pool Member](#delete-pool-member)
    - [Pool Member Reward Claimed](#pool-member-reward-claimed)
    - [Pool Member Reward Address Changed](#pool-member-reward-address-changed)
- [L2 Reward supplier contract](#l2-reward-supplier-contract)
  - [Functions](#functions-2)
    - [calculate\_staking\_rewards](#calculate_staking_rewards)
    - [claim\_rewards](#claim_rewards-2)
    - [on\_receive](#on_receive)
    - [state\_of](#state_of-2)
  - [Events](#events-2)
    - [Mint Request](#mint-request)
- [Minting curve contract](#minting-curve-contract)
  - [Functions](#functions-3)
    - [yearly\_mint](#yearly_mint)
  - [Events](#events-3)
    - [Total Supply Changed](#total-supply-changed)
- [Errors](#errors)
    - [STAKER\_EXISTS](#staker_exists)
    - [STAKER\_NOT\_EXISTS](#staker_not_exists)
    - [OPERATIONAL\_EXISTS](#operational_exists)
    - [AMOUNT\_LESS\_THAN\_MIN\_STAKE](#amount_less_than_min_stake)
    - [COMMISSION\_OUT\_OF\_RANGE](#commission_out_of_range)
    - [CONTRACT\_IS\_PAUSED](#contract_is_paused)
    - [UNSTAKE\_IN\_PROGRESS](#unstake_in_progress)
    - [CALLER\_CANNOT\_INCREASE\_STAKE](#caller_cannot_increase_stake)
    - [MISSING\_UNSTAKE\_INTENT](#missing_unstake_intent)
    - [INTENT\_WINDOW\_NOT\_FINISHED](#intent_window_not_finished)
    - [UNEXPECTED\_BALANCE](#unexpected_balance)
    - [ONLY\_OPERATOR](#only_operator)
    - [FINAL\_STAKER\_INDEX\_ALREADY\_SET](#final_staker_index_already_set)
    - [CLAIM\_REWARDS\_FROM\_UNAUTHORIZED\_ADDRESS](#claim_rewards_from_unauthorized_address)
    - [CALLER\_IS\_NOT\_POOL\_CONTRACT](#caller_is_not_pool_contract)
    - [MISSING\_POOL\_CONTRACT](#missing_pool_contract)
    - [AMOUNT\_TOO\_HIGH](#amount_too_high)
    - [MISSMATCHED\_DELEGATION\_POOL](#missmatched_delegation_pool)
    - [MISSING\_UNDELEGATE\_INTENT](#missing_undelegate_intent)
    - [STAKER\_ALREADY\_HAS\_POOL](#staker_already_has_pool)
    - [STAKER\_INACTIVE](#staker_inactive)
    - [POOL\_MEMBER\_EXISTS](#pool_member_exists)
    - [AMOUNT\_IS\_ZERO](#amount_is_zero)
    - [POOL\_MEMBER\_DOES\_NOT\_EXIST](#pool_member_does_not_exist)
    - [UNDELEGATE\_IN\_PROGRESS](#undelegate_in_progress)
    - [CALLER\_CANNOT\_ADD\_TO\_POOL](#caller_cannot_add_to_pool)
    - [POOL\_CLAIM\_REWARDS\_FROM\_UNAUTHORIZED\_ADDRESS](#pool_claim_rewards_from_unauthorized_address)
    - [CALLER\_IS\_NOT\_STAKING\_CONTRACT](#caller_is_not_staking_contract)
    - [SWITCH\_POOL\_DATA\_DESERIALIZATION\_FAILED](#switch_pool_data_deserialization_failed)
    - [ONLY\_SECURITY\_AGENT](#only_security_agent)
    - [ONLY\_SECURITY\_ADMIN](#only_security_admin)
- [Structs](#structs)
    - [StakerPoolInfo](#stakerpoolinfo)
    - [StakerInfo](#stakerinfo)
    - [StakingContractInfo](#stakingcontractinfo)
    - [PoolMemberInfo](#poolmemberinfo)
    - [PoolContractInfo](#poolcontractinfo)
    - [RewardSupplierStatus](#rewardsupplierstatus)

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
## L2 Contracts block diagram
```mermaid
classDiagram
  class StakingContract{
    map < staker_address, Option < StakerInfo >>
    map < operational_address, staker_address >
    global_index
    global_index_last_update_timestamp
    min_stake
    total_stake
    pool_contract_class_hash
    map < UndelegateIntentKey, UndelegateIntentValue >
    pool_contract_admin
    is_paused
    stake()
    increase_stake()
    unstake_intent()
    unstake_action()
    claim_rewards()
    add_stake_from_pool()
    remove_from_delegation_pool_intent()
    remove_from_delegation_pool_action()
    switch_staking_delegation_pool()
    change_reward_address()
    change_operational_address()
    set_open_for_delegation()
    claim_delegation_pool_rewards()
    state_of()
    contract_parameters()
    calculate_rewards()
    get_total_stake()

  }
  class DelegationPoolContract{
    map < pool_member_address, PoolMemberInfo >
    staker_address
    final_staker_index
    map < ContractAddress, Option < PoolMemberInfo >>
    commission
    enter_delegation_pool()
    add_to_delegation_pool()
    exit_delegation_pool_intent()
    exit_delegation_pool_action()
    claim_rewards()
    change_reward_address()
    state_of()
    contract_parameters()
    switch_delegation_pool()
    enter_delegation_pool_from_staking_contract()
    set_final_staker_index()
    calculate_rewards()
  }
  class StakerInfo{
    reward_address
    operational_address
    option < unstake_time >
    amount_own
    index
    pooled_amount
    unclaimed_rewards_own
    pooled_unclaimed_rewards
    option < StakerPoolInfo >
  }
  class StakerPoolInfo{
    pool_contract
    amount
    unclaimed_rewards
    commission
  }
  class PoolMemberInfo{
    reward_address
    amount
    index
    unclaimed_rewards
    option < unpool_time >
  }
  class RewardSupplier {
    last_timestamp,
    unclaimed_rewards,
    l1_pending_requested_amount,
    base_mint_amount,
    base_mint_msg,
    minting_curve_dispatcher,
    staking_contract,
    erc20_dispatcher,
    l1_staking_minter,
    calculate_staking_rewards()
    claim_rewards()
    on_receive()
    state_of()
  }
  class MintingCurve {
    staking_dispatcher,
    total_supply,
    l1_staking_minter_address,
    yearly_mint()
  }
  StakingContract o-- StakerInfo
  StakerInfo o-- StakerPoolInfo
  DelegationPoolContract o-- PoolMemberInfo
  StakingContract o-- RewardSupplier
  RewardSupplier o-- MintingCurve
```

## L1 Contracts block diagram
```mermaid
classDiagram
  class RewardSupplier {
    tick()
  }
  class MintManager {
    mintRequest()
    allowance()
    approve()
    increaseAllowance()
    decreaseAllowance()
    stopAllowance()
  }
```

## Enter protocol flow diagram
```mermaid
sequenceDiagram
  actor staker
  participant StakingContract
  participant DelegationPoolContract
  actor pool member
  staker ->>+ StakingContract: stake<br/>(pool enabled = true)
  StakingContract -->> DelegationPoolContract: deploy delegation pool contract
  par
    loop
      staker ->> StakingContract: increase_stake
    end
  and
    loop
      pool member ->>+ DelegationPoolContract: enter_delegation_pool
      DelegationPoolContract ->>- StakingContract: add_stake_from_pool
      loop
        pool member ->>+ DelegationPoolContract: add_to_delegation_pool
        DelegationPoolContract ->>- StakingContract: add_stake_from_pool
      end
    end
  end
```

## Exit protocol flow diagram
```mermaid
sequenceDiagram
  actor staker
  participant StakingContract
  participant DelegationPoolContract
  actor pool member
  opt Loop
    pool member ->>+ DelegationPoolContract: exit_delegation_pool_intent
    DelegationPoolContract ->>- StakingContract: remove_from_delegation_pool_intent
    pool member ->>+ DelegationPoolContract: exit_delegation_pool_action
    DelegationPoolContract ->>- StakingContract: remove_from_delegation_pool_action
  end
  staker ->> StakingContract: unstake_intent
  staker ->> StakingContract: unstake_action
  opt Loop
    pool member ->>+ DelegationPoolContract: exit_delegation_pool_intent
    DelegationPoolContract ->>- StakingContract: remove_from_delegation_pool_intent
    pool member ->>+ DelegationPoolContract: exit_delegation_pool_action
    DelegationPoolContract ->>- StakingContract: remove_from_delegation_pool_action
  end
```

## Rewards claim flow diagram
```mermaid
sequenceDiagram
  actor staker
  participant RewardSupplier
  participant StakingContract
  participant DelegationPoolContract
  actor pool member
  Loop
    staker ->> StakingContract: claim_rewards
    StakingContract ->>+ RewardSupplier: claim_rewards
    RewardSupplier -->> StakingContract: Transfer
    StakingContract -->> staker: Transfer
  end
  opt Loop
    pool member ->>+ DelegationPoolContract: claim_rewards
    DelegationPoolContract ->>+ StakingContract: claim_delegation_pool_rewards
    StakingContract ->>+ RewardSupplier: claim_rewards
    RewardSupplier -->> StakingContract: Transfer
    StakingContract -->> DelegationPoolContract: Transfer
    DelegationPoolContract -->> pool member: Transfer
  end
```

## Delegation pool switching flow diagram
```mermaid
sequenceDiagram
  participant DelegationPoolContract B
  participant StakingContract
  participant DelegationPoolContract A
  actor pool member
  pool member ->>+ DelegationPoolContract A: exit_delegation_pool_intent
  DelegationPoolContract A ->>- StakingContract: remove_from_delegation_pool_intent
  pool member ->>+ DelegationPoolContract A: switch_delegation_pool
  DelegationPoolContract A ->>+ StakingContract: switch_staking_delegation_pool
  StakingContract ->>- DelegationPoolContract B: enter_delegation_pool_from_staking_contract
  deactivate DelegationPoolContract A
  loop 
    Note left of StakingContract:  optional for switching some<br/> of the funds but keeping the rest<br/> with the original stakeror splitting<br/> between multiple stakers
    pool member ->>+ DelegationPoolContract A: switch_delegation_pool
    DelegationPoolContract A ->> StakingContract: switch_staking_delegation_pool
    StakingContract ->> DelegationPoolContract B: enter_delegation_pool_from_staking_contract
    deactivate DelegationPoolContract A
  end
```

## L1 Mint & transfer flow diagram
```mermaid
sequenceDiagram
  actor anyAccount
  participant RewardSupplier
  participant MintingManager
  participant STRK ERC20
  participant StarkGate bridge
  anyAccount ->>+ RewardSupplier: tick(tokensPerMintAmount, maxMessagesToProcess)
  RewardSupplier ->>+ MintingManager: mintRequest(totalAmountToMint)
  MintingManager ->>- STRK ERC20: mint
  RewardSupplier ->>+ StarkGate bridge: depositWithMessage
  deactivate RewardSupplier
```

## L2 Rewards calculation and minting request flow diagram
```mermaid
sequenceDiagram
  actor caller
  participant Staking
  participant RewardSupplier
  participant MintingCurve
  participant L1
  caller ->>+ Staking: update_global_index
  Staking ->>+ RewardSupplier: calculate_staking_rewards
  RewardSupplier ->>+ MintingCurve: yearly_mint
  MintingCurve ->> Staking: get_total_stake
  MintingCurve -->>- RewardSupplier: return yearly amount
  RewardSupplier ->>- L1: send mint request
  deactivate Staking
```


# Staking contract
## Functions
### stake
```rust
fn stake(
  ref self: TContractState,
  reward_address: ContractAddress,
  operational_address: ContractAddress,
  amount: u128,
  pool_enabled: bool,
  commission: u16
) -> bool
```
#### description <!-- omit from toc -->
Add a new staker to the stake.
#### emits <!-- omit from toc -->
1. [New Delegation Pool](#new-delegation-pool) - if `pool_enabled` is true
2. [Stake Balance Changed](#stake-balance-changed)
3. [New Staker](#new-staker)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_EXISTS](#staker_exists)
4. [OPERATIONAL\_EXISTS](#operational_exists)
5. [AMOUNT\_LESS\_THAN\_MIN\_STAKE](#amount_less_than_min_stake)
6. [COMMISSION\_OUT\_OF\_RANGE](#commission_out_of_range)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Staker (caller)  has operator role.
3. Staker (caller) is not listed in the contract.
4. `operational_address` is not listed in the contract.
5. `amount` is above the minimum amount for staking.
6. `commission` is not above the maximum commission for staking.
#### access control <!-- omit from toc -->
Only staker address.
#### logic  <!-- omit from toc -->
1. Transfer amount from staker to be locked in the contract.
2. Create a new registry for the staker (caller).
3. Set:
   1. Staker index = current global index.
   2. Unclaimed amount = 0.
   3. amount = given amount.
4. If pool enabled then deploy a pool contract instance.

### increase_stake
```rust
fn increase_stake(
    ref self: ContractState, 
    staker_address: ContractAddress, 
    amount: u128
) -> u128
``` 
#### description <!-- omit from toc -->
Increase the amount staked for an existing staker.
Return the updated total amount.
#### emits <!-- omit from toc -->
[Stake Balance Changed](#stake-balance-changed)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
4. [UNSTAKE\_IN\_PROGRESS](#unstake_in_progress)
5. [CALLER\_CANNOT\_INCREASE\_STAKE](#caller_cannot_increase_stake)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. `caller_address` has operator role.
3. Staker is listed in the contract.
4. Staker is not in an exit window.
#### access control <!-- omit from toc -->
Only the staker address or rewards address for which the change is requested for.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards).
2. Increase staked amount.

### unstake_intent
```rust
fn unstake_intent(ref self: ContractState) -> u64
```
#### description <!-- omit from toc -->
Inform of the intent to exit the stake. 
This will remove the funds from the stake, pausing rewards collection for the staker and it's pool members (if exist).
This will also start the exit window timeout.
Return the time in which the staker will be able to unstake.
#### emits <!-- omit from toc -->
1. [Staker Exit Intent](#staker-exit-intent)
2. [Stake Balance Changed](#stake-balance-changed)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
4. [UNSTAKE\_IN\_PROGRESS](#unstake_in_progress)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Staker (caller) has operator role.
3. Staker (caller) is listed in the contract.
4. Staker (caller) is not in an exit window.
#### access control <!-- omit from toc -->
Only the staker address for which the operation is requested for.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards).
2. Set unstake time.

### unstake_action
```rust
fn unstake_action(
  ref self: ContractState, 
  staker_address: ContractAddress
) -> u128
```
#### description <!-- omit from toc -->
Executes the intent to exit the stake if enough time have passed.
Transfers the funds back to the staker.
Return the amount of tokens transferred back to the staker.
#### emits <!-- omit from toc -->
1. [Staker Reward Claimed](#staker-reward-claimed)
2. If pool exists: [Rewards Supplied To Delegation Pool](#rewards-supplied-to-delegation-pool)
3. If pool exists: [Final Index Set](#final-index-set)
4. [Delete Staker](#delete-staker)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
4. [MISSING\_UNSTAKE\_INTENT](#missing_unstake_intent)
5. [INTENT\_WINDOW\_NOT\_FINISHED](#intent_window_not_finished)
6. [UNEXPECTED\_BALANCE](#unexpected_balance)
7. [FINAL\_STAKER\_INDEX\_ALREADY\_SET](#final_staker_index_already_set)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Staker (caller) has operator role.
3. Staker exist and requested to unstake.
4. Enough time have passed from the unstake intent call.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. Claim rewards.
2. Remove funds and transfer to staker.
3. Transfer pool unclaimed rewards and stake to delegation pool contract.
4. Call [set\_final\_staker\_index](#set_final_staker_index) on the delegation_pool_contract.
5. Delete staker record.

### claim_rewards
```rust
fn claim_rewards(
  ref self: ContractState, 
  staker_address: ContractAddress
) -> u128
```
#### description <!-- omit from toc -->
Calculate rewards and transfer them to the reward address.
Return the amount of tokens transferred to the reward address.
#### emits <!-- omit from toc -->
1. [Staker Reward Claimed](#staker-reward-claimed)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
4. [CLAIM\_REWARDS\_FROM\_UNAUTHORIZED\_ADDRESS](#claim_rewards_from_unauthorized_address)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. `caller_address` has operator role.
3. Staker is listed in the contract.
#### access control <!-- omit from toc -->
Only staker address or reward address can execute.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards).
2. Transfer unclaimed_rewards.
3. Set unclaimed_rewards = 0.

### add_stake_from_pool
```rust
fn add_stake_from_pool(
    ref self: ContractState, 
    staker_address: ContractAddress, 
    amount: u128
) -> (u128, u64)
```
#### description <!-- omit from toc -->
Delegation pool contract's way to add funds to the staking pool.
#### return <!-- omit from toc -->
pool_amount: u128 - total pool amount after addition.
index: u64 - updated index
#### emits <!-- omit from toc -->
1. [Stake Balance Changed](#stake-balance-changed)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
4. [UNSTAKE\_IN\_PROGRESS](#unstake_in_progress)
5. [MISSING\_POOL\_CONTRACT](#missing_pool_contract)
6. [CALLER\_IS\_NOT\_POOL\_CONTRACT](#caller_is_not_pool_contract)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Pool contract (caller) has operator role.
3. Staker is listed in the contract.
4. Staker is not in an exit window.
5. Staker has pool contract.
#### access control <!-- omit from toc -->
Only pool contract for the given staker can execute.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards)
2. transfer funds from pool contract to staking contract.
3. Add amount to staker's pooled amount

### remove_from_delegation_pool_intent
```rust
fn remove_from_delegation_pool_intent(
    ref self: ContractState,
    staker_address: ContractAddress,
    identifier: felt252,
    amount: u128,
) -> u64
```
#### description <!-- omit from toc -->
Inform the staker that an amount will be reduced from the delegation pool.
Return the time in which the pool member will be able to exit.
#### emits <!-- omit from toc -->
1. [Stake Balance Changed](#stake-balance-changed)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
4. [MISSING\_POOL\_CONTRACT](#missing_pool_contract)
5. [CALLER\_IS\_NOT\_POOL\_CONTRACT](#caller_is_not_pool_contract)
6. [AMOUNT\_TOO\_HIGH](#amount_too_high)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Pool contract (caller) has operator role.
3. Staker is listed in the contract.
4. Staker has pool contract.
5. Pooled amount is greater or equal then amount requested to remove.
#### access control <!-- omit from toc -->
Only pool contract for the given staker can execute.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards).
2. Remove amount from staker's pooled amount.
3. Register intent with given identifier, amount and unstake_time.

### remove_from_delegation_pool_action
```rust
fn remove_from_delegation_pool_action(
    ref self: ContractState, 
    identifier: felt252
) -> u128
```
#### description <!-- omit from toc -->
Execute the intent to remove funds from pool if enough time have passed.
Transfers the funds to the pool contract.
Return the amount being transferred to the pool contract.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [INTENT\_WINDOW\_NOT\_FINISHED](#intent_window_not_finished)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. `caller_address` has operator role.
3. Removal intent request with the given `identifier` have been sent before.
4. Enough time have passed since the intent request.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. Transfer funds from staking contract to pool contract.
2. Remove intent from staker's list.

### switch_staking_delegation_pool
```rust
fn switch_staking_delegation_pool(
    ref self: ContractState,
    to_staker: ContractAddress,
    to_pool: ContractAddress,
    switched_amount: u128,
    data: Span<felt252>,
    identifier: felt252
) -> bool
```
#### description <!-- omit from toc -->
Execute a pool member request to move from one staker's delegation pool to another staker's delegation pool.
Return true upon success, otherwise return false.
#### emits <!-- omit from toc -->
1. [Delegation Pool Member Balance Changed](#delegation-pool-member-balance-changed)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [MISSING\_UNDELEGATE\_INTENT](#missing_undelegate_intent)
4. [AMOUNT\_TOO\_HIGH](#amount_too_high)
5. [STAKER\_NOT\_EXISTS](#staker_not_exists)
6. [UNSTAKE\_IN\_PROGRESS](#unstake_in_progress)
7. [MISSING\_POOL\_CONTRACT](#missing_pool_contract)
8. [MISSMATCHED\_DELEGATION\_POOL](#missmatched_delegation_pool)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Pool contract (caller) has operator role.
3. `switched_amount` is not zero.
4. Enough funds is in intent for switching.
5. `to_staker` exist in the contract and is not in exit window.
6. `to_pool` is the delegation pool contract for `to_staker`.
#### access control <!-- omit from toc -->
Only pool contract for the given staker can execute.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards).
2. Remove requested amount from the caller pool intent amount.
3. Add requested amount to `to_staker`'s pool with pool contract address `to_pool`.
4. Call `to_pool`'s [enter\_delegation\_pool\_from\_staking\_contract](#enter_delegation_pool_from_staking_contract) function.

### change_reward_address
```rust
fn change_reward_address(
  ref self: ContractState, 
  reward_address: ContractAddress
) -> bool
```
#### description <!-- omit from toc -->
Change the reward address for a staker.
#### emits <!-- omit from toc -->
1. [Staker Reward Address Changed](#staker-reward-address-changed)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Staker (caller) has operator role.
3. Staker (caller) exist in the contract.
#### access control <!-- omit from toc -->
Only staker address.
#### logic <!-- omit from toc -->
1. Change registered `reward_address` for the staker.

### set_open_for_delegation
```rust
fn set_open_for_delegation(
  ref self: ContractState, 
  commission: u16
) -> ContractAddress
```
#### description <!-- omit from toc -->
Creates a staking delegation pool for a staker that doesn't have one.
Return the pool address.
#### emits <!-- omit from toc -->
1. [New Delegation Pool](#new-delegation-pool)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
4. [COMMISSION\_OUT\_OF\_RANGE](#commission_out_of_range)
5. [STAKER\_ALREADY\_HAS\_POOL](#staker_already_has_pool)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Staker (caller) has operator role.
3. Staker (caller) exist in the contract.
4. `commission` is in valid range.
5. Staker has no pool.
#### access control <!-- omit from toc -->
Only staker address.
#### logic <!-- omit from toc -->
1. Generate pool contract for staker.
2. Register pool.

### claim_delegation_pool_rewards
```rust
fn claim_delegation_pool_rewards(
    ref self: ContractState, 
    staker_address: ContractAddress
) -> u64
```
#### description <!-- omit from toc -->
Calculate rewards and transfer the delegation pool rewards to the delegation pool contract.
Return the updated staker index.
#### emits <!-- omit from toc -->
[Rewards Supplied To Delegation Pool](#rewards-supplied-to-delegation-pool)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
4. [MISSING\_POOL\_CONTRACT](#missing_pool_contract)
5. [CALLER\_IS\_NOT\_POOL\_CONTRACT](#caller_is_not_pool_contract)
6. [AMOUNT\_TOO\_HIGH](#amount_too_high)
7. [UNEXPECTED\_BALANCE](#unexpected_balance)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Pool contract (caller) has operator role.
3. Staker exist in the contract.
4. Delegation pool exist for the staker.
#### access control <!-- omit from toc -->
Delegation pool contract of the given staker.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards)
2. Transfer rewards to pool contract.

### state_of
```rust
fn state_of(
  self: @ContractState, 
  staker_address: ContractAddress
) -> StakerInfo
```
#### description <!-- omit from toc -->
Return [StakerInfo](#stakerinfo) of the given staker.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
#### pre-condition <!-- omit from toc -->
1. Staker exist in the contract.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. Return Staker's info.

### contract_parameters
```rust
fn contract_parameters(self: @ContractState) -> StakingContractInfo
```
#### description <!-- omit from toc -->
Return general parameters of the contract.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
#### logic <!-- omit from toc -->

### get_total_stake
```rust
get_total_stake(self: @ContractState) -> u128
```
#### description <!-- omit from toc -->
Return the total stake amount.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
#### logic <!-- omit from toc -->


### calculate_rewards
>**note:** internal logic
```rust
fn calculate_rewards(
  ref self: ContractState, 
  ref staker_info: StakerInfo
) -> bool
```
#### description <!-- omit from toc -->
Calculate rewards, add amount to unclaimed_rewards, update index.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
Internal function.
#### logic <!-- omit from toc -->
1. If Staker is in an exit window, return false.
2. Update index.
3. Calculate rewards for `amount_own`.
4. Calculate rewards for `pool_info.amount`.
5. Update `unclaimed_rewards_own` with own rewards + pool rewards commission.
6. Update `pool_info.unclaimed_rewards` with pool rewards without commission. 

### change_operational_address
```rust
fn change_operational_address(
    ref self: ContractState, 
    operational_address: ContractAddress
) -> bool
```
#### description <!-- omit from toc -->
Change the operational address for a staker.
#### emits <!-- omit from toc -->
1. [Operational Address Changed](#operational-address-changed)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
3. [STAKER\_NOT\_EXISTS](#staker_not_exists)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Staker (caller) has operator role.
3. Staker (caller) exist in the contract.
#### access control <!-- omit from toc -->
Only staker address.
#### logic <!-- omit from toc -->
1. Change registered `operational_address` for the staker.

### update_global_index_if_needed
```rust
fn update_global_index_if_needed(ref self: TContractState) -> bool
```
#### description <!-- omit from toc -->
Update the global index if enough time has passed since the last update.
This function is called in every staking function that alter the state.
Return `true` if the index has been updated.
#### emits <!-- omit from toc -->
1. [Global Index Updated](#global-index-updated)
#### errors <!-- omit from toc -->
1. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
2. [ONLY\_OPERATOR](#only_operator)
#### pre-condition <!-- omit from toc -->
1. Staking contract is unpaused.
2. Caller has operator role.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. Check if enough time has passed since the last update, if not, return `false`.
2. [calculate\_staking\_rewards](#calculate_staking_rewards).
3. [get_total_stake](#get_total_stake).
4. Update the global index.

### is_paused
```rust
fn is_paused(self: @TContractState) -> bool
```
#### description <!-- omit from toc -->
Return `true` if the staking contract is paused.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->

### pause
```rust
fn pause(ref self: TContractState)
```
#### description <!-- omit from toc -->
Pause the staking contract.
#### emits <!-- omit from toc -->
1. [Paused](#paused)
#### errors <!-- omit from toc -->
1. [ONLY\_SECURITY\_AGENT](#only_security_agent)
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
Only security agent.
#### logic <!-- omit from toc -->

### unpause
```rust
fn unpause(ref self: TContractState)
```
#### description <!-- omit from toc -->
Unpause the staking contract.
#### emits <!-- omit from toc -->
1. [Unpaused](#unpaused)
#### errors <!-- omit from toc -->
1. [ONLY\_SECURITY\_ADMIN](#only_security_admin)
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
Only security admin.
#### logic <!-- omit from toc -->

## Events
### Stake Balance Changed
| data                | type    | keyed |
| ------------------- | ------- | ----- |
| staker_address      | address | ✅     |
| old_self_stake      | u128    | ❌     |
| old_delegated_stake | u128    | ❌     |
| new_self_stake      | u128    | ❌     |
| new_delegated_stake | u128    | ❌     |

### New Delegation Pool
| data           | type    | keyed |
| -------------- | ------- | ----- |
| staker_address | address | ✅     |
| pool_contract  | address | ✅     |
| commission     | u16     | ❌     |

### New Staker
| data                | type    | keyed |
| ------------------- | ------- | ----- |
| staker_address      | address | ✅     |
| reward_address      | address | ❌     |
| operational_address | address | ❌     |
| self_stake          | u128    | ❌     |

### Staker Exit intent
| data    | type    | keyed |
| ------- | ------- | ----- |
| staker  | address | ✅     |
| exit_at | time    | ❌     |

### Rewards Supplied To Delegation Pool
| data           | type    | keyed |
| -------------- | ------- | ----- |
| staker_address | address | ✅     |
| pool_address   | address | ✅     |
| amount         | u128    | ❌     |

### Delete Staker
| data                | type            | keyed |
| ------------------- | --------------- | ----- |
| staker_address      | address         | ✅     |
| reward_address      | address         | ❌     |
| operational_address | address         | ❌     |
| pool_contract       | Option<address> | ❌     |

### Staker Reward Claimed
| data           | type    | keyed |
| -------------- | ------- | ----- |
| staker_address | address | ✅     |
| reward_address | address | ❌     |
| amount         | u128    | ❌     |

### Staker Reward Address Changed
| data           | type    | keyed |
| -------------- | ------- | ----- |
| staker_address | address | ✅     |
| new_address    | address | ❌     |
| old_address    | address | ❌     |

### Operational Address Changed
| data           | type    | keyed |
| -------------- | ------- | ----- |
| staker_address | address | ✅     |
| new_address    | address | ❌     |
| old_address    | address | ❌     |

### Global Index Updated
| data                                  | type | keyed |
| ------------------------------------- | ---- | ----- |
| old_index                             | u64  | ❌     |
| new_index                             | u64  | ❌     |
| global_index_last_update_timestamp    | u64  | ❌     |
| global_index_current_update_timestamp | u64  | ❌     |

### Paused
| data    | type    | keyed |
| ------- | ------- | ----- |
| account | address | ❌    |

### Unpaused
| data    | type    | keyed |
| ------- | ------- | ----- |
| account | address | ❌    |

# Delegation pool contract

## Functions
### enter_delegation_pool
```rust
fn enter_delegation_pool(
    ref self: ContractState, 
    reward_address: ContractAddress, 
    amount: u128
) -> bool
```
#### description <!-- omit from toc -->
Add a new pool member to the delegation pool.
#### emits <!-- omit from toc -->
1. [Stake Balance Changed](#stake-balance-changed)
2. [New Pool Member](#new-pool-member)
3. [Delegation Pool Member Balance Changed](#delegation-pool-member-balance-changed)
#### errors <!-- omit from toc -->
1. [STAKER\_INACTIVE](#staker_inactive)
2. [POOL\_MEMBER\_EXISTS](#pool_member_exists)
3. [AMOUNT\_IS\_ZERO](#amount_is_zero)
4. [INSUFFICIENT\_ALLOWANCE](#insufficient_allowance)
5. [UNSTAKE\_IN\_PROGRESS](#unstake_in_progress)
#### pre-condition <!-- omit from toc -->
1. Staker is active and not in an exit window.
2. `caller_address` is not listed in the contract as a pool member.
3. `amount` is not zero.
4. `caller_address` has enough funds.
#### access control <!-- omit from toc -->
Only a non-listed pool member address.
#### logic <!-- omit from toc -->
1. Transfer funds from pool member to pool contract.
2. Approve transferal from pool contract to staking contract.
3. Call staking contract's [add_stake_from_pool](#add_stake_from_pool).
4. Get current index from staking contract.
5. Create entry for pool member.

### add_to_delegation_pool
```rust
fn add_to_delegation_pool(
    ref self: ContractState, 
    pool_member: ContractAddress, 
    amount: u128
) -> u128
```
#### description <!-- omit from toc -->
Increase the funds for an existing pool member.
Return the updated total amount.
#### emits <!-- omit from toc -->
1. [Stake Balance Changed](#stake-balance-changed)
2. [Delegation Pool Member Balance Changed](#delegation-pool-member-balance-changed)
#### errors <!-- omit from toc -->
1. [STAKER\_INACTIVE](#staker_inactive)
2. [POOL\_MEMBER\_DOES\_NOT\_EXIST](#pool_member_does_not_exist)
3. [CALLER\_CANNOT\_ADD\_TO\_POOL](#caller_cannot_add_to_pool)
4. [UNSTAKE\_IN\_PROGRESS](#unstake_in_progress)
#### pre-condition <!-- omit from toc -->
1. Staker is active and not in an exit window.
2. `pool_member` listed in the contract.
3. `pool_member` has enough funds.
#### access control <!-- omit from toc -->
Only the pool member address or rewards address for which the change is requested for.
#### logic <!-- omit from toc -->
1. Transfer funds from caller to the contract.
2. Call staking contract's [add_stake_from_pool](#add_stake_from_pool).
3. Get current index from staking contract.
4. [Calculate rewards](#calculate_rewards-1)
5. Update pool member entry with
   1. index
   2. amount
   3. unclaimed rewards

### exit_delegation_pool_intent
```rust
fn exit_delegation_pool_intent(
  ref self: ContractState, 
  amount: u128
)
```
#### description <!-- omit from toc -->
Inform of the intent to exit the stake. This will remove the funds from the stake, pausing rewards collection for the pool member. This will also start the exit window timeout.
#### emits <!-- omit from toc -->
1. If staker is active: [Rewards Supplied To Delegation Pool](#rewards-supplied-to-delegation-pool)
2. If staker is active: [Stake Balance Changed](#stake-balance-changed)
3. [Pool Member Exit Intent](#pool-member-exit-intent)
#### errors <!-- omit from toc -->
1. [POOL\_MEMBER\_DOES\_NOT\_EXIST](#pool_member_does_not_exist)
2. [AMOUNT\_TOO\_HIGH](#amount_too_high)
3. [UNDELEGATE\_IN\_PROGRESS](#undelegate_in_progress)
4. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
5. [ONLY\_OPERATOR](#only_operator)
#### pre-condition <!-- omit from toc -->
1. Pool member (caller) is listed in the contract.
2. `amount` is lower or equal to the total amount of the pool member (caller). 
3. Pool member (caller) is not in an exit window or staker is active.
4. Staking contract is unpaused.
#### access control <!-- omit from toc -->
Only the pool member address for which the operation is requested for.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards-1)
2. If staker is active, call [remove from delegation pool intent](#remove_from_delegation_pool_intent)
3. If `amount` is zero, remove request for intent (if exist).
4. If `amount` is not zero, set exit window timeout.

### exit_delegation_pool_action
```rust
fn exit_delegation_pool_action(
    ref self: ContractState, 
    pool_member: ContractAddress
) -> u128
```
#### description <!-- omit from toc -->
Executes the intent to exit the stake if enough time have passed. Transfers the funds back to the pool member.
Return the amount of tokens transferred back to the pool member.
#### emits <!-- omit from toc -->
1. [Pool Member Reward Claimed](#pool-member-reward-claimed)
2. [Delete Pool Member](#delete-pool-member)
#### errors <!-- omit from toc -->
1. [POOL\_MEMBER\_DOES\_NOT\_EXIST](#pool_member_does_not_exist)
2. [MISSING\_UNDELEGATE\_INTENT](#missing_undelegate_intent)
3. [INTENT\_WINDOW\_NOT\_FINISHED](#intent_window_not_finished)
4. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
5. [ONLY\_OPERATOR](#only_operator)
#### pre-condition <!-- omit from toc -->
1. Pool member exist and requested to unstake.
2. Enough time have passed from the delegation pool exit intent call.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. [Remove from delegation pool action](#remove_from_delegation_pool_action).
2. Transfer rewards to pool member.
3. Transfer funds to pool member.


### claim_rewards
```rust
fn claim_rewards(
  ref self: ContractState, 
  pool_member: ContractAddress
) -> u128
```
#### description <!-- omit from toc -->
Calculate rewards and transfer them to the reward address.
Return the amount transferred to the reward address.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
1. [POOL\_MEMBER\_DOES\_NOT\_EXIST](#pool_member_does_not_exist)
2. [POOL\_CLAIM\_REWARDS\_FROM\_UNAUTHORIZED\_ADDRESS](#pool_claim_rewards_from_unauthorized_address)
3. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
4. [ONLY\_OPERATOR](#only_operator)
5. [UNEXPECTED\_BALANCE](#unexpected_balance)
6. [AMOUNT\_TOO\_HIGH](#amount_too_high)
#### pre-condition <!-- omit from toc -->
1. `pool_member` is listed in the contract.
#### access control <!-- omit from toc -->
Only pool member address or reward address can execute.
#### logic <!-- omit from toc -->
1. [Calculate rewards](#calculate_rewards-1).
2. Transfer unclaimed_rewards
3. Set unclaimed_rewards = 0.

### switch_delegation_pool
```rust
fn switch_delegation_pool(
    ref self: ContractState,
    to_staker: ContractAddress,
    to_pool: ContractAddress,
    amount: u128
) -> u128
```
#### description <!-- omit from toc -->
Request the staking contract to move a pool member to another pool contract.
Return the amount left in exit window for the pool member in this pool.
#### emits <!-- omit from toc -->
1. [Delegation Pool Member Balance Changed](#delegation-pool-member-balance-changed)
2. If pool member amount and intent amount are zero: [Delete Pool Member](#delete-pool-member)
#### errors <!-- omit from toc -->
1. [AMOUNT\_IS\_ZERO](#amount_is_zero)
2. [POOL\_MEMBER\_DOES\_NOT\_EXIST](#pool_member_does_not_exist)
3. [MISSING\_UNDELEGATE\_INTENT](#missing_undelegate_intent)
4. [AMOUNT\_TOO\_HIGH](#amount_too_high)
5. [CONTRACT\_IS\_PAUSED](#contract_is_paused)
6. [ONLY\_OPERATOR](#only_operator)
7. [UNSTAKE\_IN\_PROGRESS](#unstake_in_progress)
8. [MISSMATCHED\_DELEGATION\_POOL](#missmatched_delegation_pool)
#### pre-condition <!-- omit from toc -->
1. `amount` is not zero.
2. Pool member (caller) is in exit window.
3. Pool member's amount is greater or equal to the amount requested.
4. `to_staker` exist in the staking contract and is not in an exit window.
5. `to_pool` is the delegation pool contract for `to_staker`.
#### access control <!-- omit from toc -->
Only pool member can execute.
#### logic <!-- omit from toc -->
1. Compose and serialize data: pool member address and reward address.
2. If pool member amount and intent amount are zero, transfer rewards to pool member and remove him from the pool. 
3. Call staking contract's [switch delegation pool](#switch_staking_delegation_pool).

### enter_delegation_pool_from_staking_contract
```rust
fn enter_delegation_pool_from_staking_contract(
    ref self: ContractState, 
    amount: u128, 
    index: u64, 
    data: Span<felt252>
) -> bool
```
#### description <!-- omit from toc -->
Entry point for staking contract to inform pool of a pool member being moved from another pool to this one.
No funds need to be transferred since staking contract holds the pool funds.
#### emits <!-- omit from toc -->
1. [Delegation Pool Member Balance Changed](#delegation-pool-member-balance-changed)
#### errors <!-- omit from toc -->
1. [AMOUNT\_IS\_ZERO](#amount_is_zero)
2. [CALLER\_IS\_NOT\_STAKING\_CONTRACT](#caller_is_not_staking_contract)
3. [SWITCH\_POOL\_DATA\_DESERIALIZATION\_FAILED](#switch_pool_data_deserialization_failed)
#### pre-condition <!-- omit from toc -->
1. `amount` is not zero.
2. `pool_member` is not in an exit window.
#### access control <!-- omit from toc -->
Only staking contract can execute.
#### logic <!-- omit from toc -->
1. Deserialize data, get `pool_member` and `rewrad_address`.
2. If pool member is listed in the contract:
   1. [Calculate rewards](#calculate_rewards-1)
   2. Update pool member entry
3. Else
   1. Create an entry for the pool member.

### set_final_staker_index
```rust
fn set_final_staker_index(
  ref self: ContractState, 
  final_staker_index: u64
)
```
#### description <!-- omit from toc -->
Informs the delegation pool contract that the staker has left and the contract is now detached from the staking contract.
#### emits <!-- omit from toc -->
1. [Final Index Set](#final-index-set)
#### errors <!-- omit from toc -->
1. [CALLER\_IS\_NOT\_STAKING\_CONTRACT](#caller_is_not_staking_contract)
2. [FINAL\_STAKER\_INDEX\_ALREADY\_SET](#final_staker_index_already_set)
#### pre-condition <!-- omit from toc -->
1. Final staker index is not already set.
#### access control <!-- omit from toc -->
Only staking contract can execute.
#### logic <!-- omit from toc -->
1. Set staker final index to the provided index.

### change_reward_address
```rust
fn change_reward_address(
  ref self: ContractState, 
  reward_address: ContractAddress
) -> bool
```
#### description <!-- omit from toc -->
Change the reward address for a pool member.
#### emits <!-- omit from toc -->
1. [Pool Member Reward Address Changed](#pool-member-reward-address-changed)
#### errors <!-- omit from toc -->
1. [POOL\_MEMBER\_DOES\_NOT\_EXIST](#pool_member_does_not_exist)
#### pre-condition <!-- omit from toc -->
1. Pool member exist in the contract.
#### access control <!-- omit from toc -->
Only pool member can execute.
#### logic <!-- omit from toc -->
1. Change registered `reward_address` for the pool member.

### state_of
```rust
fn state_of(
  self: @ContractState, 
  pool_member: ContractAddress
) -> PoolMemberInfo
```
#### description <!-- omit from toc -->
Return [PoolMemberInfo](#poolmemberinfo) of the given pool member.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
1. [POOL\_MEMBER\_DOES\_NOT\_EXIST](#pool_member_does_not_exist)
#### pre-condition <!-- omit from toc -->
1. Pool member exist in the contract.
#### access control <!-- omit from toc -->
Any address can execute.
#### logic <!-- omit from toc -->
1. Return Pool member info.

### contract_parameters
```rust
fn contract_parameters(self: @ContractState) -> StakingContractInfo
```
#### description <!-- omit from toc -->
Return [PoolContractInfo](#poolcontractinfo) of the contract.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
#### logic <!-- omit from toc -->

### calculate_rewards
```rust
fn calculate_rewards(
    ref self: ContractState, 
    ref pool_member_info: PoolMemberInfo, 
    updated_index: u64
) -> bool
```
>**note:** internal logic
#### description <!-- omit from toc -->
Calculate rewards, add amount to unclaimed_rewards, update index.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### access control <!-- omit from toc -->
internal function.
#### logic <!-- omit from toc -->
1. Update index.
2. Calculate rewards for `pool_member_info`.
3. Update `unclaimed_rewards`.

## Events
### New Staking Delegation Pool Member
| data        | type    | keyed |
| ----------- | ------- | ----- |
| staker      | address | ✅     |
| pool_member | address | ✅     |
| amount      | u128    | ❌     |

### Delegation Pool Member Balance Changed
| data                | type    | keyed |
| ------------------- | ------- | ----- |
| pool_member         | address | ✅     |
| old_delegated_stake | u128    | ❌     |
| new_delegated_stake | u128    | ❌     |

### Pool Member Exit Intent
| data        | type    | keyed |
| ----------- | ------- | ----- |
| pool_member | address | ✅     |
| exit_at     | time    | ❌     |

### Final Index Set
| data               | type    | keyed |
| ------------------ | ------- | ----- |
| staker_address     | address | ✅     |
| final_staker_index | u64     | ❌     |

### New Pool Member
| data           | type    | keyed |
| -------------- | ------- | ----- |
| pool_member    | address | ✅     |
| staker_address | address | ✅     |
| reward_address | address | ❌     |
| amount         | u128    | ❌     |

### Delete Pool Member
| data           | type    | keyed |
| -------------- | ------- | ----- |
| pool_member    | address | ✅     |
| reward_address | address | ❌     |

### Pool Member Reward Claimed
| data           | type    | keyed |
| -------------- | ------- | ----- |
| pool_member    | address | ✅     |
| reward_address | address | ✅     |
| amount         | u128    | ❌     |

### Pool Member Reward Address Changed
| data           | type    | keyed |
| -------------- | ------- | ----- |
| pool_member    | address | ✅    |
| new_address    | address | ❌    |
| old_address    | address | ❌    |

# L2 Reward supplier contract

## Functions
### calculate_staking_rewards
```rust
fn calculate_staking_rewards(ref self: TContractState) -> u128
```
#### description <!-- omit from toc -->
Calculate the total amount of rewards owed to the stakers (based on total stake), since the previous
time it was calculated.
#### return <!-- omit from toc -->
rewards: u128 - the rewards owed to stakers, in FRI.
#### emits <!-- omit from toc -->
[Mint Request](#mint-request)
#### errors <!-- omit from toc -->
#### logic <!-- omit from toc -->
1. Invoke the Minting Curve's [yearly_mint](#yearly-mint) to receive the theoretic yearly amount of rewards.
2. From the theoretic yearly amount, deduce the rewards from the last timestamp.
3. Request funds from L1 if needed.

#### access control <!-- omit from toc -->
Only staking contract.

### claim_rewards
```rust
fn claim_rewards(ref self: TContractState, amount: u128)
```
#### description <!-- omit from toc -->
Transfers `amount` FRI to staking contract
#### return <!-- omit from toc -->
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
`unclaimed_rewards >= amount`

#### logic <!-- omit from toc -->
1. Transfer `amount` FRI to staking contract and decrease it from unclaimed_rewards.

#### access control <!-- omit from toc -->
Only staking contract.

### state_of
```rust
fn state_of(self: @TContractState) -> RewardSupplierStatus
```
#### description <!-- omit from toc -->
Return [RewardSupplierStatus](#rewardsupplierstatus) filled with the corresponding storage values.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### pre-condition <!-- omit from toc -->
#### logic <!-- omit from toc -->
#### access control <!-- omit from toc -->
Any address can execute.

### on_receive
```rust
fn on_receive(
    ref self: TContractState,
    l2_token: ContractAddress,
    amount: u256,
    depositor: EthAddress,
    message: Span<felt252>
) -> bool
```
#### description <!-- omit from toc -->
Get notified by StarkGate `amount` was transferred from L1.
Return true upon success. 
The function will fail only in the unlikely scenario where `amount` is over 2**128 FRI.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
- [AMOUNT\_TOO\_HIGH](#amount_too_high)
#### pre-condition <!-- omit from toc -->

#### logic <!-- omit from toc -->
1. Decrease `amount` from l1_pending_requested_amount. If the expected result is negative, the
variable is set to 0.

#### access control <!-- omit from toc -->

## Events
### Mint Request
| data         | type | keyed |
| ------------ | ---- | ----- |
| total_amount | u128 | ❌    |
| num_msgs     | u128 | ❌    |

# Minting Curve Contract

## Functions
### yearly_mint
```rust
fn yearly_mint(self: @TContractState) -> u128
```
#### description <!-- omit from toc -->
Return the amount to be minted in a year given the current total stake in the staking contract.
#### emits <!-- omit from toc -->
#### errors <!-- omit from toc -->
#### logic <!-- omit from toc -->
1. [get_total_stake](#get_total_stake).
2. Compute the yearly mint by using total_stake and total_supply.

#### access control <!-- omit from toc -->
Any address can execute.

## Events
### Total Supply Changed
| data                 | type | keyed |
| -------------------- | ---- | ----- |
| old_total_supply     | u128 | ❌    |
| new_total_supply     | u128 | ❌    |

# Errors
### STAKER_EXISTS
"Staker already exists, use increase_stake instead."

### STAKER_NOT_EXISTS
"Staker does not exist."

### OPERATIONAL_EXISTS
"Operational address already exists."

### AMOUNT_LESS_THAN_MIN_STAKE
"Amount is less than min stake - try again with enough funds."

### COMMISSION_OUT_OF_RANGE
"Commission is out of range, expected to be 0-10000."

### CONTRACT_IS_PAUSED
"Contract is paused."

### UNSTAKE_IN_PROGRESS
"Unstake is in progress, staker is in an exit window."

### CALLER_CANNOT_INCREASE_STAKE
"Caller address should be staker address or reward address."

### MISSING_UNSTAKE_INTENT
"Unstake intent is missing."

### INTENT_WINDOW_NOT_FINISHED
"Intent window is not finished."

### UNEXPECTED_BALANCE
"Unexpected balance."

### ONLY_OPERATOR
"ONLY_OPERATOR"

### FINAL_STAKER_INDEX_ALREADY_SET
"Final staker index already set."

### CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
"Claim rewards must be called from staker address or reward address."

### CALLER_IS_NOT_POOL_CONTRACT
"Caller is not pool contract."

### MISSING_POOL_CONTRACT
"Staker does not have a pool contract."

### AMOUNT_TOO_HIGH
"Amount is too high."

### MISSMATCHED_DELEGATION_POOL
"to_pool is not the delegation pool contract for to_staker."

### MISSING_UNDELEGATE_INTENT
"Undelegate intent is missing."

### STAKER_ALREADY_HAS_POOL
"Staker already has a pool."

### STAKER_INACTIVE
"Staker inactive."

### POOL_MEMBER_EXISTS
"Pool member exists, use add_to_delegation_pool instead."

### AMOUNT_IS_ZERO
"Amount is zero."

### POOL_MEMBER_DOES_NOT_EXIST
"Pool member does not exist."

### UNDELEGATE_IN_PROGRESS
"Undelegate from pool in progress, pool member is in an exit window."

### CALLER_CANNOT_ADD_TO_POOL
"Caller address should be pool member address or reward address."

### POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
"Claim rewards must be called from pool member address or reward address."

### CALLER_IS_NOT_STAKING_CONTRACT
"Caller is not staking contract."

### SWITCH_POOL_DATA_DESERIALIZATION_FAILED
"Switch pool data deserialization failed."

### ONLY_SECURITY_AGENT
"ONLY_SECURITY_AGENT"

### ONLY_SECURITY_ADMIN
"ONLY_SECURITY_ADMIN"

# Structs
### StakerPoolInfo
| name              | type    |
| ----------------- | ------- |
| pool_contract  | address |
| amount            | u128    |
| unclaimed_rewards | u128    |
| commission        | u16     |

### StakerInfo
| name                  | type                   |
| --------------------- | ---------------------- |
| reward_address        | address                |
| operational_address   | address                |
| unstake_time          | Option<u64>            |
| amount_own            | u128                   |
| index                 | u64                    |
| unclaimed_rewards_own | u128                   |
| pool_info             | Option<StakerPoolInfo> |

### StakingContractInfo
| name                     | type      |
| ------------------------ | --------- |
| min_stake                | u128      |
| token_address            | address   |
| global_index             | u64       |
| pool_contract_class_hash | ClassHash |
| reward_supplier          | address   |

### PoolMemberInfo
| name              | type        |
| ----------------- | ----------- |
| reward_address    | address     |
| amount            | u128        |
| index             | u64         |
| unclaimed_rewards | u128        |
| unpool_amount     | u128        |
| unpool_time       | Option<u64> |

### PoolContractInfo
| name               | type        |
| ------------------ | ----------- |
| staker_address     | address     |
| final_staker_index | Option<u64> |
| staking_contract   | address     |
| token_address      | address     |
| commission         | u16         |

### RewardSupplierStatus
| name                          | type      |
| ----------------------------- | --------- |
| last_timestamp                | u64       |
| unclaimed_rewards             | u128      |
| l1_pending_requested_amount   | u128      |
