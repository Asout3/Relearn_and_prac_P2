// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112

/**
 * @title UQ112x112 (modified)
 * @notice Derived from Uniswap V2 (https://github.com/Uniswap/v2-core),
 *         originally licensed under GPL-3.0.
 * @dev Modified for Solidity ^0.8.30 compatibility. Protocol logic unchanged.
 */
library UQ112x112 {
    uint224 constant Q112 = 2 ** 112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
