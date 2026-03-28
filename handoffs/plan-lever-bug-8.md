# Plan: LEVER-BUG-8 — No Closing Transaction Fee (10bps Foregone)
## Date: 2026-03-28T16:20:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

The protocol charges a 10bps (0.10%) transaction fee on position opens via
`feeRouter.collectTransactionFee(notional)`. No equivalent fee is charged on position closes.
This forfeits roughly 50% of transaction fee revenue.

An ad-hoc fix (FIX LEVER-009, line 357-358) attempted to add a closing fee by calling
`feeRouter.collectTransactionFee(pos.positionSize)` at the top of `_executeClose`. **This fix
is fundamentally broken** for two reasons:

#### Reason 1: FeeRouter has no USDT at call time

`collectTransactionFee` (FeeRouter.sol line 136-166) immediately distributes USDT from
FeeRouter's own balance via three `usdt.safeTransfer` calls. But at line 358, no USDT has been
transferred to FeeRouter yet for this transaction. The USDT is still in AccountManager.

The transfer to FeeRouter happens later in `_settlePnL` at line 431:
`accountManager.transferOut(address(feeRouter), toFeeRouter)`.

So `collectTransactionFee` either:
- **Reverts** if FeeRouter has zero USDT balance (entire closePosition fails)
- **Double-routes** if FeeRouter has leftover USDT from a prior `routeFees` call

#### Reason 2: Double accounting in _settlePnL

Even if `collectTransactionFee` succeeded, the `closingFee` returned is then passed to
`_settlePnL` where it is:
- Deducted from the user's balance again (line 399: `pnlDelta = pnl - borrowFees - closingFee + funding`)
- Combined with `borrowFees` into `totalFees` (line 416)
- Transferred to FeeRouter AND routed as `FeeType.BORROW` (line 431-432)

The fee would be collected twice: once by `collectTransactionFee` (from FeeRouter's existing
balance) and once by `_settlePnL` (from AccountManager). The user gets double-charged.

#### Why the opening flow works but the closing flow doesn't

On **open** (lines 295-305):
1. `txFee = feeRouter.collectTransactionFee(notional)` — FeeRouter distributes from its balance
2. `ctx.collateralNet = params.collateral - txFee` — reduced collateral is locked
3. `accountManager.debitPnL(msg.sender, txFee)` — user's balance debited

The key: at step 1, FeeRouter must already have USDT. This works because FeeRouter accumulates
USDT from prior `routeFees` calls (borrow fee routing from closed positions). But it is fragile:
if FeeRouter's balance is insufficient, the open reverts too.

On **close** (line 358): Same pattern attempted, but the timing is wrong. The USDT for this
transaction hasn't reached FeeRouter yet.

---

### Current Code State

**ExecutionEngine.sol line 357-358 (broken fix):**
```solidity
// FIX LEVER-009: Collect closing transaction fee
uint256 closingFee = feeRouter.collectTransactionFee(pos.positionSize);
```

**ExecutionEngine.sol _settlePnL lines 416, 431-432 (mixes fee types):**
```solidity
uint256 totalFees = borrowFees + closingFee;       // combines into one bucket
// ...
accountManager.transferOut(address(feeRouter), toFeeRouter);
feeRouter.routeFees(IFeeRouter.FeeType.BORROW, toFeeRouter);  // ← all routed as BORROW
```

**FeeRouter.sol lines 32, 136-166 (collectTransactionFee):**
```solidity
uint256 public constant TX_FEE_RATE = 1e15;  // 0.10% (10 bps)

function collectTransactionFee(uint256 notional) external ... returns (uint256 fee) {
    fee = notional.wadMul(TX_FEE_RATE);
    // ... immediately does usdt.safeTransfer to 3 recipients from FeeRouter's balance
}
```

**Opening flow (lines 295-305) — CORRECT (for comparison):**
```solidity
uint256 txFee = feeRouter.collectTransactionFee(notional);
ctx.collateralNet = params.collateral - txFee;
accountManager.lockCollateral(msg.sender, ctx.collateralNet);
if (txFee > 0) {
    accountManager.debitPnL(msg.sender, txFee);
}
```

---

### Approach

**Remove `collectTransactionFee` from the close path.** The closing fee must follow the same
token flow as borrow fees: compute the amount, include it in `_settlePnL` accounting, transfer
USDT to FeeRouter, then call `routeFees` with the correct FeeType.

The fix has three parts:

1. **Compute the closing fee without routing:** Replace `collectTransactionFee` with a pure
   fee calculation. Either read TX_FEE_RATE from FeeRouter or add a view function.

2. **Route closing fee separately from borrow fees in `_settlePnL`:** After transferring
   the combined fees to FeeRouter, call `routeFees` twice with the correct FeeType for each.

3. **Add `computeTransactionFee` view function to FeeRouter/IFeeRouter:** A pure computation
   that returns the fee amount without moving tokens.

---

### Implementation Steps

**Step 1: Run existing tests**

```bash
cd /home/lever/Lever
forge build
forge test --match-path "test/ExecutionEngine.t.sol" -v
```

---

**Step 2: Add `computeTransactionFee` to FeeRouter**

