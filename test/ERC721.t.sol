// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol"; 
import {MyNft} from "../src/ERC721.sol";

contract testERC721 is Test {
    MyNft mynft;
    address bel;
    address alice;
    address bob;
    address john;
    address nig;

    event OwnershipTrasfered(address indexed _from, address indexed _to, uint256 indexed _id);


    function setUp() public {
        mynft = new MyNft("shit", "sit");

        bel = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        john = makeAddr("john");

        for (uint256 i = 0; i <= 4; i++) {
            mynft.mint(address(bel)); //   1, 4, 7, 10, 13
            mynft.mint(address(alice)); // 2, 5, 8, 11, 14
            mynft.mint(address(bob)); //   3, 6, 9, 12, 15
        }
    }

    function test_mint_works() public {
    	 vm.expectEmit(true, false, false, true);
    	 emit OwnershipTrasfered(address(0), address(alice), 17);

    	 mynft.mint(address(alice));

    	 assertEq(mynft.balanceOf(address(alice)), 6);
    	 assertEq(mynft.id(), 17);
    }

    function test_mint_revert_with_zero_address() public {
    	vm.expectRevert(MyNft.cantSendToZeroAddress.selector);
    	mynft.mint(address(0));
    }

    function test_mint_revert_with_non_owner() public {
    	vm.expectRevert("you are not the owner");
    	vm.prank(alice);
    	mynft.mint(address(alice));
    }

    function test_transferOwnership_works() public {
    	vm.startPrank(alice);
    	vm.expectEmit(true, false, false, true);
    	emit OwnershipTrasfered(address(alice), address(john), 5);

    	mynft.transferOwnership(address(alice), address(john), 5);
    	vm.stopPrank();

    	assertEq(mynft.balanceOf(address(alice)), 4);
    	assertEq(mynft.balanceOf(address(john)), 1);
    	assertEq(mynft.ownerOf(5), address(john));
    }

    function test_transferOwnership_reverts_on_you_are_not_owner() public {
    	vm.expectRevert(MyNft.youAreNotOwner.selector);
    	mynft.transferOwnership(address(alice), address(john), 2);
    }

    function test_transferOwnership_reverts_on_you_do_not_own_the_token() public {
    	vm.expectRevert(MyNft.youDoNotOwnTheToken.selector);
    	vm.prank(alice);
    	mynft.transferOwnership(address(alice), address(john), 3);
    }

    function test_transferOwnership_reverts_on_one_wei_above() public {
    	vm.expectRevert(MyNft.youDoNotOwnTheToken.selector);
    	vm.prank(alice);
    	mynft.transferOwnership(address(alice), address(john), 2 + 1 wei);
    }

    function test_transferOwnership_pass_on_the_same_address() public {
    	vm.startPrank(alice);
    	vm.expectEmit(true, false, false, true);
    	emit OwnershipTrasfered(address(alice), address(alice), 5);

    	mynft.transferOwnership(address(alice), address(alice), 5);
    	vm.stopPrank();

    	assertEq(mynft.balanceOf(address(alice)), 5);
    }

    function test_transferOwnership_reverts_on_same_zero_address() public {
    	vm.expectRevert(MyNft.youAreNotOwner.selector);
    	mynft.transferOwnership(address(0), address(0), 1);
    }

    function test_transferOwnership_works_on_transfering_to_zero_address() public {
    	vm.startPrank(alice);
    	vm.expectEmit(true, false, false, true);
    	emit OwnershipTrasfered(address(alice), address(0), 5);

    	mynft.transferOwnership(address(alice), address(0), 5);
    	vm.stopPrank();

    	assertEq(mynft.balanceOf(address(alice)), 4);
    }


}

