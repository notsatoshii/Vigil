# Plan: LEVER-BUG-7 — Zero Liquidations (depthThreshold unset)
## Date: 2026-03-28T16:05:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

No positions are being liquidated on the testnet. The root cause is that `depthThreshold` is
zero (unset) for live markets across multiple engines. This has three compounding effects:

#### Effect 1: Maintenance Margin is too lenient

MarginEngine._getRAdj (line 403) has a guard clause (FIX LEVER-007) that defaults `M_market = 1.0`
when `depthThreshold == 0`. This tells the system the market is perfectly liquid and safe.

The formula chain:
```
depthThreshold == 0
  → M_market = 1.0 (guard clause, no market risk adjustment)
  → R_adjusted = R(τ) × 1.0 (uncompressed)
  → MM_Multiplier = 3.0 - R_adjusted × 2.0 (lower than it should be)
  → MM = BASE_MM_RATE × notional × MM_Multiplier (understated)
  → Liquidation threshold too low → positions never cross it
```

For a market far from resolution: R(τ) ≈ 1.0, so MM_Multiplier = 1.0 (minimum).
With proper M_market (e.g. 0.3 for illiquid market): R_adjusted = 0.3, MM_Multiplier = 2.4.
The maintenance margin is up to **2.4x lower** than it should be.

#### Effect 2: Borrow fees and funding rates stop accruing

BorrowFeeEngine._getRBorrowAdjusted (line 320) calls `RiskCurves.computeMarketAdjustment`
directly WITHOUT any guard clause. When `depthThreshold == 0`, this calls
`computeDepthFactor` which reverts with `RiskCurves__ZeroDepthThreshold()`.

Same for FundingRateEngine (calls computeMarketAdjustment without guard).

The keeper processes that update borrow/funding indices REVERT on these calls. This means:
- Borrow indices freeze at their last value
- Funding indices freeze at their last value
- Borrow fees stop accruing → position equity stays higher than it should
- Funding imbalances are not charged → no rebalancing pressure

The read functions (`getAccruedFees`, `getAccruedFunding`) still work because they use the
STORED indices. But those indices never update, so accrued fees plateau.

#### Effect 3: Keeper processes may crash entirely

If the borrow/funding keeper script encounters the revert and does not handle it gracefully, it
may halt for ALL markets, not just the unconfigured ones. This is an operational failure mode:
one misconfigured market can kill fee accrual for the entire protocol.

**Combined effect:** Positions opened with high leverage in illiquid markets have:
- Lower MM than appropriate (never get liquidated)
- Frozen borrow fees (equity degrades slower)
- Frozen funding (no rebalancing)

Result: zero liquidations.

---

### Current Code State

**MarginEngine.sol lines 403-416 — guard clause (the bandaid fix):**
```solidity
// FIX LEVER-007: Skip market adjustment if depthThreshold not configured
uint256 mMarket;
if (depthThreshold[marketId] == 0) {
    mMarket = WAD; // No market adjustment when unconfigured
} else {
    mMarket = RiskCurves.computeMarketAdjustment(
        sigmaCurrent[marketId], sigmaBaseline[marketId],
        externalDepth[marketId], depthThreshold[marketId],
        marketOI[marketId], globalOI
    );
}
```

**BorrowFeeEngine.sol lines 320-327 — NO guard clause (REVERTS on zero):**
```solidity
uint256 mMarket = RiskCurves.computeMarketAdjustment(
    sigmaCurrent[marketId], sigmaBaseline[marketId],
    externalDepth[marketId], depthThreshold[marketId],  // ← reverts if 0
    marketOI[marketId], globalOI
);
```

**FundingRateEngine.sol — same pattern, NO guard clause (REVERTS on zero).**

**RiskCurves.sol line 109:**
```solidity
if (depthThreshold == 0) revert RiskCurves__ZeroDepthThreshold();
```

**LeverageModelFixed.sol lines 321-324 — defensive defaults:**
```solidity
if (params.depthThreshold == 0) {
    params.sigmaBaseline = 0.25e18;
    params.depthThreshold = 1e18;
}
```

