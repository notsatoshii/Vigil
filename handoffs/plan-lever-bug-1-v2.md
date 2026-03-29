# Plan v2: LEVER-BUG-1 -- PnL Formula Mismatch (entryPrice vs entryPI)
## Date: 2026-03-29T07:50:00Z
## Requested by: Master (via Commander)
## Supersedes: plan-lever-bug-1.md (v1, rejected by CRITIQUE with verdict REVISE)
## Codebase: /home/lever/lever-protocol @ commit 9f77cc990

---

### Critique Issues Addressed

This revision addresses all three blocking issues from critique-lever-bug-1.md:

1. **Exit-side formula now aligned with LESSONS.md** (single-impact). The exit side uses raw oracle PI, not execution-adjusted exit price. Only the entry side uses execution price.
2. **LEVER-P06 ordering constraint resolved**. Phases 2 and 3 deploy together atomically. The rollback plan no longer allows shipping Phase 2 without Phase 3.
3. **All line numbers verified** against actual codebase at `/home/lever/lever-protocol` (commit 9f77cc990), reflecting P03, P04, and P06 changes.

---

### Problem Statement

The protocol stores two distinct price values per position:

- `entryPI` -- raw oracle probability index at open (WAD)
- `entryPrice` -- oracle PI adjusted for execution impact (long pays more, short pays less)

These differ by the impact percentage (typically 1-5%):
- Long entry: `entryPrice = entryPI * (1 + impact)` -- trader pays the ask
- Short entry: `entryPrice = entryPI * (1 - impact)` -- trader receives the bid

The ad-hoc fix (line 382, comment "FIX LEVER-001") switched to `pos.entryPI` for both entry
and exit. This removed the worst symptom (38 winners, 0 losers) but uses the wrong entry
reference. The execution price a trader pays at entry is the correct cost basis.

**Master's clarification (LESSONS.md line 100-106):**

> PnL = direction * (current_PI - entry_execution_price) * size

The current PI from the oracle is the correct mark price for exit. The entry price must be
the execution price (PI + impact adjustment). This is single-impact: the spread is charged
once at entry, and the exit uses raw oracle PI as the mark price.

The correct formula:
```
PnL = direction * (currentPI - pos.entryPrice) * size
```

Where:
- `pos.entryPrice` is already stored (set at open by `_computeExecutionPrice`)
- `currentPI` is the raw oracle PI at time of close (already fetched at line 378)

---

### Current Code State (verified against /home/lever/lever-protocol @ 9f77cc990)

**ExecutionEngine.sol line 378:** PI fetched at close:
```solidity
uint256 pi = oracleAdapter.getPI(pos.marketId);
```

**ExecutionEngine.sol line 379:** exitPrice computed but currently unused for PnL:
```solidity
(uint256 exitPrice,) = _computeExecutionPrice(pos.marketId, pos.isLong, pos.positionSize, pi, false);
```

**ExecutionEngine.sol lines 381-382:** ad-hoc fix uses raw PI for both sides (NOT final):
```solidity
// FIX LEVER-001: Use raw PI values for PnL (consistent with MarginEngine/SettlementEngine)
int256 pnl = _computePnL(pos.isLong, pi, pos.entryPI, pos.positionSize);
```

**ExecutionEngine.sol lines 406-410:** LEVER-P06 vault NAV tracking:
```solidity
// FIX LEVER-P06: Remove this position's unrealized PnL from vault NAV tracking.
int256 currentUnrealized = leverVault.getNetUnrealizedPnL();
leverVault.updateUnrealizedPnL(currentUnrealized - pnl);
```
This subtracts the realized `pnl` from vault's running unrealized total. If realized PnL
uses a different formula than unrealized PnL (MarginEngine), the subtraction is mismatched
and vault NAV drifts. This is why Phases 2 and 3 MUST deploy together.

**ExecutionEngine.sol lines 589-599:** `_computePnL` with misleading parameter names:
```solidity
function _computePnL(
    bool isLong,
    uint256 exitPrice,    // receives raw `pi` -- misleading name
    uint256 entryPrice,   // receives `pos.entryPI` -- misleading name
    uint256 positionSize
) internal pure returns (int256 pnl) {
    int256 priceDiff = int256(exitPrice) - int256(entryPrice);
    if (!isLong) priceDiff = -priceDiff;
    pnl = (priceDiff * int256(positionSize)) / int256(WAD);
}
```

