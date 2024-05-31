// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RebalanceStrategy} from "../src/AutomationRebalanceStrategy.sol";
import {IInterestVault} from "../src/interfaces/IInterestVault.sol";
import {IProvider} from "../src/interfaces/IProvider.sol";

contract AutomationRebalanceStrategyTest is Test {
    RebalanceStrategy public strategy;

    event UpkeepPerformed(IProvider newProvider);

    function setUp() public {
        IInterestVault vault = IInterestVault(0xD430e22c3a0F8Ebd6813411084a5cb26937f6661);
        strategy = new RebalanceStrategy(vault);
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

    // function test_ShouldRebalanceWhenNotBest() public view {
    //     // set provider rates artificially
    //     IProvider[] memory providers = strategy.vault().getProviders();
    //     // TODO: set rates for each provider
    //     // Aave
    //     // getDepositRatesFor(vault) calls 0x794a61358D6845594F94dc1DB02A252b5b4814aD.getReserveData(vault.asset())
    //     // which returns a ReserveData struct: https://arbiscan.io/address/0x03e8c5cd5e194659b16456bb43dd5d38886fe541#code#F45#L1
    //     // which has a variable currentLiquidityRate
    //     // Radiant
    //     // same but 0xF4B1486DD74D07706052A33d31d7c0AAFD0659E1
    //     // DForce
    //     // more complicated: https://arbiscan.io/address/0x2c17806FF8bE2f9507AA75E3857eB49E8185ca70#code#F14#L122
    //     // Compound
    //     // more complicated with CometInterface cMarketV3.getUtilization() etc:
    //     // https://arbiscan.io/address/0x7Ff252970E13A49B3070E199C82786Eb54c76030#code#F8#L67
    // }

    function test_CheckUpkeep() public view {
        IProvider activeProvider = strategy.vault().activeProvider();
        (bool upkeepNeeded, bytes memory performData) = strategy.checkUpkeep("");
        if (upkeepNeeded) {
            IProvider newProvider = abi.decode(performData, (IProvider));
            assertTrue(newProvider != activeProvider);
        }
    }

    function test_PerformUpkeep() public {
        IProvider provider = strategy.vault().activeProvider();
        vm.expectEmit(true, true, true, true);
        emit UpkeepPerformed(provider);
        strategy.performUpkeep(abi.encode(provider));
    }
}
