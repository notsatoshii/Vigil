# Plan v2: LEVER-BUG-6 -- FeeRouter Called Without USDT by Liquidation/Settlement
## Date: 2026-03-29T08:30:00Z
## Revision: v2 (fixes SettlementEngine vault funding deficit identified by critique)

---

### Changes from v1

The critique (critique-lever-bug-6.md) found a critical error in v1's Step 3 (SettlementEngine fix for winners). The vault was funding only `profit` (net delta after fee deduction), but the settlement fee also leaves AccountManager as a separate USDT transfer. This creates a per-settlement fee-sized deficit: USDT in AccountManager falls below the sum of internal balances.

**The fix:** The vault must fund `profit + settlementFee` (gross profit before fee deduction), matching ExecutionEngine's pattern where `fundTraderPnL(pnl)` covers both the user's credit and the fee transfer out.

Everything else from v1 is unchanged. Only Step 3 (SettlementEngine winner case) is revised.

---

### Problem Statement (unchanged from v1)

Three layers of accounting errors in LiquidationEngine and SettlementEngine:

1. **LiquidationEngine fee double-spend:** `loss = collateral - traderReceives` includes the fee, but the fee was already sent to FeeRouter. Fee USDT leaves AccountManager twice.
2. **SettlementEngine collateral double-counting:** `creditPnL(payout)` adds the full payout (which includes collateral) to `_balances`, but collateral was never removed from `_balances` by `releaseCollateral`. Double-count.
3. **SettlementEngine fee transfer without balancing debit:** `transferOut(feeRouter, fee)` removes USDT with no `_balances` adjustment, creating a USDT/balance mismatch.

---

### Current Code (verified against actual codebase 2026-03-29)

**LiquidationEngine.sol `_closeAndSettle` (lines 397-415):**
- `loss = collateral - traderReceives` (includes fee)
- `debitPnL(trader, loss)` then `transferOut(vault, loss)` -- fee double-sent

**LiquidationEngine.sol `_routeFee` (lines 419-436):**
- bounty = fee * 10%, credited internally (no token move)
- feeForProtocol = fee - bounty, transferred to FeeRouter

**SettlementEngine.sol `claimSettlement` (lines 261-280):**
- `releaseCollateral(collateral)` -- only changes `_lockedCollateral`
- `creditPnL(payout)` -- adds full payout (includes collateral) to `_balances`
- `transferOut(feeRouter, settlementFee)` -- USDT out, no balance debit

**ExecutionEngine.sol `_settlePnL` (lines 428-481) -- THE CORRECT REFERENCE:**
- `releaseCollateral(collateral)`
- `pnlDelta = pnl - borrowFees - closingFee + funding` -- delta only
- `creditPnL(pnlDelta)` or `debitPnL(-pnlDelta)` -- delta only
- `fundTraderPnL(AM, pnl)` -- vault funds FULL gross profit (covers both user credit AND fee transfer)
- `transferOut(vault, priceLoss)` and `transferOut(feeRouter, fees)` -- outflows from the gross amount

**AccountManager.sol (lines 92-129):**
- `releaseCollateral`: only decrements `_lockedCollateral`, does NOT change `_balances`
- `creditPnL`: increments `_balances[user]`
- `debitPnL`: decrements `_balances[user]`, returns bad debt if balance < amount
- `transferOut`: raw `safeTransfer` (no internal balance check)

**LeverVault.sol `fundTraderPnL` (line 321):**
- Requires `EXECUTION_ENGINE_ROLE`
- SettlementEngine does NOT currently have this role

---

### Implementation Steps

**Step 1: Run existing tests to establish baseline**

```bash
cd /home/lever/lever-protocol
forge build
forge test --match-path "test/LiquidationEngine.t.sol" -v
forge test --match-path "test/integration/InsuranceBadDebt.t.sol" -v
forge test --match-path "test/integration/SettlementFlow.t.sol" -v
```

---

**Step 2: Fix LiquidationEngine._closeAndSettle** (unchanged from v1)

Pass the `fee` amount and subtract it from the vault-bound loss.

FROM (lines 397-415):
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

    // Total deduction from trader = everything they don't keep
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

**Numeric trace (LiquidationEngine, with external liquidator):**
- collateral=100, equity=50, fee=10, bounty=1, feeForProtocol=9
- traderReceives = equity - fee = 40
- totalDeduct = 100 - 40 = 60
- vaultLoss = 60 - 10 = 50

