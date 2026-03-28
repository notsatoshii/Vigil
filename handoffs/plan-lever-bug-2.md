# Plan: LEVER-BUG-2 — Unaccounted Vault Drain ($304K)
## Date: 2026-03-28
## Requested by: KANBAN BACKLOG

---

### Problem Statement

The vault has lost $426K of LP capital with only $122K traceable to legitimate PnL outflows.
The remaining ~$304K is a silent drain caused by broken fee accounting in ExecutionEngine.

Two distinct bugs in `_executeOpen` and `_executeClose` cause every position to drain vault-seeded
capital from FeeRouter without touching the actual USDT in AccountManager. The accounting says
fees were paid; the USDT never moved.

---

### Root Cause Analysis

**Bug A — Opening fee: FeeRouter bleeds its own reserve**

In `ExecutionEngine._executeOpen()` (line 295-305):

```solidity
uint256 txFee = feeRouter.collectTransactionFee(notional); // BROKEN
ctx.collateralNet = params.collateral - txFee;
// ...
accountManager.lockCollateral(msg.sender, ctx.collateralNet);
if (txFee > 0) {
    accountManager.debitPnL(msg.sender, txFee); // BROKEN
}
```

`feeRouter.collectTransactionFee(notional)` computes the fee and immediately transfers
`lpShare + protocolShare + insuranceShare` FROM FEEROUTER'S OWN USDT BALANCE to their
respective destinations (RewardsDistributor, treasury, InsuranceFund). No USDT enters
FeeRouter from the user before this call.

Then `accountManager.debitPnL(user, txFee)` reduces the user's ledger entry in AccountManager,
but performs no USDT transfer. The actual USDT stays locked in AccountManager.

Net effect per open:
- FeeRouter loses `txFee` USDT (vault-seeded capital exits the system permanently)
- AccountManager retains `txFee` USDT as phantom balance (user ledger is reduced but USDT stays)
- Sum of `_balances` in AccountManager no longer equals AccountManager's actual USDT balance

**Bug B — Closing fee: same fee routed twice**

In `ExecutionEngine._executeClose()` (line 358):

```solidity
uint256 closingFee = feeRouter.collectTransactionFee(pos.positionSize); // BROKEN: payment #1
```

This pays `closingFee` from FeeRouter's own balance (same mechanism as Bug A).

Then `_settlePnL` is called with `closingFee` as a parameter. Inside `_settlePnL` (line 416-432):

```solidity
uint256 totalFees = borrowFees + closingFee; // closingFee included here
// ...
accountManager.transferOut(address(feeRouter), toFeeRouter); // USDT sent to FeeRouter
feeRouter.routeFees(IFeeRouter.FeeType.BORROW, toFeeRouter); // payment #2
```

The closing fee is routed twice:
- First routing: `collectTransactionFee()` pays from FeeRouter's reserve to LP/protocol/insurance
- Second routing: `_settlePnL` moves the same amount from AccountManager to FeeRouter, then routes again

Net effect per close: `closingFee` exits FeeRouter's reserve (payment 1) AND AccountManager sends
`closingFee` to FeeRouter which routes it again (payment 2). LP/protocol/insurance receive double fees;
FeeRouter's seeded vault capital drains at 1x instead of 0x.

**Why the vault is hit**

FeeRouter was seeded with vault USDT during testnet initialization to bootstrap fee distributions.
Every opening fee call drains this seeded balance. Every closing fee call drains it a second time
on top of the AccountManager-sourced second payment. The vault's equity left as FeeRouter seeding
is now gone, reflected in the $426K NAV drop.

---

### Approach

The fix is localized to `ExecutionEngine.sol` only. No changes to FeeRouter, InsuranceFund,
AccountManager, or LeverVault.

**For opening fee (Bug A):**
Stop calling `collectTransactionFee`. Compute the fee locally, use `debitPnL` to update the
user's ledger, use `transferOut` to physically move USDT from AccountManager to FeeRouter,
then call `routeFees` so FeeRouter distributes the USDT it actually received.

