// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.24;

import {IGem} from "../interfaces/IGem.sol";

/// @title MockWETH
/// @notice Mintable ERC20 mock for WETH collateral. Open mint for testnet demo.
contract MockWETH is IGem {
    // --- ERC20 metadata ---
    string public constant name     = "Mock WETH";
    string public constant symbol   = "mWETH";
    uint8  public constant decimals = 18;

    // --- ERC20 state ---
    uint256                      public totalSupply;
    mapping(address => uint256)  public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- Events ---
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Approval(address indexed owner, address indexed spender, uint256 wad);

    // --- ERC20 ---

    function approve(address spender, uint256 wad) external override {
        allowance[msg.sender][spender] = wad;
        emit Approval(msg.sender, spender, wad);
    }

    function transfer(address dst, uint256 wad) external override returns (bool) {
        return _transfer(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) external override returns (bool) {
        if (allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad, "MockWETH/insufficient-allowance");
            allowance[src][msg.sender] -= wad;
        }
        return _transfer(src, dst, wad);
    }

    function _transfer(address src, address dst, uint256 wad) internal returns (bool) {
        require(balanceOf[src] >= wad, "MockWETH/insufficient-balance");
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        emit Transfer(src, dst, wad);
        return true;
    }

    // --- Mint / Burn ---

    /// @notice Open to anyone for testnet demo — mints `wad` tokens to `dst`.
    function mint(address dst, uint256 wad) external override {
        balanceOf[dst] += wad;
        totalSupply    += wad;
        emit Transfer(address(0), dst, wad);
    }

    /// @notice Burns `wad` from `src`. Caller must be `src` or have sufficient allowance.
    function burn(address src, uint256 wad) external override {
        if (src != msg.sender) {
            if (allowance[src][msg.sender] != type(uint256).max) {
                require(allowance[src][msg.sender] >= wad, "MockWETH/insufficient-allowance");
                allowance[src][msg.sender] -= wad;
            }
        }
        require(balanceOf[src] >= wad, "MockWETH/insufficient-balance");
        balanceOf[src] -= wad;
        totalSupply    -= wad;
        emit Transfer(src, address(0), wad);
    }

    // --- Push / Pull / Move helpers ---

    function push(address dst, uint256 wad) external override {
        _transfer(msg.sender, dst, wad);
    }

    function pull(address src, uint256 wad) external override {
        if (allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad, "MockWETH/insufficient-allowance");
            allowance[src][msg.sender] -= wad;
        }
        _transfer(src, msg.sender, wad);
    }

    function move(address src, address dst, uint256 wad) external override {
        if (allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad, "MockWETH/insufficient-allowance");
            allowance[src][msg.sender] -= wad;
        }
        _transfer(src, dst, wad);
    }
}
