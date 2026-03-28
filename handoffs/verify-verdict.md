# VERIFY Verdict
## Date: 2026-03-28
## Task: Audit Phase 2 - LEVER-P01 through P06 fixes
## Verdict: PASS WITH CONCERNS

---

## Summary

All 6 audit fixes implemented correctly. Build passes. Full test suite: 1074 pass, 4 fail (pre-existing PriceSmoothing failures confirmed, zero regressions from P01-P06 changes).

---

## Pass 1: Functional Verification

### P01 - FundingRateEngine depthThreshold guard (PASS)
`FundingRateEngine.sol:343-355` — `if (depthThreshold[marketId] == 0) mMarket = WAD` guard is correct. Consistent with MarginEngine LEVER-007 fix. Prevents `ZeroDepthThreshold` revert on uninitiated markets. Test confirms accrual runs without revert and produces sensible output.

### P02 - BorrowFeeEngine depthThreshold guard (PASS)
`BorrowFeeEngine.sol:320-335` — Identical guard pattern in `_getRBorrowAdjusted`. Confirmed via test: `getCurrentBorrowRate`, `accrueIndex`, and `accrueAll` all succeed with `depthThreshold=0`. Index grows past WAD after accrual.

### P03 - ExecutionEngine fee routing (PASS)
`ExecutionEngine.sol:302-315` (open), `ExecutionEngine.sol:369-373` (close).

On open: fee is `notional * TX_FEE_RATE / WAD`, then `accountManager.debitPnL` + `transferOut(feeRouter)` + `routeFees(TRANSACTION)`. `collectTransactionFee` is never called.

On close: `closingFee` computed locally, passed to `_settlePnL` as a distinct argument. Combined with `borrowFees` in `totalFees`, then `transferOut(feeRouter)` + `routeFees(BORROW)`. No phantom distribution.

Test confirms: `collectTransactionFeeCalled == false`, `transferOut` called to `feeRouter`, `routeFees` called, amount matches `0.10% * notional`.

### P04 - InsuranceFund absorbBadDebt recipient (PASS)
`InsuranceFund.sol:115` — New signature `absorbBadDebt(bytes32, uint256, address recipient)`. USDT transferred via `usdt.safeTransfer(recipient, insurancePaid)` at line 188. All three callers (ExecutionEngine L378, LiquidationEngine L444, SettlementEngine L503) pass `address(leverVault)` as recipient.

Test confirms: USDT goes to recipient, caller balance stays 0, fund accounting balance decreases correctly.

### P05 - FundingRateEngine.routeUnmatchedFunding (PASS)
`FundingRateEngine.sol:143-145` — `accountManager.transferOut(address(rewardsDistributor), pending)` then `rewardsDistributor.receiveUnmatchedFunding(marketId, pending)`. No longer calls `depositRewards`. Pending balance zeroed after routing. Double-route reverts with `FundingRateEngine__NoUnmatchedFunding`.

Test confirms: `receiveUnmatchedFundingCallCount == 1`, `depositRewardsCallCount == 0`, amounts match, transfer destination is rewardsDistributor.

### P06 - updateUnrealizedPnL on close (PASS)
`ExecutionEngine.sol:388-389` — `currentUnrealized - pnl` removes the closed position's contribution from vault NAV tracking. `getNetUnrealizedPnL` called first (read-then-write is sequential, safe in single-tx context).

Test confirms: vault PnL goes from `+400e18` to `0` after closing a position with `+400e18` realized PnL.

---

## Pass 2: Visual/Design Verification

N/A — contracts-only change, no frontend modified.

---

## Pass 3: Data Verification

- No decimal precision issues introduced
- `TX_FEE_RATE = 1e15` used consistently in both open and close paths
- `updateUnrealizedPnL` takes WAD-precision `int256`, consistent with `_netUnrealizedPnL` storage type
- All role hashes consistent: `EXECUTION_ENGINE_ROLE`, `LIQUIDATION_ENGINE_ROLE`, `SETTLEMENT_ENGINE_ROLE`

---

## Concerns (Non-Blocking)

### CONCERN 1: InsuranceFundFixed.sol ignores recipient
`InsuranceFundFixed.sol:115` — recipient parameter is commented out (`address /* recipient */`) and there is NO `safeTransfer` call. If `InsuranceFundFixed` is accidentally deployed instead of `InsuranceFund`, bad debt insurance USDT goes nowhere. Both files exist in the codebase. Deployment must use `InsuranceFund.sol`. Recommend marking `InsuranceFundFixed.sol` as deprecated.

### CONCERN 2: Closing fee routed as FeeType.BORROW (pre-existing)
`ExecutionEngine.sol:451` — `totalFees = borrowFees + closingFee` sent to FeeRouter as `FeeType.BORROW`. Opening fee uses `FeeType.TRANSACTION`. If FeeRouter distributes these types differently, closing TX fees are misclassified. Pre-existing design, not introduced by this fix. Flag for next audit cycle.

### CONCERN 3: P06 minimal fix — no update on open (acknowledged)
`ExecutionEngine.sol:388-389` — `updateUnrealizedPnL` only called on close, not on open or during position lifetime. NAV drift between open and close is not tracked until a keeper calls `updateUnrealizedPnL` separately. Acknowledged in handoff as LEVER-008. Does not block demo.

### CONCERN 4: EXECUTION_ENGINE_ROLE must be granted post-deployment
`LeverVault.sol:314` — `updateUnrealizedPnL` requires `EXECUTION_ENGINE_ROLE` on LeverVault. Also confirm `EXECUTION_ENGINE_ROLE` is on `InsuranceFund` for ExecutionEngine to call `absorbBadDebt`. Both must be in the 22-step deployment checklist.

---

## Test Results

```
P01: PASS  P02: PASS  P03: PASS  P04: PASS  P05: PASS  P06: PASS
Full suite: 1074 pass, 4 fail
Failing: test/verification/PriceSmoothingVerification.t.sol (pre-existing, unrelated)
Build: PASS
Commit: c59754b02
```

---

## Decision

**PASS WITH CONCERNS** — all 6 fixes are correct, no regressions introduced, concerns are non-blocking. Redeployment is unblocked.

*Independently re-verified by VERIFY session on 2026-03-28 13:17 UTC. Fresh forge test run confirmed 1074/4 results.*

Follow the 22-step checklist in `REVIEW/AUDIT_FINDINGS_FINAL.md`. Pay special attention to Concern 1 (deploy `InsuranceFund.sol` not `InsuranceFundFixed.sol`) and Concern 4 (role grants for `updateUnrealizedPnL`).

## Recommendations for BUILD

None required. Fixes are complete.

## Recommendations for PLAN

- Deprecate or remove `InsuranceFundFixed.sol` to prevent accidental deployment
- Track Concern 2 (closing fee type classification) as a formal finding for next audit cycle

## KANBAN Update

Move P01-P06 items to DONE.
