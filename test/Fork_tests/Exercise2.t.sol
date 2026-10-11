// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Owner {
    address public owner;

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    constructor() {
        owner = msg.sender;
    }

    function privileged(address _to, uint256 _amount) external returns (bool) {
        require(msg.sender == owner, "Not owner");

        bool ok = IERC20(DAI).transfer(_to, _amount);
        require(ok, "transfer failed");

        return true;
    }
}

contract Exercise1 is Test {
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant WHALE = 0x28C6c06298d514Db089934071355E5743bf21d60;
    address joe = makeAddr("joe");
    address bel = makeAddr("bel");

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 18_000_000);
    }

    function test_exercise2A() public {
        uint256 amount = 500e18;

        uint256 whaleBalacneBefore = IERC20(DAI).balanceOf(WHALE);
        uint256 joeBalanceBefore = IERC20(DAI).balanceOf(joe);
        console2.log("Balance of whale before sending: ", whaleBalacneBefore / 1e18);
        console2.log("Balance of joe before sending: ", joeBalanceBefore / 1e18);

        vm.prank(WHALE);
        bool ok = IERC20(DAI).transfer(joe, amount);
        assertTrue(ok, "transfer failed");

        console2.log("Balance of whale after sending: ", IERC20(DAI).balanceOf(WHALE) / 1e18);
        console2.log("Balance of joe after sending: ", IERC20(DAI).balanceOf(joe) / 1e18);

        assertEq(IERC20(DAI).balanceOf(joe), joeBalanceBefore + amount);
        assertEq(IERC20(DAI).balanceOf(WHALE), whaleBalacneBefore - amount);
    }

    function test_exercise2B() public {
        uint256 amount = 100e18;
        uint256 amount2 = 200e18;

        uint256 whaleBalacneBefore = IERC20(DAI).balanceOf(WHALE);
        uint256 joeBalanceBefore = IERC20(DAI).balanceOf(joe);
        console2.log("Balance of whale before sending: ", whaleBalacneBefore / 1e18);
        console2.log("Balance of joe before sending: ", joeBalanceBefore / 1e18);

        vm.startPrank(WHALE);
        bool ok = IERC20(DAI).transfer(joe, amount);
        assertTrue(ok, "transfer failed");

        bool ok2 = IERC20(DAI).transfer(joe, amount2);
        assertTrue(ok2, "transfer failed");
        vm.stopPrank();

        console2.log("Balance of whale after sending: ", IERC20(DAI).balanceOf(WHALE) / 1e18);
        console2.log("Balance of joe after sending: ", IERC20(DAI).balanceOf(joe) / 1e18);

        vm.expectRevert();
        IERC20(DAI).transfer(joe, amount);

        assertEq(IERC20(DAI).balanceOf(address(this)), 0);
        assertEq(IERC20(DAI).balanceOf(joe), joeBalanceBefore + amount + amount2);
        assertEq(IERC20(DAI).balanceOf(WHALE), whaleBalacneBefore - amount - amount2);
    }

    function test_exercise2C1() public {
        uint256 amount = 1000e18;

        uint256 whaleBalacneBeforeDeal = IERC20(DAI).balanceOf(WHALE);
        uint256 balanceBeforeDeal = IERC20(DAI).balanceOf(address(this));

        deal(DAI, address(this), amount);

        uint256 whaleBalacneAfterDeal = IERC20(DAI).balanceOf(WHALE);

        assertEq(whaleBalacneBeforeDeal, whaleBalacneAfterDeal);
        assertGt(IERC20(DAI).balanceOf(address(this)), balanceBeforeDeal);
    }

    function test_exercise2C2() public {
        uint256 amount = 1000e18;

        uint256 whaleBalacneBeforeDeal = IERC20(DAI).balanceOf(WHALE);

        vm.prank(WHALE);
        bool ok = IERC20(DAI).transfer(address(this), amount);
        assertTrue(ok, "transfer failed");

        assertEq(IERC20(DAI).balanceOf(WHALE), whaleBalacneBeforeDeal - amount);
    }

    function test_exercise2D1() public {
        uint256 amount = 1000e6;
        uint256 amountToTransfer = 500e6;

        uint256 balanceBeforeDeal = IERC20(USDC).balanceOf(address(this));

        // nothing really happens
        deal(USDC, address(this), amount);

        assertEq(IERC20(USDC).balanceOf(address(this)), balanceBeforeDeal + amount);

        uint256 balanceOfJoeBefore = IERC20(USDC).balanceOf(joe);
        uint256 balanceAfterDeal = IERC20(USDC).balanceOf(address(this));

        bool ok = IERC20(USDC).transfer(joe, amountToTransfer);
        assertTrue(ok, "transfer failed");

        assertEq(IERC20(USDC).balanceOf(address(this)), balanceAfterDeal - amountToTransfer);
        assertEq(IERC20(USDC).balanceOf(joe), balanceOfJoeBefore + amountToTransfer);
    }

    function test_exercise2D2() public {
        uint256 amount = 1000e6;
        uint256 amountToTransfer = 500e6;

        uint256 balanceBeforeDeal = IERC20(USDC).balanceOf(address(this));

        // now better
        deal(USDC, address(this), amount, true);

        assertEq(IERC20(USDC).balanceOf(address(this)), balanceBeforeDeal + amount);

        uint256 balanceOfJoeBefore = IERC20(USDC).balanceOf(joe);
        uint256 balanceAfterDeal = IERC20(USDC).balanceOf(address(this));

        bool ok = IERC20(USDC).transfer(joe, amountToTransfer);
        assertTrue(ok, "transfer failed");

        assertEq(IERC20(USDC).balanceOf(address(this)), balanceAfterDeal - amountToTransfer);
        assertEq(IERC20(USDC).balanceOf(joe), balanceOfJoeBefore + amountToTransfer);
    }

    function test_exercise2E1() public {
        Owner ow = new Owner();

        deal(DAI, address(this), 1000e18);
        deal(DAI, address(ow), 10_000e18);

        bool ok = ow.privileged(joe, 500e18);
        assertTrue(ok, "transfer failed");
    }

    function test_exercise2E2() public {
        Owner ow = new Owner();

        deal(DAI, address(ow), 10_000e18);

        vm.expectRevert("Not owner");
        vm.prank(joe);
        ow.privileged(joe, 500e18);
    }
}
