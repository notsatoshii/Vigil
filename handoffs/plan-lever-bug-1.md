# Plan: LEVER-BUG-1 — PnL Formula Mismatch (entryPrice vs entryPI)
## Date: 2026-03-28T13:45:00Z
## Requested by: Master (via Commander)
## Supersedes: plan-20260328-133501.md (earlier draft — incomplete, pre-Master clarification)

---

### Problem Statement

The protocol stores two distinct price values per position:

- `entryPI` — raw oracle probability index at open (WAD)
- `entryPrice` — oracle PI adjusted for execution impact (long pays more, short pays less)

These differ by the impact percentage (typically 1-5%):
- Long entry: `entryPrice = entryPI * (1 + impact)` — trader pays the ask
- Short entry: `entryPrice = entryPI * (1 - impact)` — trader receives the bid

The ORIGINAL bug in `ExecutionEngine._executeClose` used `pos.entryPrice` (impact-adjusted)
for the exit PnL but compared it against raw `pi` (unadjusted oracle) on close. This created
a systematic discrepancy: losers received inflated losses (penalized by double impact), equity
went negative, triggered the insurance fund waterfall, and appeared as "zero losers" — while
winners remained on the books. Result: 38 winners, 0 losers.

An ad-hoc fix was applied (line 353, comment "FIX LEVER-001") that switched to `pos.entryPI`.
This reduced the asymmetry but is NOT the correct architectural solution.

**Master's clarification (recorded in LESSONS.md line 100-106):**

> PnL must be calculated using the mark-to-market (MTM) price and entry price, NOT the raw
> oracle PI. The execution price a trader pays includes the imbalance-delta impact. Using raw PI
> ignores this cost. The whitepaper formula may be wrong.

The correct formula is:
```
PnL = direction * (exitPrice_execution_adjusted - entryPrice_execution_adjusted) * size
```

Where:
- `entryPrice` is already stored in `pos.entryPrice` (set at open by `_computeExecutionPrice`)
- `exitPrice` must be computed at close by calling `_computeExecutionPrice` (already done on
  line 350 — result is computed but currently discarded for PnL purposes)

---

### Current Code State (READ before touching anything)

**ExecutionEngine.sol line 350:** exitPrice is computed but not used for PnL:
```solidity
(uint256 exitPrice,) = _computeExecutionPrice(pos.marketId, pos.isLong, pos.positionSize, pi, false);
```

**ExecutionEngine.sol line 353:** ad-hoc fix uses raw PI (intermediate fix, NOT final):
```solidity
// FIX LEVER-001: Use raw PI values for PnL (consistent with MarginEngine/SettlementEngine)
int256 pnl = _computePnL(pos.isLong, pi, pos.entryPI, pos.positionSize);
```

**ExecutionEngine.sol lines 543-553:** `_computePnL` has misleading parameter names:
```solidity
function _computePnL(
    bool isLong,
    uint256 exitPrice,    // receives raw `pi` — misleading
    uint256 entryPrice,   // receives `pos.entryPI` — misleading
    uint256 positionSize
) internal pure returns (int256 pnl) {
    int256 priceDiff = int256(exitPrice) - int256(entryPrice);
    if (!isLong) priceDiff = -priceDiff;
    pnl = (priceDiff * int256(positionSize)) / int256(WAD);
}
```

**MarginEngine.sol lines 366-370:** unrealized PnL uses raw PI (will diverge from realized
PnL after this fix — must be updated in Phase 3):
```solidity
int256 piDelta = int256(currentPI) - int256(pos.entryPI);
result.pnl = direction * piDelta * int256(pos.positionSize) / int256(WAD);
```

**SettlementEngine.sol lines 534-536:** settlement PnL uses raw PI (Phase 4 — assess separately):
```solidity
int256 piDiff = int256(piOutcome) - int256(pos.entryPI);
ctx.outcomePnL = direction * piDiff * int256(pos.positionSize) / int256(WAD);
```

---

### Approach

Four phases in strict order. Do NOT skip ahead.

**Phase 1 — Parameter rename (cosmetic, zero risk)**
Rename misleading `_computePnL` parameters to match what is actually passed. No logic change.
Compiled bytecode is identical. Purpose: prevent this bug class from recurring via naming confusion.

**Phase 2 — Implement MTM PnL in ExecutionEngine (the architectural fix)**
Change line 353 to use `exitPrice` (already computed at line 350) and `pos.entryPrice` (already
stored in position). This is the formula Master specified. The PnL now correctly charges traders
for the bid-ask spread they pay at open AND at close.

**Phase 3 — Update MarginEngine unrealized PnL for consistency**
After Phase 2, realized PnL and unrealized PnL use different formulas. A position opened at
`entryPrice` and measured unrealized against raw `currentPI` will show more optimistic unrealized
PnL than it will realize on close. This creates confusion and can affect liquidation decisions.
Fix: compute a hypothetical `exitPrice` in MarginEngine and use `(exitPrice - pos.entryPrice)`.