Balance changes:
- `_balances[trader]`: was 100 (from deposit). debitPnL(60) -> 40
- `_balances[liquidator]`: creditPnL(1) -> +1

USDT movements:
- transferOut(feeRouter, 9) -> -9
- transferOut(vault, 50) -> -50
- AM USDT: 100 - 9 - 50 = 41

Internal balances: trader(40) + liquidator(1) = 41. MATCH.

---

**Step 3: Fix SettlementEngine.claimSettlement** (REVISED from v1)

Replace the release-then-credit-full-payout pattern with the ExecutionEngine delta pattern. Critical change from v1: vault funds `grossProfit = profit + settlementFee`, not just `profit`.

FROM (lines 261-274):
```solidity
oiLimits.decreaseOI(pos.marketId, pos.owner, pos.isLong, pos.positionSize);
positionManager.closePosition(positionId);
accountManager.releaseCollateral(pos.owner, pos.collateral);

if (result.payout > 0) {
    accountManager.creditPnL(pos.owner, result.payout);
}

// FIX LEVER-005: Transfer USDT to FeeRouter before calling routeFees
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
// For winners: payout = equity - fee, so delta = (equity - fee) - collateral
// For losers: payout = max(equity, 0), no fee
int256 delta = int256(result.payout) - int256(pos.collateral);

if (delta > 0) {
    // Winner with net profit beyond collateral.
    // Vault must fund the GROSS profit (delta + fee) so that USDT covers
    // both the user's credit AND the fee transfer to FeeRouter.
    uint256 profit = uint256(delta);
    uint256 grossProfit = profit + result.settlementFee;
    leverVault.fundTraderPnL(address(accountManager), grossProfit);
    accountManager.creditPnL(pos.owner, profit);
} else if (delta < 0) {
    // Loser (or winner whose fees exceeded gains): lost part or all of collateral.
    uint256 loss = uint256(-delta);
    uint256 badDebt = accountManager.debitPnL(pos.owner, loss);
    // Send the recoverable loss to vault (losers fund winners)
    uint256 vaultBound = loss > badDebt ? loss - badDebt : 0;
    if (vaultBound > 0) {
        accountManager.transferOut(address(leverVault), vaultBound);
    }
}
// delta == 0: no credit or debit needed (e.g., void settlement)

// Route settlement fee (winners only; losers have settlementFee = 0)
if (result.settlementFee > 0) {
    accountManager.transferOut(address(feeRouter), result.settlementFee);
    feeRouter.routeFees(IFeeRouter.FeeType.SETTLEMENT, result.settlementFee);
}
```

**Numeric trace (SettlementEngine winner, delta > 0):**
- collateral=200, equity=700, settlementFee=2, payout = 700 - 2 = 698
- delta = 698 - 200 = 498 (profit)
- grossProfit = 498 + 2 = 500

Balance changes:
- `_balances[trader]`: was 200 (from deposit). creditPnL(498) -> 698

USDT movements:
- vault fundTraderPnL(AM, 500) -> +500
- transferOut(feeRouter, 2) -> -2
- AM USDT: 200 + 500 - 2 = 698

Internal balances: trader(698) = 698. MATCH.

v1 bug trace (for comparison):
- v1 funded only profit=498 from vault
- AM USDT: 200 + 498 - 2 = 696
- Internal balances: 698. DEFICIT of 2 (the fee). BROKEN.

**Numeric trace (SettlementEngine loser):**
- collateral=200, equity=50, settlementFee=0, payout=50
- delta = 50 - 200 = -150 (loss)
- debitPnL(150): `_balances[trader]` = 200 - 150 = 50
- vaultBound = 150 (assuming no bad debt)

USDT movements:
- transferOut(vault, 150) -> -150
- AM USDT: 200 - 150 = 50

Internal balances: trader(50) = 50. MATCH.

**Numeric trace (SettlementEngine winner with delta <= 0, fees exceed gains):**
- collateral=200, outcomePnL=10, borrowFees=5, funding=0
- equity = 200 + 10 - 5 = 205, settlementFee=2, payout = 205 - 2 = 203
- delta = 203 - 200 = 3 > 0, so this is still in the delta > 0 branch
- grossProfit = 3 + 2 = 5, creditPnL(3)
- AM USDT: 200 + 5 - 2 = 203. Internal: 200 + 3 = 203. MATCH.

