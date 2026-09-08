// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// MAKE SURE YOU PUT THE EVEN ADD THE PARAMS OKAY.

import {Test} from "forge-std/Test.sol";
import {Asout3Token} from "../src/ERC20.sol";

contract TestERC20 is Test {
    Asout3Token token;
    address alice;
    address bob;
    address john;

    event Transfer(address indexed sender, address indexed receiver, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        token = new Asout3Token("Asout3Token", "A3T", 18, 100 * 1e18);

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        john = makeAddr("john");

        token.transfer(address(alice), 10 * 1e18);
        token.transfer(address(bob), 10 * 1e18);
    }

    function test_transfer() public {
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(alice), address(bob), 2 * 1e18);

        vm.prank(alice);
        token.transfer(address(bob), 2 * 1e18);

        assertEq(token.balanceOf(address(alice)), 8 * 1e18);
        assertEq(token.balanceOf(address(bob)), 12 * 1e18);
    }

    function test_transfer_with_max_it_have() public {
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(alice), address(bob), 10 * 1e18);

        vm.prank(alice);
        token.transfer(address(bob), 10 * 1e18);

        assertEq(token.balanceOf(address(alice)), 0);
        assertEq(token.balanceOf(address(bob)), 20 * 1e18);
    }

    function test_transfer_zero_amount() public {
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(alice), address(bob), 0);

        vm.prank(alice);
        token.transfer(address(bob), 0);

        assertEq(token.balanceOf(address(alice)), 10 * 1e18);
        assertEq(token.balanceOf(address(bob)), 10 * 1e18);
    }

    function test_transfer_to_zero_address() public {
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(alice), address(0), 1 * 1e18);

        vm.prank(alice);
        token.transfer(address(0), 1 * 1e18);

        assertEq(token.balanceOf(address(alice)), 9 * 1e18);
    }

    function test_transfer_with_zero_address_and_zero_amount() public {
        vm.expectEmit(true, false, false, true);
        emit Transfer(address(alice), address(0), 0);

        vm.prank(alice);
        token.transfer(address(0), 0);

        assertEq(token.balanceOf(address(alice)), 10 * 1e18);
    }

    function test_transfer_reverts_with_Insufficient_Balance() public {
        vm.expectRevert(Asout3Token.InsufficientBalance.selector);
        vm.prank(john);
        token.transfer(address(alice), 2 * 1e18);
    }

    function test_approve_works() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 3 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 3 * 1e18);

        vm.prank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");
    }

    function test_approve_spender_is_zero() public {
        vm.expectEmit();
        emit Approval(address(alice), address(0), 3 * 1e18);

        vm.prank(alice);
        token.approve(address(0), 3 * 1e18);

        vm.prank(address(0));
        bool success = token.checkApproval(address(alice), address(0));
        assertTrue(success, "it fails");
    }

    // This shit fails wow I WILL NOT FIX IT I WILL KEEP IT.
    // inorder it to pass i need to make it to assertFalse(success, "it fails")
    // but i want to keep it
    function test_approve_amount_is_zero() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 0);

        vm.prank(alice);
        token.approve(address(john), 0);

        vm.prank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");
    }

    // this one pass as expected but in real production i think it supposed to fail.
    // its approving more than it have so i am going to do smt with you
    function test_approve_much_more_than_approver_have() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 20 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 20 * 1e18);

        vm.prank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");
    }

    function test_approve_approver_approves_him_self() public {
        vm.expectEmit();
        emit Approval(address(alice), address(alice), 2 * 1e18);

        vm.prank(alice);
        token.approve(address(alice), 2 * 1e18);

        vm.prank(john);
        bool success = token.checkApproval(address(alice), address(alice));
        assertTrue(success, "it fails");
    }

    function test_transferFrom_works() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 3 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 3 * 1e18);

        vm.startPrank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");

        vm.expectEmit();
        emit Transfer(address(alice), address(john), 2 * 1e18);

        token.transferFrom(address(alice), address(john), 2 * 1e18);
        vm.stopPrank();

        assertEq(token.balanceOf(address(john)), 2 * 1e18);
        assertEq(token.balanceOf(address(alice)), 8 * 1e18);
    }

    function test_transferFrom_reverts_on_Insufficent_allowance() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 3 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 3 * 1e18);

        vm.startPrank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");

        vm.expectRevert(Asout3Token.InsufficientAllowance.selector);
        token.transferFrom(address(alice), address(john), 5 * 1e18);
        vm.stopPrank();
    }

    function test_transferFrom_works_on_transfering_all() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 10 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 10 * 1e18);

        vm.startPrank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");

        vm.expectEmit();
        emit Transfer(address(alice), address(john), 10 * 1e18);

        token.transferFrom(address(alice), address(john), 10 * 1e18);
        vm.stopPrank();

        assertEq(token.balanceOf(address(john)), 10 * 1e18);
        assertEq(token.balanceOf(address(alice)), 0 * 1e18);
    }

    function test_transferFrom_reverts_on_insufficent_balance() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 20 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 20 * 1e18);

        vm.startPrank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");

        vm.expectRevert(Asout3Token.InsufficientBalance.selector);
        token.transferFrom(address(alice), address(john), 15 * 1e18);
        vm.stopPrank();
    }

    function test_transferFrom_works_on_similar_allower_and_reciver() public {
        vm.expectEmit();
        emit Approval(address(alice), address(alice), 10 * 1e18);

        vm.prank(alice);
        token.approve(address(alice), 10 * 1e18);

        vm.startPrank(alice);
        bool success = token.checkApproval(address(alice), address(alice));
        assertTrue(success, "it fails");

        vm.expectEmit();
        emit Transfer(address(alice), address(alice), 10 * 1e18);

        token.transferFrom(address(alice), address(alice), 10 * 1e18);
        vm.stopPrank();

        assertEq(token.balanceOf(address(alice)), 10 * 1e18);
    }

    function test_transferFrom_on_zero_amout_to_approve() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 10 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 10 * 1e18);

        vm.startPrank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");

        vm.expectEmit();
        emit Transfer(address(alice), address(john), 0 * 1e18);

        token.transferFrom(address(alice), address(john), 0 * 1e18);
        vm.stopPrank();

        assertEq(token.balanceOf(address(john)), 0 * 1e18);
        assertEq(token.balanceOf(address(alice)), 10 * 1e18);
    }

    function test_transferFrom_reverts_on_one_wei_above_allowance() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 8 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 8 * 1e18);

        vm.startPrank(john);
        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");

        vm.expectRevert(Asout3Token.InsufficientAllowance.selector);
        token.transferFrom(address(alice), address(john), 8 * 1e18 + 1 wei);
        vm.stopPrank();
    }

    function test_transferFrom_works_when_from_and_to_are_zero_address() public {
        vm.expectEmit();
        emit Approval(address(0), address(0), 10 * 1e18);

        vm.prank(address(0));
        token.approve(address(0), 10 * 1e18);

        vm.startPrank(address(0));
        bool success = token.checkApproval(address(0), address(0));
        assertTrue(success, "it fails");

        vm.expectEmit();
        emit Transfer(address(0), address(0), 0 * 1e18);

        token.transferFrom(address(0), address(0), 0 * 1e18);
        vm.stopPrank();
    }

    function test_transferFrom_works_on_same_approver_and_spender() public {
        vm.expectEmit();
        emit Approval(address(alice), address(alice), 10 * 1e18);

        vm.prank(alice);
        token.approve(address(alice), 10 * 1e18);

        vm.startPrank(alice);
        bool success = token.checkApproval(address(alice), address(alice));
        assertTrue(success, "it fails");

        vm.expectEmit();
        emit Transfer(address(alice), address(alice), 0 * 1e18);

        token.transferFrom(address(alice), address(alice), 0 * 1e18);
        vm.stopPrank();

        assertEq(token.balanceOf(address(alice)), 10 * 1e18);
    }

    function test_checkApproval_works() public {
        vm.expectEmit();
        emit Approval(address(alice), address(john), 2 * 1e18);

        vm.prank(alice);
        token.approve(address(john), 2 * 1e18);

        bool success = token.checkApproval(address(alice), address(john));
        assertTrue(success, "it fails");
    }

    function test_checkApproval_returns_false() public view {
        bool success = token.checkApproval(address(alice), address(john));
        assertFalse(success, "it fails");
    }

    function test_checkApproval_works_on_similar_address() public {
        vm.expectEmit();
        emit Approval(address(alice), address(alice), 2 * 1e18);

        vm.prank(alice);
        token.approve(address(alice), 2 * 1e18);

        bool success = token.checkApproval(address(alice), address(alice));
        assertTrue(success, "it fails");
    }

    function test_totalSupplies_works() public view {
        assertEq(token.totalSupplies(), 100 * 1e18);
    }

    function test_balanceOf_works() public view {
        assertEq(token.balanceOf(address(alice)), 10 * 1e18);
    }

    function test_balanceOf_with_zero_address() public view {
        assertEq(token.balanceOf(address(0)), 0);
    }

    function test_balanceOf_with_random_address() public view {
        assertEq(token.balanceOf(address(1)), 0);
    }
}