**Phase 4 — Assess SettlementEngine (design decision required)**
At market resolution, PI = 0 or 1 exactly. There is no trade execution at resolution — no market
maker, no impact, no spread. The settlement price IS the oracle outcome. Therefore:
- Using execution prices for settlement is arguable but potentially wrong (there IS no spread at resolution)
- Using raw piOutcome against `pos.entryPrice` (not entryPI) is a middle ground
- This is a protocol-level design decision, not a bug fix

SettlementEngine is OUT OF SCOPE for this plan. BUILD must flag this for Master's decision before touching it.

---

### Implementation Steps

**Step 1: Run existing tests first. Establish a clean baseline.**

```bash
cd /home/lever/Lever
forge build
forge test --match-path "test/audit/AuditFindings.t.sol" -v
forge test --match-path "test/ExecutionEngine.t.sol" -v
```

If any tests fail BEFORE touching code, diagnose and report. Do not proceed until baseline passes.

---

**Step 2: Phase 1 — Rename `_computePnL` parameters**

In `contracts/ExecutionEngine.sol` lines 543-553, change:

```solidity
function _computePnL(
    bool isLong,
    uint256 exitPrice,
    uint256 entryPrice,
    uint256 positionSize
) internal pure returns (int256 pnl) {
    int256 priceDiff = int256(exitPrice) - int256(entryPrice);
    if (!isLong) priceDiff = -priceDiff;
    pnl = (priceDiff * int256(positionSize)) / int256(WAD);
}
```

To:

```solidity
function _computePnL(
    bool isLong,
    uint256 exitMTM,
    uint256 entryMTM,
    uint256 positionSize
) internal pure returns (int256 pnl) {
    int256 priceDiff = int256(exitMTM) - int256(entryMTM);
    if (!isLong) priceDiff = -priceDiff;
    pnl = (priceDiff * int256(positionSize)) / int256(WAD);
}
```

Run `forge build` — must compile clean.

---

**Step 3: Phase 2 — Switch PnL to use execution prices**

In `contracts/ExecutionEngine.sol`, `_executeClose` function, change line 353:

FROM:
```solidity
// FIX LEVER-001: Use raw PI values for PnL (consistent with MarginEngine/SettlementEngine)
int256 pnl = _computePnL(pos.isLong, pi, pos.entryPI, pos.positionSize);
```

TO:
```solidity
// LEVER-BUG-1: Use execution prices for PnL (MTM formula per Master spec)
// exitPrice already computed at line 350 using _computeExecutionPrice
// pos.entryPrice stored at open by _storePosition
int256 pnl = _computePnL(pos.isLong, exitPrice, pos.entryPrice, pos.positionSize);
```

The `exitPrice` variable is already declared at line 350. No additional computation needed.
The `pos.entryPrice` field is already populated by `_storePosition` via `ctx.entryPrice`.

Run `forge build`. Then run:
```bash
forge test --match-path "test/ExecutionEngine.t.sol" -v
```

Some existing tests WILL fail because their expected PnL values were based on raw PI.
BUILD must update those test expected values to reflect the new formula:
- `expectedPnL = direction * (exitPrice - pos.entryPrice) * size / WAD`
- Where `exitPrice = pi * (1 - impact)` for long close, `pi * (1 + impact)` for short close

Do NOT delete failing tests. Update their expected values.

---

**Step 4: Phase 3 — Update MarginEngine unrealized PnL**

In `contracts/MarginEngine.sol`, `_computeEquity` function (lines 360-389):

The function does not currently call `_computeExecutionPrice`. It must compute a hypothetical
exit price to measure unrealized PnL in the same terms as realized PnL.

Change the PnL calculation block (lines 366-370) from:
```solidity
uint256 currentPI = oracle.getPI(pos.marketId);
int256 direction = pos.isLong ? int256(1) : int256(-1);
int256 piDelta = int256(currentPI) - int256(pos.entryPI);
result.pnl = direction * piDelta * int256(pos.positionSize) / int256(WAD);
```

To:
```solidity
uint256 currentPI = oracle.getPI(pos.marketId);
int256 direction = pos.isLong ? int256(1) : int256(-1);
// Unrealized PnL uses hypothetical exit price (MTM formula, consistent with realized PnL)
uint256 hypotheticalExitPrice = executionEngine.computeHypotheticalExitPrice(
    pos.marketId, pos.isLong, pos.positionSize, currentPI
);
int256 priceDelta = int256(hypotheticalExitPrice) - int256(pos.entryPrice);
result.pnl = direction * priceDelta * int256(pos.positionSize) / int256(WAD);
```

