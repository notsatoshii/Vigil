# Critique: LEVER-BUG-8 — No Closing Transaction Fee (10bps Foregone)
## Date: 2026-03-29T04:40:00Z
## Plan reviewed: handoffs/plan-lever-bug-8.md
## Codebase verified against: /home/lever/lever-protocol @ commit 9f77cc990

---

### Verdict: APPROVED (with notes — plan is 90% already done)

LEVER-P03 ("ExecutionEngine direct fee routing", VERIFIED PASS) already fixed the core issues described in this plan. The closing fee is computed locally, deducted from the user, transferred to FeeRouter, and routed. The ONLY remaining issue is the FeeType classification: closing fees are routed as `FeeType.BORROW` instead of `FeeType.TRANSACTION`.

---

### What Is Good

- Correct root cause analysis of the original FIX LEVER-009 bug (double-routing via `collectTransactionFee`).
- Good analysis of the opening vs closing flow asymmetry.
- Step 4 (FeeType split) is the one piece of remaining work and is well-specified.
- Edge cases (zero notional, bad debt proration, first-ever close) are thorough.

---

### Issues Found

**1. [HIGH] Steps 2, 3, and 5 are already done by LEVER-P03. Only Step 4 remains.**

Verified in the actual codebase:

**Closing fee (P03 fix, line 373-377):**
```solidity
// FIX LEVER-P03 (Bug B) + LEVER-009: Compute closing fee locally.
uint256 closingFee = pos.positionSize * TX_FEE_RATE / WAD;
```
No `collectTransactionFee` call. Fee computed locally using `TX_FEE_RATE` (already a public constant on ExecutionEngine, line 44). **Step 3 is done.**

**Opening fee (P03 fix, lines 305-315):**
```solidity
// FIX LEVER-P03 (Bug A): Compute fee locally...
uint256 txFee = notional * TX_FEE_RATE / WAD;
// ...
accountManager.transferOut(address(feeRouter), txFee);
feeRouter.routeFees(IFeeRouter.FeeType.TRANSACTION, txFee);
```
Opening flow already uses `computeTransactionFee`-equivalent local math AND routes as `FeeType.TRANSACTION`. **Step 5 is done.**

**Step 2 (`computeTransactionFee` view function):** Not needed. P03 computes fees directly using `TX_FEE_RATE` constant. No external call to FeeRouter required.

**The one remaining issue (Step 4):** Line 459:
```solidity
feeRouter.routeFees(IFeeRouter.FeeType.BORROW, toFeeRouter);
```
All fees (borrow + closing) are combined into `toFeeRouter` and routed as `BORROW`. The closing fee should be routed as `TRANSACTION`. This is an accounting classification issue; the USDT flow is correct.

---

**2. [MEDIUM] The FeeType split is LOW functional severity**

All FeeTypes use the same 50/30/20 distribution (LP/protocol/insurance). The only difference is the `_totalFeesRouted[FeeType]` accumulator in FeeRouter. Routing closing fees as BORROW:
- Does NOT affect USDT distribution (same split)
- Does NOT affect any downstream logic (nothing reads `_totalFeesRouted` for decision-making)
- Only affects reporting/dashboards that show fee breakdown by type

If there are higher-priority bugs to fix, this can be deferred.

---

**3. [LOW] File paths reference `/home/lever/Lever/`**

Same as all other plans. Actual codebase is at `/home/lever/lever-protocol/`.

---

### Missing Steps

None for the remaining work. Step 4's FeeType split code is well-specified and handles the bad debt proration edge case correctly.

---

### Simpler Alternative

Since this is just a classification fix, the simplest approach: pass `closingFee` as a separate parameter alongside `borrowFees` through `_settlePnL` (already done) and split the `routeFees` call. The plan's Step 4 code does this correctly.

---

### Revised Effort Estimate

**Tiny** (reduced from Small). Only the FeeType split in `_settlePnL` remains. One code change (split the routeFees call at line 457-460). 30 minutes of work plus test updates.

---

### Recommendation

**Send to BUILD** with these notes:

1. **Skip Steps 2, 3, and 5.** All already done by LEVER-P03.
2. **Only implement Step 4** (split `routeFees` into two calls: `BORROW` for borrowFees, `TRANSACTION` for closingFee).
3. **Do NOT add `computeTransactionFee` to FeeRouter.** The fee is already computed locally using `TX_FEE_RATE`.
4. The "Current Code State" section in the plan is stale (shows pre-P03 code). The actual code at lines 373-377 and 457-459 is what BUILD should read.
5. This is LOW functional severity. If BUILD is time-constrained, defer in favor of higher-priority bugs.
