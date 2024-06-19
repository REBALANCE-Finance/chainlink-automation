// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RebalanceStrategy} from "../src/AutomationRebalanceStrategy.sol";
import {IRebalancerManager} from "../src/interfaces/IRebalancerManager.sol";
import {IInterestVault} from "../src/interfaces/IInterestVault.sol";
import {IProvider} from "../src/interfaces/IProvider.sol";

// Test for RebalanceStrategy
contract RebalanceStrategyTest is Test {
    RebalanceStrategy public strategy;  // instance of RebalanceStrategy used in tests
    IRebalancerManager public manager;  // RebalancerManager strategy uses
    IInterestVault public vault;        // InterestVault strategy manages

    // Error thrown by Ownable.onlyOwner
    error OwnableUnauthorizedAccount(address account);

    // Event expected to be emitted by RebalanceStrategy.performUpkeep()
    event UpkeepPerformed(IProvider newProvider);
    // Event expected to be emitted by RebalancerManager.allowExecutor()
    event AllowExecutor(address indexed executor, bool allowed);

    // Called before each test
    function setUp() public {
        // set up a fork of the network to test on live contracts
        vm.createSelectFork(vm.envString("RPC_URL"));
        // get the vault and the manager contracts
        vault = IInterestVault(vm.envAddress("VAULT"));
        manager = IRebalancerManager(vm.envAddress("REBALANCER_MANAGER"));
        // instantiate strategy with the vault and the manager
        strategy = new RebalanceStrategy(vault, manager);
    }

    // Should be able to set the forwarder
    function test_CanSetForwarder() public {
        strategy.setForwarder(address(this));
        assertEq(strategy.forwarder(), address(this), "forwarder not set");
    }

    // Should not be able to set the forwarder if not the owner
    function test_CannotSetForwarderIfNotOwner() public {
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(0)));
        vm.prank(address(0));
        strategy.setForwarder(address(this));
    }

    // Should be able to update settings successfully
    function test_CanUpdateSettings() public {
        uint256 t = strategy.minRebalanceInterval() + 1;
        uint256 d = strategy.minRebalanceDeltaRate() + 1;
        vm.expectEmit(true, true, true, true);
        emit RebalanceStrategy.SettingsUpdated(t, d);
        strategy.updateSettings(t, d);
        assertEq(strategy.minRebalanceInterval(), t, "minRebalanceInterval not updated correctly");
        assertEq(strategy.minRebalanceDeltaRate(), d, "minRebalanceDeltaRate not updated correctly");
    }

    // Should not be able to update settings if not the owner
    function test_CannotUpdateSettingsIfNotOwner() public {
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(0)));
        vm.prank(address(0));
        strategy.updateSettings(0, 0);
    }

    // Should be able to get providers from the vault
    function test_HasProviders() public view {
        IProvider[] memory providers = strategy.vault().getProviders();
        assertGt(providers.length, 0, "no providers");
    }

    // Should be able to get current deposit rates for each provider
    function test_GetsDepositRates() public view {
        uint256[] memory rates = strategy.depositRates();
        assertGt(rates.length, 0, "no deposit rates");
    }

    // Should be able to check if a rebalancing is needed
    function test_CanCheckIfShouldRebalance() public view {
        // get providers and rates
        IProvider[] memory providers = strategy.vault().getProviders();
        IProvider activeProvider = strategy.vault().activeProvider();
        uint256[] memory rates = strategy.depositRates();
        // check what strategy is saying
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
        // check if should rebalance
        uint256 rateActive = activeProvider.getDepositRateFor(strategy.vault());
        uint256 rateHighest = newProvider.getDepositRateFor(strategy.vault());
        if (
            strategy.lastRebalance() + strategy.minRebalanceInterval() <= block.timestamp &&
            rateHighest - rateActive >= strategy.minRebalanceDeltaRate()
        ) {
            assertEq(should, true, "should rebalance is false");
        } else {
            assertEq(should, false, "should rebalance is true");
        }
    }

    // Should execute checkUpkeep() correctly
    function test_CanCheckUpkeep() public view {
        IProvider activeProvider = strategy.vault().activeProvider();
        (bool upkeepNeeded, bytes memory performData) = strategy.checkUpkeep("");
        if (upkeepNeeded) {
            // if upkeep is needed, the new provider should be different from the active provider
            IProvider newProvider = abi.decode(performData, (IProvider));
            assertTrue(newProvider != activeProvider, "new provider same as active provider");
        }
    }

    // Should only be able to perform upkeep by the forwarder
    function test_CannotPerformUpkeepIfNotForwarder() public {
        IProvider[] memory providers = strategy.vault().getProviders();
        vm.expectRevert("Only the forwarder can call this function");
        strategy.performUpkeep(abi.encode(providers[0]));
    }

    // Should perform upkeep correctly
    function test_CanPerformUpkeep() public {
        // set strategy as executor in RebalancerManager, impersonating the admin of RebalancerManager
        vm.startPrank(vm.envAddress("REBALANCER_MANAGER_ADMIN"));
        vm.expectEmit(true, true, true, true);
        emit AllowExecutor(address(strategy), true);
        manager.allowExecutor(address(strategy), true);
        vm.stopPrank();
        // set this test contract as the forwarder to perform the upkeep
        strategy.setForwarder(address(this));
        // get providers
        IProvider[] memory providers = strategy.vault().getProviders();
        IProvider provider = strategy.vault().activeProvider();
        // find a provider that is not the active provider
        for (uint256 i = 0; i < providers.length; i++) {
            if (providers[i] != provider) {
                provider = providers[i];
                break;
            }
        }
        // rebalance to the other provider
        vm.expectEmit(true, true, true, true);
        emit UpkeepPerformed(provider);
        strategy.performUpkeep(abi.encode(provider));
        assertEq(address(strategy.vault().activeProvider()), address(provider), "active provider not updated");
    }
}

