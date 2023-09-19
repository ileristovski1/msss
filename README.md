1. (Relative Staiblity) Anchored or Pegged -> 1.0.0 denar 
   1. Chainlink Price feed 
   2. Set a function to exchange ETH & BTC -> denar amount
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
   1. People can only mint the stablecoin with enough collateral (coded) 
3. Collateral: Exogenous (Crypto/ERC20 versions) 
   1. wETH 
   2. wBTC

Liquidation Logic:
   120 000 DEN Worth of ETH (1 ETH = $2000) backing 60 000 DEN worth of MKD token
   (ETH PRICE TANKS) -> 24000 DEN of ETH backing 60 000 DEN worth of MKD token <- MKDToken isn't worth 1 DENAR
   If someone is almost undercollateralized, we will pay you to liquadate them
   Visualization:
   Price lowers from 120 000 DEN -> 90 000
   Liquidator takes 90 000 DEN worth of backing and pays off the 60 000 DEN worth of MKD
     