**ExecutionEngine.sol `_computeRAdjusted` (line 536-541) — does NOT use M_market at all:**
```solidity
function _computeRAdjusted(bytes32 marketId) internal view returns (uint256) {
    uint256 tau = marketRegistry.getTau(marketId);
    bool isLive = marketRegistry.isLive(marketId);
    uint256 tauEff = RiskCurves.computeTauEffective(tau, isLive);
    return RiskCurves.computeR(tauEff);  // Pure R(τ), no M_market
}
```

**IntegrationBase.sol lines 313-347 — tests set depthThreshold explicitly:**
```solidity
borrowFeeEngine.updateMarketRiskParams(marketId, 1e17, 1e17, 100_000e18, 100_000e18, 0, 0);
fundingRateEngine.updateMarketRiskParams(marketId, 1e17, 1e17, 100_000e18, 100_000e18, 0, 0);
marginEngine.updateMarketRiskParams(marketId, 1e17, 1e17, 100_000e18, 100_000e18, 0, 0);
```

**Summary of inconsistency across engines:**

| Engine | depthThreshold=0 behavior | Risk |
|--------|--------------------------|------|
| MarginEngine | Guard: M_market=1.0 | MM too lenient, no liquidations |
| BorrowFeeEngine | REVERTS | Keeper crashes, fees freeze |
| FundingRateEngine | REVERTS | Keeper crashes, funding freezes |
| LeverageModelFixed | Defaults to 1e18 | Leverage computed with arbitrary depth |
| LeverageModel (base) | REVERTS | openPosition fails |
| ExecutionEngine | Does not use depthThreshold | Execution depth unaffected |

---

### Approach

Two-part fix: **enforce configuration at the gate, and add consistent guards everywhere.**

**Part A: Gate check — reject operations on unconfigured markets.**
Add a validation in ExecutionEngine.openPosition and MarketRegistry that ensures
depthThreshold is set for a market before any positions can be opened. This is the
correct architectural solution: markets must be fully configured before they are tradeable.

**Part B: Consistent guard clauses — prevent reverts in fee engines.**
Add the same guard clause from MarginEngine to BorrowFeeEngine and FundingRateEngine.
When depthThreshold=0, default M_market=1.0 instead of reverting. This prevents keeper
crashes and ensures existing positions on partially-configured markets can still have
their fees computed.

**Part C: Configuration script — set depthThreshold for all live markets.**
Create a Foundry script that reads oracle depth data and sets appropriate depthThreshold
values for all registered markets across all 4 engines (MarginEngine, BorrowFeeEngine,
FundingRateEngine, LeverageModel).

---

### Implementation Steps

**Step 1: Run existing tests to establish baseline**

```bash
cd /home/lever/Lever
forge build
forge test --match-path "test/MarginEngine.t.sol" -v
forge test --match-path "test/LiquidationEngine.t.sol" -v
forge test --match-path "test/audit/AuditFindings.t.sol" --match-test "LEVER007" -v
```

---

**Step 2: Add guard clauses to BorrowFeeEngine and FundingRateEngine**

In `BorrowFeeEngine.sol`, `_getRBorrowAdjusted` (lines 313-330):

FROM:
```solidity
function _getRBorrowAdjusted(bytes32 marketId) internal view returns (uint256) {
    uint256 tauHours = marketRegistry.getTau(marketId);
    bool isLive_ = marketRegistry.isLive(marketId);
    uint256 tauEff = RiskCurves.computeTauEffective(tauHours, isLive_);
    uint256 rBorrow = RiskCurves.computeRBorrow(tauEff);

    uint256 mMarket = RiskCurves.computeMarketAdjustment(
        sigmaCurrent[marketId], sigmaBaseline[marketId],
        externalDepth[marketId], depthThreshold[marketId],
        marketOI[marketId], globalOI
    );

    return RiskCurves.computeRAdjusted(rBorrow, mMarket);
}
```

