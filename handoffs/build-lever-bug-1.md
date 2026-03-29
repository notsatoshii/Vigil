# BUILD Handoff Report
## Date: 2026-03-29T10:10:00Z
## Task: LEVER-BUG-1 -- PnL Formula Mismatch (single-impact per LESSONS.md)
## Plan: plan-lever-bug-1-v2.md (CRITIQUE: APPROVED)

---

### Summary

Implemented the single-impact PnL formula per LESSONS.md:
`PnL = direction * (currentPI - pos.entryPrice) * size`

Entry side uses execution price (PI + impact), exit side uses raw oracle PI. This charges the
spread once at entry (single-impact). The old bug used raw PI for both sides, hiding the entry
spread and creating the "38 winners, 0 losers" symptom.

Phases 1-3 (code changes) were applied by a prior session. This session wrote the 5 regression
tests and updated 6 existing test files whose expected values changed due to the formula.

---

### Changes Made (code, applied by prior session)

**contracts/ExecutionEngine.sol**:
- Phase 1: `_computePnL` parameters renamed from `exitPrice/entryPrice` to `exitMark/entryMark`
- Phase 2: line 383 swapped `pos.entryPI` to `pos.entryPrice` in PnL computation

**contracts/MarginEngine.sol**:
- Phase 3: line 370 swapped `pos.entryPI` to `pos.entryPrice` in `_computeEquity`

**Phases 2+3 deployed together** per the critique mandate (LEVER-P06 ordering constraint).

### Changes Made (tests, this session)

**test/integration/PnLConsistency.t.sol** (new, 5 tests):
- `testRoundTripPnLSingleImpact`: flat market shows negative PnL (entry spread charged)
- `testRealizedMatchesUnrealized`: MarginEngine and ExecutionEngine PnL agree (P06 safe)
- `testRegressionRawPIEntryWouldFail`: documents formula difference, catches reversion
- `testWinnersAndLosersBothExist`: PI up creates long winners + short losers
- `testLongShortZeroSumSingleImpact`: long shows entry spread cost on flat market

**test/audit/AuditFindings.t.sol**: Updated LEVER001 test for single-impact formula. Updated PnL consistency invariant (long+short is no longer zero-sum; spread is protocol revenue).

**test/audit/AuditNewFindings.t.sol**: Updated P06 test to use `pos.entryPrice` for expected PnL.

**test/audit/ClosingFee.t.sol**: Updated "breakeven" assertion (user pays fees + entry spread).

**test/audit/VaultDrain.t.sol**: Updated accounting invariant to include vault USDT (entry spread loss flows from trader to vault as counterparty).

**test/audit/UnrealizedPnL.t.sol**: Updated flat-market PnL assertions (no longer zero).

---

### Files Modified

- `/home/lever/lever-protocol/test/integration/PnLConsistency.t.sol` (created)
- `/home/lever/lever-protocol/test/audit/AuditFindings.t.sol`
- `/home/lever/lever-protocol/test/audit/AuditNewFindings.t.sol`
- `/home/lever/lever-protocol/test/audit/ClosingFee.t.sol`
- `/home/lever/lever-protocol/test/audit/VaultDrain.t.sol`
- `/home/lever/lever-protocol/test/audit/UnrealizedPnL.t.sol`

---

### Tests Run

```
PnLConsistency.t.sol: 5 passed, 0 failed
All audit tests (8 suites): 40 passed, 0 failed
ClosePositionFlow.t.sol: 6 passed, 0 failed
FeeFlow.t.sol: 15 passed, 0 failed
InsuranceFund.t.sol: 48 passed, 0 failed
OILimits.t.sol: 53 passed, 0 failed
Total: 167 passed, 0 failed
```

---

### Known Risks

1. **SettlementEngine NOT modified**: Uses `pos.entryPI` for settlement PnL. At resolution
   (PI=0 or 1), the impact spread is small relative to the outcome, so this is safe for now.
   Master decision needed before touching SettlementEngine.

2. **Existing open positions**: Equity shifts down by the entry impact amount when MarginEngine
   switches to entryPrice. Positions near liquidation threshold could be unexpectedly liquidated.
   On testnet with ~$4.3K OI and typical 1-2% impact, the equity shift is $43-$86.

3. **P06 ordering**: Phases 2+3 were committed together. MUST NOT be deployed separately.

---

### Contract Changes

- ExecutionEngine.sol: line 383, `pos.entryPI` -> `pos.entryPrice`
- MarginEngine.sol: line 370, `pos.entryPI` -> `pos.entryPrice`
- ExecutionEngine.sol: `_computePnL` parameter rename (cosmetic)

---

### Build/Deploy Actions

- `git commit ae88747b4` to `main` branch (tests)
- Code changes were in prior session commits
- No services restarted

---

### Notes for VERIFY

1. The core formula change is TWO one-word swaps. Verify lines 383 and 370.
2. Phase 2+3 MUST be deployed atomically (P06 vault NAV tracking alignment).
3. 6 existing test files were updated; all expected value changes trace to entry spread visibility.
4. SettlementEngine is OUT OF SCOPE (pending Master decision). Flag in verdict.
