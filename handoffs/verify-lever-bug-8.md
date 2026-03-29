# VERIFY Verdict: LEVER-BUG-8
## Date: 2026-03-29T05:20:00Z
## Task: No closing transaction fee (10bps foregone) / FeeType misclassification
## Verdict: PASS

---

## Summary

LEVER-P03 already fixed the core fee routing (closing fee computed locally, no double-routing). The remaining issue was FeeType misclassification: closing fees were routed as `FeeType.BORROW` instead of `FeeType.TRANSACTION`. The fix splits the single `routeFees` call into two calls with correct types. 4 regression tests pass. No regressions in existing suites. No design flaws.

---

## Pass 1: Functional Verification

### FeeType Split in _settlePnL (PASS)
`ExecutionEngine.sol:460-465`:
```
uint256 borrowToRoute = borrowFees > toFeeRouter ? toFeeRouter : borrowFees;
uint256 closingToRoute = toFeeRouter - borrowToRoute;
if (borrowToRoute > 0) feeRouter.routeFees(IFeeRouter.FeeType.BORROW, borrowToRoute);
if (closingToRoute > 0) feeRouter.routeFees(IFeeRouter.FeeType.TRANSACTION, closingToRoute);
```

**Correctness analysis:**
- Normal case (no bad debt): `toFeeRouter = totalFees = borrowFees + closingFee`. So `borrowToRoute = borrowFees`, `closingToRoute = closingFee`. Each type routed separately. Correct.
- Same-block close (borrowFees=0): `borrowToRoute = 0`, `closingToRoute = closingFee`. Only TRANSACTION call fires. Correct.
- Bad debt proration: Borrow fees get priority (first claim on `toFeeRouter`). Closing fee gets remainder. Both are zero-guarded. No underflow possible since `closingToRoute = toFeeRouter - borrowToRoute` and `borrowToRoute <= toFeeRouter`. Correct.
- Full bad debt (toFeeRouter=0): Both guards skip. No `routeFees` calls. Correct.

### Opening Fee Path Unchanged (PASS)
`ExecutionEngine.sol:314`: Opening fee still routed as `FeeType.TRANSACTION` via the direct path in `_executeOpen`. This was correct before and is unchanged.

### ClosingFee.t.sol (4/4 PASS)
| Test | What it proves |
|------|---------------|
| `closingFeeDeductedFromUser` | User balance = deposit - openFee - closingFee after round trip |
| `closeFeeTypeDoesNotRevert` | Split routeFees with both borrow + closing fees works (no revert after 2hr borrow accrual) |
| `feeRouterReceivesTotalFees` | FeeRouter USDT increases by exactly closingFee on close |
| `routeFeesCalledForClosingFee` | `totalFeesCollected` increments by exactly closingFee (one routing, not double) |

### Regression Suites (PASS)
- VaultDrain.t.sol: 4/4. P03 invariants preserved (conservation, single routing on close).
- AuditNewFindings.t.sol: 6/6. P03 test still passes (no `collectTransactionFee` call).
- Integration.t.sol: 2/2. Full lifecycle + liquidation waterfall unaffected.

---

## Pass 2: Visual/Design Verification

N/A. Contract-only change, no frontend modified.

---

## Pass 3: Data Verification

- `TX_FEE_RATE = 1e15` (10bps) used consistently in both open and close paths.
- `closingFee` passed as a distinct parameter to `_settlePnL` (line 373), not mixed with borrow fees until the routing split.
- The proration arithmetic: `borrowToRoute = min(borrowFees, toFeeRouter)`, `closingToRoute = toFeeRouter - borrowToRoute`. No truncation or precision issues; all values are WAD-scale uint256.
- `FeeType.BORROW` and `FeeType.TRANSACTION` are enum values (uint8). MockFeeRouter ignores the type parameter but increments `totalFeesCollected` on each `routeFees` call. Two calls = two increments. Test 4 asserts exactly one increment for closing fee (since borrowFees=0 in same-block close, only TRANSACTION call fires).

---

## Limitation Noted

MockFeeRouter does not track fees by type. The per-type classification cannot be verified in tests without updating the mock to record `FeeType` per call. This is a test coverage gap, not a code bug. The code change is a straightforward two-line split with correct enum values, verified by code review.

---

## Test Results

```
ClosingFee.t.sol:        4/4 PASS
VaultDrain.t.sol:        4/4 PASS
AuditNewFindings.t.sol:  6/6 PASS
Integration.t.sol:       2/2 PASS
Total: 16 pass, 0 fail
```

---

## No Design Flaws Found

The fix is minimal: split one `routeFees` call into two with correct FeeType enums. Proration logic handles bad debt edge cases correctly. The approach is sound.

---

## Decision

**PASS** -- FeeType misclassification fixed. Closing fees now routed as `TRANSACTION`, borrow fees as `BORROW`. 4 regression tests pass. No regressions across 16 tests in 4 suites. No design flaws.
