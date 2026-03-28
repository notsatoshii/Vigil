# BUILD Handoff Report
## Date: 2026-03-28T15:10:00Z
## Task: LEVER-BUG-2 — Unaccounted Vault Drain ($304K), regression tests

---

### Summary

The code fix for LEVER-BUG-2 was already applied as LEVER-P03 (verified and merged).
This BUILD session wrote the regression test suite that proves the fix is correct and
would catch any future reversion to the buggy code.

---

### Pre-existing State (confirmed before writing tests)

`ExecutionEngine.sol` already had LEVER-P03 applied:

**Bug A fix (_executeOpen, lines 298-315):**
- Fee computed locally: `uint256 txFee = notional * TX_FEE_RATE / WAD`
- USDT flow: `debitPnL(user, txFee)` + `transferOut(feeRouter, txFee)` + `routeFees(TRANSACTION, txFee)`
- OLD broken code: `collectTransactionFee(notional)` + `debitPnL` (no transferOut, no routeFees)

**Bug B fix (_executeClose, line 370):**
- Fee computed locally: `uint256 closingFee = pos.positionSize * TX_FEE_RATE / WAD`
- OLD broken code: `collectTransactionFee(pos.positionSize)` — draining FeeRouter and then _settlePnL routing again

---

### Changes Made

- `test/audit/VaultDrain.t.sol` — new file, 4 regression tests

---

### Files Modified

- `/home/lever/lever-protocol/test/audit/VaultDrain.t.sol` (created)

---

### Tests Run

```
Ran 4 tests for test/audit/VaultDrain.t.sol:VaultDrainTest
[PASS] test_BUG2_openFeeDebitedFromAccountManager
[PASS] test_BUG2_closeFeeRoutedOnce
[PASS] test_BUG2_accountingInvariantAfterRoundTrip
[PASS] test_BUG2_vaultNotFundedOnBreakevenTrade

4 passed, 0 failed
```

Full suite: 1078 passed, 4 failed (pre-existing failures in PriceSmoothingVerification.t.sol,
unrelated to this work).

---

### What Each Test Proves

| Test | Property | How it catches a regression |
|------|----------|----------------------------|
| `openFeeDebitedFromAccountManager` | AM USDT decreases by txFee on open; FeeRouter USDT increases by txFee | If bug A reintroduced (no transferOut), AM USDT would not decrease |
| `closeFeeRoutedOnce` | `totalFeesCollected` increments by exactly `closingFee` on close | If bug B reintroduced (collectTransactionFee + routeFees), increment would be 2x |
| `accountingInvariantAfterRoundTrip` | `AM USDT + FeeRouter USDT == initial deposit` after open+close | If phantom balance created, sum > initial deposit |
| `vaultNotFundedOnBreakevenTrade` | `vault USDT == 0` throughout; alice's final balance = deposit - 2*txFee | If vault capital consumed, vault USDT would change |

---

### Known Risks

None. Tests use the IntegrationBase setup with MockFeeRouter (real USDT token, tracks balances).
The MockFeeRouter does not forward USDT to LP/protocol/insurance (no-op routeFees), so USDT
accumulates at MockFeeRouter's address — this is by design and the invariant tests account for it.

---

### Contract Changes

None. All changes are test-only.

---

### Build/Deploy Actions

- `git commit 9f77cc990` to `main` branch
- No services restarted (no production code changed)

---

### Notes for VERIFY

1. The 4 VaultDrain tests cover the regression scenarios from plan-lever-bug-2.md.
2. The PriceSmoothingVerification.t.sol failures are pre-existing and unrelated.
3. LEVER-BUG-1 remains BLOCKED (CRITIQUE verdict REVISE x2) — do NOT confuse with BUG-2.
4. The Commander's routing message referenced `plan-20260328-133419.md` (BUG-1 plan, BLOCKED).
   BUILD correctly redirected to `plan-lever-bug-2.md` (the actual BUG-2 plan) based on
   the handoff filename and KANBAN state.
