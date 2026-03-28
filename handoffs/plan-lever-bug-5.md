# Plan: LEVER-BUG-5 — InsuranceFund Decimal Mismatch (WAD bootstrap + USDT deposits)
## Date: 2026-03-28T14:30:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

The InsuranceFund contract mixes two incompatible decimal scales:

- **USDT (6 decimals):** `_balance`, deposits from FeeRouter, `totalAssets()` from LeverVault
- **WAD (18 decimals):** `totalBadDebt` from ExecutionEngine/SettlementEngine, percentage constants,
  `wadMul`/`wadDiv` library functions

The protocol's `FixedPointMath.wadMul(a, b)` computes `a * b / 1e18`. When `a` is in WAD and `b` is
a WAD-scale percentage, the result is in WAD. When `a` is in USDT (6-decimal), the result is in USDT.
The contract never accounts for this difference, so:

1. `insuranceTarget` (from WAD bad debt) is in WAD scale (1e18)
2. `dailyCap` and `floor` (from USDT balance/TVL) are in USDT scale (1e6)
3. They are directly compared, producing nonsensical results
4. `remainder = totalBadDebt(WAD) - insurancePaid(USDT)` is an invalid subtraction
5. `socializeLoss(remainder)` passes a near-WAD value to LeverVault, which uses USDT,
   potentially wiping out the entire vault NAV

**Concrete example:** $1,000 bad debt with $10,000 insurance balance:
- `insuranceTarget = 1000e18.wadMul(7e17) = 700e18` (WAD)
- `dailyCap = 10_000e6.wadMul(25e16) = 2_500e6` (USDT)
- `700e18 > 2_500e6`? YES (always true, 1e12x scale difference)
- Insurance always clamps to daily cap, regardless of tier percentage
- `insurancePaid = 2_500e6`, `remainder = 1000e18 - 2_500e6 ≈ 1000e18`
- Vault receives `socializeLoss(~1000e18)` when real remainder is ~$0
- `_socializedLosses += 1000e18`, nuking `totalAssets()` by $1e12

**The InsuranceFundFixed.sol attempt is ALSO BROKEN.** It applies `/ WAD * USDT_DECIMALS` after
every wadMul, but this conversion only works when the wadMul input was in WAD. When the input was
already USDT (like `_balance` or `tvl`), the division by WAD truncates to zero:
- `_balance.wadMul(DAILY_CAP_PCT)` = 2_500e6 (USDT, correct)
- `2_500e6 / 1e18 * 1e6` = 0 (integer truncation)

Additionally, InsuranceFundFixed is missing the `EXECUTION_ENGINE_ROLE` in its role check
(lines 122-127) and does not include the `safeTransfer` added as FIX LEVER-002.

---

### Current Code State (BUILD must read before touching anything)

**InsuranceFund.sol (deployed, buggy):**

| Line | Code | Scale Issue |
|------|------|------------|
| 36 | `INSURANCE_BOOTSTRAP = 10_000e6` | Correct (USDT). Fixed from earlier WAD bug. |
| 94 | `_balance = INSURANCE_BOOTSTRAP` | Correct (USDT) |
| 109 | `_balance += amount` | Correct (FeeRouter sends USDT amounts) |
| 153 | `insuranceTarget = totalBadDebt.wadMul(insurancePct)` | **BUG:** Result is WAD. Compared against USDT values below. |
| 156 | `dailyCap = _balance.wadMul(DAILY_CAP_PCT)` | Result is USDT (correct by accident). Compared against WAD insuranceTarget. |
| 164 | `floor = tvl.wadMul(IFR_FLOOR)` | Result is USDT (correct). Compared against USDT maxSpend. OK. |
| 177 | `remainder = totalBadDebt - insurancePaid` | **BUG:** WAD minus USDT = garbage. |
| 186 | `usdt.safeTransfer(msg.sender, insurancePaid)` | Transfer amount is USDT (accidentally correct after daily cap clamp). |

**InsuranceFundFixed.sol (not deployed, also buggy):**

