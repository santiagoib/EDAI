# EDAI Stable Coin 🪙

Educational project: rewriting MakerDAO’s DAI system

This project does not intend to reinvent the wheel — it is a practical exercise to learn how DAI works under the hood. The goal was to recreate the core logic of DAI to understand:

- **How a collateral-backed stablecoin is built.** By reimplementing the modules, you gain intuition about how a system like DAI maintains parity with the dollar while being over‑collateralized.
- **The role of each module** (`vat`, `pot`, `vow`, `clipper`, etc.), which manage collateral, interest accrual, liquidations and auctions.
- **The interaction between parameters** such as the liquidation ratio (`mat`), the spot price (`spot`) and debt ceilings. These parameters determine when liquidations occur and how much DAI can be minted against an asset.

This repository serves as a study reference and portfolio project, **not a production implementation**.

## 🎯 Motivation

DAI is one of the most important and battle‑tested protocols in DeFi. By rewriting its contracts in simplified form I aimed to:

- Learn the **architecture** behind a real stablecoin.
- Practise reading and translating legacy code to modern Solidity.
- Gain intuition about the **dynamics of collateral**, stability fees and liquidations.

The emphasis is on personal learning and not on launching a new product.

## 🛠️ Tech stack

- **Solidity** (latest version).
- **Foundry** with `forge-std` to compile and run tests.
- Modular contracts inspired by the DSS (Dai Stablecoin System) of MakerDAO.

## 🚀 Usage

To compile and run the tests with Foundry:
```shell
forge build
forge test
```

```shell
# Check this test for how the system works
forge test --match-path test/sim/Sim.test.sol
```

### Links

- [docs](https://docs.makerdao.com/)
- [dss](https://github.com/makerdao/dss)
- [dss-proxy](https://github.com/makerdao/dss-proxy)
- [dss-proxy-actions](https://github.com/makerdao/dss-proxy-actions)
- [dss-cdp-manager](https://github.com/makerdao/dss-cdp-manager)
- [osm](https://github.com/makerdao/osm)
- [contract addresses](https://chainlog.sky.money/api/mainnet/active.json)

TODO: ESM

TODO: OSM

TODO: gov

TODO: test

- pot
- vow
- clipper
- dog
- flopper
- flapper
- cdp manager

### Memo

ETH A - 0x4554482d41000000000000000000000000000000000000000000000000000000

ETH C - 0x4554482d43000000000000000000000000000000000000000000000000000000

```
par [ray] 1000000000000000000000000000
mat [ray] 1450000000000000000000000000
val [wad] 2067300000000000000000
spot [ray] 1429862068965517241379310344827

liquidation ratio = mat / par
                  = collateral USD value / debt USD value

liquidation price = spot = val * 1e9 * par / mat
```
## 🙌 Inspiration

This project was inspired by [t4sk's work](https://github.com/t4sk/dai-rewrite) and MakerDAO’s original [DAI system](https://github.com/makerdao/dss).  
The goal was **learn by rebuilding** the core components of a real DeFi protocol.  
