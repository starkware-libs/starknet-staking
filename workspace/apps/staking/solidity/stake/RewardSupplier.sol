// SPDX-License-Identifier: Apache-2.0.
pragma solidity 0.8.24;

import "starkware/solidity/components/GovernanceStub.sol";
import "starkware/solidity/interfaces/BlockDirectCall.sol";
import "starkware/solidity/interfaces/Identity.sol";
import "starkware/solidity/interfaces/ProxySupport.sol";
import "starkware/solidity/libraries/Addresses.sol";
import "starkware/solidity/stake/RewardSupplierStorage.sol";
import "starkware/solidity/stake/RewardSupplierExternalInterfaces.sol";
import "starkware/solidity/tokens/ERC20/IERC20.sol";
import "third_party/open_zeppelin/utils/math/Math.sol";

uint256 constant TOKENS_PER_MINT_REQUEST = 1_300_000;
uint256 constant MAX_MESSAGES_TO_PROCESS_PER_TICK = 10;

// L1_handler selector for 'update_total_supply'.
uint256 constant UPDATE_TOTAL_SUPPLY_SELECTOR = 0x3f52d976f20d8cb65b362a5df632b87dd69039597d692d7a0c65443f0e5363;

/**
  The RewardSupplier supplies funds to designated Starknet L2 contracts.

  Upon triggering using the tick() function.
  It collects pending funding requests from its L2 counterpart,
  Request respective tokens to be minted, and send them to L2 using StarkGate.
*/
contract RewardSupplier is
    RewardSupplierStorage,
    Identity,
    BlockDirectCall,
    ProxySupport,
    GovernanceStub
{
    using Addresses for address;
    event ConsumedL2MintRequests(uint256 messagesConsumed, uint256 amountMinted);

    function identify() external pure override returns (string memory) {
        return "StarkWare_RewardSupplier_2024_1";
    }

    function validateInitData(bytes calldata data) internal view virtual override {
        require(data.length == 7 * 32, "ILLEGAL_DATA_SIZE");
        (
            address bridge,
            address token,
            address mintManager,
            address messagingContract,
            uint256 mintRequestSource,
            uint256 mintDestination,
            uint256 mintingCurveContract
        ) = abi.decode(data, (address, address, address, address, uint256, uint256, uint256));
        require(bridge.isContract(), "INVALID_BRIDGE_ADDRESS");
        require(token.isContract(), "INVALID_TOKEN_ADDRESS");
        require(mintManager.isContract(), "INVALID_MINT_MGR_ADDRESS");
        require(messagingContract.isContract(), "INVALID_MESSAGING_CONTRACT_ADDRESS");
        require(mintRequestSource != 0, "INVALID_MINT_REQ_SOURCE");
        require(mintDestination != 0, "INVALID_MINT_DESTINATION");
        require(mintingCurveContract != 0, "INVALID_MINTING_CURVE");
    }

    function l2ToL1MsgHash(
        uint256 fromAddress,
        address toAddress,
        uint256[] memory payload
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(fromAddress, uint256(uint160(toAddress)), payload.length, payload)
            );
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
            uint256 mintRequestSource,
            uint256 mintDestination,
            uint256 mintingCurveContract
        ) = abi.decode(data, (address, address, address, address, uint256, uint256, uint256));
        setBridge(bridge);
        setToken(token);
        setMintManager(mintManager);
        setMessagingContract(messagingContract);
        setMintRequestSource(mintRequestSource);
        setMintDestination(mintDestination);
        setMintingCurve(mintingCurveContract);
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

    /*
      Checks how many mintRequests messages should be consumed,
      and how much should be minted against those messages.
    */
    function requiredMinting() public view returns (uint256, uint256) {
        uint256[] memory messagePayload = new uint256[](1);
        messagePayload[0] = TOKENS_PER_MINT_REQUEST;

        bytes32 msgHash = l2ToL1MsgHash(mintRequestSource(), address(this), messagePayload);
        // Limit the number of msgs to consume to limit.
        uint256 numMsgsToConsume = Math.min(
            messagingContract().l2ToL1Messages(msgHash),
            MAX_MESSAGES_TO_PROCESS_PER_TICK
        );

        return (TOKENS_PER_MINT_REQUEST * numMsgsToConsume, numMsgsToConsume);
    }

    function tick() external payable {
        // Check if minting is required, and how much.
        (uint256 amountToMint, uint256 numMsgsToConsume) = requiredMinting();

        if (amountToMint > 0) {
            // Prepare the L2->L1 mintRequest message for consumption.
            uint256[] memory messagePayload = new uint256[](1);
            messagePayload[0] = TOKENS_PER_MINT_REQUEST;

            // Consume the mintRequest messages.
            for (uint256 i = 0; i < numMsgsToConsume; i++) {
                messagingContract().consumeMessageFromL2(mintRequestSource(), messagePayload);
            }

            // Reuest minting of the requested amount from the mint manager.
            mintManager().mintRequest(token(), amountToMint);

            // Deposit the minted amount onto the bridge to the credit of `mintDestination`.
            uint256 msgFee = msg.value / 2;
            bridge().depositWithMessage{value: msgFee}(
                token(),
                amountToMint,
                mintDestination(),
                new uint256[](0)
            );
            emit ConsumedL2MintRequests(numMsgsToConsume, amountToMint);

            // Send a totalSupply update to L2MintCurve.
            msgFee = msg.value - msgFee;
            messagePayload[0] = IERC20(token()).totalSupply();
            messagingContract().sendMessageToL2{value: msgFee}(
                mintingCurve(),
                UPDATE_TOTAL_SUPPLY_SELECTOR,
                messagePayload
            );
        }
    }
}
