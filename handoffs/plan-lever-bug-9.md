# Plan: LEVER-BUG-9 — Vault NAV Missing Unrealized PnL
## Date: 2026-03-28T16:28:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

LeverVault's `totalAssets()` computes NAV as:
```solidity
NAV = usdt.balanceOf(vault) - _netUnrealizedPnL - _socializedLosses
```

The `_netUnrealizedPnL` variable is **never updated in production**. It stays at zero forever.
The `updateUnrealizedPnL(int256 newPnL)` function exists (line 314) and is callable by
ExecutionEngine, but no contract ever calls it. It is only used in unit tests.

**Consequence:** The vault's NAV ignores all unrealized PnL from open positions. When traders
are profitable but haven't closed yet, the vault overstates its NAV. When traders are losing,
the vault understates its NAV.

This directly affects:
- **LP share price:** ERC4626 `previewDeposit`, `previewRedeem`, and all share calculations
  use `totalAssets()`. Share price is wrong.
- **Deposits:** New LPs buy shares at inflated price when traders are profitable (diluting
  existing LPs). Or at deflated price when traders are losing (gifting value to new LPs).
- **Withdrawals:** LPs redeem at wrong prices for the same reasons.
- **Protocol metrics:** TVL, utilization ratios, and risk metrics that read `totalAssets()` are wrong.

**Current testnet state:** TVL shows $502K, share price $1.000007. With ~$4.3K OI, the
unrealized PnL impact is small, but it grows linearly with OI and price moves.

---

### Current Code State

**LeverVault.sol line 79:**
```solidity
int256 private _netUnrealizedPnL;  // always 0 in production
```

**LeverVault.sol lines 130-134:**
```solidity
function totalAssets() public view override(ERC4626, IERC4626) returns (uint256) {
    uint256 balance = usdt.balanceOf(address(this));
    int256 nav = int256(balance) - _netUnrealizedPnL - int256(_socializedLosses);
    return nav > 0 ? uint256(nav) : 0;
}
```

**LeverVault.sol lines 312-318:**
```solidity
function updateUnrealizedPnL(int256 newPnL) external onlyRole(EXECUTION_ENGINE_ROLE) {
    int256 oldPnL = _netUnrealizedPnL;
    _netUnrealizedPnL = newPnL;
    emit UnrealizedPnLUpdated(oldPnL, newPnL);
}
```

**ExecutionEngine.sol — openPosition (line 156-179):** No call to `updateUnrealizedPnL`.

**ExecutionEngine.sol — _executeClose (lines 348-380):** No call to `updateUnrealizedPnL`.

**MarginEngine.sol — _computeEquity (lines 361-389):** Computes per-position unrealized PnL
on demand, but never aggregates across all positions.

**PositionManager.sol:** Has `getMarketPositions(marketId)`, `getUserPositions(user)`,
`isPositionOpen(posId)`, sequential position IDs from 1 to `nextPositionId - 1`. No
`getAllOpenPositions()` function, but positions can be iterated by ID.

---

### Approach

Two-part fix: **incremental delta tracking on open/close** + **keeper for price-driven changes**.

#### Part A: Incremental delta updates in ExecutionEngine

When a position **opens**: unrealized PnL starts at ~0 (position just opened at the current
price). No material NAV impact. No update needed.

When a position **closes**: the position's unrealized PnL has been part of `_netUnrealizedPnL`
(or should have been). At close, this PnL becomes realized (vault pays profit via
`fundTraderPnL` or receives loss via `transferOut`). The closed position's unrealized PnL must
be subtracted from `_netUnrealizedPnL` so it is not counted twice.

Delta on close: `_netUnrealizedPnL -= positionUnrealizedPnL`

This ensures that `_netUnrealizedPnL` correctly reflects only OPEN positions.

#### Part B: Keeper for price-driven changes

Between opens and closes, oracle price movements change every open position's unrealized PnL.
No on-chain transaction triggers this update. A keeper must periodically:
1. Iterate all open positions (off-chain or via a view helper)
2. Sum unrealized PnL across all positions
3. Call `updateUnrealizedPnL(sum)` on-chain

Keeper frequency: every 5-10 minutes is sufficient for NAV accuracy. Critical accuracy is
only needed at deposit/withdraw time, and withdrawals go through a queue.

#### Part C: View helper for off-chain computation

Add a `computeNetUnrealizedPnL` view function to MarginEngine (or a separate helper contract)
that iterates all open positions and returns the aggregate. The keeper reads this, and anyone
can verify the vault's NAV off-chain.

