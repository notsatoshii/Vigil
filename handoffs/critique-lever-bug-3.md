# Critique: LEVER-BUG-3 — Ghost OI (Stale Open Interest with Zero Positions)
## Date: 2026-03-29T03:26:00Z
## Plan reviewed: handoffs/plan-lever-bug-3.md
## Codebase verified against: /home/lever/lever-protocol @ commit 9f77cc990
## Note: Commander routed plan-20260328-133419.md (LEVER-BUG-1); that is the wrong file. This critique reviews plan-lever-bug-3.md per the output filename.

---

### Verdict: APPROVED (with notes)

The plan is well-analyzed. Root cause is correct, the four OI decrement paths are verified, the two defects in `adminResetMarketOI` are real, and the approach is sound. Notes below are guidance for BUILD, not blockers.

---

### What Is Good

- Correct root cause: redeployment artifact, not a code bug. All four OI decrement paths verified correct in the actual codebase (ExecutionEngine line 392, LiquidationEngine line 402, SettlementEngine lines 262 and 318). Only one increment path (ExecutionEngine._executeOpen line 319). No missing decrements.
- Correctly identifies both defects: no on-chain position check (Defect A), no per-user OI clearing (Defect B).
- Safety check (revert if positions exist) prevents misuse on markets with live positions.
- Good test plan covering happy path, revert, no-op, and partial user list.
- Honest about the main uncertainty (PositionManager protected status) and provides alternatives.

---

### Issues Found

**1. [MEDIUM] `getMarketPositions` already exists in IPositionManager; no need to modify PositionManager**

The plan's Open Question 1 asks whether PositionManager is protected and whether `getMarketPositions` exists. I verified:

- `getMarketPositions(bytes32 marketId)` exists in PositionManager (lines 191-193) and is declared in IPositionManager (line 104). It returns `uint256[]` (the array of open position IDs, swap-and-pop removed on close at line 131).
- `_marketPositions` is a `mapping(bytes32 => uint256[])`, NOT EnumerableSet. `.length` works correctly.
- `closePosition` (line 131) removes from `_marketPositions` via swap-and-pop. So `getMarketPositions(marketId).length == 0` reliably means zero open positions.

This resolves the main uncertainty: BUILD does NOT need to add `getMarketPositionCount` to PositionManager. OILimits can call `positionManager.getMarketPositions(marketId).length` via the existing IPositionManager interface.

**Impact on implementation:**
- Step 3 (add `getMarketPositionCount` to PositionManager) can be **skipped entirely**.
- Step 4 (update IPositionManager interface) can be **skipped entirely**.
- Step 2's on-chain check becomes: `uint256 posCount = positionManager.getMarketPositions(marketId).length;`
- Gas note: this external call copies the full array to memory to get the length. For the ghost OI scenario (zero positions), the array is empty (32 bytes). For an admin-only function called rarely, this is acceptable even with non-empty markets. If gas matters, the alternative is to add the counter inside OILimits itself (see Simpler Alternative below).

---

**2. [MEDIUM] File paths reference `/home/lever/Lever/` but the actual codebase is at `/home/lever/lever-protocol/`**

Same issue as LEVER-BUG-1. The plan references:
- `/home/lever/Lever/contracts/OILimits.sol` should be `/home/lever/lever-protocol/contracts/OILimits.sol`
- `/home/lever/Lever/contracts/PositionManager.sol` should be `/home/lever/lever-protocol/contracts/core/PositionManager.sol`
- All script and test paths similarly wrong

BUILD must use `/home/lever/lever-protocol/` as the project root.

---

**3. [MEDIUM] OILimits redeployment itself clears ghost OI; the new function only prevents future occurrences**

The plan requires adding `positionManager` to the OILimits constructor, which means OILimits must be redeployed. Upon redeployment, ALL storage is fresh: `_globalOI`, `_marketOI`, `_longOI`, `_shortOI`, `_userOI` are all zero. The current ghost OI is gone as a side effect of redeployment.

