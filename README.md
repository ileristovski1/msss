# Macedonian Standard Stablecoin System

![AI Generated Image for the MSS System](https://i.imgur.com/2u3B8cf.jpeg)

Welcome to the official repository for the Macedonian Standard Stablecoin system, a decentralized stable coin linked to the Macedonian Denar. This project is authored and maintained by Ilija Ristovski.

## Overview

This decentralized stablecoin is designed to provide relative stability by being pegged to the Macedonian Denar, the national currency of North Macedonia. The system utilizes a collateral mechanism with exogenous assets such as ETH and BTC. The minting process is algorithmic and decentralized, ensuring that the stablecoin remains stable and secure.

## Features

### Pegging and Stability

- **Relative Stability:** The stablecoin is anchored or pegged to 1.0.0 Denar.
- **Chainlink Price Feed:** The system uses Chainlink price feeds to maintain accurate and real-time pricing information.

### Minting and Collateral

- **Minting Mechanism:** Algorithmic minting ensures decentralized control over the creation of stablecoins.
- **Collateral Types:** Users can mint stablecoins by providing collateral in the form of exogenous assets, including wETH and wBTC.

### Stability Mechanism

- **Decentralized Stability:** The stability mechanism is decentralized, and users can only mint stablecoins if they have sufficient collateral, as coded in the system.

### Liquidation Logic

- **Liquidation Threshold:** If a user's collateral falls below a certain threshold, liquidation is triggered.
- **Liquidation Process:** A liquidator takes a portion of the collateral to pay off the stablecoin debt. Visualization: As the price of ETH drops, the liquidator steps in to prevent undercollateralization.

### Example Scenario

- **Initial State:** 120,000 DEN worth of ETH (1 ETH = $2000) backs 60,000 DEN worth of MKD token.
- **Price Drop:** ETH price decreases, and the backing reduces to 90,000 DEN.
- **Liquidation:** The liquidator steps in, taking 90,000 DEN worth of backing to pay off the 60,000 DEN worth of MKD token.

## Getting Started

To explore and contribute to the Macedonian Standard Stablecoin system, follow these steps:

1. Clone the repository: `git clone https://github.com/ileristovski1/msss.git`
2. Install dependencies: `npm install`
3. Explore the codebase and documentation to understand the system architecture.

Feel free to reach out to Ilija Ristovski for any questions or collaboration opportunities.

Thank you for your interest in the Macedonian Standard Stablecoin system!
