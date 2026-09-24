// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

/**
 * @title IUniswapV2Callee (modified)
 * @notice Derived from Uniswap V2 (https://github.com/Uniswap/v2-core),
 *         originally licensed under GPL-3.0.
 * @dev Modified for Solidity ^0.8.30 compatibility. Protocol logic unchanged.
 */
interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
