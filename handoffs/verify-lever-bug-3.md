# VERIFY Verdict: LEVER-BUG-3
## Date: 2026-03-29T04:36:00Z
## Task: Ghost OI (Stale Open Interest with Zero Positions)
## Verdict: PASS

---

## Summary

BUILD added `adminResetMarketOIFull` to OILimits.sol with an on-chain safety check (reverts if PositionManager has open positions) and per-user OI clearing. Constructor updated to accept `positionManager` as an immutable reference. `InsuranceFundFixed.sol` deleted (BUG-5 co-change, not BUG-3). All 4 regression tests pass. All 53 existing OILimits tests pass. All affected test/script constructor call sites updated (13 files). No design flaws.

---

## Pass 1: Functional Verification

### New Function: `adminResetMarketOIFull` (PASS)
`OILimits.sol:171-196`

- **Access control**: `onlyRole(ADMIN_ROLE)` + `nonReentrant`. Correct.
- **On-chain safety check** (line 176): `positionManager.getMarketPositions(marketId).length` verified. Returns the in-memory copy of `_marketPositions[marketId]`, which is a `uint256[]` with swap-and-pop removal on close. `.length == 0` reliably means zero open positions. Revert with specific error `OILimits__MarketHasOpenPositions(marketId, count)`. Correct.
- **Early return** (line 180): if all three market-level accumulators are zero, no-op. Prevents unnecessary state writes and event emission. Correct.
- **Global OI subtraction** (line 183): `_globalOI = oldMarket > _globalOI ? 0 : _globalOI - oldMarket`. Defensive against underflow (can happen if OI tracking drifted from redeployment). Correct.
- **Market accumulators** (lines 186-188): `_marketOI`, `_longOI`, `_shortOI` all zeroed. Correct.
- **Per-user OI clearing** (lines 191-193): iterates `affectedUsers`, zeros `_userOI[marketId][user]`. This addresses Defect B from the plan. Correct.
- **Event emission** (line 195): `OIReset(marketId, clearedAmount, userCount)`. Correct.

### Constructor Change (PASS)
`OILimits.sol:69-79`

- Added `IPositionManager` as 3rd parameter (before admin), stored as immutable. Zero-address check included. All 13 constructor call sites updated and verified via grep. Correct.

### Interface Update (PASS)
`IOILimits.sol`: Added `OILimits__MarketHasOpenPositions` error, `OIReset` event, `adminResetMarketOIFull` signature. Correct.

### Test 1: `test_adminReset_clearsAllOI` (PASS)
Creates ghost OI for alice (100K long) and bob (80K short), clears PositionManager, then resets. Verifies all 6 accumulators (global, market, long, short, alice per-user, bob per-user) are zero. Correct coverage.

### Test 2: `test_adminReset_revertsIfPositionsOpen` (PASS)
Adds a position WITHOUT clearing PositionManager. Confirms revert with expected selector and args. Confirms OI unchanged after revert. Correct.

### Test 3: `test_adminReset_noopOnZeroOI` (PASS)
Calls reset on a clean market. No revert, state unchanged. Correct.

### Test 4: `test_adminReset_partialUserList` (PASS)
Three users have ghost OI. Only two provided in reset call. Global/market/side OI fully cleared. Listed users cleared. Unlisted user (charlie) retains per-user OI. Documents the limitation correctly.

### Regression Tests (PASS)
- OILimits.t.sol: 53/53 pass (includes 3 fuzz tests, cap tests, role tests, pause tests)
- Integration.t.sol: 2/2 pass (full lifecycle + liquidation waterfall)
- AuditFindings.t.sol: 8/8 pass (includes `test_LEVER006_adminCanResetGhostOI`)

---

## Pass 2: Visual/Design Verification

N/A. Contracts-only change, no frontend modified.

---

## Pass 3: Data Verification

- All OI values are WAD-scale (1e18), consistent with existing OILimits accumulators.
- No decimal precision issues introduced.
- `getMarketPositions` returns `uint256[]` from a plain array (not EnumerableSet). `.length` is correct. Confirmed in PositionManager source (lines 191-193, swap-and-pop at line 131).
- Role hashes: `ADMIN_ROLE = DEFAULT_ADMIN_ROLE`, `EXECUTION_ENGINE_ROLE` used in tests. Consistent with codebase.
- Constructor call sites verified: Deploy.s.sol, DeployEngines.s.sol, RedeployAuditFixes.s.sol, script-disabled/Deploy.s.sol, OILimits.t.sol (5 calls), Integration.t.sol, IntegrationBase.sol, AuditFindings.t.sol, GhostOI.t.sol. All 13 updated.

---

## No Design Flaws Found

The approach is sound: admin-only function with on-chain safety verification, clearing all 5 accumulator levels. The `getMarketPositions` memory copy has O(n) gas cost, but this is an admin function called rarely on markets with zero positions (array is empty), so gas is negligible. The incomplete user list limitation is inherent and properly documented.

---

## Concerns (Non-Blocking)

### CONCERN 1: Original `adminResetMarketOI` retained without safety check
`OILimits.sol:154-164`: The old function has no on-chain position check and no per-user OI clearing. If an admin accidentally calls the old function instead of `adminResetMarketOIFull`, they get the weaker reset. Consider deprecating or removing the old function in a future cleanup.

### CONCERN 2: Diagnostic script has TODO address
`script/DiagnoseGhostOI.s.sol:30`: `OI_LIMITS = address(0)` needs to be updated before use. This is noted in the handoff and is an operational concern, not a code bug.

### CONCERN 3: Redeployment clears ghost OI as side effect
The constructor change requires OILimits redeployment, which wipes all storage. The current ghost OI will be cleared by redeployment itself. `adminResetMarketOIFull` prevents future recurrence. This is correct behavior but the deployment team should understand that the function is for future protection, not for fixing the current issue.

### CONCERN 4: 2 pre-existing audit tests failing (P03, P06) from BUG-5 uncommitted changes
`test/audit/AuditNewFindings.t.sol`: P03 and P06 tests fail with EvmError:Revert. These failures are caused by the parallel LEVER-BUG-5 uncommitted changes to `ExecutionEngine.sol` and `InsuranceFund.sol` (constructor `_balance = 0`, socializeLoss scale conversion). NOT caused by BUG-3. BUG-5 test updates are needed to restore these.

---

## Test Results

```
GhostOI.t.sol:        4/4 PASS
OILimits.t.sol:       53/53 PASS
Integration.t.sol:    2/2 PASS
AuditFindings.t.sol:  8/8 PASS
VaultDrain.t.sol:     4/4 PASS (unrelated, confirms no regression)

Full suite could not run (solc OOM-killed, known server issue).
All individually-run test files affected by BUG-3 changes: 0 regressions.
Commit: 34e256b52
```

---

## Decision

**PASS** -- `adminResetMarketOIFull` is correctly implemented with on-chain safety check and per-user OI clearing. All critique notes addressed. No design flaws. No regressions from BUG-3 changes. Ready for OILimits redeployment (requires role re-granting per the 22-step deployment checklist).
