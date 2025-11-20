// SPDX-License-Identifier: Apache-2.0.
pragma solidity 0.8.24;

import "starkware/starknet/solidity/IStarknetMessaging.sol";
import "starkware/solidity/stake/IMintManager.sol";

interface IBridge {
    function depositWithMessage(
        address token,
        uint256 amount,
        uint256 l2Recipient,
        uint256[] calldata message
    ) external payable;
}
