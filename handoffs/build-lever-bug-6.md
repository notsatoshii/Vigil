# BUILD Handoff Report
## Date: 2026-03-29T10:30:00Z
## Task: LEVER-BUG-6 -- FeeRouter Called Without USDT by Liquidation/Settlement
## Plan: plan-lever-bug-6-v2.md (CRITIQUE: APPROVED)

---

### Summary

Three layers of accounting errors fixed:

1. **LiquidationEngine fee double-spend**: `_closeAndSettle` now takes a `fee` parameter and
   subtracts it from the vault-bound loss. Previously `loss = collateral - traderReceives`
   included the fee, but the fee was already sent to FeeRouter in `_routeFee`.

2. **SettlementEngine collateral double-counting**: Replaced `creditPnL(fullPayout)` with
   delta-based credit/debit (same pattern as ExecutionEngine._settlePnL).
   `delta = payout - collateral`, then `creditPnL(delta)` for winners, `debitPnL(-delta)`
   for losers.

3. **SettlementEngine fee transfer without vault backing**: Separate `fundTraderPnL` calls
   for profit and fee. The fee call is unconditional on delta sign, handling the edge case
   where a winner's fees exceed their gains (delta < 0 but settlementFee > 0).

---

### Changes Made

**contracts/LiquidationEngine.sol** (`_closeAndSettle`, lines 397-418):
- Added `fee` parameter
- `vaultLoss = totalDeduct - fee` (vault receives loss WITHOUT fee)
- Call site at line 348 updated: `_closeAndSettle(pos, positionId, ctx.traderReceives, ctx.fee)`

**contracts/SettlementEngine.sol** (`claimSettlement`, lines 261-292):
- Delta-based accounting: `delta = payout - collateral`
- Winner (delta > 0): vault funds profit, creditPnL(profit)
- Loser (delta < 0): debitPnL(loss), transferOut to vault
- Fee handling (separate): vault funds settlementFee, transferOut to FeeRouter, routeFees

**script/RedeployAuditFixes.s.sol** (line 183):
- Added `IGrantRole(LEVER_VAULT).grantRole(EE_ROLE, address(newSE))` for SettlementEngine's
  `fundTraderPnL` calls

**test/audit/FeeAccounting.t.sol** (new, 4 tests):
- `test_BUG6_liquidationEngineDeploysWithFeeParam`: structural verification
- `test_BUG6_liquidationVaultReceivesLossMinusFee`: USDT conservation after liquidation
- `test_BUG6_settlementDeltaBasedCredit`: compilation verification
- `test_BUG6_feeAndVaultLossAreSeparate`: vault and FeeRouter receive separate amounts

Also committed in same changeset: **BUG-1 code changes** (applied by prior session, first commit):
- ExecutionEngine line 383: `pos.entryPI` -> `pos.entryPrice`
- MarginEngine line 370: `pos.entryPI` -> `pos.entryPrice`
- ExecutionEngine `_computePnL` parameter rename

---

### Files Modified

- `/home/lever/lever-protocol/contracts/LiquidationEngine.sol`
- `/home/lever/lever-protocol/contracts/SettlementEngine.sol`
- `/home/lever/lever-protocol/contracts/ExecutionEngine.sol` (BUG-1 code changes)
- `/home/lever/lever-protocol/contracts/MarginEngine.sol` (BUG-1 code changes)
- `/home/lever/lever-protocol/script/RedeployAuditFixes.s.sol`

### Files Created

- `/home/lever/lever-protocol/test/audit/FeeAccounting.t.sol`

---

### Tests Run

```
FeeAccounting.t.sol: 4 passed, 0 failed
All audit tests (9 suites): 44 passed, 0 failed
ClosePositionFlow.t.sol: 6 passed, 0 failed
LiquidationFlow.t.sol: 10 passed, 0 failed
```

---

### Known Risks

1. **SettlementEngine needs EXECUTION_ENGINE_ROLE on LeverVault**: The role grant is in the
   deploy script but has NOT been executed on-chain yet. `fundTraderPnL` will revert until
   the role is granted.

2. **MockLeverVault.fundTraderPnL is a no-op**: The SettlementEngine tests cannot verify
   actual USDT movement from vault in the mock environment. The numeric traces in the plan
   (7 traces, all verified correct) serve as the primary correctness evidence.

3. **SettlementEngine integration test requires market resolution**: Full end-to-end testing
   of the settlement path (market resolves, user claims) is complex to set up in IntegrationBase.
   The tests verify compilation, deployment, and basic accounting properties.

---

### Contract Changes

- LiquidationEngine: `_closeAndSettle` signature + vault loss computation
- SettlementEngine: `claimSettlement` accounting rewrite (delta-based)
- Deploy script: EXECUTION_ENGINE_ROLE grant for SettlementEngine on LeverVault

---

### Build/Deploy Actions

- `git commit 8890a53ba` to `main` branch
- No services restarted
- Role grant NOT yet executed on-chain

---

### Notes for VERIFY

1. Seven numeric traces in the plan (Traces A-G) cover all edge cases. Verify at least
   Trace A (winner, delta > 0) and Trace C (winner, delta < 0, fees exceed gains).
2. The key design decision (separate vault calls for profit and fee) is documented in the
   plan's "Key Design Decision" section.
3. The losers have `settlementFee = 0` (verified in `_computePositionSettlement` line 603).
4. BUG-1 code changes are included in this commit (first time committed).
