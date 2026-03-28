# Plan: LEVER-BUG-6 — FeeRouter Called Without USDT by Liquidation/Settlement
## Date: 2026-03-28T15:50:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

LiquidationEngine and SettlementEngine call `feeRouter.routeFees()` to distribute protocol fees.
FeeRouter.routeFees() assumes USDT tokens are already in its balance (it does three `safeTransfer`
calls to distribute them).

An ad-hoc fix (FIX LEVER-005) added `accountManager.transferOut(address(feeRouter), fee)` before
each `routeFees` call. This made the FeeRouter call succeed. **But it introduced a worse bug:**
the fee amount is now double-spent in LiquidationEngine, and SettlementEngine has a separate
collateral double-counting bug that the fee transfer compounds.

**There are three layers of accounting errors:**

#### Layer 1: LiquidationEngine fee double-spend

In `_executeLiquidation`, the execution order is:
1. Step 4 (line 339): `_routeFee(fee, liquidator)` — transfers fee USDT from AccountManager to FeeRouter
2. Step 6 (line 348): `_closeAndSettle(pos, positionId, traderReceives)` — sends `loss` to vault

The problem: `loss = collateral - traderReceives` where `traderReceives = equity - fee`.
So `loss = collateral - equity + fee`. **The loss includes the fee.**

The fee is sent to BOTH:
- FeeRouter (in step 4, via `accountManager.transferOut`)
- LeverVault (in step 6, as part of `loss` via `accountManager.transferOut`)

**Concrete numbers:**
- collateral = 100, equity = 50, fee = 10
- traderReceives = 50 - 10 = 40, loss = 100 - 40 = 60
- USDT sent to FeeRouter: 10 (or 9 to FeeRouter + 1 bounty credited)
- USDT sent to vault: 60 (includes the fee)
- Total out: 70. But only 100 in AccountManager for this trader.
- Trader's balance debited: 60 (via debitPnL(loss))
- Trader keeps: 40. Liquidator gets: 1 (bounty).
- AccountManager USDT: 100 - 70 = 30. Internal balances owed: 40 + 1 = 41.
- **Deficit: 11 USDT** (the fee amount leaks every liquidation)

#### Layer 2: SettlementEngine collateral double-counting

In `claimSettlement` (lines 261-268):
```solidity
accountManager.releaseCollateral(pos.owner, pos.collateral);  // unlocks collateral

if (result.payout > 0) {
    accountManager.creditPnL(pos.owner, result.payout);  // adds payout to balance
}
```

For winners: `payout = equity - fee = (collateral + pnl - borrowFees + funding) - fee`.

`releaseCollateral` does NOT change `_balances`, only `_lockedCollateral`. Then `creditPnL`
ADDS `payout` to `_balances`. But `payout` includes the collateral amount (equity includes
collateral). So the trader's balance becomes:

`original_balance + payout = collateral + (collateral + pnl - fees) = 2*collateral + pnl - fees`

The correct amount is `collateral + pnl - fees`. **Collateral is double-counted.**

Compare to ExecutionEngine._settlePnL (the correct pattern, lines 396-404):
```solidity
accountManager.releaseCollateral(owner, collateral);
int256 pnlDelta = pnl - int256(borrowFees) - int256(closingFee) + accruedFunding;
if (pnlDelta > 0) accountManager.creditPnL(owner, uint256(pnlDelta));
else if (pnlDelta < 0) badDebt = accountManager.debitPnL(owner, uint256(-pnlDelta));
```

ExecutionEngine credits only the DELTA (profit/loss), not the full equity. SettlementEngine
credits the full payout (which includes collateral). This is the root accounting mismatch.

#### Layer 3: SettlementEngine fee transfer without balancing debit

After the collateral double-counting, `claimSettlement` also does:
```solidity
accountManager.transferOut(address(feeRouter), result.settlementFee);
```

This sends USDT out of AccountManager, but no corresponding `debitPnL` is called for the fee
amount. The trader was credited `equity - fee` (fee already deducted from payout), but the
USDT for the fee is extracted from AccountManager's token balance without reducing any internal
balance. AccountManager's USDT balance goes out of sync with its sum of `_balances`.

