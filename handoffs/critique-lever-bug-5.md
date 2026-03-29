# Critique: LEVER-BUG-5 — InsuranceFund Decimal Mismatch (WAD bootstrap + USDT deposits)
## Date: 2026-03-29T03:49:00Z
## Plan reviewed: handoffs/plan-lever-bug-5.md
## Codebase verified against: /home/lever/lever-protocol @ commit 9f77cc990

---

### Verdict: APPROVED (with mandatory corrections)

The plan is the most thorough of the bug fix plans. The scale analysis is correct, the approach (normalize to WAD internally, convert to USDT at transfer) is sound, and the test plan covers the right properties. One critical correction required: the rewritten `absorbBadDebt` function must preserve the P04 3-arg signature, not revert to 2-arg. BUILD must not copy the Step 2 code verbatim.

---

### What Is Good

- Excellent scale analysis with concrete numerical examples showing exactly how mixed scales produce wrong results.
- Correct diagnosis that InsuranceFundFixed.sol has its own bugs (truncation to zero, missing role, missing transfer).
- Sound approach: WAD normalization internally, USDT only at transfer boundary.
- `_getIFR` correctly identified as already working (USDT / USDT = correct WAD ratio).
- LeverageModel workaround correctly identified as unchanged.
- Good test plan covering scale consistency, daily cap, floor, vault interaction, and regression.
- Correctly identifies the `socializeLoss` caller ripple effect and provides two options.

---

### Issues Found

**1. [CRITICAL] The rewritten `absorbBadDebt` reverts LEVER-P04 (3-arg signature with recipient)**

The plan's Step 2 rewrite (line 144) uses the OLD 2-arg signature:
```solidity
function absorbBadDebt(bytes32 marketId, uint256 totalBadDebt)
```

And line 220 sends to `msg.sender`:
```solidity
usdt.safeTransfer(msg.sender, transferUSDT);
```

The actual code (post-P04) uses 3 args with a `recipient` parameter:
```solidity
function absorbBadDebt(bytes32 marketId, uint256 totalBadDebt, address recipient)
```

Line 188: `usdt.safeTransfer(recipient, insurancePaid);`

All three callers (ExecutionEngine line 378, LiquidationEngine line 444, SettlementEngine line 503) pass `address(leverVault)` as the recipient. If BUILD copies the plan's code verbatim, P04 is reverted and insurance USDT goes to the calling engine contract (stuck, unretrievable).

**Mandatory correction:** BUILD must use the 3-arg signature and `usdt.safeTransfer(recipient, transferUSDT)` instead of `usdt.safeTransfer(msg.sender, transferUSDT)`. The rest of the rewrite (SCALE conversion, WAD normalization) is correct.

---

**2. [HIGH] Caller references use old code and old line numbers**

The plan's "Current Code State" section (lines 78-93) shows the old 2-arg caller code:
```solidity
insuranceFund.absorbBadDebt(pos.marketId, badDebt);
```

Actual code (post-P04):
```solidity
insuranceFund.absorbBadDebt(pos.marketId, badDebt, address(leverVault));
```

Line numbers throughout the plan reference the pre-P03/P04/P06 codebase:
- "ExecutionEngine line 365" is actually ~line 378
- "ExecutionEngine line 367" (socializeLoss) is actually ~line 380
- "SettlementEngine line 502" and "line 516" are also shifted

BUILD must use the actual codebase at `/home/lever/lever-protocol/` and find the correct lines.

---

**3. [HIGH] Open Question 1 is resolved: `_socializedLosses` IS USDT-scale. Conversion IS required.**

I verified LeverVault.sol:
- `_socializedLosses` is USDT-scale (6 decimals)
- `totalAssets()` = `usdt.balanceOf(this) - _netUnrealizedPnL - _socializedLosses` (all USDT-scale)
- `socializeLoss(amount)` adds `amount` directly to `_socializedLosses`

Therefore callers MUST convert `remainder` from WAD to USDT before `socializeLoss`. The plan's Option B is confirmed correct. BUILD should:
- ExecutionEngine: `leverVault.socializeLoss(remainder / 1e12);`
- SettlementEngine: `leverVault.socializeLoss((remainder - totalWinnerPayout) / 1e12);`