**MarginEngine.sol lines 366-370:** unrealized PnL uses raw PI for both sides:
```solidity
// PnL = direction x (PI_current - PI_entry) x position_size
uint256 currentPI = oracle.getPI(pos.marketId);
int256 direction = pos.isLong ? int256(1) : int256(-1);
int256 piDelta = int256(currentPI) - int256(pos.entryPI);
result.pnl = direction * piDelta * int256(pos.positionSize) / int256(WAD);
```

**MarginEngine.sol constructor (lines 109-129):** Takes `admin`, `positionManager`, `oracle`,
`marketRegistry`, `borrowFeeEngine`, `fundingRateEngine`. No ExecutionEngine reference.

**SettlementEngine.sol lines 536-539:** settlement PnL uses raw PI:
```solidity
int256 piDiff = int256(piOutcome) - int256(pos.entryPI);
int256 direction = pos.isLong ? int256(1) : int256(-1);
ctx.outcomePnL = direction * piDiff * int256(pos.positionSize) / int256(WAD);
```

**ExecutionEngine.sol line 390:** closing fee (P03 local computation):
```solidity
uint256 closingFee = pos.positionSize * TX_FEE_RATE / WAD;
```

**ExecutionEngine.sol lines 396-403:** bad debt waterfall (P04 3-arg absorbBadDebt):
```solidity
if (badDebt > 0) {
    (, uint256 remainder) = insuranceFund.absorbBadDebt(pos.marketId, badDebt, address(leverVault));
    if (remainder > 0) {
        leverVault.socializeLoss(remainder / 1e12);
    }
    emit BadDebtRecorded(positionId, pos.owner, badDebt);
}
```

---

### Approach

Three phases in strict order. Phase 2 and Phase 3 MUST deploy together (see ordering constraint below).

**Phase 1 -- Parameter rename (cosmetic, zero risk)**
Rename misleading `_computePnL` parameters. No logic change. Compiled bytecode identical.

**Phase 2 -- Implement single-impact PnL in ExecutionEngine (the architectural fix)**
Change line 382: swap `pos.entryPI` to `pos.entryPrice`. Keep `pi` (raw oracle PI) as the
exit mark price. This is the LESSONS.md formula: `PnL = direction * (pi - pos.entryPrice) * size`.

**Phase 3 -- Update MarginEngine unrealized PnL for consistency**
Change line 369: swap `pos.entryPI` to `pos.entryPrice`. Keep `currentPI` (raw oracle PI) as
the exit mark price. One word change. No new function, no new dependency, no gas increase,
no circular dependency, no interface change.

**Phase 4 -- Assess SettlementEngine (design decision, OUT OF SCOPE)**
At market resolution, PI = 0 or 1 exactly. No trade execution at resolution. SettlementEngine
is NOT modified in this plan. BUILD must flag this for Master's decision.

### Why Phase 2 and Phase 3 Must Deploy Together

LEVER-P06 (lines 406-410) subtracts realized `pnl` from the vault's running unrealized PnL
total. The unrealized total is computed by MarginEngine. If Phase 2 changes the realized PnL
formula (entryPI to entryPrice) but Phase 3 has NOT updated MarginEngine, the subtraction is
mismatched:

- Unrealized PnL tracked using `currentPI - pos.entryPI` (MarginEngine, unmodified)
- Realized PnL subtracted using `pi - pos.entryPrice` (ExecutionEngine, Phase 2)
- Difference = impact spread per position, accumulating with every close
- Vault NAV drifts by the cumulative impact spread of all closed positions

With the single-impact formula, both changes are one-word swaps (`entryPI` to `entryPrice`).
They change both formulas by the same delta, keeping the P06 subtraction aligned.

---

### Implementation Steps

**Step 1: Run existing tests. Establish clean baseline.**

```bash
cd /home/lever/lever-protocol
forge build
forge test --match-path "test/audit/AuditFindings.t.sol" -v
forge test --match-path "test/ExecutionEngine.t.sol" -v
```

If any tests fail BEFORE touching code, diagnose and report. Do not proceed until baseline passes.

---

**Step 2: Phase 1 -- Rename `_computePnL` parameters**