In `contracts/interfaces/IFeeRouter.sol`, add:
```solidity
/// @notice Compute transaction fee without routing (for closing fee calculation)
/// @param notional Position notional (WAD)
/// @return fee Fee amount (WAD)
function computeTransactionFee(uint256 notional) external pure returns (uint256 fee);
```

In `contracts/FeeRouter.sol`, add:
```solidity
/// @inheritdoc IFeeRouter
function computeTransactionFee(uint256 notional) external pure override returns (uint256 fee) {
    fee = notional.wadMul(TX_FEE_RATE);
}
```

This is a `pure` function (no state reads, no transfers, no role checks). Any contract can call it.

---

**Step 3: Fix `_executeClose` — compute fee without routing**

In `contracts/ExecutionEngine.sol`, change line 357-358:

FROM:
```solidity
// FIX LEVER-009: Collect closing transaction fee
uint256 closingFee = feeRouter.collectTransactionFee(pos.positionSize);
```

TO:
```solidity
// Closing transaction fee: compute amount only; routing happens in _settlePnL
uint256 closingFee = feeRouter.computeTransactionFee(pos.positionSize);
```

No other changes to `_executeClose`. The `closingFee` is still passed to `_settlePnL` at line 361.

---

**Step 4: Fix `_settlePnL` — route fees with correct FeeTypes**

In `contracts/ExecutionEngine.sol`, change the fee routing section (lines 430-433):

FROM:
```solidity
if (toFeeRouter > 0) {
    accountManager.transferOut(address(feeRouter), toFeeRouter);
    feeRouter.routeFees(IFeeRouter.FeeType.BORROW, toFeeRouter);
}
```

TO:
```solidity
if (toFeeRouter > 0) {
    accountManager.transferOut(address(feeRouter), toFeeRouter);

    // Route borrow fees and closing fee separately for correct accounting
    if (borrowFees > 0 && closingFee > 0 && toFeeRouter < totalFees) {
        // Bad debt reduced transferable amount; prorate between fee types
        uint256 borrowToRoute = toFeeRouter * borrowFees / totalFees;
        uint256 closingToRoute = toFeeRouter - borrowToRoute;
        if (borrowToRoute > 0) feeRouter.routeFees(IFeeRouter.FeeType.BORROW, borrowToRoute);
        if (closingToRoute > 0) feeRouter.routeFees(IFeeRouter.FeeType.TRANSACTION, closingToRoute);
    } else {
        // No bad debt shortfall; route each fee type at its full amount
        uint256 borrowToRoute = borrowFees > toFeeRouter ? toFeeRouter : borrowFees;
        uint256 closingToRoute = toFeeRouter - borrowToRoute;
        if (borrowToRoute > 0) feeRouter.routeFees(IFeeRouter.FeeType.BORROW, borrowToRoute);
        if (closingToRoute > 0) feeRouter.routeFees(IFeeRouter.FeeType.TRANSACTION, closingToRoute);
    }
}
```

Token flow: one `transferOut` sends all fees to FeeRouter. Then two `routeFees` calls
distribute from FeeRouter's balance. After the first call, FeeRouter has `closingToRoute` USDT
remaining for the second call. The split percentages are identical (50/30/20), but the
`_totalFeesRouted` accounting is correct per FeeType.

**Note:** `_settlePnL` already receives `closingFee` as a parameter (line 394). No signature change needed.

---

**Step 5: Also fix the opening flow fragility (optional but recommended)**

The opening flow's `collectTransactionFee` call (line 295) is fragile: it assumes FeeRouter
has USDT from prior operations. If FeeRouter is empty (e.g., first-ever open, or after a drain),
the open reverts.

A more robust opening flow:
```solidity
uint256 txFee = feeRouter.computeTransactionFee(notional);  // just compute
ctx.collateralNet = params.collateral - txFee;
accountManager.lockCollateral(msg.sender, ctx.collateralNet);
if (txFee > 0) {
    accountManager.debitPnL(msg.sender, txFee);
    accountManager.transferOut(address(feeRouter), txFee);
    feeRouter.routeFees(IFeeRouter.FeeType.TRANSACTION, txFee);
}
```

This follows the standard `transferOut` + `routeFees` pattern used everywhere else.
It does NOT depend on FeeRouter having existing USDT.

**BUILD decision:** This is a separate improvement beyond the closing fee bug. If it adds
risk, skip it and file as a follow-up. The opening flow works today because FeeRouter tends
to have leftover USDT.

---

**Step 6: Write tests**

New tests in `test/ExecutionEngine.t.sol` or `test/integration/ClosingFee.t.sol`:

**6a. `testClosingFeeDeducted`**
- Open a position with known notional (e.g., 1000e18)
- Close the position
- Verify: the `PositionClosed` event reflects the closing fee deduction
- Verify: user's final balance is reduced by closing fee (10bps of notional)

**6b. `testClosingFeeRoutedAsTransaction`**
- Open and close a position
- Check `feeRouter._totalFeesRouted(FeeType.TRANSACTION)`: should include BOTH the opening
  fee and the closing fee (2 × 10bps × notional)
