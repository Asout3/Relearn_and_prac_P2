// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test, console2} from "forge-std/Test.sol";
import {VulnerableBank} from "../../src/VulnerableBank.sol";
import {SafeBank} from "../../src/SafeBank.sol";
import {Attacker, SafeBankAttacker} from "../../src/Attacker.sol";

/// @title A simulator for Reentrancy attack and Safer bank
/// @author Mikiyas.
/// @notice This is just simulation.
contract Reentrancy is Test {
    VulnerableBank bank;
    Attacker attacker;
    SafeBankAttacker sattacker;
    SafeBank safeBank;
    address alice;

    function setUp() public {
        bank = new VulnerableBank();
        attacker = new Attacker(bank);
        safeBank = new SafeBank();
        sattacker = new SafeBankAttacker(safeBank);

        alice = makeAddr("alice");

        vm.deal(alice, 1000_000 ether);
        /// @dev  well the attack will revert due to recursive call depth we can't go above 1000
        ///       at one call can on mainnet it is just around 340 because the 63/64 gas rule
        ///       starves deep calls long before the 1024 hard limit so lets withdraw huge amount
        ///       and assume the attacker get it from flash loan.
        vm.deal(address(this), 100_000 ether);
    }

    function test_exploit() public {
        vm.prank(alice);
        bank.deposit{value: 1000_000 ether}();
        uint256 bankBalanceBefore = bank.checkBalance();
        uint256 attackerBeforeAttack = attacker.getTotalBalance();

        attacker.deposit{value: 10_000 ether}();
        uint256 attackerBalanceAfterDeposit = attacker.getTotalBalance();
        attacker.depositToVictimContractAndAttack();
        uint256 afterAttack = attacker.getTotalBalance();
        uint256 bankBalanceAfterAttack = bank.checkBalance();

        console2.log("Bank balance before: ", bankBalanceBefore / 1e18);
        console2.log("attacker before attack: ", attackerBeforeAttack / 1e18);
        console2.log("attacker balance after deposit", attackerBalanceAfterDeposit / 1e18);
        console2.log("wellie After Attack: ", afterAttack / 1e18);
        console2.log("Bank After Attack", bankBalanceAfterAttack / 1e18);

        assertEq(bankBalanceAfterAttack, 0);
        assertEq(afterAttack, 1010000 ether);
    }

    function test_safeBank() public {
        vm.prank(alice);
        safeBank.deposit{value: 1000_000 ether}();
        uint256 bankBalanceBefore = safeBank.checkBalance();
        uint256 attackerBeforeAttack = sattacker.getTotalBalance();

        sattacker.deposit{value: 10_000 ether}();
        uint256 attackerBalanceAfterDeposit = sattacker.getTotalBalance();
        vm.expectRevert(SafeBank.TransferFailed.selector);
        sattacker.depositToVictimContractAndAttack();
        uint256 afterAttack = sattacker.getTotalBalance();
        uint256 bankBalanceAfterAttack = safeBank.checkBalance();

        console2.log("Bank balance before: ", bankBalanceBefore / 1e18);
        console2.log("Attacker before attack: ", attackerBeforeAttack / 1e18);
        console2.log("Attacker balance after deposit", attackerBalanceAfterDeposit / 1e18);
        console2.log("Attacker balance After Attack: ", afterAttack / 1e18);
        console2.log("Bank After Attack", bankBalanceAfterAttack / 1e18);

        assertEq(bankBalanceAfterAttack, 1000_000 ether);
        assertEq(afterAttack, 10_000 ether);
    }
}
