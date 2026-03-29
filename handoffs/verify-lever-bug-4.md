# VERIFY Verdict: LEVER-BUG-4
## Date: 2026-03-29T04:37:00Z
## Task: InsuranceFund phantom bootstrap removal + InsuranceFundFixed deletion
## Verdict: PASS

---

## Summary

BUG-4 had two defects: (1) phantom bootstrap inflating `_balance` without real USDT, and (2) wrong transfer recipient in `absorbBadDebt`. Defect 2 was already fixed by LEVER-P04 (verified 2026-03-28). This BUILD fixed Defect 1 (`_balance = 0` in constructor), deleted `InsuranceFundFixed.sol`, and updated all test files. All BUG-4-specific tests pass. No regressions from these changes.

---

## Pass 1: Functional Verification

### Defect 1 Fix: `_balance = 0` (PASS)
`InsuranceFund.sol:96`: Constructor now sets `_balance = 0` instead of `_balance = INSURANCE_BOOTSTRAP`. Confirmed in committed code (commit `a03ee9ada`).

### InsuranceFundFixed.sol Deletion (PASS)
File confirmed absent from disk. This contract had the phantom bootstrap AND silently ignored the P04 `recipient` parameter (no `safeTransfer` call). Deletion prevents accidental deployment of the buggy version.

### New Regression Tests: PhantomBootstrap.t.sol (4/4 PASS)
| Test | What it proves |
|------|---------------|
| `test_BUG4_constructorStartsAtZero` | `getBalance() == 0` after construction |
| `test_BUG4_absorbWorksAfterRealDeposit` | `absorbBadDebt` succeeds with real USDT; recipient receives tokens; accounting decreases correctly |
| `test_BUG4_absorbWithZeroBalanceReturnsFullRemainder` | Zero balance = zero insurance payment, full remainder for socialization, no revert |
| `test_BUG4_depositAccountingMatchesTokens` | `getBalance() == usdt.balanceOf(address(fund))` after deposit |

Tests are well-structured: each test targets a specific invariant the bug violated, with clear regression detection.

### Updated Test Files (PASS)
| Test file | Result | Changes |
|-----------|--------|---------|
| InsuranceFund.t.sol | 48/48 PASS | setUp adds explicit `fund.deposit(BOOTSTRAP)`, constructor test renamed, all `absorbBadDebt` inputs updated to WAD scale (BUG-5 co-change) |
| InsuranceBadDebt.t.sol | 21/21 PASS | setUp seeds real USDT + deposit, all inputs WAD-scale |
| AuditNewFindings.t.sol P04 test | PASS | Updated for BUG-4 (explicit deposit) and BUG-5 (WAD-scale) |

### Defect 2 (P04 recipient fix): Still intact (PASS)
`InsuranceFund.sol:188`: `usdt.safeTransfer(recipient, transferUSDT)` confirmed. P04 test passes.

---

## Pass 2: Visual/Design Verification

N/A. Contracts-only change, no frontend modified.

---

## Pass 3: Data Verification

- `_balance` starts at 0 (uint256 default). No phantom USDT accounting.
- `deposit()` increments `_balance` by `amount` (USDT scale, 6 decimals). Caller is FeeRouter (role-gated).
- `getBalance()` returns `_balance` (USDT). Matches actual token holdings when deposits are properly paired with transfers.
- `absorbBadDebt` receives WAD-scale `totalBadDebt`, does all constraint math in WAD, converts to USDT only for the `safeTransfer` (via `/ SCALE`). Internal accounting (`_balance`, `_dailySpent`, `_totalAbsorbed`) all remain USDT-scale. Consistent.
- The test `depositAccountingMatchesTokens` is the critical invariant: it proves `getBalance() == usdt.balanceOf(address(fund))`, which is exactly what the phantom bootstrap violated.

---

## Concurrent Session Impact

Two observations unrelated to BUG-4:

1. **BUG-7 (concurrent)** modified `ExecutionEngine.sol` (uncommitted) to add a `depthThreshold` check on `openPosition`. This breaks `AuditNewFindings.t.sol` tests P03 and P06 (which open positions through IntegrationBase). These failures are from BUG-7, not BUG-4. The BUG-7 session must update IntegrationBase to configure depth thresholds in its setup.

2. **DepthThreshold.t.sol** is an untracked file from a concurrent session with a compilation error (`accrueIndex` not found). Not part of BUG-4.

---

## No Design Flaws Found

The fix is minimal and correct: remove the phantom balance, require real USDT via deposit. The deployment note (admin must transfer USDT + call deposit after redeployment) is properly documented in the handoff.

---

## Decision

**PASS** -- constructor fix verified, InsuranceFundFixed deleted, 4 regression tests correct, 146 tests across 8 suites pass (48 InsuranceFund + 21 InsuranceBadDebt + 4 PhantomBootstrap + 6 AuditNewFindings + 8 AuditFindings + 4 VaultDrain + 2 Integration + 53 OILimits), zero failures. No design flaws.

*Re-verified 2026-03-29 04:43 UTC. Full suite completed: 1081 pass, 9 fail. 4 are pre-existing PriceSmoothing. 5 are BUG-5 test gaps (LiquidationEngine.t.sol: 3, SettlementEngine.t.sol: 2) where test assertions still expect USDT-scale returns from absorbBadDebt but BUG-5 changed returns to WAD-scale. These are NOT BUG-4 regressions; BUG-5 BUILD must update those test files.*
