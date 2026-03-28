# Plan: LEVER-BUG-3 — Ghost OI (Stale Open Interest with Zero Positions)
## Date: 2026-03-28T13:45:00Z
## Requested by: Master (via Commander routing)

---

### Problem Statement

OILimits.sol reports substantial open interest across markets while PositionManager
has zero open positions. This causes three downstream failures:

1. **Vault utilization is artificially inflated** — the OI cap (60% of TVL) appears
   nearly or fully consumed, blocking any new position opens.
2. **Per-user OI caps remain exhausted** — individual users cannot open positions
   even after closing all their trades, because `_userOI[marketId][user]` was never
   decremented for orphaned positions.
3. **Funding rate calculations are wrong** — FundingRateEngine calls
   `oiLimits.getSideOI()` live; ghost OI makes matched/unmatched split meaningless.

---

### Root Cause

Ghost OI is a redeployment artifact, not a code bug in the normal close/liquidate/settle
paths.

All four normal OI decrement paths are correct:
- `ExecutionEngine._executeClose()` calls `decreaseOI` (line 373)
- `LiquidationEngine._closeAndSettle()` calls `decreaseOI` (line 402)
- `SettlementEngine.claimSettlement()` calls `decreaseOI` (line 262)
- `SettlementEngine.settleVoid()` calls `decreaseOI` in loop (line 318)

The gap is in the redeployment workflow documented in build-handoff.md:
> "After redeployment: depthThreshold must be set for all 20 markets, ghost OI must
> be reset, roles must be granted."

When PositionManager is redeployed (or its state is cleared as part of a contract
upgrade), the positions it tracks are wiped. OILimits.sol is not redeployed (it holds
accumulator state and is expensive to migrate). Result: OILimits still believes those
positions are open. There is no automatic sync between PositionManager state and OI
accumulators.

This matches the LESSONS.md entry: "OI/TVL Mismatch from Orphaned Positions — 36
orphaned positions after vault redeployment caused 441% utilization."

The audit fix LEVER-006 (now in production as P06) added `adminResetMarketOI()` to
OILimits.sol for exactly this scenario. However it has two defects:

**Defect A:** No on-chain verification. The function trusts the admin to verify zero
positions off-chain. If called with live positions, OI becomes negative (hits the
floor-at-zero logic), breaking cap enforcement silently.

**Defect B:** `_userOI[marketId][user]` is not cleared. After the reset, users who
held orphaned positions still have their per-user OI cap consumed. They cannot open
new positions even after global/market OI is cleared.

---

### Approach

Two-phase fix:

**Phase 1 (contract):** Improve `adminResetMarketOI` in OILimits.sol to accept an
explicit user list, add on-chain position count verification via PositionManager, and
clear per-user OI for all supplied addresses.

**Phase 2 (operational):** Create a Forge script that (a) diagnoses ghost OI by
comparing OILimits state with actual PositionManager state across all 20 markets,
and (b) executes the reset for affected markets with the correct user list built from
OI event history.

---

### Implementation Steps

#### Step 1: Verify PositionManager has a market position count view

Read `/home/lever/Lever/contracts/PositionManager.sol` and check for a function that
returns the count of open positions in a market. We need one of:
- `getMarketPositionCount(bytes32 marketId) returns (uint256)`
- `getMarketPositions(bytes32 marketId) returns (uint256[] memory)` (length = count)

If neither exists, add a view function to PositionManager (see Step 2 alt).

#### Step 2: Add `adminResetMarketOIFull` to OILimits.sol

Replace the existing `adminResetMarketOI(bytes32 marketId)` with an improved version
that also accepts a user list:

```solidity
/// @notice Emergency admin function to clear ghost OI after redeployment
/// @dev Reverts if market has any open positions — prevents misuse with live positions
/// @param marketId The market to reset
/// @param affectedUsers List of users whose per-user OI to clear
///        (build this list from OIIncreased events for the market)
function adminResetMarketOIFull(
    bytes32 marketId,
    address[] calldata affectedUsers
) external onlyRole(ADMIN_ROLE) nonReentrant {
    // On-chain safety check: revert if any positions still open
    uint256 posCount = positionManager.getMarketPositionCount(marketId);
    if (posCount != 0) revert OILimits__MarketHasOpenPositions(marketId, posCount);

    uint256 oldMarket = _marketOI[marketId];
    if (oldMarket == 0 && _longOI[marketId] == 0 && _shortOI[marketId] == 0) return;

    // Clear global OI
    _globalOI = oldMarket > _globalOI ? 0 : _globalOI - oldMarket;

    // Clear market accumulators
    _marketOI[marketId] = 0;
    _longOI[marketId] = 0;
    _shortOI[marketId] = 0;

    // Clear per-user OI for every known user in this market
    for (uint256 i = 0; i < affectedUsers.length; ++i) {
        _userOI[marketId][affectedUsers[i]] = 0;
    }

    emit OIReset(marketId, oldMarket, affectedUsers.length);
}
```

