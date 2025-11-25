# Flow Ideas
## Views
- Get staker info while staker has zero balance.
- staker change balance and test with view of current epoch balance
- member change balance and test with view of current epoch balance

## `update_rewards`
- staker with only btc pool.
- staker with empty pool (STRK + BTC).
- staker with 2 btc pools with different decimals.
- staker immediately/one epoch after he called intent.
- update rewards for 2 different blocks in the same epoch - should be same rewards.
- Change epoch len in blocks - rewards should be changed.
- disable_rewards = true, advance block, disable_rewards = false, advance block, disable_rewards = true, test rewards.
- update rewards for some different blocks in the same epoch, test rewards of pool member.
- staker change balance, attest, change balance, attest, set_v3, change balance, update_rewards, change_balance, update_rewards, test rewards.
- with member from previous versions.

## k=1 -> k=2 balances
- delegator claim rewards when last change is in epoch + 2, then advance epochs and claim again to see no missing rewards
- same as above, also when there is change in epoch + 1
- delegate, advance epoch and get rewards for the pool, claim - zero rewards for the delegate
- delegate, advance epoch, delegate, advance epoch, claim rewards - only for the first delegation, advance epoch, claim rewards - for all
- delegator claim after claim
- delegator claim after claim when exists checkpoint with the current epoch of the first claim
- staker change balance in each epoch (increase, intent, delegate increase, delegate intent, delegate exit) and attest in each epoch - test rewards (also some epochs with no balance change and some epochs with no attest)
- staker has multiple pool with multiple delegator each, change balance (staker, strk delegate, btc delegate) and attest in many epochs and test rewards both staker and members
- test staker claim rewards with more than one balance change in an epoch.
- member enter, in the same epoch or one epoch after claim (balance is zero).

## k=1 -> k=2 Migration Member
- Member change balances before migration, some attestations, upgrade, change balances , some update_rewards, test calculate rewards of the member
- Member only enter before migration, some attestations, upgrade, change balances , some update_rewards, test calculate rewards of the member
- Member only enter before migration, no rewards to pool at all, upgrade, claim rewards.
- Member only enter before migration, only one rewards to pool, upgrade, claim rewards.
- Member change balances before migration, upgrade, one rewards to pool, claim rewards.
- find_sigma_standard_case: Enter V1, change in V1, catch all ifs.
- find_sigma_standard_case: Enter V1, change in V2, catch all ifs.
- find sigma: Enter V0, change in V1, catch all ifs.
- find sigma: Enter V0, change in V2, catch all ifs.
- find sigma_edge_cases: catch the comments.
- find sigma - cover all branches with member from V0, V1, V2(V2 DONE).
- member from V0, update balance at V3 before getting rewards, pool gets rewards, test rewards.
- member from V0, pool gets rewards at V1, update balance at V3 before getting rewards, pool gets rewards, test rewards.
- member from V0, pool gets rewards at V1, pool gets rewards at V3, update balance, test rewards.
- member from V0, pool gets rewards at V1, pool gets rewards at V3, test rewards without update balance.
- member from V1(+V2), update balance at V3, pool gets rewards at V3, test rewards. (IDX=0)
- member from V1(+V2), update balance at V1, update balance at V3, test rewards. (IDX=1=LEN)
- member from V1(+V2), update balance at V1, pool gets rewards at V1, update balance at V3, test rewards. (IDX=1!=LEN)
- member from V1(+V2), pool gets rewards at V1, pool gets rewards at V1, update balance at V1, update balance at V3, test rewards (IDX=LEN)
- member from V1(+V2), pool gets_rewards at V1, pool gets rewards at V1, update balance at V1, pool gets rewards at V3,  update balance at V3, test rewards. (REGULAR CASE)
- member from V1(+V2), pool gets_rewards at V1, pool gets rewards at V1, update balance at V1, pool gets rewards at V1 same epoch, pool gets rewards at V3,  update balance at V3, test rewards. (REGULAR CASE)
- V0->V1->V3:
 - enter in V0, pool gets rewards in V1, change balance at V1, pool gets rewards in V1, pool gets rewards in V3, update balance at V3, pool gets rewards in V3, test rewards.
more ideas:
- member from V1, pool gets rewards at V1, update balance at V1, update balance at V3, pool gets rewards at V3, test rewards.
- member from V1, pool gets rewards at V1, pool gets rewards at V3, update balance at V3, test rewards.
- member from V1, pool gets rewards at V1, pool gets rewards at V3, test rewards.

## k=1 -> k=2 Migration Staker
- staker enter in V0, attest in V1, update balance in V1, attest in V1, attest in V2, update balance in V2, attest in V2, attest in V3, update balance in V3, attest in V3, test rewards.
- staker enter in V2, advance epoch, update balance in V2, upgrade to V3, update balance, attest, advance epoch, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, update balance in V2, upgrade to V3, update balance, attest, advance epoch, update balance, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, advance epoch, upgrade to V3, update balance, attest, advance epoch, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, advance epoch, upgrade to V3, attest, update balance,advance epoch, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, update balance, upgrade to V3, attest, advance epoch, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, upgrade to V3, advance epoch, attest,
- staker enter in V0, upgrade to V3, attest
- staker enter in V0, advance epoch, update balance, upgrade to V3, attest, update balance, advance epoch, attest
- staker enter in V1, advance epoch, update balance, upgrade to V3, attest, update balance, advance epoch, attest
- staker enter in V0, advance epoch, update balance, advance epoch, update balance, upgrade to V3, attest
- staker enter in V1, advance epoch, update balance, advance epoch, update balance, upgrade to V3, attest
- staker in V2, advance epoch, update balance staker+update balance pool, advance epoch, update balance staker+update balance pool, upgrade, update balance staker+update balance pool, attest in current epoch, attest in next epoch, attest in next next epoch

## pool member balance at curr epoch migration
- Member from V0, no actions in V1 or V2, test curr balance
- Member from V1, no actions in V2, test curr balance
- Member from V0, change balance at V1, no action at V2, test curr balance
- Member from V2, change balance, upgrade, test curr balance
- Cover all ifs with migration from: V0, V1, V2.

## k=1 -> k=2 token
- enable token, update rewards, advance epoch, update rewards, advance epoch, update rewards - token does not get rewards until after 2 epochs
- same as above with disable (can be implemented together as one test)
- enable token A and disable token B, next epoch upgrade, test views and rewards.
