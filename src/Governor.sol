// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/*

   ____
  / ___| _____   _____ _ __ _ __   ___  _ __
 | |  _ / _ \ \ / / _ \ '__| '_ \ / _ \| '__|
 | |_| | (_) \ V /  __/ |  | | | | (_) | |
  \____|\___/ \_/ \___|_|  |_| |_|\___/|_|


*/

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @notice This contract is taken from the phase one of relearn solidity
///         and modified the contract to make follow best practice the core
///         logic did not change only the solidity best practice. You can
///         find the original code at this link:
///         https://github.com/Asout3/Relearn_and_prac/blob/main/src/Governor.sol
///         This contract is not gas optmized and also have bugs so never use
///         this contract in production.

/// @title Governor
/// @author Mikiyas Y.
/// @notice A simple governance contract for creating and voting on proposals.
/// @dev Voting power is based on the caller's ERC20 token balance.
contract Governor {
    /// @notice A governance proposal.
    /// @param id Unique proposal ID.
    /// @param proposer Address that created the proposal.
    /// @param target Contract to call if the proposal executes.
    /// @param callData Calldata to send to `target`.
    /// @param description Short proposal description.
    /// @param votesFor Total votes in favor.
    /// @param votesAgainst Total votes against.
    /// @param startTime Voting start timestamp.
    /// @param endTime Voting end timestamp.
    /// @param executed Whether the proposal has been executed.
    struct Proposal {
        uint256 id;
        address proposer;
        address target;
        bytes callData;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }

    /// @notice Possible states for a proposal.
    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Queued,
        Executed
    }

    /// @notice ERC20 token used for voting power.
    address public immutable TOKEN;

    /// @notice ID for the next proposal.
    uint256 public currentID = 1;

    /// @notice Voting period in seconds (3 days).
    uint256 public constant VOTING_PERIOD = 259200;

    /// @notice Timelock delay in seconds (2 days).
    uint256 public constant TIMELOCK_DELAY = 172800;

    /// @notice Minimum total votes required for a proposal to succeed.
    uint256 public constant QUORUM = 100e18;

    /// @notice Maximum allowed proposal description length.
    uint256 public constant MAX_DESCRIPTION_LENGTH = 512;

    /// @notice Proposal data by proposal ID.
    mapping(uint256 => Proposal) public proposals;

    /// @notice Whether an address has voted on a given proposal.
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @notice Emitted when a new proposal is created.
    /// @param target Contract to call if the proposal executes.
    /// @param callData Calldata to send to `target`.
    /// @param description Proposal description.
    event ProposalCreated(address indexed target, bytes callData, string description);

    /// @notice Thrown when an address tries to vote twice on the same proposal.
    error AlreadyVoted();

    /// @notice Thrown when voting is not active for a proposal.
    error VotingNotActive();

    /// @notice Thrown when a proposal cannot be executed because it did not succeed.
    error ProposalNotSuccessful();

    /// @notice Sets the voting token address.
    /// @param _address ERC20 token used for voting power.
    constructor(address _address) {
        TOKEN = _address;
    }

    /// @notice Creates a new proposal.
    /// @dev Checks proposer token balance, zero target, and description length before writing state.
    /// @param target Contract to call if the proposal executes.
    /// @param callData Calldata to send to `target`.
    /// @param description Short proposal description.
    function propose(address target, bytes calldata callData, string calldata description) external {
        require(IERC20(TOKEN).balanceOf(msg.sender) > 0, "You don't have enough power to propose");
        require(target != address(0), "zero address contract is not allowed");
        require(bytes(description).length <= MAX_DESCRIPTION_LENGTH, "too much wtf make it short");

        uint256 startingTime = block.timestamp;
        uint256 endingTime = block.timestamp + VOTING_PERIOD;

        proposals[currentID] = Proposal({
            id: currentID,
            proposer: msg.sender,
            target: target,
            callData: callData,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            startTime: startingTime,
            endTime: endingTime,
            executed: false
        });
        currentID++;

        emit ProposalCreated(target, callData, description);
    }

    /// @notice Votes on an active proposal.
    /// @dev Voting weight is the caller's current ERC20 token balance.
    /// @param proposalId ID of the proposal.
    /// @param support True to vote for, false to vote against.
    function vote(uint256 proposalId, bool support) external {
        require(IERC20(TOKEN).balanceOf(msg.sender) > 0, "You don't have enough power to vote");
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();
        if (state(proposalId) != ProposalState.Active) revert VotingNotActive();

        uint256 weight = IERC20(TOKEN).balanceOf(msg.sender);

        if (support) {
            proposals[proposalId].votesFor += weight;
        } else {
            proposals[proposalId].votesAgainst += weight;
        }

        hasVoted[proposalId][msg.sender] = true;
    }

    /// @notice Executes a succeeded proposal.
    /// @dev Timelock check is currently commented out in this version.
    /// @param proposalId ID of the proposal to execute.
    function execute(uint256 proposalId) external {
        if (state(proposalId) != ProposalState.Succeeded) revert ProposalNotSuccessful();
        require(!proposals[proposalId].executed, "its already executed");

        Proposal storage p = proposals[proposalId];

        proposals[proposalId].executed = true;

        (bool success,) = p.target.call(p.callData);
        require(success, "failed executing");
    }

    /// @notice Returns the current state of a proposal.
    /// @param proposalId ID of the proposal.
    /// @return Current state of the proposal.
    /// @custom:issues This function uses block timestamp to compare which can be
    ///                manupliated so it is known issue and accept risk for this exercise.
    function state(uint256 proposalId) public view returns (ProposalState) {
        if (proposals[proposalId].executed) {
            return ProposalState.Executed;
        } else if (block.timestamp < proposals[proposalId].endTime) {
            return ProposalState.Active;
        } else if (proposals[proposalId].votesFor + proposals[proposalId].votesAgainst < QUORUM) {
            return ProposalState.Defeated;
        } else if (proposals[proposalId].votesFor > proposals[proposalId].votesAgainst) {
            if (block.timestamp < proposals[proposalId].endTime + TIMELOCK_DELAY) {
                return ProposalState.Queued;
            }

            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }
}
