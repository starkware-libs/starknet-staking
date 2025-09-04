# Flow Ideas
## `set_public_key`
- Set same epoch as upgrade.
- Intent, upgrade, set public key.
- Exit, upgrade, set public key.
- Set same public key for 2 different stakers.

## `get_current_public_key`
- Upgrade, get public key.

## `get_stakers`
- Get stakers with staker with zero balance (same epoch as stake).

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
