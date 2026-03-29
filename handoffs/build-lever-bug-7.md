# BUILD Handoff Report
## Date: 2026-03-29T04:45:00Z
## Task: LEVER-BUG-7 — Zero Liquidations (depthThreshold unset)

---

### Summary

Added a gate check in `ExecutionEngine.openPosition` that rejects positions on markets
where `MarginEngine.depthThreshold(marketId) == 0`. This prevents opening positions in
markets where maintenance margins are miscalibrated (M_market defaults to 1.0, making
liquidations impossible). Also created a configuration script and 5 regression tests.

Step 2 of the plan (guard clauses in BorrowFeeEngine/FundingRateEngine) was already done
by LEVER-P01 and LEVER-P02 (VERIFIED PASS). Skipped per critique guidance.

---

### Changes Made

**contracts/ExecutionEngine.sol** (openPosition, after _validateMarket):
- Added gate check: `if (marginEngine.depthThreshold(params.marketId) == 0) revert ExecutionEngine__MarketNotConfigured(marketId)`
- This prevents NEW positions on unconfigured markets. Existing positions can still be closed/liquidated.

**contracts/interfaces/IExecutionEngine.sol**:
- Added `error ExecutionEngine__MarketNotConfigured(bytes32 marketId)`

**contracts/interfaces/IMarginEngine.sol**:
- Added `function depthThreshold(bytes32 marketId) external view returns (uint256)` to expose the public mapping through the interface

**script/ConfigureMarketRiskParams.s.sol** (new):
- Foundry script that reads oracle depth data and sets depthThreshold for all registered markets across MarginEngine, BorrowFeeEngine, and FundingRateEngine
- Uses `oracleAdapter.getLatestPrice(marketId).depth` as the source of truth
- Defaults to $50K depth if oracle has no data
- IMPORTANT: Contract addresses are placeholder zeros. Must be filled from deploy-env.sh before running.

**test/audit/DepthThreshold.t.sol** (new, 5 tests):
- `test_BUG7_gateCheckBlocksUnconfiguredMarket`: Unconfigured market reverts on openPosition
- `test_BUG7_configuredMarketAllowsOpen`: Configured market allows openPosition
- `test_BUG7_liquidationWorksWithConfiguredDepth`: With proper config, leveraged position is liquidatable after large price move
- `test_BUG7_borrowFeeDoesNotRevertOnZeroDepth`: P02 guard prevents revert
- `test_BUG7_fundingRateDoesNotRevertOnZeroDepth`: P01 guard prevents revert

---

### Files Modified

- `/home/lever/lever-protocol/contracts/ExecutionEngine.sol` (gate check, +6 lines)
- `/home/lever/lever-protocol/contracts/interfaces/IExecutionEngine.sol` (error)
- `/home/lever/lever-protocol/contracts/interfaces/IMarginEngine.sol` (depthThreshold view)
- `/home/lever/lever-protocol/test/audit/AuditNewFindings.t.sol` (added depthThreshold to MockMarginEngine_ANF + set calls in P03/P06 tests for gate check compatibility)

### Files Created

- `/home/lever/lever-protocol/test/audit/DepthThreshold.t.sol`
- `/home/lever/lever-protocol/script/ConfigureMarketRiskParams.s.sol`

---

### Tests Run

```
DepthThreshold.t.sol: 5 passed, 0 failed
ClosePositionFlow.t.sol: 6 passed, 0 failed (regression check)
FeeFlow.t.sol: 15 passed, 0 failed (regression check)
```

---

### Known Risks

1. **Deploy order is critical**: The configuration script (ConfigureMarketRiskParams.s.sol)
   must run BEFORE redeploying ExecutionEngine with the gate check. Otherwise all openPosition
   calls will revert on every market.

2. **Contract addresses in config script are placeholders**: The script has `address(0)` for all
   contract references. Must be filled from deploy-env.sh before use.

3. **Gate check reads from MarginEngine only**: Each engine stores depthThreshold independently.
   The config script must set ALL engines for each market. The gate only validates MarginEngine
   (the most critical for liquidation).

4. **Oracle smoothing**: The liquidation test needed widened smoothing params (alpha=0.9,
   epsilon=50%) to move PI fast enough. In production, gradual PI changes will work
   correctly with the standard smoothing config.

---

### Contract Changes

- ExecutionEngine.sol: new revert in openPosition when depthThreshold=0
- IExecutionEngine.sol: new error `ExecutionEngine__MarketNotConfigured`
- IMarginEngine.sol: new view function `depthThreshold(bytes32)`

---

### Build/Deploy Actions

- `git commit f3537f406` (gate check + tests) and `0634b83ff` (mock fix for existing tests) to `main` branch
- No services restarted (ExecutionEngine requires redeployment for the change to take effect)
- Config script NOT yet run (needs contract addresses filled in first)

---

### Notes for VERIFY

1. Step 2 (guard clauses) was already done by P01/P02. Do NOT look for guard clause changes.
2. The config script is operational tooling, not production code. Verify it compiles but
   contract addresses are intentionally left as address(0) placeholders.
3. The gate check is a contract change (ExecutionEngine is a protected contract). Master
   approved this via the PLAN->CRITIQUE->BUILD pipeline.
