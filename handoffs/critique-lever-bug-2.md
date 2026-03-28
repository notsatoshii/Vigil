# Critique: LEVER-BUG-1 — PnL Formula Mismatch (entryPrice vs entryPI)
## Date: 2026-03-28T14:05:00Z
## Plan reviewed: handoffs/plan-20260328-133419.md
## Supersedes: prior critique at same path (written 13:50 UTC, pre-code-verification)
## Routing note: This is the LEVER-BUG-1 plan. The KANBAN also lists LEVER-BUG-1 at plan-20260328-133501.md (a later revision with Master's CRITICAL UPDATE). Commander routed the earlier, un-amended version here. PLAN and Commander should verify which version is canonical.

---

### Verdict: REVISE

---

### What Is Good

- Correctly identifies the misleading `entryPrice` parameter name in `_computePnL` as a readability hazard.
- Right instinct to formalize the ad-hoc fix through the pipeline with tests.
- Test categories (round-trip, zero-sum, cross-engine consistency) are the right structure.
- Correctly limits code changes to ExecutionEngine.sol.

---

### Issues Found

**1. [CRITICAL] The plan contradicts LESSONS.md (marked "from Master") and has the fix direction backwards**

LESSONS.md line 100, explicitly labeled "CRITICAL, from Master":

> "PnL = direction * (current_PI - entry_execution_price) * size. The entry price stored on-chain must be the execution price (PI + impact adjustment from ExecutionEngine), not the raw oracle PI at time of entry. The bug was that the code used raw PI at entry instead of the impact-adjusted execution price, making every position appear profitable because the spread was not captured."

The plan says the opposite: raw oracle PI (`pos.entryPI`) is correct, impact-adjusted execution price (`pos.entryPrice`) was the bug. The ad-hoc fix at line 353 uses `pos.entryPI` (raw oracle PI). According to LESSONS.md, this IS the original bug, not the fix.

I verified the actual storage in `_storePosition` (ExecutionEngine.sol lines 325-338):
```solidity
positionManager.createPosition(
    ...
    ctx.pi,           // stored as pos.entryPI  -- raw oracle PI
    ctx.entryPrice,   // stored as pos.entryPrice -- impact-adjusted execution price
    ...
)
```

`ctx.entryPrice` is returned by `_computeExecutionPrice`, which applies directional pricing:
- Open LONG: `price = pi * (1 + impact)` — higher than oracle
- Open SHORT: `price = pi * (1 - impact)` — lower than oracle

So `pos.entryPI` is raw oracle PI. `pos.entryPrice` is what the trader actually paid/received.

**The economic consequence of using raw entryPI**: Every position opens with an implicit phantom credit equal to the impact spread. A long that paid execution price of 0.51 gets a PnL reference of 0.50. That 0.01 * size is credited on paper — it comes from somewhere (the vault). Using entryPI (raw) gives EVERY trader a free spread on every position. This directly explains "38 winners, 0 losers" — not because losers were pushed into bad debt, but because everyone's entry reference was shifted favorably, making borderline losses disappear.

Using `entryPrice` (execution price) would do the opposite: it bakes the spread cost in, so traders must overcome impact before they profit. That creates MORE losers, not fewer.

The plan's causality is inverted. The ad-hoc fix at line 353 must not be approved until this is resolved.

The amended plan (plan-20260328-133501.md) contains a CRITICAL UPDATE FROM MASTER that explicitly confirms this:
> "CORRECT: entry_price = execution price AFTER impact adjustment. WRONG: entry_price = raw PI from oracle at time of entry. BUILD must verify that PositionManager stores the execution price (not raw PI) as entryPI."

The file being critiqued (plan-20260328-133419.md) predates this amendment and does not contain it. PLAN should have submitted the amended version (133501.md) for CRITIQUE, not the earlier one.

**Fix required:** Return to PLAN. Reconcile with the CRITICAL UPDATE. The revised plan must confirm that `pos.entryPrice` is the correct reference, then specify whether:
- (a) `_executeClose` should call `_computePnL(..., pos.entryPrice, ...)` instead of `pos.entryPI`, OR
- (b) `_storePosition` should write `ctx.entryPrice` as `entryPI` (making the field semantically correct for all downstream readers)

Option (b) is simpler — one line change in storage, all engines remain unchanged.

---

**2. [CRITICAL] MarginEngine and SettlementEngine are called "correct references" — they are likely also broken**

The plan cites MarginEngine line 369 and SettlementEngine line 534 as correct reference implementations because they use `pos.entryPI`. I read both. Both use raw oracle PI for PnL.

If LESSONS.md is correct (entryPrice is the right reference), then all three engines compute PnL incorrectly in the same direction. Citing three consistent-but-wrong implementations as mutual proof of correctness is not evidence of correctness.

Specific consequence for test 3c ("realized PnL == unrealized PnL"): if the fix at line 353 uses `pos.entryPI` and MarginEngine also uses `pos.entryPI`, the test passes trivially because both are wrong in the same way. The test proves self-consistency, not correctness. It cannot detect the actual bug.

**Fix required:** If the correct formula uses `pos.entryPrice` (execution price), MarginEngine._computeEquity line 369 and SettlementEngine line 534 also need to change. The plan must scope them in. If the storage fix path (b) is chosen, they change for free since they read from `pos.entryPI` which would then hold the right value.

---

**3. [HIGH] PositionManager storage assignment was not checked — Master explicitly required this**

Master's CRITICAL UPDATE: "BUILD must verify that PositionManager stores the execution price (not raw PI) as entryPI."

The plan does not direct BUILD to check `_storePosition`. It lists PositionManager.sol as a file to read "for the Position struct" but the storage assignment is in ExecutionEngine.sol lines 325-338 — and the plan does not list that section for reading.

