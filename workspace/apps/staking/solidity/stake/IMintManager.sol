// SPDX-License-Identifier: Apache-2.0.
pragma solidity 0.8.24;

interface IMintManager {
    function mintRequest(address token, uint256 amount) external;
}
