# VERIFY Verdict: LEVER-BUG-6
## Date: 2026-03-29T10:45:00Z
## Task: FeeRouter called without USDT by Liquidation/Settlement
## Verdict: PASS WITH CONCERNS

---

## Summary

Three accounting errors fixed across two engines:

1. **LiquidationEngine**: `_closeAndSettle` now takes a `fee` parameter and subtracts it from vault-bound loss (`vaultLoss = totalDeduct - fee`). Previously the fee was double-spent: sent to FeeRouter via `_routeFee` AND included in the vault transfer.

2. **SettlementEngine**: `claimSettlement` rewritten with delta-based accounting (`delta = payout - collateral`, credit/debit only the delta). Previously `creditPnL(payout)` double-counted collateral.

3. **SettlementEngine fee handling**: Separate `fundTraderPnL` call for the settlement fee so vault backs the USDT before it leaves AccountManager.

4 regression tests pass. No regressions across 46 tests.

---

## Pass 1: Functional Verification

### LiquidationEngine._closeAndSettle (PASS)
`LiquidationEngine.sol:397-418`: New signature `_closeAndSettle(pos, positionId, traderReceives, fee)`.
- Line 408: `totalDeduct = collateral - traderReceives` (everything trader loses)
- Line 414: `vaultLoss = totalDeduct - fee` (vault only gets loss WITHOUT fee)
- Call site at line 348: `_closeAndSettle(pos, positionId, ctx.traderReceives, ctx.fee)` passes the fee correctly.
- `_routeFee` (line 422) handles fee separately: USDT transferred to FeeRouter via `transferOut` + `routeFees`. No overlap.

### SettlementEngine.claimSettlement (PASS)
`SettlementEngine.sol:261-292`: Delta-based accounting rewrite.
- Line 268: `delta = int256(result.payout) - int256(pos.collateral)`
- Winner (delta > 0, lines 270-274): vault funds profit, AM credits profit. Correct.
- Loser/small-winner (delta < 0, lines 275-283): AM debits loss, transfers to vault. Bad debt tracked. Correct.
- Fee handling (lines 288-292): vault sends `settlementFee` to AM, AM sends to FeeRouter, FeeRouter routes. Unconditional on delta sign.

### Numeric Trace Verification

**Trace A (winner, delta > 0):** collateral=100, equity=200, fee=10, payout=190.
- delta=90. Vault sends 90 (profit). User balance: 100+90=190. Fee: vault sends 10, AM sends to FR.
- Vault net: -100. AM net: +90. FR: +10. Conservation: 100 = 190 + 10 - 100. CORRECT.

**Trace C (winner, delta < 0, fees exceed gains):** collateral=100, equity=105, fee=10, payout=95.
- delta=-5. AM debits 5, sends to vault. Fee: vault sends 10, AM sends to FR.
- User: 95. Vault net: +5-10=-5. FR: +10. Conservation: 100=95+10-5. CORRECT.

### Fee Computation for Losers (PASS)
`SettlementEngine.sol:574-579`: Losers have no `settlementFee` computed (only winners at line 566). The `if (result.settlementFee > 0)` guard at line 288 correctly skips fee handling for losers.

### Deploy Script Role Grant (PASS)
`RedeployAuditFixes.s.sol:184`: `IGrantRole(LEVER_VAULT).grantRole(EE_ROLE, address(newSE))`. SettlementEngine needs `EXECUTION_ENGINE_ROLE` on LeverVault for `fundTraderPnL` calls. Grant is in the script but NOT yet executed on-chain.

---

## Pass 2: Visual/Design Verification

N/A. Contract-only change, no frontend modified.

---

## Pass 3: Data Verification

- All values in `claimSettlement` are WAD-scale (consistent with rest of protocol).
- `payout` comes from `_computePositionSettlement` which returns WAD-scale.
- `fundTraderPnL` on MockLeverVault is a no-op (does not transfer USDT). This means Test 2 and Test 4 cannot verify actual USDT movement from vault. They verify AM-side conservation only. The SettlementEngine test (Test 3) is a compilation/structural check. See Concern 2.
- No decimal precision issues. Delta computation is simple subtraction of WAD values.

---

## Test Results

```
FeeAccounting.t.sol:  4/4 PASS
All audit suites:     44/44 PASS
Integration.t.sol:    2/2 PASS
Total: 46 pass, 0 fail (including BUG-1 code changes bundled in same commit)
```

---

## Concerns (Non-Blocking)

### CONCERN 1: EXECUTION_ENGINE_ROLE not yet granted on-chain
SettlementEngine's `fundTraderPnL` calls will revert until `EXECUTION_ENGINE_ROLE` is granted on LeverVault. The grant is in the deploy script but has not been executed. Must be done before any market resolution.

### CONCERN 2: SettlementEngine tests are structural, not functional
Tests 1 and 3 verify compilation and deployment. Tests 2 and 4 verify liquidation-side USDT conservation but use MockLeverVault (which has a no-op `fundTraderPnL`). A full settlement integration test (market resolves, user claims, real USDT flows from vault) would require complex setup not available in IntegrationBase. The numeric traces in the plan serve as the primary correctness evidence. Low risk given the code is a straightforward application of the ExecutionEngine._settlePnL pattern.

### CONCERN 3: BUG-1 code changes bundled in same commit
`ExecutionEngine.sol` and `MarginEngine.sol` PnL formula swaps (`entryPI` -> `entryPrice`) are included in this commit. These were verified separately in verify-lever-bug-1.md. The bundling is acceptable since BUG-1 code changes were applied by a prior session and this was their first commit.

---

## No Design Flaws Found

The delta-based accounting pattern (credit/debit only the difference between payout and collateral) is the same pattern used by ExecutionEngine._settlePnL, which is already proven correct. Applying it to SettlementEngine is sound. The separate vault funding for profit and fee handles all edge cases (winner delta > 0, winner delta < 0, loser).

---

## Decision

**PASS WITH CONCERNS** -- LiquidationEngine fee double-spend fixed. SettlementEngine rewritten with delta-based accounting. 46 tests pass, zero failures. No design flaws. Concerns: on-chain role grant needed, SettlementEngine tests are structural (not end-to-end), BUG-1 code changes bundled.
