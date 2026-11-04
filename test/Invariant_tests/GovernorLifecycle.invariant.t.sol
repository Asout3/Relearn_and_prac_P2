// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test, console2} from "forge-std/Test.sol";
import {Governor} from "../../src/Governor.sol";
import {Asout3Token} from "../../src/ERC20.sol";
import {GovernorHandler} from "../Handlers/GovernorHandler.sol";

contract GovernorLifecycleInvariantTest is Test {
    Governor public gov;
    Asout3Token public token;
    GovernorHandler public handler;

    function setUp() public {
        token = new Asout3Token("Meow", "MW", 18, 110_000e18);
        gov = new Governor(address(token));
        handler = new GovernorHandler(gov, token);

        for (uint256 i = 0; i < 8; i++) {
            token.transfer(handler.actors(i), ((5000) - (i * 100)) - 2500);
        }

        targetContract(address(handler));
    }

    function invariant_meow() public pure {
        console2.log("woff");
    }
}
