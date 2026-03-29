# Critique: LEVER-BUG-7 — Zero Liquidations (depthThreshold unset)
## Date: 2026-03-29T04:30:00Z
## Plan reviewed: handoffs/plan-lever-bug-7.md
## Codebase verified against: /home/lever/lever-protocol @ commit 9f77cc990

---

### Verdict: APPROVED (with notes)

The root cause analysis is correct: zero liquidations trace to unset depthThreshold values. The plan is partially stale (guard clauses in Step 2 are already applied by LEVER-P01 and P02), but the remaining work (gate check, configuration script, tests) is still needed and well-specified.

---

### What Is Good

- Correct root cause: depthThreshold=0 causes M_market=1.0 (overly lenient), making liquidation thresholds too low.
- Good analysis of the three compounding effects and their interactions.
- Correct identification of the inconsistency across engines.
- Gate check approach is architecturally sound: markets must be configured before they're tradeable.
- Configuration script is the right operational fix (versus hardcoding values).
- Deploy order concern (config before gate check) is correctly flagged.
- `depthThreshold` IS a public mapping on MarginEngine (verified at line 87) so the gate check can read it directly.

---

### Issues Found

**1. [HIGH] Step 2 (guard clauses) is already done. LEVER-P01 and P02 are in KANBAN DONE.**

I verified the actual code:

- **BorrowFeeEngine.sol** `_getRBorrowAdjusted` (lines 313-338): Already has the guard clause with comment `FIX LEVER-P02`. Defaults `mMarket = WAD` when `depthThreshold[marketId] == 0`.
- **FundingRateEngine.sol** `_getRAdjusted` (lines 333-358): Already has the guard clause with comment `FIX LEVER-P01`. Same pattern.

KANBAN DONE confirms both:
- `[2026-03-28] LEVER-P01: FundingRateEngine depthThreshold=0 guard — VERIFIED PASS`
- `[2026-03-28] LEVER-P02: BorrowFeeEngine depthThreshold=0 guard — VERIFIED PASS`

**BUILD should skip Step 2 entirely.** The plan's "Effect 2" (keeper crashes) and "Effect 3" (keeper halts) are already mitigated. The remaining issue is "Effect 1" (MM too lenient) which is addressed by the config script (Step 4) and the gate check (Step 3).

---

**2. [MEDIUM] The plan's "Current Code State" section is stale for BorrowFeeEngine and FundingRateEngine**

The plan shows BorrowFeeEngine lines 320-327 as having NO guard clause. The actual code has the guard clause (FIX LEVER-P02). The plan shows FundingRateEngine as the same. BUILD reading the "Current Code State" section will see outdated code that no longer matches the codebase.

---

**3. [MEDIUM] File paths reference `/home/lever/Lever/`**

Same as all other plans. Actual codebase is at `/home/lever/lever-protocol/`.

---

**4. [LOW] The gate check reads from MarginEngine only, but depthThreshold is per-engine**

The plan's Step 3 checks `marginEngine.depthThreshold(params.marketId) == 0`. But each engine stores its own depthThreshold independently. It is possible (due to a partial configuration) for MarginEngine to have a non-zero depthThreshold while BorrowFeeEngine or FundingRateEngine does not (or vice versa). The guard clauses in P01/P02 prevent reverts, but the risk params may differ across engines.

For a gate check, reading from MarginEngine is reasonable (it's the most important for liquidation). But BUILD should note that the configuration script (Step 4) must set ALL engines simultaneously. The gate check protects against "completely unconfigured" but not "partially configured."

---

**5. [LOW] IntegrationBase test setup (line 313-347) passes zeros for depthThreshold**

The plan notes this but doesn't propose fixing it. If tests use depthThreshold=0, they exercise the guard clause path (M_market=1.0) rather than the real path. Test 5d (`testMMarketCompression`) addresses this with non-zero values, but existing tests should also be updated to use realistic depthThreshold values. Not a blocker, but BUILD should note it.

---

### Missing Steps

None critical. The remaining work (Steps 3, 4, 5, 6) is well-specified.

---

### Edge Cases Not Covered

- **Market registered after configuration script runs:** New markets added to MarketRegistry won't have depthThreshold set. The gate check prevents positions from opening on them (correct), but there's no automated way to configure a new market. This is an operational concern, not a code bug. The configuration script should be re-runnable for new markets.

---

### Simpler Alternative

None. The plan's approach (gate check + config script) is already minimal.

---

### Revised Effort Estimate

**Small-Medium** (reduced from Medium). Step 2 is already done. Remaining:
- Gate check in ExecutionEngine: 30 minutes
- Configuration script: 1-2 hours
- Tests: 1.5 hours
- Deploy + verify: 30 minutes

---

### Recommendation

**Send to BUILD** with these notes:

1. **Skip Step 2 entirely.** Guard clauses already applied by LEVER-P01 and LEVER-P02.
2. **Ignore the "Current Code State" section for BorrowFeeEngine and FundingRateEngine.** The code shown is pre-P01/P02 and no longer matches the actual codebase.
3. Use `/home/lever/lever-protocol/` as project root.
4. Deploy in the stated order: config script first, then gate check.
5. `depthThreshold` is a public mapping on MarginEngine (line 87), so the gate check `marginEngine.depthThreshold(params.marketId)` works directly.