The improved `adminResetMarketOIFull` function protects against future ghost OI (if PositionManager is redeployed again). The plan should make this explicit so BUILD understands: Phase 2 (operational scripts) is about future protection, not fixing the current ghost OI.

The current ghost OI will be cleared by the OILimits redeployment. BUT: if there are any live positions at the time of redeployment, their OI is also lost (new OILimits starts at zero while positions still exist). The diagnostic script (Step 5) must confirm zero live positions before redeployment, not just zero ghost OI.

---

**4. [LOW] Plan assumes EnumerableSet for `_marketPositions`**

Plan Step 3: "This assumes _marketPositions is a EnumerableSet or similar structure." It is actually a plain `uint256[]` with manual swap-and-pop removal. `.length` works identically. BUILD should not look for EnumerableSet patterns.

---

**5. [LOW] `nonReentrant` on the new function differs from existing `adminResetMarketOI`**

The existing `adminResetMarketOI` does NOT have `nonReentrant`. The plan adds `nonReentrant` to `adminResetMarketOIFull`. This is fine (the user list loop could theoretically interact with a malicious address if user addresses were contracts, but they're just used as mapping keys). Note: if OILimits does not currently inherit ReentrancyGuard, adding `nonReentrant` requires importing it. BUILD should check.

---

### Missing Steps

- Verify OILimits inherits ReentrancyGuard before adding `nonReentrant` to the new function.
- Confirm zero live positions (via PositionManager `totalOpenPositions()` and per-market `getMarketPositions`) before OILimits redeployment. Add this as an explicit pre-deployment gate.
- Update `IOILimits.sol` to add `adminResetMarketOIFull` signature (the plan mentions this but it's easy to miss).

---

### Edge Cases Not Covered

- **Redeployment race**: If a position opens between the diagnostic script run and the OILimits redeployment, the new OILimits starts at zero OI but a position exists. This creates reverse ghost OI (position exists, OI = 0). The redeployment should be done with ExecutionEngine paused to prevent new opens. The plan should note this.
- **Script event enumeration**: The reset script reconstructs `affectedUsers[]` from `OIIncreased` events. After OILimits is redeployed, the new contract has no events. The event query must target the OLD OILimits contract address. BUILD should note this in the script.

---

### Simpler Alternative (noted, not required)

The plan's Open Question 1 mentions tracking position count inside OILimits (`increment in increaseOI, decrement in decreaseOI`). This is arguably cleaner:
- No cross-contract dependency (no positionManager reference needed)
- Gas-efficient (single SLOAD for the count)
- Always in sync with OI accumulators
- Bootstrapping: after redeployment, counter starts at 0 (correct if no positions exist)

Downside: if `decreaseOI` is called without a corresponding `increaseOI` (e.g., a position migrated from an old OILimits), the counter underflows (needs floor-at-zero like the existing OI logic). This is the same redeployment edge case the function is designed to handle, so it's circular.

BUILD can choose either approach. The plan's cross-contract approach is fine for an admin-only function.

---

### Revised Effort Estimate

**Small.** Since PositionManager does not need modification (skipping Steps 3-4), the work reduces to:
- One new function in OILimits.sol + constructor change
- Two Forge scripts (diagnostic + reset)
- Four tests
- OILimits redeployment with role re-granting

---

### Recommendation

**Send to BUILD.** The plan is solid. BUILD should note:

1. Use `positionManager.getMarketPositions(marketId).length` for the on-chain check. Do NOT modify PositionManager.
2. Use `/home/lever/lever-protocol/` as project root, not `/home/lever/Lever/`.
3. Confirm zero live positions and pause ExecutionEngine before OILimits redeployment.
4. The current ghost OI is cleared by the redeployment itself; `adminResetMarketOIFull` prevents future recurrence.