| Line | Code | Scale Issue |
|------|------|------------|
| 152 | `insuranceTarget = totalBadDebt.wadMul(insurancePct) / WAD * USDT_DECIMALS` | Correct conversion (WAD to USDT). |
| 155 | `dailyCap = _balance.wadMul(DAILY_CAP_PCT) / WAD * USDT_DECIMALS` | **BUG:** Truncates to 0. Already USDT before conversion. |
| 163 | `floor = tvl.wadMul(IFR_FLOOR) / WAD * USDT_DECIMALS` | **BUG:** Truncates to 0. Same issue. |
| 176 | `remainder = totalBadDebt - insurancePaid` | **BUG:** Still WAD minus USDT. |
| N/A | Missing `EXECUTION_ENGINE_ROLE` in role check | **BUG:** ExecutionEngine cannot call absorbBadDebt. |
| N/A | Missing `safeTransfer` of USDT on payout | **BUG:** No actual tokens move. |

**Callers expect WAD returns (per IInsuranceFund interface, line 40-41):**
```solidity
/// @return insurancePaid Amount paid by insurance fund (WAD)
/// @return remainder Amount NOT covered by insurance (WAD)
```

**ExecutionEngine.sol line 365:**
```solidity
(uint256 insurancePaid, uint256 remainder) = insuranceFund.absorbBadDebt(pos.marketId, badDebt);
if (remainder > 0) {
    leverVault.socializeLoss(remainder);  // remainder must be correct scale
}
```

**SettlementEngine.sol line 502:**
```solidity
(uint256 insurancePaid, uint256 remainder) = insuranceFund.absorbBadDebt(marketId, totalBadDebt);
// ... remainder used in wadDiv for ADL haircut calculation (line 513)
```

**LeverVault.socializeLoss (line 329):** just adds `amount` to `_socializedLosses`, which is
subtracted from `totalAssets()`. This uses USDT balance, so the amount must be USDT-scale.

---

### Approach

The cleanest fix: **normalize to WAD inside `absorbBadDebt`, convert to USDT only for the transfer.**

1. All inputs arrive in WAD (from callers). All outputs return in WAD (per interface).
2. Internal `_balance` stays in USDT (deposits from FeeRouter are USDT).
3. At the top of `absorbBadDebt`, scale `_balance` up to WAD for comparison math.
4. After determining the WAD-scale payout, convert to USDT for the actual `safeTransfer`.
5. Deduct the USDT amount from `_balance`.

This approach:
- Does NOT change the interface. Callers (ExecutionEngine, SettlementEngine) are unchanged.
- Does NOT change deposit(). FeeRouter is unchanged.
- All WAD math stays in WAD. No mixed-scale comparisons.
- The USDT conversion happens once, at the transfer boundary.
- Floor and daily cap calculations use the WAD-scaled balance, consistent with the WAD tier percentages.

The scale conversion factor is `SCALE = 1e12` (WAD / USDT_DECIMALS = 1e18 / 1e6).

---

### Implementation Steps

**Step 1: Run existing tests to establish baseline**

```bash
cd /home/lever/Lever
forge build
forge test --match-path "test/InsuranceFund.t.sol" -v
forge test --match-path "test/integration/InsuranceBadDebt.t.sol" -v
forge test --match-path "test/audit/AuditFindings.t.sol" --match-test "LEVER003" -v
```

Record which tests pass and which fail.

---

**Step 2: Rewrite `absorbBadDebt` in InsuranceFund.sol with correct scale handling**

Add constant:
```solidity
uint256 public constant SCALE = 1e12;  // WAD / USDT = 1e18 / 1e6
```

Rewrite `absorbBadDebt`:

