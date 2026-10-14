// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test, console2} from "forge-std/Test.sol";

/// @title Minimal ERC20 interface
/// @notice Used to interact with mainnet tokens in fork tests.
interface IERC20 {
    /// @notice Returns the token balance of `account`.
    /// @param account The address to query.
    /// @return The balance of `account`.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the total supply of the token.
    /// @return The total supply.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the number of decimals used by the token.
    /// @return The decimals (e.g. 6 for USDC, 18 for DAI).
    function decimals() external view returns (uint8);

    /// @notice Transfers `amount` tokens to `to`.
    /// @param to The recipient address.
    /// @param amount The amount of tokens to transfer.
    /// @return True if the transfer succeeded.
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title Fork testing examples
/// @notice Demonstrates how to test real mainnet tokens on a forked network.
/// @dev Uses Foundry cheatcodes such as `vm.label`, `makeAddr`, `deal`, and `vm.expectRevert`.
contract Forktest is Test {
    /// @notice Mainnet address of USDC.
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @notice Mainnet address of DAI.
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    /// @notice Test address used to simulate a user.
    address alice;

    /// @notice Sets up labels and creates the `alice` address before each test.
    ///         and creates and select fork at specific block.
    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 18_000_000);
        vm.label(USDC, "USDC");
        vm.label(DAI, "DAI");
        alice = makeAddr("alice");
    }

    /// @notice Checks that USDC reports 6 decimals on mainnet.
    /// @dev This is a simple fork test that reads real on-chain data.
    function test_usdcHas6Decimals() public view {
        console2.log(IERC20(USDC).decimals());
        assertEq(IERC20(USDC).decimals(), 6);
    }

    /// @notice Shows that transferring 1000e18 USDC fails because USDC uses 6 decimals.
    /// @dev `deal` gives alice 1000e6 USDC (1000 USDC). The transfer tries to send 1000e18,
    /// which is far more than her balance, so the call must revert.
    function test_usdcTransferFailsWith18DecimalAssumption() public {
        // Give alice 1000 USDC (1000 * 10^6) and adjust total supply.
        deal(USDC, alice, 1000e6, true);

        vm.startPrank(alice);
        // This assumes USDC has 18 decimals - it should fail
        // because alice only has 1000e6 USDC, not 1000e18.
        vm.expectRevert(); // Insufficient balance
        IERC20(USDC).transfer(address(this), 1000e18);
        vm.stopPrank();
    }
}
