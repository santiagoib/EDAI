#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────────────────────
#  EDAI — Sequential deploy to Sepolia via forge create
#  Usage: bash script/deploy.sh
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../.env"

: "${SEPOLIA_RPC_URL:?Need SEPOLIA_RPC_URL in .env}"

RPC="$SEPOLIA_RPC_URL"
ACCOUNT="--account deployer"
FORGE_FLAGS="--rpc-url $RPC $ACCOUNT --broadcast"

# Extract deployed address from forge create output
addr() { grep -oP 'Deployed to: \K0x[0-9a-fA-F]{40}'; }

echo "================================================================"
echo " EDAI deploy — Sepolia"
echo "================================================================"
echo ""

# ── 1. MockWETH ──────────────────────────────────────────────
echo "[1/16] MockWETH..."
MOCKWETH=$(forge create src/mocks/MockWETH.sol:MockWETH \
  $FORGE_FLAGS 2>&1 | tee /dev/stderr | addr)
echo "  MockWETH: $MOCKWETH"
sleep 3

# ── 2. MockGov ───────────────────────────────────────────────
echo "[2/16] MockGov..."
MOCKGOV=$(forge create src/mocks/MockGov.sol:MockGov \
  $FORGE_FLAGS 2>&1 | tee /dev/stderr | addr)
echo "  MockGov: $MOCKGOV"
sleep 3

# ── 3. MockV3Aggregator ──────────────────────────────────────
# constructor(int256 _initialAnswer) — 2000 USD with 8 decimals
echo "[3/16] MockV3Aggregator..."
PRICE_FEED=$(forge create src/mocks/MockV3Aggregator.sol:MockV3Aggregator \
  $FORGE_FLAGS \
  --constructor-args 200000000000 \
  2>&1 | tee /dev/stderr | addr)
echo "  MockV3Aggregator: $PRICE_FEED"
sleep 3

# ── 4. CDPEngine ─────────────────────────────────────────────
echo "[4/16] CDPEngine..."
CDP_ENGINE=$(forge create src/stable-coin/CDPEngine.sol:CDPEngine \
  $FORGE_FLAGS 2>&1 | tee /dev/stderr | addr)
echo "  CDPEngine: $CDP_ENGINE"
sleep 3

# ── 5. Coin (BEI stablecoin) ─────────────────────────────────
# constructor() — no args
echo "[5/16] Coin (BEI)..."
COIN=$(forge create src/stable-coin/Coin.sol:Coin \
  $FORGE_FLAGS 2>&1 | tee /dev/stderr | addr)
echo "  Coin: $COIN"
sleep 3

