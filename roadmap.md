# Phase 2 — Verification & Systems Engineering
### Testing · Scripting · Deep Gas/EVM · From-Scratch Architecture

**Context for reviewer:** This is phase two of a self-directed Solidity relearning program. Phase one (20 exercises, 4 tiers — Foundations, Security Patterns, DeFi Mechanics, Gas/Advanced) is complete: vaults, staking, AMM, flash loans, governance, UUPS proxies, Merkle airdrops, EIP-712, and a DAO-hack case study, all written from spec without OpenZeppelin. Phase two closes the gap between "can implement a contract" and "can verify, ship, and defend one like a working engineer" — and is explicitly designed around a specific competitive thesis (below), not just "more exercises."

**Pace constraint:** originally written for 1–2 hrs/day; the current working pace is ~26 hrs/week on Phase 2 exercises. The per-tier week estimates below were written for the original pace and were never recalibrated — treat them as relative size, not a schedule. See "Schedule & Cut List" next.

---

## Schedule & Cut List

**Working pace:** ~26 hrs/week on Phase 2 exercises (separate from ~4 hrs/week for reading, posts and strategy). Target: finish by end of December 2026 — about 13 weeks from the start of Tier B, roughly 340 hours on paper, less after exam weeks and the buffer you will actually use.

**Honest sizing:** the remaining scope is 56 exercises across Tiers B–F (B: 7, C: 11, D: 6, E: 21, F: 11) — about 6 hours per exercise on paper. That is fine for most of them and tight for the heavy ones (invariant handlers, the Yul rewrite, the lending-market design doc). Tier A ran past its own estimate, so do not trust the week numbers below. **After each tier, compare your actual hours (from the tracker) against the estimate and re-plan the remaining tiers from real data.**

**Cut list — decided now, so you are not deciding while behind.** If the date starts slipping, cut from this list in order instead of rushing anything else: (1) Tier E ex 19, (2) Tier E ex 18, (3) Tier C ex 8 (Solmate), (4) Tier D ex 5 (post-deploy scripts). If that is still not enough, move the date.

**Protected — never cut, never rush:** every "Audit the AI" exercise, Tier C ex 4–7, and Tier F ex 1–4, 10 and 11. If those need more time, move the date, not the quality bar.

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

This habit is woven explicitly into every tier below as a required exercise type, not an optional add-on.

