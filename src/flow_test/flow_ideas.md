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

## k=1 -> k=2 Migration Member
- find sigma: Enter V0, change in V1, catch all ifs.
more ideas:
- member from V1, pool gets rewards at V1, update balance at V1, update balance at V3, pool gets rewards at V3, test rewards.
- member from V1, pool gets rewards at V1, pool gets rewards at V3, update balance at V3, test rewards.
- member from V1, pool gets rewards at V1, pool gets rewards at V3, test rewards.

## k=1 -> k=2 Migration Staker
- staker enter in V2, advance epoch, update balance in V2, upgrade to V3, update balance, attest, advance epoch, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, update balance in V2, upgrade to V3, update balance, attest, advance epoch, update balance, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, advance epoch, upgrade to V3, update balance, attest, advance epoch, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, advance epoch, upgrade to V3, attest, update balance,advance epoch, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, update balance, upgrade to V3, attest, advance epoch, attest, advance epoch, attest, test rewards
- staker enter in V2, advance epoch, upgrade to V3, advance epoch, attest,
- staker in V2, update balance staker+update balance pool, upgrade, attest in current epoch, attest in next epoch, attest in next next epoch
- staker in V2, advance epoch, update balance staker+update balance pool, advance epoch, update balance staker+update balance pool, upgrade, update balance staker+update balance pool, attest in current epoch, attest in next epoch, attest in next next epoch

## pool member balance at curr epoch migration
- Member from V0, no actions in V1 or V2, test curr balance
- Member from V1, no actions in V2, test curr balance
- Member from V0, change balance at V1, no action at V2, test curr balance
- Member from V2, change balance, upgrade, test curr balance
- Cover all ifs with migration from: V0, V1, V2.
