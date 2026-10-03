// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test, console2} from "forge-std/Test.sol";
import {VulnerableToken} from "../../src/VulnerableToken.sol";
import {SafeToken} from "../../src/SafeToken.sol";

contract OverflowRegressionTest is Test {
    VulnerableToken Vtoken;
    SafeToken Stoken;
    address alice;
    address bob;

    function setUp() public {
        Vtoken = new VulnerableToken();
        Stoken = new SafeToken();

        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_VulnerableToken_mint_overflows() public {
        Vtoken.mint(alice, 10);
        assertEq(Vtoken.balanceOf(alice), 10);

        console2.log("Total supply: ", Vtoken.totalSupply());
        console2.log("alice balance: ", Vtoken.balanceOf(alice));

        Vtoken.mint(bob, type(uint256).max);
        assertEq(Vtoken.balanceOf(bob), type(uint256).max);

        // 10 + type(uint256).max = 9 - it overflows and wrap around at 9.
        assertEq(Vtoken.totalSupply(), 9);
        console2.log("total Supply: ", Vtoken.totalSupply());
        console2.log("balance of bob: ", Vtoken.balanceOf(bob));
    }

    function test_SafeToken_mint_does_not_overflow() public {
        Stoken.mint(alice, 10);
        uint256 aliceBalanceBefore = Stoken.balanceOf(alice);
        uint256 totalSupplyBefore = Stoken.totalSupply();
        assertEq(Stoken.balanceOf(alice), 10);

        vm.expectRevert();
        Stoken.mint(bob, type(uint256).max);
        assertEq(Stoken.balanceOf(alice), aliceBalanceBefore);
        assertEq(Stoken.totalSupply(), totalSupplyBefore);
        assertEq(Stoken.balanceOf(bob), 0);
    }

    function test_VulnerableToken_transfer_underflows() public {
        Vtoken.mint(alice, 10);
        assertEq(Vtoken.balanceOf(alice), 10);

        vm.prank(alice);
        Vtoken.transfer(bob, 25);
        uint256 ans = type(uint256).max - 14; // why 14 - cuz 10 - 25 -> 0 - 15 -> max - 14
        assertEq(Vtoken.balanceOf(alice), ans);
        assertEq(Vtoken.balanceOf(bob), 25);
        assertEq(Vtoken.totalSupply(), 10);
    }

    function test_SafeToken_transfer_does_not_underflow() public {
        Stoken.mint(alice, 10);
        assertEq(Stoken.balanceOf(alice), 10);

        vm.prank(alice);
        vm.expectRevert(SafeToken.InsufficientBalance.selector);
        Stoken.transfer(bob, 25);

        assertEq(Stoken.balanceOf(alice), 10);
        assertEq(Stoken.balanceOf(bob), 0);
        assertEq(Stoken.totalSupply(), 10);
    }
}
