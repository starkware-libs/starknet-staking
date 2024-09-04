// SPDX-License-Identifier: Apache-2.0.
pragma solidity 0.8.24;

import "starkware/solidity/libraries/NamedStorage8.sol";

abstract contract MintManagerStorage {
    // Named storage slot tags.

    string internal constant TOKEN_TAG = "MINT_MANAGER_TOKEN_SLOT_TAG";
    string internal constant ALLOWANCE_TAG = "MINT_MANAGER_ALLOWANCE_SLOT_TAG";

    // Storage Getters.

    function token() internal view returns (address) {
        return NamedStorage.getAddressValue(TOKEN_TAG);
    }

    function allowance() internal pure returns (mapping(address => uint256) storage) {
        return NamedStorage.addressToUint256Mapping(ALLOWANCE_TAG);
    }

    // Storage Setters.

    function setToken(address token_) internal {
        NamedStorage.setAddressValueOnce(TOKEN_TAG, token_);
    }
}
