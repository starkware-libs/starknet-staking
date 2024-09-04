// SPDX-License-Identifier: Apache-2.0.
pragma solidity 0.8.24;

import "starkware/solidity/stake/IMintManager.sol";
import "starkware/solidity/stake/MintManagerStorage.sol";

import "starkware/solidity/interfaces/ExternalInitializer.sol";
import "starkware/solidity/interfaces/ContractInitializer.sol";
import "starkware/solidity/interfaces/BlockDirectCall.sol";
import "starkware/solidity/libraries/Addresses.sol";

import "starkware/solidity/interfaces/Identity.sol";

/**
  The MintManager contract handles controlled token minting requests.

  It manages and enforces allowances for accounts, allowing mint requests
  to be processed based on pre-set allowances. The contract ensures only
  authorized governors can set, increase, decrease, or stop allowances.
*/
contract MintManager is
    MintManagerStorage,
    IMintManager,
    Identity,
    ExternalInitializer,
    ContractInitializer,
    BlockDirectCall
{
    event MintRequest(address account, uint256 amount);
    event AllowanceChanged(address account, uint256 newAllowance);
    using Addresses for address;

    modifier onlyAllowanceGovernor() {
        _;
    }

    modifier onlyStopGovernor() {
        _;
    }

    function identify() external pure override returns (string memory) {
        return "StarkWare_MintManager_2024_1";
    }

    function validateInitData(bytes calldata data) internal view virtual override {
        require(data.length == 1 * 32, "ILLEGAL_DATA_SIZE");
        address token = abi.decode(data, (address));
        require(token.isContract(), "INVALID_TOKEN_CONTRACT_ADDRESS");
    }

    /*
      Initializes the contract.
    */
    function initializeContractState(bytes calldata data) internal override {
        address token_ = abi.decode(data, (address));
        setToken(token_);
    }

    function isInitialized() internal view override returns (bool) {
        return token() != address(0);
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

    /**
      Processes a mint request by deducting the specified amount from the sender's allowance and 
      minting tokens, reverting if the allowance is insufficient.
    */
    function mintRequest(uint256 amount) external {
        if (allowance()[msg.sender] < amount) {
            revert("INSUFFICIENT_ALLOWANCE");
        }
        allowance()[msg.sender] -= amount;
        mintableToken(token()).mint(msg.sender, amount);
        emit MintRequest(msg.sender, amount);
    }

    /**
      Returns the current allowance for a specified account.
    */
    function allowance(address account) external view returns (uint256) {
        return allowance()[account];
    }

    /**
      Sets the allowance for a specified account to a given amount, only callable by 
      the allowance governor. 
    */
    function approve(address account, uint256 amount) external onlyAllowanceGovernor {
        allowance()[account] = amount;
        emit AllowanceChanged(account, amount);
    }

    /**
      Increases the allowance for a specified account by a given amount, only callable by
      the allowance governor.
    */
    function increaseAllowance(address account, uint256 amount) external onlyAllowanceGovernor {
        allowance()[account] += amount;
        emit AllowanceChanged(account, allowance()[account]);
    }

    /**
      Decreases the allowance for a specified account by a given amount, only callable by
      the allowance governor.
    */
    function decreaseAllowance(address account, uint256 amount) external onlyAllowanceGovernor {
        if (allowance()[account] < amount) {
            revert("ALLOWANCE_BELOW_ZERO");
        }
        allowance()[account] -= amount;
        emit AllowanceChanged(account, allowance()[account]);
    }

    /**
      Sets the allowance of a specified account to zero, only callable by the stop governor.
    */
    function stopAllowance(address account) external onlyStopGovernor {
        allowance()[account] = 0;
        emit AllowanceChanged(account, 0);
    }
}

interface mintableToken {
    function mint(address account, uint256 amount) external;
}
