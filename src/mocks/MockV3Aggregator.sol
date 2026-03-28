// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

/// @title MockV3Aggregator
/// @notice Chainlink-style price feed mock. Stores price in 8-decimal format
///         and exposes it as WAD (18-decimal) via IPriceFeed.peek().
contract MockV3Aggregator is IPriceFeed {
    /// @notice Raw price in Chainlink 8-decimal format (e.g. 2000e8 = $2000).
    int256 public answer;

    constructor(int256 _initialAnswer) {
        answer = _initialAnswer;
    }

    // --- IPriceFeed ---

    /// @notice Returns the price scaled to WAD (18 decimals) and a validity flag.
    /// @return val  Price in WAD (answer * 1e10).
    /// @return ok   True when the stored answer is positive.
    function peek() external view override returns (uint256 val, bool ok) {
        val = uint256(answer * 1e10);
        ok  = answer > 0;
    }

    // --- Admin (open for testnet demo) ---

    /// @notice Update the stored price. Anyone can call on testnet.
    function updateAnswer(int256 _answer) external {
        answer = _answer;
    }

    /// @notice Returns the raw 8-decimal answer (for UI / info purposes).
    function latestAnswer() external view returns (int256) {
        return answer;
    }
}
