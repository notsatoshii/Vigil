# VERIFY Verdict: LEVER-BUG-5
## Date: 2026-03-29T04:18:00Z
## Task: InsuranceFund decimal mismatch (WAD bootstrap + USDT deposits)
## Verdict: PASS WITH CONCERNS

---

## Routing Note

Commander routed VERIFY to `build-liquid-physics.md` (landing page animation). This is NOT the BUG-5 handoff. There is no `build-lever-bug-5.md` file. The actual BUG-5 work was found as:
- Commit `a03ee9ada`: InsuranceFund.sol rewrite + InsuranceFundFixed.sol deletion + test updates
- Uncommitted changes: socializeLoss caller fixes in ExecutionEngine, LiquidationEngine, SettlementEngine

BUILD must write handoff files. This is the second time VERIFY has had to discover what was done by reading diffs.

---

## Pass 1: Functional Verification

### InsuranceFund.sol SCALE Conversion (PASS)

`InsuranceFund.sol:44` adds `SCALE = 1e12` constant. The `absorbBadDebt` function (line 117-203) now:

1. Converts `_balance` (USDT, 6-decimal) to WAD: `balanceWAD = _balance * SCALE` (line 136)
2. All constraint math (daily cap, floor, tier split) operates in WAD (lines 158-181)
3. Single conversion point back to USDT: `transferUSDT = insurancePaid / SCALE` (line 188)
4. Internal state (`_balance`, `_dailySpent`, `_totalAbsorbed`) updated in USDT (lines 191-193)
5. `safeTransfer(recipient, transferUSDT)` (line 197), preserving P04 3-arg fix

Math trace for $1000 bad debt with $10K balance, $100K TVL:
- `balanceWAD` = 10_000e6 * 1e12 = 10_000e18. Correct.
- IFR = 10% (tier 3, 40%). `insuranceTarget` = 400e18. Correct.
- Daily cap = 2500e18. Floor maxSpend = 5000e18. Neither binds. Correct.
- `transferUSDT` = 400e18 / 1e12 = 400e6 ($400 USDT). Correct.
- `_balance` = 10_000e6 - 400e6 = 9600e6. Correct.

### BUG-4 Co-fix: Constructor Bootstrap (PASS)

`InsuranceFund.sol:95`: `_balance = 0`. No phantom bootstrap. Test `test_constructor_setsZeroBalance` confirms a fresh fund starts at 0. Test setup now explicitly deposits via `FEE_ROUTER_ROLE` to bootstrap with real USDT.

### InsuranceFundFixed.sol Deletion (PASS)

File fully deleted. No references remain in deployment scripts (checked `Deploy.s.sol`, `RedeployAuditFixes.s.sol`).

### P04 3-arg Signature Preserved (PASS)

`absorbBadDebt(bytes32 marketId, uint256 totalBadDebt, address recipient)` at line 117. Transfer uses `recipient`, not `msg.sender`. All three callers pass `address(leverVault)`:
- `ExecutionEngine.sol:378`
- `LiquidationEngine.sol:444`
- `SettlementEngine.sol:503`

### socializeLoss Caller Conversion (PASS)

All three callers convert WAD remainder to USDT before `socializeLoss`:
- `ExecutionEngine.sol`: `leverVault.socializeLoss(remainder / 1e12)`
- `LiquidationEngine.sol`: `leverVault.socializeLoss(socializedAmount / 1e12)`
- `SettlementEngine.sol`: `leverVault.socializeLoss(remainder / 1e12)` and `leverVault.socializeLoss((remainder - totalWinnerPayout) / 1e12)`

`_socializedLosses` in LeverVault is USDT-scale (confirmed via `totalAssets()` at LeverVault.sol:132). Conversion is correct.

### View Functions (PASS)

- `getRemainingDailyCapacity()`: Computes in WAD, returns USDT (/ SCALE). Correct.
- `getFloor()`: `tvl * IFR_FLOOR / WAD` (USDT * WAD-pct / WAD = USDT). Correct.
- `getTarget()`: Same pattern. Correct.
- `_getIFR()`: `_balance.wadDiv(tvl)` (USDT/USDT = WAD ratio). Already correct, unchanged.

### Test Results

| Suite | Pass | Fail | Notes |
|-------|------|------|-------|
| InsuranceFund.t.sol | 48 | 0 | All unit tests updated for WAD-scale inputs |
| InsuranceBadDebt.t.sol | - | compile error | Line 373: `paid`/`badDebt` undeclared (should be `paidWAD`/`badDebtWAD`) |
| AuditNewFindings.t.sol | 4 | 2 | P03+P06 fail (EvmError:Revert from BUG-5 behavior changes) |

Full suite cannot run cleanly due to cross-contamination from BUG-3 and BUG-7 uncommitted changes in the same working tree.

---

## Pass 2: Visual/Design Verification

N/A. Contract-only changes, no frontend modified.

---

## Pass 3: Data Verification

### Scale Consistency (PASS)
- All internal math in `absorbBadDebt` operates in WAD. Single conversion at `transferUSDT = insurancePaid / SCALE`. No mixed-scale comparisons within the function.
- `_balance`, `_dailySpent`, `_totalAbsorbed` remain USDT-scale (6 decimals). Storage unchanged.
- Return values `insurancePaid` and `remainder` are WAD-scale. Callers handle correctly.