---

### Implementation Steps

**Step 1: Run existing tests**

```bash
cd /home/lever/Lever
forge build
forge test --match-path "test/LeverVault.t.sol" -v
```

---

**Step 2: Add `computeNetUnrealizedPnL` view function to MarginEngine**

New function in `contracts/MarginEngine.sol`:

```solidity
/// @notice Compute aggregate unrealized PnL across all open positions
/// @dev Iterates all position IDs from 1 to nextPositionId. Gas-intensive view;
///      intended for keeper reads and off-chain queries, not on-chain state updates.
/// @return netPnL Sum of unrealized PnL (positive = traders profitable = vault liability)
function computeNetUnrealizedPnL() external view returns (int256 netPnL) {
    uint256 nextId = positionManager.nextPositionId();
    for (uint256 i = 1; i < nextId; ++i) {
        if (!positionManager.isPositionOpen(i)) continue;
        IPositionManager.Position memory pos = positionManager.getPosition(i);
        EquityResult memory eq = _computeEquity(pos);
        netPnL += eq.pnl;
    }
}
```

This is a `view` function (no gas cost for off-chain calls). On-chain calls would be expensive
for many positions. The keeper calls it off-chain with `eth_call`, then submits the result.

**Gas consideration:** On Base L2, iterating 100 positions in a view call is fine (no real gas
cost for eth_call). On mainnet, this would need pagination or a different approach.

Add to `IMarginEngine.sol`:
```solidity
/// @notice Compute net unrealized PnL across all open positions
function computeNetUnrealizedPnL() external view returns (int256 netPnL);
```

---

**Step 3: Add delta update in ExecutionEngine._executeClose**

In `contracts/ExecutionEngine.sol`, `_executeClose` (after computing PnL at line 353, before
any state changes):

```solidity
function _executeClose(uint256 positionId, IPositionManager.Position memory pos) private {
    uint256 pi = oracleAdapter.getPI(pos.marketId);
    (uint256 exitPrice,) = _computeExecutionPrice(pos.marketId, pos.isLong, pos.positionSize, pi, false);

    int256 pnl = _computePnL(pos.isLong, pi, pos.entryPI, pos.positionSize);
    uint256 borrowFees = borrowFeeEngine.getAccruedFees(positionId);
    int256 accruedFunding = fundingRateEngine.getAccruedFunding(positionId);

    uint256 closingFee = feeRouter.computeTransactionFee(pos.positionSize);

    // Update vault's unrealized PnL: remove this position's PnL (it's becoming realized)
    _updateVaultUnrealizedPnL(-pnl);

    uint256 badDebt = _settlePnL(pos.owner, pos.collateral, pnl, borrowFees, accruedFunding, closingFee);
    // ... rest unchanged
}
```

New private helper:
```solidity
/// @dev Adjust vault's net unrealized PnL by a delta
function _updateVaultUnrealizedPnL(int256 delta) private {
    int256 current = leverVault.getUnrealizedPnL();
    leverVault.updateUnrealizedPnL(current + delta);
}
```

This requires a getter on LeverVault:
```solidity
/// @notice Get current net unrealized PnL
function getUnrealizedPnL() external view returns (int256) {
    return _netUnrealizedPnL;
}
```

Add to `ILeverVault.sol`:
```solidity
function getUnrealizedPnL() external view returns (int256);
```

**Why `-pnl`?** When a position closes, its unrealized PnL (`pnl`) leaves the unrealized
pool. If the position had +500 unrealized PnL (trader profitable), closing it subtracts 500
from `_netUnrealizedPnL`. The 500 is now realized via `fundTraderPnL`/`transferOut`.

---

**Step 4: Create keeper script**

New file: `script/keeper/UpdateUnrealizedPnL.s.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../contracts/interfaces/IMarginEngine.sol";
import "../contracts/interfaces/ILeverVault.sol";

contract UpdateUnrealizedPnL is Script {
    function run() external {
        IMarginEngine marginEngine = IMarginEngine(vm.envAddress("MARGIN_ENGINE"));
        ILeverVault vault = ILeverVault(vm.envAddress("LEVER_VAULT"));

        // Compute net unrealized PnL off-chain (view call, no gas)
        int256 netPnL = marginEngine.computeNetUnrealizedPnL();

        // Submit on-chain update
        vm.startBroadcast();
        vault.updateUnrealizedPnL(netPnL);
        vm.stopBroadcast();

        console.log("Updated net unrealized PnL to:", netPnL);
    }
}
```

