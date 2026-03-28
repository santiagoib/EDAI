// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CDPEngine}         from "../src/stable-coin/CDPEngine.sol";
import {Coin}              from "../src/stable-coin/Coin.sol";
import {GemJoin}           from "../src/stable-coin/GemJoin.sol";
import {CoinJoin}          from "../src/stable-coin/CoinJoin.sol";
import {Spotter}           from "../src/stable-coin/Spotter.sol";
import {Jug}               from "../src/stable-coin/Jug.sol";
import {Pot}               from "../src/stable-coin/Pot.sol";
import {MockWETH}          from "../src/mocks/MockWETH.sol";
import {MockV3Aggregator}  from "../src/mocks/MockV3Aggregator.sol";

// ─────────────────────────────────────────────────────────────
//  Deploy 2 of 3 — Joins + Stability modules
//  Deploys: GemJoin, CoinJoin, Spotter, Jug, Pot
//  Also:    auth grants + CDPEngine/Spotter/Jug initialization
//
//  Prerequisites (.env must contain):
//    CDPENGINE_ADDRESS         = <from Deploy1>
//    COIN_ADDRESS              = <from Deploy1>
//    MOCKWETH_ADDRESS          = <from Deploy1>
//    MOCKV3AGGREGATOR_ADDRESS  = <from Deploy1>
//
//  Run:
//    forge script script/Deploy2.s.sol \
//      --rpc-url $SEPOLIA_RPC_URL \
//      --account deployer \
//      --broadcast \
//      --slow
//
//  After running: copy the logged addresses into .env before Deploy3
// ─────────────────────────────────────────────────────────────

uint256 constant WAD2 = 1e18;
uint256 constant RAY2 = 1e27;
uint256 constant RAD2 = 1e45;

bytes32 constant WETH_TYPE2 = bytes32(bytes("WETH"));

contract Deploy2 is Script {

    function run() external {
        // ── Load Deploy1 addresses from env ───────────────────────
        CDPEngine        cdpEngine = CDPEngine(vm.envAddress("CDPENGINE_ADDRESS"));
        Coin             coin      = Coin(vm.envAddress("COIN_ADDRESS"));
        MockWETH         weth      = MockWETH(vm.envAddress("MOCKWETH_ADDRESS"));
        MockV3Aggregator priceFeed = MockV3Aggregator(vm.envAddress("MOCKV3AGGREGATOR_ADDRESS"));

        vm.startBroadcast();

        // ── Deploy ────────────────────────────────────────────────
        GemJoin  gemJoin  = new GemJoin(address(cdpEngine), WETH_TYPE2, address(weth));
        CoinJoin coinJoin = new CoinJoin(address(cdpEngine), address(coin));
        Spotter  spotter  = new Spotter(address(cdpEngine));
        Jug      jug      = new Jug(address(cdpEngine));
        Pot      pot      = new Pot(address(cdpEngine));

        // ── Auth grants ───────────────────────────────────────────
        cdpEngine.grant_auth(address(gemJoin));
        cdpEngine.grant_auth(address(coinJoin));
        cdpEngine.grant_auth(address(spotter));
        cdpEngine.grant_auth(address(jug));
        cdpEngine.grant_auth(address(pot));

        // Coin (BEI) allows coinJoin to mint
        coin.grant_auth(address(coinJoin));

        // ── CDPEngine init ────────────────────────────────────────
        cdpEngine.init(WETH_TYPE2);                               // rate_acc = RAY
        cdpEngine.set("sys_max_debt",      1_000_000 * RAD2);
        cdpEngine.set(WETH_TYPE2, "max_debt", 500_000 * RAD2);
        // dust = 0 (no minimum CDP size for demo)

        // ── Spotter (price feed) ──────────────────────────────────
        spotter.set(WETH_TYPE2, "price_feed",         address(priceFeed));
        spotter.set(WETH_TYPE2, "liquidation_ratio",  15 * RAY2 / 10); // 150%
        spotter.poke(WETH_TYPE2);                                 // set initial spot price

        // ── Jug (stability fee) ───────────────────────────────────
        jug.init(WETH_TYPE2);      // duty = RAY → 0% annual fee
        jug.set("base_fee", 0);

        vm.stopBroadcast();

        console.log("=== Deploy 2/3: Joins + Stability modules ===");
        console.log("GemJoin:  ", address(gemJoin));
        console.log("CoinJoin: ", address(coinJoin));
        console.log("Spotter:  ", address(spotter));
        console.log("Jug:      ", address(jug));
        console.log("Pot:      ", address(pot));
        console.log("");
        console.log("-- Add to .env before Deploy3 --");
        console.log("GEMJOIN_ADDRESS=  ", address(gemJoin));
        console.log("COINJOIN_ADDRESS= ", address(coinJoin));
        console.log("SPOTTER_ADDRESS=  ", address(spotter));
        console.log("JUG_ADDRESS=      ", address(jug));
        console.log("POT_ADDRESS=      ", address(pot));
    }
}
