# Critique: LEVER-BUG-1 — PnL Formula Mismatch (entryPrice vs entryPI)
## Date: 2026-03-28T14:57:00Z
## Plan reviewed: handoffs/plan-lever-bug-1.md
## Supersedes: critique-lever-bug-2.md (reviewed earlier draft of this plan)

---

### Verdict: REVISE

This plan is substantially improved over the earlier drafts. The phased approach is sound, the correct formula direction (execution price, not raw PI) aligns with LESSONS.md, and the tests target the right properties. Two issues block approval: the exit-side formula departs from LESSONS.md, and Phase 3 has an unscoped infrastructure change that will block BUILD.

---

### What Is Good

- Correctly reconciles with LESSONS.md and Master's clarification. The plan now uses `pos.entryPrice` (execution price) for PnL, not `pos.entryPI` (raw PI). This is the right direction.
- Phased approach (rename, then ExecutionEngine, then MarginEngine, then SettlementEngine separately) is clean and allows incremental rollback.
- `exitPrice` is already computed at line 350 and currently discarded for PnL. Reusing it is free.
- `pos.entryPrice` is already stored at open. No new storage needed.
- SettlementEngine correctly scoped out as a design decision for Master.
- Correct observation that Phase 2 can ship independently if Phase 3 is complicated.
- Test cases are well-targeted: round-trip spread test, cross-engine consistency, regression guard.

---

### Issues Found

**1. [CRITICAL] Exit-side formula departs from LESSONS.md**

The plan's formula: `PnL = direction * (exitPrice_execution - entryPrice_execution) * size`

LESSONS.md line 101 (from Master): `PnL = direction * (current_PI - entry_execution_price) * size`

LESSONS.md explicitly says: "The current PI from the oracle is the correct mark price." This means raw oracle PI as exit reference, execution price as entry reference. The plan uses execution-adjusted exit prices on BOTH sides.

The difference is the close-side execution impact. Using the plan's formula:
- Long close: `exitPrice = pi * (1 - impact)` (lower than raw pi)
- Short close: `exitPrice = pi * (1 + impact)` (higher than raw pi)

The plan charges traders the spread on BOTH open AND close. LESSONS.md charges them only on open.

Numerical example at 2% impact, PI = 0.50, size = 10000 USDT:
- LESSONS.md: round-trip PnL = (0.50 - 0.51) * 10000 = -$100 (entry spread only)
- Plan: round-trip PnL = (0.49 - 0.51) * 10000 = -$200 (double spread)

This is not a subtle distinction. It is a 2x difference in the cost of every round trip. At typical volumes, this has a major impact on trader economics and vault revenue.

