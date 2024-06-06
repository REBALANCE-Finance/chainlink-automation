// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RebalanceStrategy} from "../src/AutomationRebalanceStrategy.sol";
import {IRebalancerManager} from "../src/interfaces/IRebalancerManager.sol";
import {IInterestVault} from "../src/interfaces/IInterestVault.sol";
import {IProvider} from "../src/interfaces/IProvider.sol";

contract AutomationRebalanceStrategyTest is Test {
    RebalanceStrategy public strategy;

    event UpkeepPerformed(IProvider newProvider);

    function setUp() public {
        IInterestVault vault = IInterestVault(0xD430e22c3a0F8Ebd6813411084a5cb26937f6661);  // USDC.e
        IRebalancerManager manager = IRebalancerManager(0x7912C6906649D582dD8928fC121D35f4b3B9fEF2);
        strategy = new RebalanceStrategy(vault, manager);
    }

    function test_HasProviders() public view {
        IProvider[] memory providers = strategy.vault().getProviders();
        assertGt(providers.length, 0);
    }

    function test_GetsDepositRates() public view {
        uint256[] memory rates = strategy.depositRates();
        assertGt(rates.length, 0);
    }

    function test_ShouldRebalanceCurrent() public view {
        IProvider[] memory providers = strategy.vault().getProviders();
        IProvider activeProvider = strategy.vault().activeProvider();
        uint256[] memory rates = strategy.depositRates();
        (bool should, IProvider newProvider) = strategy.shouldRebalance();
        // find the iBestProvider of newProvider in providers
        uint256 iBestProvider;
        for (uint256 i = 0; i < providers.length; i++) {
            if (providers[i] == newProvider) {
                iBestProvider = i;
                break;
            }
        }
        // check that the best provider indeed has rate higher than every other
        for (uint256 i = 0; i < rates.length; i++) {
            if (i != iBestProvider) {
                assertGt(rates[iBestProvider], rates[i]);
            }
        }
        // check that should=true only when activeProvider rate is different than newProvider
        assertEq(should, activeProvider.getDepositRateFor(strategy.vault()) != newProvider.getDepositRateFor(strategy.vault()));
    }

    function test_CheckUpkeep() public view {
        IProvider activeProvider = strategy.vault().activeProvider();
        (bool upkeepNeeded, bytes memory performData) = strategy.checkUpkeep("");
        if (upkeepNeeded) {
            IProvider newProvider = abi.decode(performData, (IProvider));
            assertTrue(newProvider != activeProvider, "new provider same as active provider");
        }
    }

    function test_PerformUpkeep() public {
        IProvider[] memory providers = strategy.vault().getProviders();
        IProvider provider = strategy.vault().activeProvider();
        // find a provider that is not active provider
        for (uint256 i = 0; i < providers.length; i++) {
            if (providers[i] != provider) {
                provider = providers[i];
                break;
            }
        }
        vm.expectEmit(true, true, true, true);
        emit UpkeepPerformed(provider);
        strategy.performUpkeep(abi.encode(provider));
        assertEq(address(strategy.vault().activeProvider()), address(provider), "active provider not updated");
    }
}
