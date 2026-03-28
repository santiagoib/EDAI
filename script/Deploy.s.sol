// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CDPEngine}              from "../src/stable-coin/CDPEngine.sol";
import {Coin}                   from "../src/stable-coin/Coin.sol";
import {GemJoin}                from "../src/stable-coin/GemJoin.sol";
import {CoinJoin}               from "../src/stable-coin/CoinJoin.sol";
import {Spotter}                from "../src/stable-coin/Spotter.sol";
import {Jug}                    from "../src/stable-coin/Jug.sol";
import {Pot}                    from "../src/stable-coin/Pot.sol";
import {LinearDecrease}         from "../src/stable-coin/AuctionPriceCalculator.sol";
import {SurplusAuction}         from "../src/stable-coin/SurplusAuction.sol";
import {DebtAuction}            from "../src/stable-coin/DebtAuction.sol";
import {DSEngine}               from "../src/stable-coin/DSEngine.sol";
import {LiquidationEngine}      from "../src/stable-coin/LiquidationEngine.sol";
import {CollateralAuction}      from "../src/stable-coin/CollateralAuction.sol";
import {MockWETH}               from "../src/mocks/MockWETH.sol";
import {MockGov}                from "../src/mocks/MockGov.sol";
import {MockV3Aggregator}       from "../src/mocks/MockV3Aggregator.sol";

uint256 constant WAD = 1e18;
uint256 constant RAY = 1e27;
uint256 constant RAD = 1e45;

bytes32 constant WETH_TYPE = bytes32(bytes("WETH"));