This requires a NEW view function on ExecutionEngine:

```solidity
/// @notice Compute hypothetical exit price for a position (for unrealized PnL)
/// @dev View only — does not modify state
function computeHypotheticalExitPrice(
    bytes32 marketId,
    bool isLong,
    uint256 positionSize,
    uint256 pi
) external view returns (uint256 exitPrice) {
    (exitPrice,) = _computeExecutionPrice(marketId, isLong, positionSize, pi, false);
}
```

**IMPORTANT NOTE on `computeHypotheticalExitPrice`:** `_computeExecutionPrice` reads current OI
from `oiLimits` (for imbalance delta). The hypothetical exit uses CURRENT OI (before the position
closes). This slightly understates the impact vs the actual close (which would update OI first in
some implementations). This is an acceptable approximation for a view function.

**IMPORTANT NOTE on circular dependency:** MarginEngine calling ExecutionEngine must be verified
against the deployment graph. If MarginEngine is deployed before ExecutionEngine (or holds an
immutable reference), BUILD must check whether a new getter on ExecutionEngine creates a circular
import. If it does, extract `_computeExecutionPrice` logic into a shared library or a
`PriceImpactLib` that both contracts import.

BUILD must read the constructor/deployment order before implementing this step.

---

**Step 5: Write regression tests**

New file: `test/integration/PnLConsistency.t.sol`

Five test cases:

**5a. `testRoundTripPnLMTM`**
Open a LONG at PI = 0.50 with measurable impact (depth = 100K USDT, size = 5K, so impact ~2.5%).
Immediately close at PI = 0.50 (flat market). Expected PnL is NEGATIVE (you paid the spread).
Exact expected: `pnl = exitPrice - entryPrice` where both reflect the impact.
Verify PnL != 0 (raw formula would give 0 for flat). This confirms the spread is being charged.

**5b. `testLongShortZeroSumMTM`**
Open matched LONG and SHORT of equal size at the same PI. Apply identical impact (symmetric
market). Move PI by delta. Close both. Verify: `pnl(long) + pnl(short) ≈ -(2 * spread_cost)`.
The sum should be negative (both sides paid spread), but with well-matched OI, total drain should
be bounded and predictable. If the formula is wrong, the sum will be random or highly negative.

**5c. `testRealizedMatchesUnrealizedAfterFix`**
Open a LONG. Snapshot unrealized PnL from MarginEngine at current PI (after Phase 3 fix).
Close the position at exactly that PI (same block if possible, or freeze PI). Verify that
realized PnL from `PositionClosed` event equals the snapshotted MarginEngine unrealized PnL
within acceptable rounding (1e6 = 1 micro-USDT). Any divergence means formula inconsistency.

**5d. `testRegressionRawPIWouldFail`**
Using direct math only (not contract calls), show that using raw PI gives a DIFFERENT result
from execution prices on a realistic scenario:
- entryPI = 0.50, impact_open = 2%, entryPrice = 0.51
- exitPI = 0.50, impact_close = 2%, exitPrice = 0.49
- Raw formula: pnl = 0 (flat market)
- MTM formula: pnl = (0.49 - 0.51) * size = -0.02 * size (paid the spread)
Assert that `correctPnL != 0` and equals the exact spread cost. This test documents the difference
and will fail if code reverts to raw PI.

**5e. `testWinnersAndLosersBothExist`**
Open 5 LONG and 5 SHORT positions. Settle with PI moving significantly (50% to 80%).
Verify the event log contains BOTH winners (longs with positive pnl) AND losers (shorts with
negative pnl). The 38 winners / 0 losers bug is directly reproduced if this test fails.

---

**Step 6: Run full test suite**

```bash
forge test -v 2>&1 | tee /tmp/test-results.txt
```

All tests must pass. UPDATE failing tests whose expected values changed due to formula change.
Do NOT delete or skip failing tests — fix them.

Report test results in handoff.

---

### Files to Modify

- `contracts/ExecutionEngine.sol`
  - Lines 543-553: rename parameters (Phase 1)
  - Line 353: switch to `exitPrice` and `pos.entryPrice` (Phase 2)
  - Add `computeHypotheticalExitPrice` view function (Phase 3 dependency)

- `contracts/MarginEngine.sol`
  - Lines 366-370: switch to MTM formula with hypothetical exit price (Phase 3)

### Files to Create

- `test/integration/PnLConsistency.t.sol` — 5 regression/integration tests

### Files to Read First (BUILD must read all of these)

- `contracts/ExecutionEngine.sol` lines 325-560 (full close, computeExecutionPrice, computePnL)
- `contracts/MarginEngine.sol` lines 355-420 (computeEquity, full context)
- `contracts/core/PositionManager.sol` lines 1-100 (Position struct, entryPI vs entryPrice)
- `test/integration/IntegrationBase.sol` (test infrastructure)
- `test/integration/ClosePositionFlow.t.sol` (existing tests that will need value updates)
- `test/audit/AuditFindings.t.sol` (test_LEVER001 must still pass, values may change)

