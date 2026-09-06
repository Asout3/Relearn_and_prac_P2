// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract PrankPractice is Test {
    Bank bank;
    address alice;
    address Bob;

    function setUp() public {
        bank = new Bank();

        alice = makeAddr("alice");
        Bob = makeAddr("bob");

        vm.deal(alice, 10 ether);
        vm.deal(Bob, 10 ether);
    }

    function test_getTotalBalance_reverts_for_non_owner() public {
        vm.expectRevert(Bank.NotOwner.selector);
        vm.prank(alice);
        bank.getTotalBalance();
    }

    function test_getTotalBalance_pass_for_owner() public {
        bank.getTotalBalance();
        assertEq(bank.getTotalBalance(), 0);
    }

    function test_multiActor_deposit_and_withdraw() public {
        vm.prank(alice);
        bank.deposit{value: 5 ether}();

        vm.prank(Bob);
        bank.deposit{value: 3 ether}();

        vm.prank(alice);
        bank.withdraw(2 ether);

        uint256 aliceCurrentBalance = bank.balances(alice);
        assertEq(aliceCurrentBalance, 3 ether);

        uint256 bobCurrentBalance = bank.balances(Bob);
        assertEq(bobCurrentBalance, 3 ether);

        assertEq(bank.getTotalBalance(), 6 ether);
    }

    function test_startPrank() public {
        vm.startPrank(Bob);
        bank.deposit{value: 1 ether}();
        bank.deposit{value: 2 ether}();
        vm.stopPrank();

        uint256 bobCurrentBalance = bank.balances(Bob);
        assertEq(bobCurrentBalance, 3 ether);

        assertEq(bank.getTotalBalance(), 3 ether);
    }
}
