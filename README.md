# Rebalance Automation

This is a rebalance strategy to be used with Chainlink Automation to perform automatic rebalancing of assets in Rebalance Finance vaults without the use of a backend.

The strategy is implemented in `src/AutomationRebalanceStrategy.sol` and is compatible with Chainlink Automation.

## Access Control

The strategy can only be used by Chainlink Forwarder. Chainlink creates a new Forwarder contract for every new Chainlink Upkeep, so after setting up the Upkeep you should set the Forwarder address in the RebalanceStrategy contract by calling `setForwarder(address)` right away.

The RebalanceStrategy contract does not have any admin access. `setForwarder()` can only be called once, so once it's set, no one can affect the behavior of the contract. If you want to create a new Upkeep, you will have to deploy a new RebalanceStrategy contract.

RebalanceStrategy must have the Executor role in RebalancerManager. After deploying the RebalanceStrategy contract and setting the Forwarder, make sure to grant it the Executor role in the RebalancerManager contract.

## Prerequisites

1. [Install Foundry](https://book.getfoundry.sh/getting-started/installation)

## Setup

1. Clone this repository:

    `git clone https://github.com/REBALANCE-Finance/chainlink-automation.git`

1. Install dependencies:
    
    `forge install`

1. Create `.env` file from `.env.example`:

    `cp .env.example .env`

1. Update `.env` file with your values if needed.

## How to test

1. Run tests:

    `forge test`

## How to use

1. Deploy the RebalanceStrategy contract, setting the right Vault and RebalancerManager.

1. Create Chainlink Upkeep with Custom Logic and set the RebalanceStrategy address.

1. Get the Forwarder address from the Chainlink Upkeep.

1. Set the Forwarder address in the RebalanceStrategy contract by calling `setForwarder(address)`.

1. Grant the Executor role to RebalanceStrategy in the RebalancerManager contract.

1. Fund the Upkeep with LINK.

6. Run the Upkeep.
