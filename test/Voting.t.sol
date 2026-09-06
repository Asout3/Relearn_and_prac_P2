// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Voting} from "../src/Voting.sol";

/// @dev This dummy contract acts as a non-owner voter proxy..
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

    /*//////////////////////////////////////////////////////////////
    //                       activateVoting                      //
    //////////////////////////////////////////////////////////////*/

    /// @dev The reason i put then in uint8() while asserting is because of this reason:
    /// @dev reason: When you pass two enum values directly to assertEq(), the compiler may fail to resolve which overload to use, or it may implicitly convert in unexpected ways.
    /// @dev The solution is to use uint8() cast works because:
    /// @dev 1. Enums with ≤256 members fit in uint8
    /// @dev 2. assertEq(uint8, uint8) unambiguously resolves to the uint256 overload (since uint8 promotes to uint256)
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

    /*//////////////////////////////////////////////////////////////
    //                       closeTheVoting                       //
    //////////////////////////////////////////////////////////////*/
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

    /*//////////////////////////////////////////////////////////////
    //                        voteYes                             //
    //////////////////////////////////////////////////////////////*/
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

    function test_voteYes_reverts_when_same_address_votes_twice() public {
        voting.activateVoting();
        voting.voteYes();

        vm.expectRevert(Voting.AlreadyVoted.selector);
        voting.voteYes();
    }

    function test_voteYes_allows_different_addresses_to_vote() public {
        DummyNonOwner dummy = new DummyNonOwner(voting);

        voting.activateVoting();
        voting.voteYes();
        dummy.callVoteYes();

        assertEq(voting.seeYesVotes(), 2);
    }

    /*//////////////////////////////////////////////////////////////
    //                         voteNo                             //
    //////////////////////////////////////////////////////////////*/
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

    function test_voteNo_reverts_when_same_address_votes_twice() public {
        voting.activateVoting();
        voting.voteNo();

        vm.expectRevert(Voting.AlreadyVoted.selector);
        voting.voteNo();
    }

    function test_voteNo_allows_different_addresses_to_vote() public {
        DummyNonOwner dummy = new DummyNonOwner(voting);

        voting.activateVoting();
        voting.voteNo();
        dummy.callVoteNo();

        assertEq(voting.seeNoVotes(), 2);
    }

    /*//////////////////////////////////////////////////////////////
    //                       seeYesVotes                         //
    //////////////////////////////////////////////////////////////*/
    function test_seeYesVotes() public {
        assertEq(voting.seeYesVotes(), 0);
        voting.activateVoting();
        voting.voteYes();
        assertEq(voting.seeYesVotes(), 1);
    }

    /*//////////////////////////////////////////////////////////////
    //                       seeNoVotes                           //
    //////////////////////////////////////////////////////////////*/
    function test_seeNoVotes() public {
        assertEq(voting.seeNoVotes(), 0);
        voting.activateVoting();
        voting.voteNo();
        assertEq(voting.seeNoVotes(), 1);
    }

    /*//////////////////////////////////////////////////////////////
    //                          seeWinner                         //
    //////////////////////////////////////////////////////////////*/
    function test_seeWinner() public {
        voting.activateVoting();
        voting.voteYes();
        voting.closeTheVote();

        string memory see = voting.seeWinner();
        assertEq(see, "yes won");
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

    function test_seeWinner_reverts_while_voting_is_active() public {
        voting.activateVoting();
        voting.voteYes();

        vm.expectRevert(Voting.NotClosedYet.selector);
        voting.seeWinner();
    }

    function test_seeWinner_when_no_one_votes() public {
        voting.activateVoting();
        voting.closeTheVote();
        string memory see = voting.seeWinner();
        assertEq(see, "its a tie");
    }
}