**For closing fee (Bug B):**
Stop calling `collectTransactionFee`. Compute the fee locally. The existing `_settlePnL`
logic already correctly handles the USDT flow for closing fees via `transferOut` + `routeFees`.
Removing the redundant `collectTransactionFee` call eliminates the double-payment.

The `_settlePnL` function does NOT need changes. Its `transferOut(feeRouter, toFeeRouter)`
followed by `routeFees(BORROW, toFeeRouter)` is already the correct pattern.

`collectTransactionFee` remains in FeeRouter/IFeeRouter as dead code. It is not removed in this
fix to keep the diff minimal. It can be deprecated in a separate cleanup pass.

---

### Implementation Steps

**Step 1: Add local TX_FEE_RATE constant to ExecutionEngine**

At the top of the constants section in ExecutionEngine.sol, add:

```solidity
/// @notice Transaction fee rate: 0.10% (10 bps). Must match FeeRouter.TX_FEE_RATE.
uint256 internal constant TX_FEE_RATE = 1e15;
```

This avoids an external call to read a constant from FeeRouter. If FeeRouter.TX_FEE_RATE ever
changes, this must be updated in sync. Add the comment to make that dependency explicit.

**Step 2: Fix `_executeOpen` in ExecutionEngine.sol**

Replace lines 295-305:

```solidity
// BEFORE (broken):
uint256 txFee = feeRouter.collectTransactionFee(notional);
ctx.collateralNet = params.collateral - txFee;
// ...
accountManager.lockCollateral(msg.sender, ctx.collateralNet);
if (txFee > 0) {
    accountManager.debitPnL(msg.sender, txFee);
}

// AFTER (correct):
uint256 txFee = notional.wadMul(TX_FEE_RATE);
ctx.collateralNet = params.collateral - txFee;
// ...
accountManager.lockCollateral(msg.sender, ctx.collateralNet);
if (txFee > 0) {
    // Debit the fee from user's ledger, move USDT to FeeRouter, then route
    accountManager.debitPnL(msg.sender, txFee);
    accountManager.transferOut(address(feeRouter), txFee);
    feeRouter.routeFees(IFeeRouter.FeeType.TRANSACTION, txFee);
}
```

USDT flow after fix: User AM balance (debitPnL) -> AM USDT pool (transferOut) -> FeeRouter
(routeFees) -> LP/protocol/insurance. Atomic. No phantom balance. FeeRouter never uses its own reserve.

**Step 3: Fix `_executeClose` in ExecutionEngine.sol**

Replace line 358:

```solidity
// BEFORE (broken — pays from FeeRouter's own reserve, then _settlePnL pays again):
uint256 closingFee = feeRouter.collectTransactionFee(pos.positionSize);

// AFTER (correct — just compute locally; _settlePnL handles the USDT transfer):
uint256 closingFee = pos.positionSize.wadMul(TX_FEE_RATE);
```

No other changes to `_executeClose` or `_settlePnL`. The `_settlePnL` function already correctly
handles the USDT flow: `debitPnL` reduces the user's ledger, `transferOut(feeRouter, toFeeRouter)`
moves USDT, `routeFees(BORROW, toFeeRouter)` distributes it.

**Step 4: Write regression tests**

Add to `test/audit/AuditFindings.t.sol` (or a new `test/audit/VaultDrain.t.sol`):

Test 1: `test_BUG2_openFeeDoesNotDrainFeeRouter`
- Setup: deploy full system with FeeRouter seeded with $10K vault USDT
- Snapshot FeeRouter USDT balance before open
- Open a $1000 notional position
- Assert FeeRouter USDT balance UNCHANGED (receives txFee, immediately distributes it = net 0)
- Assert AccountManager USDT balance decreased by txFee (money actually left AM)
- Assert LP rewards increased by txFee * 0.50

Test 2: `test_BUG2_closeFeeNotDoubleRouted`
- Setup: open and close a position with known parameters
- Track total LP rewards before and after close
- Assert LP received exactly 50% of (borrowFees + closingFee), not more
- Assert total USDT distributed to LP + protocol + insurance == borrowFees + closingFee (once)