Now a case where fees truly eat all gains:
- collateral=200, outcomePnL=1, borrowFees=5, funding=0
- equity = 200 + 1 - 5 = 196, settlementFee=2, payout = 196 - 2 = 194
- delta = 194 - 200 = -6. Enters delta < 0 branch.
- debitPnL(6): `_balances` = 200 - 6 = 194. vaultBound = 6.
- settlementFee = 2 (still charged since isWinner)
- AM USDT: 200 - 6 - 2 = 192. Internal: 194. DEFICIT of 2!

This is a problem. When delta < 0 but the winner still has a settlementFee > 0, the fee transfer creates a deficit because no vault funding covers it.

**Resolution:** When delta < 0 for a winner (fees exceeded gains), the vault still needs to fund the settlement fee. The fee USDT is leaving AccountManager, so the vault must provide it.

REVISED code for the delta < 0 case when there is still a settlement fee:
```solidity
if (delta > 0) {
    uint256 profit = uint256(delta);
    uint256 grossProfit = profit + result.settlementFee;
    leverVault.fundTraderPnL(address(accountManager), grossProfit);
    accountManager.creditPnL(pos.owner, profit);
} else if (delta < 0) {
    uint256 loss = uint256(-delta);
    uint256 badDebt = accountManager.debitPnL(pos.owner, loss);
    uint256 vaultBound = loss > badDebt ? loss - badDebt : 0;
    if (vaultBound > 0) {
        accountManager.transferOut(address(leverVault), vaultBound);
    }
    // Winner with delta < 0 still has settlementFee; vault must fund it
    if (result.settlementFee > 0) {
        leverVault.fundTraderPnL(address(accountManager), result.settlementFee);
    }
} else {
    // delta == 0: no credit/debit, but winner might still owe a fee
    if (result.settlementFee > 0) {
        leverVault.fundTraderPnL(address(accountManager), result.settlementFee);
    }
}
```

Wait. Let me reconsider. When delta < 0 for a winner, the loser loss goes to vault, and the vault also needs to send the fee amount back. This is a net wash in some cases and adds unnecessary token movement. Let me think about this differently.

Actually, the cleaner approach: always fund the settlementFee from vault regardless of delta sign, and only fund the profit portion conditionally. This keeps it simple:

**FINAL REVISED CODE:**
```solidity
oiLimits.decreaseOI(pos.marketId, pos.owner, pos.isLong, pos.positionSize);
positionManager.closePosition(positionId);
accountManager.releaseCollateral(pos.owner, pos.collateral);

// Compute delta: net gain/loss beyond collateral
int256 delta = int256(result.payout) - int256(pos.collateral);

if (delta > 0) {
    // Winner with net profit: vault funds the profit
    uint256 profit = uint256(delta);
    leverVault.fundTraderPnL(address(accountManager), profit);
    accountManager.creditPnL(pos.owner, profit);
} else if (delta < 0) {
    // Lost part or all of collateral (losers, or winners whose fees exceeded gains)
    uint256 loss = uint256(-delta);
    uint256 badDebt = accountManager.debitPnL(pos.owner, loss);
    uint256 vaultBound = loss > badDebt ? loss - badDebt : 0;
    if (vaultBound > 0) {
        accountManager.transferOut(address(leverVault), vaultBound);
    }
}
// delta == 0: no credit, no debit

// Vault funds the settlement fee so the fee transfer out is covered
// (settlementFee > 0 only for winners; losers have settlementFee = 0)
if (result.settlementFee > 0) {
    leverVault.fundTraderPnL(address(accountManager), result.settlementFee);
    accountManager.transferOut(address(feeRouter), result.settlementFee);
    feeRouter.routeFees(IFeeRouter.FeeType.SETTLEMENT, result.settlementFee);
}
```

This separates the profit funding from the fee funding. The vault always provides exactly the USDT that will leave as the fee, regardless of whether the user's delta is positive or negative. This avoids any edge-case deficit.

**Re-verify numeric traces with final code:**

**Trace A: Winner with delta > 0 (common case)**
- collateral=200, payout=698, settlementFee=2
- delta = 498. creditPnL(498). vault funds 498.
- vault funds 2 (for fee). transferOut(feeRouter, 2).
- AM USDT: 200 + 498 + 2 - 2 = 698
- Internal: 200 + 498 = 698. MATCH.

