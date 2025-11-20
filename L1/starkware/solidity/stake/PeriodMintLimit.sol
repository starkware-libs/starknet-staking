// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.8.0;

import "starkware/solidity/libraries/NamedStorage8.sol";

// Periodic mint cap limits the total minting of a token within a time period,
// regardless of minting allowance.
uint256 constant PERIOD_MINT_CAP = 6_500_000 * 10**18;
uint256 constant MINTING_PERIOD_DURATION = 1 weeks;

/**
  PeriodMintLimit limits the amount of minted token in a period.
*/
abstract contract PeriodMintLimit {
    // Named storage slot tags.
    string internal constant PERIODICAL_MINT_ACCOUNTING_TAG = "PERIODICAL_MINT_ACCOUNTING_SLOT_TAG";

    function checkAndUpdatePeriodicalQuota(address token, uint256 amount) internal {
        bytes32 periodSlot = periodAccountingSlot(token);
        uint256 mintedThisPeriodBefore = periodMintAccounting()[periodSlot];
        uint256 mintedThisPeriodAfter = mintedThisPeriodBefore + amount;
        require(mintedThisPeriodAfter <= PERIOD_MINT_CAP, "EXCEED_PERIOD_MINTING");
        periodMintAccounting()[periodSlot] = mintedThisPeriodAfter;
    }

    // Returns a storage mapping keyed by token and period index to the amount
    // of tokens that were already minted during that period.
    function periodMintAccounting() internal pure returns (mapping(bytes32 => uint256) storage) {
        return NamedStorage.bytes32ToUint256Mapping(PERIODICAL_MINT_ACCOUNTING_TAG);
    }

    // Returns the storage slot per a period index per token.
    function periodAccountingSlot(address token) internal view returns (bytes32) {
        uint256 period_index = block.timestamp / MINTING_PERIOD_DURATION;
        return keccak256(abi.encode(MINTING_PERIOD_DURATION, token, period_index));
    }
}
