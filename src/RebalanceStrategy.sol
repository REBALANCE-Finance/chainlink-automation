// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import {AutomationCompatibleInterface} from "chainlink/v0.8/automation/AutomationCompatible.sol";
import {IProvider} from "./interfaces/IProvider.sol";
import {IInterestVault} from "./interfaces/IInterestVault.sol";
import {IVaultManager} from "./interfaces/IVaultManager.sol";

// This contract implements a rebalancing strategy for an interest vault.
// It is designed to be used as a Chainlink Automation Upkeep.
contract RebalanceStrategy is AutomationCompatibleInterface, Ownable {
    // The interest vault to manage
    IInterestVault public vault;
    // The rebalancer manager responsible for the rebalancing process
    IVaultManager public vaultManager;
    // The address of Chainlink's Forwarder contract that will be used to trigger performUpkeep()
    address public forwarder;
    // The minimal rebalance interval in seconds
    uint256 public minRebalanceInterval;
    // The minimal interest rate delta to trigger a rebalance, in ray units
    uint256 public minRebalanceDeltaRate;
    // The last time rebalance was performed
    uint256 public lastRebalance;

    // When rebalance is performed
    event UpkeepPerformed(IProvider newProvider);
    // When forwarder is set
    event ForwarderSet(address indexed forwarder);
    // When rebalance settings are updated
    event SettingsUpdated(uint256 minRebalanceInterval, uint256 minRebalanceDeltaRate);


    constructor(IInterestVault _vault, IVaultManager _vaultManager) Ownable(msg.sender) {
        vault = _vault;
        vaultManager = _vaultManager;
        // default rebalance settings
        minRebalanceInterval = 600;           // 10 minutes interval
        minRebalanceDeltaRate = 10**25;       // 1% rate delta
    }

    // Set the address of Chainlink's Forwarder contract that will be able to trigger rebalance
    function setForwarder(address _forwarder) external onlyOwner {
        forwarder = _forwarder;
        emit ForwarderSet(_forwarder);
    }

    // Update the rebalance settings
    function updateSettings(uint256 _minRebalanceInterval, uint256 _minRebalanceDeltaRate) external onlyOwner {
        minRebalanceInterval = _minRebalanceInterval;
        minRebalanceDeltaRate = _minRebalanceDeltaRate;
        emit SettingsUpdated(_minRebalanceInterval, _minRebalanceDeltaRate);
    }

    // Function called by Chainlink to perform the upkeep, i.e. rebalance the vault
    function performUpkeep(bytes calldata performData) external override {
        require(msg.sender == forwarder, "Only the forwarder can call this function");
        IProvider newProvider = abi.decode(performData, (IProvider));
        vaultManager.rebalanceVault(vault, type(uint256).max, vault.activeProvider(), newProvider, 0, true);
        lastRebalance = block.timestamp;
        emit UpkeepPerformed(newProvider);
    }

    // Function called by Chainlink to check whether it needs to perform the upkeep (rebalance)
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

    // Function to check whether a rebalancing is needed
    // It aims to rebalance to another provider as soon as its deposit rate is the highest
    function shouldRebalance() public view returns (bool should, IProvider newProvider) {
        // limit the rebalance frequency
        if (block.timestamp - lastRebalance < minRebalanceInterval) {
            return (false, vault.activeProvider());
        }
        // get providers and rates
        IProvider[] memory providers = vault.getProviders();
        uint256[] memory rates = depositRates();
        IProvider activeProvider = vault.activeProvider();
        uint256 activeRate = activeProvider.getDepositRateFor(vault);
        // find the best provider
        uint256 highestRate = 0;
        IProvider bestProvider;
        for (uint256 i = 0; i < rates.length; i++) {
            if (rates[i] > highestRate) {
                highestRate = rates[i];
                bestProvider = providers[i];
            }
        }
        // we should rebalance if the active provider rate is lower than the best provider rate
        // by at least minRebalanceDeltaRate
        if (highestRate - activeRate >= minRebalanceDeltaRate) {
            should = true;
            newProvider = bestProvider;
        } else {
            should = false;
            newProvider = activeProvider;
        }
    }

    // Get deposit rates for each provider, in the same order as getProviders()
    function depositRates() public view returns (uint256[] memory rates) {
        IProvider[] memory providers = vault.getProviders();
        rates = new uint256[](providers.length);
        for (uint256 i = 0; i < providers.length; i++) {
            rates[i] = providers[i].getDepositRateFor(vault);
        }
    }
}
