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
- staker change balance, attest, change balance, attest, set_v3, change balance, update_rewards, change_balance, update_rewards, test rewards.
- with member from previous versions.

## pool member balance at curr epoch migration
- Member from V0, no actions in V1 or V2, test curr balance
- Member from V1, no actions in V2, test curr balance
- Member from V0, change balance at V1, no action at V2, test curr balance
- Member from V2, change balance, upgrade, test curr balance
- Cover all ifs with migration from: V0, V1, V2.

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
