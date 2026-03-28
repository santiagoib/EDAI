// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CDPEngine}         from "../src/stable-coin/CDPEngine.sol";
import {Coin}              from "../src/stable-coin/Coin.sol";
import {MockWETH}          from "../src/mocks/MockWETH.sol";
import {MockGov}           from "../src/mocks/MockGov.sol";
import {MockV3Aggregator}  from "../src/mocks/MockV3Aggregator.sol";

// ─────────────────────────────────────────────────────────────
//  Deploy 1 of 3 — Mocks + Core
//  Deploys: MockWETH, MockGov, MockV3Aggregator, CDPEngine, Coin
//
//  Prerequisites: none
//
//  Run:
//    forge script script/Deploy1.s.sol \
//      --rpc-url $SEPOLIA_RPC_URL \
//      --account deployer \
//      --broadcast \
//      --slow
//
//  After running: copy the logged addresses into .env before Deploy2
// ─────────────────────────────────────────────────────────────
contract Deploy1 is Script {

    function run() external {
        vm.startBroadcast();

        MockWETH         weth      = new MockWETH();
        MockGov          gov       = new MockGov();
        MockV3Aggregator priceFeed = new MockV3Aggregator(2000e8);
        CDPEngine        cdpEngine = new CDPEngine();
        Coin             coin      = new Coin();

        vm.stopBroadcast();

        console.log("=== Deploy 1/3: Mocks + Core ===");
        console.log("MockWETH:          ", address(weth));
        console.log("MockGov:           ", address(gov));
        console.log("MockV3Aggregator:  ", address(priceFeed));
        console.log("CDPEngine:         ", address(cdpEngine));
        console.log("Coin (BEI):        ", address(coin));
        console.log("");
        console.log("-- Add to .env before Deploy2 --");
        console.log("MOCKWETH_ADDRESS=         ", address(weth));
        console.log("MOCKGOV_ADDRESS=          ", address(gov));
        console.log("MOCKV3AGGREGATOR_ADDRESS= ", address(priceFeed));
        console.log("CDPENGINE_ADDRESS=        ", address(cdpEngine));
        console.log("COIN_ADDRESS=             ", address(coin));
    }
}
