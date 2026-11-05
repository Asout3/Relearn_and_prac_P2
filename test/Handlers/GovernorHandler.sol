// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Governor} from "../../src/Governor.sol";
import {Asout3Token} from "../../src/ERC20.sol";

/// @title GovernorHandler
/// @notice Drives `Governor` through the full proposal lifecycle using a fixed pool of actors.
/// @dev Every action is guarded so out-of-order calls become no-ops rather than reverts,
///      letting the fuzzer explore arbitrary call sequences safely.
contract GovernorHandler is Test {
    Governor gov;
    Asout3Token token;

    uint256[] public ids;
    address[] public actors;
    address internal currentActor;
    uint256 public successfulExecutions = 0;
    uint256 public constant TIMELOCK_DELAY = 172800;
    uint256 public constant VOTING_PERIOD = 259200;
    uint256 public constant MAX_TIME_JUMP = (VOTING_PERIOD + TIMELOCK_DELAY) * 3;

    /// @notice Deploys the handler and seeds it with 8 deterministic actors.
    /// @param _governor Governor contract the handler will drive.
    /// @param _token Token used to grant actors voting power.
    constructor(Governor _governor, Asout3Token _token) {
        gov = _governor;
        token = _token;

        for (uint256 i = 0; i < 8; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            actors.push(actor);
        }
    }

    /// @notice Selects an actor from `actors` and pranks as them for the body.
    /// @param _actorSeed Seed used to derive the actor index via `bound`.
    modifier useActor(uint256 _actorSeed) {
        currentActor = actors[bound(_actorSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    /// @notice Creates a new proposal on behalf of a randomly selected actor.
    /// @dev Returns early if the selected actor has zero voting power.
    /// @param _actorSeed Seed used to select the proposing actor.
    function propose(uint256 _actorSeed) public useActor(_actorSeed) {
        if (token.balanceOf(currentActor) == 0) return;
        gov.propose(address(0x1234), "adfadfad", "freedom and privacy");
        ids.push(gov.currentID());
    }

    /// @notice Casts a vote on an existing proposal on behalf of a randomly selected actor.
    /// @dev No-ops if the actor has no balance, there are no proposals, the proposal is not
    ///      `Active`, or the actor has already voted.
    /// @param _proposalId Seed bounded to the range of known proposal IDs.
    /// @param _actorSeed Seed used to select the voting actor.
    /// @param _supportSeed Vote direction (`true` = for, `false` = against).
    function castVote(uint256 _proposalId, uint256 _actorSeed, bool _supportSeed) public useActor(_actorSeed) {
        if (token.balanceOf(currentActor) == 0) return;
        if (ids.length == 0) return;
        uint256 index = bound(_proposalId, 0, ids.length - 1);
        uint256 actualId = ids[index];
        if (gov.state(actualId) != Governor.ProposalState.Active) return;
        if (gov.hasVoted(actualId, currentActor)) return;

        gov.vote(actualId, _supportSeed);
    }

    /// @notice Advances time past the governor's queue delay for a `Queued` proposal.
    /// @dev Only warps when the selected proposal is `Queued`; the jump is bounded to at least
    ///      `172800` seconds.
    /// @param _proposalId Seed bounded to a valid index into `ids`.
    /// @param _timeSeed Seed for the time jump, bounded to `[172800, type(uint256).max]`.
    function queueProposal(uint256 _proposalId, uint256 _timeSeed) public {
        if (ids.length == 0) return;
        uint256 index = bound(_proposalId, 0, ids.length - 1);
        uint256 actualId = ids[index];
        if (gov.state(actualId) != Governor.ProposalState.Queued) return;
        _timeSeed = bound(_timeSeed, TIMELOCK_DELAY, TIMELOCK_DELAY * 10);

        vm.warp(block.timestamp + _timeSeed);
    }

    /// @notice Executes a proposal that has reached the `Succeeded` state.
    /// @dev No-ops if the proposal is already `Executed` or not `Succeeded`.
    /// @param _proposalId Seed bounded to a valid index into `ids`.
    function executeProposal(uint256 _proposalId) public {
        if (ids.length == 0) return;
        uint256 index = bound(_proposalId, 0, ids.length - 1);
        uint256 actualId = ids[index];
        if (gov.state(actualId) == Governor.ProposalState.Executed) return;
        if (gov.state(actualId) != Governor.ProposalState.Succeeded) return;

        gov.execute(actualId);
    }

    /// @notice Warps `block.timestamp` forward by a bounded amount.
    /// @param _timeSeed Seed bounded to `[0, MAX_TIME_JUMP]` to keep jumps realistic.
    function warpTime(uint256 _timeSeed) public {
        _timeSeed = bound(_timeSeed, 0, MAX_TIME_JUMP);
        vm.warp(block.timestamp + _timeSeed);
    }

    function getArrayLength() public view returns (uint256) {
        return ids.length;
    }
}