# ── 6. GemJoin ───────────────────────────────────────────────
# constructor(address cdpEngine, bytes32 ilk, address gem)
ILK=$(cast format-bytes32-string "WETH-A")
echo "[6/16] GemJoin (ilk=$ILK)..."
GEM_JOIN=$(forge create src/stable-coin/GemJoin.sol:GemJoin \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" "$ILK" "$MOCKWETH" \
  2>&1 | tee /dev/stderr | addr)
echo "  GemJoin: $GEM_JOIN"
sleep 3

# ── 7. CoinJoin ──────────────────────────────────────────────
echo "[7/16] CoinJoin..."
COIN_JOIN=$(forge create src/stable-coin/CoinJoin.sol:CoinJoin \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" "$COIN" \
  2>&1 | tee /dev/stderr | addr)
echo "  CoinJoin: $COIN_JOIN"
sleep 3

# ── 8. Spotter ───────────────────────────────────────────────
echo "[8/16] Spotter..."
SPOTTER=$(forge create src/stable-coin/Spotter.sol:Spotter \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" \
  2>&1 | tee /dev/stderr | addr)
echo "  Spotter: $SPOTTER"
sleep 3

# ── 9. Jug ───────────────────────────────────────────────────
echo "[9/16] Jug..."
JUG=$(forge create src/stable-coin/Jug.sol:Jug \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" \
  2>&1 | tee /dev/stderr | addr)
echo "  Jug: $JUG"
sleep 3

# ── 10. Pot ──────────────────────────────────────────────────
echo "[10/16] Pot..."
POT=$(forge create src/stable-coin/Pot.sol:Pot \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" \
  2>&1 | tee /dev/stderr | addr)
echo "  Pot: $POT"
sleep 3

# ── 11. LinearDecrease ───────────────────────────────────────
# Lives in AuctionPriceCalculator.sol — specify :ContractName
echo "[11/16] LinearDecrease..."
LINEAR_DECREASE=$(forge create src/stable-coin/AuctionPriceCalculator.sol:LinearDecrease \
  $FORGE_FLAGS 2>&1 | tee /dev/stderr | addr)
echo "  LinearDecrease: $LINEAR_DECREASE"
sleep 3

# ── 12. SurplusAuction ───────────────────────────────────────
echo "[12/16] SurplusAuction..."
SURPLUS_AUCTION=$(forge create src/stable-coin/SurplusAuction.sol:SurplusAuction \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" "$MOCKGOV" \
  2>&1 | tee /dev/stderr | addr)
echo "  SurplusAuction: $SURPLUS_AUCTION"
sleep 3

# ── 13. DebtAuction ──────────────────────────────────────────
echo "[13/16] DebtAuction..."
DEBT_AUCTION=$(forge create src/stable-coin/DebtAuction.sol:DebtAuction \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" "$MOCKGOV" \
  2>&1 | tee /dev/stderr | addr)
echo "  DebtAuction: $DEBT_AUCTION"
sleep 3

# ── 14. DSEngine ─────────────────────────────────────────────
# constructor(address cdpEngine, address surplusAuction, address debtAuction)
echo "[14/16] DSEngine..."
DS_ENGINE=$(forge create src/stable-coin/DSEngine.sol:DSEngine \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" "$SURPLUS_AUCTION" "$DEBT_AUCTION" \
  2>&1 | tee /dev/stderr | addr)
echo "  DSEngine: $DS_ENGINE"
sleep 3

# ── 15. LiquidationEngine ────────────────────────────────────
echo "[15/16] LiquidationEngine..."
LIQ_ENGINE=$(forge create src/stable-coin/LiquidationEngine.sol:LiquidationEngine \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" \
  2>&1 | tee /dev/stderr | addr)
echo "  LiquidationEngine: $LIQ_ENGINE"
sleep 3

# ── 16. CollateralAuction ────────────────────────────────────
# constructor(address cdpEngine, address spotter, address liqEngine, bytes32 collateralType)
echo "[16/16] CollateralAuction..."
COL_AUCTION=$(forge create src/stable-coin/CollateralAuction.sol:CollateralAuction \
  $FORGE_FLAGS \
  --constructor-args "$CDP_ENGINE" "$SPOTTER" "$LIQ_ENGINE" "$ILK" \
  2>&1 | tee /dev/stderr | addr)
echo "  CollateralAuction: $COL_AUCTION"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "================================================================"
echo " Deploy complete — copy-paste to .env"
echo "================================================================"
echo ""
echo "MOCKWETH_ADDRESS=$MOCKWETH"
echo "MOCKGOV_ADDRESS=$MOCKGOV"
echo "PRICE_FEED_ADDRESS=$PRICE_FEED"
echo "CDP_ENGINE_ADDRESS=$CDP_ENGINE"
echo "COIN_ADDRESS=$COIN"
echo "GEM_JOIN_ADDRESS=$GEM_JOIN"
echo "COIN_JOIN_ADDRESS=$COIN_JOIN"
echo "SPOTTER_ADDRESS=$SPOTTER"
echo "JUG_ADDRESS=$JUG"
echo "POT_ADDRESS=$POT"
echo "LINEAR_DECREASE_ADDRESS=$LINEAR_DECREASE"
echo "SURPLUS_AUCTION_ADDRESS=$SURPLUS_AUCTION"
echo "DEBT_AUCTION_ADDRESS=$DEBT_AUCTION"
echo "DS_ENGINE_ADDRESS=$DS_ENGINE"
echo "LIQ_ENGINE_ADDRESS=$LIQ_ENGINE"
echo "COL_AUCTION_ADDRESS=$COL_AUCTION"
echo "WETH_ILK=$ILK"