There are valid arguments for both approaches:
- Double-impact (plan's formula): mirrors traditional bid-ask spread. Correct if the vault is a market maker that charges spread on both legs.
- Single-impact (LESSONS.md): correct if the exit impact is a theoretical price (no counterparty executes at that price; the vault just pays PnL). The execution impact at open is real (the trader "bought" at a worse price); at close, the vault settles at mark.

The plan needs to resolve this with Master before BUILD starts. LESSONS.md is authoritative and explicit. If the plan's double-impact model is correct, LESSONS.md must be updated. If LESSONS.md is correct, line 353 should be: `_computePnL(pos.isLong, pi, pos.entryPrice, pos.positionSize)` (raw pi for exit, entryPrice for entry).

**Fix:** Add this as a decision point. Propose both options to Master with the numerical impact. Do not assume double-impact. If Master chooses single-impact (LESSONS.md formula), Phase 2 becomes simpler (just swap `pos.entryPI` to `pos.entryPrice` on line 353, keep `pi` as exit) and Phase 3 becomes trivial (MarginEngine changes one line, no external call needed).

---

**2. [HIGH] Phase 3 circular dependency is larger than described; MarginEngine has no ExecutionEngine reference at all**

I read MarginEngine.sol. The constructor takes 6 addresses: `admin`, `positionManager`, `oracle`, `marketRegistry`, `borrowFeeEngine`, `fundingRateEngine`. There is no ExecutionEngine import, no IExecutionEngine import, no stored reference.

Adding `computeHypotheticalExitPrice` requires:
- Adding `IExecutionEngine` import to MarginEngine.sol
- Adding `IExecutionEngine executionEngine` state variable
- Modifying the constructor (breaking change) or adding a `setExecutionEngine` setter with admin ACL
- Updating the deployment script to pass ExecutionEngine address to MarginEngine
- Updating IMarginEngine if constructor changes

The plan says "BUILD must check whether a new getter on ExecutionEngine creates a circular import." It is not a circular import issue (Solidity interfaces don't create cycles). It is an infrastructure issue: MarginEngine has never had a reference to ExecutionEngine, and adding one is a constructor change that affects deployment order and all existing deployment scripts.

The plan lists this as an open question but does not scope the work. BUILD will hit this at Step 4 and stall.

**Fix:** Either scope the MarginEngine constructor change explicitly (including deployment script updates and migration path), OR, choose the single-impact model from LESSONS.md, which eliminates Phase 3 entirely. With the LESSONS.md formula, MarginEngine only needs to change `pos.entryPI` to `pos.entryPrice` on line 369, one line, no external call, no new dependency.

---

**3. [HIGH] Phase 3 adds gas cost to 4 hot paths**

`_computeEquity` is called in 4 places within MarginEngine:
- `computeEquity()` (external view, used by LiquidationEngine in 3 places)
- `isLiquidatable()` (called during every liquidation attempt)
- `isInDangerZone()` (monitoring/UI)
- `canRemoveCollateral()` (called during collateral removal)

The proposed `computeHypotheticalExitPrice` call adds an external call to ExecutionEngine, which internally calls `_computeExecutionPrice`, which reads from `oiLimits` (external) and `marketRegistry` (external) for imbalance delta computation. That is 2-3 additional external SLOAD chains per equity computation.

LiquidationEngine calls `marginEngine.computeEquity()` at least twice per liquidation (isLiquidatable check + actual liquidation). Additional gas per liquidation attempt: estimated 10-15K gas from the new external calls. At scale, this matters.

**Fix:** If the single-impact model is chosen (LESSONS.md formula), this issue disappears (no external call needed; just change which Position field is read). If double-impact is confirmed, at minimum note the gas cost increase in the plan and verify it does not push any transaction near the block gas limit.

---

**4. [MEDIUM] IExecutionEngine.sol not listed in files-to-modify**

The plan adds `computeHypotheticalExitPrice` to ExecutionEngine but does not list `contracts/interfaces/IExecutionEngine.sol` in files-to-modify. MarginEngine will call this function through the interface. The interface must be updated.

---

**5. [MEDIUM] Test 5b zero-sum assertion is imprecise**

The plan says: "Verify: pnl(long) + pnl(short) approximately equals -(2 * spread_cost)."

With the plan's double-impact formula and flat market (pi_open = pi_close = 0.50, 2% impact):
- Long PnL = (0.49 - 0.51) * size = -0.02 * size
- Short PnL = -(0.51 - 0.49) * size = -0.02 * size
- Sum = -0.04 * size

That is 4x the single-side spread, not 2x. "2 * spread_cost" is ambiguous. If spread_cost = impact * pi * size, then sum = -4 * spread_cost. If spread_cost = (entryPrice - exitPrice) * size per side (i.e., 2*impact*pi*size), then sum = -2 * spread_cost. BUILD will have to guess.

**Fix:** Define spread_cost explicitly in the test description with exact WAD arithmetic. Include the expected numerical value for the test parameters.

---

**6. [LOW] Test 5e ("winners and losers both exist") may be testing the wrong thing**

The test opens 5 longs and 5 shorts, moves PI from 50% to 80%, and asserts both winners and losers exist. With ANY correct PnL formula (raw PI or execution price), longs will win and shorts will lose when PI goes up. The 38-0 bug was not about "no losers in the event log" but about losers getting pushed into bad debt via inflated losses, making them appear as insurance claims rather than losses.

The test as described will pass with the old raw-PI formula too, since it only checks that some PnL values are positive and some negative. It does not reproduce the specific mechanism of the 38-0 bug.

**Fix:** Tighten the assertion. After closing all positions, verify that the sum of realized PnL is bounded (not wildly negative) and that no position triggers bad debt when it should not. That is the actual property that 38-0 violated.

---

### Missing Steps

- Resolve exit-side formula with Master: raw PI (LESSONS.md) or execution-adjusted exitPrice (plan's formula)
- If double-impact confirmed: scope MarginEngine constructor change, deployment script updates, and IExecutionEngine.sol interface update
- If single-impact confirmed: Phase 3 simplifies to a one-line change in MarginEngine (entryPI to entryPrice), no new dependencies, no gas increase. Rewrite Steps 4 accordingly.
- Assess gas impact of Phase 3 under the double-impact model
- Exact numerical values for test 5b assertions

---

### Edge Cases Not Covered

- **Position opened before the fix, closed after the fix:** If `pos.entryPrice` was stored correctly at open (it was, per `_storePosition`), old positions will get the new PnL formula at close. Their unrealized PnL in MarginEngine will change once Phase 3 is deployed. Verify this does not trigger unexpected liquidations on existing positions (equity shifts downward by the impact amount).
- **Impact asymmetry between open and close:** The imbalance delta can differ at close time vs open time. A position that opened in a balanced market may close in a highly imbalanced one, creating a large impact at close. With double-impact, this asymmetry is passed to the trader. With single-impact (LESSONS.md), it is not.

---

### Simpler Alternative

If Master confirms the LESSONS.md formula (single-impact, raw PI for exit):

**Phase 2 becomes:** Change line 353 from `_computePnL(pos.isLong, pi, pos.entryPI, ...)` to `_computePnL(pos.isLong, pi, pos.entryPrice, ...)`. One word change.

**Phase 3 becomes:** Change MarginEngine line 369 from `int256(pos.entryPI)` to `int256(pos.entryPrice)`. One word change. No new function, no new import, no new dependency, no gas increase.

Total code change: 2 lines in 2 files + the Phase 1 rename + tests. Effort: small, not medium.

The double-impact model is valid too, but carries significantly more complexity (new view function, new dependency chain, deployment change, gas increase). Unless Master specifically wants close-side impact charged, the simpler model matches his stated formula and avoids all Phase 3 complexity.

---

### Revised Effort Estimate

- If single-impact (LESSONS.md formula): **Small** (2-3 hours). Two one-line changes + tests.
- If double-impact (plan's formula): **Medium** (4-6 hours) as stated, plus deployment script work not currently scoped.

---

### Recommendation

**Do not send to BUILD yet.** Two items to resolve first:

1. **Master must confirm the exit-side formula.** Present both options:
   - (a) Single-impact (LESSONS.md): `PnL = direction * (current_PI - pos.entryPrice) * size`. Simpler, 2 lines changed.
   - (b) Double-impact (plan): `PnL = direction * (exitPrice - pos.entryPrice) * size`. More complete market model, but 3 files changed + new dependency chain.
   Update LESSONS.md if option (b) is chosen (the current lesson explicitly says raw PI for exit).

2. **If double-impact is chosen:** scope the MarginEngine constructor change, IExecutionEngine.sol update, and deployment script updates in the implementation steps. BUILD cannot do Phase 3 without this.

Once the exit formula is confirmed, resubmit for CRITIQUE review. If option (a) is chosen, this should approve immediately. The work is clear, scoped, and small.
