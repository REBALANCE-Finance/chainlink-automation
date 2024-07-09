// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/**
 * @title IVaultManager
 *
 * @notice Defines the interface of {VaultManager}.
 */

import {IInterestVault} from "./IInterestVault.sol";
import {IProvider} from "./IProvider.sol";

interface IVaultManager {

    error ProtocolAccessControl__CallerIsNotAdmin();
    error ProtocolAccessControl__CallerIsNotExecutor();
    error ProtocolAccessControl__CallerIsNotRebalancer();
    error VaultManager__InvalidAssetAmount();

    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function EXECUTOR_ROLE() external view returns (bytes32);

    function REBALANCER_ROLE() external view returns (bytes32);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function rebalanceVault(
        IInterestVault vault,
        uint256 assets,
        IProvider from,
        IProvider to,
        uint256 fee,
        bool activateToProvider
    ) external returns (bool success);

    function renounceRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