```solidity
function absorbBadDebt(bytes32 marketId, uint256 totalBadDebt)
    external override nonReentrant whenNotPaused
    returns (uint256 insurancePaid, uint256 remainder)
{
    if (
        !hasRole(EXECUTION_ENGINE_ROLE, msg.sender)
            && !hasRole(LIQUIDATION_ENGINE_ROLE, msg.sender)
            && !hasRole(SETTLEMENT_ENGINE_ROLE, msg.sender)
    ) {
        revert AccessControlUnauthorizedAccount(msg.sender, LIQUIDATION_ENGINE_ROLE);
    }

    if (totalBadDebt == 0) return (0, 0);

    // ── Scale _balance to WAD for all comparison math ──
    uint256 balanceWAD = _balance * SCALE;

    // 1. Reset daily window if expired
    if (block.timestamp >= _dailyWindowStart + DAILY_WINDOW) {
        _dailySpent = 0;
        _dailyWindowStart = block.timestamp;
        emit DailyCapReset(balanceWAD.wadMul(DAILY_CAP_PCT), block.timestamp);
    }

    // 2. Determine tier (insurance vs ADL split)
    uint256 ifr = _getIFR();
    uint256 insurancePct;
    if (ifr > TIER_1_THRESHOLD) {
        insurancePct = WAD; // 100% insurance
    } else if (ifr > TIER_2_THRESHOLD) {
        insurancePct = 7e17; // 70%
    } else if (ifr > TIER_3_THRESHOLD) {
        insurancePct = 4e17; // 40%
    } else {
        insurancePct = 1e17; // 10%
    }

    // 3. Insurance's share of bad debt (WAD scale throughout)
    uint256 insuranceTarget = totalBadDebt.wadMul(insurancePct);

    // 4. Apply daily cap constraint (all in WAD)
    uint256 dailyCap = balanceWAD.wadMul(DAILY_CAP_PCT);
    uint256 dailySpentWAD = _dailySpent * SCALE;
    uint256 dailyRemaining = dailyCap > dailySpentWAD ? dailyCap - dailySpentWAD : 0;
    if (insuranceTarget > dailyRemaining) {
        insuranceTarget = dailyRemaining;
    }

    // 5. Apply floor constraint (fund cannot drop below 5% of TVL)
    uint256 tvl = leverVault.totalAssets();
    uint256 tvlWAD = tvl * SCALE;
    uint256 floor = tvlWAD.wadMul(IFR_FLOOR);
    uint256 maxSpend = balanceWAD > floor ? balanceWAD - floor : 0;
    if (insuranceTarget > maxSpend) {
        insuranceTarget = maxSpend;
    }

    // 6. Cannot spend more than balance
    if (insuranceTarget > balanceWAD) {
        insuranceTarget = balanceWAD;
    }

    // 7. Final amounts (all WAD)
    insurancePaid = insuranceTarget;
    remainder = totalBadDebt > insurancePaid ? totalBadDebt - insurancePaid : 0;

    // 8. Convert to USDT for actual token operations
    uint256 transferUSDT = insurancePaid / SCALE;

    // 9. Update internal state (USDT scale)
    _balance -= transferUSDT;
    _dailySpent += transferUSDT;
    _totalAbsorbed += transferUSDT;

    // 10. Transfer USDT to caller
    if (transferUSDT > 0) {
        usdt.safeTransfer(msg.sender, transferUSDT);
    }

    emit BadDebtAbsorbed(marketId, totalBadDebt, insurancePaid, remainder, block.timestamp);

    return (insurancePaid, remainder);
}
```

Key changes:
- `balanceWAD = _balance * SCALE` at the top
- All comparisons are WAD vs WAD
- `_dailySpent` scaled to WAD for comparison, stored back in USDT
- `remainder = totalBadDebt - insurancePaid` is WAD minus WAD (correct)
- `transferUSDT = insurancePaid / SCALE` is the single conversion point
- Return values are all WAD (matches interface documentation)

---

**Step 3: Fix the view functions for consistency**

Update `getRemainingDailyCapacity`, `getFloor`, `getTarget` to return in the SAME scale
as the interface documents. Currently the interface does not specify scale for these, so
return USDT (since `getBalance()` returns USDT):

```solidity
function getRemainingDailyCapacity() external view override returns (uint256) {
    uint256 balanceWAD = _balance * SCALE;
    uint256 dailyCap = balanceWAD.wadMul(DAILY_CAP_PCT);
    uint256 spent;

    if (block.timestamp >= _dailyWindowStart + DAILY_WINDOW) {
        spent = 0;
    } else {
        spent = _dailySpent * SCALE;
    }

    uint256 remainingWAD = dailyCap > spent ? dailyCap - spent : 0;
    return remainingWAD / SCALE;  // return in USDT
}

function getFloor() external view override returns (uint256 floor) {
    uint256 tvl = leverVault.totalAssets();
    return tvl * IFR_FLOOR / WAD;  // simple percentage of USDT TVL, returns USDT
}

function getTarget() external view override returns (uint256 target) {
    uint256 tvl = leverVault.totalAssets();
    return tvl * IFR_TARGET / WAD;  // simple percentage of USDT TVL, returns USDT
}
```

