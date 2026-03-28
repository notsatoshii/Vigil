# BUILD Handoff Report
## Date: 2026-03-28
## Task: Full protocol audit Phase 2 - implement fixes for LEVER-P01 through P06

### Changes Made

- `contracts/FundingRateEngine.sol`: LEVER-P01 - added `if (depthThreshold[marketId] == 0) mMarket = WAD` guard in `_getRAdjusted`. LEVER-P05 - changed `rewardsDistributor.depositRewards(pending)` to `rewardsDistributor.receiveUnmatchedFunding(marketId, pending)`.
- `contracts/BorrowFeeEngine.sol`: LEVER-P02 - added same depthThreshold guard in `_getRBorrowAdjusted`.
- `contracts/ExecutionEngine.sol`: LEVER-P03 - replaced `feeRouter.collectTransactionFee(notional)` with direct fee computation + `accountManager.debitPnL` + `accountManager.transferOut(feeRouter)` + `feeRouter.routeFees(TRANSACTION)` in both `_executeOpen` and `_executeClose`. LEVER-P06 - added `leverVault.updateUnrealizedPnL(currentPnL - pnl)` call on close.
- `contracts/InsuranceFund.sol`: LEVER-P04 - changed `absorbBadDebt(uint256)` to `absorbBadDebt(uint256, address recipient)`, sends USDT to `recipient` instead of `msg.sender`.
- `contracts/InsuranceFundFixed.sol`: LEVER-P04 - same signature change.
- `contracts/interfaces/IInsuranceFund.sol`: LEVER-P04 - updated interface signature.
- `contracts/interfaces/ILeverVault.sol`: LEVER-P06 - added `updateUnrealizedPnL(int256)` and `getNetUnrealizedPnL()` to interface.
- `contracts/LeverVault.sol`: LEVER-P06 - added `getNetUnrealizedPnL()` view function.
- `contracts/LiquidationEngine.sol`: LEVER-P04 - updated `absorbBadDebt` call to pass `address(leverVault)`.
- `contracts/SettlementEngine.sol`: LEVER-P04 - same.
- `test/audit/AuditNewFindings.t.sol`: New test file with 6 tests validating all P01-P06 fixes.
- `REVIEW/AUDIT_FINDINGS_FINAL.md`: Updated with Phase 2 findings table, expanded deployment checklist (22 steps), and detailed bug narratives.

### Files Modified
- /home/lever/lever-protocol/contracts/FundingRateEngine.sol
- /home/lever/lever-protocol/contracts/BorrowFeeEngine.sol
- /home/lever/lever-protocol/contracts/ExecutionEngine.sol
- /home/lever/lever-protocol/contracts/InsuranceFund.sol
- /home/lever/lever-protocol/contracts/InsuranceFundFixed.sol
- /home/lever/lever-protocol/contracts/interfaces/IInsuranceFund.sol
- /home/lever/lever-protocol/contracts/interfaces/ILeverVault.sol
- /home/lever/lever-protocol/contracts/LeverVault.sol
- /home/lever/lever-protocol/contracts/LiquidationEngine.sol
- /home/lever/lever-protocol/contracts/SettlementEngine.sol
- /home/lever/lever-protocol/test/audit/AuditNewFindings.t.sol (new)
- /home/lever/lever-protocol/REVIEW/AUDIT_FINDINGS_FINAL.md

### Tests Run
- test_LEVER_P01_fundingEngineDepthThresholdGuard: PASS
- test_LEVER_P02_borrowEngineDepthThresholdGuard: PASS
- test_LEVER_P03_openFeeUsesDirectRouting: PASS
- test_LEVER_P04_insuranceBadDebtGoesToVault: PASS
- test_LEVER_P05_routeUnmatchedFundingCallsCorrectFunction: PASS
- test_LEVER_P06_updateUnrealizedPnLCalledOnClose: PASS
- Full suite: 1074 pass, 4 fail (pre-existing PriceSmoothing failures only)

### Known Risks
- LEVER-P06 fix is minimal-correct: it removes realized PnL from NAV on close, but intra-position drift (unrealized PnL as oracle moves between open and close) is not reflected until a keeper calls updateUnrealizedPnL. This is a LEVER-008 / noted item and does not block demo.
- All 9 contracts with code changes need redeployment. Full deployment checklist is in AUDIT_FINDINGS_FINAL.md (22 steps).
- After redeployment: depthThreshold must be set for all 20 markets, ghost OI must be reset, roles must be granted.

### Contract Changes
All changes were pre-approved as part of the audit fix mandate. Solidity files modified: FundingRateEngine, BorrowFeeEngine, ExecutionEngine, InsuranceFund, InsuranceFundFixed, IInsuranceFund, ILeverVault, LeverVault, LiquidationEngine, SettlementEngine.

### Build/Deploy Actions
- `~/.foundry/bin/forge build` - PASS
- `~/.foundry/bin/forge test` - 1074 pass, 4 pre-existing failures
- Committed as: c59754b02

### Next Steps for VERIFY
1. Review each contract change against AUDIT_FINDINGS_V2.md bug descriptions
2. Confirm the fee flow in ExecutionEngine is correct end-to-end (P03 is the trickiest)
3. Verify InsuranceFund absorbBadDebt now correctly sends to vault, not caller
4. Check that all three callers (ExecutionEngine, LiquidationEngine, SettlementEngine) pass the right recipient
5. Confirm no regressions in the full test suite beyond pre-existing failures
6. Once VERIFY passes: redeployment can proceed using the 22-step checklist in AUDIT_FINDINGS_FINAL.md
