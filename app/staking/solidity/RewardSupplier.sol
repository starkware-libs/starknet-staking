// SPDX-License-Identifier: Apache-2.0.
pragma solidity 0.8.24;

import "starkware/solidity/interfaces/ExternalInitializer.sol";
import "starkware/solidity/interfaces/ContractInitializer.sol";
import "starkware/solidity/interfaces/BlockDirectCall.sol";
import "starkware/solidity/tokens/ERC20/IERC20.sol";

import "starkware/solidity/interfaces/Identity.sol";

import "starkware/solidity/stake/RewardSupplierStorage.sol";
import "starkware/solidity/stake/RewardSupplierExternalInterfaces.sol";

import "third_party/open_zeppelin/utils/math/Math.sol";
import "starkware/solidity/libraries/Addresses.sol";

/**
  The RewardSupplier supplies funds to designated Starknet L2 contracts.

  Upon triggering using the tick() function.
  It collects pending funding requests from its L2 counterpart,
  Request respective tokens to be minted, and send them to L2 using StarkGate.
*/
contract RewardSupplier is
    RewardSupplierStorage,
    Identity,
    ExternalInitializer,
    ContractInitializer,
    BlockDirectCall
{
    using Addresses for address;
    event ConsumedMessages(uint256 messagesConsumed, uint256 totalAmountToMint);

    function identify() external pure override returns (string memory) {
        return "StarkWare_RewardSupplier_2024_1";
    }

    function validateInitData(bytes calldata data) internal view virtual override {
        require(data.length == 6 * 32, "ILLEGAL_DATA_SIZE");
        (
            address bridge_,
            address token_,
            address mintManager_,
            address messagingContract_,
            uint256 source_,
            uint256 mintDestination_
        ) = abi.decode(data, (address, address, address, address, uint256, uint256));
        require(bridge_.isContract(), "INVALID_BRIDGE_CONTRACT_ADDRESS");
        require(token_.isContract(), "INVALID_TOKEN_CONTRACT_ADDRESS");
        require(mintManager_.isContract(), "INVALID_MINTER_CONTRACT_ADDRESS");
        require(messagingContract_.isContract(), "INVALID_MESSAGING_CONTRACT_ADDRESS");
        require(source_ != 0, "INVALID_REWARD_RECEIVER");
        require(mintDestination_ != 0, "INVALID_MESSAGE_DISPATCHER");
    }

    /*
      Initializes the contract.
    */
    function initializeContractState(bytes calldata data) internal override {
        (
            address bridge,
            address token,
            address mintManager,
            address messagingContract,
            uint256 source,
            uint256 mintDestination
        ) = abi.decode(data, (address, address, address, address, uint256, uint256));
        setBridge(bridge);
        setToken(token);
        setMintManager(mintManager);
        setMessagingContract(messagingContract);
        setSource(source);
        setMintDestination(mintDestination);
        IERC20(token).approve(bridge, type(uint256).max);
    }

    function isInitialized() internal view override returns (bool) {
        return mintDestination() != 0;
    }

    /*
      No processing needed, as there are no sub-contracts to this contract.
    */
    function processSubContractAddresses(bytes calldata subContractAddresses) internal override {}

    function numOfSubContracts() internal pure override returns (uint256) {
        return 0;
    }

    function isFrozen() external view virtual returns (bool) {
        return false;
    }

    function initialize(bytes calldata data) external notCalledDirectly {
        if (isInitialized()) {
            require(data.length == 0, "UNEXPECTED_INIT_DATA");
        } else {
            // Contract was not initialized yet.
            validateInitData(data);
            initializeContractState(data);
        }
    }

    function tick(uint256 tokensPerMintAmount, uint256 maxMessagesToProcess) external payable {
        // Create the message payload with a single element containing the amount of tokens per message.
        uint256[] memory messageReceived = new uint256[](1);
        messageReceived[0] = tokensPerMintAmount;

        // Consume the message from L2.
        bytes32 msgHash = messagingContract().l2ToL1MsgHash(
            source(),
            address(this),
            messageReceived
        );

        // Calculate the number of messages to process.
        uint256 messagesToProcess = Math.min(
            messagingContract().l2ToL1Messages(msgHash),
            maxMessagesToProcess
        );

        // Process the messages.
        for (uint256 i = 0; i < messagesToProcess; i++) {
            // Consume the next message from L2.
            messagingContract().consumeMessageFromL2(source(), messageReceived);
        }

        uint256 totalAmountToMint = messagesToProcess * tokensPerMintAmount;
        mintManager().mintRequest(totalAmountToMint);

        bridge().depositWithMessage{value: msg.value}(
            token(),
            totalAmountToMint,
            mintDestination(),
            new uint256[](0)
        );
        emit ConsumedMessages(messagesToProcess, totalAmountToMint);
    }
}
