# Flow Ideas
## `set_public_key`
- Set same epoch as upgrade.
- Intent, upgrade, set public key.
- Exit, upgrade, set public key.
- Set same public key for 2 different stakers.

## `get_current_public_key`
- Upgrade, get public key.

## `get_stakers`
- Get stakers with staker with zero balance.
- Staker exit action, get stakers.
- Staker exit intent, get stakers.
- Delegate STRK and/or BTC, get stakers.
- Undelegate, get stakers.
- Enable / disable tokens, get stakers.
- Stake, get stakers, increase stake, get stakers.
- Stake with delegation, get stakers, switch pool, get stakers.
- Staker without public key.

## `get_current_staker_info` (name is WIP)
- Get staker info while staker has zero balance.

## `update_rewards`
- staker with only strk pool.
- staker with only btc pool.
- staker with empty pool (STRK + BTC).
- staker with 2 btc pools with different decimals.
- staker immediately/one epoch after he called intent.
- update rewards for 2 different blocks in the same epoch - should be same rewards.
- Change epoch len in blocks - rewards should be changed.
- disable_rewards = true, advance block, disable_rewards = false, advance block, disable_rewards = true, test rewards.
- update rewards for some different blocks in the same epoch, test rewards of pool member.

## v3 flag
- update_rewards_from_attestation, update_rewards (not distribute), set_v3_epoch, update_rewards_from_attestation, update_rewards (not distribute), advance epoch to v3 epoch, update_rewards_from_attestation-panic, update_rewards-distribute, advance epoch, update_rewards_from_attestation-panic, update_rewards-distribute, advance epoch, update_rewards_from_attestation-panic, update_rewards with disable rewards-not distribute.
- disable rewards with v3 off - no rewards, same block - panic
- disable rewards with v3 on - no rewards, same block - panic
- not disable rewards with v3 off - no rewards, same block - panic
- not disable rewards with v3 on - rewards, same block - panic

## k=1 -> k=2 balances
- staker with stake, upgrade, increase stake - before upgrade after 1 epoch, after 2 epochs (check also total stake)
- delegator delegate, upgrade, add delegation - same
- delegator claim rewards when last change is in epoch + 2, then advance epochs and claim again to see no missing rewards
- same as above, also when there is change in epoch + 1
- delegate, advance epoch and get rewards for the pool, claim - zero rewards for the delegate 
- delegate, advance epoch, delegate, advance epoch, claim rewards - only for the first delegation, advance epoch, claim rewards - for all
- delegator claim after claim 
- delegator claim after claim when exists checkpoint with the current epoch of the first claim
- staker change balance in each epoch (increase, intent, delegate increase, delegate intent, delegate exit) and attest in each epoch - test rewards (also some epochs with no balance change and some epochs with no attest)
- staker has multiple pool with multiple delegator each, change balance (staker, strk delegate, btc delegate) and attest in many epochs and test rewards both staker and members
- staker change balance and test with view of current epoch balance
- mamber change balance and test with view of current epoch balance
- staker increase stake, attest same epoch, advance epoch, attest, advance epoch, attest, test rewards
- delegator increase delegate, attest same epoch, advance epoch, attest, advance epoch, attest, test rewards
- test staker claim rewards with more than one balance change in an epoch.
- test delegator claim rewards with V3 rewards?
- test staker rewards with v3 rewards?

## k=1 -> k=2 Migration
- Member change balances before migration, some attestations, upgrade, change balances , some update_rewards, test calculate rewards of the member
- Member only enter before migration, some attestations, upgrade, change balances , some update_rewards, test calculate rewards of the member
- Member only enter before migration, no rewards to pool at all, upgrade, claim rewards.
- Member only enter before migration, only one rewards to pool, upgrade, claim rewards.
- Member change balances before migration, upgrade, one rewards to pool, claim rewards.
- TODO: Think of edge cases here in calculate rewards.

## k=1 -> k=2 token
- enable token, update rewards, advance epoch, update rewards, advance epoch, update rewards - token does not get rewards until after 2 epochs
- same as above with disable (can be implemented together as one test)
- token enabled, upgrade, disable
- token disabled, upgrade, enable
- token A enabled, next epoch token B enabled, next epoch token A disabled, next epoch token B disabled

## block rewards by timestamp
- advance blocks with different block times and check the avg is calculated correctly
- update_rewards for blocks in same epoch - same rewards, then advance epoch, different rewards, update rewards for blocks in same epoch - same rewards.
- update rewards is not called every block, still rewards is updated correctly (miss block, miss first block in epoch, miss epoch)
- block time less than min and block time more than max
- set block time config and test rewards after
- test with factor = 100
- test with very small factor
