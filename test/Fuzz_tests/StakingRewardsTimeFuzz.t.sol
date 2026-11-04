// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice The natSpec(doc) is written by an AI(deepseek v4.1 flash).

import {Test, console2} from "forge-std/Test.sol";
import {StakingRewards, RewardToken, IAsout3Token} from "../../src/StakingRewards.sol";

/// @title StakingRewardsTimeFuzz
/// @notice Fuzz test suite for `StakingRewards` focused on time manipulation
///         and reward-accounting invariants (e.g. total earned never exceeds
///         the notified reward amount, rewards stop accruing at `periodFinish`).
contract StakingRewardsTimeFuzz is Test {
    StakingRewards stakingReward;
    RewardToken rewardToken;
    IAsout3Token stakingToken;
    RewardToken mockStakingToken;

    address stakerA;
    address stakerB;

    uint256 constant REWARD_AMOUNT = 1000 ether;

    /// @notice Deploys the staking and reward contracts, mints staking tokens to
    ///         both stakers, and seeds the reward pool with `REWARD_AMOUNT`.
    function setUp() public {
        mockStakingToken = new RewardToken("Stake Token", "STK", 18, 0);
        stakingToken = IAsout3Token(address(mockStakingToken));
        stakingReward = new StakingRewards(address(stakingToken));
        rewardToken = stakingReward.rewardToken();

        stakerA = makeAddr("stakerA");
        stakerB = makeAddr("stakerB");

        stakingToken.mint(1_100_000 ether, stakerA);
        stakingToken.mint(5_000 ether, stakerB);

        stakingReward.notifyReward(REWARD_AMOUNT);
    }

    /// @notice A single staker's earned rewards must never exceed the notified reward amount,
    ///         regardless of stake size or warp duration.
    /// @param _stakeAmount Amount of staking tokens staked by stakerA.
    /// @param _warpDuration Time in seconds to warp after staking.
    function testFuzz_singleStakerEarnedNeverExceedsNotified(uint256 _stakeAmount, uint256 _warpDuration) public {
        _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
        _warpDuration = bound(_warpDuration, 0, 2 * stakingReward.SEVEN_DAYS());

        vm.startPrank(stakerA);
        mockStakingToken.approve(address(stakingReward), type(uint256).max);
        stakingReward.stake(_stakeAmount);
        vm.stopPrank();
        vm.warp(block.timestamp + _warpDuration);

        assertLe(stakingReward.earned(stakerA), REWARD_AMOUNT);
    }

    /// @notice Two stakers' combined earned rewards must never exceed the notified reward amount.
    /// @dev Regression test for an underflow bug caused by `lastUpdateTime = block.timestamp`
    ///      inside `updateReward()`. Because `block.timestamp` keeps growing past
    ///      `periodFinish`, the expression `lastTimeRewardApplicable() - lastUpdateTime`
    ///      turns negative and reverts with panic 0x11. The contract is fixed by assigning
    ///      `lastUpdateTime = lastTimeRewardApplicable()`, which clamps it to `periodFinish`.
    /// @param _stakeAmountA Amount staked by stakerA.
    /// @param _stakeAmountB Amount staked by stakerB.
    /// @param _warpBeforeB Time warped between stakerA's and stakerB's stake.
    /// @param _warpAfterB Time warped after stakerB's stake.
    function testFuzz_twoStakersTotalEarnedNeverExceedsNotified(
        uint256 _stakeAmountA,
        uint256 _stakeAmountB,
        uint256 _warpBeforeB,
        uint256 _warpAfterB
    ) public {
        _stakeAmountA = bound(_stakeAmountA, 1e18, 1_000_000e18);
        _stakeAmountB = bound(_stakeAmountB, 1e18, 5_00e18);
        _warpBeforeB = bound(_warpBeforeB, 0, 2 * stakingReward.SEVEN_DAYS());
        _warpAfterB = bound(_warpAfterB, 0, 2 * stakingReward.SEVEN_DAYS());

        vm.startPrank(stakerA);
        mockStakingToken.approve(address(stakingReward), type(uint256).max);
        stakingReward.stake(_stakeAmountA);
        vm.stopPrank();
        vm.warp(block.timestamp + _warpBeforeB);

        vm.startPrank(stakerB);
        mockStakingToken.approve(address(stakingReward), type(uint256).max);
        stakingReward.stake(_stakeAmountB);
        vm.stopPrank();
        vm.warp(block.timestamp + _warpAfterB);

        uint256 totalEarned = stakingReward.earned(stakerA) + stakingReward.earned(stakerB);

        assertLe(totalEarned, REWARD_AMOUNT);
    }

    /// @notice Earned rewards must not accrue past `periodFinish`; earned after the period
    ///         equals `rewardRate * SEVEN_DAYS` within a relative rounding tolerance.
    /// @param _stakeAmount Amount of staking tokens staked by stakerA.
    /// @param _extraTimePastFinish Additional time warped past `periodFinish`.
    function testFuzz_warpPastPeriodFinishCapsRewards(uint256 _stakeAmount, uint256 _extraTimePastFinish) public {
        _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000 ether);
        _extraTimePastFinish = bound(_extraTimePastFinish, 0, stakingReward.SEVEN_DAYS());

        vm.startPrank(stakerA);
        mockStakingToken.approve(address(stakingReward), type(uint256).max);
        stakingReward.stake(_stakeAmount);
        vm.stopPrank();
        vm.warp(stakingReward.periodFinish() + _extraTimePastFinish);

        assertApproxEqRel(stakingReward.earned(stakerA), stakingReward.rewardRate() * stakingReward.SEVEN_DAYS(), 1e12);
    }

    /// @notice Staking, unstaking, then re-staking must never cause earned rewards to exceed
    ///         the notified reward amount at any checkpoint.
    /// @param _stakeAmount1 Initial amount staked.
    /// @param _warp1 Time warped after the first stake.
    /// @param _unstakeFraction Amount unstaked (bounded to the initial staked amount).
    /// @param _warp2 Time warped after unstaking.
    /// @param _restakeAmount Amount re-staked.
    function testFuzz_stakeUnstakeRestakeEarnedNeverExceedsNotified(
        uint256 _stakeAmount1,
        uint256 _warp1,
        uint256 _unstakeFraction,
        uint256 _warp2,
        uint256 _restakeAmount
    ) public {
        _stakeAmount1 = bound(_stakeAmount1, 1e18, 7_00_000 ether);
        _warp1 = bound(_warp1, 0, 2 * stakingReward.SEVEN_DAYS());
        _unstakeFraction = bound(_unstakeFraction, 1e18, _stakeAmount1);
        _warp2 = bound(_warp2, 0, stakingReward.SEVEN_DAYS());
        _restakeAmount = bound(_restakeAmount, 1e18, 3_00_000 ether);

        vm.startPrank(stakerA);
        mockStakingToken.approve(address(stakingReward), type(uint256).max);
        stakingReward.stake(_stakeAmount1);
        vm.stopPrank();

        vm.warp(block.timestamp + _warp1);

        assertLe(stakingReward.earned(stakerA), REWARD_AMOUNT);

        vm.prank(stakerA);
        stakingReward.unstake(_unstakeFraction);

        vm.warp(block.timestamp + _warp2);

        assertLe(stakingReward.earned(stakerA), REWARD_AMOUNT);

        vm.startPrank(stakerA);
        stakingReward.stake(_restakeAmount);

        assertLe(stakingReward.earned(stakerA), REWARD_AMOUNT);
    }
}
