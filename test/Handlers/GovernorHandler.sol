// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test, console2} from "forge-std/Test.sol";
import {Governor} from "../../src/Governor.sol";
import {Asout3Token} from "../../src/ERC20.sol";

contract GovernorHandler is Test {
    Governor gov;
    Asout3Token token;

    uint256[] public ids;
    address[] public actors;
    address internal currentActor;

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

    function propose(uint256 _actorSeed) public useActor(_actorSeed) {
        if (token.balanceOf(currentActor) == 0) return;
        gov.propose(address(0x1234), "adfadfad", "freedom and privacy");
        ids.push(gov.currentID());
    }

    function castVote(uint256 _proposalId, uint256 _actorSeed, bool _supportSeed) public useActor(_actorSeed) {
        if (token.balanceOf(currentActor) == 0) return;
        if (ids.length == 0) return;
        _proposalId = bound(_proposalId, 0, ids.length - 1);
        if (gov.state(_proposalId) != Governor.ProposalState.Active) return;
        if (gov.hasVoted(_proposalId, currentActor)) return;

        gov.vote(_proposalId, _supportSeed);
    }

    function queueProposal(uint256 _proposalId, uint256 _timeSeed) public {
        if (ids.length == 0) return;
        _proposalId = bound(_proposalId, 0, ids.length - 1);
        if (gov.state(_proposalId) != Governor.ProposalState.Queued) return;
        _timeSeed = bound(_timeSeed, 172800, type(uint256).max);

        vm.warp(_timeSeed);
    }
}