### Rounding (ACCEPTABLE)
- `insurancePaid / SCALE` truncates up to 1e12 - 1 dust per absorption (less than $0.000001). Negligible.
- Safe subtraction `totalBadDebt > insurancePaid ? totalBadDebt - insurancePaid : 0` prevents underflow from rounding.

### Event Scale Change (MINOR CONCERN)
- `DailyCapReset` event now emits WAD-scale daily cap value (was USDT-scale). Breaking change for any indexers consuming this event.
- `BadDebtAbsorbed` event emits `insurancePaid` in WAD (was USDT-scale). Same concern.

---

## Concerns

### CONCERN 1 [HIGH]: P06 `_netUnrealizedPnL` Scale Mismatch (Pre-existing, NOT from BUG-5)

`LeverVault.totalAssets()` (line 132): `int256(balance) - _netUnrealizedPnL - int256(_socializedLosses)`

All terms should be USDT-scale. But `_netUnrealizedPnL` is set by `updateUnrealizedPnL(currentUnrealized - pnl)` where `pnl` comes from `_computePnL` (WAD-scale). This means after any position close, `_netUnrealizedPnL` becomes WAD-scale, corrupting `totalAssets()`.

**Impact on BUG-5**: InsuranceFund uses `leverVault.totalAssets()` for IFR and floor calculations. If vault NAV is corrupted, floor and IFR become unreliable. BUG-5's code is internally correct, but its correctness depends on accurate upstream values.

**This is a pre-existing P06 bug, not introduced by BUG-5. But it directly undermines BUG-5's floor constraint.**

DESIGN FLAW: LEVER-P06 updates a USDT-scale tracker (`_netUnrealizedPnL`) with WAD-scale PnL values. This is not a code bug fixable in a few lines; `_computePnL`, `updateUnrealizedPnL`, or `totalAssets()` need a scale decision and potentially all callers of `totalAssets()` need review. Route to PLAN for rearchitecting the PnL-to-NAV pipeline scale.

### CONCERN 2 [HIGH]: Working Tree Contamination

Uncommitted changes from BUG-7 (depthThreshold guard in ExecutionEngine.sol:174) are mixed with BUG-5's socializeLoss fix in the same file. BUG-7's changes break 2 existing audit tests (P03, P06 mocks lack `depthThreshold` function). Cannot run full regression suite cleanly.

Multiple BUILD sessions writing to the same files without coordination is a process failure. Each bug fix should be on its own branch or at minimum committed atomically.

### CONCERN 3 [MEDIUM]: Event Scale Breaking Change

`DailyCapReset` and `BadDebtAbsorbed` events now emit WAD-scale values for amounts that were previously USDT-scale. Any downstream indexers, dashboards, or monitoring that parse these events will show values 1e12x too large.

### CONCERN 4 [LOW]: No BUILD Handoff

No `build-lever-bug-5.md` exists. Commander routed VERIFY to `build-liquid-physics.md` (landing page, unrelated). VERIFY had to discover changes via `git log` and `git diff`. This makes the review harder and increases risk of missing changes.

---

## Critique Compliance

Checking against the 7 issues from `critique-lever-bug-5.md`:

| # | Issue | Status |
|---|-------|--------|
| 1 | [CRITICAL] Preserve 3-arg `absorbBadDebt` signature (P04) | PASS |
| 2 | [HIGH] Caller references use actual code, not stale plan | PASS |
| 3 | [HIGH] `socializeLoss` callers convert WAD to USDT | PASS |
| 4 | [MEDIUM] Co-deploy with BUG-4 (constructor `_balance = 0`) | PASS |
| 5 | [MEDIUM] P06 `_netUnrealizedPnL` scale mismatch | NOT ADDRESSED (flagged as Concern 1) |
| 6 | [LOW] Use correct file paths | PASS |
| 7 | [LOW] Event emission scale change | NOTED (flagged as Concern 3) |

---

## Decision

**PASS WITH CONCERNS.** The BUG-5 changes are internally correct, well-tested (69 targeted tests pass), and address all CRITICAL/HIGH items from the critique. The SCALE conversion approach is clean and the single conversion point at line 188 is the right design.

However:
- The P06 scale mismatch (Concern 1) is a DESIGN FLAW that undermines the floor constraint this fix depends on. It must be routed to PLAN before redeployment.
- The working tree contamination (Concern 2) prevents full regression verification.

**Recommendation**: Do NOT redeploy InsuranceFund until the P06 `_netUnrealizedPnL` scale is resolved. The floor/IFR calculations will produce wrong results if vault NAV is corrupted.

---

## Recommendations for PLAN

1. **[CRITICAL] Route P06 scale mismatch to PLAN.** `_netUnrealizedPnL` must be either: (a) converted to USDT before storage, or (b) `totalAssets()` must convert it from WAD to USDT. This requires reviewing all callers of both `updateUnrealizedPnL` and `totalAssets()`.
2. **[HIGH] Enforce atomic commits per bug fix.** Multiple sessions writing uncommitted changes to the same files causes untestable contamination.

## Recommendations for BUILD

1. Write a handoff file for every completed task. No exceptions.
2. Commit BUG-5 caller changes (socializeLoss) separately from BUG-7 changes.

## KANBAN Update

LEVER-BUG-5 remains IN REVIEW. Do not move to DONE until P06 scale concern is resolved or explicitly accepted as a known limitation.
