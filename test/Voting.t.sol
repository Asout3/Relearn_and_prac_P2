// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Voting} from "../src/Voting.sol";

contract DummyNonOwner {
    Voting public voting;

    constructor(Voting votingaddr) {
        voting = votingaddr;
    }

    function callActivateVoting() public {
        voting.activateVoting();
    }

    function callCloseTheVote() public {
        voting.closeTheVote();
    }

    function callVoteYes() public {
        voting.voteYes();
    }

    function callVoteNo() public {
        voting.voteNo();
    }
}

contract VotingTest is Test {
    Voting voting;

    function setUp() public {
        voting = new Voting();
    }

    function test_activateVoting() public {
        voting.activateVoting();
        assertEq(uint8(voting.getStatus()), uint8(Voting.Status.Active));
    }

    function test_revert_activateVoting_with_non_owner() public {
        DummyNonOwner dummy = new DummyNonOwner(voting);

        vm.expectRevert(Voting.NotOwner.selector);
        dummy.callActivateVoting();
    }

    function test_revert_activateVoting_on_wrong_status() public {
        voting.activateVoting();

        vm.expectRevert(Voting.NotInPendingStage.selector);
        voting.activateVoting();

        voting.closeTheVote();

        vm.expectRevert(Voting.NotInPendingStage.selector);
        voting.activateVoting();
    }

    function test_closeTheVote() public {
        voting.activateVoting();

        voting.closeTheVote();
        assertEq(uint8(voting.getStatus()), uint8(Voting.Status.Closed));
    }

    function test_revert_closeTheVote_with_non_owner() public {
        DummyNonOwner dummy = new DummyNonOwner(voting);

        voting.activateVoting();

        vm.expectRevert(Voting.NotOwner.selector);
        dummy.callCloseTheVote();
    }

    function test_revert_closeTheVote_on_wrong_status() public {
        vm.expectRevert(Voting.NotInActiveStage.selector);
        voting.closeTheVote();
    }

    function test_voteYes() public {
        voting.activateVoting();
        voting.voteYes();

        assertEq(voting.seeYesVotes(), 1);
    }

    function test_voteYes_reverts_when_not_active() public {
        vm.expectRevert(Voting.NotActive.selector);
        voting.voteYes();
    }

    function test_voteYes_reverts_after_voting_closed() public {
        voting.activateVoting();
        voting.voteYes();

        voting.closeTheVote();
        vm.expectRevert(Voting.NotActive.selector);
        voting.voteYes();
    }

    function test_voteYes_reverts_on_voting_more_than_once() public {
        DummyNonOwner dummy = new DummyNonOwner(voting);

        voting.activateVoting();
        voting.voteYes();

        vm.expectRevert(Voting.AlreadyVoted.selector);
        voting.voteYes();

        dummy.callVoteYes();
        vm.expectRevert(Voting.AlreadyVoted.selector);
        dummy.callVoteYes();
    }

    function test_voteNo() public {
        voting.activateVoting();
        voting.voteNo();

        assertEq(voting.seeNoVotes(), 1);
    }

    function test_voteNo_reverts_when_not_active() public {
        vm.expectRevert(Voting.NotActive.selector);
        voting.voteNo();
    }

    function test_voteNo_reverts_after_voting_closed() public {
        voting.activateVoting();
        voting.voteNo();

        voting.closeTheVote();
        vm.expectRevert(Voting.NotActive.selector);
        voting.voteNo();
    }

    function test_voteNo_reverts_on_voting_more_than_once() public {
        DummyNonOwner dummy = new DummyNonOwner(voting);

        voting.activateVoting();
        voting.voteNo();

        vm.expectRevert(Voting.AlreadyVoted.selector);
        voting.voteNo();

        dummy.callVoteNo();
        vm.expectRevert(Voting.AlreadyVoted.selector);
        dummy.callVoteNo();
    }

    function test_seeYesVotes() public {
        assertEq(voting.seeYesVotes(), 0);
        voting.activateVoting();
        voting.voteYes();
        assertEq(voting.seeYesVotes(), 1);
    }

    function test_seeNoVotes() public {
        assertEq(voting.seeNoVotes(), 0);
        voting.activateVoting();
        voting.voteNo();
        assertEq(voting.seeNoVotes(), 1);
    }

    function test_seeWinner() public {
        voting.activateVoting();
        voting.voteYes();
        voting.closeTheVote();

        string memory see = voting.seeWinner();
        assertEq(see, "yes won");
    }

    function test_seeWinner_reverts_while_voting_is_active() public {
        voting.activateVoting();
        voting.voteYes();

        vm.expectRevert(Voting.NotClosedYet.selector);
        voting.seeWinner();
    }

    function test_seeWinner_check_tie() public {
        DummyNonOwner dummy = new DummyNonOwner(voting);

        voting.activateVoting();
        voting.voteYes();
        dummy.callVoteNo();
        voting.closeTheVote();

        string memory see = voting.seeWinner();
        assertEq(see, "its a tie");
    }

    function test_seeWinner_check_for_No_wins() public {
        DummyNonOwner dummy = new DummyNonOwner(voting);

        voting.activateVoting();
        voting.voteNo();
        dummy.callVoteNo();
        voting.closeTheVote();

        string memory see = voting.seeWinner();
        assertEq(see, "no won");
    }
}