Define `SCALE = 1e12` either in each engine (local constant) or import from InsuranceFund.

---

**4. [MEDIUM] Plan should co-deploy with BUG-4 (phantom bootstrap fix)**

The plan's Open Question 2 says "leave constructor as-is" for the phantom bootstrap. But BUG-4's critique (APPROVED) recommends `_balance = 0` and bootstrapping via deploy script. Since InsuranceFund must be redeployed for BUG-5, this is the obvious time to fix the bootstrap too. Having the constructor set `_balance = INSURANCE_BOOTSTRAP` with no backing USDT means the fund starts with a phantom $10K that would immediately fail on `safeTransfer`.

BUILD should apply both BUG-4 and BUG-5 in the same redeployment: set `_balance = 0` in constructor AND rewrite `absorbBadDebt` with correct scale handling.

---

**5. [MEDIUM] LEVER-P06 may have a related scale mismatch in LeverVault**

LEVER-P06 added to ExecutionEngine._executeClose (line 388-389):
```solidity
int256 currentUnrealized = leverVault.getNetUnrealizedPnL();
leverVault.updateUnrealizedPnL(currentUnrealized - pnl);
```

Where `pnl` comes from `_computePnL` which returns WAD-scale values. But `_netUnrealizedPnL` in LeverVault is USDT-scale. If `pnl` is WAD and `currentUnrealized` is USDT, the subtraction `currentUnrealized - pnl` is a scale mismatch.

This is outside BUG-5 scope but directly related. BUILD should note it in the handoff for a follow-up investigation. If confirmed, it's a critical issue (the vault NAV tracker is being corrupted on every position close).

---

**6. [LOW] File paths reference `/home/lever/Lever/`**

Same issue as all other plans. Actual codebase is at `/home/lever/lever-protocol/`.

---

**7. [LOW] Event emission scale change**

Line 165 of the plan's rewrite: `emit DailyCapReset(balanceWAD.wadMul(DAILY_CAP_PCT), ...)` emits WAD-scale daily cap. The current code emits USDT-scale. If any frontend or indexer relies on the event value scale, this is a breaking change. Minor, but BUILD should note it.

---

### Missing Steps

- Verify `_netUnrealizedPnL` scale vs `pnl` scale in the P06 code (related mismatch, separate bug).
- SettlementEngine's `totalWinnerPayout` must also be confirmed as WAD-scale before the `(remainder - totalWinnerPayout) / SCALE` conversion is applied.

---

### Edge Cases Not Covered

- **Multiple absorptions in one transaction:** If a batch liquidation triggers multiple `absorbBadDebt` calls, the `_dailySpent` accumulator (USDT) is updated after each call. The WAD-scaled comparison `dailySpentWAD = _dailySpent * SCALE` is recomputed each time. This is correct but should be tested.
- **Insurance fund with very large balance ($100M+):** `_balance * SCALE` where `_balance = 100_000_000e6` gives `1e8 * 1e6 * 1e12 = 1e26`. Safe within uint256. No overflow concern.

---

### Simpler Alternative

None. The plan's approach (SCALE conversion at boundaries) is already the cleanest solution. The only simplification would be to store `_balance` in WAD instead of USDT, but that would break `deposit()` and `getBalance()` callers, which is worse.

---

### Revised Effort Estimate

**Medium** as stated, plus the BUG-4 co-deployment adds 15 minutes. If the P06 scale mismatch investigation is included, add 1-2 hours.

---

### Recommendation

**Send to BUILD** with these mandatory corrections:

1. **Do NOT copy the Step 2 rewrite verbatim.** Use the 3-arg signature with `recipient` parameter (P04). Replace `usdt.safeTransfer(msg.sender, ...)` with `usdt.safeTransfer(recipient, ...)`.
2. **Co-deploy with BUG-4:** Set `_balance = 0` in constructor. Bootstrap via deploy script.
3. **Callers must convert:** `socializeLoss(remainder / 1e12)` in ExecutionEngine and SettlementEngine. `_socializedLosses` is confirmed USDT-scale.
4. **Delete InsuranceFundFixed.sol** as the plan states.
5. Use `/home/lever/lever-protocol/` as project root. Line numbers in the plan are stale.
6. Note the P06 `_netUnrealizedPnL` scale concern in the handoff for follow-up.
