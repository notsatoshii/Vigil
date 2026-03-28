# VERIFY Verdict: LEVER-BUG-2
## Date: 2026-03-28T15:37:00Z
## Task: Verify regression tests for $304K vault drain (LEVER-BUG-2 / LEVER-P03)
## Verdict: PASS

---

## Summary

BUILD's deliverable was test-only: 4 regression tests in `test/audit/VaultDrain.t.sol` covering the LEVER-P03 fix (already verified in the P01-P06 audit). No contract code was changed. All 4 tests pass. Full suite: 1078 pass, 4 fail (pre-existing PriceSmoothing, unrelated). No regressions.

---

## Pass 1: Functional Verification

### Test 1: `test_BUG2_openFeeDebitedFromAccountManager` (PASS)
Verifies that on open, USDT physically leaves AccountManager and arrives at FeeRouter. Checks three invariants: AM balance decreases by txFee, FeeRouter balance increases by txFee, user ledger debited. Would catch Bug A regression (no transferOut).

### Test 2: `test_BUG2_closeFeeRoutedOnce` (PASS)
Verifies that on close, `totalFeesCollected` increments by exactly one closing fee, not two. MockFeeRouter increments `totalFeesCollected` on both `collectTransactionFee` and `routeFees`, so double-routing from Bug B would show as 2x. Clean catch.

### Test 3: `test_BUG2_accountingInvariantAfterRoundTrip` (PASS)
Conservation invariant: after a breakeven open+close, `AM USDT + FeeRouter USDT == initial deposit`. No phantom balances created. Would catch Bug A (phantom USDT stays in AM, sum exceeds deposit).

### Test 4: `test_BUG2_vaultNotFundedOnBreakevenTrade` (PASS)
Verifies vault USDT stays at 0 and Alice's final balance equals deposit minus exactly 2 x txFee. Confirms fees come from trader capital, not vault LP capital.

### Test Harness Review
- `IntegrationBase.sol` uses real `ExecutionEngine`, `AccountManager`, `BorrowFeeEngine`, `FundingRateEngine`, `MarginEngine`, `OILimits`, `PositionManager`. Only leaf dependencies are mocked.
- `MockFeeRouter` retains the old `collectTransactionFee` method (increments counter, no USDT move). Since the fixed code never calls it, this is inert. `routeFees` also increments the counter, making Test 2 a valid double-routing detector.
- `MockLeverVault.fundTraderPnL` is a no-op. For breakeven PnL=0 tests this is correct (function should not be called with amount > 0).

### Coverage Assessment
The 4 tests cover all scenarios from `plan-lever-bug-2.md`:
- Bug A open path: Test 1 (USDT flow), Test 3 (conservation)
- Bug B close path: Test 2 (single routing), Test 3 (conservation)
- No vault capital consumed: Test 4

---

## Pass 2: Visual/Design Verification

N/A. Test-only change, no frontend modified.

---

## Pass 3: Data Verification

- `TX_FEE_BPS = 1e15` matches `ExecutionEngine.TX_FEE_RATE` (0.10% = 10 bps in WAD). Confirmed consistent.
- `COLLATERAL = 1_000e18`, `LEVERAGE = 2e18`, so `notional = 2_000e18`, `txFee = 2e18`. Math checks out.
- No decimal precision issues. All arithmetic uses WAD-scale division, consistent with production code.
- No hardcoded addresses.

---

## Full Test Suite

```
VaultDrain tests: 4/4 PASS
Full suite: 1078 pass, 4 fail
Failing: test/verification/PriceSmoothingVerification.t.sol (pre-existing, unrelated)
Build: PASS (no compilation needed, test-only)
Commit: 9f77cc990
```

---

## No Design Flaws Found

The test design is sound. Tests exercise real contract code paths through the integration harness, not unit-level mocks. Each test targets a specific regression scenario with clear failure conditions. MockFeeRouter's `totalFeesCollected` counter is an effective double-routing detector.

---

## Decision

**PASS** -- all 4 regression tests are correct, well-structured, and would catch reintroduction of both Bug A and Bug B. No contract code changed, no regressions, no design flaws.
