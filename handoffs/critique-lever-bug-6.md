# Critique: LEVER-BUG-6 — FeeRouter Called Without USDT by Liquidation/Settlement
## Date: 2026-03-29T04:10:00Z
## Plan reviewed: handoffs/plan-lever-bug-6.md
## Codebase verified against: /home/lever/lever-protocol @ commit 9f77cc990

---

### Verdict: REVISE

The root cause analysis is excellent and all three accounting layers are confirmed correct against the actual code. The LiquidationEngine fix is correct. The SettlementEngine fix has a critical USDT accounting error: the vault funds too little, causing a per-settlement fee deficit in AccountManager.

---

### What Is Good

- All three layers of accounting errors are confirmed by reading the actual code:
  - **Layer 1** (LiquidationEngine fee double-spend): Verified. `loss = collateral - traderReceives` includes the fee, and fee was already sent to FeeRouter. Double-spend.
  - **Layer 2** (SettlementEngine collateral double-counting): Verified. AccountManager.lockCollateral only increments `_lockedCollateral` (line 98), does NOT change `_balances`. releaseCollateral only decrements `_lockedCollateral` (line 103). Then `creditPnL(payout)` adds the full payout (which includes collateral) to `_balances`. Double-count.
  - **Layer 3** (SettlementEngine fee transfer without debit): Verified. `transferOut(feeRouter, fee)` removes USDT with no `_balances` adjustment.

- The LiquidationEngine fix (Step 2) is numerically verified correct. With collateral=100, equity=50, fee=10: AM USDT (41) matches sum of internal balances (trader=40 + liquidator=1 = 41).

- Correct identification of ExecutionEngine._settlePnL as the reference pattern.

- Edge cases are well-reasoned (zero equity, full equity consumed by fee, void settlement).

- Good test plan targeting the exact invariant: `usdt.balanceOf(AM) == sum(_balances)`.

---

### Issues Found

**1. [CRITICAL] SettlementEngine fix: vault funds `profit` (delta, after fee) but fee also leaves as USDT. Creates per-settlement deficit.**

The plan's Step 3 for winners:
```solidity
uint256 profit = uint256(delta);  // delta = payout - collateral = equity - fee - collateral
leverVault.fundTraderPnL(address(accountManager), profit);  // vault sends delta USDT to AM
accountManager.creditPnL(pos.owner, profit);
// ...later:
accountManager.transferOut(address(feeRouter), result.settlementFee);  // fee USDT leaves AM
```

After this sequence:
- `_balances` change: +delta = +(equity - fee - collateral)
- USDT in AM: +delta (from vault) - fee (to feeRouter) = delta - fee

Per-user mismatch: `_balances - USDT = fee`. Each winner settlement creates a `fee`-sized deficit. AccountManager's USDT balance is permanently less than the sum of internal balances.

**Why this happens:** The vault sends `profit` (which already has the fee deducted). Then the fee also leaves as a separate USDT transfer. The fee is "paid" twice: once via balance reduction (delta excludes it), once via token transfer.

**How ExecutionEngine avoids this (lines 430-452):** The vault funds the FULL `pnl` (raw profit, BEFORE fee deduction), not `pnlDelta` (after fees):

```solidity
// Balance: credits pnlDelta = pnl - fees
creditPnL(owner, pnlDelta);

// Vault funds FULL pnl (fees come from this amount)
leverVault.fundTraderPnL(address(accountManager), uint256(pnl));

// Fees taken from the vault-funded amount (not extra)
transferOut(address(feeRouter), toFeeRouter);
```

USDT = collateral + pnl - fees = collateral + pnlDelta (ignoring funding). Matches `_balances`. The excess between vault funding (`pnl`) and user credit (`pnlDelta = pnl - fees`) covers the fee transfer.

**The fix:** Vault must fund the gross profit (before fee deduction). Two equivalent approaches:

Option A: Fund gross profit explicitly:
```solidity
if (delta > 0) {
    uint256 profit = uint256(delta);
    uint256 grossProfit = profit + result.settlementFee;
    leverVault.fundTraderPnL(address(accountManager), grossProfit);
    accountManager.creditPnL(pos.owner, profit);
}
```

