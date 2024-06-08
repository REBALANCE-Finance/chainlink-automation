// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AutomationCompatibleInterface} from "chainlink/v0.8/automation/AutomationCompatible.sol";
import {IProvider} from "./interfaces/IProvider.sol";
import {IInterestVault} from "./interfaces/IInterestVault.sol";
import {IRebalancerManager} from "./interfaces/IRebalancerManager.sol";

contract RebalanceStrategy is AutomationCompatibleInterface {
    IInterestVault public vault;
    IRebalancerManager public rebalancerManager;
    address public forwarder;
    
    event UpkeepPerformed(IProvider newProvider);

    constructor(IInterestVault _vault, IRebalancerManager _rebalancerManager) {
        vault = _vault;
        rebalancerManager = _rebalancerManager;
    }

    function setForwarder(address _forwarder) external {
        require(forwarder == address(0), "Forwarder already set");
        forwarder = _forwarder;
    }

    function performUpkeep(bytes calldata performData) external override {
        require(msg.sender == forwarder, "Only the forwarder can call this function");
        IProvider newProvider = abi.decode(performData, (IProvider));
        rebalancerManager.rebalanceVault(vault, type(uint256).max, vault.activeProvider(), newProvider, 0, true);
        emit UpkeepPerformed(newProvider);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        IProvider newProvider;
        (upkeepNeeded, newProvider) = shouldRebalance();
        if (upkeepNeeded) {
            performData = abi.encode(newProvider);
        }
    }

    function shouldRebalance() public view returns (bool should, IProvider newProvider) {
        IProvider[] memory providers = vault.getProviders();
        uint256[] memory rates = depositRates();
        IProvider activeProvider = vault.activeProvider();
        uint256 activeRate = activeProvider.getDepositRateFor(vault);
        uint256 highestRate = 0;
        IProvider bestProvider;
        for (uint256 i = 0; i < rates.length; i++) {
            if (rates[i] > highestRate) {
                highestRate = rates[i];
                bestProvider = providers[i];
            }
        }
        if (activeRate != highestRate) {
            should = true;
            newProvider = bestProvider;
        } else {
            should = false;
            newProvider = activeProvider;
        }
    }

    function depositRates() public view returns (uint256[] memory rates) {
        IProvider[] memory providers = vault.getProviders();
        rates = new uint256[](providers.length);
        for (uint256 i = 0; i < providers.length; i++) {
            rates[i] = providers[i].getDepositRateFor(vault);
        }
    }
}