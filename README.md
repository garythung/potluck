# Potluck

Ever wanted to ape into a shitcoin with your friends? Well now you can with Potluck!

Potluck is a group fund used to purchase a single asset. Contributors pool their ETH together and when the target amount is hit, the funds are exchanged for the target asset on the open market. Currently, Potluck only supports ERC20s and the exchange is done using Uniswap.

Shout out to [Anish Agnihotri](https://twitter.com/_anishagnihotri) who created [PartyBid](https://github.com/Anish-Agnihotri/partybid). The code here is a fork of his PartyBid contract.

## 🧐 How does Potluck work?

1. Deploy a potluck using `Potluck.sol`. Parameters required are the **ERC20 token address** you want to purchase, the **amount of ETH to be raised** (unit is wei), and the **deadline for funding** (unit is unix timestamp)

2. People call `join()` and send ETH to participate in the potluck.

3. When the target funding amount is reached, then any contributor may execute the purchase with `executeBuy()`. Contributors can then retrieve their share of the purchase with `exit()`.

4. If the funding deadline `exitTimeout` is reached and the buy hasn't been executed, then contributors may `exit()` and retrieve their funds. Anyone who exits may not rejoin.

## 🛠 Building and deployment

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Fork mainnet to local so that you get Uniswap, WETH, etc. with this guide
# https://hardhat.org/guides/mainnet-forking.html

# Deploy
npx hardhat run scripts/deploy.js --network localhost # (fill in the deploy script to your liking)
```

## ⚠️ Caveats

This contract has not been tested on testnet or mainnet and has been developed with a local fork of mainnet. Make sure to check that the Uniswap liquidity pool for ETH and your target ERC20 token is stable. **Use at your own risk.**

## 💡 Extensions

1. Route the order through an MEV optimizer. Large buy orders are prime targets for frontrunning so using something like KeeperDAO would help here.
2. Use a liquidity aggregator. Using a liquidity aggregator like 0x would be an improvement over a single provider.
3. Create a factory contract to spin up Potlucks. This sole contract isn't enough to have a protocol.
4. Earn yield with idle potluck funds. Put funds into Yearn while waiting to reach the funding target.
