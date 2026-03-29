# VERIFY Verdict: LEVER-BUG-7
## Date: 2026-03-29T05:10:00Z
## Task: Zero liquidations (depthThreshold unset)
## Verdict: PASS

---

## Summary

BUG-7's root cause: when `depthThreshold=0`, maintenance margins default to `M_market=1.0` (overly lenient), making liquidations impossible. The fix adds a gate check in `ExecutionEngine.openPosition` that rejects new positions on unconfigured markets. Guard clauses for keeper operations (P01/P02) were already in place. 5 regression tests pass. No regressions in existing suites. No design flaws.

---

## Pass 1: Functional Verification

### Gate Check in openPosition (PASS)
`ExecutionEngine.sol:171-176`: After `_validateMarket`, before leverage check:
```solidity
if (marginEngine.depthThreshold(params.marketId) == 0) {
    revert ExecutionEngine__MarketNotConfigured(params.marketId);
}
```
- Placement is correct: after market existence/activation check, before any collateral locking or state changes.
- `closePosition` is NOT gated (line 192). Existing positions on unconfigured markets can still be closed/liquidated. Correct.
- `addCollateral` is NOT gated. Correct (users should be able to add margin to existing positions).

### Interface Additions (PASS)
- `IExecutionEngine.sol:29`: `error ExecutionEngine__MarketNotConfigured(bytes32 marketId)` added.
- `IMarginEngine.sol:88-89`: `function depthThreshold(bytes32 marketId) external view returns (uint256)` exposes the public mapping through the interface. This is needed because ExecutionEngine references MarginEngine via the interface.

### P01/P02 Already Done (PASS)
Confirmed: `FundingRateEngine.sol:344` and `BorrowFeeEngine.sol:324` both have `if (depthThreshold[marketId] == 0) mMarket = WAD` guards from the P01/P02 audit fixes. No duplicate work.

### AuditNewFindings Mock Update (PASS)
`AuditNewFindings.t.sol`: MockMarginEngine_ANF now has a `depthThreshold` mapping and `setDepthThreshold` function. P03 and P06 tests call `marginEngine.setDepthThreshold(MARKET_A, 1e18)` before opening positions, satisfying the gate check. All 6 P01-P06 tests pass.

### IntegrationBase Configuration (PASS)
`IntegrationBase.sol:317-351`: All three engines (MarginEngine, BorrowFeeEngine, FundingRateEngine) and LeverageModel have `depthThreshold = 100_000e18` set for the test market. All integration-based tests (VaultDrain, Integration, DepthThreshold) pass through the gate check.

### DepthThreshold.t.sol (5/5 PASS)
| Test | What it proves |
|------|---------------|
| `gateCheckBlocksUnconfiguredMarket` | New market without depthThreshold reverts on openPosition with `MarketNotConfigured` |
| `configuredMarketAllowsOpen` | Market with depthThreshold > 0 allows position open |
| `liquidationWorksWithConfiguredDepth` | With proper config, 5x leveraged position is liquidatable after adverse price move |
| `borrowFeeDoesNotRevertOnZeroDepth` | P02 guard prevents keeper revert when depthThreshold=0 |
| `fundingRateDoesNotRevertOnZeroDepth` | P01 guard prevents keeper revert when depthThreshold=0 |

Test 3 (liquidation) uses widened smoothing params (alpha=0.9, epsilon=50%) to move PI fast enough in test context. This is appropriate for test isolation; production uses standard smoothing.

---

## Pass 2: Visual/Design Verification

N/A. Contract-only change, no frontend modified.

---

## Pass 3: Data Verification

- `depthThreshold` is uint256 in WAD (1e18 scale). The gate check compares against 0, not a specific value. Scale-agnostic. Correct.
- No decimal precision issues introduced.
- No hardcoded addresses in contract code. Config script has placeholder `address(0)` values (intentional, must be filled from deploy-env.sh).
- The gate reads from `MarginEngine.depthThreshold` only. BorrowFeeEngine and FundingRateEngine have independent `depthThreshold` storage. The config script must set all three engines for each market. This is documented in the handoff.

---

## Test Results

```
DepthThreshold.t.sol:     5/5 PASS
AuditNewFindings.t.sol:   6/6 PASS
VaultDrain.t.sol:         4/4 PASS
Integration.t.sol:        2/2 PASS
Total: 17 pass, 0 fail
```

---

## Concerns (Non-Blocking)

### CONCERN 1: Deploy ordering is critical
The configuration script (ConfigureMarketRiskParams.s.sol) MUST run before redeploying ExecutionEngine. If ExecutionEngine is deployed with the gate check before depthThresholds are set, ALL openPosition calls will revert on every market. The deployment checklist must sequence this correctly.

### CONCERN 2: Three engines need independent configuration
The gate only checks MarginEngine. If BorrowFeeEngine or FundingRateEngine depthThresholds are not set, keepers will use the P01/P02 fallback (M_market=1.0), giving inaccurate risk adjustments. The config script addresses all three engines, but operational verification should confirm all are set post-deployment.

---

## No Design Flaws Found

The gate check is minimal and correctly placed. It prevents the root cause (positions opening in unliquidatable states) without blocking closes or liquidations on existing positions. The approach is sound.

---

## Decision

**PASS** -- gate check in openPosition verified correct. 5 regression tests pass. Existing test suites updated for compatibility. No regressions. No design flaws. Deploy ordering is critical (set depthThresholds before deploying new ExecutionEngine).
