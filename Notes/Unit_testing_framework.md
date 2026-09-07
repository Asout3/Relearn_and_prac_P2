
TESTING A CONTRACT (Foundry)
│
├── 0. BEFORE WRITING ANY TEST (enumerate on paper)
│     ├── STATES the contract can be in
│     ├── FUNCTIONS + what state each touches
│     ├── ACTORS (who can call what?)
│     ├── EXTERNAL DEPS (tokens, oracles, other protocols)
│     └── INVARIANTS in plain English ("vault always solvent", "shares add up")
│
├── 1. UNIT TESTS — per function
│     ├── Happy path
│     │     ├── state BEFORE vs AFTER
│     │     ├── return value
│     │     ├── events emitted (with correct data!)
│     │     └── balances actually moved (tokens in/out)
│     ├── Revert tests — EVERY branch
│     │     ├── access control (per actor)
│     │     ├── input validation (0, empty, max)
│     │     ├── state validation (wrong state for this call)
│     │     └── external call failures
│     └── Boundaries: 0, 1, max, exactly-at-the-limit
│
├── 2. STATE MACHINE MATRIX
│     ├── grid: state × function → every legal transition = test
│     └── every ILLEGAL transition = revert test


CONTRACT: MiniVault

ACTORS:
- bob:   owner, has 1000e18 tokens
- alice: depositor, has 1000e18 tokens
- eve:   no tokens, no shares (the "empty actor")
.
.

IMPLICIT STATES (no enum, but they exist!):
- EMPTY:        totalShares == 0
- FUNDED:       totalShares > 0
- FUNDED+PROFIT: vault balance > what depositors put in

FUNCTION INVENTORY + BRANCHES:

deposit(assets):
  b1: assets == 0              → revert ZeroAmount
  b2: totalShares == 0         → 1:1 mint (first depositor)
  b3: totalShares > 0          → proportional mint, ROUNDS DOWN
  b4: approval missing         → external call fails
  writes: shares, totalShares, token balances
  emits:  Deposit
  returns: sharesOut

withdraw(sharesIn):
  b1: sharesIn == 0            → revert ZeroAmount
  b2: sharesIn > user shares   → revert InsufficientShares
  b3: partial withdrawal       → happy
  b4: sharesIn == user shares  → boundary (full withdrawal)
  b5: last withdrawer          → vault returns to EMPTY state
  writes/emits/returns: ...

INVARIANTS (English):
  I1: vault's token balance >= what shareholders are collectively owed
  I2: sum of all user shares == totalShares
  I3: share price only moves because of real gains (no free mint)
  I4: nobody can withdraw more than their share


MAKE SURE YOU TAKE A MINUTE OR TWO TO FOCUS AND TRY TO FIND EDGE CASE WHILE TESTING LIKE TRY TO FIND THE EDGE CASE OKAY.


Definition of done for the unit phase
- [] Every external/public function: ≥1 happy test
- []  Every branch covered — branch %, not line %
- []  Every revert: tested, exact selector
- []  Every event: tested, with correct data
- []  Every numeric input: 0, 1, max, exact limit, limit±1
- []  Every actor × restricted function combination (the access matrix: eve calls everything)
- []  View functions return correct values in constructed states
- []  Every state transition exercised, including back-to-empty
- []  No test depends on another test's execution
- []  All expected values computed independently (no formula mirroring)












1. STATES the contract can be in:-
      
      1.1 Explicit:-
      - Pending
      - Active 
      - Closed
      
      1.2 IMPLICIT STATES:-
      - hasVoted
      - NotVoted
      - yes won
      - no won
      - its a tie

2. FUNCTIONS + what state each touches:-
      
      2.1 activateVoting():-
            b1: owner != msg.sender  =>  revert NotOwner.
            b2: status == status.Pending  =>  pass.
            b3: status == status.Active  => revert  NotInPendingStage.
            b4: status == status.Closed  => revert  NotInPendingStage.
            
            updates status to status.Active.
            emits an event  => VoteActivated.

      2.2 closeTheVote():-
            b1: owner != msg.sender  =>  revert NotOwner.
            b2: status == Status.Active  =>  pass 
            b3: status == status.Pending  => revert NotInActiveStage.
            b4: status == status.Closed  => revert NotInActiveStage.

            updates status to status.Closed
            emits an event  => VoteCancelled.

      2.3 voteYes():-
            b1: status == status.Active  => pass
            b2: status == status.Pending  => revert NotActive.
            b3: status == status.Closed  => revert NotActive.
            b4: _hasVoted[msg.sender] == true  => revert AlreadyVoted.
            b5: _hasVoted[msg.sender] == false  => pass.
            increment yesVotes.
            update _hasVoted.
            emits an event => VotedYes.
      2.3 voteNo():-
            b1: status == status.Active  => pass
            b2: status == status.Pending  => revert NotActive.
            b3: status == status.Closed  => revert NotActive.
            b4: _hasVoted[msg.sender] == true  => revert AlreadyVoted.
            b5: _hasVoted[msg.sender] == false  => pass.
            increment noVotes.
            update _hasVoted.
            emits an event => VotedNo.
      2.4 seeYesVotes():-
            returns  =>  yesVotes.
      2.5 seeNoVotes():-
            returns  =>  noVotes.
      2.6 seeWinner():-
            b1: status == status.Active  => revert NotClosedYet.
            b2: status == status.Pending  => revert NotClosedYet.
            b3: status == status.Closed  => pass.
            b4: _yesVotes > _noVotes  =>  return "yes Won".
            b5: _yesVotes == _noVotes  => returns "its a tie".
            b6: _yesVotes < _noVotes  =>  returns "no won"
            returns strings.
3. INVARIANTS (English):-
      I1: Only owner can update the explicit states
      I2: No one can't proceed(vote) unless the explicit states allows you.
4. Actors:-
      owner: have some privileges.
      dummyNonOwner: non owner and voter.
