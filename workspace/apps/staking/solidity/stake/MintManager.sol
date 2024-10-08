// SPDX-License-Identifier: Apache-2.0.
pragma solidity 0.8.24;

import "starkware/solidity/components/GovernanceStub.sol";
import "starkware/solidity/components/Roles.sol";
import "starkware/solidity/interfaces/BlockDirectCall.sol";
import "starkware/solidity/interfaces/ContractInitializer.sol";
import "starkware/solidity/interfaces/ExternalInitializer.sol";
import "starkware/solidity/interfaces/Identity.sol";
import "starkware/solidity/interfaces/ProxySupport.sol";
import "starkware/solidity/libraries/Addresses.sol";
import "starkware/solidity/libraries/NamedStorage8.sol";
import "starkware/solidity/libraries/RolesLib.sol";
import "starkware/solidity/stake/IMintManager.sol";

interface mintableToken {
    function mint(address account, uint256 amount) external;
}

/**
  MintManager handles controlled token minting requests.

  It regulates minting using per caller per token minting allowances.
  It assumes target token allows this contract to mint, and supports `mint(recipient, amount)` api.
*/
contract MintManager is
    IMintManager,
    Identity,
    BlockDirectCall,
    ProxySupport,
    GovernanceStub,
    Roles(false)
{
    // Named storage slot tags.
    string internal constant MINTING_ALLOWANCE_TAG = "MINT_MANAGER_MINTING_ALLOWANCE_SLOT_TAG";

    event MintProcessed(address token, address account, uint256 amount);
    event MintingAllowanceSet(address token, address account, uint256 newAllowance);
    using Addresses for address;

    function identify() external pure override returns (string memory) {
        return "StarkWare_MintManager_2024_1";
    }

    function validateInitData(bytes calldata data) internal view virtual override {
        require(data.length == 0, "ILLEGAL_DATA_SIZE");
    }

    /*
      Initializes the contract.
    */
    function initializeContractState(bytes calldata data) internal override {}

    function isInitialized() internal view override returns (bool) {
        return true;
    }

    /*
      No processing needed, as there are no sub-contracts to this contract.
    */
    function processSubContractAddresses(bytes calldata subContractAddresses) internal override {}

    function numOfSubContracts() internal pure override returns (uint256) {
        return 0;
    }

    /**
      Processes a mint request by deducting the specified amount from the sender's allowance and
      minting tokens, reverting if the allowance is insufficient.
    */
    function mintRequest(address token, uint256 amount) external {
        address _sender = msg.sender;
        require(mintingAllowance(token)[_sender] >= amount, "INSUFFICIENT_MINTING_ALLOWANCE");
        mintingAllowance(token)[_sender] -= amount;
        mintableToken(token).mint(_sender, amount);
        emit MintProcessed(token, _sender, amount);
    }

    /**
      Returns the minting allowance for a specified account on a specified token.
    */
    function mintingAllowance(address token, address account) external view returns (uint256) {
        return mintingAllowance(token)[account];
    }

    /**
      Sets the minting allowance for a specified account on a specified token to a given amount.
      Callable only by the token admin.
    */
    function setMintingAllowance(
        address token,
        address account,
        uint256 amount
    ) external onlyTokenAdmin {
        mintingAllowance(token)[account] = amount;
        emit MintingAllowanceSet(token, account, amount);
    }

    /**
      Sets the allowance for a specified account to a zero amount, only callable by security agents.
    */
    function cancelMintingAllowance(address token, address account) external onlySecurityAgent {
        mintingAllowance(token)[account] = 0;
        emit MintingAllowanceSet(token, account, 0);
    }

    // Storage Getters.
    function mintingAllowance(address token)
        internal
        view
        returns (mapping(address => uint256) storage)
    {
        return NamedStorage.addressToAddressToUint256Mapping(MINTING_ALLOWANCE_TAG)[token];
    }
}
