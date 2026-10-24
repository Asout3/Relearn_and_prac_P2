// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Vault, ShareToken} from "../../src/Vault.sol";

/// @title VaultFuzzTest
/// @notice Fuzz tests for the Vault's deposit and withdraw accounting.
/// @dev All amounts are bounded to [1, 1e30] to avoid uint256 overflow in the
///      share math (`_amount * totalSupply`) while still exercising large values.
contract VaultFuzzTest is Test {
    Vault vault;
    ShareToken token;

    address alice;

    function setUp() public {
        token = new ShareToken("Underlying", "UND", 18, 0);
        vault = new Vault(address(token));

        alice = makeAddr("alice");
    }

    /// @notice Verifies that a first deposit mints shares 1:1 and updates vault accounting.
    /// @dev Protects: `totalAsset` increases by exactly `_assets`, shares minted match
    ///      `previewDeposit`, and total supply equals the minted shares.
    /// @param _assets Amount of underlying tokens to deposit (bounded 1..1e30).
    function testFuzz_deposit(uint256 _assets) public {
        _assets = bound(_assets, 1, 1e30);
        token.mint(_assets, alice);

        uint256 totalAssetBefore = vault.totalAsset();
        uint256 expectedShare = vault.previewDeposit(_assets);

        vm.startPrank(alice);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(_assets);
        vm.stopPrank();

        uint256 totalAssetAfter = vault.totalAsset();
        uint256 shareOf = vault.sharesOf(alice);

        assertEq(totalAssetAfter, totalAssetBefore + _assets);
        assertEq(shareOf, expectedShare);
        assertEq(vault.shareToken().totalSupply_(), expectedShare);
    }

    /// @notice Verifies that a partial withdraw returns the correct proportional amount,
    ///         and that a subsequent full withdraw empties the vault.
    /// @dev Protects: withdraw math `(shares * assets) / totalSupply`, no stranded assets
    ///      after full exit, and zero supply/shares afterwards.
    /// @param _depositAmount Amount deposited by alice (bounded 1..1e30).
    /// @param _withdrawAmount Shares to burn on first withdraw (bounded 1..alice's shares).
    function testFuzz_depositThenWithdraw(uint256 _depositAmount, uint256 _withdrawAmount) public {
        _depositAmount = bound(_depositAmount, 1, 1e30);

        token.mint(_depositAmount, alice);

        vm.startPrank(alice);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(_depositAmount);

        _withdrawAmount = bound(_withdrawAmount, 1, vault.sharesOf(alice));

        uint256 expectedDecreaseAmount = (_withdrawAmount * vault.totalAsset()) / vault.shareToken().totalSupply_();
        uint256 balanceAfterDeposit = token.balanceOf(alice);
        uint256 vaultAssetsBefore = vault.totalAsset();
        uint256 initialShares = vault.sharesOf(alice);

        vault.withdraw(_withdrawAmount);
        vm.stopPrank();

        assertEq(vault.sharesOf(alice), initialShares - _withdrawAmount);
        assertEq(vault.totalAsset(), vaultAssetsBefore - expectedDecreaseAmount);
        assertEq(token.balanceOf(alice), balanceAfterDeposit + expectedDecreaseAmount);

        uint256 remaining = vault.sharesOf(alice);
        if (remaining > 0) {
            vm.prank(alice);
            vault.withdraw(remaining);
        }

        assertEq(vault.sharesOf(alice), 0);
        assertEq(vault.shareToken().totalSupply_(), 0);
        assertEq(vault.totalAsset(), 0);
    }

    /// @notice Verifies that any non-excluded caller receives correct shares on deposit.
    /// @dev Uses `vm.assume` to exclude addresses that would make the test meaningless
    ///      (zero address, the vault itself, the underlying token). `bound()` cannot
    ///      filter specific addresses, so `vm.assume` is the correct tool here.
    /// @param _caller The fuzzed depositor address.
    /// @param _assets Amount to deposit (bounded 1..1e30).
    function testFuzz_depositFromValidCaller(address _caller, uint256 _assets) public {
        vm.assume(_caller != address(0));
        vm.assume(_caller != address(vault));
        vm.assume(_caller != address(token));

        _assets = bound(_assets, 1, 1e30);

        token.mint(_assets, _caller);

        uint256 expectedShares = vault.previewDeposit(_assets);
        uint256 vaultAssetsBefore = vault.totalAsset();
        uint256 totalSupplyBefore = vault.shareToken().totalSupply_();

        vm.startPrank(_caller);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(_assets);
        vm.stopPrank();

        assertEq(vault.sharesOf(_caller), expectedShares);
        assertEq(vault.totalAsset(), vaultAssetsBefore + _assets);
        assertEq(vault.shareToken().totalSupply_(), totalSupplyBefore + expectedShares);
    }
}
