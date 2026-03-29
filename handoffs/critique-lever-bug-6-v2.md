# Critique v2: LEVER-BUG-6 -- FeeRouter Called Without USDT by Liquidation/Settlement
## Date: 2026-03-29T09:00:00Z
## Plan reviewed: handoffs/plan-lever-bug-6-v2.md
## Codebase verified against: /home/lever/lever-protocol/contracts/

---

### Verdict: APPROVE

The revised plan correctly addresses the critical SettlementEngine vault funding deficit identified in critique v1. The key design decision (separate vault calls for profit and fee) eliminates all edge cases cleanly. All numeric traces verify. This is ready for BUILD.

---

### What Is Good

1. **The v1 critique issue is fully resolved.** The original critique found that the vault funded only `profit` (net delta), leaving a per-settlement fee-sized USDT deficit. v2 separates profit funding and fee funding into independent `fundTraderPnL` calls. The fee call is unconditional on delta sign, so it works regardless of whether the winner has positive, negative, or zero delta.

2. **All line numbers verified against actual codebase:**
   - LiquidationEngine._closeAndSettle: lines 397-415. Confirmed exact match.
   - LiquidationEngine._executeLiquidation call site: line 348. Confirmed.
   - LiquidationEngine._routeFee: lines 419-436. Confirmed.
   - SettlementEngine.claimSettlement: lines 261-280. Confirmed exact match.
   - ExecutionEngine._settlePnL: lines 428-481. Confirmed.
   - AccountManager functions: lines 92-129. Confirmed (lockCollateral, releaseCollateral, creditPnL, debitPnL, transferOut).
   - LeverVault.fundTraderPnL: line 321, requires EXECUTION_ENGINE_ROLE. Confirmed.

3. **All seven numeric traces verified correct.** Each trace ends with AM USDT matching sum of internal balances:
   - Trace A (winner, delta > 0): 698 = 698
   - Trace B (loser): 50 = 50
   - Trace C (winner, delta < 0, fees exceed gains): 194 = 194
   - Trace D (winner, delta = 0): 200 = 200
   - Trace E (void): 200 = 200
   - Trace F (loser, zero equity): 0 = 0
   - Trace G (loser, bad debt): 0 = 0

4. **Self-correction within the plan is transparent and sound.** The plan shows the thought process of discovering the delta < 0 edge case, then arriving at the cleaner "separate calls" solution. This makes it easy for BUILD to understand the design rationale.

5. **LiquidationEngine fix is unchanged from v1 and was already approved in critique v1.** The fee subtraction from vault-bound loss is correct.

6. **Correct identification of role grant requirement.** SettlementEngine needs EXECUTION_ENGINE_ROLE on LeverVault (Step 4). The plan flags this clearly.

7. **Losers confirmed to have settlementFee = 0.** Verified in `_computePositionSettlement` at line 603: losers get `settlementFee: 0`. This means the unconditional fee block (`if result.settlementFee > 0`) only fires for winners, which is correct.

---

### Issues Found

**None critical. Two minor notes for BUILD awareness:**

1. **[LOW] ADL haircut interaction is safe but unmentioned.** The ADL haircut (line 256) modifies `result.payout` but not `result.settlementFee`. Since the plan's delta computation uses `result.payout`, the haircut correctly reduces the profit the vault funds. Traced: with 10% haircut on payout=698, fee=2, delta drops from 498 to 428.2, vault funds 428.2 + 2 = 430.2, AM USDT balances. No action needed, but BUILD should be aware this interaction exists.

2. **[LOW] Winner with payout=0 and settlementFee > 0 edge case.** When a winner's equity is positive but less than the raw fee (lines 550-552), `settlementFee` is capped to `equity` and `payout=0`. This means `delta = -collateral`. The plan's code handles this correctly: debitPnL(collateral), transferOut(vault, collateral), then vault funds the capped fee and transfers it to feeRouter. All balances zero out. Verified.

---

### Interaction with Other Bug Fixes

- **BUG-5 (LEVER-005):** The existing `transferOut(feeRouter, fee)` + `routeFees` pattern in SettlementEngine was added by BUG-5. BUG-6 preserves this pattern in the fee block at the bottom. No conflict.
- **BUG-8:** Modified only ExecutionEngine._settlePnL (fee type classification). No overlap with LiquidationEngine or SettlementEngine changes. No conflict.
- **BUG-10 (LEVER-010):** The comment on line 396 of LiquidationEngine references this. The current `_closeAndSettle` was shaped by this fix. BUG-6 modifies the same function but the changes are additive (adding `fee` parameter). No conflict.
- **P01-P06 patches:** None touch the specific functions being modified. No conflict.

---

### Confirmation: Ready for BUILD

The plan is correct, complete, and well-traced. BUILD should:

1. Read all files listed in "Files to Read First"
2. Implement Steps 2-5 exactly as described (use the FINAL REVISED CODE in Step 3)
3. Write the 7 tests in Step 6
4. Run the full test suite (Step 7) and fix any expected-value shifts in existing tests
5. Grant EXECUTION_ENGINE_ROLE to SettlementEngine on LeverVault in the deployment/setup script

Estimated effort: Medium (4-6 hours). No rearchitecture needed.