TO:
```solidity
function _getRBorrowAdjusted(bytes32 marketId) internal view returns (uint256) {
    uint256 tauHours = marketRegistry.getTau(marketId);
    bool isLive_ = marketRegistry.isLive(marketId);
    uint256 tauEff = RiskCurves.computeTauEffective(tauHours, isLive_);
    uint256 rBorrow = RiskCurves.computeRBorrow(tauEff);

    uint256 mMarket;
    if (depthThreshold[marketId] == 0) {
        mMarket = WAD;
    } else {
        mMarket = RiskCurves.computeMarketAdjustment(
            sigmaCurrent[marketId], sigmaBaseline[marketId],
            externalDepth[marketId], depthThreshold[marketId],
            marketOI[marketId], globalOI
        );
    }

    return RiskCurves.computeRAdjusted(rBorrow, mMarket);
}
```

Apply the same pattern to FundingRateEngine's equivalent function. Search for
`computeMarketAdjustment` in FundingRateEngine.sol and wrap with the same guard.

---

**Step 3: Add market configuration validation to ExecutionEngine.openPosition**

In `ExecutionEngine.sol`, at the top of `openPosition` (before any state changes),
add a check that the market's depthThreshold is configured in MarginEngine:

```solidity
// Reject positions on markets with unconfigured risk parameters
if (marginEngine.depthThreshold(params.marketId) == 0) {
    revert ExecutionEngine__MarketNotConfigured(params.marketId);
}
```

Add the custom error:
```solidity
error ExecutionEngine__MarketNotConfigured(bytes32 marketId);
```

This prevents NEW positions from being opened on unconfigured markets. Existing positions
on unconfigured markets can still be closed/liquidated (the guard clauses handle that).

**Alternative (if depthThreshold is not publicly readable from MarginEngine):** Add a
`isMarketConfigured(bytes32 marketId)` view function to MarginEngine that returns
`depthThreshold[marketId] > 0`.

---

**Step 4: Create configuration script**

New file: `script/ConfigureMarketRiskParams.s.sol`

This script:
1. Reads all registered markets from MarketRegistry
2. For each market, reads the oracle depth from OracleAdapter
3. Sets depthThreshold = externalDepth (Depth_Factor = 1.0 when depth matches threshold)
4. Sets other risk params to reasonable defaults:
   - sigmaCurrent = sigmaBaseline = 0.1e18 (10% baseline vol)
   - externalDepth = read from oracle
   - depthThreshold = externalDepth
   - marketOI = read from OILimits
   - globalOI = sum of all markets' OI
5. Calls `updateMarketRiskParams` on ALL four engines:
   - MarginEngine
   - BorrowFeeEngine
   - FundingRateEngine
   - LeverageModel (or LeverageModelFixed)

```solidity
// Pseudocode
for each marketId in registeredMarkets:
    uint256 depth = oracleAdapter.getDepth(marketId);  // or a reasonable default
    if (depth == 0) depth = 1e18;  // minimum 1 USDT

    marginEngine.updateMarketRiskParams(marketId, sigma, sigma, depth, depth, mktOI, gOI);
    borrowFeeEngine.updateMarketRiskParams(marketId, sigma, sigma, depth, depth, mktOI, gOI);
    fundingRateEngine.updateMarketRiskParams(marketId, sigma, sigma, depth, depth, mktOI, gOI);
    leverageModel.setMarketParams(marketId, sigma, depth);
```

Run with:
```bash
forge script script/ConfigureMarketRiskParams.s.sol --rpc-url $RPC_URL --broadcast
```

**IMPORTANT:** BUILD must read the oracle adapter to understand what depth data is available.
If the oracle does not provide depth (CLOB orderbook depth), use a sensible default
(e.g., $50,000 for active Polymarket markets, $10,000 for thin markets).

**IMPORTANT from LESSONS.md:** "Depth thresholds were set to 1000x while actual oracle depths
were around 1.0." The values MUST match the oracle's scale. If oracle returns depth in WAD
($50,000 = 50_000e18), then depthThreshold must be in the same scale.

