# EDAI Stable Coin

> Educational reimplementation of MakerDAO's DAI system in modern Solidity.
> Study reference and portfolio project — not a production implementation.

![Network](https://img.shields.io/badge/network-Sepolia-blue)
![Solidity](https://img.shields.io/badge/solidity-0.8.24-lightgrey)
![Framework](https://img.shields.io/badge/framework-Foundry-orange)

---

## Motivation

DAI is one of the most thoroughly audited and battle-tested protocols in DeFi. Rewriting its core contracts was a deliberate exercise in understanding how a collateral-backed stablecoin actually works — not from documentation, but from code.

The goals were concrete:
- Understand the **architecture**: how each module fits together and why.
- Translate **legacy Solidity** patterns to idiomatic 0.8.x code.
- Build intuition about **collateral dynamics**: liquidation ratios, stability fees, and auction mechanics.

---

## Architecture

The system is built around a set of loosely coupled modules, each with a single responsibility.

**CDPEngine** is the core accounting contract. It tracks collateral balances, debt positions, and the internal units of account (`wad`, `ray`, `rad`). No module moves tokens without going through CDPEngine.

**Spotter** translates external price feed data into the `spot` price — the maximum debt a position can carry per unit of collateral. It reads from a Chainlink-compatible aggregator and applies the liquidation ratio (`mat`) to produce a safe collateral price.

**Jug** accrues stability fees over time. Each collateral type has its own fee rate (`duty`), compounded per second via a `drip()` call. Fees accumulate as system surplus in DSEngine.

**Pot** implements the DAI Savings Rate (DSR equivalent). Users deposit BEI to earn the base savings rate, funded from protocol surplus.

**DSEngine** (the `vow` equivalent) is the system's balance sheet. It absorbs bad debt from liquidations and surplus from stability fees. When surplus exceeds a threshold it triggers a SurplusAuction; when bad debt accumulates it triggers a DebtAuction.

**LiquidationEngine** monitors positions and initiates liquidations when collateral value drops below the required threshold. It dispatches collateral to a CollateralAuction.

**CollateralAuction** sells seized collateral in a falling-price Dutch auction using a `LinearDecrease` price calculator. Proceeds cover the liquidated debt and a liquidation penalty; any excess returns to the position owner.

**SurplusAuction** auctions off excess BEI for MockGov tokens, which are then burned. **DebtAuction** mints MockGov to cover uncovered system debt in exchange for BEI.

**GemJoin / CoinJoin** are the adapters that move real ERC-20 tokens in and out of the CDPEngine's internal accounting.

---

## Deployed Contracts — Sepolia

All contracts are verified on Etherscan.

| Contract | Address |
|---|---|
| MockWETH | [0xe6fcC3E43428a3eEDFA09E60699c2dA0b63E7c8D](https://sepolia.etherscan.io/address/0xe6fcC3E43428a3eEDFA09E60699c2dA0b63E7c8D) |
| MockGov | [0x54dADDa736721DeF324ef0EDc16f20C96eAf5A84](https://sepolia.etherscan.io/address/0x54dADDa736721DeF324ef0EDc16f20C96eAf5A84) |
| MockV3Aggregator | [0x8DCCf547C5209891AA4638CD3Cc6A226C387E030](https://sepolia.etherscan.io/address/0x8DCCf547C5209891AA4638CD3Cc6A226C387E030) |
| CDPEngine | [0xB5c84f63f5b1399d919a6e6BA2611525f5b7c955](https://sepolia.etherscan.io/address/0xB5c84f63f5b1399d919a6e6BA2611525f5b7c955) |
| Coin (BEI) | [0x6ADD2C82ddC0fD084BA3f34A79B301071221649e](https://sepolia.etherscan.io/address/0x6ADD2C82ddC0fD084BA3f34A79B301071221649e) |
| GemJoin | [0x880EF35b7af7dB72A14a35406d3fee9BCbb49E3a](https://sepolia.etherscan.io/address/0x880EF35b7af7dB72A14a35406d3fee9BCbb49E3a) |
| CoinJoin | [0xCe0fAC5556c408A1E34785FA6F32b6f7AFCAEFc2](https://sepolia.etherscan.io/address/0xCe0fAC5556c408A1E34785FA6F32b6f7AFCAEFc2) |
| Spotter | [0xA18B155c808EC9CB32d3C4B45C215414d8bED8d5](https://sepolia.etherscan.io/address/0xA18B155c808EC9CB32d3C4B45C215414d8bED8d5) |
| Jug | [0xe0637a50FDd2589C06B23864AE202680142d5546](https://sepolia.etherscan.io/address/0xe0637a50FDd2589C06B23864AE202680142d5546) |
| Pot | [0x3980d17a3C32964718a900485bCBb3ceEEc2d09C](https://sepolia.etherscan.io/address/0x3980d17a3C32964718a900485bCBb3ceEEc2d09C) |
| LinearDecrease | [0x49F00ca1505eDD4978a487D17241357a4E82dC9C](https://sepolia.etherscan.io/address/0x49F00ca1505eDD4978a487D17241357a4E82dC9C) |
| SurplusAuction | [0x786a7d7ed3373492E2255810fC2599559B7dFf34](https://sepolia.etherscan.io/address/0x786a7d7ed3373492E2255810fC2599559B7dFf34) |
| DebtAuction | [0x9e2ab487888CfEBcEDC14E4e7C498b9e03A2FF71](https://sepolia.etherscan.io/address/0x9e2ab487888CfEBcEDC14E4e7C498b9e03A2FF71) |
| DSEngine | [0x44029d21ab45EbBd8C769261c8c2B2590567721c](https://sepolia.etherscan.io/address/0x44029d21ab45EbBd8C769261c8c2B2590567721c) |
| LiquidationEngine | [0xb13175c77558D09416240187124DE6cC4473BFA3](https://sepolia.etherscan.io/address/0xb13175c77558D09416240187124DE6cC4473BFA3) |
| CollateralAuction | [0x3aeFfCb3e2C6e4FBfB064531d8ab95B718369934](https://sepolia.etherscan.io/address/0x3aeFfCb3e2C6e4FBfB064531d8ab95B718369934) |

---

## Usage

### Build and test

```shell
forge build
forge test

# End-to-end simulation of the full system
forge test --match-path test/sim/Sim.test.sol
```

### Deploy to Sepolia

**Prerequisites:**
- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- A `.env` file with `SEPOLIA_RPC_URL` and `ETHERSCAN_API_KEY`
- A keystore entry named `deployer`:
  ```shell
  cast wallet import deployer --interactive
  ```

**Run:**
```shell
bash script/deploy.sh
```

The script deploys all contracts in order, configures module permissions and parameters, and prints the deployed addresses.

---

## References

- [MakerDAO docs](https://docs.makerdao.com/)
- [dss (original contracts)](https://github.com/makerdao/dss)
- [dss-cdp-manager](https://github.com/makerdao/dss-cdp-manager)
- [dss-proxy-actions](https://github.com/makerdao/dss-proxy-actions)
- [osm](https://github.com/makerdao/osm)
- [Mainnet contract addresses](https://chainlog.sky.money/api/mainnet/active.json)
- [t4sk's DAI rewrite](https://github.com/t4sk/dai-rewrite) — initial inspiration

---

*This project was built to learn, not to deploy. The code is simplified and has not been audited.*