Test 3: `test_BUG2_accountingInvariantAfterOpenClose`
- Deposit $10K into vault, open position, close position (net-zero PnL scenario)
- Compute total USDT across: vault + AccountManager + FeeRouter + InsuranceFund + treasury + LP rewards
- Assert: total == initial deposit (no money created or destroyed)
- This is the "no phantom balance" invariant

Test 4: `test_BUG2_vaultNAVUnchangedByFees`
- Vault NAV should not change from fees (fees come from trader collateral, not vault capital)
- Open position, close at breakeven (pnl = 0, fees charged)
- Assert vault NAV == pre-trade NAV (fees came from AM, not vault)

---

### Files to Modify

- `contracts/ExecutionEngine.sol`
  - Add `TX_FEE_RATE` constant (1 line)
  - `_executeOpen()`: replace 1 line with 3 lines (debitPnL + transferOut + routeFees)
  - `_executeClose()`: replace 1 line with 1 line (local computation vs collectTransactionFee call)
  - Total delta: ~+4 lines, -1 line

### Files to Create

- `test/audit/VaultDrain.t.sol` (preferred) OR extend `test/audit/AuditFindings.t.sol`
  - 4 tests covering the regression scenarios above

### Files NOT Changed

- `contracts/FeeRouter.sol` — `collectTransactionFee` stays, just not called
- `contracts/interfaces/IFeeRouter.sol` — no changes
- `contracts/InsuranceFund.sol` — no changes
- `contracts/LeverVault.sol` — no changes
- `contracts/core/AccountManager.sol` — no changes

---

### Dependencies and Ripple Effects

- `_settlePnL` is called for BOTH position close (ExecutionEngine) and liquidation
  (LiquidationEngine). LiquidationEngine may have an analogous bug (LEVER-BUG-10 in audit).
  That is out of scope here — LEVER-BUG-2 covers ExecutionEngine only.
- `borrowFees + closingFee` are routed together as `FeeType.BORROW` in `_settlePnL`. This means
  the closing fee is emitted with the wrong type. This is pre-existing and tracked as a low-severity
  issue by VERIFY. It does not affect USDT flow correctness.
- `feeRouter.TX_FEE_RATE` is `1e15`. The local constant must match. BUILD must verify this before
  committing.

---

### Edge Cases

- **txFee rounds to zero for tiny notionals**: The existing `if (txFee > 0)` guard handles this.
  No change needed.
- **Partial closing fee in bad debt scenario**: `_settlePnL` already handles this. If `toFeeRouter`
  is less than `totalFees` due to bad debt, only what's available is sent. The local computation of
  `closingFee` feeds correctly into this logic.
- **FeeRouter receiving USDT and immediately routing**: The `routeFees` call must happen in the same
  transaction after `transferOut`. If FeeRouter is paused, the call reverts. This is acceptable
  (position open reverts too, which is the safe outcome).
- **params.collateral < txFee**: If someone opens with collateral less than the transaction fee,
  `ctx.collateralNet` would underflow. The existing `_validateMargin` check should catch this
  (minimum margin requirements imply non-trivial collateral). No additional guard needed.

---

### Test Plan

| Test | What it proves |
|------|---------------|
| `test_BUG2_openFeeDoesNotDrainFeeRouter` | FeeRouter's pre-seeded USDT untouched after open |
| `test_BUG2_closeFeeNotDoubleRouted` | Closing fee distributed exactly once |
| `test_BUG2_accountingInvariantAfterOpenClose` | No phantom balance: sum(USDT) conserved |
| `test_BUG2_vaultNAVUnchangedByFees` | Fees come from trader capital, not LP capital |

---

### Effort Estimate

**Small.** Three code changes in one function each, all in ExecutionEngine.sol. The logic in
`_settlePnL` is correct and untouched. Test harness setup is the bulk of the work.

---

### Rollback Plan

ExecutionEngine is redeployable. All state (positions, collateral) lives in PositionManager and
AccountManager, not in ExecutionEngine. Rollback = deploy previous ExecutionEngine from git tag
and update contract address references. No state migration required.

---

### Open Questions

None. The fix is unambiguous. The `_settlePnL` closing fee path is correct as-is; only the
`collectTransactionFee` calls need removal.