---

### Current Code State (BUILD must read before touching anything)

**LiquidationEngine.sol `_executeLiquidation` (line 320-376):**
```
Step 4 (line 339): _routeFee(ctx.fee, liquidator)
  → accountManager.transferOut(feeRouter, fee)     ← fee USDT leaves AccountManager
  → feeRouter.routeFees(LIQUIDATION, fee)

Step 6 (line 348): _closeAndSettle(pos, positionId, ctx.traderReceives)
  → accountManager.releaseCollateral(collateral)
  → loss = collateral - traderReceives             ← INCLUDES fee
  → accountManager.debitPnL(trader, loss)
  → accountManager.transferOut(vault, loss)         ← fee USDT leaves AccountManager AGAIN
```

**LiquidationEngine.sol `_closeAndSettle` (line 397-415):**
```solidity
function _closeAndSettle(pos, positionId, traderReceives) internal {
    ...
    accountManager.releaseCollateral(pos.owner, pos.collateral);
    uint256 loss = pos.collateral > traderReceives ? pos.collateral - traderReceives : 0;
    if (loss > 0) {
        accountManager.debitPnL(pos.owner, loss);
        accountManager.transferOut(address(leverVault), loss);  // ← BUG: loss includes fee
    }
}
```

**SettlementEngine.sol `claimSettlement` (lines 261-274):**
```solidity
accountManager.releaseCollateral(pos.owner, pos.collateral);

if (result.payout > 0) {
    accountManager.creditPnL(pos.owner, result.payout);    // ← BUG: payout includes collateral
}

if (result.settlementFee > 0) {
    accountManager.transferOut(address(feeRouter), result.settlementFee);  // ← no debit
    feeRouter.routeFees(IFeeRouter.FeeType.SETTLEMENT, result.settlementFee);
}
```

**ExecutionEngine.sol `_settlePnL` (lines 396-435) — THE CORRECT REFERENCE:**
```solidity
accountManager.releaseCollateral(owner, collateral);
int256 pnlDelta = pnl - int256(borrowFees) - int256(closingFee) + accruedFunding;  // ← delta only
if (pnlDelta > 0) accountManager.creditPnL(owner, uint256(pnlDelta));              // ← delta only
else if (pnlDelta < 0) badDebt = accountManager.debitPnL(owner, uint256(-pnlDelta));

if (pnl > 0) leverVault.fundTraderPnL(address(accountManager), uint256(pnl));      // ← vault pays winners
uint256 toFeeRouter = ...;
accountManager.transferOut(address(feeRouter), toFeeRouter);                         // ← from deducted amount
feeRouter.routeFees(IFeeRouter.FeeType.BORROW, toFeeRouter);
```

**AccountManager.sol (lines 102-128):**
- `releaseCollateral`: only decrements `_lockedCollateral`, does NOT change `_balances`
- `creditPnL`: increments `_balances[user]`
- `debitPnL`: decrements `_balances[user]`, returns bad debt if balance < amount
- `transferOut`: raw `safeTransfer` from contract's USDT balance (no internal balance check)

---

### Approach

Fix both engines to follow the ExecutionEngine pattern: **release collateral, compute the delta
(not the full payout), credit/debit the delta, and separately handle token transfers to vault and
FeeRouter without double-counting.**

**LiquidationEngine fix:** Pass the `fee` to `_closeAndSettle` and subtract it from the
vault-bound loss. The fee already went to FeeRouter; the vault should only receive the actual
trading loss.

**SettlementEngine fix:** Replace `creditPnL(payout)` with `creditPnL(delta)` / `debitPnL(delta)`
where `delta = payout - collateral` (the net gain/loss beyond collateral). And add a `debitPnL`
for the fee amount so the internal balance correctly reflects the fee outflow. Also: add
`leverVault.fundTraderPnL` for winner profits (missing vault funding).

---

### Implementation Steps

**Step 1: Run existing tests to establish baseline**