Option B: Compute gross delta separately:
```solidity
int256 grossDelta = int256(result.payout + result.settlementFee) - int256(pos.collateral);
if (grossDelta > 0) {
    leverVault.fundTraderPnL(address(accountManager), uint256(grossDelta));
}
int256 netDelta = int256(result.payout) - int256(pos.collateral);
if (netDelta > 0) {
    accountManager.creditPnL(pos.owner, uint256(netDelta));
}
```

Both ensure: USDT_in = grossProfit, USDT_out = fee, net = profit = delta = `_balances` change.

---

**2. [MEDIUM] The plan says "fee transfer stays as-is" (Layer 3) but the fix doesn't fully resolve it**

The plan acknowledges Layer 3 (fee transfer without balancing debit) and says: "Fee transfer stays as-is (FIX LEVER-005), but now the accounting is correct because we only credit `delta` (which already has fee deducted for winners)."

This reasoning is incorrect. Crediting `delta` (fee-deducted) handles the `_balances` side, but the USDT side still has the fee leaving via `transferOut`. The vault funding must cover BOTH the user credit AND the fee transfer. See finding 1.

---

**3. [MEDIUM] File paths reference `/home/lever/Lever/`**

Same as all other plans. Actual codebase is at `/home/lever/lever-protocol/`.

---

**4. [LOW] Line numbers may be shifted from P03/P04/P06**

LiquidationEngine and SettlementEngine may or may not have been modified by the P01-P06 fixes. The plan references specific lines. BUILD should verify against the actual code, not the line numbers.

From my verification: LiquidationEngine._executeLiquidation is at lines 320-376, `_closeAndSettle` at 397-415, `_routeFee` at 419-436. SettlementEngine.claimSettlement is at lines 235-280. These appear to match the plan's references approximately, but BUILD should confirm.

---

**5. [LOW] Loser case in SettlementEngine: vault receives loser loss, but is this necessary?**

The plan adds `accountManager.transferOut(vault, vaultBound)` for losers. In ExecutionEngine, loser losses go to vault because the vault is the counterparty. In settlement, losers' losses fund winners' profits. The vault acts as an intermediary: losers send to vault, vault sends to winners via `fundTraderPnL`. This is architecturally fine but creates unnecessary USDT movement (loser AM to vault, vault to winner AM). An alternative: losers' losses stay in AM and fund winners directly (internal rebalancing). But this is a design choice, not a bug. The plan's approach is consistent with ExecutionEngine and is correct.

---

### Missing Steps

- Verify SettlementEngine has the role to call `leverVault.fundTraderPnL`. The plan flags this in Open Question 1 but does not include it as an implementation step. If the role is missing, deployment must grant it.
- Add a `debitPnL` for the fee amount in the loser-with-settlement-fee case (can a loser have a settlement fee?). The plan says "losers have settlementFee = 0" but BUILD should verify `_computePositionSettlement` confirms this.

---

### Edge Cases Not Covered

- **Winner with delta < 0 but payout > 0:** If equity > 0 but equity < collateral + fee (borrow fees ate into the position), delta is negative but the user still "won" the market. The user should get their remaining equity back. The plan's code handles this: delta < 0, `debitPnL(loss)`, `transferOut(vault, vaultBound)`. The user's `_balances` is reduced. But is this correct for a market "winner"? The user might be surprised to lose collateral despite being on the right side. This is economically correct (fees exceeded gains) but may need documentation.

---

### Simpler Alternative

None. The accounting fix requires matching ExecutionEngine's pattern, which means both balance and USDT flow changes.

---

### Revised Effort Estimate

**Medium** as stated. The vault funding amount fix (finding 1) is a small change to the proposed code, not a rearchitecture.

---

### Recommendation

**Do not send to BUILD yet.** One correction required:

1. **Fix the vault funding amount for winners in Step 3.** The vault must fund `profit + settlementFee` (gross profit before fee deduction), not just `profit` (net after fee). This matches ExecutionEngine's pattern where `fundTraderPnL(pnl)` covers both user credit and fee transfer.

Once PLAN updates Step 3 with the correct vault funding amount, this should approve on resubmission. The rest of the plan is correct and well-analyzed.
