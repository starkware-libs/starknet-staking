// SPDX-License-Identifier: Apache-2.0.
pragma solidity 0.8.24;

import "starkware/solidity/components/Roles.sol";
import "starkware/solidity/interfaces/Identity.sol";
import "starkware/solidity/libraries/NamedStorage8.sol";
import "starkware/solidity/libraries/RolesLib.sol";
import "starkware/solidity/stake/IMintManager.sol";
import "starkware/solidity/stake/PeriodMintLimit.sol";
import "starkware/solidity/upgrade/ProxySupportImpl.sol";

interface mintableToken {
    function mint(address account, uint256 amount) external;
}

/**
  MintManager handles controlled token minting requests.

  It regulates minting using per caller per token minting allowances.
  It assumes target token allows this contract to mint, and supports `mint(recipient, amount)` api.
*/
contract MintManager is IMintManager, Identity, ProxySupportImpl, PeriodMintLimit, Roles(false) {
    // Named storage slot tags.
    string internal constant MINTING_ALLOWANCE_TAG = "MINT_MANAGER_MINTING_ALLOWANCE_SLOT_TAG";
    string internal constant REGISTERED_MINTERS_TAG = "REGISTERED_MINTERS_SLOT_TAG";

    event MintProcessed(address token, address account, uint256 amount);
    event MintingAllowanceSet(address token, address account, uint256 newAllowance);
    event TokenMinterRegistered(address token, address minter);
    event TokenMinterRevoked(address token, address minter);

    /**
      Modifier allowing caller addresses holding any of the roles:
      SecurityAgent, SecurityAdmin or AppGovernor.
    */
    modifier onlySecurityRole() {
        address _msgSender = AccessControl._msgSender();
        require(
            isAppGovernor(_msgSender) || isSecurityAdmin(_msgSender) || isSecurityAgent(_msgSender),
            "ONLY_GOVERNOR_OR_SECURITY"
        );
        _;
    }

    function identify() external pure override returns (string memory) {
        return "StarkWare_MintManager_2024_1";
    }

    /**
      Processes a mint request by deducting the specified amount from the sender's allowance and
      minting tokens, reverting if the allowance is insufficient.
    */
    function mintRequest(address token, uint256 amount) external {
        address requester = AccessControl._msgSender();
        require(registeredMinters(token)[requester], "NOT_A_REGISTERED_MINTER");
        require(mintingAllowance(token)[requester] >= amount, "INSUFFICIENT_MINTING_ALLOWANCE");

        // Update allowance.
        checkAndUpdatePeriodicalQuota(token, amount);
        mintingAllowance(token)[requester] -= amount;

        // Mint.
        mintableToken(token).mint(requester, amount);
        emit MintProcessed(token, requester, amount);
    }

    /**
      Returns the token's minting allowance for a specified account.
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
        require(registeredMinters(token)[account], "NOT_A_REGISTERED_MINTER");
        _setMintingAllowance(token, account, amount);
    }

    function _setMintingAllowance(
        address token,
        address account,
        uint256 amount
    ) private {
        mintingAllowance(token)[account] = amount;
        emit MintingAllowanceSet(token, account, amount);
    }

    /**
      Register an eligible token minter.
      Callable only by the app governor.
    */
    function registerTokenMinter(address token, address minter) external onlyAppGovernor {
        // Do nothing if minter is already registered.
        if (registeredMinters(token)[minter]) {
            return;
        }

        registeredMinters(token)[minter] = true;
        emit TokenMinterRegistered(token, minter);
        _setMintingAllowance(token, minter, 0);
    }

    /**
      Unregister an eligible token minter.
      Callable only by the app governor or a security agent/admin.
    */
    function revokeTokenMinter(address token, address minter) external onlySecurityRole {
        // Do nothing if minter is not registered.
        if (!registeredMinters(token)[minter]) {
            return;
        }

        registeredMinters(token)[minter] = false;
        emit TokenMinterRevoked(token, minter);
        _setMintingAllowance(token, minter, 0);
    }

    /**
      Sets the allowance for a specified account to a zero amount, only callable by security agents.
    */
    function cancelMintingAllowance(address token, address account) external onlySecurityAgent {
        _setMintingAllowance(token, account, 0);
    }

    /**
      Storage variable access.
      Returns the token's minting allowance mapping.
    */
    function mintingAllowance(address token)
        internal
        pure
        returns (mapping(address => uint256) storage)
    {
        bytes32 location = keccak256(abi.encodePacked(MINTING_ALLOWANCE_TAG, token));
        return NamedStorage._addressToUint256Mapping(location);
    }

    /**
      Storage variable access.
      Returns the token's registered minters mapping.
    */
    function registeredMinters(address token)
        internal
        pure
        returns (mapping(address => bool) storage)
    {
        bytes32 location = keccak256(abi.encodePacked(REGISTERED_MINTERS_TAG, token));
        return NamedStorage._addressToBoolMapping(location);
    }
}
