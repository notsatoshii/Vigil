# Critique: LEVER-BUG-9 — Vault NAV Missing Unrealized PnL
## Date: 2026-03-29T04:57:00Z
## Plan reviewed: handoffs/plan-lever-bug-9.md
## Codebase verified against: /home/lever/lever-protocol @ commit 9f77cc990

---

### Verdict: APPROVED (with notes — Step 3 already done by P06)

The plan's architecture is sound. The incremental delta on close (Step 3) is already implemented by LEVER-P06. The remaining work (keeper aggregation view + keeper entry point + keeper script + tests) is still needed and well-specified.

---

### What Is Good

- Correct two-part architecture: incremental deltas on close + periodic keeper full recompute. The delta prevents drift between keeper runs; the keeper catches price-driven changes.
- Clean separation: `computeNetUnrealizedPnL` (read-only aggregation) vs `updateUnrealizedPnL` (state write) vs `refreshUnrealizedPnL` (keeper entry combining both).
- Correct identification that LiquidationEngine/SettlementEngine also need delta updates (flagged as follow-up; keeper catches the gap).
- Good edge case analysis (zero positions, vault insolvency, keeper lag, pagination for large position counts).
- `getNetUnrealizedPnL` getter correctly identified as necessary.

---

### Issues Found

**1. [HIGH] Step 3 (delta update on close) and the vault getter are already done by LEVER-P06.**

Actual code at ExecutionEngine.sol lines 393-397:
```solidity
// FIX LEVER-P06: Remove this position's unrealized PnL from vault NAV tracking.
int256 currentUnrealized = leverVault.getNetUnrealizedPnL();
leverVault.updateUnrealizedPnL(currentUnrealized - pnl);
```

LeverVault.sol line 417-419:
```solidity
function getNetUnrealizedPnL() external view returns (int256) {
    return _netUnrealizedPnL;
}
```

ILeverVault.sol line 107: `function getNetUnrealizedPnL() external view returns (int256);`

All three pieces from Step 3 already exist. BUILD should skip Step 3 entirely.

The plan's `_updateVaultUnrealizedPnL` private helper and `getUnrealizedPnL` getter proposals are unnecessary; P06 does the same thing inline. Note the name difference: P06 uses `getNetUnrealizedPnL()`, the plan proposes `getUnrealizedPnL()`. The actual name is `getNetUnrealizedPnL`.

---

**2. [MEDIUM] The plan says "_netUnrealizedPnL is never updated in production". This is no longer true.**

P06 was applied (commit 91d86cd21, VERIFIED PASS). The delta update fires on every `_executeClose`. So `_netUnrealizedPnL` IS being updated on close. However, it is NOT updated for:
- Price changes between opens and closes (the keeper gap)
- Liquidations (LiquidationEngine has its own close path)
- Settlements (SettlementEngine has its own close path)

The plan's keeper (Parts B and C) would fill the price-change gap. The LiquidationEngine/SettlementEngine gap is correctly flagged as follow-up.

---

**3. [MEDIUM] `computeNetUnrealizedPnL` iterates ALL position IDs including closed ones**

The plan's view function:
```solidity
for (uint256 i = 1; i < nextId; ++i) {
    if (!positionManager.isPositionOpen(i)) continue;
    ...
}
```

This iterates ALL positions ever created, skipping closed ones. If 1000 positions were created and 990 are closed, it reads 1000 positions to find 10 open ones. Each iteration requires an external call to `isPositionOpen`.

A more efficient approach: MarginEngine could iterate only market-level open positions via `positionManager.getMarketPositions(marketId)` for each registered market. These arrays only contain open positions (closed ones are swap-and-pop removed, verified earlier). This avoids iterating closed positions entirely.

Not a blocker (the view function is off-chain, gas is free for eth_call), but worth noting for scalability.

---

**4. [LOW] File paths reference `/home/lever/Lever/`**

Same as all other plans. Actual codebase is at `/home/lever/lever-protocol/`.

---

**5. [LOW] Test values may need scale verification**

The plan's test descriptions use WAD notation (e.g., "1000e18" for $1000, line 278). Protocol amounts for positions and PnL are computed as `priceDiff * positionSize / WAD` where prices are WAD and sizes are USDT-scale (6 decimals). The resulting PnL is in USDT-scale (6 dec). BUILD should verify the expected test values match the actual scale by reading through one concrete computation path.

---

### Missing Steps

- Verify that the oracle keeper address has (or can be granted) `KEEPER_ROLE` on ExecutionEngine for `refreshUnrealizedPnL`.
- Consider using `getMarketPositions` per market instead of iterating all position IDs for the aggregation view (efficiency improvement).

---

### Edge Cases Not Covered

- **Concurrent keeper + close race:** If the keeper calls `refreshUnrealizedPnL` (full recompute, overwrites `_netUnrealizedPnL`) at the same instant a close calls `updateUnrealizedPnL(current - pnl)`, the close's delta could be based on a stale `current` value. On L2 with sequential transactions, this isn't an issue (transactions are ordered). But BUILD should note that the full recompute (keeper) supersedes any delta; the next delta after a keeper recompute will be correct because it reads the fresh `current`.

---

### Simpler Alternative

None. The plan's architecture (delta on close + periodic keeper) is already the standard pattern for tracking aggregate unrealized PnL in a vault.

---

### Revised Effort Estimate

**Small-Medium** (reduced from Medium). Step 3 is done. Remaining:
- `computeNetUnrealizedPnL` view function: 45 minutes
- `refreshUnrealizedPnL` keeper entry point: 30 minutes
- Keeper bash script: 15 minutes
- Tests: 1.5 hours
- Role grants and deploy: 30 minutes

---

### Recommendation

**Send to BUILD** with these notes:

1. **Skip Step 3.** Delta update on close and the `getNetUnrealizedPnL` getter are already implemented by LEVER-P06.
2. Focus on Steps 2, 4, 5, 6: the aggregation view, the keeper entry point, the keeper script, and tests.
3. Use `getNetUnrealizedPnL()` (the actual function name from P06), not `getUnrealizedPnL()`.
4. Consider using `getMarketPositions` per market instead of iterating all position IDs for the aggregation view.
5. Use `/home/lever/lever-protocol/` as project root.
6. Verify test expected values against actual amount scale (USDT 6-decimal vs WAD 18-decimal) by tracing one concrete computation.
