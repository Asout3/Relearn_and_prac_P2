// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV2Pair} from "../../src/uniswapv2/UniswapV2Pair.sol";
import {UniswapV2Factory} from "../../src/uniswapv2/UniswapV2Factory.sol";
import {UniswapV2ERC20} from "../../src/uniswapv2/UniswapV2ERC20.sol";
import {IUniswapV2Pair} from "../../src/uniswapv2/Interfaces/IUniswapV2Pair.sol";

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "MockERC20: INSUFFICIENT_BALANCE");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

contract UniswapV2Integration is Test {
    UniswapV2Factory factory;
    MockERC20 token0;
    MockERC20 token1;

    address alice;
    address bob;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    function setUp() public {
        factory = new UniswapV2Factory(msg.sender);
        token0 = new MockERC20("Wrapped Ether", "WETH");
        token1 = new MockERC20("Asout3 Token", "A3T");

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token0.mint(alice, 10000 ether);
        token1.mint(alice, 10000 ether);
        token1.mint(bob, 10000 ether);
        token0.mint(bob, 10000 ether);
    }

    function _createPair()
        internal
        returns (address pair, IUniswapV2Pair pairContract, address expected0, address expected1, address expectedPair)
    {
        pair = factory.createPair(address(token0), address(token1));
        assertTrue(pair != address(0), "deployed to zero Address");

        pairContract = IUniswapV2Pair(pair);

        (expected0, expected1) =
            address(token1) > address(token0) ? (address(token0), address(token1)) : (address(token1), address(token0));

        expectedPair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(factory),
                            keccak256(abi.encodePacked(address(token0), address(token1))),
                            keccak256(type(UniswapV2Pair).creationCode)
                        )
                    )
                )
            )
        );
    }

    function _addLiquidity(address pair, address usr, uint256 _amount0, uint256 _amount1) internal {
        vm.startPrank(usr);
        token0.transfer(address(pair), _amount0);
        token1.transfer(address(pair), _amount1);
        vm.stopPrank();
    }

    function test_createPair_succeeds() public {
        (address pair, IUniswapV2Pair pairContract, address expected0, address expected1, address expectedPair) =
            _createPair();

        assertEq(expectedPair, pair);
        assertEq(pairContract.token0(), expected0);
        assertEq(pairContract.token1(), expected1);
        assertEq(pairContract.factory(), address(factory));
        assertEq(factory.allPairsLength(), 1);
    }

    function test_createPair_reverts_on_duplicate() public {
        factory.createPair(address(token0), address(token1));
        vm.expectRevert("UniswapV2: PAIR_EXISTS");
        factory.createPair(address(token0), address(token1));

        assertEq(factory.allPairsLength(), 1);
    }

    function test_firstMint_mintsCorrectShares_and_locksMinimumLiquidity() public {
        uint256 amount = 100 ether;
        uint256 amountLocked = 1000;
        uint256 expectedLiquidity = amount - amountLocked;

        (address pair, IUniswapV2Pair pairContract, address expected0, address expected1, address expectedPair) =
            _createPair();

        assertEq(expectedPair, pair);
        assertEq(pairContract.token0(), expected0);
        assertEq(pairContract.token1(), expected1);
        assertEq(pairContract.factory(), address(factory));
        assertEq(factory.allPairsLength(), 1);

        uint256 totalSupplyBefore = pairContract.totalSupply();
        uint256 balance0Before = token0.balanceOf(address(pair));
        uint256 balance1Before = token1.balanceOf(address(pair));
        (uint112 r0Before, uint112 r1Before,) = pairContract.getReserves();

        _addLiquidity(pair, alice, amount, amount);
        vm.expectEmit(true, false, false, true);
        emit Mint(alice, amount, amount);

        vm.prank(alice);
        uint256 liquidity = pairContract.mint(alice);

        (uint112 r0After, uint112 r1After,) = pairContract.getReserves();

        assertEq(pairContract.totalSupply(), totalSupplyBefore + amount);
        assertEq(token0.balanceOf(address(pair)), balance0Before + amount);
        assertEq(token1.balanceOf(address(pair)), balance1Before + amount);
        assertEq(r0After, uint256(r0Before) + amount);
        assertEq(r1After, uint256(r1Before) + amount);
        assertEq(liquidity, expectedLiquidity);
        assertEq(pairContract.balanceOf(alice), expectedLiquidity);
        assertEq(pairContract.balanceOf(address(0)), amountLocked);
    }

    function test_secondMint_proportional() public {
        uint256 amount = 100 ether;
        uint256 amountForBob = 50 ether;
        uint256 expectedLiquidity = 50 ether;

        (address pair, IUniswapV2Pair pairContract, address expected0, address expected1,) = _createPair();

        assertEq(pairContract.token0(), expected0);
        assertEq(pairContract.token1(), expected1);
        assertEq(pairContract.factory(), address(factory));
        assertEq(factory.allPairsLength(), 1);

        _addLiquidity(pair, alice, amount, amount);

        vm.expectEmit(true, false, false, true);
        emit Mint(alice, amount, amount);

        vm.prank(alice);
        pairContract.mint(alice);

        uint256 totalSupplyBefore = pairContract.totalSupply();
        uint256 balance0Before = token0.balanceOf(address(pair));
        uint256 balance1Before = token1.balanceOf(address(pair));
        (uint112 r0Before, uint112 r1Before,) = pairContract.getReserves();

        _addLiquidity(pair, bob, amountForBob, amountForBob);

        vm.expectEmit(true, false, false, true);
        emit Mint(bob, amountForBob, amountForBob);

        vm.prank(bob);
        uint256 liquidityBob = pairContract.mint(bob);

        (uint112 r0After, uint112 r1After,) = pairContract.getReserves();

        assertEq(pairContract.totalSupply(), totalSupplyBefore + amountForBob);
        assertEq(token0.balanceOf(address(pair)), balance0Before + amountForBob);
        assertEq(token1.balanceOf(address(pair)), balance1Before + amountForBob);
        assertEq(r0After, uint256(r0Before) + amountForBob);
        assertEq(r1After, uint256(r1Before) + amountForBob);
        assertEq(liquidityBob, expectedLiquidity);
        assertEq(pairContract.balanceOf(bob), expectedLiquidity);
    }

    function test_swap_token0_to_token1() public {
        uint256 aliceDepositToken0 = 1000 ether;
        uint256 aliceDepositToken1 = 500 ether;
        uint256 bobToken0ToTransfer = 25 ether;

        (address pair, IUniswapV2Pair pairContract, address expected0, address expected1,) = _createPair();

        assertEq(pairContract.token0(), expected0);
        assertEq(pairContract.token1(), expected1);
        assertEq(pairContract.factory(), address(factory));
        assertEq(factory.allPairsLength(), 1);

        _addLiquidity(pair, alice, aliceDepositToken0, aliceDepositToken1);

        vm.prank(alice);
        pairContract.mint(alice);

        uint256 balance0Before = token0.balanceOf(address(pair));
        uint256 balance1Before = token1.balanceOf(address(pair));
        uint256 balance0OfBobBefore = token0.balanceOf(address(bob));
        uint256 balance1OfBobBefore = token1.balanceOf(address(bob));
        (uint112 r0Before, uint112 r1Before,) = pairContract.getReserves();

        vm.startPrank(bob);
        token0.transfer(address(pair), bobToken0ToTransfer);

        uint256 bobToken1Expected =
            (bobToken0ToTransfer * 997 * uint256(r1Before)) / (uint256(r0Before) * 1000 + bobToken0ToTransfer * 997);

        vm.expectEmit(true, true, false, true);
        emit Swap(bob, bobToken0ToTransfer, 0, 0, bobToken1Expected, bob);

        pairContract.swap(0, bobToken1Expected, bob, "");
        vm.stopPrank();

        (uint112 r0After, uint112 r1After,) = pairContract.getReserves();

        assertEq(token0.balanceOf(bob), balance0OfBobBefore - bobToken0ToTransfer);
        assertEq(token1.balanceOf(bob), balance1OfBobBefore + bobToken1Expected);
        assertEq(token0.balanceOf(address(pair)), balance0Before + bobToken0ToTransfer);
        assertEq(token1.balanceOf(address(pair)), balance1Before - bobToken1Expected);
        assertEq(r0After, uint256(r0Before) + bobToken0ToTransfer);
        assertEq(r1After, uint256(r1Before) - bobToken1Expected);
    }

    // magic numbers
    function test_swap_token1_to_token0() public {
        uint256 aliceDepositToken0 = 1000 ether;
        uint256 aliceDepositToken1 = 500 ether;
        uint256 bobToken1ToTransfer = 25 ether;

        (address pair, IUniswapV2Pair pairContract, address expected0, address expected1,) = _createPair();

        assertEq(pairContract.token0(), expected0);
        assertEq(pairContract.token1(), expected1);
        assertEq(pairContract.factory(), address(factory));
        assertEq(factory.allPairsLength(), 1);

        _addLiquidity(pair, alice, aliceDepositToken0, aliceDepositToken1);

        vm.prank(alice);
        pairContract.mint(alice);

        uint256 balance0Before = token0.balanceOf(address(pair));
        uint256 balance1Before = token1.balanceOf(address(pair));
        uint256 balance0OfBobBefore = token0.balanceOf(address(bob));
        uint256 balance1OfBobBefore = token1.balanceOf(address(bob));
        (uint112 r0Before, uint112 r1Before,) = pairContract.getReserves();

        vm.startPrank(bob);
        token1.transfer(address(pair), bobToken1ToTransfer);

        uint256 bobToken0Expected = (47 ether * 997 * uint256(r1Before)) / (uint256(r0Before) * 1000 + 47 ether * 997);

        vm.expectEmit(true, true, false, true);
        emit Swap(bob, 0, bobToken1ToTransfer, bobToken0Expected, 0, bob);

        pairContract.swap(bobToken0Expected, 0, bob, "");
        vm.stopPrank();

        (uint112 r0After, uint112 r1After,) = pairContract.getReserves();

        assertEq(token0.balanceOf(bob), balance0OfBobBefore + bobToken0Expected);
        assertEq(token1.balanceOf(bob), balance1OfBobBefore - bobToken1ToTransfer);
        assertEq(token0.balanceOf(address(pair)), balance0Before - bobToken0Expected);
        assertEq(token1.balanceOf(address(pair)), balance1Before + bobToken1ToTransfer);
        assertEq(r0After, uint256(r0Before) - bobToken0Expected);
        assertEq(r1After, uint256(r1Before) + bobToken1ToTransfer);
    }

    // magic numbers
    function test_swap_kInvariantHolds() public {
        uint256 aliceDepositToken0 = 1000 ether;
        uint256 aliceDepositToken1 = 500 ether;

        (address pair, IUniswapV2Pair pairContract, address expected0, address expected1,) = _createPair();

        assertEq(pairContract.token0(), expected0);
        assertEq(pairContract.token1(), expected1);
        assertEq(pairContract.factory(), address(factory));
        assertEq(factory.allPairsLength(), 1);

        _addLiquidity(pair, alice, aliceDepositToken0, aliceDepositToken1);

        vm.prank(alice);
        pairContract.mint(alice);

        (uint112 r0Before, uint112 r1Before,) = pairContract.getReserves();

        _addLiquidity(pair, bob, 0, 25 ether);

        uint256 Token0Expected1 = (47 ether * 997 * uint256(r1Before)) / (uint256(r0Before) * 1000 + 47 ether * 997);
        pairContract.swap(Token0Expected1, 0, bob, "");

        (uint112 r0After, uint112 r1After,) = pairContract.getReserves();

        assertTrue(uint256(r0After) * uint256(r1After) >= uint256(r0Before) * uint256(r1Before), "K decreased");

        (uint112 r0Before1, uint112 r1Before1,) = pairContract.getReserves();

        _addLiquidity(pair, alice, aliceDepositToken0, 60 ether);

        uint256 bobToken0Expected2 =
            (106 ether * 997 * uint256(r1Before)) / (uint256(r0Before) * 1000 + 106 ether * 997);
        pairContract.swap(bobToken0Expected2, 0, bob, "");

        (uint112 r0After2, uint112 r1After2,) = pairContract.getReserves();

        assertTrue(uint256(r0After2) * uint256(r1After2) >= uint256(r0Before1) * uint256(r1Before1), "K decreased");
    }

    // magic numbers
    function test_swap_feeAccounting() public {
        uint256 aliceDepositToken0 = 1000 ether;
        uint256 aliceDepositToken1 = 500 ether;

        (address pair, IUniswapV2Pair pairContract, address expected0, address expected1,) = _createPair();

        assertEq(pairContract.token0(), expected0);
        assertEq(pairContract.token1(), expected1);
        assertEq(pairContract.factory(), address(factory));
        assertEq(factory.allPairsLength(), 1);

        _addLiquidity(pair, alice, aliceDepositToken0, aliceDepositToken1);

        pairContract.mint(alice);
        (uint112 r0Before, uint112 r1Before,) = pairContract.getReserves();

        uint256 bobToken1Expected = (25 ether * 997 * uint256(r1Before)) / (uint256(r0Before) * 1000 + 25 ether * 997);

        _addLiquidity(pair, bob, 25 ether, 0);
        pairContract.swap(0, bobToken1Expected, bob, "");

        (uint112 r0After, uint112 r1After,) = pairContract.getReserves();

        assertGt(uint256(r0After) * uint256(r1After), uint256(r0Before) * uint256(r1Before), "fee not accrued");
    }

    // magic numbers
    function test_swap_with_zero_amount() public {
        uint256 aliceDepositToken0 = 1000 ether;
        uint256 aliceDepositToken1 = 500 ether;

        (address pair, IUniswapV2Pair pairContract, , ,) = _createPair();
        _addLiquidity(pair, alice, aliceDepositToken0, aliceDepositToken1);
        pairContract.mint(alice);

         _addLiquidity(pair, bob, 25 ether, 0);
        vm.expectRevert( "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        pairContract.swap(0, 0, bob, "");
    }

    // magic number
    function test_swap_exceeding_reserves() public {
        (address pair, IUniswapV2Pair pairContract, , ,) = _createPair();

        _addLiquidity(pair, bob, 25 ether, 0);
        vm.expectRevert("UniswapV2: INSUFFICIENT_LIQUIDITY");
        pairContract.swap(0, 25 ether, bob, "");
    }

    // this have issues other wise we are done
    function test_mint_with_zero_tokens() public {
        (address pair, IUniswapV2Pair pairContract, , ,) = _createPair();
        vm.expectRevert("UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        pairContract.mint(alice);
    }
}

