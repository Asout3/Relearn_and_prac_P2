// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

/// @dev This is a dummy helper contract to test non owner revert on getTotalBalance
contract DummyNonOwner {
    Bank public bank;

    constructor(Bank _bank) {
        bank = _bank;
    }

    function tryGetTotalBalance() external view returns (uint256) {
        return bank.getTotalBalance();
    }
}

/// @dev This is a dummy helper contract to test the TransferFailed() error.
contract DummyRejectsEth {
    Bank public bank;

    constructor(Bank _bank) {
        bank = _bank;
    }

    function tryToDeposit(uint256 _amount) external {
        bank.deposit{value: _amount}();
    }

    function tryToWithdraw(uint256 _amount) external {
        bank.withdraw(_amount);
    }
}

contract BankTest is Test {
    Bank bank;

    /// @dev This receive function is to stop the test_withdraw() from failing.
    /// @dev The reason it fails is that the test contract(msg.sender) doesn't receive any ethers.
    receive() external payable {}

    function setUp() public {
        bank = new Bank();

        vm.deal(address(this), 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
    //                          Deposit                           //
    //////////////////////////////////////////////////////////////*/
    function test_deposit() public {
        bank.deposit{value: 2 ether}();
        assertEq(bank.getBalance(), 2 ether);
    }

    /*//////////////////////////////////////////////////////////////
    //                          Withdraw                          //
    //////////////////////////////////////////////////////////////*/
    function test_withdraw() public {
        bank.deposit{value: 9 ether}();

        bank.withdraw(3 ether);
        assertEq(bank.getBalance(), 6 ether);
    }

    function test_withdraw_reverts() public {
        bank.deposit{value: 5 ether}();

        vm.expectRevert(Bank.NotEnoughMoney.selector);
        bank.withdraw(6 ether);
    }

    function test_withdraw_revert_with_Transfer_failed() public {
        DummyRejectsEth dummy = new DummyRejectsEth(bank);

        vm.deal(address(dummy), 5 ether);
        dummy.tryToDeposit(2 ether);

        vm.expectRevert(Bank.TransferFailed.selector);
        dummy.tryToWithdraw(2 ether);
    }

    function test_withdraw_exactly_user_balance() public {
        bank.deposit{value: 5 ether}();

        bank.withdraw(5 ether);
        assertEq(bank.getBalance(), 0 ether);
    }

    function test_withdraw_zero() public {
        bank.deposit{value: 5 ether}();

        bank.withdraw(0 ether);
        assertEq(bank.getBalance(), 5 ether);
    }

    function test_withdraw_without_deposit() public {
        bank.withdraw(0 ether);
        assertEq(bank.getBalance(), 0 ether);
    }

    function test_withdraw_one_wei_above() public {
        bank.deposit{value: 5 ether}();

        vm.expectRevert(Bank.NotEnoughMoney.selector);
        bank.withdraw(5 ether + 1 wei);
    }

    /*//////////////////////////////////////////////////////////////
    //                          getBalance                        //
    //////////////////////////////////////////////////////////////*/
    function test_getBalance() public {
        bank.deposit{value: 5 ether}();

        assertEq(bank.getBalance(), 5 ether);
    }

    // --- getTotalBalance ---
    function test_getTotalBalance_pass_for_owner() public {
        bank.deposit{value: 5 ether}();

        assertEq(bank.getTotalBalance(), 5 ether);
    }

    function test_getTotalBalance_reverts_for_non_owner() public {
        DummyNonOwner dummy = new DummyNonOwner(bank);

        vm.expectRevert(Bank.NotOwner.selector);

        dummy.tryGetTotalBalance();
    }

    /*//////////////////////////////////////////////////////////////
    //                          receive                          //
    //////////////////////////////////////////////////////////////*/
    function test_receive() public {
        (bool success,) = address(bank).call{value: 3 ether}("");
        assertTrue(success);

        assertEq(bank.getBalance(), 3 ether);
        assertEq(bank.getTotalBalance(), 3 ether);
    }

    /*//////////////////////////////////////////////////////////////
    //                          fallback                          //
    //////////////////////////////////////////////////////////////*/
    function test_fallback() public {
        (bool success,) = address(bank).call{value: 2 ether}(abi.encodeWithSignature("nonExistingFunction()"));
        assertTrue(success);
    }
}

