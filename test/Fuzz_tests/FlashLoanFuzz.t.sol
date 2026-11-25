// SPDX-License-Identifier: MIT
pragma solidity ^0.8.38;

import {Test} from "forge-std/Test.sol";
import {Flashlender} from "../../src/Flashlender.sol";
import {MaliciousBorrower} from "../../src/MaliciousBorrower.sol";
import {Asout3Token} from "../../src/ERC20.sol";

contract flashLoanTest is Test {
    Flashlender lender;
    MaliciousBorrower borrower;
    Asout3Token token;

    address public alice;
    address public bob;

    uint256 public constant LENDER_TOTAL_AMOUNT = 600e18;
    uint256 public constant BORROWER_BALANCE = 10e18;
    uint256 public constant STARTING_BORROWING_AMOUNT = 5e18;

    function setUp() public {
        lender = new Flashlender();
        token = new Asout3Token("meow", "mw", 18, 1000e18);
        borrower = new MaliciousBorrower(address(lender), address(token));

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token.transfer(address(lender), LENDER_TOTAL_AMOUNT);
        token.transfer(address(borrower), BORROWER_BALANCE);
    }

    function testFuzz_lenderNeverLosesPrincipal(uint256 _amount) public {
        _amount = bound(_amount, STARTING_BORROWING_AMOUNT, LENDER_TOTAL_AMOUNT);

        uint256 balanceOfLenderBeforeLent = token.balanceOf(address(lender));

        borrower.flashloan(address(token), _amount);

        uint256 balanceOfLenderAfterLent = token.balanceOf(address(lender));
        assertGe(balanceOfLenderAfterLent, balanceOfLenderBeforeLent);
    }

    function testFuzz_maliciousReciverhostile(uint256 _amount) public {
        _amount = bound(_amount, STARTING_BORROWING_AMOUNT, LENDER_TOTAL_AMOUNT);

        uint256 balanceOfLenderBeforeLent = token.balanceOf(address(lender));

        borrower.setSteal(true);
        vm.expectRevert(Asout3Token.InsufficientAllowance.selector);
        borrower.flashloan(address(token), _amount);

        uint256 balanceOfLenderAfterLent = token.balanceOf(address(lender));
        assertGe(balanceOfLenderAfterLent, balanceOfLenderBeforeLent);
    }
}