`_getIFR()` is already correct: both `_balance` and `tvl` are USDT, so `wadDiv` produces
a correct WAD-scale ratio.

---

**Step 4: Delete InsuranceFundFixed.sol**

The "fixed" version has its own bugs (dailyCap/floor truncate to zero, missing role, missing
transfer). It should not exist as a potential source of confusion. Delete it.

---

**Step 5: Verify callers handle return values correctly**

After the fix, `absorbBadDebt` returns:
- `insurancePaid` in WAD (how much bad debt the fund covers)
- `remainder` in WAD (how much bad debt is left for ADL/socialization)

**ExecutionEngine.sol lines 365-368:**
```solidity
if (remainder > 0) {
    leverVault.socializeLoss(remainder);
}
```

`socializeLoss` adds `amount` to `_socializedLosses`, which is subtracted from `totalAssets()`.
`totalAssets()` returns `usdt.balanceOf(address(this)) - _netUnrealizedPnL - _socializedLosses`.
The USDT balance is 6-decimal. So `_socializedLosses` must also be 6-decimal (or at least
the same scale as balance).

**This means the caller (ExecutionEngine) must convert remainder from WAD to USDT before
passing to `socializeLoss`.** This is a ripple effect.

Same issue in SettlementEngine line 516: `leverVault.socializeLoss(remainder - totalWinnerPayout)`.

**Decision:** Two options:
- (A) Change `absorbBadDebt` to return USDT, update callers to not convert
- (B) Keep returning WAD, update callers to convert before socializeLoss

Option (B) is better because:
- ADL haircut calculation (SettlementEngine line 513) uses `remainder.wadDiv(totalWinnerPayout)`
  which requires WAD for both operands
- Only `socializeLoss` needs USDT, and the conversion is `/ SCALE`

BUILD must add `/ SCALE` before every `socializeLoss(remainder)` call:
- ExecutionEngine.sol line 367: `leverVault.socializeLoss(remainder / SCALE);`
  where `SCALE` is defined locally or read from InsuranceFund
- SettlementEngine.sol line 516: `leverVault.socializeLoss((remainder - totalWinnerPayout) / SCALE);`

Actually wait: `totalWinnerPayout` in SettlementEngine is computed from position PnL which is WAD.
The subtraction `remainder - totalWinnerPayout` is WAD minus WAD. OK. Then divide by SCALE for USDT.

But there is a subtlety: does `_netUnrealizedPnL` in LeverVault use WAD or USDT? BUILD must check
this before choosing the conversion strategy. If `_socializedLosses` is already tracked in WAD and
`totalAssets()` handles the conversion, then no caller changes are needed.

**BUILD must read LeverVault.sol thoroughly before deciding on caller changes.**

---

**Step 6: Update LeverageModel.sol workaround**

`LeverageModel.sol` lines 166 and 236 manually scale insurance balance:
```solidity
uint256 insuranceBalance = insuranceFund.getBalance() * USDT_DECIMALS_SCALE;
```

After this fix, `getBalance()` still returns USDT. So this workaround remains correct.
No change needed unless we change `getBalance()` to return WAD (which we should NOT do;
it is the actual token balance).

---

**Step 7: Write tests**

New file: `test/integration/InsuranceFundDecimals.t.sol`

**7a. `testAbsorbBadDebtScaleConsistency`**
- Bootstrap fund at $10,000 (10_000e6)
- Set TVL at $10M (10_000_000e6)
- Call absorbBadDebt with 1000e18 (WAD, $1000 bad debt)
- Verify: `insurancePaid + remainder == totalBadDebt` (both WAD)
- Verify: fund balance decreased by `insurancePaid / 1e12` USDT
- Verify: `remainder` is reasonable (not near 1e18 when insurance has funds)

**7b. `testDailyCapEnforced`**
- Bootstrap at $10,000
- Daily cap = 25% = $2,500
- Call absorbBadDebt with $5,000 (5000e18) at 100% tier (IFR > 15%)
- Verify: insurancePaid = 2500e18 (daily cap), not 5000e18
- Verify: balance decreased by $2,500 (2_500e6)

**7c. `testFloorEnforced`**
- Set TVL at $100,000 (100_000e6)
- Floor = 5% of TVL = $5,000
- Bootstrap at $6,000
- Max spend = $6,000 - $5,000 = $1,000
- Call absorbBadDebt with $3,000 bad debt
- Verify: insurancePaid <= 1000e18 (floor enforced)
- Verify: balance >= floor after absorption