I read the code. Result: `pos.entryPI` = raw oracle PI, `pos.entryPrice` = execution price. If Master wants the execution price stored as `entryPI`, that assignment must change. The plan is silent on this.

---

**4. [MEDIUM] Regression test 3d validates the wrong formula**

Test 3d: "assert that only the `entryPI` path gives the expected $500 PnL."

Numbers used: entryPI = 0.50, entryPrice = 0.51, exitPI = 0.55, size = 10000 USDT.
- entryPI path: (0.55 - 0.50) * 10000 = $500
- entryPrice path: (0.55 - 0.51) * 10000 = $400

The test asserts $500 is correct. But if execution price is the right reference, $400 is correct (the trader paid 0.51, PI moved to 0.55, net gain is 0.04, not 0.05). The test would lock in inflated PnL as "correct" and prevent any future fix from merging.

A regression guard that enshrines the wrong answer is worse than no test at all.

---

**5. [MEDIUM] `pos.entryPrice` field purpose after this change is undefined**

If all PnL calculations use `pos.entryPI`, then `pos.entryPrice` is stored on-chain but read by no contract. The Position struct pays for it in storage gas permanently. More importantly, it becomes a trap: the next engineer who reads the struct sees a field named `entryPrice` and assumes it has PnL significance — which causes exactly the bug this plan claims to fix.

PLAN must state what `entryPrice` is for after this change. If nothing uses it contractually, it should be removed from the struct in this same PR.

---

**6. [LOW] The plan submitted for CRITIQUE was not the current version**

KANBAN PLANNED section: "LEVER-BUG-1: plan: handoffs/plan-20260328-133501.md"

This critique reviewed plan-20260328-133419.md (earlier, without Master's amendment). If 133501 is the KANBAN-approved version, CRITIQUE was handed the wrong file. The amended version partially corrects issue 1 by adding the CRITICAL UPDATE, but its implementation steps still direct BUILD to use `pos.entryPI` (they were not updated to match the amendment). The amendment is appended but the plan body contradicts it. A revision is needed either way.

---

### Missing Steps

- Read `_storePosition` (ExecutionEngine.sol 325-338) and explicitly state what is assigned to `entryPI` vs `entryPrice` at position open.
- Decide fix path: reading-side fix (use `pos.entryPrice` in all three engines) or storage-side fix (write `ctx.entryPrice` as `entryPI` in `_storePosition`).
- If reading-side fix: add MarginEngine._computeEquity (line 369) and SettlementEngine line 534 to files-to-modify.
- If storage-side fix: add `_storePosition` to files-to-modify; verify Position struct field naming.
- Rewrite test 3d to assert the execution-price formula gives the expected PnL, not the raw-PI formula.
- State disposition of `pos.entryPrice` field after the change.
- Cross-reference LEVER-BUG-2: the vault drain may be the cumulative effect of crediting every position with the impact spread at open. If so, fixing LEVER-BUG-1 correctly (using execution price as reference) may reduce or explain part of the LEVER-BUG-2 drain. Analyze before treating them as fully independent.

---

### Edge Cases Not Covered

- **Maximum impact (depth = 0)**: `_computeExecutionPrice` applies `MAX_IMPACT` when depth is zero (line 452-453 of ExecutionEngine.sol). At max impact, entryPrice diverges maximally from entryPI. The error in PnL is largest at this boundary. No test covers it.
- **Short position direction**: Impact goes the other way for shorts (entryPrice < entryPI). Using entryPI gives shorts a favorable phantom discount too. Test 3a only covers LONG. Add an equivalent SHORT test.
- **Market resolution (PI = 0 or 1)**: At PI = 1 for a LONG, difference between entryPI and entryPrice paths is (entryPrice - entryPI) * size. At typical 1-5% impact, this is 1-5% of notional. For large positions, this is material. Tests should cover resolution outcomes.

---

### Simpler Alternative

If the storage-side fix path is chosen:

Change one line in `_storePosition` from passing `ctx.pi` to passing `ctx.entryPrice` as the `entryPI` argument to `positionManager.createPosition`. All downstream engines (MarginEngine, SettlementEngine, ExecutionEngine) already read `pos.entryPI` and compute PnL from it. With the correct value stored there, all three are fixed simultaneously with a single line change.

The parameter rename in `_computePnL` becomes meaningful: rename the field to `entryExecutionPI` (or just `entryPI` is fine since it now holds the right thing). No engine logic changes. No new inconsistency between unrealized and realized PnL.

This path requires one additional consideration: the `entryPI` field on the Position struct currently documents "raw PI from oracle at time of open." The struct NatSpec or comments would need updating to reflect "execution price at time of open." Small, but must not be skipped.

---

### Revised Effort Estimate

Still small once the economic question is resolved. The resolution (reading the actual code + running a numerical check on one historical position) is 1-2 hours of PLAN work. Do not send to BUILD until PLAN completes that analysis and updates the plan document to be internally consistent (implementation steps must match the CRITICAL UPDATE).

---

### Recommendation

**Do not send to BUILD.**

Return to PLAN with these specific requirements:

1. Reconcile the implementation steps with the CRITICAL UPDATE FROM MASTER in plan-133501. The current implementation steps direct BUILD to use `pos.entryPI` (raw PI). The CRITICAL UPDATE says execution price is correct. These contradict. Fix the plan body to match the amendment.

2. Choose fix path (reading-side or storage-side) and scope accordingly. Storage-side is simpler and touches fewer files.

3. Rewrite test 3d to prove the execution-price formula is correct, not raw PI.

4. State disposition of `pos.entryPrice` field (used by frontend only? remove from struct?).

Once PLAN resubmits with a consistent plan, this should approve quickly. The code changes themselves are small.