**Trace B: Loser**
- collateral=200, payout=50, settlementFee=0
- delta = -150. debitPnL(150). transferOut(vault, 150).
- No fee.
- AM USDT: 200 - 150 = 50
- Internal: 200 - 150 = 50. MATCH.

**Trace C: Winner with delta < 0 (fees exceed gains)**
- collateral=200, payout=194, settlementFee=2
- delta = -6. debitPnL(6). transferOut(vault, 6).
- vault funds 2 (for fee). transferOut(feeRouter, 2).
- AM USDT: 200 - 6 + 2 - 2 = 194
- Internal: 200 - 6 = 194. MATCH.

**Trace D: Winner with delta = 0 exactly**
- collateral=200, payout=200, settlementFee=2
- delta = 0. No credit/debit.
- vault funds 2. transferOut(feeRouter, 2).
- AM USDT: 200 + 2 - 2 = 200
- Internal: 200. MATCH.

**Trace E: Void settlement (payout = collateral, no fee)**
- collateral=200, payout=200, settlementFee=0
- delta = 0. No credit/debit. No fee.
- AM USDT: 200. Internal: 200. MATCH.

**Trace F: Loser with bad debt**
- collateral=200, payout=0, settlementFee=0
- delta = -200. debitPnL(200): balance was 200, now 0, badDebt=0. transferOut(vault, 200).
- AM USDT: 200 - 200 = 0. Internal: 0. MATCH.

**Trace G: Loser with equity < 0 (bad debt)**
- collateral=200, equity=-50, payout=0, settlementFee=0, badDebt from _compute=50
- delta = 0 - 200 = -200. debitPnL(200): balance=200, enough, badDebt=0, balance=0.
  (Note: the bad debt from _computePositionSettlement is handled separately in _handleBadDebtWaterfall during settleMarket, not here. The per-position claim just zeros the user.)
- transferOut(vault, 200).
- AM USDT: 0. Internal: 0. MATCH.

All traces balance. The key insight vs v1: separate the profit funding and fee funding into two independent vault calls. This eliminates the edge case where delta < 0 but a fee still needs to leave.

---

**Step 4: Grant EXECUTION_ENGINE_ROLE to SettlementEngine on LeverVault**

`fundTraderPnL` requires `EXECUTION_ENGINE_ROLE` (LeverVault.sol line 321). SettlementEngine does not currently have this role. BUILD must add the role grant in the deployment/setup script.

Check the deployment script for the existing grant to ExecutionEngine and add an equivalent one for SettlementEngine:
```solidity
leverVault.grantRole(EXECUTION_ENGINE_ROLE, address(settlementEngine));
```

If there is a deploy script at `script/Deploy.s.sol` or similar, add the grant there. If roles are granted via a separate setup transaction, include the grant in the setup instructions.

---

**Step 5: Verify SettlementEngine has ENGINE role on AccountManager**

SettlementEngine calls `accountManager.debitPnL` (new in this fix) and `accountManager.transferOut` (existing from LEVER-005). Both require `ENGINE` role. BUILD must verify SettlementEngine already has this role. If `creditPnL` and `transferOut` already work (they do, per current code), then the ENGINE role is already granted and `debitPnL` will also work.

---

**Step 6: Write tests** (unchanged from v1, with updated expected values)

New file: `test/integration/FeeAccountingConsistency.t.sol`

Core invariant to test: **`usdt.balanceOf(accountManager) == sum(_balances)` after every operation.**

| Test | What it verifies |
|------|-----------------|
| `testLiquidationFeeNotDoubleCounted` | Vault receives loss WITHOUT fee; AM USDT = sum of internal balances |
| `testSettlementWinnerAccounting` | Winner: vault funds grossProfit (profit + fee); AM USDT = internal balances |
| `testSettlementLoserAccounting` | Loser: loss goes to vault; AM USDT = internal balances |
| `testSettlementWinnerNegativeDelta` | Winner with delta < 0: vault funds only fee; AM USDT = internal balances |
| `testSettlementVoidAccounting` | Void: no credits/debits/transfers; AM USDT = internal balances |
| `testSettlementFeeCorrectlyRouted` | FeeRouter receives exactly settlementFee USDT |
| `testLiquidationBadDebtWithFee` | Zero-fee case (bad debt) still works correctly |

---

**Step 7: Run full test suite**