Alternatively, a simple bash script using `cast`:
```bash
#!/bin/bash
source /home/lever/Lever/deploy-env.sh

# Read net unrealized PnL (view call, free)
NET_PNL=$(cast call $MARGIN_ENGINE "computeNetUnrealizedPnL()(int256)" --rpc-url $RPC_URL)

# Submit on-chain update (costs gas)
cast send $LEVER_VAULT "updateUnrealizedPnL(int256)" "$NET_PNL" \
  --rpc-url $RPC_URL --private-key $KEEPER_KEY
```

This script should run every 5-10 minutes via cron or systemd timer. The update only costs
~50K gas on Base (one storage write + event).

**IMPORTANT:** The keeper must use an address that has `EXECUTION_ENGINE_ROLE` on LeverVault.
Either grant the role to the keeper address, or route the call through ExecutionEngine (which
already has the role). Routing through ExecutionEngine is cleaner:

Add to ExecutionEngine:
```solidity
/// @notice Update vault's net unrealized PnL (keeper-callable)
function refreshUnrealizedPnL() external onlyRole(KEEPER_ROLE) {
    int256 netPnL = marginEngine.computeNetUnrealizedPnL();
    leverVault.updateUnrealizedPnL(netPnL);
}
```

This way, the keeper calls `ExecutionEngine.refreshUnrealizedPnL()` with KEEPER_ROLE (which
the oracle keeper already has). ExecutionEngine calls vault with EXECUTION_ENGINE_ROLE.

---

**Step 5: Write tests**

**5a. `testNAVDecreasesWhenTradersProfit`**
- LP deposits 10,000 USDT. NAV = 10,000.
- Open a long position. Move PI up (trader profits by 1,000).
- Call `refreshUnrealizedPnL` (or manually `updateUnrealizedPnL(1000e18)`).
- Verify: `totalAssets() == 9,000` (vault owes 1,000 unrealized)
- Verify: share price decreased

**5b. `testNAVIncreasesWhenTradersLose`**
- LP deposits 10,000 USDT.
- Open a long position. Move PI down (trader loses 500).
- Update unrealized PnL.
- Verify: `totalAssets() == 10,500` (vault gained from trader loss)

**5c. `testCloseDeltaRemovesFromUnrealized`**
- Set `_netUnrealizedPnL = 1000e18` (traders are +1000 unrealized)
- Close one position with pnl = +400
- Verify: `_netUnrealizedPnL == 600e18` (1000 - 400)
- Verify: vault's USDT balance decreased by 400 (fundTraderPnL)
- NAV correctly reflects both changes

**5d. `testDepositAtCorrectSharePrice`**
- LP1 deposits 10,000. Gets 10,000 shares.
- Trader profits 2,000 unrealized. Update PnL.
- NAV = 8,000. Share price = 0.80.
- LP2 deposits 4,000. Should get 4,000 / 0.80 = 5,000 shares.
- Verify: LP2 got 5,000 shares (not 4,000 at par value)

**5e. `testComputeNetUnrealizedPnL`**
- Open 3 positions: 2 longs, 1 short
- Move PI so longs profit, short loses
- Call `marginEngine.computeNetUnrealizedPnL()`
- Verify: result equals manual computation of sum(position PnLs)

---

**Step 6: Run full test suite**

```bash
forge test -v
```

---

### Files to Modify

- `contracts/MarginEngine.sol` — add `computeNetUnrealizedPnL` view function
- `contracts/interfaces/IMarginEngine.sol` — add function signature
- `contracts/LeverVault.sol` — add `getUnrealizedPnL` view function
- `contracts/interfaces/ILeverVault.sol` — add function signature
- `contracts/ExecutionEngine.sol`
  - `_executeClose`: add delta update before settlement
  - Add `refreshUnrealizedPnL` keeper-callable function
  - Add `_updateVaultUnrealizedPnL` private helper

### Files to Create

- `script/keeper/update-unrealized-pnl.sh` — keeper script (bash + cast)

### Files to Read First

- `contracts/LeverVault.sol` lines 75-134 (state, totalAssets), 312-336 (updateUnrealizedPnL,
  fundTraderPnL, socializeLoss)
- `contracts/ExecutionEngine.sol` lines 348-380 (_executeClose, full flow)
- `contracts/MarginEngine.sol` lines 361-389 (_computeEquity per position)
- `contracts/core/PositionManager.sol` lines 175-207 (position queries, iteration)
- `contracts/interfaces/ILeverVault.sol` — current interface

