// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

/**
 * @title IUniswapV2Factory (modified)
 * @notice Derived from Uniswap V2 (https://github.com/Uniswap/v2-core),
 *         originally licensed under GPL-3.0.
 * @dev Modified for Solidity ^0.8.30 compatibility. Protocol logic unchanged.
 */
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
