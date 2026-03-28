#!/usr/bin/env bash
set -e

# ── Addresses ────────────────────────────────────────────────────────────────
MOCKWETH_ADDRESS=0xe6fcC3E43428a3eEDFA09E60699c2dA0b63E7c8D
MOCKGOV_ADDRESS=0x54dADDa736721DeF324ef0EDc16f20C96eAf5A84
PRICE_FEED_ADDRESS=0x8DCCf547C5209891AA4638CD3Cc6A226C387E030
CDP_ENGINE_ADDRESS=0xB5c84f63f5b1399d919a6e6BA2611525f5b7c955
COIN_ADDRESS=0x6ADD2C82ddC0fD084BA3f34A79B301071221649e
GEM_JOIN_ADDRESS=0x880EF35b7af7dB72A14a35406d3fee9BCbb49E3a
COIN_JOIN_ADDRESS=0xCe0fAC5556c408A1E34785FA6F32b6f7AFCAEFc2
SPOTTER_ADDRESS=0xA18B155c808EC9CB32d3C4B45C215414d8bED8d5
JUG_ADDRESS=0xe0637a50FDd2589C06B23864AE202680142d5546
POT_ADDRESS=0x3980d17a3C32964718a900485bCBb3ceEEc2d09C
LINEAR_DECREASE_ADDRESS=0x49F00ca1505eDD4978a487D17241357a4E82dC9C
SURPLUS_AUCTION_ADDRESS=0x786a7d7ed3373492E2255810fC2599559B7dFf34
DEBT_AUCTION_ADDRESS=0x9e2ab487888CfEBcEDC14E4e7C498b9e03A2FF71
DS_ENGINE_ADDRESS=0x44029d21ab45EbBd8C769261c8c2B2590567721c
LIQ_ENGINE_ADDRESS=0xb13175c77558D09416240187124DE6cC4473BFA3
COL_AUCTION_ADDRESS=0x3aeFfCb3e2C6e4FBfB064531d8ab95B718369934
WETH_ILK=0x574554482d410000000000000000000000000000000000000000000000000000

# ── Checks ───────────────────────────────────────────────────────────────────
if [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "Error: ETHERSCAN_API_KEY is not set"
  exit 1
fi

CHAIN="sepolia"
CHAIN_ID=11155111

verify() {
  local label="$1"
  local addr="$2"
  local contract="$3"   # path/to/File.sol:ContractName
  shift 3
  # remaining args are --constructor-args ...

  echo ""
  echo "── Verifying $label ($addr) ──"
  forge verify-contract \
    --chain-id "$CHAIN_ID" \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    --compiler-version 0.8.24 \
    --watch \
    "$addr" \
    "$contract" \
    "$@"
}

# ── No-constructor contracts ──────────────────────────────────────────────────
verify "MockWETH"        "$MOCKWETH_ADDRESS"       "src/mocks/MockWETH.sol:MockWETH"
verify "MockGov"         "$MOCKGOV_ADDRESS"        "src/mocks/MockGov.sol:MockGov"
verify "CDPEngine"       "$CDP_ENGINE_ADDRESS"     "src/stable-coin/CDPEngine.sol:CDPEngine"
verify "Coin"            "$COIN_ADDRESS"           "src/stable-coin/Coin.sol:Coin"
verify "LinearDecrease"  "$LINEAR_DECREASE_ADDRESS" "src/stable-coin/AuctionPriceCalculator.sol:LinearDecrease"

# ── MockV3Aggregator(int256 _initialAnswer) → 2000e8 = 200000000000 ──────────
verify "MockV3Aggregator (PriceFeed)" "$PRICE_FEED_ADDRESS" \
  "src/mocks/MockV3Aggregator.sol:MockV3Aggregator" \
  --constructor-args $(cast abi-encode "constructor(int256)" 200000000000)

# ── GemJoin(address cdp_engine, bytes32 collateral_type, address gem) ────────
verify "GemJoin" "$GEM_JOIN_ADDRESS" \
  "src/stable-coin/GemJoin.sol:GemJoin" \
  --constructor-args $(cast abi-encode "constructor(address,bytes32,address)" \
    "$CDP_ENGINE_ADDRESS" "$WETH_ILK" "$MOCKWETH_ADDRESS")

# ── CoinJoin(address cdp_engine, address coin) ───────────────────────────────
verify "CoinJoin" "$COIN_JOIN_ADDRESS" \
  "src/stable-coin/CoinJoin.sol:CoinJoin" \
  --constructor-args $(cast abi-encode "constructor(address,address)" \
    "$CDP_ENGINE_ADDRESS" "$COIN_ADDRESS")

# ── Spotter(address cdp_engine) ──────────────────────────────────────────────
verify "Spotter" "$SPOTTER_ADDRESS" \
  "src/stable-coin/Spotter.sol:Spotter" \
  --constructor-args $(cast abi-encode "constructor(address)" "$CDP_ENGINE_ADDRESS")

# ── Jug(address cdp_engine) ──────────────────────────────────────────────────
verify "Jug" "$JUG_ADDRESS" \
  "src/stable-coin/Jug.sol:Jug" \
  --constructor-args $(cast abi-encode "constructor(address)" "$CDP_ENGINE_ADDRESS")

# ── Pot(address cdp_engine) ──────────────────────────────────────────────────
verify "Pot" "$POT_ADDRESS" \
  "src/stable-coin/Pot.sol:Pot" \
  --constructor-args $(cast abi-encode "constructor(address)" "$CDP_ENGINE_ADDRESS")

# ── SurplusAuction(address cdp_engine, address gem) ─────────────────────────
verify "SurplusAuction" "$SURPLUS_AUCTION_ADDRESS" \
  "src/stable-coin/SurplusAuction.sol:SurplusAuction" \
  --constructor-args $(cast abi-encode "constructor(address,address)" \
    "$CDP_ENGINE_ADDRESS" "$MOCKGOV_ADDRESS")

# ── DebtAuction(address cdp_engine, address gem) ────────────────────────────
verify "DebtAuction" "$DEBT_AUCTION_ADDRESS" \
  "src/stable-coin/DebtAuction.sol:DebtAuction" \
  --constructor-args $(cast abi-encode "constructor(address,address)" \
    "$CDP_ENGINE_ADDRESS" "$MOCKGOV_ADDRESS")

# ── DSEngine(address cdp_engine, address surplus_auction, address debt_auction)
verify "DSEngine" "$DS_ENGINE_ADDRESS" \
  "src/stable-coin/DSEngine.sol:DSEngine" \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" \
    "$CDP_ENGINE_ADDRESS" "$SURPLUS_AUCTION_ADDRESS" "$DEBT_AUCTION_ADDRESS")

# ── LiquidationEngine(address cdp_engine) ───────────────────────────────────
verify "LiquidationEngine" "$LIQ_ENGINE_ADDRESS" \
  "src/stable-coin/LiquidationEngine.sol:LiquidationEngine" \
  --constructor-args $(cast abi-encode "constructor(address)" "$CDP_ENGINE_ADDRESS")

# ── CollateralAuction(address cdp_engine, address spotter, address liq_engine, bytes32 collateral_type)
verify "CollateralAuction" "$COL_AUCTION_ADDRESS" \
  "src/stable-coin/CollateralAuction.sol:CollateralAuction" \
  --constructor-args $(cast abi-encode "constructor(address,address,address,bytes32)" \
    "$CDP_ENGINE_ADDRESS" "$SPOTTER_ADDRESS" "$LIQ_ENGINE_ADDRESS" "$WETH_ILK")

echo ""
echo "✓ All contracts verified."