---

### Dependencies and Ripple Effects

- **`_computePnL` is `internal pure`** — only called from `_executeClose`. Rename: zero runtime impact.
- **`exitPrice` at line 350** — already computed before line 353. Reusing it is free. No extra oracle call.
- **`pos.entryPrice`** — already stored in PositionManager at open. No new storage needed.
- **LiquidationEngine** — does NOT compute position PnL directly. Reads equity from MarginEngine.
  After Phase 3 (MarginEngine update), liquidation thresholds will reflect the new MTM formula.
  The direction of change: with execution prices, unrealized PnL is slightly MORE pessimistic
  (you see the spread cost). Liquidation triggers sooner on losing positions. This is correct behavior.
- **SettlementEngine** — NOT modified in this plan (see Phase 4 note above). Leave as-is.
  BUILD must note in handoff that SettlementEngine remains on raw PI formula pending Master decision.
- **Circular dependency check** — MarginEngine calling ExecutionEngine.computeHypotheticalExitPrice
  must be checked against deployment order. See Step 4 note.

---

### Edge Cases

**Zero impact (small positions):** When `positionSize << marketDepth`, impact approaches 0.
`entryPrice ≈ entryPI` and `exitPrice ≈ pi`. The MTM formula degrades gracefully to the raw
formula. Tests must use realistic sizes with non-zero impact to distinguish the formulas.

**Maximum impact (huge positions):** `impact` is capped at `MAX_IMPACT`. The formula still
holds; the cap prevents division-level weirdness.

**PI at extremes near resolution (0.95, 0.99):** At high PI values, a small impact percentage
still represents significant absolute PnL difference. Test with PI near 0.95 and long position.

**Negative equity on close:** The MTM formula makes losing positions MORE negative (they pay
the spread twice). This means bad debt detection at lines 364-370 triggers more often. This is
correct. The insurance fund and socialization logic are unchanged.

**Flat market round trip:** Open and immediately close at same PI. PnL will be negative (spread
cost). This is EXPECTED and CORRECT behavior. Tests should not assert PnL = 0 for round trips.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `testRoundTripPnLMTM` | Spread is charged on round-trip (flat market PnL < 0) |
| `testLongShortZeroSumMTM` | No unexpected asymmetry; total drain is bounded |
| `testRealizedMatchesUnrealizedAfterFix` | MarginEngine and ExecutionEngine PnL agree |
| `testRegressionRawPIWouldFail` | Documents bug, catches reversion to raw PI |
| `testWinnersAndLosersBothExist` | The 38 winners / 0 losers symptom does not recur |

---

### Effort Estimate

**Medium** — 4-6 hours.
- Phase 1 (rename): 15 minutes
- Phase 2 (ExecutionEngine PnL change + test updates): 1-2 hours
- Phase 3 (MarginEngine + new view function + circular dep check): 2-3 hours
- Phase 4 tests: 1 hour

---

### Rollback Plan

**Phase 1 rollback:** Revert parameter rename in `_computePnL`. Bytecode-identical change.

**Phase 2 rollback:** Revert line 353 back to `_computePnL(pos.isLong, pi, pos.entryPI, pos.positionSize)`.
The `exitPrice` variable at line 350 was already being computed before this bug fix. No orphaned code.

**Phase 3 rollback:** Revert MarginEngine to raw PI formula. Remove `computeHypotheticalExitPrice`
from ExecutionEngine interface if unused.

Critical: the Phase 2 change (line 353) is the most important. Phase 3 (MarginEngine) is
secondary — if Phase 3 is complicated by circular deps, ship Phase 2 first and file Phase 3 separately.

---

### Open Questions for Master

1. **SettlementEngine formula:** At market resolution (PI = 0 or 1), should settlement PnL use:
   - (a) raw piOutcome against pos.entryPI (current behavior)
   - (b) raw piOutcome against pos.entryPrice (half-MTM)
   - (c) Full MTM is not applicable (there is no execution price at resolution)
   The plan recommends option (b) — winners paid the spread on entry, resolution should charge them for it.
   But this requires Master's explicit sign-off before BUILD touches SettlementEngine.

2. **Circular dependency:** If MarginEngine calling ExecutionEngine creates a deployment cycle,
   should the impact calculation be extracted to a shared `PriceImpactLib`? Or should MarginEngine
   hold a direct reference to an `IPriceImpact` interface? Flag this in the handoff and await direction.

---

### KANBAN Update

Move LEVER-BUG-1 to PLANNED. This plan supersedes plan-20260328-133501.md.