---

**Step 5: Write tests**

New file: `test/integration/DepthThresholdConfig.t.sol`

**5a. `testLiquidationWorksWithConfiguredDepth`**
- Register a market with proper depthThreshold on all engines
- Open a leveraged position
- Move price against the position until equity < MM
- Call `isLiquidatable`: should return true
- Execute liquidation: should succeed
- This is the basic "liquidations work" smoke test

**5b. `testLiquidationFailsWithZeroDepthThreshold`**
- Register a market WITHOUT setting depthThreshold
- Open a position (should be blocked by the gate check in Step 3)
- Verify: revert with `ExecutionEngine__MarketNotConfigured`

**5c. `testBorrowFeeKeeperDoesNotRevertOnZeroDepth`**
- Set depthThreshold = 0 for a market in BorrowFeeEngine
- Call the borrow index update function
- Verify: does NOT revert (guard clause catches it)
- Verify: rate is computed with M_market = 1.0

**5d. `testMMarketCompression`**
- Set depthThreshold = 100_000e18, externalDepth = 50_000e18 (illiquid)
- Compute R_adjusted: should be R(τ) × 0.5 (Depth_Factor = 0.5)
- Compute MM_Multiplier: should be higher than with depthThreshold=0
- Compute MM: should be higher
- Verify: position is liquidatable at a higher equity threshold

**5e. `testAllEnginesHaveConsistentDepthThreshold`**
- Set depthThreshold on all 4 engines to the same value
- Verify: M_market is computed identically across MarginEngine, BorrowFeeEngine,
  FundingRateEngine
- Verify: no engine reverts

---

**Step 6: Run full test suite and deploy configuration**

```bash
forge test -v
```

After tests pass, deploy the configuration script to testnet:
```bash
forge script script/ConfigureMarketRiskParams.s.sol --rpc-url $BASE_SEPOLIA_RPC --broadcast
```

Verify on-chain:
```bash
cast call $MARGIN_ENGINE "depthThreshold(bytes32)" $MARKET_ID --rpc-url $BASE_SEPOLIA_RPC
```

Should return non-zero value.

---

### Files to Modify

- `contracts/BorrowFeeEngine.sol`
  - `_getRBorrowAdjusted` (~line 313): add depthThreshold==0 guard clause

- `contracts/FundingRateEngine.sol`
  - Equivalent function: add depthThreshold==0 guard clause

- `contracts/ExecutionEngine.sol`
  - `openPosition`: add market configuration check (depthThreshold > 0)
  - Add custom error `ExecutionEngine__MarketNotConfigured`

### Files to Create

- `script/ConfigureMarketRiskParams.s.sol` — configuration deployment script
- `test/integration/DepthThresholdConfig.t.sol` — 5 tests

### Files to Read First (BUILD must read all of these)

- `contracts/MarginEngine.sol` lines 85-95 (risk param storage), 205-224 (isLiquidatable),
  391-420 (_getRAdj with guard)
- `contracts/BorrowFeeEngine.sol` lines 77-82 (risk params), 310-330 (_getRBorrowAdjusted)
- `contracts/FundingRateEngine.sol` — find equivalent _getRAdj function
- `contracts/libraries/RiskCurves.sol` lines 101-165 (computeDepthFactor, computeMarketAdjustment)
- `contracts/LeverageModelFixed.sol` lines 318-325 (defensive defaults)
- `contracts/ExecutionEngine.sol` — openPosition entry point and _computeRAdjusted
- `contracts/core/OracleAdapter.sol` — what depth data is available
- `test/integration/IntegrationBase.sol` lines 313-347 (how tests configure risk params)

---

### Dependencies and Ripple Effects

- **Existing positions on unconfigured markets:** The guard clauses ensure these can still be
  closed and liquidated (using M_market=1.0). The gate check only prevents NEW positions.

