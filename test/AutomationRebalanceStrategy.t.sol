// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RebalanceStrategy} from "../src/AutomationRebalanceStrategy.sol";
import {IRebalancerManager} from "../src/interfaces/IRebalancerManager.sol";
import {IInterestVault} from "../src/interfaces/IInterestVault.sol";
import {IProvider} from "../src/interfaces/IProvider.sol";

contract AutomationRebalanceStrategyTest is Test {
    uint256 forkId;
    RebalanceStrategy public strategy;
    IRebalancerManager public manager;
    IInterestVault public vault;

    event UpkeepPerformed(IProvider newProvider);
    event AllowExecutor(address indexed executor, bool allowed);

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("arbitrum"));
        vault = IInterestVault(0xD430e22c3a0F8Ebd6813411084a5cb26937f6661);  // USDC.e
        manager = IRebalancerManager(0x7912C6906649D582dD8928fC121D35f4b3B9fEF2);
        strategy = new RebalanceStrategy(vault, manager);
    }

    function test_HasProviders() public view {
        IProvider[] memory providers = strategy.vault().getProviders();
        assertGt(providers.length, 0, "no providers");
    }

    function test_GetsDepositRates() public view {
        uint256[] memory rates = strategy.depositRates();
        assertGt(rates.length, 0, "no deposit rates");
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
                assertGt(rates[iBestProvider], rates[i], "best provider rate not highest");
            }
        }
        // check that should=true only when activeProvider rate is different than newProvider
        assertEq(should, activeProvider.getDepositRateFor(strategy.vault()) != newProvider.getDepositRateFor(strategy.vault()), "wrong should value");
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
        // set strategy as executor in RebalancerManager
        vm.startPrank(0xc8a682F0991323777253ffa5fa6F19035685E723);
        vm.expectEmit(true, true, true, true);
        emit AllowExecutor(address(strategy), true);
        manager.allowExecutor(address(strategy), true);
        vm.stopPrank();

        IProvider[] memory providers = strategy.vault().getProviders();
        IProvider provider = strategy.vault().activeProvider();
        // find a provider that is not active provider
        for (uint256 i = 0; i < providers.length; i++) {
            if (providers[i] != provider) {
                provider = providers[i];
                break;
            }
        }
        // rebalance to the new provider
        vm.expectEmit(true, true, true, true);
        emit UpkeepPerformed(provider);
        strategy.performUpkeep(abi.encode(provider));
        assertEq(address(strategy.vault().activeProvider()), address(provider), "active provider not updated");
    }
}
