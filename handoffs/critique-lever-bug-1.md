# Critique: LEVER-BUG-1 — PnL Formula Mismatch (entryPrice vs entryPI)
## Date: 2026-03-28T15:28:00Z
## Plan reviewed: handoffs/plan-lever-bug-1.md (unchanged since 14:23 UTC)
## Supersedes: critique at 14:57 UTC (same file, pre-codebase-sync)
## Codebase verified against: /home/lever/lever-protocol @ commit 9f77cc990

---

### Verdict: REVISE

This plan is architecturally sound and correctly aligns with Master's LESSONS.md clarification. Three issues block approval: (1) the exit-side formula departs from LESSONS.md, (2) LEVER-P06 creates a Phase 2/Phase 3 ordering constraint the plan explicitly gets wrong, and (3) every line number in the plan is stale because the critique workspace symlink points to an old backup, not the actual codebase.

---

### What Is Good

- Correctly reconciles with LESSONS.md: uses `pos.entryPrice` (execution price), not `pos.entryPI` (raw PI).
- Phased approach is clean and allows incremental rollback.
- `exitPrice` is already computed at line 359 (actual) and currently discarded for PnL. Reusing it is free.
- SettlementEngine correctly scoped out as a design decision requiring Master input.
- Good test structure targeting the right properties.
- Correctly identifies that `_computePnL` parameter names are misleading and proposes rename first.

---

### Issues Found

**1. [CRITICAL] LEVER-P06 makes "ship Phase 2 without Phase 3" unsafe**

The plan says (Rollback Plan section): "if Phase 3 is complicated by circular deps, ship Phase 2 first and file Phase 3 separately."

This is no longer safe. LEVER-P06 (applied in commit 91d86cd21, verified and merged) added lines 385-389 in `_executeClose`:

```solidity
// FIX LEVER-P06: Remove this position's unrealized PnL from vault NAV tracking.
int256 currentUnrealized = leverVault.getNetUnrealizedPnL();
leverVault.updateUnrealizedPnL(currentUnrealized - pnl);
```

This subtracts the realized `pnl` from the vault's running unrealized PnL total. If Phase 2 changes `pnl` to use execution prices but Phase 3 has NOT updated MarginEngine (which computes the unrealized PnL that feeds this total), the subtraction is mismatched:

- Unrealized PnL was tracked using raw-PI formula (MarginEngine, unmodified)
- Realized PnL subtracted using execution-price formula (ExecutionEngine, Phase 2)
- Difference = impact spread per position, accumulating with every close
- Vault NAV drifts by the cumulative impact spread of all closed positions

This means Phase 2 and Phase 3 must ship TOGETHER, not separately. The rollback plan must be revised: either both phases deploy in the same transaction (upgrade proxy pattern) or Phase 3 is a prerequisite for Phase 2, not a follow-up.

The plan does not mention LEVER-P06 at all. It was written before P06 was applied.

---

**2. [CRITICAL] Exit-side formula departs from LESSONS.md**

(Unchanged from prior critique; restated because plan has not been revised.)

LESSONS.md line 101 (from Master): `PnL = direction * (current_PI - entry_execution_price) * size`

The plan's formula: `PnL = direction * (exitPrice_execution - entryPrice_execution) * size`

LESSONS.md says "The current PI from the oracle is the correct mark price" for exit. The plan uses execution-adjusted exit prices on both sides, charging the spread twice per round trip.

At 2% impact, PI = 0.50, size = $10K:
- LESSONS.md formula (single-impact): round-trip PnL = -$100
- Plan formula (double-impact): round-trip PnL = -$200

Master must confirm which is correct before BUILD starts. If LESSONS.md formula (single-impact) is chosen:
- Phase 2 becomes: swap `pos.entryPI` to `pos.entryPrice` on line 362 (actual). Keep `pi` as exit. One word change.
- Phase 3 becomes: swap `pos.entryPI` to `pos.entryPrice` on MarginEngine line 369. One word change. No new function, no new dependency, no gas increase, no circular dependency concern.
- The LEVER-P06 ordering issue (finding 1) also disappears because MarginEngine and ExecutionEngine would both change by the same delta (entryPI to entryPrice), keeping the subtraction aligned.

---

**3. [HIGH] All line numbers in the plan are stale (shifted ~9-19 lines)**

The plan was written against the old backup at `/home/lever/Lever` (commit c68e797). The actual codebase at `/home/lever/lever-protocol` (commit 9f77cc990) has LEVER-P03, P04, and P06 applied, which inserted new code and shifted line numbers:

| Plan references | Actual line (lever-protocol) | What changed |
|---|---|---|
| Line 350: exitPrice computed | **Line 359** | +9 from P03 open-fee expansion |
| Line 353: PnL computation | **Line 362** | +9 |
| Lines 364-370: bad debt waterfall | **Lines 375-383** | +11; also P04 changed `absorbBadDebt` to 3 args |
| Lines 543-553: `_computePnL` | **Lines 562-572** | +19 from P03+P04+P06 additions |
| Lines 295-305: `_executeOpen` fee code | **Lines 298-315** | Completely rewritten by P03 |

BUILD will be looking at the wrong lines. Also, the plan's Step 3 code snippet shows `feeRouter.collectTransactionFee(pos.positionSize)` at "line 358" as the closing fee; the actual code at line 370 is `pos.positionSize * TX_FEE_RATE / WAD` (already fixed by P03). The plan does not reference the P03 local fee computation.

**Fix:** Update all line references to match the actual codebase at `/home/lever/lever-protocol`. Also update the "Current Code State" section to reflect P03, P04, and P06 changes. The critique workspace symlink (`/home/lever/command/workspaces/critique/lever-protocol -> /home/lever/Lever`) should be updated to point to the actual repo.