**The pipeline, stated explicitly:** every "Audit the AI" exercise in this roadmap is a specific instance of one repeatable workflow — you define the requirements/threat model/invariants first, AI generates an implementation or test suite, you review and challenge it, Foundry (fuzz/invariant/fork/mutation, per whichever tier you're in) validates it further, and only then do you accept, modify, or reject it. That order matters: AI comes *after* you've stated what "correct" means, never before. This isn't a separate tier to complete — it's the operating mode for the whole phase, and by Tier F it culminates in the AI-vs-self design comparison, where you run the same design prompt both ways (you design first then compare to AI's version, and separately, AI designs first and you review its design doc as the harder, more consequential version of "audit the AI") and document where each one's reasoning held up or failed.

---

## Learning path

Each tier below lists: what you'll learn, **why it matters**, resources to consume *before* attempting the exercises, and the exercises themselves.

**Link note:** Foundry's docs now live at getfoundry.sh. If a `book.getfoundry.sh` link below redirects oddly or 404s, search the same page title on getfoundry.sh.

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
8. **Audit the AI** — have AI generate a full test file for one contract you haven't tested yet. Before accepting any of it, identify the single most dangerous missing case (not just any 3 gaps) and write a paragraph on why it's the most dangerous — this forces severity judgment, the actual skill, rather than box-checking a minimum count.
9. **Multi-contract integration — Uniswap V2 core.** Everything up to this point tests one contract in isolation. Real protocols are graphs of contracts calling each other, and bugs that only exist *because* of that interaction (see: the Cream Finance cross-contract reentrancy, not a same-function case) are a different class than anything above. Copy the real, canonical [`UniswapV2Factory.sol`](https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Factory.sol), [`UniswapV2Pair.sol`](https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol), and [`UniswapV2ERC20.sol`](https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2ERC20.sol) into your repo (adjust pragma to 0.8.x and fix compiler-only issues, same rule as WETH9 — do not touch the core logic). Deploy the Factory, create a real Pair from two of your own tokens, and write an integration suite covering: pair creation via `createPair`, first liquidity provision (including the minimum-liquidity lock — you already understand this from your own AMM build), swaps in both directions, the `k` invariant holding after every swap, and fee-on-swap accounting. This is Tier A's true capstone — same "test code you didn't write" spirit as WETH9 and the Solmate (Tier C) and deeper Uniswap Pair (Tier F) exercises, one full level harder because now it's dependencies interacting, not one contract standing alone.

---

### 🔵 Tier B — Security Testing: Prove the Exploit
**~1.5 weeks**

**Why this tier exists:** Testing isn't just "does it work," it's "can I prove it can't be broken." This is the mindset shift from developer-testing to security-testing — and security-testing judgment is exactly the layer AI is least reliable at unsupervised.

**Resources:**
- **[Rekt.news](https://rekt.news/)** — read 3–4 recent writeups before starting, specifically noticing what *kind* of test would have caught each exploit
- **[Foundry Book — Fork Testing](https://book.getfoundry.sh/forge/fork-testing)** (read fully before Exercise 7 — it is the primary reference for the fork-state exercise, and the concept comes back in Tier C)
- **Smart Contract Programmer — YouTube, Reentrancy Attack video** for a second explanation angle beyond what you already know

**Exercises:**
1. Reentrancy: prove the exploit — write a test where `Attacker` actually drains `VulnerableBank`, assert the balance change
2. Reentrancy: prove the fix — same attack against `SafeBank`, assert it reverts, balance unchanged
3. Treasury access control tests — every role boundary: Admin-only, Manager-only, Viewer-can't-withdraw, tested from the wrong caller
4. Overflow/Underflow regression tests — prove `VulnerableToken` breaks, prove `SafeToken` reverts on the same inputs
5. TipJar pull-payment tests — prove the push-payment failure mode conceptually, test `claim()` correctness and double-claim prevention
6. **Audit the AI** — ask AI to write a security-focused test suite for one of your Tier 3 contracts (Vault, AMM, or Governor). Before running anything, review its reasoning and ask: if you had to bet your job on this suite catching every real bug, would you? Identify the one gap that worries you most and why — not just whether it re-tests the happy path with a security-sounding name.
7. **Fork-state integration testing — real mainnet conditions.** Every test so far runs against a clean, deployed-from-zero Anvil state. Real protocols eventually have to interact with the actual live state of mainnet — real pool depths, real token balances, real oracle prices at a specific block. Use `forge test --fork-url <mainnet RPC> --fork-block-number <a specific block>` to fork real mainnet state, then write a test where one of your own contracts (your AMM or Vault) interacts with a real deployed token (e.g., real USDC or WETH at their actual mainnet addresses) at that forked block. Specifically test what happens when assumptions from a clean-state test break against real conditions: what if the "empty" pool you assumed in earlier tests actually has significant existing liquidity or a skewed price at that block? What if the real token has a nonstandard `decimals()` value your contract assumed was 18? This is the gap between "my tests pass in a vacuum" and "my contract survives real-world state" — a distinct and commonly underrated skill. Resource: [Foundry Book — Fork Testing](https://book.getfoundry.sh/forge/fork-testing), and [Alchemy](https://www.alchemy.com/) or [Infura](https://www.infura.io/) for a free mainnet RPC URL to fork from.

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
9. **Mutation testing — prove your tests actually catch bugs** — 100% line coverage doesn't mean your tests are meaningful; a test suite can hit every line and still miss real logic bugs. Run mutation testing against one of your Tier 3 contracts (Vault or AMM): it injects small bugs (`>` flipped to `<`, `+=` changed to `-=`, a `require` deleted) and reruns your suite against each mutant. Any mutant that survives reveals a real gap in your tests — fix it by writing a test that specifically kills that mutant. Resources: Foundry now has mutation testing built in — `forge test --mutate src/Vault.sol --match-contract VaultTest` — see [Foundry — Mutation testing guide](https://getfoundry.sh/guides/mutation-testing) (the docs mark it as an early MVP, so expect rough edges and check the current flags). Fallback: RareSkills' actively maintained [vertigo-rs](https://github.com/RareSkills/vertigo-rs) and their [Solidity mutation testing article](https://rareskills.io/post/solidity-mutation-testing).
10. **Differential testing — prove your math against a trusted reference.** Every invariant test above proves your contract is internally consistent. It doesn't prove your math is *correct* against an independent, trusted source. Differential testing closes that gap: write a small Python or Rust reference implementation of one non-trivial piece of math you've built in Solidity (the AMM's `sqrt`/`min` logic from your own from-scratch implementation is the natural target), then use Foundry's `ffi` cheatcode to shell out to that script from within a fuzz test, feed it the same random inputs your Solidity function receives, and assert the two outputs match exactly. This is a genuinely different skill from anything above — proving correctness against an external source of truth, not just proving self-consistency — and it's how real quant/DeFi teams validate math-heavy contracts (AMM curves, interest-rate models) before shipping. Resource: [Foundry Book — `ffi` cheatcode reference](https://book.getfoundry.sh/cheatcodes/ffi) — note the security warning about `ffi` and untrusted input; this is a testing-only technique, never used in production contract code.
11. **Audit the AI — invariants.** Follow the pipeline from Module 0.5. First write down, by hand and before touching AI, the invariants you believe must hold for your Governor or StakingRewards contract. Only then ask AI to propose an invariant suite for the same contract. Review every AI-proposed invariant and classify it: false (fails on a legitimate action sequence), incomplete (holds, but protects nothing real), redundant, or poorly specified. Then identify the single most important invariant that neither list contains. This is the hardest version of "audit the AI" so far, because a weak invariant passes silently while looking like protection.

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

### 🟣 Tier E — Calldata, Tracing & Gas Optimization: Basics to Full EVM Depth
**~3.5 weeks** (extra half-week for the new ABI/tracing sub-section below)

**Why this tier exists:** Full depth as requested — starting from how a function call actually becomes bytes, through raw opcode cost, down to Yul. By the end you should be able to look at a function and predict roughly what it costs and why, and read a failing trace and know exactly which call/storage-write caused it — not just measure gas after the fact or stare at a red X.

**Resources:**
- **[evm.codes](https://www.evm.codes/)** — the canonical interactive opcode reference. Bookmark this, you'll use it constantly through this whole tier.
- **[Solidity docs — Contract ABI Specification](https://docs.soliditylang.org/en/latest/abi-spec.html)** — official reference for function selectors, static/dynamic encoding, and calldata layout
- **[EIP-2929 — Gas cost increases for state access opcodes](https://eips.ethereum.org/EIPS/eip-2929)** — the actual spec for cold/warm storage access, read this directly rather than a summary
- **[Solidity docs — Layout of State Variables in Storage](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html)** — official reference for how packing actually works at the slot level
- **[RareSkills — Gas Optimization articles](https://www.rareskills.io/post/gas-optimization)** — one of the better technical-depth free resources specifically on Solidity gas tricks including assembly
- **[Solidity docs — Inline Assembly](https://docs.soliditylang.org/en/latest/assembly.html)** — official Yul reference, needed before the assembly exercises
- Video: **Smart Contract Programmer — "Yul and Inline Assembly" YouTube series** (free, hands-on)
- **[Foundry Book — forge inspect](https://book.getfoundry.sh/reference/forge/forge-inspect)** for the `storage-layout` command used in the exercises
- **[Foundry Book — `cast` reference](https://book.getfoundry.sh/reference/cast/)** for decoding calldata/return data directly from the command line

**Exercises — Part 0: ABI, Calldata & Tracing (the call boundary — new, do this first)**
This is the layer underneath everything you've been testing since Tier A. You've been reading `-vvvv` traces for weeks without formally understanding what the bytes actually are — this closes that gap before you touch gas or Yul.
1. Function selectors by hand — compute `bytes4(keccak256("transfer(address,uint256)"))` yourself, then verify it against `cast sig` and against what you see at the start of a real `-vvvv` trace's calldata.
2. Static vs dynamic ABI encoding — manually encode a call to a function taking a `uint256` and a `string`, by hand on paper, then verify byte-for-byte against `cast calldata`. Understand why dynamic types need an offset pointer while static types don't.
3. Read a real trace end to end — take any existing test with a multi-call trace (your Uniswap integration test is perfect for this) and, using `forge test -vvvv`, manually explain every `CALL`, `SLOAD`, `SSTORE`, and `RETURN` in the trace in your own words, in order — not just "it passed," but *why* each storage slot changed.
4. Custom error decoding — trigger a custom error with arguments, then use `cast 4byte-decode` (or read the raw revert data in a trace) to manually decode the selector and arguments from the raw bytes, without looking at the Solidity source first.
5. `DELEGATECALL` vs `CALL` in a trace — go back to your Phase 1 UUPS proxy exercise, run a test with `-vvvv`, and identify exactly which frame is a `DELEGATECALL` and why `msg.sender`/storage context stays the same across it while a plain `CALL` would change it.

**Exercises — Part 1: Fundamentals (things you don't know yet)**
6. `require` vs `revert` with custom errors — measure the actual gas difference yourself with `forge test --gas-report`. Understand *why*: string reverts encode and store the full string in bytecode/calldata; custom errors are just a 4-byte selector.
7. Function visibility cost — `external` vs `public` for functions never called internally, and why `external` is cheaper (calldata vs memory copying for array/string args).
8. `++i` vs `i++` in loops, and pre-increment inside `unchecked` blocks — measure, don't assume.
9. Short-circuit evaluation ordering in `&&`/`||` — cheapest/most-likely-to-fail condition first, and why.
10. Constant/immutable vs regular state variables — measure the deployment and runtime gas difference directly.
11. Fixed-size vs dynamic arrays, and why `bytes32` beats `string` when you don't need a variable-length string.

**Exercises — Part 2: EVM-level depth**
12. EVM cost model fundamentals — gas cost table for SLOAD/SSTORE/CALL/opcodes, cold vs warm storage access (EIP-2929), why storage is the most expensive resource
13. Storage layout mastery — manually compute storage slots for structs/mappings/arrays, verify with `forge inspect storage-layout`
14. `forge snapshot` workflow — `.gas-snapshot` baselines, before/after diffing, CI gas regression checks
15. Memory vs calldata vs storage cost — real cost differences measured, not assumed; memory expansion cost curve
16. Intro to Yul/inline assembly — basic assembly blocks: `mload`, `mstore`, `sload`, `sstore` — reading and writing storage/memory directly
17. Rewrite a hot function in Yul — take your cheapest-possible ERC20 `transfer()` and hand-optimize it in assembly, measure the delta
18. Calldata packing for L2 cost — L2s charge for calldata bytes, so packing several small values into fewer bytes cuts real cost. Design a packed-calldata version of one function (e.g. two `uint128` amounts and a flag in a single word), decode it in Yul, and measure the calldata size and gas difference against the plain ABI-encoded version. (Custom-error encoding is already covered in Part 0.)
19. Assembly-based storage slot manipulation — direct slot reads/writes for a packed struct, bypassing the compiler's default access patterns
20. **Brutalize testing on your Yul code** — Solidity does not always zero out the unused upper bits of a `uint8`, `bool`, `address` or other sub-32-byte value; hand-written Yul that silently assumes "clean" bits can pass every normal test and still be wrong. Foundry has no built-in cheatcode for this (an earlier version of this roadmap wrongly pointed to `vm.brutalizeMemory` — it is not a real cheatcode). Instead, construct dirty-bit inputs yourself: in a test helper, use inline assembly to OR/XOR garbage into the upper bits of a value before passing it to your Yul function, and confirm the function still behaves correctly or cleans the bits before using them. Study how Solady does it: its test base [`test/utils/SoladyTest.sol`](https://github.com/Vectorized/solady/blob/main/test/utils/SoladyTest.sol) ships "brutalizer" helpers (for example `_brutalizedUint8`) and uses them throughout its assembly-heavy tests.
21. Full audit: optimize a real Tier 3 contract — take your AMM or StakingRewards and apply everything above, producing a before/after gas report with reasoning for every change. Follow the AI pipeline from Module 0.5: before applying anything, ask AI for a list of proposed gas optimizations, and for each one predict whether it will actually help and whether it could change behavior. Then verify each against your test suite, fuzz tests and `forge snapshot` diffs — and note any suggestion that saved gas but broke an invariant or edge case, and any that saved nothing.

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
2. From-scratch: a lending market — one-paragraph prompt only. Design collateral ratios, liquidation logic, interest accrual — write the doc first, then build it. Your design doc must explicitly name and justify a price-oracle choice (Chainlink feed vs. your own TWAP vs. something else), including staleness handling and what happens if the feed lags or gets manipulated — oracle choice is arguably the single most consequential decision in a real lending market, so don't leave it implicit.
3. Peer-review your own lending market — cold review a week later: what did past-you miss, what would you change now
4. From-scratch: an escrow/dispute system — one-paragraph prompt only. Design trust assumptions and dispute resolution before writing a single function
5. Break your own AMM — write an attacker contract attempting a sandwich attack on your own swap function, document what you find
6. **Diff and test the real thing** — you already migrated the real `UniswapV2Pair.sol` and integration-tested it in Tier A, so this exercise goes deeper instead of repeating that. First diff it against your own Phase 1 AMM: what did Uniswap add, and why (the TWAP price accumulators, the `MINIMUM_LIQUIDITY` lock, the reentrancy `lock` modifier, `sync`/`skim`, the protocol-fee logic in `_mintFee`, the flash-swap callback)? Then write tests for the parts Tier A deliberately skipped: `burn`, the flash-swap callback path, `sync`/`skim`, the cumulative price accumulators over time (`vm.warp`), and the protocol-fee mint. This is your hardest "test code you didn't write" exercise: a real, audited, production contract with genuinely subtle behavior.
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
- **Immediately after Phase 2 finishes** (not folded into a tier, so it doesn't compress an already-tight timeline): find a real, live protocol, read its code, find a small real issue or improvement, and submit a PR. This is the single highest-leverage addition external review has flagged — a real, verifiable contribution in a real codebase with real maintainers and real review, which converts "I completed a curriculum" into "I've worked in a real codebase." Do this in week 1-2 post-Phase-2, alongside the README update and before the hooks project ships.

**What level this puts you at, honestly:** this is a real, solid **intermediate smart contract engineer** profile — someone who can be trusted with a junior-to-mid remote role, contract work, or hook-grant application, and who has demonstrable, artifact-backed evidence (not just claims) for both implementation and design judgment. It is not, by itself, a senior/staff-level profile — that additionally requires shipped production experience with real users and real incidents survived, which no amount of self-directed exercises can substitute for. Nobody honest can promise you a job from a roadmap; what this roadmap can honestly promise is that you'll have the specific, checkable evidence a hiring manager or grant reviewer actually looks for, and a genuine, defensible answer to "why should we trust you over a model that can also write Solidity" — which is the real question this entire phase was designed to answer.

**The artifacts this phase should leave you with** (this is the real product — a hiring manager or grant reviewer looks at these, not at how many exercises you finished):
- A public repo with the full unit, security, fuzz and invariant test suites, a coverage report, and a mutation-testing report
- The Uniswap V2 integration suite plus the WETH9 and Solmate "code you didn't write" suites
- A Sepolia deployment with verified addresses and the scripts that produced it
- A before/after gas report for a real contract
- Two from-scratch design docs (a lending market with a justified oracle choice, and an escrow/dispute system) plus your written AI-vs-self comparison
- Be ready to defend any line of any of it out loud — if you cannot explain it, it is not yours yet

---

## Notes for reviewing AI

- Formal verification is intentionally excluded — planned as a separate track via Cyfrin's dedicated course, not duplicated here.
- The author explicitly requested: (1) a competitive positioning thesis about AI capability growth, reflected in the "Actual Thesis" section, the AI pipeline in Module 0.5, the "Audit the AI" exercises in Tiers A–D, the AI-optimization step in Tier E, and the AI-vs-self design comparison in Tier F; (2) full EVM/Yul depth for gas optimization, structured as ABI/calldata/tracing first, then gas fundamentals, then EVM internals and Yul; (3) open-ended (no-spec) design exercises for architecture, framed as the center of gravity for the whole phase; (4) formal verification/SMT deliberately deferred to a separate later track.
- Feedback wanted on: sequencing correctness, any missing foundational topic, resource quality/currency, whether the "Audit the AI" exercises are meaningfully different from standard testing exercises or redundant, and whether the closing honest-assessment section is calibrated correctly (not overclaiming, not underselling real completed work).