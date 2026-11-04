// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice The natSpec(doc) is written by an AI(deepseek v4.1 flash)

import {Test} from "forge-std/Test.sol";
import {AMM, LP} from "../../src/AMM.sol";

/// @title AMMHandler
/// @notice Fuzz handler wrapping AMM interactions for invariant testing.
/// @dev    Funds actors with both tokens and keeps swap calls within balances.
contract AMMHandler is Test {
    AMM amm;
    LP tokenA;
    LP tokenB;

    address[] public actors;
    address internal currentActor;
    uint256 constant AMOUNT_OF_TOKEN_TO_ADD_TO_LIQUIDITY = 1000 ether;
    uint256 constant AMOUNT_OF_TOKEN_TO_MINT = 110_000 ether;
    uint256 private constant _ACTOR_COUNT = 5;
    uint256 private constant _MIN_SWAP_AMOUNT = 1;

    /// @notice Deploys the handler, funds all actors, and seeds initial liquidity.
    /// @param _amm    The AMM contract under test.
    /// @param _tokenA First token of the pair, minted to actors.
    /// @param _tokenB Second token of the pair, minted to actors.
    constructor(AMM _amm, LP _tokenA, LP _tokenB) {
        amm = _amm;
        tokenA = _tokenA;
        tokenB = _tokenB;
        for (uint256 i = 0; i < _ACTOR_COUNT; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            actors.push(actor);
            vm.startPrank(msg.sender);
            _tokenA.mint(AMOUNT_OF_TOKEN_TO_MINT, actor);
            _tokenB.mint(AMOUNT_OF_TOKEN_TO_MINT, actor);
            vm.stopPrank();

            vm.prank(actor);
            _tokenA.approve(address(amm), type(uint256).max);
            vm.prank(actor);
            _tokenB.approve(address(amm), type(uint256).max);
        }

        vm.startPrank(msg.sender);
        _tokenA.mint(AMOUNT_OF_TOKEN_TO_ADD_TO_LIQUIDITY, address(this));
        _tokenB.mint(AMOUNT_OF_TOKEN_TO_ADD_TO_LIQUIDITY, address(this));
        vm.stopPrank();

        _tokenA.approve(address(amm), type(uint256).max);
        _tokenB.approve(address(amm), type(uint256).max);
        amm.addLiquidity(AMOUNT_OF_TOKEN_TO_ADD_TO_LIQUIDITY, AMOUNT_OF_TOKEN_TO_ADD_TO_LIQUIDITY);
    }

    /// @notice Selects an actor from `actors` and pranks as them for the body.
    /// @param actorSeed Seed used to derive the actor index via `bound`.
    modifier useActor(uint256 actorSeed) {
        currentActor = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    /// @notice Swaps tokenA for tokenB on behalf of a selected actor.
    /// @param _actorSeed Seed used to select the acting address.
    /// @param _amount    Requested amount of tokenA to swap in; bounded to the actor's balance.
    function swapAforB(uint256 _actorSeed, uint256 _amount) public useActor(_actorSeed) {
        uint256 bal = tokenA.balanceOf(currentActor);
        if (bal == 0) return;
        _amount = bound(_amount, _MIN_SWAP_AMOUNT, bal);

        amm.swapAforB(_amount);
    }

    /// @notice Swaps tokenB for tokenA on behalf of a selected actor.
    /// @param _actorSeed Seed used to select the acting address.
    /// @param _amount    Requested amount of tokenB to swap in; bounded to the actor's balance.
    function swapBforA(uint256 _actorSeed, uint256 _amount) public useActor(_actorSeed) {
        uint256 bal = tokenB.balanceOf(currentActor);
        if (bal == 0) return;
        _amount = bound(_amount, _MIN_SWAP_AMOUNT, bal);

        amm.swapBforA(_amount);
    }
}