```bash
cd /home/lever/lever-protocol
forge test -v 2>&1 | tee /tmp/test-results-bug6.txt
```

Existing tests will likely fail due to changed expected values. BUILD must update expected values, not delete tests.

---

### Files to Modify

- `contracts/LiquidationEngine.sol`
  - `_closeAndSettle` (lines 397-415): add `fee` parameter, subtract fee from vault-bound loss
  - `_executeLiquidation` (line 348): pass `ctx.fee` to `_closeAndSettle`

- `contracts/SettlementEngine.sol`
  - `claimSettlement` (lines 261-280): replace full-payout credit with delta credit/debit, add vault funding for winners (profit) and fee (separately), add loser loss transfer to vault

- Deployment script (location TBD by BUILD):
  - Grant `EXECUTION_ENGINE_ROLE` to SettlementEngine on LeverVault

### Files to Create

- `test/integration/FeeAccountingConsistency.t.sol` -- 7 tests

### Files to Read First (BUILD must read all)

- `contracts/LiquidationEngine.sol` -- full file
- `contracts/SettlementEngine.sol` -- full file
- `contracts/ExecutionEngine.sol` lines 428-481 (`_settlePnL` -- correct reference pattern)
- `contracts/core/AccountManager.sol` lines 85-129 (lock/release/credit/debit/transferOut)
- `contracts/FeeRouter.sol` (routeFees)
- `contracts/LeverVault.sol` (fundTraderPnL, role requirements)

---

### Dependencies and Ripple Effects

- **AccountManager:** No changes needed. All functions correctly implemented.
- **FeeRouter:** No changes needed.
- **LeverVault.fundTraderPnL:** SettlementEngine needs EXECUTION_ENGINE_ROLE (Step 4).
- **InsuranceFund:** No changes. Bad debt waterfall in `settleMarket` is separate from per-position `claimSettlement`.
- **Events:** No event changes. Emitted values computed before accounting.

---

### Edge Cases

| Case | delta | settlementFee | What happens | Correct? |
|------|-------|---------------|--------------|----------|
| Winner, big profit | +498 | 2 | vault funds 498 + 2, credit 498, fee out 2 | Yes (trace A) |
| Loser, positive equity | -150 | 0 | debit 150, loss to vault 150 | Yes (trace B) |
| Winner, fees > gains | -6 | 2 | debit 6, loss to vault 6, vault funds 2, fee out 2 | Yes (trace C) |
| Winner, delta = 0 | 0 | 2 | no credit/debit, vault funds 2, fee out 2 | Yes (trace D) |
| Void settlement | 0 | 0 | no ops | Yes (trace E) |
| Loser, zero equity | -200 | 0 | debit 200, loss to vault 200 | Yes (trace F) |
| Loser, bad debt | -200 | 0 | debit 200 (partial), loss to vault (what was recoverable) | Yes (trace G) |
| Winner, fee consumes all equity | payout=0, fee=equity | 0 | delta = -collateral, debit all, no fee transfer | Yes |

---

### Key Design Decision: Separate Vault Calls for Profit and Fee

v1 combined profit and fee into a single `fundTraderPnL(grossProfit)` call in the delta > 0 branch. This fails when delta <= 0 but settlementFee > 0 (winner whose fees exceeded their gains).

v2 separates them: one `fundTraderPnL(profit)` in the delta > 0 branch, and one `fundTraderPnL(settlementFee)` in the fee block (unconditional on delta sign). This handles all edge cases correctly and is easier to reason about:
- The profit funding covers the `creditPnL` increase to `_balances`
- The fee funding covers the `transferOut(feeRouter)` decrease to USDT

Each vault call has a clear, single purpose.

---

### Effort Estimate

**Medium** -- 4-6 hours (same as v1).

---

### Rollback Plan

Same as v1. If only one fix can ship, prioritize the SettlementEngine fix (larger dollar impact).

---

### Open Questions

1. **LeverVault role grant mechanism:** How are roles currently granted? Is there a deploy script, a multisig transaction, or a governance proposal? BUILD must find the pattern and follow it.
2. **Can `fundTraderPnL` be called with amount=0?** The code reverts on zero amount. The fee block is guarded by `result.settlementFee > 0`, so this is safe. The profit block is guarded by `delta > 0`, also safe.

---

### KANBAN Update

Keep LEVER-BUG-6 in PLANNED. Ready for BUILD after critique approval.
