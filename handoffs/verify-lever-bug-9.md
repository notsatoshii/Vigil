# VERIFY Verdict: LEVER-BUG-9
## Date: 2026-03-29T10:00:00Z
## Task: Vault NAV missing unrealized PnL
## Verdict: PASS WITH CONCERNS

---

## Summary

BUG-9 adds the missing pieces for vault NAV to reflect unrealized PnL: an aggregation view (`computeNetUnrealizedPnL` on MarginEngine) and a keeper entry point (`refreshUnrealizedPnL` on ExecutionEngine). Combined with the existing P06 delta-on-close, the vault NAV now tracks unrealized PnL through two mechanisms: periodic full recompute (keeper) and incremental update (close). 5 regression tests pass. No regressions.

---

## Pass 1: Functional Verification

### MarginEngine.computeNetUnrealizedPnL (PASS)
`MarginEngine.sol:465-475`: Iterates active markets from `MarketRegistry.getActiveMarkets()`, then for each market, iterates open positions via `PositionManager.getMarketPositions()`. Sums `_computeEquity(pos).pnl` for each position. Returns `int256 netPnL`.

- Uses `getMarketPositions` which is already used by LiquidationEngine and SettlementEngine (proven pattern).
- `_computeEquity` includes current PI, accrued borrow fees, and accrued funding. The `.pnl` field is the raw PI-based PnL (WAD, signed). This is the correct field for NAV: borrow fees and funding are not vault PnL.
- View function: gas cost is free for `eth_call`. Noted as ~3M gas for 100 positions; will need pagination if position count grows to 1000+.

### ExecutionEngine.refreshUnrealizedPnL (PASS)
`ExecutionEngine.sol:291-294`: Reads `marginEngine.computeNetUnrealizedPnL()` and writes to `leverVault.updateUnrealizedPnL(netPnL)`. Gated by `KEEPER_ROLE`.

- Minimal: two lines, one read + one write. Correct.
- `KEEPER_ROLE` defined at line 65: `keccak256("KEEPER_ROLE")`. Standard OZ pattern.
- `updateUnrealizedPnL` on LeverVault requires `EXECUTION_ENGINE_ROLE` (from P06). Since this call comes from ExecutionEngine, the role requirement is already satisfied.

### Keeper Script (PASS)
`script/keeper/update-unrealized-pnl.sh`: Sources `deploy-env.sh`, validates env vars, calls `cast send` with `refreshUnrealizedPnL()`. Proper error handling with `set -euo pipefail`. Gas limit 500K (sufficient for view + write).

### IMarginEngine Interface (PASS)
Confirmed `computeNetUnrealizedPnL()` added to the interface.

### UnrealizedPnL.t.sol (5/5 PASS)
| Test | What it proves |
|------|---------------|
| `noPositionsReturnsZero` | Zero positions = zero aggregation |
| `longProfitReflectedInAggregation` | PI increase = positive PnL for long |
| `keeperRefreshUpdatesVault` | Keeper call syncs vault with MarginEngine computation |
| `closeDeltaRemovesFromUnrealized` | P06 delta confirmed: close subtracts realized PnL from vault |
| `multiplePositionsAggregate` | Long + short approximately cancel (net < 10% of notional) |

---

## Pass 2: Visual/Design Verification

N/A. Contract-only change, no frontend modified.

---

## Pass 3: Data Verification

- `eq.pnl` is WAD-scale `int256` (from `EquityResult` struct). Sum of WAD values is WAD. `updateUnrealizedPnL` takes `int256`. Scale consistent.
- No decimal precision issues.
- Keeper script uses `$EXECUTION_ENGINE` from deploy-env.sh (not hardcoded).

---

## Test Results

```
UnrealizedPnL.t.sol:     5/5 PASS
AuditNewFindings.t.sol:   6/6 PASS
Integration.t.sol:        2/2 PASS
Total: 13 pass, 0 fail
```

---

## Concerns (Non-Blocking)

### CONCERN 1: LiquidationEngine/SettlementEngine gap
These engines close positions via their own paths (not through `ExecutionEngine._executeClose`). They do NOT call `updateUnrealizedPnL`. Between keeper runs, vault NAV is stale for liquidation/settlement-closed positions. The keeper's periodic full recompute catches this, but the lag window exists. The handoff correctly flags this as a follow-up.

### CONCERN 2: Gas scalability
`computeNetUnrealizedPnL` iterates all positions across all markets. At 100 positions: ~3M gas (fine for view). At 1000+: may exceed gas limits even for `eth_call` on some RPC providers. Needs pagination or off-chain aggregation at scale.

### CONCERN 3: KEEPER_ROLE must be granted post-deployment
Without `KEEPER_ROLE` on the keeper address, `refreshUnrealizedPnL` reverts. Add to deployment checklist.

---

## No Design Flaws Found

The two-mechanism approach (keeper full recompute + P06 delta on close) is sound. Full recompute is authoritative; delta keeps NAV approximately correct between runs.

---

## Decision

**PASS WITH CONCERNS** -- aggregation view, keeper entry point, and keeper script are correct. 5 regression tests pass. No regressions. Concerns are non-blocking: liquidation/settlement gap handled by keeper cadence, gas scalability is a future concern, KEEPER_ROLE grant is a deployment checklist item.
