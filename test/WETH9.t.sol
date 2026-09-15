// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {WETH9} from "../src/WETH9.sol";

contract TestWETH9 is Test {
    WETH9 weth;
    address alice;
    address bob;
    address john;

    function setUp() public {
        weth = new WETH9();

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        john = makeAddr("john");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 5 ether);
    }

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    function test_WETH9_deposit_works() public {
        uint256 aliceAmountOfDeposit = 10 ether;

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, aliceAmountOfDeposit);

        vm.prank(alice);
        weth.deposit{value: aliceAmountOfDeposit}();

        assertEq(weth.balanceOf(alice), aliceAmountOfDeposit);
    }

    function test_WETH9_deposit_works_on_recive_call() public {
        uint256 aliceAmountOfDeposit = 10 ether;

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, aliceAmountOfDeposit);

        vm.prank(alice);
        (bool ok,) = address(weth).call{value: aliceAmountOfDeposit}("");
        assertTrue(ok, "transfer failed");

        assertEq(weth.balanceOf(alice), aliceAmountOfDeposit);
    }

    function test_WETH9_deposit_works_on_zero_amount_sent() public {
        uint256 bobAmoutOfDeposit = 0 ether;

        vm.expectEmit(true, false, false, true);
        emit Deposit(bob, bobAmoutOfDeposit);

        vm.prank(bob);
        weth.deposit{value: bobAmoutOfDeposit}();

        assertEq(weth.balanceOf(bob), bobAmoutOfDeposit);
    }

    function test_WETH9_deposit_works_max_uint256() public {
        uint256 amountToTransfer = type(uint256).max;
        address yon = makeAddr("yon");
        vm.deal(yon, amountToTransfer);

        vm.expectEmit(true, false, false, true);
        emit Deposit(yon, amountToTransfer);

        vm.prank(yon);
        weth.deposit{value: amountToTransfer}();

        assertEq(weth.balanceOf(yon), amountToTransfer);
    }

    function test_WETH9_withdraw_works() public {
        uint256 aliceAmountOfDeposit = 10 ether;
        uint256 aliceAmoutToWithdraw = 8 * 1e18;

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, aliceAmountOfDeposit);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountOfDeposit}();

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(alice, aliceAmoutToWithdraw);

        weth.withdraw(aliceAmoutToWithdraw);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), aliceAmountOfDeposit - aliceAmoutToWithdraw);
    }

    function test_WETH9_withdraw_reverts_on_over_withdrawing() public {
        uint256 aliceAmountOfDeposit = 10 ether;
        uint256 aliceAmoutToWithdraw = 15 * 1e18;

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, aliceAmountOfDeposit);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountOfDeposit}();
        uint256 balanceAfterDeposit = weth.balanceOf(alice);

        vm.expectRevert();
        weth.withdraw(aliceAmoutToWithdraw);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), balanceAfterDeposit);
    }

    function test_WETH9_withdraw_works_on_zero_amount_to_withdraw() public {
        uint256 aliceAmountOfDeposit = 10 ether;
        uint256 aliceAmoutToWithdraw = 0;

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, aliceAmountOfDeposit);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountOfDeposit}();

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(alice, aliceAmoutToWithdraw);

        weth.withdraw(aliceAmoutToWithdraw);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), aliceAmountOfDeposit - aliceAmoutToWithdraw);
    }

    function test_WETH9_withdraw_work_on_zero_for_non_user() public {
        uint256 amountToWithdraw = 0;

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(john, amountToWithdraw);

        vm.prank(john);
        weth.withdraw(amountToWithdraw);
    }

    function test_WETH9_withdraw_works_withdrawing_uint256_max() public {
        uint256 amountToTransfer = 100 ether;
        uint256 amountToWithdraw = type(uint256).max;
        address yon = makeAddr("yon");

        vm.deal(yon, amountToTransfer);

        vm.expectEmit(true, false, false, true);
        emit Deposit(yon, amountToTransfer);

        vm.prank(yon);
        weth.deposit{value: amountToTransfer}();

        uint256 yonBalanceBefore = weth.balanceOf(yon);

        vm.expectRevert();
        vm.prank(yon);
        weth.withdraw(amountToWithdraw);

        assertEq(weth.balanceOf(yon), yonBalanceBefore);
    }

    function test_WETH9_withdraw_works_on_full_amount_withdraw() public {
        uint256 aliceAmountOfDeposit = 10 ether;
        uint256 aliceAmoutToWithdraw = 10 * 1e18;

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, aliceAmountOfDeposit);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountOfDeposit}();

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(alice, aliceAmoutToWithdraw);

        weth.withdraw(aliceAmoutToWithdraw);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), aliceAmountOfDeposit - aliceAmoutToWithdraw);
    }

    function test_WETH9_totalSupply_works() public {
        uint256 aliceDeposit = 5 ether;
        uint256 bobDeposit = 3 ether;
        uint256 bobAdditionalDeposit = 123456789 wei;

        vm.prank(alice);
        weth.deposit{value: aliceDeposit}();
        vm.prank(bob);
        weth.deposit{value: bobDeposit + bobAdditionalDeposit}();

        assertEq(weth.totalSupply(), aliceDeposit + bobDeposit + bobAdditionalDeposit);
        console2.log("Total supply: ", weth.totalSupply());
    }

    function test_WETH9_approval_works() public {
        uint256 amountToApprove = 3 * 1e18;

        vm.expectEmit(true, true, false, true);
        emit Approval(alice, john, amountToApprove);

        vm.prank(alice);
        weth.approve(john, amountToApprove);

        assertEq(weth.allowance(alice, john), amountToApprove);
    }

    function test_WETH9_approval_works_on_zero_address() public {
        uint256 amountToApprove = 3 * 1e18;

        vm.startPrank(alice);

        vm.expectEmit(true, true, false, true);
        emit Approval(alice, address(0), amountToApprove);

        weth.approve(address(0), amountToApprove);
        vm.stopPrank();

        assertEq(weth.allowance(alice, address(0)), amountToApprove);
    }

    function test_WETH9_approval_works_on_zero_address_and_zero_amount() public {
        uint256 amountToApprove = 0;

        vm.startPrank(alice);

        vm.expectEmit(true, true, false, true);
        emit Approval(alice, address(0), amountToApprove);

        weth.approve(address(0), amountToApprove);
        vm.stopPrank();

        assertEq(weth.allowance(alice, address(0)), amountToApprove);
    }

    function test_WETH9_approval_works_on_zero_address_and_uint256_max() public {
        uint256 amountToApprove = type(uint256).max;

        vm.startPrank(alice);

        vm.expectEmit(true, true, false, true);
        emit Approval(alice, address(0), amountToApprove);

        weth.approve(address(0), amountToApprove);
        vm.stopPrank();

        assertEq(weth.allowance(alice, address(0)), amountToApprove);
    }

    function test_WETH9_approval_approving_more_than_you_own() public {
        uint256 aliceAmountOfDeposit = 3 ether;
        uint256 amountToApprove = 5 * 1e18;

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, aliceAmountOfDeposit);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountOfDeposit}();

        vm.expectEmit(true, true, false, true);
        emit Approval(alice, john, amountToApprove);

        weth.approve(john, amountToApprove);
        vm.stopPrank();

        assertEq(weth.allowance(alice, john), amountToApprove);
    }

    function test_WETH9_approval_works_on_uint256_max() public {
        uint256 aliceAmountOfDeposit = 3 ether;
        uint256 amountToApprove = type(uint256).max;

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, aliceAmountOfDeposit);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountOfDeposit}();

        vm.expectEmit(true, true, false, true);
        emit Approval(alice, john, amountToApprove);

        weth.approve(john, amountToApprove);
        vm.stopPrank();

        assertEq(weth.allowance(alice, john), amountToApprove);
    }

    function test_WETH9_transfer_works() public {
        uint256 aliceAmountToDeposit = 10 ether;
        uint256 aliceAmountToTransfer = 3 ether;
        uint256 johnAmountBefore = weth.balanceOf(john);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountToDeposit}();
        uint256 aliceBalanceAfterDeposit = weth.balanceOf(alice);

        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, john, aliceAmountToTransfer);

        weth.transfer(john, aliceAmountToTransfer);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), aliceBalanceAfterDeposit - aliceAmountToTransfer);
        assertEq(weth.balanceOf(john), johnAmountBefore + aliceAmountToTransfer);
    }

    function test_WETH9_transfer_reverts_on_transfering_more_than_you_have() public {
        uint256 aliceAmountToDeposit = 10 ether;
        uint256 aliceAmountToTransfer = 15 ether;
        uint256 johnAmountBefore = weth.balanceOf(john);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountToDeposit}();
        uint256 aliceBalanceAfterDeposit = weth.balanceOf(alice);

        vm.expectRevert();
        weth.transfer(john, aliceAmountToTransfer);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), aliceBalanceAfterDeposit);
        assertEq(weth.balanceOf(john), johnAmountBefore);
    }

    function test_WETH9_transfer_reverts_on_transfering_uint256_max() public {
        uint256 aliceAmountToDeposit = 10 ether;
        uint256 aliceAmountToTransfer = type(uint256).max;
        uint256 johnAmountBefore = weth.balanceOf(john);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountToDeposit}();
        uint256 aliceBalanceAfterDeposit = weth.balanceOf(alice);

        vm.expectRevert();
        weth.transfer(john, aliceAmountToTransfer);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), aliceBalanceAfterDeposit);
        assertEq(weth.balanceOf(john), johnAmountBefore);
    }

    function test_WETH9_transfer_to_zero_address() public {
        uint256 aliceAmountToDeposit = 10 ether;
        uint256 aliceAmountToTransfer = 5 ether;

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountToDeposit}();
        uint256 aliceBalanceAfterDeposit = weth.balanceOf(alice);

        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, address(0), aliceAmountToTransfer);

        weth.transfer(address(0), aliceAmountToTransfer);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), aliceBalanceAfterDeposit - aliceAmountToTransfer);
    }

    function test_WETH9_transfer_zero_amount() public {
        uint256 aliceAmountToDeposit = 10 ether;
        uint256 aliceAmountToTransfer = 0;
        uint256 johnAmountBefore = weth.balanceOf(john);

        vm.startPrank(alice);
        weth.deposit{value: aliceAmountToDeposit}();
        uint256 aliceBalanceAfterDeposit = weth.balanceOf(alice);

        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, john, aliceAmountToTransfer);

        weth.transfer(john, aliceAmountToTransfer);
        vm.stopPrank();

        assertEq(weth.balanceOf(alice), aliceBalanceAfterDeposit - aliceAmountToTransfer);
        assertEq(weth.balanceOf(john), johnAmountBefore + aliceAmountToTransfer);
    }


}