Add `OILimits__MarketHasOpenPositions(bytes32 marketId, uint256 count)` custom error.
Add `OIReset(bytes32 marketId, uint256 clearedAmount, uint256 userCount)` event.
Add `IPositionManager public immutable positionManager` storage reference (set in
constructor alongside existing references).

Keep the original `adminResetMarketOI` as a shim that calls the new one with an
empty user list, for backwards ABI compatibility. Or remove it if nothing calls it.

**IMPORTANT:** OILimits.sol constructor already takes contract references. Add
`positionManager` to the constructor parameter list. Since OILimits is NOT in the
protected-contract list, it can be redeployed. Cross-reference the deploy checklist
to ensure roles are re-granted after redeployment.

#### Step 3: Add market position count view to PositionManager (if missing)

If `getMarketPositionCount` does not exist:

```solidity
/// @notice Returns the number of open positions in a market
function getMarketPositionCount(bytes32 marketId) external view returns (uint256) {
    return _marketPositions[marketId].length();
}
```

This assumes `_marketPositions` is a EnumerableSet or similar structure already used
for `getMarketPositions`. If the internal data structure differs, adapt accordingly.

#### Step 4: Update IPositionManager interface

Add `getMarketPositionCount(bytes32 marketId) external view returns (uint256)` to the
interface at `/home/lever/Lever/contracts/interfaces/IPositionManager.sol`.

Add `getMarketPositionCount` to IOILimits or wherever the cross-contract interface
requires it.

#### Step 5: Create diagnostic Forge script

File: `/home/lever/Lever/script/DiagnoseGhostOI.s.sol`

Script reads all 20 market IDs from a hardcoded list (or from OracleAdapter), then
for each market prints:
- `_marketOI[marketId]`
- `_longOI[marketId]`
- `_shortOI[marketId]`
- `positionManager.getMarketPositionCount(marketId)`

Any market where OI > 0 and positionCount == 0 is a ghost OI market.

#### Step 6: Create reset Forge script

File: `/home/lever/Lever/script/ResetGhostOI.s.sol`

Script:
1. For each market: check OI and position count (same as diagnostic)
2. For markets with ghost OI: reconstruct `affectedUsers[]` by reading past
   `OIIncreased(marketId, ...)` events (via `vm.getRecordedLogs()` or hardcoded
   from event scan)
3. Call `oiLimits.adminResetMarketOIFull(marketId, affectedUsers)` for each ghost market
4. Re-query and assert ghost OI is now 0
5. Log results

#### Step 7: Write tests

File: `/home/lever/Lever/test/audit/GhostOI.t.sol`

Tests:
- **test_adminReset_clearsAllOI**: Open positions, force-remove them from
  PositionManager via mock (simulating redeployment), call `adminResetMarketOIFull`,
  assert all OI accumulators are zero including per-user.
- **test_adminReset_revertsIfPositionsOpen**: Call `adminResetMarketOIFull` while
  a position is open. Expect revert with `OILimits__MarketHasOpenPositions`.
- **test_adminReset_noopOnZeroOI**: Call on a market with no OI. Expect no state
  change and no revert.
- **test_adminReset_partialUserList**: Call with only some users in the list (simulate
  incomplete user enumeration). Verify named users are cleared but unlisted users are
  not. This is a safety test documenting the limitation.

---

### Files to Modify

- `/home/lever/Lever/contracts/OILimits.sol`
  - Add `IPositionManager public immutable positionManager` field
  - Add `positionManager` constructor parameter
  - Add `OILimits__MarketHasOpenPositions` custom error
  - Add `OIReset` event
  - Replace or improve `adminResetMarketOI` with `adminResetMarketOIFull`

- `/home/lever/Lever/contracts/PositionManager.sol`
  - Add `getMarketPositionCount(bytes32 marketId)` view (if missing)

- `/home/lever/Lever/contracts/interfaces/IPositionManager.sol`
  - Add `getMarketPositionCount` signature

- `/home/lever/Lever/contracts/interfaces/IOILimits.sol`
  - Add `adminResetMarketOIFull` signature
  - Add `OIReset` event

### Files to Create

- `/home/lever/Lever/script/DiagnoseGhostOI.s.sol`
  - Diagnostic: print OI vs position count for all 20 markets

- `/home/lever/Lever/script/ResetGhostOI.s.sol`
  - Operational: safely reset ghost OI markets

- `/home/lever/Lever/test/audit/GhostOI.t.sol`
  - 4 tests covering happy path, revert, no-op, partial user list

---

### Dependencies and Ripple Effects

