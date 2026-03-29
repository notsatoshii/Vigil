# BUILD Handoff Report
## Date: 2026-03-29T04:30:00Z
## Task: LEVER-BUG-3 — Ghost OI (Stale Open Interest with Zero Positions)

---

### Summary

Added `adminResetMarketOIFull` to OILimits.sol with two improvements over the
original `adminResetMarketOI`:
1. On-chain safety check: reverts if market has any open positions in PositionManager
2. Per-user OI clearing: accepts a user list and zeros their `_userOI` entries

Also added `IPositionManager` as an immutable reference in OILimits (constructor change),
wrote 4 regression tests, and created diagnostic/reset Forge scripts.

---

### Changes Made

**contracts/OILimits.sol:**
- Added `IPositionManager public immutable positionManager` storage reference
- Updated constructor to accept `_positionManager` address (4th param before admin)
- Added `adminResetMarketOIFull(bytes32 marketId, address[] calldata affectedUsers)`:
  - Calls `positionManager.getMarketPositions(marketId).length` for on-chain position count
  - Reverts with `OILimits__MarketHasOpenPositions` if any positions exist
  - Clears `_globalOI`, `_marketOI`, `_longOI`, `_shortOI` for the market
  - Clears `_userOI[marketId][user]` for each supplied user
  - Emits `OIReset(marketId, clearedAmount, userCount)`
- Original `adminResetMarketOI` kept for backwards compat (does not clear per-user OI)

**contracts/interfaces/IOILimits.sol:**
- Added `OILimits__MarketHasOpenPositions` error
- Added `OIReset` event
- Added `adminResetMarketOIFull` function signature

**All constructor call sites updated** (13 files total):
- test/OILimits.t.sol, test/Integration.t.sol, test/integration/IntegrationBase.sol
- test/audit/AuditFindings.t.sol
- script/Deploy.s.sol, script/DeployEngines.s.sol, script/RedeployAuditFixes.s.sol
- script-disabled/Deploy.s.sol

---

### Files Modified
- /home/lever/lever-protocol/contracts/OILimits.sol
- /home/lever/lever-protocol/contracts/interfaces/IOILimits.sol
- /home/lever/lever-protocol/test/OILimits.t.sol
- /home/lever/lever-protocol/test/Integration.t.sol
- /home/lever/lever-protocol/test/integration/IntegrationBase.sol
- /home/lever/lever-protocol/test/audit/AuditFindings.t.sol
- /home/lever/lever-protocol/script/Deploy.s.sol
- /home/lever/lever-protocol/script/DeployEngines.s.sol
- /home/lever/lever-protocol/script/RedeployAuditFixes.s.sol
- /home/lever/lever-protocol/script-disabled/Deploy.s.sol

### Files Created
- /home/lever/lever-protocol/test/audit/GhostOI.t.sol (4 tests)
- /home/lever/lever-protocol/script/DiagnoseGhostOI.s.sol (diagnostic)
- /home/lever/lever-protocol/script/ResetGhostOI.s.sol (operational reset)

---

### Tests Run

```
GhostOI.t.sol: 4 passed, 0 failed
  test_adminReset_clearsAllOI
  test_adminReset_revertsIfPositionsOpen
  test_adminReset_noopOnZeroOI
  test_adminReset_partialUserList

OILimits.t.sol: 53 passed, 0 failed (no regressions)

Full suite: 1068 passed, 22 failed
  - 4 pre-existing: PriceSmoothingVerification.t.sol
  - 18 from parallel LEVER-BUG-4 InsuranceFund changes (not from this PR)
  - 0 failures related to OILimits or GhostOI
```

---

### Known Risks

1. **Constructor change requires OILimits redeployment.** After redeployment, all roles
   must be re-granted (EXECUTION_ENGINE_ROLE, LIQUIDATION_ENGINE_ROLE, SETTLEMENT_ENGINE_ROLE).
   All engines pointing to OILimits must be updated with the new address.

2. **Redeployment itself clears ghost OI** (fresh storage). The new `adminResetMarketOIFull`
   prevents future ghost OI recurrence after subsequent PositionManager redeployments.

3. **Incomplete user list limitation.** If the admin provides fewer users than actually
   held OI, unlisted users retain stale per-user OI caps. Documented in test 4.
   Users must be enumerated from `OIIncreased` events before calling.

4. **Redeployment race.** If a position opens between diagnostic and redeployment, the
   new OILimits starts at zero OI but a position exists. Pause ExecutionEngine before
   redeploying to prevent this.

---

### Contract Changes

- OILimits.sol: constructor signature changed (added positionManager param),
  new admin function added. **Requires redeployment.**
- PositionManager: NOT modified. Uses existing `getMarketPositions(bytes32)` view.

---

### Build/Deploy Actions

- `git commit 34e256b52` on `main` branch
- No on-chain deployment performed (requires Master approval for contract changes)
- Scripts ready: DiagnoseGhostOI.s.sol and ResetGhostOI.s.sol need OI_LIMITS address
  updated before use

---

### Critique Notes Addressed

Per critique-lever-bug-3.md (APPROVED with notes):
1. Used `positionManager.getMarketPositions(marketId).length` (no PositionManager modification)
2. Used `/home/lever/lever-protocol/` as project root
3. OILimits inherits ReentrancyGuard (confirmed), so `nonReentrant` works
4. Diagnostic script confirms zero positions before reset
5. Error/event declared in IOILimits interface (not duplicated in contract)