```bash
cd /home/lever/Lever
forge build
forge test --match-path "test/LiquidationEngine.t.sol" -v
forge test --match-path "test/integration/InsuranceBadDebt.t.sol" -v
forge test --match-path "test/integration/SettlementFlow.t.sol" -v
```

---

**Step 2: Fix LiquidationEngine._closeAndSettle**

Change `_closeAndSettle` to accept the fee amount and exclude it from vault-bound loss:

FROM:
```solidity
function _closeAndSettle(
    IPositionManager.Position memory pos,
    uint256 positionId,
    uint256 traderReceives
) internal {
    oiLimits.decreaseOI(pos.marketId, pos.owner, pos.isLong, pos.positionSize);
    positionManager.closePosition(positionId);
    accountManager.releaseCollateral(pos.owner, pos.collateral);

    uint256 loss = pos.collateral > traderReceives ? pos.collateral - traderReceives : 0;
    if (loss > 0) {
        accountManager.debitPnL(pos.owner, loss);
        accountManager.transferOut(address(leverVault), loss);
    }
}
```

TO:
```solidity
function _closeAndSettle(
    IPositionManager.Position memory pos,
    uint256 positionId,
    uint256 traderReceives,
    uint256 fee
) internal {
    oiLimits.decreaseOI(pos.marketId, pos.owner, pos.isLong, pos.positionSize);
    positionManager.closePosition(positionId);
    accountManager.releaseCollateral(pos.owner, pos.collateral);

    // Total deduction from trader = loss + fee (everything they don't keep)
    uint256 totalDeduct = pos.collateral > traderReceives ? pos.collateral - traderReceives : 0;
    if (totalDeduct > 0) {
        accountManager.debitPnL(pos.owner, totalDeduct);
    }

    // Only the trading loss goes to vault (fee already sent to FeeRouter in _routeFee)
    uint256 vaultLoss = totalDeduct > fee ? totalDeduct - fee : 0;
    if (vaultLoss > 0) {
        accountManager.transferOut(address(leverVault), vaultLoss);
    }
}
```

Update the call site in `_executeLiquidation` (line 348):
```solidity
_closeAndSettle(pos, positionId, ctx.traderReceives, ctx.fee);
```