- **OILimits redeployment required**: Adding `positionManager` to the constructor
  means OILimits must be redeployed. After redeployment, roles must be re-granted:
  EXECUTION_ENGINE_ROLE, LIQUIDATION_ENGINE_ROLE, SETTLEMENT_ENGINE_ROLE on OILimits.
  ExecutionEngine, LiquidationEngine, SettlementEngine must each point to the new
  OILimits address. Read deploy-env.sh and the 22-step redeployment checklist.

- **PositionManager**: If `getMarketPositionCount` is added, PositionManager does
  NOT need redeployment unless it was already on the list. The function is a pure
  view over existing state; no storage changes. If PositionManager is a protected
  contract, do NOT redeploy it. In that case, find an alternative for the on-chain
  check (e.g., read from AccountManager or track position count within OILimits itself).

- **FundingRateEngine**: Will immediately benefit from correct OI once ghost OI is
  cleared. No code changes needed there.

- **depthThreshold**: After redeployment, depthThreshold must still be set for all
  20 markets. This is already documented in build-handoff.md. Coordinate with the
  redeployment checklist.

---

### Edge Cases

- **Market with both live and ghost OI**: Impossible with the on-chain position check,
  because `adminResetMarketOIFull` reverts if any position exists. Ghost OI can only
  be cleared when position count is zero.

- **Incomplete user list**: If the admin provides only 15 of 20 users who held OI
  in a market, the 5 unlisted users retain their `_userOI` caps. Global/market/side
  OI is still cleared correctly. Document this as a known limitation: admin MUST
  enumerate all users from OIIncreased events before calling.

- **Multi-market ghost OI**: Each market is reset independently. Loop over all 20
  markets in the reset script.

- **_globalOI consistency**: Subtracting each market's OI from `_globalOI` in
  sequence is correct as long as markets are reset one at a time. Parallel calls by
  the same admin could cause a race (nonReentrant prevents this within one tx; the
  script should batch markets in a single transaction or verify after each call).

- **PositionManager is protected**: If PositionManager cannot be modified, check if
  `getMarketPositions(bytes32)` already exists and returns an array (use `.length`).
  As a last resort, OILimits can accept a keeper-attested position count as a
  separate admin function, but on-chain verification is strongly preferred.

---

### Test Plan

- **test_adminReset_clearsAllOI**: Confirm all five accumulators (global, market,
  long, short, per-user for each supplied address) are zero after reset.
- **test_adminReset_revertsIfPositionsOpen**: Confirm the function reverts with the
  right custom error when market has live positions.
- **test_adminReset_noopOnZeroOI**: Confirm no state mutation and no revert when
  called on an already-zero market.
- **test_adminReset_partialUserList**: Confirm unlisted users retain stale userOI
  (documents the limitation and prevents silent surprise).
- **Run existing OILimits test suite**: Ensure no regressions. 1074 tests must still
  pass.

---

### Effort Estimate

**Small-Medium.** The contract change is focused (one function, one new immutable,
two new events/errors). PositionManager may need a one-line view function. Scripts
are straightforward Forge scripts. The main uncertainty is whether PositionManager
is a protected contract (affects whether we can add the view function or need an
alternative approach for on-chain verification).

Primary risk: the redeployment of OILimits requires careful role re-granting. This
is well-documented in the existing checklist, but must be coordinated with the other
9 contracts already queued for redeployment.

---

### Rollback Plan

OILimits is redeployable (not in the protected list). If the new version has issues:
1. Redeploy the previous OILimits (no positionManager param)
2. Re-grant roles to the old address
3. Update env vars in deploy-env.sh

Ghost OI will persist until a correct fix is shipped, but the protocol remains
operational with artificially inflated utilization (users can still close positions;
they just cannot open new ones while OI cap appears consumed).

---

### Open Questions

1. **Is PositionManager protected?** The protected list in CLAUDE.md includes
   PositionManager: "ExecutionEngine, LeverageModel, LeverVault, PositionManager,
   SettlementEngine, LiquidationEngine." If PositionManager cannot be modified,
   check whether `getMarketPositions(bytes32)` already exists. If not, implement
   on-chain verification by tracking a position count inside OILimits directly
   (increment in `increaseOI`, decrement in `decreaseOI`) rather than reading from
   PositionManager. This avoids the cross-contract dependency entirely and is arguably
   cleaner. BUILD should check this before writing code.

2. **What is the current ghost OI amount and which markets are affected?** Run
   DiagnoseGhostOI.s.sol first (or a manual cast call) to quantify scope before
   calling any reset. The KANBAN entry says $3.2M; if this has changed post-audit-fix,
   the number may be different now.

3. **User enumeration strategy**: The reset script needs the list of users who held
   OI in each affected market. These can be recovered from `OIIncreased` events on
   the OILimits contract. BUILD should include event-query logic in the script.
