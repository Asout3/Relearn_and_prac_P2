// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank bank;

    function setUp() public {
        bank = new Bank();

        vm.deal(address(this), 10 ether);
    }

    function test_deposit() public {
        bank.deposit{value: 2 ether}();
        assertEq(bank.getBalance(), 2 ether);
    }
}
