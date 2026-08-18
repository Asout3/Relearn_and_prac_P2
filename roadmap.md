# Phase 2 — Verification & Systems Engineering
### Testing · Scripting · Deep Gas/EVM · From-Scratch Architecture
 
**Context for reviewer:** This is phase two of a self-directed Solidity relearning program. Phase one (20 exercises, 4 tiers — Foundations, Security Patterns, DeFi Mechanics, Gas/Advanced) is complete: vaults, staking, AMM, flash loans, governance, UUPS proxies, Merkle airdrops, EIP-712, and a DAO-hack case study, all written from spec without OpenZeppelin. Phase two closes the gap between "can implement a contract" and "can verify, ship, and defend one like a working engineer" — and is explicitly designed around a specific competitive thesis (below), not just "more exercises."
 
**Pace constraint:** 1–2 hrs/day, a few days a week. Realistic estimate ~12–14 weeks at that pace given the expanded scope.
 
---
 
## The Actual Thesis of This Phase
 
**Read this first — it's the reasoning behind every design choice below, not just a section to skip.**
 
AI can already write a working ERC20, a working staking contract, probably a passable AMM, and a decent first-pass unit test suite. That's not a hypothetical risk to plan around later — it's already true today. Pretending otherwise, or trying to out-type an AI at writing boilerplate Solidity, is a losing strategy. That's the honest starting point.
 
What AI is currently and structurally bad at:
 
1. **Designing something that hasn't been designed before.** AI is excellent at reproducing patterns with thousands of training examples — an ERC20, a Synthetix-style staking contract, a Uniswap V2 clone. It's fundamentally weaker at genuine mechanism design — a novel incentive structure, a new hook design, a lending market with a specific risk profile nobody's built exactly that way. This is *why* Tier F in this roadmap is not decoration — it's the actual center of gravity for this whole phase.
2. **Judging its own output under adversarial pressure.** AI-generated tests very often pass, and very often still miss the exact edge case a real attacker would find, because the AI is optimizing for "plausible test that compiles and passes," not "test written by someone who has personally been burned by a specific failure mode." The skill that survives this is being the *reviewer* — someone who can read AI-generated code or tests and find what's actually missing. This is why every testing tier below includes an explicit **"audit the AI"** exercise, not just "write tests yourself."
3. **Owning a decision under real consequences.** AI doesn't get paged at 3am when a contract gets drained. AI doesn't sit in a room and explain to a team why a specific timelock duration was chosen over another, and defend that choice against pushback. That accountability and judgment is not a feature AI has — it's a structurally human role in any real team, and it's exactly what a design doc, a written trade-off analysis, and a defended architectural decision demonstrate.
**The practical implication for how you should spend your limited time (1–2 hrs/day):** don't try to become faster than AI at typing Solidity. Become someone who (a) can use AI as leverage without being fooled by confidently wrong output, (b) can design systems AI has no training pattern for, and (c) can explain and defend the reasoning behind a decision under scrutiny. Everything below is built around that, not around "grinding more Solidity syntax."
 
---
 
## Module 0 — Solidity Craft & Production Norms
 
