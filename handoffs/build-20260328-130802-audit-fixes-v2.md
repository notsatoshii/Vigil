# BUILD Handoff Report
## Date: 2026-03-28 13:08:02 UTC
## Task: Implement all 6 fixes from AUDIT_FINDINGS_V2.md (LEVER-P01 through LEVER-P06)

### Summary
All 6 audit findings from AUDIT_FINDINGS_V2.md have been implemented.
Build: PASS. Test suite: 1068 pass, 4 fail (same 4 pre-existing PriceSmoothing failures as before).
Net change: +1 test passing vs baseline (1067 -> 1068 passed, 5 -> 4 failed).

---

### Changes Made

#### Fix 1: LEVER-P01 - FundingRateEngine depthThreshold=0 guard
**File:** `contracts/FundingRateEngine.sol`
**Function:** `_getRAdjusted` (line 331)
**Change:** Added `if (depthThreshold[marketId] == 0) mMarket = WAD` guard before calling
`RiskCurves.computeMarketAdjustment`. This prevents revert with `ZeroDepthThreshold` for
uninitiated markets. Same pattern as MarginEngine fix from LEVER-007.

#### Fix 2: LEVER-P02 - BorrowFeeEngine depthThreshold=0 guard
**File:** `contracts/BorrowFeeEngine.sol`
**Function:** `_getRBorrowAdjusted` (line 313)
**Change:** Same guard as Fix 1. `_accrueIndex` calls `_computeBorrowRate` which calls
`_getRBorrowAdjusted`. Without this fix, `accrueAll()` reverts for every uninitiated market.

#### Fix 3: LEVER-P05 - FundingRateEngine.routeUnmatchedFunding wrong function
**File:** `contracts/FundingRateEngine.sol`
**Function:** `routeUnmatchedFunding` (line 143)
**Change:** `rewardsDistributor.depositRewards(pending)` -> `rewardsDistributor.receiveUnmatchedFunding(marketId, pending)`
`depositRewards` requires `FEE_ROUTER_ROLE`. FundingRateEngine holds `FUNDING_RATE_ENGINE_ROLE`.
`receiveUnmatchedFunding` accepts `FUNDING_RATE_ENGINE_ROLE` and takes the marketId parameter.

#### Fix 4: LEVER-P03 - ExecutionEngine fee accounting mismatch
**File:** `contracts/ExecutionEngine.sol`
**Changes:**
- Added `TX_FEE_RATE = 1e15` constant (matches `FeeRouter.TX_FEE_RATE`)
- In `_executeOpen`: replaced `feeRouter.collectTransactionFee(notional)` with:
  `txFee = notional * TX_FEE_RATE / WAD`, `accountManager.debitPnL(user, txFee)`,
  `accountManager.transferOut(feeRouter, txFee)`, `feeRouter.routeFees(TRANSACTION, txFee)`
  This fixes Bug A: opening fees were debited from user accounting but the USDT stayed in
  AccountManager forever while FeeRouter paid from its own reserves.
- In `_executeClose`: replaced `feeRouter.collectTransactionFee(pos.positionSize)` with:
  `closingFee = pos.positionSize * TX_FEE_RATE / WAD`
  This fixes Bug B: closing fee was distributed twice (once from collectTransactionFee, once
  again when _settlePnL transferred closingFee to FeeRouter via routeFees).

#### Fix 5: LEVER-P04 - InsuranceFund.absorbBadDebt USDT routing
**Files:** `contracts/InsuranceFund.sol`, `contracts/InsuranceFundFixed.sol`,
`contracts/interfaces/IInsuranceFund.sol`, `contracts/ExecutionEngine.sol`,
`contracts/LiquidationEngine.sol`, `contracts/SettlementEngine.sol`
**Changes:**
- `IInsuranceFund.absorbBadDebt` signature changed: added `address recipient` parameter
- `InsuranceFund.absorbBadDebt`: `usdt.safeTransfer(msg.sender, insurancePaid)` ->
  `usdt.safeTransfer(recipient, insurancePaid)`
- `InsuranceFundFixed.absorbBadDebt`: signature updated for interface compliance (recipient unused)
- All three callers now pass `address(leverVault)` as recipient:
  - `ExecutionEngine._executeClose`
  - `LiquidationEngine._handleBadDebt`
  - `SettlementEngine._handleBadDebtWaterfall`