**7d. `testRemainderDoesNotNukeVault`**
- Bootstrap at $10,000, TVL at $10M
- Call absorbBadDebt with $500 bad debt (500e18)
- Get back remainder
- Verify: remainder, when divided by SCALE, is a reasonable USDT amount
- Verify: socializeLoss with the converted remainder does not reduce totalAssets by more
  than the original bad debt dollar amount

**7e. `testDepositAndAbsorbRoundTrip`**
- Deposit $5,000 via FeeRouter (5_000e6 USDT)
- Verify balance = $15,000
- Absorb $2,000 bad debt
- Verify balance decreased by the correct USDT amount
- Verify no precision loss > 1 USDT ($1e6)

**7f. `testMixedScaleRegression`**
- Pure math test proving the old formula gives wrong results:
  - `insuranceTarget(WAD) > dailyCap(USDT)` is always true when it should not be
  - `remainder = badDebt(WAD) - paid(USDT)` ≈ badDebt (almost nothing subtracted)
- Assert the new formula gives correct results where old one does not

---

**Step 8: Run full test suite**

```bash
forge test -v 2>&1 | tee /tmp/test-results.txt
```

All tests must pass. Existing tests in `InsuranceFund.t.sol` and `InsuranceBadDebt.t.sol`
may need expected values updated if they relied on the buggy scale behavior.

---

### Files to Modify

- `contracts/InsuranceFund.sol`
  - Add `SCALE` constant
  - Rewrite `absorbBadDebt` (lines 115-192)
  - Fix `getRemainingDailyCapacity` (lines 242-256)
  - Fix `getFloor` (lines 259-262)
  - Fix `getTarget` (lines 265-268)

- `contracts/ExecutionEngine.sol`
  - Line 367: convert `remainder` to USDT before `socializeLoss` (pending LeverVault scale check)

- `contracts/SettlementEngine.sol`
  - Line 516: convert `remainder` to USDT before `socializeLoss` (pending LeverVault scale check)

### Files to Delete

- `contracts/InsuranceFundFixed.sol` — broken fix, source of confusion

### Files to Create

- `test/integration/InsuranceFundDecimals.t.sol` — 6 tests

### Files to Read First (BUILD must read all of these)

- `contracts/InsuranceFund.sol` — full file (the buggy contract)
- `contracts/InsuranceFundFixed.sol` — full file (understand what was attempted and why it fails)
- `contracts/ExecutionEngine.sol` lines 360-370 (absorbBadDebt caller)
- `contracts/SettlementEngine.sol` lines 490-523 (absorbBadDebt caller + socializeLoss)
- `contracts/LeverVault.sol` lines 128-136 (totalAssets), lines 329-336 (socializeLoss)
  — BUILD must determine the scale of `_socializedLosses` and `_netUnrealizedPnL`
- `contracts/LeverageModel.sol` lines 160-170, 230-240 (USDT_DECIMALS_SCALE workaround)
- `contracts/FeeRouter.sol` lines 125-135 (deposit pattern)
- `contracts/libraries/FixedPointMath.sol` lines 28-45 (wadMul, wadDiv formulas)
- `test/InsuranceFund.t.sol` — existing tests
- `test/integration/InsuranceBadDebt.t.sol` — existing integration tests

---

### Dependencies and Ripple Effects

- **FeeRouter:** Calls `deposit(amount)` with USDT amounts. `_balance += amount` is unchanged.
  No FeeRouter changes needed.

- **LeverageModel:** Uses `getBalance() * USDT_DECIMALS_SCALE` workaround. `getBalance()` still
  returns USDT. No LeverageModel changes needed.

- **ExecutionEngine/SettlementEngine:** Must convert WAD `remainder` to USDT before
  `socializeLoss()`. This is a 1-line change per file, but BUILD must verify the LeverVault
  scale assumptions first.

- **LeverVault.socializeLoss:** Adds to `_socializedLosses`, subtracted from `totalAssets()`.
  If `_socializedLosses` is in USDT (which it should be, since `totalAssets()` returns USDT
  balance), then the conversion is required. If somehow it is in WAD, the vault is already
  broken and needs separate fixing.

