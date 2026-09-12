// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MyNft} from "../src/ERC721.sol";

contract ERC721Test is Test {
    MyNft mynft;
    address bel;
    address alice;
    address bob;
    address john;
    address nig;

    event OwnershipTrasfered(address indexed _from, address indexed _to, uint256 indexed _id);
    event Approved(address indexed _owner, address _spender, uint256 indexed _id);
    event Transfered(address indexed _from, address indexed _to, uint256 indexed _id);

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
        vm.expectEmit(true, true, true, false);
        emit OwnershipTrasfered(address(0), address(alice), 16);

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
        vm.expectEmit(true, true, true, false);
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

    function test_transferOwnership_pass_on_the_same_address() public {
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, false);
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
        vm.expectEmit(true, true, true, false);
        emit OwnershipTrasfered(address(alice), address(0), 5);

        mynft.transferOwnership(address(alice), address(0), 5);
        vm.stopPrank();

        assertEq(mynft.balanceOf(address(alice)), 4);
    }

    function test_MyNft_approve_works() public {
        vm.startPrank(alice);
        vm.expectEmit(true, false, true, false);
        emit Approved(address(alice), address(john), 2);

        mynft.approve(address(john), 2);
        vm.stopPrank();

        assertEq(mynft.approvedAddresses(2), address(john));
    }

    function test_MyNft_approve_reverts_on_youDoNotOwnTheToken() public {
        vm.prank(alice);
        vm.expectRevert(MyNft.youDoNotOwnTheToken.selector);
        mynft.approve(address(john), 1);
    }

    function test_My_Nft_approve_pass_on_approving_to_zero_address() public {
        vm.startPrank(alice);
        vm.expectEmit(true, false, true, false);
        emit Approved(address(alice), address(0), 2);

        mynft.approve(address(0), 2);
        vm.stopPrank();
    }

    function test_MyNft_approve_pass_on_approving_your_self() public {
        vm.startPrank(alice);
        vm.expectEmit(true, false, true, false);
        emit Approved(address(alice), address(alice), 2);

        mynft.approve(address(alice), 2);
        vm.stopPrank();
    }

    function test_MyNft_approve_reverts_on_youDoNotOwnTheToken_one_wei_plus_id() public {
        vm.prank(alice);
        vm.expectRevert(MyNft.youDoNotOwnTheToken.selector);
        mynft.approve(address(john), 2 + 1 wei);
    }

    function test_MyNft_transfer_works() public {
        uint256 tokenIdToTransfer = 2;
        uint256 amountOfNftAliceHaveBeforeTransfer = mynft.amountOfNft(alice);

        vm.expectEmit(true, true, true, false);
        emit Transfered(alice, john, tokenIdToTransfer);

        vm.prank(alice);
        mynft.transfer((john), tokenIdToTransfer);

        vm.assertEq(mynft.ownerOf(tokenIdToTransfer), john);
        vm.assertEq(mynft.amountOfNft(alice), amountOfNftAliceHaveBeforeTransfer - 1);
        vm.assertEq(mynft.amountOfNft(john), 1);
    }

    function test_MyNft_transfer_reverts_with_youDoNotOwnTheToken() public {
        uint256 tokenId = 3;

        vm.expectRevert(MyNft.youDoNotOwnTheToken.selector);
        vm.prank(alice);
        mynft.transfer(john, tokenId);
    }

    function test_MyNft_transfer_reverts_when_sending_to_zero_address() public {
        uint256 tokenId = 2;
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);
        address zeroaddress = address(0);

        vm.expectRevert(MyNft.cantSendToZeroAddress.selector);
        vm.prank(alice);
        mynft.transfer(zeroaddress, tokenId);

        assertEq(mynft.amountOfNft(alice), aliceAmountBefore);
    }

    function test_myNft_transfer_works_when_self_transfering() public {
        uint256 tokenIdToTransfer = 2;
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);

        vm.expectEmit(true, true, true, false);
        emit Transfered(alice, alice, tokenIdToTransfer);

        vm.prank(alice);
        mynft.transfer(alice, tokenIdToTransfer);

        vm.assertEq(mynft.amountOfNft(alice), aliceAmountBefore);
    }

    function test_MyNft_transfer_emits_when_transfered() public {
        uint256 tokenIdToTransfer = 2;

        vm.expectEmit(true, true, true, false);
        emit Transfered(alice, john, tokenIdToTransfer);

        vm.prank(alice);
        mynft.transfer((john), tokenIdToTransfer);
    }

    function test_MyNft_transferFrom_works() public {
        uint256 tokenId = 5;
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);
        uint256 johnAmountBefore = mynft.amountOfNft(john);

        vm.prank(alice);
        mynft.approve(john, tokenId);

        vm.expectEmit(true, true, true, false);
        emit Transfered(alice, john, tokenId);

        vm.prank(john);
        mynft.transferFrom(alice, john, tokenId);

        assertEq(mynft.amountOfNft(john), johnAmountBefore + 1);
        assertEq(mynft.amountOfNft(alice), aliceAmountBefore - 1);
        assertEq(mynft.ownerOf(tokenId), john);
    }

    function test_MyNft_transfer_reverts_on_youDoNotOwnTheToken() public {
        // this is redundunt test like if you can't get approved it couldn't pass so like the main source code is like bad.
        // i write this test anyway so like to put the coverage but the main contract is fucked up.
        uint256 tokenId = 1;
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);
        uint256 johnAmountBefore = mynft.amountOfNft(john);

        vm.expectRevert(MyNft.youDoNotOwnTheToken.selector);
        vm.prank(alice);
        mynft.approve(bob, 1);

        vm.prank(bob);
        vm.expectRevert(MyNft.youDoNotOwnTheToken.selector);
        mynft.transferFrom(alice, john, tokenId);

        assertEq(mynft.amountOfNft(john), johnAmountBefore);
        assertEq(mynft.amountOfNft(alice), aliceAmountBefore);
    }

    function test_MyNft_transfer_reverts_on_youAreNotOwner() public {
        uint256 tokenId = 5;
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);
        uint256 johnAmountBefore = mynft.amountOfNft(john);

        vm.expectRevert(MyNft.youAreNotOwner.selector);
        vm.prank(john);
        mynft.transferFrom(alice, john, tokenId);

        assertEq(mynft.amountOfNft(john), johnAmountBefore);
        assertEq(mynft.amountOfNft(alice), aliceAmountBefore);
    }

    function test_MyNft_transferFrom_reverts_on_cantSendToZeroAddress() public {
        uint256 tokenId = 2;
        address zeroAddress = address(0);
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);

        vm.prank(alice);
        mynft.approve(john, tokenId);

        vm.expectRevert(MyNft.cantSendToZeroAddress.selector);

        vm.prank(john);
        mynft.transferFrom(alice, zeroAddress, tokenId);

        assertEq(mynft.amountOfNft(alice), aliceAmountBefore);
    }

    function test_transferFrom_works_on_similar_address_with_approved_condition() public {
        uint256 tokenId = 5;
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);

        vm.prank(alice);
        mynft.approve(alice, tokenId);

        vm.expectEmit(true, true, true, false);
        emit Transfered(alice, alice, tokenId);

        vm.prank(alice);
        mynft.transferFrom(alice, alice, tokenId);

        assertEq(mynft.amountOfNft(alice), aliceAmountBefore);
    }

    function test_transferFrom_reverts_on_similar_address_with_not_approved_condition() public {
        uint256 tokenId = 5;
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);

        vm.expectRevert(MyNft.youAreNotOwner.selector);

        vm.prank(alice);
        mynft.transferFrom(alice, alice, tokenId);

        assertEq(mynft.amountOfNft(alice), aliceAmountBefore);
    }

    function test_transferFrom_reverts_for_from_address_is_zero_address() public {
        uint256 tokenId = 5;
        uint256 aliceAmountBefore = mynft.amountOfNft(alice);

        vm.prank(alice);
        mynft.approve(john, tokenId);

        vm.expectRevert(MyNft.youDoNotOwnTheToken.selector);

        vm.prank(john);
        mynft.transferFrom(address(0), alice, tokenId);

        assertEq(mynft.amountOfNft(alice), aliceAmountBefore);
    }

    function test_transferFrom_emits_an_event() public {
        uint256 tokenId = 5;

        vm.prank(alice);
        mynft.approve(john, tokenId);

        vm.expectEmit(true, true, true, false);
        emit Transfered(alice, john, tokenId);

        vm.prank(john);
        mynft.transferFrom(alice, john, tokenId);
    }

    function test_ownerOf_works() public view {
        // bob owns this tokens from the setUp : 3, 6, 9, 12, 15
        for (uint256 i = 3; i < 16; i += 3) {
            assertEq(mynft.ownerOf(i), bob);
        }
    }

    function test_ownerOf_on_unkown_id() public view {
        assertEq(mynft.ownerOf(50), address(0));
    }

    function test_amountOfNft_works() public view {
        //amount of nft they own from the setUp each of them own 5;
        uint256 amountOfNft = 5;

        assertEq(mynft.amountOfNft(alice), amountOfNft);
        assertEq(mynft.amountOfNft(bel), amountOfNft);
        assertEq(mynft.amountOfNft(bob), amountOfNft);
    }

    function test_amountOfNft_on_unknown_owner() public {
        address unkownOwner = makeAddr("unkownOwner");
        uint256 amountOfTokenTheUnkownOwnerHave = 0;

        assertEq(mynft.amountOfNft(unkownOwner), amountOfTokenTheUnkownOwnerHave);
    }

    function test_approvedAddresses_works() public {
        uint256 tokenId = 2;

        vm.prank(alice);
        mynft.approve(john, tokenId);

        assertEq(mynft.approvedAddresses(tokenId), john);
    }

    function test_approvedAddresses_on_unkown_id() public view {
        uint256 tokenId = 20;

        assertEq(mynft.approvedAddresses(tokenId), address(0));
    }
}