- **Keeper processes (lever-oracle, lever-accrue-keeper):** After guard clauses are added,
  keepers will no longer crash on unconfigured markets. They will compute rates with M_market=1.0
  until proper configuration is deployed.

- **LeverageModelFixed:** Already has defensive defaults (line 321-324). No changes needed.
  But verify it uses the same depthThreshold as the other engines after configuration.

- **ExecutionEngine._computeRAdjusted:** Does NOT use M_market. This means execution depth
  (for impact calculation) is not affected by depthThreshold. This is a design asymmetry:
  margin requirements account for market risk, but execution impact does not. This is acceptable
  for now but should be noted for future risk model work.

- **MarketRegistry:** Does NOT store depthThreshold. Each engine stores its own copy. This
  means the configuration script must update ALL engines. If a market is added in the future,
  ALL engines must be configured before the market is tradeable.

---

### Edge Cases

**Market with zero OI:** When marketOI=0, `computeConcentrationFactor` returns 1.0 (no
concentration risk). This is correct. New markets start with zero OI.

**Market with zero externalDepth but non-zero depthThreshold:** Depth_Factor = 0/threshold = 0.
M_market = 0 (or near zero). R_adjusted ≈ 0. MM_Multiplier = 3.0. MM is maximum. This is
EXTREMELY conservative (highest possible margin requirement). Correct behavior: the system
demands maximum margin when the market has no liquidity.

**Market with externalDepth > depthThreshold:** Depth_Factor = 1.0. M_market is determined
by Vol_Factor and Concentration_Factor only. Normal operation.

**Configuration race condition:** If positions are opened between deploying the gate check and
deploying the configuration script, they might be blocked. Solution: deploy configuration
script FIRST, then the contract update with the gate check.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `testLiquidationWorksWithConfiguredDepth` | Liquidations actually fire with proper config |
| `testLiquidationFailsWithZeroDepthThreshold` | Gate check blocks positions on unconfigured markets |
| `testBorrowFeeKeeperDoesNotRevertOnZeroDepth` | Guard clause prevents keeper crashes |
| `testMMarketCompression` | Illiquid markets produce higher MM (tighter margin) |
| `testAllEnginesHaveConsistentDepthThreshold` | All engines compute same M_market |

---

### Effort Estimate

**Medium** — 4-6 hours.
- Guard clauses in BorrowFeeEngine + FundingRateEngine: 30 minutes
- Gate check in ExecutionEngine: 30 minutes
- Configuration script: 1-2 hours (requires reading oracle/market setup)
- Tests: 2 hours
- Deploy + verify on testnet: 30 minutes

---

### Rollback Plan

**Guard clauses:** These are strictly additive (prevent reverts). Safe to leave in place.
Rollback: not needed.

**Gate check:** If the gate check blocks legitimate operations (e.g., a new market that is
properly configured but the check reads from the wrong engine), remove the check from
ExecutionEngine.openPosition. Positions can still be opened without it; they just won't
have proper margin calibration.

**Configuration script:** If wrong values are set, re-run the script with correct values.
`updateMarketRiskParams` overwrites the previous config. No state migration needed.

---

### Open Questions

1. **What oracle depth data is available?** OracleAdapter may not expose per-market depth.
   BUILD must check if `getDepth(marketId)` or equivalent exists. If not, use the Polymarket
   CLOB orderbook depth that the oracle keeper fetches, or hardcode reasonable defaults
   ($50K-$100K for active markets).

2. **Should depthThreshold be centralized?** Currently each engine stores its own copy. A
   future improvement could store depthThreshold once in MarketRegistry and have all engines
   read from there. This is out of scope for this bug fix but should be noted for IMPROVE.

3. **Deploy order:** The configuration script must run BEFORE the gate check is deployed.
   Otherwise, all openPosition calls will revert. BUILD must deploy in this order:
   (a) Guard clauses (prevent keeper crashes)
   (b) Configuration script (set values)
   (c) Gate check (enforce configuration)

---

### KANBAN Update

Move LEVER-BUG-7 to PLANNED.