- **IInsuranceFund interface:** The NatSpec says `insurancePaid` and `remainder` are WAD.
  After this fix, they actually ARE WAD. No interface change needed, just documentation alignment.

- **Events:** `BadDebtAbsorbed` will emit WAD values for `insurancePaid` and `remainder` (correct),
  USDT for `totalBadDebt` would be wrong — wait, `totalBadDebt` is the input parameter which is WAD.
  All event values will be WAD. This is correct and consistent.

---

### Edge Cases

**Zero balance:** If `_balance == 0`, then `balanceWAD = 0`, `dailyCap = 0`, `maxSpend = 0`,
`insurancePaid = 0`, `remainder = totalBadDebt`. Everything passes to ADL/socialization. Correct.

**Very small bad debt (dust):** If `totalBadDebt < SCALE` (less than 1 USDT in WAD), then
`transferUSDT = insurancePaid / SCALE` could round to 0. The fund's internal `_balance` would
not decrease, but WAD-scale `insurancePaid` would show a payout was made. This is acceptable
for sub-penny amounts. If this precision is unacceptable, add a check:
`if (transferUSDT == 0 && insurancePaid > 0) { insurancePaid = 0; remainder = totalBadDebt; }`

**Daily cap across multiple events:** `_dailySpent` is in USDT. Scaled to WAD for comparison.
After N absorptions in one day, `_dailySpent * SCALE` should not overflow. Maximum:
`_dailySpent` could be the entire balance (at most ~1e12 for a $1M fund). `1e12 * 1e12 = 1e24`.
Well within uint256 range.

**Bootstrap without token transfer (LESSONS.md):** The constructor sets `_balance = INSURANCE_BOOTSTRAP`
but does NOT transfer USDT. The real USDT balance is 0 at deploy. This is a KNOWN ISSUE (LESSONS.md
line 82-83). The fix plan does NOT address this because the bootstrap is a one-time operation and the
deployment script is responsible for the initial token transfer. BUILD should verify the deploy script
pairs the bootstrap with an actual USDT transfer.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `testAbsorbBadDebtScaleConsistency` | insurancePaid + remainder = totalBadDebt in WAD |
| `testDailyCapEnforced` | Daily cap correctly limits WAD-scale payout |
| `testFloorEnforced` | Floor prevents fund from dropping below 5% TVL |
| `testRemainderDoesNotNukeVault` | socializeLoss receives USDT-scale, not WAD-scale |
| `testDepositAndAbsorbRoundTrip` | USDT deposits and WAD absorptions interoperate correctly |
| `testMixedScaleRegression` | Old formula provably gives wrong results |

---

### Effort Estimate

**Medium** — 4-6 hours.
- Rewrite absorbBadDebt: 1-2 hours (careful scale reasoning)
- Fix view functions: 30 minutes
- Caller updates (ExecutionEngine, SettlementEngine): 1 hour (requires LeverVault scale audit)
- Delete InsuranceFundFixed: 5 minutes
- Write 6 tests: 2 hours
- Full test suite pass: 30 minutes

---

### Rollback Plan

Revert InsuranceFund.sol to current version. The current version "works" in the sense that:
- The daily cap clamp accidentally produces USDT-scale `insurancePaid`
- The `safeTransfer` sends valid USDT
- The remainder is wrong but may not have caused visible damage yet (depends on whether
  `socializeLoss` has been called with garbage values)

If rollback is needed, also revert the caller changes (ExecutionEngine, SettlementEngine).

---

### Open Questions

1. **LeverVault `_socializedLosses` scale:** BUILD must verify what scale this uses before
   deciding how to convert `remainder` at the caller sites. If it is already WAD, the callers
   do NOT need conversion (only the safeTransfer inside InsuranceFund needs it). Read
   `LeverVault.sol` lines 128-136 and all places that modify `_socializedLosses`.

2. **Bootstrap token transfer:** Should the constructor stop setting `_balance = INSURANCE_BOOTSTRAP`
   (phantom balance with no backing tokens)? Or should this plan include a deploy script fix?
   Recommend: leave constructor as-is, but document that deploy script MUST transfer 10_000e6 USDT
   to the InsuranceFund address after deployment.

---

### KANBAN Update

Move LEVER-BUG-5 to PLANNED.