---

**4. [HIGH] Phase 3 circular dependency: MarginEngine has no ExecutionEngine reference**

(Unchanged from prior critique.)

MarginEngine's constructor takes: `admin`, `positionManager`, `oracle`, `marketRegistry`, `borrowFeeEngine`, `fundingRateEngine`. No ExecutionEngine import, no state variable, no constructor arg.

Adding `computeHypotheticalExitPrice` requires: import + state variable + constructor change (or admin setter) + deployment script update.

However, note that `IExecutionEngine.previewExecution()` already does exactly what the proposed `computeHypotheticalExitPrice` would do (calls `_computeExecutionPrice` internally). If MarginEngine gets an ExecutionEngine reference, it can call the existing `previewExecution` instead of a new function. The plan's proposed new view function is redundant.

**This issue ONLY applies if the double-impact formula is chosen.** If single-impact (LESSONS.md formula) is chosen, Phase 3 is a one-line change with no new dependencies.

---

**5. [MEDIUM] `absorbBadDebt` signature changed in LEVER-P04**

The plan discusses bad debt routing "at line 364-370" with the old signature. The actual code at line 378:
```solidity
(, uint256 remainder) = insuranceFund.absorbBadDebt(pos.marketId, badDebt, address(leverVault));
```

Three-argument version (added `address(leverVault)` as recipient). The plan's edge case discussion references the old 2-arg interface. While this does not affect the PnL fix directly, BUILD should be aware of the changed signature when reading around the close flow.

---

**6. [MEDIUM] Test 5b zero-sum assertion is imprecise**

(Unchanged from prior critique.)

"pnl(long) + pnl(short) approximately equals -(2 * spread_cost)" is ambiguous. With double-impact on flat market:
- Long: (pi*(1-imp) - pi*(1+imp)) * size = -2*pi*imp*size
- Short: -(pi*(1+imp) - pi*(1-imp)) * size = -2*pi*imp*size
- Sum = -4*pi*imp*size

Define spread_cost explicitly in WAD arithmetic with the test parameters.

---

**7. [LOW] Test 5e does not reproduce the 38-0 mechanism**

(Unchanged from prior critique.)

Opening 5 longs and 5 shorts with PI moving 50% to 80% will always produce long winners and short losers regardless of formula. The test passes trivially with any PnL implementation. The 38-0 bug was about all positions appearing as winners (inflated profits absorbing impact), not about directional trades having the wrong sign. Tighten assertions to check that the loser side actually shows negative PnL proportional to the PI move, not just "some negative PnL exists."

---

### Missing Steps

- Account for LEVER-P06's `updateUnrealizedPnL` interaction. Either mandate Phase 2+3 atomic deployment, or (if single-impact is chosen) verify that the MarginEngine one-line change aligns the subtraction.
- Update all line references to match `/home/lever/lever-protocol` @ commit 9f77cc990.
- Resolve exit formula with Master (single-impact vs double-impact). This is the key decision that determines whether Phase 3 is trivial or complex.
- If double-impact: use existing `previewExecution` instead of adding `computeHypotheticalExitPrice`. Scope MarginEngine constructor/deployment changes.
- Note P03 and P04 changes in "Current Code State" section so BUILD sees the actual code.

---

### Edge Cases Not Covered

- **Positions opened before the fix, closed after:** The `entryPrice` stored at open is already correct (set by `_computeExecutionPrice`). But unrealized PnL for existing open positions will shift when MarginEngine changes formula. This could trigger unexpected liquidations (equity drops by the impact amount). BUILD should check: are there currently open positions on testnet? If so, how many, and what is their cumulative impact exposure?
- **LEVER-P06 vault NAV drift under partial deployment:** As described in finding 1. Not an edge case; it is a guaranteed bug if Phase 2 ships without Phase 3.

---

### Simpler Alternative

If Master confirms the LESSONS.md formula (single-impact: raw PI exit, execution price entry):

**Phase 2:** Line 362 (actual): change `pos.entryPI` to `pos.entryPrice`. One word.
**Phase 3:** MarginEngine line 369: change `pos.entryPI` to `pos.entryPrice`. One word.

No new function. No new dependency. No gas increase. No circular dependency. No interface change. Phase 2 and Phase 3 can ship together trivially, fixing the P06 ordering issue. Effort: small (2-3 hours including tests).

---

### Revised Effort Estimate

- Single-impact (LESSONS.md formula): **Small** (2-3 hours). Two one-word changes + tests.
- Double-impact (plan's formula): **Medium-Large** (6-8 hours). Includes MarginEngine constructor change, deployment script update, P06 ordering analysis, and test infrastructure for the new external call path.

---

### Recommendation

**Do not send to BUILD yet.** Three items to resolve:

1. **Master must confirm exit formula.** Single-impact (LESSONS.md: `pi - pos.entryPrice`) or double-impact (plan: `exitPrice - pos.entryPrice`). If single-impact, most of the complexity in this plan evaporates.

2. **PLAN must account for LEVER-P06.** The rollback plan's "ship Phase 2 first" option is unsafe. Phase 2 and Phase 3 must deploy together, or the vault NAV tracker drifts.

3. **PLAN must update line references** to match the actual codebase at `/home/lever/lever-protocol`. Also update the "Current Code State" section to reflect P03, P04, and P06 changes. The critique workspace symlink should be fixed.

Once these are resolved, resubmit for CRITIQUE. If single-impact is chosen and line numbers are updated, this should approve on next pass.