**Verification:** After liquidation, AccountManager's USDT balance should equal:
`original - fee(to FeeRouter) - vaultLoss(to vault) = original - totalDeduct`
And internal balances should total: `traderReceives + bounty(liquidator)`
Where `traderReceives + bounty = (equity - fee) + bounty`, and `totalDeduct = collateral - traderReceives`.
Both sides: `original - totalDeduct = original - collateral + traderReceives`. Check: if original = collateral, then `traderReceives`. Internal: `traderReceives + bounty`. Gap = bounty (the liquidator bounty was credited but the USDT for it stays in AccountManager since the liquidator doesn't withdraw immediately). This is correct.

Wait, bounty. Let me re-check. In `_routeFee`:
- bounty = fee * LIQUIDATOR_BOUNTY_SHARE (10%)
- feeForProtocol = fee - bounty
- `creditPnL(liquidator, bounty)` — internal credit, no token movement
- `transferOut(feeRouter, feeForProtocol)` — tokens leave

So USDT out = feeForProtocol + vaultLoss.
Internal = traderReceives + bounty.
USDT remaining in AM = original - feeForProtocol - vaultLoss
= original - (fee - bounty) - (totalDeduct - fee)
= original - fee + bounty - totalDeduct + fee
= original - totalDeduct + bounty
= original - (collateral - traderReceives) + bounty
If original = collateral: traderReceives + bounty. Matches internal balances. Correct.

---

**Step 3: Fix SettlementEngine.claimSettlement**

Replace the release-then-credit-full-payout pattern with the ExecutionEngine's
release-then-credit-delta pattern:

FROM (lines 261-274):
```solidity
oiLimits.decreaseOI(pos.marketId, pos.owner, pos.isLong, pos.positionSize);
positionManager.closePosition(positionId);
accountManager.releaseCollateral(pos.owner, pos.collateral);

if (result.payout > 0) {
    accountManager.creditPnL(pos.owner, result.payout);
}

if (result.settlementFee > 0) {
    accountManager.transferOut(address(feeRouter), result.settlementFee);
    feeRouter.routeFees(IFeeRouter.FeeType.SETTLEMENT, result.settlementFee);
}
```

TO:
```solidity
oiLimits.decreaseOI(pos.marketId, pos.owner, pos.isLong, pos.positionSize);
positionManager.closePosition(positionId);
accountManager.releaseCollateral(pos.owner, pos.collateral);

// Compute delta: net gain/loss beyond collateral (same pattern as ExecutionEngine._settlePnL)
// payout already deducts fee for winners. For losers, payout = equity (no fee).
int256 delta = int256(result.payout) - int256(pos.collateral);

if (delta > 0) {
    // Winner: profit beyond collateral. Vault must fund the profit.
    uint256 profit = uint256(delta);
    leverVault.fundTraderPnL(address(accountManager), profit);
    accountManager.creditPnL(pos.owner, profit);
} else if (delta < 0) {
    // Loser: lost part or all of collateral.
    uint256 loss = uint256(-delta);
    uint256 badDebt = accountManager.debitPnL(pos.owner, loss);
    // Send the recoverable loss to vault (losers fund winners)
    uint256 vaultBound = loss > badDebt ? loss - badDebt : 0;
    if (vaultBound > 0) {
        accountManager.transferOut(address(leverVault), vaultBound);
    }
}

// Route settlement fee (winners only; losers have settlementFee = 0)
if (result.settlementFee > 0) {
    accountManager.transferOut(address(feeRouter), result.settlementFee);
    feeRouter.routeFees(IFeeRouter.FeeType.SETTLEMENT, result.settlementFee);
}
```

**Key changes:**
1. Credit/debit only the DELTA, not the full payout. Prevents collateral double-counting.
2. Add `leverVault.fundTraderPnL` for winners (missing vault funding).
3. Add `accountManager.transferOut(vault, ...)` for losers (their loss funds winners).
4. Fee transfer stays as-is (FIX LEVER-005), but now the accounting is correct because we
   only credit `delta` (which already has fee deducted for winners).

**IMPORTANT:** BUILD must verify that SettlementEngine has the `EXECUTION_ENGINE_ROLE` or
equivalent on LeverVault to call `fundTraderPnL`. If not, a role grant is needed in the
deployment script. Also check if SettlementEngine has ENGINE role on AccountManager for `debitPnL`.

**IMPORTANT:** The `result.payout` for losers with `equity < 0` is 0 and `result.badDebt > 0`.
In that case: `delta = 0 - collateral = -collateral`. `debitPnL(collateral)` will zero out the
trader's balance. The bad debt from `debitPnL` is the amount the trader couldn't cover.
The bad debt was already handled in `_handleBadDebtWaterfall` during `settleMarket`. So the
`debitPnL` here records the individual trader's shortfall. The `vaultBound` loss goes to the
vault (losers' collateral funds winners' profits).

---

**Step 4: Verify SettlementEngine accounting end-to-end**

After all positions in a market are settled via `claimSettlement`:

- Sum of all token inflows to AccountManager (from vault fundTraderPnL for winners)
- Sum of all token outflows from AccountManager (to vault for loser losses, to FeeRouter for fees)
- Net should equal: sum of delta credits - sum of delta debits

The market should be balanced: `sum(winner_profits) ≈ sum(loser_losses) - sum(fees) - bad_debt`
(with ADL haircuts adjusting winner payouts if needed).

BUILD must trace through a concrete example:
- 2 longs at PI=0.50, size=1000, collateral=200
- 2 shorts at PI=0.50, size=1000, collateral=200
- Market resolves YES (PI=1): longs win, shorts lose
- Expected: long profit ≈ 500 each, short loss ≈ 500 each
- Settlement fee: 0.20% of 1000 = 2 per winner
- Long payout: equity - fee. Short payout: max(equity, 0).

---

**Step 5: Write tests**

New file: `test/integration/FeeAccountingConsistency.t.sol`

**5a. `testLiquidationFeeNotDoubleCounted`**
- Open a position with collateral=100, leverage such that notional=1000
- Move price so equity drops to 50 (below maintenance margin)
- Liquidate
- fee = min(1% * 1000, 50) = 10
- After liquidation: check `usdt.balanceOf(accountManager)` equals sum of all internal
  balances (all users' `getBalance()` values)
- Check vault received exactly `collateral - equity` (the trading loss, WITHOUT fee)
- Check FeeRouter received `fee - bounty` (protocol share of fee)

**5b. `testSettlementNoCollateralDoubleCount`**
- Open matched long + short positions
- Settle market (YES)
- Claim settlement for both
- After: check `usdt.balanceOf(accountManager)` equals sum of all internal balances
- Check winner received `equity - fee` net gain (not `equity - fee + collateral` extra)
- Check loser's balance decreased by correct amount

**5c. `testSettlementVaultFundsWinners`**
- Open a long winning position (PI goes to 1.0)
- Before settlement: note vault balance
- After settlement + claim: vault balance decreased by winner's profit amount
- AccountManager balance increased by the same amount (from fundTraderPnL)

**5d. `testSettlementFeeCorrectlyRouted`**
- Open a winning position
- Settle and claim
- Check FeeRouter received exactly `settlementFee` USDT
- Check winner's internal balance = original_collateral + profit - fee
- Check AccountManager USDT = sum of internal balances

**5e. `testLiquidationBadDebtWithFee`**
- Position with equity < 0 (bad debt case)
- Fee = 0 (equity <= 0 means no fee)
- Verify: no fee routing attempted, bad debt flows through insurance/ADL correctly
- AccountManager balance still matches internal balances

---

**Step 6: Run full test suite**

```bash
forge test -v 2>&1 | tee /tmp/test-results.txt
```

Existing tests in LiquidationEngine.t.sol and SettlementFlow.t.sol WILL likely fail because
their expected values assumed the buggy accounting. BUILD must update expected values, not
delete tests.

---

### Files to Modify

- `contracts/LiquidationEngine.sol`
  - `_closeAndSettle` (lines 397-415): add `fee` parameter, subtract from vault-bound loss
  - `_executeLiquidation` (line 348): pass `ctx.fee` to `_closeAndSettle`

- `contracts/SettlementEngine.sol`
  - `claimSettlement` (lines 261-274): replace full-payout credit with delta credit/debit,
    add vault funding for winners, add loser loss transfer to vault

### Files to Create

- `test/integration/FeeAccountingConsistency.t.sol` — 5 tests

### Files to Read First (BUILD must read all of these)

- `contracts/LiquidationEngine.sol` — full file (trace full liquidation flow)
- `contracts/SettlementEngine.sol` — full file (trace full settlement flow)
- `contracts/ExecutionEngine.sol` lines 382-435 (`_settlePnL` — the correct reference pattern)
- `contracts/core/AccountManager.sol` lines 85-129 (lock/release/credit/debit/transferOut)
- `contracts/FeeRouter.sol` lines 105-165 (routeFees and collectTransactionFee)
- `contracts/LeverVault.sol` — fundTraderPnL function and role requirements
- `contracts/interfaces/IFeeRouter.sol` — FeeType enum

---

### Dependencies and Ripple Effects

- **AccountManager:** No changes. All its functions (release, credit, debit, transferOut) are
  correctly implemented. The bug is in how callers use them.

- **FeeRouter:** No changes. It correctly distributes tokens it holds. The bug was in callers
  not providing tokens (fixed by LEVER-005) and then double-counting (fixed by this plan).

- **LeverVault.fundTraderPnL:** SettlementEngine must have the right role to call this.
  Currently, fundTraderPnL requires `EXECUTION_ENGINE_ROLE` (check this). If SettlementEngine
  is not authorized, BUILD must add a role grant. Either grant EXECUTION_ENGINE_ROLE to
  SettlementEngine, or add a new `SETTLEMENT_ENGINE_ROLE` to the `fundTraderPnL` function.

- **InsuranceFund.absorbBadDebt:** Still called in `_handleBadDebtWaterfall` during `settleMarket`
  (not during `claimSettlement`). The fix in this plan does not change that flow. The bad debt
  handling is separate from the per-position fee routing.

- **LeverVault.socializeLoss:** Called by `_handleBadDebtWaterfall` with `remainder` from
  InsuranceFund. This is in WAD scale (see LEVER-BUG-5 plan). That is a separate fix.

- **Events:** No event changes. The emitted values (payout, fee) are computed before the
  accounting changes. The events still reflect the correct economic values.

---

### Edge Cases

**Zero equity liquidation (bad debt):** When equity <= 0, fee = 0 (from `_computeFeeAndOutcome`:
fee is capped at equity, and equity <= 0 means no fee). `_routeFee(0, liquidator)` returns
immediately. `_closeAndSettle` with fee=0 behaves as before. No double-counting when fee=0.

**Full equity consumed by fee:** If equity = fee (fee consumes all remaining equity),
traderReceives = 0, loss = collateral, vaultLoss = collateral - fee. Trader gets nothing.
Vault gets collateral minus fee. FeeRouter gets fee. Total out = collateral. Correct.

**Winner with payout < collateral:** Can happen if borrow fees + funding ate into profit.
delta = payout - collateral < 0. This means the "winner" actually lost money overall (fees
exceeded their price gain). The code should debitPnL for this case. The fix handles this via
the `delta < 0` branch.

**Loser with positive equity:** Common case. Loser lost on the market but still has some equity
(equity = collateral + negative_pnl - fees + funding > 0). payout = equity (no settlement fee
for losers). delta = equity - collateral < 0 (since equity < collateral for losers).
debitPnL(collateral - equity). transferOut to vault: collateral - equity. Correct.

**Settlement void (market voided):** `settleVoid` returns collateral to all traders at cost.
Each position payout = collateral. delta = 0. No credits, no debits, no transfers. Correct.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `testLiquidationFeeNotDoubleCounted` | Vault receives loss WITHOUT fee, AM balance matches internal |
| `testSettlementNoCollateralDoubleCount` | Winners get delta not full payout, AM balance matches |
| `testSettlementVaultFundsWinners` | Vault pays winner profits via fundTraderPnL |
| `testSettlementFeeCorrectlyRouted` | Fee goes to FeeRouter, internal balances correct |
| `testLiquidationBadDebtWithFee` | Zero-fee case (bad debt) still works correctly |

---

### Effort Estimate

**Medium** — 4-6 hours.
- LiquidationEngine fix: 1 hour (small, surgical change)
- SettlementEngine fix: 2-3 hours (larger refactor of claimSettlement, vault role check)
- Tests: 2 hours
- Existing test updates: 1 hour

---

### Rollback Plan

**LiquidationEngine:** Revert `_closeAndSettle` to remove the `fee` parameter. The double-spend
resumes but the system doesn't crash (it just drains AccountManager slowly).

**SettlementEngine:** Revert `claimSettlement` to the current pattern. The collateral double-counting
resumes. This inflates trader balances (they can withdraw more than they should). Higher risk
than the liquidation rollback.

If only one fix can ship: **prioritize the SettlementEngine fix** — the collateral double-counting
is a larger dollar impact (every settled position, not just liquidations).

---

### Open Questions

1. **LeverVault role for SettlementEngine:** Does `fundTraderPnL` allow SettlementEngine to call it?
   BUILD must check the role requirement and deployment grants. If a new role grant is needed,
   include it in the deployment script update.

2. **SettlementEngine and vault token flow at scale:** In a market with many positions, the
   `claimSettlement` calls happen one at a time. Each winner claim calls `fundTraderPnL` (vault
   sends USDT to AccountManager). Each loser claim calls `transferOut` (AccountManager sends
   USDT to vault). The net should balance. But the ORDER matters: if all winners claim first,
   the vault needs enough USDT to cover all profits before losers' collateral is returned.
   BUILD should verify the vault has sufficient liquidity (which it should, since TVL covers it).

---

### KANBAN Update

Move LEVER-BUG-6 to PLANNED.
