// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice The natSpec(doc) is written by an AI(deepseek v4.1 flash).

import {Test} from "forge-std/Test.sol";
import {AMM, LP} from "../../src/AMM.sol";

/**
 * @title AMMInvariantTest
 * @notice Handler-free invariant suite for the `AMM` constant-product pool.
 * @dev    Intentionally written *without* a handler to demonstrate why one is
 *         needed — the majority of the calls here fail (roughly 90%+) and
 *         that is expected. Only `swapAforB` and `swapBforA` are targeted
 *         because the fuzzer's random caller has no `deal()` / `approve()`
 *         setup, so `addLiquidity` / `removeLiquidity` would revert on
 *         `transferFrom`. The single invariant below verifies that the
 *         constant-product value `k = reserveA * reserveB` never decreases
 *         across swaps.
 */
contract AMMInvariantTest is Test {
    AMM public amm;
    LP public tokenA;
    LP public tokenB;

    uint256 initialK;
    uint256 constant AMOUNT_OF_TOKEN = 10_000 ether;
    uint256 constant AMOUNT_OF_TOKEN_TO_ADD_TO_LIQUIDITY = 1000 ether;

    /**
     * @notice Deploys the two LP tokens and the AMM, seeds initial liquidity,
     *         restricts targeting to the swap functions, and freezes `initialK`.
     * @dev    Targeting only `swapAforB` / `swapBforA` avoids the false
     *         negatives that would come from liquidity functions legitimately
     *         moving `k`, while also dodging the guaranteed `transferFrom`
     *         reverts from the fuzzer's unapproved caller.
     */
    function setUp() public {
        tokenA = new LP("Token_A", "TA", 18, 0);
        tokenB = new LP("Token_B", "TB", 18, 0);
        amm = new AMM(address(tokenA), address(tokenB));

        targetContract(address(amm));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = AMM.swapAforB.selector;
        selectors[1] = AMM.swapBforA.selector;
        targetSelector(FuzzSelector({addr: address(amm), selectors: selectors}));

        tokenA.mint(AMOUNT_OF_TOKEN, address(this));
        tokenB.mint(AMOUNT_OF_TOKEN, address(this));
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        amm.addLiquidity(AMOUNT_OF_TOKEN_TO_ADD_TO_LIQUIDITY, AMOUNT_OF_TOKEN_TO_ADD_TO_LIQUIDITY);

        initialK = amm.reserveA() * amm.reserveB();
    }

    /**
     * @notice Invariant: `reserveA * reserveB` must never drop below `initialK`.
     * @dev    The constant-product invariant is `k = reserveA * reserveB`.
     *         Swaps can only increase `k` (due to integer rounding dust) or
     *         leave it unchanged, so `assertGe` is the correct comparison.
     *         Liquidity functions are excluded from targeting because they
     *         legitimately move `k`.
     */
    function invariant_kNeverDecreases() public view {
        assertGe(amm.reserveA() * amm.reserveB(), initialK);
    }
}
