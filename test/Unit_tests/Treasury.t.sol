// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract TestTreasury is Test {
    Treasury treasury;
    address ADMIN = makeAddr("ADMIN");
    address MANAGER = makeAddr("MANAGER");
    address VIEWER = makeAddr("VIEWER");
    address random = makeAddr("random");

    event Deposited(address indexed sender, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        treasury = new Treasury(ADMIN);

        vm.startPrank(ADMIN);
        treasury.grantRole(treasury.MANAGER_ROLE(), MANAGER);
        treasury.grantRole(treasury.VIEWER_ROLE(), VIEWER);
        vm.stopPrank();

        vm.deal(ADMIN, 1000 ether);
        vm.deal(MANAGER, 500 ether);
        vm.deal(VIEWER, 250 ether);

        vm.prank(ADMIN);
        treasury.deposit{value: 100 ether}();
    }

    function test_deposit() public {
        vm.expectEmit(true, false, false, true);
        emit Deposited(MANAGER, 200 ether);

        vm.prank(MANAGER);
        treasury.deposit{value: 200 ether}();

        assertEq(address(treasury).balance, 300 ether);
    }

    function test_withdraw_with_admin() public {
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(ADMIN, 10 ether);

        vm.prank(ADMIN);
        treasury.withdraw(10 ether);

        assertEq(address(treasury).balance, 90 ether);
    }

    function test_withdraw_manager() public {
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(MANAGER, 30 ether);

        vm.prank(MANAGER);
        treasury.managerWithdraw(30 ether);

        assertEq(address(treasury).balance, 70 ether);
    }

    function test_view_balance() public {
        vm.prank(VIEWER);
        uint256 amount = treasury.viewBalance();

        assertEq(amount, 100 ether);
    }

    function test_withdraw_reverts_for_the_manager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, MANAGER, treasury.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(MANAGER);
        treasury.withdraw(10 ether);

        assertEq(address(treasury).balance, 100 ether);
    }

    function test_withdraw_reverts_for_viewer() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, VIEWER, treasury.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(VIEWER);
        treasury.withdraw(10 ether);

        assertEq(address(treasury).balance, 100 ether);
    }

    function test_managerWithdraw_reverts_for_admin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, ADMIN, treasury.MANAGER_ROLE()
            )
        );

        vm.prank(ADMIN);
        treasury.managerWithdraw(25 ether);

        assertEq(address(treasury).balance, 100 ether);
    }

    function test_managerWithdraw_reverts_for_viewer() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, VIEWER, treasury.MANAGER_ROLE()
            )
        );

        vm.prank(VIEWER);
        treasury.managerWithdraw(25 ether);

        assertEq(address(treasury).balance, 100 ether);
    }

    function test_viewBalance_reverts_for_admin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, ADMIN, treasury.VIEWER_ROLE()
            )
        );

        vm.prank(ADMIN);
        treasury.viewBalance();
    }

    function test_viewBalance_reverts_for_manager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, MANAGER, treasury.VIEWER_ROLE()
            )
        );

        vm.prank(MANAGER);
        treasury.viewBalance();
    }

    function test_withdraw_reverts_for_random_user() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, random, treasury.DEFAULT_ADMIN_ROLE()
            )
        );

        vm.prank(random);
        treasury.withdraw(10 ether);

        assertEq(address(treasury).balance, 100 ether);
    }

    function test_managerWithdraw_reverts_for_random_user() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, random, treasury.MANAGER_ROLE()
            )
        );

        vm.prank(random);
        treasury.managerWithdraw(25 ether);

        assertEq(address(treasury).balance, 100 ether);
    }

    function test_viewBalance_reverts_for_random_user() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, random, treasury.VIEWER_ROLE()
            )
        );

        vm.prank(random);
        treasury.viewBalance();
    }
}