- Check `feeRouter._totalFeesRouted(FeeType.BORROW)`: should include ONLY borrow fees

**6c. `testClosingFeeReachesRecipients`**
- Record USDT balances of RewardsDistributor, Protocol Treasury, InsuranceFund before close
- Close a position
- Verify: each recipient's USDT balance increased by the correct split of the closing fee

**6d. `testClosingFeeWithBadDebt`**
- Open a highly leveraged position
- Move price against it so equity < fees
- Close the position
- Verify: closingFee and borrowFees are prorated against available balance
- Verify: no revert (bad debt path handles it)

**6e. `testCloseDoesNotRevertWhenFeeRouterEmpty`**
- Ensure FeeRouter has zero USDT balance
- Open and close a position
- Verify: close succeeds (does not depend on FeeRouter having existing USDT)

---

**Step 7: Run full test suite**

```bash
forge test -v
```

---

### Files to Modify

- `contracts/interfaces/IFeeRouter.sol` — add `computeTransactionFee` function signature
- `contracts/FeeRouter.sol` — add `computeTransactionFee` pure function
- `contracts/ExecutionEngine.sol`
  - Line 358: replace `collectTransactionFee` with `computeTransactionFee`
  - Lines 430-433: split `routeFees` into two calls with correct FeeTypes

### Files to Create

- `test/integration/ClosingFee.t.sol` (or add tests to existing ExecutionEngine.t.sol)

### Files to Read First

- `contracts/ExecutionEngine.sol` lines 288-436 (full open and close flows)
- `contracts/FeeRouter.sol` lines 30-170 (TX_FEE_RATE, collectTransactionFee, routeFees)
- `contracts/interfaces/IFeeRouter.sol` — current interface (FeeType enum, existing functions)
- `contracts/core/AccountManager.sol` lines 107-129 (creditPnL, debitPnL, transferOut)

---

### Dependencies and Ripple Effects

- **FeeRouter interface change:** Adding `computeTransactionFee` to IFeeRouter is additive
  (no existing functions changed). All contracts that import IFeeRouter will still compile.

- **`collectTransactionFee` still exists:** It remains in FeeRouter for the opening flow
  (unless Step 5 is implemented). No function is removed.

- **Fee accounting:** `_totalFeesRouted[FeeType.TRANSACTION]` will now include closing fees.
  `_totalFeesRouted[FeeType.BORROW]` will no longer include closing fees. Any dashboard or
  reporting that reads these accumulators will see the correct breakdown.

- **LiquidationEngine and SettlementEngine:** Unaffected. They use `routeFees` with
  `FeeType.LIQUIDATION` and `FeeType.SETTLEMENT` respectively.

- **PositionClosed event:** Currently emits `borrowFees` but NOT `closingFee`. If Master
  wants closing fee visible in events, the event signature needs updating. This is optional
  and can be filed separately.

---

### Edge Cases

**Zero-notional position:** `computeTransactionFee(0)` returns 0. `closingFee = 0`. No
fee routing attempted. Correct.

**Bad debt consumes all fees:** If `badDebt >= totalOutflow`, `transferable = 0`,
`toFeeRouter = 0`. No fees routed. FeeRouter gets nothing. Protocol revenue is lost to bad
debt. This is the existing behavior and is correct (you can't collect fees from an insolvent
position).

**Partial bad debt:** `toFeeRouter < totalFees`. The proration ensures both fee types get
a proportional share. Neither borrow nor closing fee is fully zeroed while the other is fully paid.

**First-ever close (no prior borrow fee accrual):** `borrowFees = 0`, `closingFee > 0`.
`totalFees = closingFee`. `toFeeRouter = closingFee`. Single `routeFees(TRANSACTION, closingFee)`
call. Correct.

**Close with no borrow fees and no closing fee:** `totalFees = 0`, `toFeeRouter = 0`.
No routeFees calls. Correct.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `testClosingFeeDeducted` | User pays 10bps on close |
| `testClosingFeeRoutedAsTransaction` | Fee recorded as TRANSACTION, not BORROW |
| `testClosingFeeReachesRecipients` | USDT reaches RewardsDistributor, Treasury, Insurance |
| `testClosingFeeWithBadDebt` | Proration works, no revert on bad debt |
| `testCloseDoesNotRevertWhenFeeRouterEmpty` | No dependency on FeeRouter's existing balance |

---

### Effort Estimate

**Small** — 2-3 hours.
- Add `computeTransactionFee` to FeeRouter + interface: 15 minutes
- Fix `_executeClose` and `_settlePnL`: 30 minutes
- Write 5 tests: 1-2 hours
- Run full suite + fix any test value changes: 30 minutes

---

### Rollback Plan

Revert the three file changes. The closing fee collection returns to the broken FIX LEVER-009
state (or zero if LEVER-009 was never deployed). No closing fee is collected. The protocol
continues to forgo 10bps on closes. No position integrity risk.

---

### Open Questions

None. The fix is straightforward: compute the fee without routing, include it in `_settlePnL`
accounting, and route with the correct FeeType.

---

### KANBAN Update

Move LEVER-BUG-8 to PLANNED.
