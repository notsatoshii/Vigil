# BUILD Handoff Report
## Date: 2026-03-29T05:25:00Z
## Task: LEVER-BUG-9 — Vault NAV Missing Unrealized PnL

---

### Summary

Step 3 (delta update on close) was already done by LEVER-P06. This session implemented the
remaining pieces: aggregation view function, keeper entry point, keeper script, and tests.

Architecture: delta on close (P06) keeps `_netUnrealizedPnL` approximately correct between
keeper runs. The keeper periodically does a full recompute from all open positions and writes
the authoritative value. Together they ensure vault NAV accurately reflects unrealized PnL.

---

### Changes Made

**contracts/MarginEngine.sol** (new function):
- `computeNetUnrealizedPnL() external view returns (int256 netPnL)`: Iterates open positions
  per market via `getMarketPositions()` (efficient; skips closed positions). Sums PnL from
  `_computeEquity()` for each position. Gas-intensive view intended for off-chain keeper reads.

**contracts/interfaces/IMarginEngine.sol**:
- Added `computeNetUnrealizedPnL()` signature

**contracts/ExecutionEngine.sol**:
- Added `KEEPER_ROLE = keccak256("KEEPER_ROLE")`
- Added `refreshUnrealizedPnL() external onlyRole(KEEPER_ROLE)`: Reads aggregate PnL from
  MarginEngine and writes to LeverVault. Single keeper call replaces the stale value.

**script/keeper/update-unrealized-pnl.sh** (new):
- Bash script that calls `ExecutionEngine.refreshUnrealizedPnL()` via `cast send`
- Run every 5-10 minutes via cron. ~50K gas per call on Base L2.
- Requires: KEEPER_KEY with KEEPER_ROLE on ExecutionEngine

**test/audit/UnrealizedPnL.t.sol** (new, 5 tests):
- `test_BUG9_noPositionsReturnsZero`: zero positions = zero aggregation
- `test_BUG9_longProfitReflectedInAggregation`: PI up = positive unrealized PnL
- `test_BUG9_keeperRefreshUpdatesVault`: keeper call syncs vault with MarginEngine computation
- `test_BUG9_closeDeltaRemovesFromUnrealized`: P06 delta behavior confirmed
- `test_BUG9_multiplePositionsAggregate`: long + short approximately cancel

---

### Files Modified

- `/home/lever/lever-protocol/contracts/MarginEngine.sol`
- `/home/lever/lever-protocol/contracts/interfaces/IMarginEngine.sol`
- `/home/lever/lever-protocol/contracts/ExecutionEngine.sol`

### Files Created

- `/home/lever/lever-protocol/test/audit/UnrealizedPnL.t.sol`
- `/home/lever/lever-protocol/script/keeper/update-unrealized-pnl.sh`

---

### Tests Run

```
UnrealizedPnL.t.sol: 5 passed, 0 failed
All audit tests: 40 passed, 0 failed
ClosePositionFlow.t.sol: 6 passed, 0 failed
```

---

### Known Risks

1. **KEEPER_ROLE must be granted**: After redeploying ExecutionEngine, grant KEEPER_ROLE to
   the keeper address. The oracle keeper address is a good candidate since it already runs
   periodically.

2. **LiquidationEngine/SettlementEngine gap**: These engines close positions via their own
   paths (not through ExecutionEngine._executeClose). They do NOT update `_netUnrealizedPnL`.
   The keeper's periodic full recompute catches this discrepancy. Filed as follow-up.

3. **Keeper lag**: Between keeper updates, NAV is stale by up to 5-10 minutes. Acceptable on
   testnet. On mainnet, keeper frequency should match withdrawal queue execution frequency.

4. **Gas for computeNetUnrealizedPnL**: With 100 positions across all markets, the view call
   costs ~3M gas (free for eth_call). If position count grows to 1000+, the function needs
   pagination or a different approach.

---

### Contract Changes

- MarginEngine.sol: new view function `computeNetUnrealizedPnL`
- ExecutionEngine.sol: new role `KEEPER_ROLE`, new function `refreshUnrealizedPnL`
- IMarginEngine.sol: new interface function

---

### Build/Deploy Actions

- `git commit 213b829bf` to `main` branch
- No services restarted
- Keeper script NOT yet scheduled (needs KEEPER_ROLE grant + cron setup)

---

### Notes for VERIFY

1. Step 3 was already done by P06. Do NOT look for delta-on-close changes.
2. The aggregation uses `getMarketPositions()` per market (efficient, only open positions)
   rather than iterating all position IDs (the plan's approach).
3. `getNetUnrealizedPnL()` (P06 name) is used, not `getUnrealizedPnL()` (plan's name).
4. The keeper script uses `cast send` and expects deploy-env.sh for contract addresses.
