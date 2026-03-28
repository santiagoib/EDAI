// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CDPEngine}         from "../src/stable-coin/CDPEngine.sol";
import {Spotter}           from "../src/stable-coin/Spotter.sol";
import {LinearDecrease}    from "../src/stable-coin/AuctionPriceCalculator.sol";
import {SurplusAuction}    from "../src/stable-coin/SurplusAuction.sol";
import {DebtAuction}       from "../src/stable-coin/DebtAuction.sol";
import {DSEngine}          from "../src/stable-coin/DSEngine.sol";
import {LiquidationEngine} from "../src/stable-coin/LiquidationEngine.sol";
import {CollateralAuction} from "../src/stable-coin/CollateralAuction.sol";
import {MockGov}           from "../src/mocks/MockGov.sol";

// ─────────────────────────────────────────────────────────────
//  Deploy 3 of 3 — Auctions + Liquidation
//  Deploys: LinearDecrease, SurplusAuction, DebtAuction,
//           DSEngine, LiquidationEngine, CollateralAuction
//  Also:    auth grants + full auction/liquidation initialization
//
//  Prerequisites (.env must contain):
//    CDPENGINE_ADDRESS   = <from Deploy1>
//    MOCKGOV_ADDRESS     = <from Deploy1>
//    SPOTTER_ADDRESS     = <from Deploy2>
//
//  Run:
//    forge script script/Deploy3.s.sol \
//      --rpc-url $SEPOLIA_RPC_URL \
//      --account deployer \
//      --broadcast \
//      --slow
// ─────────────────────────────────────────────────────────────

uint256 constant WAD3 = 1e18;
uint256 constant RAY3 = 1e27;
uint256 constant RAD3 = 1e45;

bytes32 constant WETH_TYPE3 = bytes32(bytes("WETH"));

contract Deploy3 is Script {

    function run() external {
        // ── Load previous addresses from env ──────────────────────
        CDPEngine cdpEngine = CDPEngine(vm.envAddress("CDPENGINE_ADDRESS"));
        MockGov   gov       = MockGov(vm.envAddress("MOCKGOV_ADDRESS"));
        Spotter   spotter   = Spotter(vm.envAddress("SPOTTER_ADDRESS"));

        vm.startBroadcast();

        // ── Deploy ────────────────────────────────────────────────
        LinearDecrease    calc           = new LinearDecrease();
        SurplusAuction    surplusAuction = new SurplusAuction(address(cdpEngine), address(gov));
        DebtAuction       debtAuction    = new DebtAuction(address(cdpEngine), address(gov));

        // DSEngine constructor internally calls cdpEngine.allow_account_modification(surplusAuction)
        DSEngine          dsEngine       = new DSEngine(
            address(cdpEngine),
            address(surplusAuction),
            address(debtAuction)
        );

        LiquidationEngine liqEngine      = new LiquidationEngine(address(cdpEngine));
        CollateralAuction colAuction     = new CollateralAuction(
            address(cdpEngine),
            address(spotter),
            address(liqEngine),
            WETH_TYPE3
        );

        // ── Auth grants ───────────────────────────────────────────
        cdpEngine.grant_auth(address(dsEngine));
        cdpEngine.grant_auth(address(liqEngine));
        cdpEngine.grant_auth(address(colAuction));

        // Gov token allows debtAuction to mint (covers bad debt)
        gov.grant_auth(address(debtAuction));

        // LiquidationEngine allows colAuction to call remove_coin_from_auction
        liqEngine.grant_auth(address(colAuction));

        // ── LinearDecrease (collateral auction price) ─────────────
        calc.set("duration", uint256(3600));           // price hits 0 in 1 hour

        // ── DSEngine (surplus / debt manager) ─────────────────────
        dsEngine.set("pop_debt_delay",           uint256(3600)); // 1 hour debt queue
        dsEngine.set("debt_auction_lot_size",    100  * WAD3);   // 100 mGOV per auction
        dsEngine.set("debt_auction_bid_size",    10_000 * RAD3); // 10k BEI per debt auction
        dsEngine.set("surplus_auction_lot_size", 5_000 * RAD3);  // 5k BEI per surplus auction
        dsEngine.set("min_surplus",              1_000 * RAD3);  // need 1k BEI surplus to start

        // ── LiquidationEngine ─────────────────────────────────────
        liqEngine.set("ds_engine", address(dsEngine));
        liqEngine.set("max_coin",  10_000_000 * RAD3);
        liqEngine.set(WETH_TYPE3, "auction",  address(colAuction));
        liqEngine.set(WETH_TYPE3, "penalty",  113 * WAD3 / 100);    // 1.13 = 13% penalty
        liqEngine.set(WETH_TYPE3, "max_coin", 10_000_000 * RAD3);

        // ── CollateralAuction ─────────────────────────────────────
        colAuction.set("ds_engine",             address(dsEngine));
        colAuction.set("calc",                  address(calc));
        colAuction.set("boost",                 105 * RAY3 / 100); // 1.05 RAY starting price
        colAuction.set("max_duration",          uint256(3600));    // 1 hour max
        colAuction.set("min_delta_price_ratio", RAY3 / 2);         // reset if price drops 50%

        vm.stopBroadcast();

        console.log("=== Deploy 3/3: Auctions + Liquidation ===");
        console.log("LinearDecrease:     ", address(calc));
        console.log("SurplusAuction:     ", address(surplusAuction));
        console.log("DebtAuction:        ", address(debtAuction));
        console.log("DSEngine:           ", address(dsEngine));
        console.log("LiquidationEngine:  ", address(liqEngine));
        console.log("CollateralAuction:  ", address(colAuction));
    }
}
