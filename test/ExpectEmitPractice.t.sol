// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract ExpectEmitPractice is Test {
    Bank bank;
    address alice;

    event Deposited(address indexed user, uint256 amount);
    event Withdrew(address indexed user, uint256 amount);

    function setUp() public {
        bank = new Bank();

        alice = makeAddr("alice");
        vm.deal(alice, 10 ether);
    }

    function test_deposit_emits_event() public {
        vm.expectEmit(true, false, false, true);
        emit Deposited(address(alice), 2 ether);

        vm.prank(alice);
        bank.deposit{value: 2 ether}();
    }

    function test_withdraw_emits_event() public {
        vm.prank(alice);
        bank.deposit{value: 5 ether}();

        vm.expectEmit(true, false, false, true);
        emit Withdrew(address(alice), 3 ether);

        vm.prank(alice);
        bank.withdraw(3 ether);
    }
}
