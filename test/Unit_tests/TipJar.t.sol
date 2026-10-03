// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {TipJar} from "../../src/TipJar.sol";
import {MaliciousReceiver} from "../../src/MaliciousReceiver.sol";

contract TestTipJar is Test {
    TipJar tipJ;
    MaliciousReceiver maliciousReceiver; // maliciousReceiver
    address elon;
    address messi;
    address MJ;
    address walter;
    address trump;

    function setUp() public {
        tipJ = new TipJar();
        maliciousReceiver = new MaliciousReceiver();

        elon = makeAddr("elon");
        messi = makeAddr("messi");
        MJ = makeAddr("MJ");
        walter = makeAddr("walter");
        trump = makeAddr("trump");

        vm.deal(elon, 1000 ether);

        vm.startPrank(elon);
        tipJ.tip{value: 8 ether}(messi);
        tipJ.tip{value: 3 ether}(MJ);
        tipJ.tip{value: 5 ether}(walter);
        tipJ.tip{value: 9 ether}(trump);
        vm.stopPrank();
    }

    function test_works_on_distribute() public {
        tipJ.distribute();

        assertEq(tipJ.tipsOwed(trump), 0);
        assertEq(tipJ.tipsOwed(messi), 0);
        assertEq(tipJ.tipsOwed(MJ), 0);
        assertEq(tipJ.tipsOwed(walter), 0);

        assertEq(messi.balance, 8 ether);
        assertEq(trump.balance, 9 ether);
        assertEq(walter.balance, 5 ether);
        assertEq(MJ.balance, 3 ether);
    }

    function test_works_on_claim() public {
        vm.prank(messi);
        tipJ.claim();

        assertEq(tipJ.tipsOwed(trump), 9 ether);
        assertEq(tipJ.tipsOwed(messi), 0);
        assertEq(tipJ.tipsOwed(MJ), 3 ether);
        assertEq(tipJ.tipsOwed(walter), 5 ether);

        assertEq(messi.balance, 8 ether);
        assertEq(trump.balance, 0);
        assertEq(walter.balance, 0);
        assertEq(MJ.balance, 0);
    }

    function test_double_claim_reverts() public {
        vm.prank(messi);
        tipJ.claim();

        assertEq(tipJ.tipsOwed(messi), 0);

        vm.prank(messi);
        vm.expectRevert(TipJar.NoTipsOwed.selector);
        tipJ.claim();

        assertEq(messi.balance, 8 ether);
    }

    function test_distribute_on_Mreceiver() public {
        vm.prank(elon);
        tipJ.tip{value: 12 ether}(address(maliciousReceiver));

        vm.expectRevert(TipJar.TransferFailed.selector);
        tipJ.distribute();

        assertEq(tipJ.tipsOwed(address(maliciousReceiver)), 12 ether);
        assertEq(tipJ.tipsOwed(trump), 9 ether);
        assertEq(tipJ.tipsOwed(messi), 8 ether);
        assertEq(tipJ.tipsOwed(MJ), 3 ether);
        assertEq(tipJ.tipsOwed(walter), 5 ether);

        assertEq(messi.balance, 0);
        assertEq(trump.balance, 0);
        assertEq(walter.balance, 0);
        assertEq(MJ.balance, 0);
    }
}
