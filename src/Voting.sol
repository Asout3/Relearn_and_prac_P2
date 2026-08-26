// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @custom:info I refactored this code by improving its documentation and by following solidity best practices.
/// @custom:info You can find the original contract in this link: https://github.com/Asout3/Relearn_and_prac/blob/main/src/TheVotingSystem.sol

/// @title The Voting contract .
/// @author Mikiyas Yimer.
/// @notice It is here only for to be refactored and tested. Don't push this code to production.
/// @dev Don't push this code to production.
/// @custom:experimental This is an experimental contract.
contract Voting {
    /// @notice This struct is used for the declaration of the name and description for the proposal.
    struct Proposal {
        string name;
        string description;
    }

    /// @dev This enum is used for the states of voting.
    enum Status {
        Pending,
        Active,
        Closed
    }

    /// @notice proposal is the declaration of Proposal struct.
    Proposal proposal;
    /// @notice status is the declaration of Status enum.
    Status status;

    /// @notice _owner is the address of the owner.
    address private _owner;
    /// @notice _yesVotes are the number of yes votes.
    uint256 _yesVotes;
    /// @notice _noVotes are the number of no votes.
    uint256 _noVotes;
    /// @notice _hasVoted is mapping which is used for checking if the voter has voted.
    mapping(address => bool) internal _hasVoted;

    event VotedYes(address indexed user);
    event VotedNo(address indexed user);
    event VoteActivated();
    event VoteCancled();

    error AlreadyVoted();
    error NotActive();
    error NotInPendingStage();
    error NotInActiveStage();
    error NotOwner();
    error NotClosedYet();

    modifier onlyOwner() {
        if (_owner != msg.sender) revert NotOwner();
        _;
    }

    /// @notice this is the constructor and in it we set up the proposal name, proposal description and the owner.
    constructor() {
        proposal.name = "Should we add pool in the house?";
        proposal.description = "should we add a swiming pool to the new house that we are building.";
        _owner = msg.sender;
    }

    /// @notice This function activates the voting and only can be called by the owner.
    /// @dev It activates the vote by updating the enum and then emits an event.
    function activateVoting() external onlyOwner {
        if (status != Status.Pending) revert NotInPendingStage();

        status = Status.Active;
        emit VoteActivated();
    }

    /// @notice This function closes the voting and only can be called by the owner.
    /// @dev It closes the voting by updating the enum and then emits an event.
    function closeTheVote() external onlyOwner {
        if (status != Status.Active) revert NotInActiveStage();

        status = Status.Closed;
        emit VoteCancled();
    }

    /// @notice This is Yes voting function.
    /// @dev It increments the yesVote variable and update the hasVoted mapping then emits an event.
    function voteYes() external {
        if (status != Status.Active) revert NotActive();
        if (_hasVoted[msg.sender] == true) revert AlreadyVoted();

        _yesVotes++;
        _hasVoted[msg.sender] = true;
        emit VotedYes(msg.sender);
    }

    /// @notice This is No voting function.
    /// @dev It increments the noVote variable and update the hasVoted mapping then emits an event.
    function voteNo() external {
        if (status != Status.Active) revert NotActive();
        if (_hasVoted[msg.sender] == true) revert AlreadyVoted();

        _noVotes++;
        _hasVoted[msg.sender] = true;
        emit VotedNo(msg.sender);
    }

    /// @notice This function is used to see the yes vote count.
    /// @return yes votes.
    function seeYesVotes() external view returns (uint256) {
        return _yesVotes;
    }

    /// @notice This function is used to see the no vote count.
    /// @return The total count of yes votes.
    function seeNoVotes() external view returns (uint256) {
        return _noVotes;
    }

    /// @notice This function tells us who the winner is or if it is a tie.
    /// @return A string indicating the result: "yes won", "its a tie", or "no won".
    function seeWinner() external view returns (string memory) {
        if (status != Status.Closed) revert NotClosedYet();

        if (_yesVotes > _noVotes) {
            return "yes won";
        } else if (_yesVotes == _noVotes) {
            return "its a tie";
        } else {
            return "no won";
        }
    }
}