In `contracts/ExecutionEngine.sol` lines 589-599, change:

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
    uint256 exitMark,
    uint256 entryMark,
    uint256 positionSize
) internal pure returns (int256 pnl) {
    int256 priceDiff = int256(exitMark) - int256(entryMark);
    if (!isLong) priceDiff = -priceDiff;
    pnl = (priceDiff * int256(positionSize)) / int256(WAD);
}
```

Run `forge build` -- must compile clean.

---

**Step 3: Phase 2 -- Switch entry reference to execution price in ExecutionEngine**

In `contracts/ExecutionEngine.sol`, `_executeClose` function, change lines 381-382:

FROM:
```solidity
// FIX LEVER-001: Use raw PI values for PnL (consistent with MarginEngine/SettlementEngine)
int256 pnl = _computePnL(pos.isLong, pi, pos.entryPI, pos.positionSize);
```

TO:
```solidity
// LEVER-BUG-1: Single-impact PnL per LESSONS.md (raw PI exit, execution price entry)
// pi = raw oracle PI at close (mark price); pos.entryPrice = execution price at open
int256 pnl = _computePnL(pos.isLong, pi, pos.entryPrice, pos.positionSize);
```

Note: `pi` (raw oracle value) remains as the exit mark price. Only the entry side changes
from `pos.entryPI` to `pos.entryPrice`. The `exitPrice` variable computed at line 379 is
still used for the `PositionClosed` event (line 418) but NOT for PnL.

Run `forge build`.

---

**Step 4: Phase 3 -- Update MarginEngine unrealized PnL for consistency**

In `contracts/MarginEngine.sol`, `_computeEquity` function, change line 369:

FROM:
```solidity
int256 piDelta = int256(currentPI) - int256(pos.entryPI);
```

TO:
```solidity
// LEVER-BUG-1: Use execution price at entry (consistent with realized PnL in ExecutionEngine)
int256 piDelta = int256(currentPI) - int256(pos.entryPrice);
```

No new function needed. No new dependency needed. No constructor change. No deployment script
change. `currentPI` (raw oracle PI) remains as the exit mark price.

Run `forge build`.

**IMPORTANT: Steps 3 and 4 must be committed and deployed together.** Do not deploy Phase 2
without Phase 3. The LEVER-P06 vault NAV tracking (ExecutionEngine lines 406-410) requires
both formulas to match. See ordering constraint section above.

---

**Step 5: Run tests and update expected values**

```bash
cd /home/lever/lever-protocol
forge test --match-path "test/ExecutionEngine.t.sol" -v
forge test --match-path "test/audit/AuditFindings.t.sol" -v
```

Some existing tests WILL fail because their expected PnL values were based on raw PI.
BUILD must update those test expected values to reflect the new formula:
- `expectedPnL = direction * (currentPI - pos.entryPrice) * size / WAD`
- Where `pos.entryPrice = entryPI * (1 + impact)` for long, `entryPI * (1 - impact)` for short

Do NOT delete failing tests. Update their expected values.

---

**Step 6: Write regression tests**

New file: `test/integration/PnLConsistency.t.sol`

Five test cases:

**6a. `testRoundTripPnLSingleImpact`**
Open a LONG at PI = 0.50 with measurable impact (depth = 100K USDT, size = 5K, so impact ~2.5%).
Immediately close at PI = 0.50 (flat market).
Expected PnL: `direction * (0.50 - 0.5125) * size = -0.0125 * size` (negative, paid entry spread).
Verify PnL < 0 and equals exactly `-(impact * entryPI * size / WAD)`.
This confirms single-impact: spread charged once at entry, not twice.

**6b. `testLongShortZeroSumSingleImpact`**
Open matched LONG and SHORT of equal size at the same PI. Apply identical impact (symmetric
market). Close both at the same PI (flat market).
Long PnL: `(pi - entryPrice_long) * size` where `entryPrice_long = pi * (1 + impact)`, so PnL = `-impact * pi * size / WAD`
Short PnL: `-(pi - entryPrice_short) * size` where `entryPrice_short = pi * (1 - impact)`, so PnL = `-impact * pi * size / WAD`
Total: `-(2 * impact * pi * size / WAD)`
Define `spread_cost = impact * pi * size / WAD` explicitly in WAD arithmetic.
Assert: `pnl_long + pnl_short == -(2 * spread_cost)` within 1e6 rounding tolerance.

**6c. `testRealizedMatchesUnrealizedAfterFix`**
Open a LONG. Snapshot unrealized PnL from MarginEngine at current PI (after Phase 3 fix).
Close the position at exactly that PI (same block if possible, or freeze PI). Verify that
realized PnL from `PositionClosed` event equals the snapshotted MarginEngine unrealized PnL
within acceptable rounding (1e6 = 1 micro-USDT). Any divergence means formula inconsistency.
This test also validates the P06 ordering constraint is satisfied.

**6d. `testRegressionRawPIEntryWouldFail`**
Using direct math only (not contract calls), show that using raw PI at entry gives a DIFFERENT
result from execution price at entry on a realistic scenario:
- entryPI = 0.50, impact_open = 2%, entryPrice = 0.51
- exitPI = 0.50 (raw oracle, used directly as mark)
- Raw formula: pnl = (0.50 - 0.50) * size = 0 (flat market, no cost visible)
- Correct formula: pnl = (0.50 - 0.51) * size = -0.01 * size (entry spread visible)
Assert that `correctPnL != 0` and equals the exact entry spread cost.
This test documents the difference and will fail if code reverts to raw PI entry.

**6e. `testWinnersAndLosersBothExist`**
Open 5 LONG and 5 SHORT positions. Move PI significantly (50% to 80%).
Close all positions. Verify the event log contains BOTH winners (longs with positive pnl)
AND losers (shorts with negative pnl). The 38 winners / 0 losers bug is directly reproduced
if this test fails.
Tighten assertions: verify the short (loser) side shows negative PnL proportional to the
PI move (`direction * (0.80 - entryPrice) * size`), not just "some negative PnL exists."

---

**Step 7: Run full test suite**

```bash
cd /home/lever/lever-protocol
forge test -v 2>&1 | tee /tmp/test-results.txt
```

All tests must pass. UPDATE failing tests whose expected values changed due to formula change.
Do NOT delete or skip failing tests; fix them.

Report test results in handoff.

---

### Files to Modify

- `contracts/ExecutionEngine.sol`
  - Lines 589-599: rename parameters (Phase 1)
  - Line 382: swap `pos.entryPI` to `pos.entryPrice` (Phase 2)

- `contracts/MarginEngine.sol`
  - Line 369: swap `pos.entryPI` to `pos.entryPrice` (Phase 3)

### Files to Create

- `test/integration/PnLConsistency.t.sol` -- 5 regression/integration tests

### Files to Read First (BUILD must read all of these)

- `contracts/ExecutionEngine.sol` lines 376-420 (full _executeClose, P06 NAV tracking)
- `contracts/ExecutionEngine.sol` lines 589-599 (_computePnL)
- `contracts/MarginEngine.sol` lines 360-389 (_computeEquity)
- `contracts/core/PositionManager.sol` lines 1-100 (Position struct: entryPI vs entryPrice)
- `contracts/SettlementEngine.sol` lines 528-545 (_computePositionSettlement, out of scope but context)
- `test/integration/IntegrationBase.sol` (test infrastructure)
- `test/integration/ClosePositionFlow.t.sol` (existing tests that will need value updates)
- `test/audit/AuditFindings.t.sol` (test_LEVER001 must still pass, values may change)

---

### Dependencies and Ripple Effects

- **`_computePnL` is `internal pure`** -- only called from `_executeClose`. Rename: zero runtime impact.
- **`pos.entryPrice`** -- already stored in PositionManager at open. No new storage needed.
- **`pi` at line 378** -- already fetched. Used directly as exit mark. No extra oracle call.
- **`exitPrice` at line 379** -- still computed for the PositionClosed event emission (line 418).
  Not used for PnL. No orphaned code.
- **LEVER-P06 (lines 406-410)** -- `updateUnrealizedPnL(currentUnrealized - pnl)` remains correct
  because Phase 2 and Phase 3 change both realized and unrealized formulas by the same delta
  (entryPI to entryPrice). The subtraction stays aligned.
- **LiquidationEngine** -- does NOT compute PnL directly. Reads equity from MarginEngine.
  After Phase 3, liquidation thresholds reflect the new formula. Direction of change: with
  execution price entry, unrealized PnL is slightly more pessimistic (spread cost visible).
  Liquidation triggers sooner on losing positions. This is correct behavior.
- **SettlementEngine** -- NOT modified. Remains on raw PI formula. BUILD must note in handoff
  that SettlementEngine is pending Master decision. See Phase 4 note.
- **No circular dependency** -- MarginEngine does not need an ExecutionEngine reference.
  The change is a one-word swap in existing code. No new imports, no constructor changes,
  no deployment script changes.
- **P03 closing fee** -- local computation at line 390 (`pos.positionSize * TX_FEE_RATE / WAD`).
  Unaffected by PnL formula change.
- **P04 absorbBadDebt** -- 3-arg signature at line 398. Unaffected by PnL formula change.
  Bad debt triggers more often with execution price entry (losers slightly more negative).
  This is correct.

---

### Edge Cases

**Zero impact (small positions):** When `positionSize << marketDepth`, impact approaches 0.
`entryPrice ~ entryPI`. The new formula degrades gracefully to the old formula.
Tests must use realistic sizes with non-zero impact to distinguish the formulas.

**Maximum impact (huge positions):** `impact` is capped at `MAX_IMPACT`. The formula still
holds; the cap prevents division-level weirdness.

**PI at extremes near resolution (0.95, 0.99):** At high PI values, a small impact percentage
still represents significant absolute PnL difference. Test with PI near 0.95 and long position.

**Negative equity on close:** The new formula makes losing positions slightly MORE negative
(they paid the spread on entry). Bad debt detection at lines 396-403 triggers more often.
This is correct. The insurance fund and socialization logic are unchanged.

**Flat market round trip:** Open and immediately close at same PI. PnL will be negative
(entry spread cost only, single-impact). This is EXPECTED and CORRECT.

**Positions opened before the fix, closed after:** The `entryPrice` stored at open is already
correct (set by `_computeExecutionPrice`). `entryPI` is also stored. The fix only changes
which stored value is read at close. Existing open positions will see their unrealized PnL
shift when MarginEngine changes formula (equity drops by the impact amount per position).
This could trigger unexpected liquidations if positions are near the liquidation threshold.
BUILD should check: are there currently open positions on testnet? If so, how many, and what
is their cumulative impact exposure? If any are near liquidation, flag for Master.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `testRoundTripPnLSingleImpact` | Entry spread charged, exit uses raw PI |
| `testLongShortZeroSumSingleImpact` | Total drain is exactly 2x entry spread, bounded and predictable |
| `testRealizedMatchesUnrealizedAfterFix` | MarginEngine and ExecutionEngine PnL agree (P06 safe) |
| `testRegressionRawPIEntryWouldFail` | Documents bug, catches reversion to raw PI entry |
| `testWinnersAndLosersBothExist` | The 38 winners / 0 losers symptom does not recur |

---

### Effort Estimate

**Small** -- 2-3 hours.
- Phase 1 (rename): 15 minutes
- Phase 2 (ExecutionEngine one-word change + test updates): 30-45 minutes
- Phase 3 (MarginEngine one-word change): 15 minutes
- Regression tests: 1 hour
- Full test suite run and cleanup: 30 minutes

---

### Rollback Plan

**Phase 1 rollback:** Revert parameter rename in `_computePnL`. Bytecode-identical change.

**Phase 2+3 rollback (atomic):** Revert line 382 back to `pos.entryPI` AND revert MarginEngine
line 369 back to `pos.entryPI`. Both changes must revert together to keep P06 subtraction
aligned. Do NOT revert Phase 2 without also reverting Phase 3.

**CRITICAL: Phase 2 must NEVER ship without Phase 3.** The LEVER-P06 vault NAV tracking
(lines 406-410) requires both formulas to use the same entry reference. Shipping Phase 2 alone
causes vault NAV drift proportional to the cumulative impact spread of all closed positions.

---

### Open Questions for Master

1. **SettlementEngine formula:** At market resolution (PI = 0 or 1), should settlement PnL use:
   - (a) raw piOutcome against pos.entryPI (current behavior)
   - (b) raw piOutcome against pos.entryPrice (half-MTM; recommended)
   - (c) Full MTM is not applicable (there is no execution price at resolution)
   The plan recommends option (b). Winners paid the spread on entry; resolution should reflect it.
   But this requires Master's explicit sign-off before BUILD touches SettlementEngine.

---

### KANBAN Update

Move LEVER-BUG-1 to PLANNED. This plan supersedes plan-lever-bug-1.md (v1).