---

### Dependencies and Ripple Effects

- **ERC4626 deposit/withdraw:** All share calculations use `totalAssets()`. After this fix,
  share prices will be accurate. Existing LPs may see their share value change when the first
  `updateUnrealizedPnL` call sets a non-zero value.

- **Withdrawal queue:** `executeWithdrawal` (line 249) uses `totalAssets()` to compute payout.
  With accurate NAV, withdrawals pay the correct amount.

- **Tranche system:** `totalValue()` (line 385) uses `totalAssets()`. Tranche valuations
  become accurate.

- **ExecutionEngine role:** ExecutionEngine already has `EXECUTION_ENGINE_ROLE` on LeverVault
  (needed for `fundTraderPnL`). No new role grants needed for the delta update.

- **Keeper role:** `refreshUnrealizedPnL` uses `KEEPER_ROLE` on ExecutionEngine. The oracle
  keeper address should already have this role. Verify in deployment.

- **LiquidationEngine and SettlementEngine:** These engines also close positions but do NOT
  call `_executeClose` in ExecutionEngine. They have their own close flows. For full
  accuracy, they should ALSO update `_netUnrealizedPnL` when closing positions. This is a
  follow-up item. For now, the keeper's periodic full recompute catches the discrepancy.

---

### Edge Cases

**Zero open positions:** `computeNetUnrealizedPnL` returns 0. `updateUnrealizedPnL(0)` is
valid. NAV = balance - 0 - socializedLosses. Correct.

**All positions profitable (vault liability exceeds balance):** NAV could go negative.
`totalAssets()` already handles this: `return nav > 0 ? uint256(nav) : 0`. Share price
becomes 0. LPs cannot withdraw more than the vault holds. This is the correct response to
vault insolvency.

**Keeper lag:** Between keeper updates, NAV is stale by up to 5-10 minutes. During this
window, deposits and withdrawals use slightly incorrect share prices. On testnet this is
acceptable. On mainnet, the keeper frequency should match the withdrawal queue's execution
frequency.

**Position close between keeper updates:** The delta update in `_executeClose` keeps
`_netUnrealizedPnL` approximately correct even between keeper runs. When a position closes,
its PnL is immediately removed from the unrealized total. The keeper's next full recompute
re-syncs any drift from price changes.

**Gas for computeNetUnrealizedPnL:** With 100 positions, each requiring ~3 external calls
(getPI, getAccruedFees, getAccruedFunding) plus struct reads: ~3M gas in a view call. On
Base L2, this is fine for eth_call. If position count grows to 1000+, the function needs
pagination (pass start/end range).

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `testNAVDecreasesWhenTradersProfit` | NAV reflects trader profits as vault liability |
| `testNAVIncreasesWhenTradersLose` | NAV reflects trader losses as vault gain |
| `testCloseDeltaRemovesFromUnrealized` | Close removes position's PnL from aggregate |
| `testDepositAtCorrectSharePrice` | Share minting uses accurate NAV |
| `testComputeNetUnrealizedPnL` | View function correctly aggregates all positions |

---

### Effort Estimate

**Medium** — 4-6 hours.
- `computeNetUnrealizedPnL` view function: 1 hour
- `getUnrealizedPnL` getter: 15 minutes
- Delta update in `_executeClose`: 30 minutes
- `refreshUnrealizedPnL` keeper entry point: 30 minutes
- Keeper script: 30 minutes
- Tests: 2 hours

---

### Rollback Plan

Revert the delta update in `_executeClose` and the `refreshUnrealizedPnL` function.
`_netUnrealizedPnL` returns to 0. NAV overstates when traders profit, understates when they
lose. No position integrity risk, just incorrect LP share pricing.

The `computeNetUnrealizedPnL` view function is read-only and can be left in place even after
rollback (useful for monitoring).

---

### Open Questions

1. **LiquidationEngine and SettlementEngine:** These also close positions but bypass
   ExecutionEngine. Should they also update `_netUnrealizedPnL`? For full accuracy, yes.
   For this plan, the keeper's periodic recompute catches the delta. File as a follow-up
   if needed.

2. **Keeper scheduling:** Should this use the existing oracle keeper process or a new one?
   Recommendation: add it to the existing `lever-accrue-keeper` service (which already runs
   periodically for borrow fee accrual). One extra `cast send` call per cycle.

---

### KANBAN Update

Move LEVER-BUG-9 to PLANNED.
