// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

// a library for performing various math operations

/**
 * @title Math (modified)
 * @notice Derived from Uniswap V2 (https://github.com/Uniswap/v2-core),
 *         originally licensed under GPL-3.0.
 * @dev Modified for Solidity ^0.8.30 compatibility. Protocol logic unchanged.
 */
library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
