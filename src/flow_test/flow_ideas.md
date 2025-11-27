# Flow Ideas
## Views
- Get staker info while staker has zero balance.
- staker change balance and test with view of current epoch balance
- member change balance and test with view of current epoch balance

## `update_rewards`
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
- staker enter in V0, attest in V1, update balance in V1, attest in V1, attest in V2, update balance in V2, attest in V2, attest in V3, update balance in V3, attest in V3, test rewards.
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

## k=1 -> k=2 token
- enable token, update rewards, advance epoch, update rewards, advance epoch, update rewards - token does not get rewards until after 2 epochs
- same as above with disable (can be implemented together as one test)
- enable token A and disable token B, next epoch upgrade, test views and rewards.

## block rewards by timestamp
- advance blocks with different block times and check the avg is calculated correctly
- update_rewards for blocks in same epoch - same rewards, then advance epoch, different rewards, update rewards for blocks in same epoch - same rewards.
- update rewards is not called every block, still rewards is updated correctly (miss block, miss first block in epoch, miss epoch)
- set block time config and test rewards after

## rewards by timestamp - migration
- set_consensus_rewards to future epoch, call update_rewards before consensus epoch and after, test rewards.
- set_consensus_rewards to future epoch, call update_rewards only after consensus epoch, test rewards.
- set_consensus_rewards to curr_epoch + 2. test rewards before and after. tets avg block time is update correctly.
- set_consensus_rewards, update_rewards, then set_consensus_rewards to later epoch, update_rewards, then set_consensus_rewards to earlier epoch, update_rewards, test avg block time.
