// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice The natSpec(doc) is written by an AI(deepseek v4.1 flash).

import {Test} from "forge-std/Test.sol";
import {AMM, LP} from "../../src/AMM.sol";
import {AMMHandler} from "../Handlers/AMMHandler.sol";

/// @title AMMInvariantTestWithHandler
/// @notice Invariant test suite for the AMM using a fuzz handler.
/// @dev    Verifies that the constant-product invariant `reserveA * reserveB`
///         never decreases across handler-driven swaps.
contract AMMInvariantTestV2 is Test {
    AMM public amm;
    AMMHandler public handler;
    LP public tokenA;
    LP public tokenB;

    uint256 initialK;
    uint8 private constant _TOKEN_DECIMALS = 18;
    uint256 private constant _INITIAL_LP_SUPPLY = 0;

    /// @notice Deploys tokens, AMM, and handler; seeds liquidity; records initial K.
    function setUp() public {
        tokenA = new LP("Token_A", "TA", _TOKEN_DECIMALS, _INITIAL_LP_SUPPLY);
        tokenB = new LP("Token_B", "TB", _TOKEN_DECIMALS, _INITIAL_LP_SUPPLY);
        amm = new AMM(address(tokenA), address(tokenB));
        handler = new AMMHandler(amm, tokenA, tokenB);

        targetContract(address(handler));

        initialK = amm.reserveA() * amm.reserveB();
    }

    /// @notice The product of reserves must never fall below its initial value.
    function invariant_kNeverDecreasesHan() public view {
        assertGe(amm.reserveA() * amm.reserveB(), initialK);
    }
}