#### Fix 6: LEVER-P06 - ExecutionEngine never calls updateUnrealizedPnL
**Files:** `contracts/LeverVault.sol`, `contracts/interfaces/ILeverVault.sol`,
`contracts/ExecutionEngine.sol`
**Changes:**
- Added `getNetUnrealizedPnL() returns (int256)` to `ILeverVault` interface and `LeverVault`
  implementation. This getter is needed so ExecutionEngine can compute incremental delta.
- Added `updateUnrealizedPnL(int256 newPnL)` to `ILeverVault` interface (was only in
  LeverVault implementation, not the interface - ExecutionEngine couldn't call it).
- In `ExecutionEngine._executeClose`: after settling PnL, reads current unrealized PnL,
  subtracts the realized `pnl` (removing the closed position from the running total):
  `leverVault.updateUnrealizedPnL(currentUnrealized - pnl)`
- On open: no update needed (initial unrealized PnL = 0, no change to vault total).

---

### Files Modified

**Contracts:**
- `/home/lever/lever-protocol/contracts/FundingRateEngine.sol`
- `/home/lever/lever-protocol/contracts/BorrowFeeEngine.sol`
- `/home/lever/lever-protocol/contracts/ExecutionEngine.sol`
- `/home/lever/lever-protocol/contracts/InsuranceFund.sol`
- `/home/lever/lever-protocol/contracts/InsuranceFundFixed.sol`
- `/home/lever/lever-protocol/contracts/LiquidationEngine.sol`
- `/home/lever/lever-protocol/contracts/SettlementEngine.sol`
- `/home/lever/lever-protocol/contracts/LeverVault.sol`
- `/home/lever/lever-protocol/contracts/interfaces/IInsuranceFund.sol`
- `/home/lever/lever-protocol/contracts/interfaces/ILeverVault.sol`

**Tests (updated for interface/signature changes):**
- `/home/lever/lever-protocol/test/FundingRateEngine.t.sol` (added receiveUnmatchedFunding to mock)
- `/home/lever/lever-protocol/test/ExecutionEngine.t.sol` (updated mock, added new vault methods)
- `/home/lever/lever-protocol/test/LiquidationEngine.t.sol` (updated absorbBadDebt mock signature)
- `/home/lever/lever-protocol/test/SettlementEngine.t.sol` (updated absorbBadDebt mock signature)
- `/home/lever/lever-protocol/test/InsuranceFund.t.sol` (all absorbBadDebt calls + address(this) recipient)
- `/home/lever/lever-protocol/test/integration/InsuranceBadDebt.t.sol` (all absorbBadDebt calls)
- `/home/lever/lever-protocol/test/integration/IntegrationBase.sol` (updated mocks)
- `/home/lever/lever-protocol/test/audit/AuditFindings.t.sol` (updated vault mock)

---

### Tests Run

- `forge test --match-path "test/audit/*"`: 8/8 PASS
- `forge test` (full suite): 1068 PASS, 4 FAIL (same pre-existing PriceSmoothing failures)
- Net improvement: +1 test now passing vs baseline (LEVER-P05 routeUnmatchedFunding test)

---

### Known Risks

1. **LEVER-P06 unrealized PnL tracking is approximate**: The implementation tracks when
   positions CLOSE (subtracts realized pnl). It does NOT track unrealized PnL changes
   between open and close as the oracle price moves. For full correctness, a keeper should
   periodically call `updateUnrealizedPnL` with the actual sum of all open positions' PnL.
   The current fix is a minimal correctness improvement over never calling it at all.

2. **InsuranceFundFixed.sol is a deprecated intermediate contract**: The `recipient` parameter
   is accepted but unused (no USDT transfer in that contract). Any deployment using
   InsuranceFundFixed should migrate to InsuranceFund.

3. **All 5 bugs require contract redeployment** (contracts are not upgradeable).
   After redeployment, call `OILimits.adminResetMarketOI(marketId)` for all 20 markets.

---

### Contract Changes
- No Solidity deployment actions taken. All changes are to source files only.
- These contracts require redeployment to take effect on Base Sepolia.

### Build/Deploy Actions
- `forge build --skip test`: PASS (warnings only, no errors)
- `forge test`: 1068 pass, 4 fail (pre-existing)
