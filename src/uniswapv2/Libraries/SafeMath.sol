// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

/**
 * @title SafeMath (modified)
 * @notice Derived from Uniswap V2 (https://github.com/Uniswap/v2-core),
 *         originally licensed under GPL-3.0.
 * @dev Modified for Solidity ^0.8.30 compatibility. Protocol logic unchanged.
 */
library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }
}