contract DeployEDAI is Script {

    // ── Deployed addresses (state avoids stack-too-deep in run()) ──
    MockWETH          internal weth;
    MockGov           internal gov;
    MockV3Aggregator  internal priceFeed;
    CDPEngine         internal cdpEngine;
    Coin              internal coin;
    GemJoin           internal gemJoin;
    CoinJoin          internal coinJoin;
    Spotter           internal spotter;
    Jug               internal jug;
    Pot               internal pot;
    LinearDecrease    internal calc;
    SurplusAuction    internal surplusAuction;
    DebtAuction       internal debtAuction;
    DSEngine          internal dsEngine;
    LiquidationEngine internal liqEngine;
    CollateralAuction internal colAuction;

    function run() external {
        vm.startBroadcast();

        _deployContracts();
        _grantAuth();
        _initCDPEngine();
        _initSpotter();
        _initJug();
        _initCalc();
        _initDSEngine();
        _initLiqEngine();
        _initColAuction();

        vm.stopBroadcast();

        _logAddresses();
    }

    // ── Deploy ────────────────────────────────────────────────────

    function _deployContracts() internal {
        // Mocks
        weth      = new MockWETH();
        gov       = new MockGov();
        priceFeed = new MockV3Aggregator(2000e8);

        // Core
        cdpEngine = new CDPEngine();
        coin      = new Coin();

        // Adapters
        gemJoin  = new GemJoin(address(cdpEngine), WETH_TYPE, address(weth));
        coinJoin = new CoinJoin(address(cdpEngine), address(coin));

        // Price / fee modules
        spotter = new Spotter(address(cdpEngine));
        jug     = new Jug(address(cdpEngine));
        pot     = new Pot(address(cdpEngine));

        // Auction price calculator
        calc = new LinearDecrease();

        // Auctions
        surplusAuction = new SurplusAuction(address(cdpEngine), address(gov));
        debtAuction    = new DebtAuction(address(cdpEngine), address(gov));

        // DSEngine
        dsEngine = new DSEngine(address(cdpEngine), address(surplusAuction), address(debtAuction));

        // Liquidation
        liqEngine = new LiquidationEngine(address(cdpEngine));
        colAuction = new CollateralAuction(
            address(cdpEngine),
            address(spotter),
            address(liqEngine),
            WETH_TYPE
        );
    }

    // ── Auth ──────────────────────────────────────────────────────

    function _grantAuth() internal {
        // CDPEngine authorizes all modules that write to it
        cdpEngine.grant_auth(address(gemJoin));
        cdpEngine.grant_auth(address(coinJoin));
        cdpEngine.grant_auth(address(spotter));
        cdpEngine.grant_auth(address(jug));
        cdpEngine.grant_auth(address(pot));
        cdpEngine.grant_auth(address(dsEngine));
        cdpEngine.grant_auth(address(liqEngine));
        cdpEngine.grant_auth(address(colAuction));

        // Coin (BEI) authorizes coinJoin to mint
        coin.grant_auth(address(coinJoin));

        // Gov token authorizes debtAuction to mint (covers bad debt)
        gov.grant_auth(address(debtAuction));

        // LiquidationEngine authorizes colAuction to call remove_coin_from_auction
        liqEngine.grant_auth(address(colAuction));
    }

    // ── Initialization helpers ────────────────────────────────────

    function _initCDPEngine() internal {
        cdpEngine.init(WETH_TYPE);                          // rate_acc = RAY
        cdpEngine.set("sys_max_debt", 1_000_000 * RAD);
        cdpEngine.set(WETH_TYPE, "max_debt", 500_000 * RAD);
        // dust = 0 for demo (no minimum CDP size)
    }

    function _initSpotter() internal {
        spotter.set(WETH_TYPE, "price_feed", address(priceFeed));
        spotter.set(WETH_TYPE, "liquidation_ratio", 15 * RAY / 10); // 150 %
        spotter.poke(WETH_TYPE);                            // set initial spot price
    }

    function _initJug() internal {
        jug.init(WETH_TYPE);    // fee = RAY → 0 % annual fee
        jug.set("base_fee", 0);
    }

    function _initCalc() internal {
        calc.set("duration", uint256(3600)); // price hits 0 in 1 hour
    }

    function _initDSEngine() internal {
        dsEngine.set("pop_debt_delay",          uint256(3600));  // 1 hour queue
        dsEngine.set("debt_auction_lot_size",   100 * WAD);      // 100 mGOV per auction
        dsEngine.set("debt_auction_bid_size",   10_000 * RAD);   // 10k BEI per debt auction
        dsEngine.set("surplus_auction_lot_size", 5_000 * RAD);   // 5k BEI per surplus auction
        dsEngine.set("min_surplus",              1_000 * RAD);   // need 1k BEI surplus to start
    }

    function _initLiqEngine() internal {
        liqEngine.set("ds_engine", address(dsEngine));
        liqEngine.set("max_coin",  10_000_000 * RAD);
        liqEngine.set(WETH_TYPE, "auction",  address(colAuction)); // address overload
        liqEngine.set(WETH_TYPE, "penalty",  113 * WAD / 100);    // 1.13 WAD = 13 % penalty
        liqEngine.set(WETH_TYPE, "max_coin", 10_000_000 * RAD);
    }

    function _initColAuction() internal {
        colAuction.set("ds_engine",             address(dsEngine));
        colAuction.set("calc",                  address(calc));
        colAuction.set("boost",                 105 * RAY / 100);  // 1.05 RAY starting price
        colAuction.set("max_duration",          uint256(3600));    // 1 hour max
        colAuction.set("min_delta_price_ratio", RAY / 2);          // reset if price drops 50 %
    }

    // ── Console output ────────────────────────────────────────────

    function _logAddresses() internal view {
        console.log("=== EDAI DEPLOYMENT ===");
        console.log("MockWETH:           ", address(weth));
        console.log("MockGov:            ", address(gov));
        console.log("MockV3Aggregator:   ", address(priceFeed));
        console.log("CDPEngine:          ", address(cdpEngine));
        console.log("Coin (BEI):         ", address(coin));
        console.log("GemJoin:            ", address(gemJoin));
        console.log("CoinJoin:           ", address(coinJoin));
        console.log("Spotter:            ", address(spotter));
        console.log("Jug:                ", address(jug));
        console.log("Pot:                ", address(pot));
        console.log("LinearDecrease:     ", address(calc));
        console.log("SurplusAuction:     ", address(surplusAuction));
        console.log("DebtAuction:        ", address(debtAuction));
        console.log("DSEngine:           ", address(dsEngine));
        console.log("LiquidationEngine:  ", address(liqEngine));
        console.log("CollateralAuction:  ", address(colAuction));
    }
}