*(Read and internalize before Tier A. This is not exercises — it's the standard everything after this gets held to.)*
 
### Why this module exists
Across phase one, naming was inconsistent (`deposite`, `taksCount`, mismatched casing on errors/events), comments were often stream-of-consciousness rather than structured, and there was no fixed style discipline. That's normal for a first pass through 20 exercises — but phase two code should be written to a real standard from the start, not cleaned up after.
 
### 0.1 — Naming conventions (the official standard)
- **Contracts / structs / enums:** `PascalCase` — `StakingRewards`, `UserInfo`, `ProposalState`
- **Functions / variables / parameters:** `camelCase` — `depositAmount`, `getUserBalance()`
- **Constants / immutables:** `SCREAMING_SNAKE_CASE` — `MAX_SUPPLY`, `VOTING_PERIOD`
- **Private/internal state:** prefix with `_` — `_balances`, `_owner`
- **Function parameters (to avoid shadowing state vars):** prefix with `_` — `function transfer(address _to, uint256 _amount)`
- **Custom errors:** `PascalCase`, no `Error` suffix — `InsufficientBalance()`, not `InsufficientBalanceError()`
- **Events:** `PascalCase`, past tense — `Deposited`, `Withdrawn`, not `Deposit`, `DepositEvent`
- Read: **[Solidity Style Guide, official docs](https://docs.soliditylang.org/en/latest/style-guide.html)** — this is the canonical source, not a blog opinion.
### 0.2 — Commenting standard: NatSpec
Phase one comments were personal reasoning notes — valuable for learning, wrong for production. Real contracts use **NatSpec** (Ethereum Natural Language Specification), which tools like Etherscan, IDEs, and doc generators parse automatically.
 
```solidity
/// @title A simple vault for single-asset deposits
/// @notice Users deposit an ERC20 and receive proportional shares
/// @dev Share math follows the ERC4626 pattern; not fully compliant
contract Vault {
    /// @notice Deposits `assets` and mints shares to the caller
    /// @param assets The amount of the underlying token to deposit
    /// @return shares The amount of vault shares minted
    function deposit(uint256 assets) external returns (uint256 shares) { ... }
}
```
Read: **[NatSpec Format, official docs](https://docs.soliditylang.org/en/latest/natspec-format.html)**
 
**The rule going forward:** reasoning-while-learning comments are fine in a scratch/notes file, but the actual contract file gets NatSpec. Two different documents, two different audiences.
 
### 0.3 — Layout order (Solidity style guide convention)
Inside a contract, order should be: type declarations → state variables → events → errors → modifiers → constructor → receive/fallback → external → public → internal → private, with `view`/`pure` functions grouped after state-changing ones in each visibility group.
 
### 0.4 — Where real protocols actually differ from tutorials
- **Checks-Effects-Interactions is necessary but not sufficient** — real protocols add `ReentrancyGuard` even when CEI is followed, as defense in depth (you already did this correctly in your DAO fix).
- **Real protocols almost never use raw `transfer()`/`send()` for ETH** — always low-level `.call` with a gas-forwarding check, because `transfer`'s fixed 2300 gas stipend breaks with smart contract wallets and post-EIP-1884 gas repricing.
- **Real protocols separate "core logic" contracts from "periphery" contracts** — see Uniswap's Pair/Router split. The core holds minimal, security-critical logic; the periphery handles UX conveniences like slippage and deadlines. Bugs in periphery are recoverable (redeploy); bugs in core holding funds are catastrophic.
- **Real protocols use extensive access control layering** — not just `onlyOwner`, but timelocks on top of multisigs on top of role-based permissions, so no single compromised key can act instantly.
- **Real protocols publish threat models, not just code** — a written document listing trust assumptions, actors, and known limitations, published alongside the contract (this is exactly what Tier F builds toward).
Read: **[Consensys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)** — the closest thing the industry has to a canonical "how real teams actually work" reference. Read the whole "Development Recommendations" and "Known Attacks" sections specifically.
 
### 0.5 — Working with AI as leverage, not as a crutch
Since this phase is explicitly built around staying relevant as AI improves, one working habit matters more than any single tool skill: **every time AI writes something for you — a contract, a test, an explanation — your job is to find what's wrong with it before you accept it.** Not because AI is untrustworthy, but because the practice of skeptical review *is* the skill. Two concrete habits to build starting now:
 
- When AI generates a test suite, your first pass is never "does it pass" — it's "what case would a real attacker try that isn't covered here."
- When AI explains why something works, ask it (or yourself) "what's the one input or timing sequence that would break this explanation" before moving on.
This habit is woven explicitly into Tiers A through D below as a required exercise type, not an optional add-on.
 
---
 
## Learning path
 
Each tier below lists: what you'll learn, **why it matters**, resources to consume *before* attempting the exercises, and the exercises themselves.
 
---
 
### 🟢 Tier A — Foundry Testing Fundamentals
**~1.5 weeks**
 
**Why this tier exists:** "It compiles" was your bar for done in phase one. This tier moves the bar to "I can prove it works" — and to "I can catch what an AI-generated test suite missed," which is the durable version of this skill.
 
**Resources — read/watch before starting:**
- **[Foundry Book — Writing Tests](https://book.getfoundry.sh/forge/writing-tests)** (official docs, primary reference for this entire tier)
- **[Foundry Book — Cheatcodes Reference](https://book.getfoundry.sh/cheatcodes/)** (keep this open as a tab while working — you'll reference it constantly)
- Video: **Patrick Collins / Cyfrin Updraft — "Foundry Fundamentals" (free YouTube course)** — covers `setUp`, assertions, and basic test structure with live examples
- **[Solidity by Example — Testing section](https://solidity-by-example.org/)** for quick syntax lookups mid-exercise
**Exercises:**
1. Foundry test anatomy — `setUp()`, test naming convention, `assertEq`/`assertTrue`, running `forge test -vvv`
2. Bank + Voting unit tests — full coverage: happy path, every custom error, boundary values (0, exact balance, overflow-adjacent)
3. `vm.prank` / `vm.startPrank` — testing multi-actor flows, impersonating different addresses, testing `onlyOwner` reverts correctly
4. `expectRevert` deep dive — testing custom errors with args, revert reasons, low-level call failures
5. `expectEmit` — asserting events fire with correct indexed/non-indexed params (often skipped by beginners, always checked in real audits)
6. ERC20 + ERC721 full suite — transfer, approve, transferFrom edge cases: insufficient balance, insufficient allowance, self-transfer, zero address
7. **Test code you didn't write — WETH9** — pull in the canonical [WETH9 contract](https://github.com/gnosis/canonical-weth/blob/master/contracts/WETH9.sol) (the real wrapped ETH contract deployed on mainnet, small and self-contained). Write a full unit test suite for it *without* asking anyone what it's supposed to do first — read the code, infer the intended behavior, then write tests that confirm your understanding. This is a different skill than testing your own code: you don't get to lean on remembering your own design intent.
8. **Audit the AI** — have AI generate a full test file for one contract you haven't tested yet, then manually find at least 3 missing cases or bugs in its test coverage before you accept any of it. Document what it missed and why.
---
 
### 🔵 Tier B — Security Testing: Prove the Exploit
**~1.5 weeks**
 
**Why this tier exists:** Testing isn't just "does it work," it's "can I prove it can't be broken." This is the mindset shift from developer-testing to security-testing — and security-testing judgment is exactly the layer AI is least reliable at unsupervised.
 
**Resources:**
- **[Rekt.news](https://rekt.news/)** — read 3–4 recent writeups before starting, specifically noticing what *kind* of test would have caught each exploit
- **[Foundry Book — Fork Testing](https://book.getfoundry.sh/forge/fork-testing)** (skim now — you'll want this concept for Tier C)
- **Smart Contract Programmer — YouTube, Reentrancy Attack video** for a second explanation angle beyond what you already know
**Exercises:**
1. Reentrancy: prove the exploit — write a test where `Attacker` actually drains `VulnerableBank`, assert the balance change
2. Reentrancy: prove the fix — same attack against `SafeBank`, assert it reverts, balance unchanged
3. Treasury access control tests — every role boundary: Admin-only, Manager-only, Viewer-can't-withdraw, tested from the wrong caller
4. Overflow/Underflow regression tests — prove `VulnerableToken` breaks, prove `SafeToken` reverts on the same inputs
5. TipJar pull-payment tests — prove the push-payment failure mode conceptually, test `claim()` correctness and double-claim prevention
6. **Audit the AI** — ask AI to write a security-focused test suite for one of your Tier 3 contracts (Vault, AMM, or Governor). Before running anything, review its reasoning: does it actually target a real attack vector, or does it just re-test the happy path with a security-sounding name? Write down your verdict before you run it.
---
 
### 🩷 Tier C — Fuzz & Invariant Testing
**~2 weeks**
 
**Why this tier exists:** This is the actual differentiator among human developers, AI-assisted or not. Most self-taught developers never write a fuzz test. Real protocols live and die by invariant coverage — this tier makes that instinct automatic instead of theoretical.
 
**Resources:**
- **[Foundry Book — Fuzz Testing](https://book.getfoundry.sh/forge/fuzz-testing)** and **[Invariant Testing](https://book.getfoundry.sh/forge/invariant-testing)** — mandatory reading, this is the primary spec for the whole tier
- **[Trail of Bits — Building Secure Contracts, "Invariant Testing" guide](https://github.com/crytic/building-secure-contracts)** — the closest thing to an industry standard reference on this topic, written by one of the top audit firms
- Video: **Cyfrin Updraft — "Foundry Fuzz Testing" module** (free)
- Read the **Handler pattern** section of the Foundry Book invariant docs specifically before attempting the AMM handler exercise
**Exercises:**
1. Fuzz testing basics — `testFuzz_` naming, `bound()`, `vm.assume()` — fuzzing Vault deposit/withdraw with random amounts
2. Vault: prove the inflation attack — write a fuzz/scenario test reproducing the exact attack you documented in your phase-one comments
3. StakingRewards: time-based fuzzing — `vm.warp()` across random durations, fuzz stake amounts, assert no reward ever exceeds the notified amount
4. AMM: your first invariant test — `invariant_k_never_decreases`, `reserveA * reserveB` must hold across thousands of random swap sequences
5. AMM: handler-based invariant testing — write a `Handler` contract that bounds fuzzer actions to valid operations, the real-world pattern used in production test suites
6. Governor: full lifecycle fuzz — fuzz propose/vote/timelock/execute sequences, assert the state machine never reaches an invalid state
7. **Define your own invariant** — pick any Tier 3 contract, and without asking AI first, write down in plain English one invariant that must always hold that isn't in the list above. Then implement it. This is the exercise that tests whether you actually understand the system, not just whether you can follow a template.
8. **Fuzz code you didn't write — Solmate ERC20** — pull in [Solmate's `ERC20.sol`](https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol), a real, widely-used, gas-optimized production implementation with some non-obvious design choices (unchecked blocks, packed logic) different from the ERC20 you wrote yourself. Fuzz `transfer`, `approve`, and `transferFrom` against random inputs, and specifically look for any assumption their unchecked arithmetic makes that could break under a fuzzed edge case. You're not looking for a real bug in a battle-tested library — you're practicing forming a hypothesis about someone else's code and testing it rigorously.
---
 
### 🟠 Tier D — Scripting & Deployment
**~1.5 weeks**
 
**Why this tier exists:** The gap between "I can write a contract" and "I can ship one" — real deploy workflows, not a Remix button click.
 
**Resources:**
- **[Foundry Book — Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting)** (official, primary reference)
- **[Foundry Book — Deploying and Verifying](https://book.getfoundry.sh/forge/deploying)**
- Video: **Patrick Collins — "Foundry Deployment" section of the Cyfrin Full Course** (free on YouTube)
- **[Alchemy — Sepolia faucet](https://www.alchemy.com/faucets/ethereum-sepolia)** or **[sepoliafaucet.com](https://sepoliafaucet.com/)** for test ETH
**Exercises:**
1. `forge script` basics — writing a `Deploy.s.sol`, `vm.startBroadcast`/`stopBroadcast`, running against local Anvil
2. Multi-contract deploy script — deploy your AMM: MockToken A, MockToken B, then the AMM itself wired together in one script
3. Environment & config handling — reading private keys/RPC URLs safely via `.env`, never hardcoding secrets
4. Sepolia deploy + verify via script — full real-world flow: `forge script --broadcast --verify` against a live testnet
5. Post-deploy interaction scripts — a second script that calls your deployed contract, e.g. triggering a swap or a stake after deployment
6. **Audit the AI** — have AI write a deploy script for a multi-contract system you haven't scripted yet. Check specifically: does it handle deploy ordering correctly (dependencies deployed before the contracts that need their addresses), and does it hardcode anything that should come from `.env`?
---
 
### 🟣 Tier E — Gas Optimization: Basics to Full EVM Depth
**~3 weeks**
 
**Why this tier exists:** Full depth as requested — starting from the fundamentals you don't know yet, down to raw opcode cost and Yul. By the end you should be able to look at a function and predict roughly what it costs and why, not just measure it after the fact.
 
**Resources:**
- **[evm.codes](https://www.evm.codes/)** — the canonical interactive opcode reference. Bookmark this, you'll use it constantly through this whole tier.
- **[EIP-2929 — Gas cost increases for state access opcodes](https://eips.ethereum.org/EIPS/eip-2929)** — the actual spec for cold/warm storage access, read this directly rather than a summary
- **[Solidity docs — Layout of State Variables in Storage](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html)** — official reference for how packing actually works at the slot level
- **[RareSkills — Gas Optimization articles](https://www.rareskills.io/post/gas-optimization)** — one of the better technical-depth free resources specifically on Solidity gas tricks including assembly
- **[Solidity docs — Inline Assembly](https://docs.soliditylang.org/en/latest/assembly.html)** — official Yul reference, needed before the assembly exercises
- Video: **Smart Contract Programmer — "Yul and Inline Assembly" YouTube series** (free, hands-on)
- **[Foundry Book — forge inspect](https://book.getfoundry.sh/reference/forge/forge-inspect)** for the `storage-layout` command used in the exercises
**Exercises — Part 1: Fundamentals (things you don't know yet)**
1. `require` vs `revert` with custom errors — measure the actual gas difference yourself with `forge test --gas-report`. Understand *why*: string reverts encode and store the full string in bytecode/calldata; custom errors are just a 4-byte selector.
2. Function visibility cost — `external` vs `public` for functions never called internally, and why `external` is cheaper (calldata vs memory copying for array/string args).
3. `++i` vs `i++` in loops, and pre-increment inside `unchecked` blocks — measure, don't assume.
4. Short-circuit evaluation ordering in `&&`/`||` — cheapest/most-likely-to-fail condition first, and why.
5. Constant/immutable vs regular state variables — measure the deployment and runtime gas difference directly.
6. Fixed-size vs dynamic arrays, and why `bytes32` beats `string` when you don't need a variable-length string.
**Exercises — Part 2: EVM-level depth**
7. EVM cost model fundamentals — gas cost table for SLOAD/SSTORE/CALL/opcodes, cold vs warm storage access (EIP-2929), why storage is the most expensive resource
8. Storage layout mastery — manually compute storage slots for structs/mappings/arrays, verify with `forge inspect storage-layout`
9. `forge snapshot` workflow — `.gas-snapshot` baselines, before/after diffing, CI gas regression checks
10. Memory vs calldata vs storage cost — real cost differences measured, not assumed; memory expansion cost curve
11. Intro to Yul/inline assembly — basic assembly blocks: `mload`, `mstore`, `sload`, `sstore` — reading and writing storage/memory directly
12. Rewrite a hot function in Yul — take your cheapest-possible ERC20 `transfer()` and hand-optimize it in assembly, measure the delta
13. Custom errors and calldata packing at the byte level — how error selectors work, packing multiple values into fewer calldata bytes for L2 cost savings
14. Assembly-based storage slot manipulation — direct slot reads/writes for a packed struct, bypassing the compiler's default access patterns
15. Full audit: optimize a real Tier 3 contract — take your AMM or StakingRewards, apply everything above, produce a before/after gas report with reasoning for every change
 
---
 
### 🟡 Tier F — Architecture: Design From Scratch
**~3.5 weeks**
 
**Why this tier exists — read this one carefully.** This is the actual center of this entire phase, not just another tier. Everything in Tiers A–E makes you competent and verifiably trustworthy. This tier is what makes you *differentiated* — because designing something novel, under real constraints, and defending the trade-offs in writing, is the part of this job an AI model genuinely cannot reliably do on its own yet. No given spec, no given functions — a one-paragraph problem statement, and you write the design doc and build it, the way real protocol work actually starts.
 
**Resources:**
- **[Uniswap V2 core source, GitHub](https://github.com/Uniswap/v2-core)** — read `UniswapV2Pair.sol` directly for the diffing exercise
- **[Aave V3 core source, GitHub](https://github.com/aave/aave-v3-core)** — reference architecture for the lending market design exercise; don't copy, read *after* writing your own design doc, not before
- **[Trail of Bits — Building Secure Contracts, full repo](https://github.com/crytic/building-secure-contracts)** — has real-world design-review checklists worth adapting into your own
- **[Rekt.news — Flash loan governance attacks archive](https://rekt.news/)** — search specifically for governance/flash-loan incidents before the governance design-reasoning exercise
- **[Consensys — Smart Contract Best Practices, "Software Engineering" section](https://consensys.github.io/smart-contract-best-practices/)** for the design doc template starting point
**Exercises:**
1. How to write a design doc — problem statement, actors, state, invariants, attack surface, trade-offs — the template used before any real protocol writes code
2. From-scratch: a lending market — one-paragraph prompt only. Design collateral ratios, liquidation logic, interest accrual — write the doc first, then build it
3. Peer-review your own lending market — cold review a week later: what did past-you miss, what would you change now
4. From-scratch: an escrow/dispute system — one-paragraph prompt only. Design trust assumptions and dispute resolution before writing a single function
5. Break your own AMM — write an attacker contract attempting a sandwich attack on your own swap function, document what you find
6. **Diff and test the real thing** — read Uniswap V2's actual `UniswapV2Pair.sol`, diff it against yours — what did they add, and why. Then write a partial test suite for `UniswapV2Pair.sol` itself (a handful of tests targeting its `swap()` and `mint()` functions is enough) — this is your third and hardest "test code you didn't write" exercise: a real, audited, production contract significantly more complex than WETH9 or Solmate's ERC20.
7. Design-reasoning: staking exploit (written only) — a whale stakes right before day 7 and unstakes after — is this exploitable? Design the fix on paper before touching code
8. Design-reasoning: governance flash-loan attack (written only) — could someone flash-loan tokens to pass a malicious proposal? Why or why not, given your Governor's actual design
9. Mock security review — pick a Tier 3 contract you haven't touched in a while, review it cold as if it were someone else's PR, write up findings
10. **AI-assisted vs. AI-first design comparison** — for the escrow/dispute system in exercise 4, write your own design doc completely unaided first. Only after you've finished, ask AI to design the same system from the same one-paragraph prompt. Compare the two side by side: what did you consider that it didn't, what did it consider that you didn't, and where did your trade-off reasoning actually differ. Write this comparison up — it's the single most direct evidence you can produce of your own judgment relative to AI's.
11. Final: design doc for your hooks project idea — apply everything in this tier to a real one-pager for the Uniswap V4 hook — this becomes the seed of the actual next project
---
 
## Honest Assessment — What Finishing This Actually Makes True
 
This section is here because it was asked for directly, and it deserves a direct, calibrated answer rather than hype.
 
**What completing Phase 2 will make objectively true about you:**
- You will have a tested, fuzzed, and invariant-checked test suite across your hardest phase-one contracts — something the large majority of self-taught Solidity developers, and a meaningful share of bootcamp graduates, do not have.
- You will understand gas costs from `require` vs custom errors up through hand-written Yul — genuine EVM-level fluency, not just "I used `unchecked` once."
- You will have a real, working Foundry deployment pipeline, used against a live testnet, not just Remix's deploy button.
- You will have at least two from-scratch design docs (a lending market, an escrow system) written before any code, plus a direct written comparison of your own design judgment against AI's on the same prompt — which is concrete, defensible evidence of exactly the skill this whole phase was built to prove.
**What level this puts you at, honestly:** this is a real, solid **intermediate smart contract engineer** profile — someone who can be trusted with a junior-to-mid remote role, contract work, or hook-grant application, and who has demonstrable, artifact-backed evidence (not just claims) for both implementation and design judgment. It is not, by itself, a senior/staff-level profile — that additionally requires shipped production experience with real users and real incidents survived, which no amount of self-directed exercises can substitute for. Nobody honest can promise you a job from a roadmap; what this roadmap can honestly promise is that you'll have the specific, checkable evidence a hiring manager or grant reviewer actually looks for, and a genuine, defensible answer to "why should we trust you over a model that can also write Solidity" — which is the real question this entire phase was designed to answer.
 
---

 
## Notes for reviewer
 
- Formal verification is intentionally excluded — planned as a separate track via Cyfrin's dedicated course, not duplicated here.
- The author explicitly requested: (1) a competitive positioning thesis about AI capability growth, reflected in the "Actual Thesis" section and the "Audit the AI" exercises woven into Tiers A, B, D, and the AI-vs-self design comparison in Tier F; (2) full EVM/Yul depth for gas optimization, now split into a fundamentals-first sub-section before the EVM-internals sub-section; (3) open-ended (no-spec) design exercises for architecture, framed explicitly as the center of gravity for the whole phase.
- Feedback wanted on: sequencing correctness, any missing foundational topic, resource quality/currency, whether the "Audit the AI" exercises are meaningfully different from standard testing exercises or redundant, and whether the closing honest-assessment section is calibrated correctly (not overclaiming, not underselling real completed work).
