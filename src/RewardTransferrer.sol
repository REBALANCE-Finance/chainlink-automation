// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AutomationCompatibleInterface} from "chainlink/v0.8/automation/AutomationCompatible.sol";
import {IVault} from "./interfaces/IVault.sol";

// This contract transfers the rewards InterestVault has received to RewardDistributor.
// It is designed to be used as a Chainlink Automation Upkeep.
contract RewardTransferrer is AutomationCompatibleInterface {
    // The interest vault to monitor
    IVault public vault;
    // The reward token
    address public token;

    // When rewards transfer is performed
    event UpkeepPerformed();

    constructor(IVault _vault, address _token) {
        vault = _vault;
        token = _token;
    }

    // Called by Chainlink to perform the upkeep, i.e. transfer rewards
    function performUpkeep(bytes calldata /* performData */) external override {
        vault.transferRewards(token);
        emit UpkeepPerformed();
    }

    // Called by Chainlink to check whether it needs to perform the upkeep, i.e. to transfer rewards
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = IERC20(token).balanceOf(address(vault)) > 0;
        performData = new bytes(0);
    }
}
