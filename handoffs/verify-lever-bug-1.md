# VERIFY Verdict: LEVER-BUG-1
## Date: 2026-03-29T10:35:00Z
## Task: PnL formula mismatch (single-impact per LESSONS.md)
## Verdict: PASS WITH CONCERNS

---

## Summary

The core bug: PnL was computed as `(exitPI - entryPI) * size`, using raw oracle PI for both sides. This hid the entry execution spread, making every position appear to start at the oracle midpoint ("38 winners, 0 losers" symptom). The fix swaps `entryPI` to `entryPrice` (the execution price which includes market impact) in both ExecutionEngine and MarginEngine. Two one-word changes. 5 new regression tests + 6 updated test files, all pass. No regressions.

---

## Pass 1: Functional Verification

### Phase 2: ExecutionEngine PnL Fix (PASS)
`ExecutionEngine.sol:383`: `int256 pnl = _computePnL(pos.isLong, pi, pos.entryPrice, pos.positionSize);`
- `pi` = raw oracle PI at close (mark price). Correct exit reference.
- `pos.entryPrice` = execution price at open (PI + impact). Correct entry reference.
- Previously used `pos.entryPI` (raw oracle PI at open), which hid the spread.
- `_computePnL` parameters renamed from `exitPrice/entryPrice` to `exitMark/entryMark` for clarity. Cosmetic, no logic change.

### Phase 3: MarginEngine PnL Fix (PASS)
`MarginEngine.sol:370`: `int256 piDelta = int256(currentPI) - int256(pos.entryPrice);`
- Uses same formula as ExecutionEngine. Both engines now agree on PnL.
- This satisfies the LEVER-P06 ordering constraint: vault NAV tracking uses the same PnL computation as position close.

### SettlementEngine NOT Modified (CONFIRMED)
`SettlementEngine.sol:555`: Still uses `pos.entryPI`. Intentionally out of scope per handoff. At resolution (PI=0 or PI=1), the impact spread is negligible relative to the outcome. Master decision pending.

### PnLConsistency.t.sol (5/5 PASS)
| Test | What it proves |
|------|---------------|
| `roundTripPnLSingleImpact` | Flat market round-trip shows negative PnL (entry spread charged, not hidden) |
| `realizedMatchesUnrealized` | MarginEngine and ExecutionEngine PnL agree (P06 safe) |
| `regressionRawPIEntryWouldFail` | Pure math proof: single-impact != raw-both. Catches formula reversion |
| `winnersAndLosersBothExist` | PI up creates long winners + short losers (fixes the 38-0 symptom) |
| `longShortZeroSumSingleImpact` | Long shows entry spread cost on flat market; PnL < 0 |

### Updated Test Files (6/6 PASS)
| File | What changed |
|------|-------------|
| `AuditFindings.t.sol` | LEVER001 test: single-impact formula verified. Invariant updated (long+short not zero-sum). |
| `AuditNewFindings.t.sol` | P06 test: expected PnL uses `pos.entryPrice` |
| `ClosingFee.t.sol` | Breakeven assertion: user pays fees + entry spread (not just fees) |
| `VaultDrain.t.sol` | Accounting invariant includes vault USDT (entry spread flows to vault) |
| `UnrealizedPnL.t.sol` | Flat-market assertions: PnL is negative (entry spread visible), not zero |

---

## Pass 2: Visual/Design Verification

N/A. Contract-only change, no frontend modified.

---

## Pass 3: Data Verification

- `entryPrice` and `entryPI` are both `uint256` WAD-scale values stored in the Position struct. The swap is type-safe.
- `entryPrice` is always >= `entryPI` for longs (paid the ask) and always <= `entryPI` for shorts (paid the bid). The `_computeExecutionPrice` function applies impact in the correct direction.
- The spread cost is `|entryPrice - entryPI| * size / WAD`. For $5K notional with typical 2.5% impact, this is ~$125. Test 1 validates this is "significant (not just fees)".
- `_computePnL` function at line 591 uses `exitMark - entryMark` for longs, `entryMark - exitMark` for shorts. Both are WAD-scale. No precision issues.

---

## Test Results

```
PnLConsistency.t.sol:    5/5 PASS
All audit tests (9 suites): 44/44 PASS
Integration.t.sol:        2/2 PASS
Total: 51 pass, 0 fail
```

---

## Concerns (Non-Blocking)

### CONCERN 1: SettlementEngine uses entryPI (not entryPrice)
`SettlementEngine.sol:555` still uses `pos.entryPI`. At resolution (PI=0 or 1), the impact spread is small relative to the full outcome, so this is safe for demo. But it creates a PnL inconsistency between settlement and close paths. Master decision needed before modifying SettlementEngine.

### CONCERN 2: Existing positions shift equity on redeployment
When MarginEngine switches to `entryPrice`, existing positions' equity drops by the entry impact amount. With ~$4.3K OI and typical 1-2% impact, the shift is $43-$86. Positions near liquidation threshold could be unexpectedly liquidated. On testnet this is acceptable; on mainnet, a migration strategy would be needed.

### CONCERN 3: Phases 2+3 must deploy atomically
ExecutionEngine and MarginEngine must be redeployed together. If only one is updated, P06's `updateUnrealizedPnL` creates a systematic NAV error (realized PnL from one formula, unrealized from the other). The deployment checklist must enforce this.

---

## No Design Flaws Found

The single-impact formula (raw PI exit, execution price entry) is the correct interpretation of the whitepaper. The entry execution price captures the market impact cost, and using raw PI at exit means the trader is marked against the current oracle price. This matches LESSONS.md and Master's explicit direction.

---

## Decision

**PASS WITH CONCERNS** -- two one-word swaps correctly implement the single-impact PnL formula. 5 new regression tests + 6 updated test files all pass. 51 total tests, zero failures. No design flaws. Concerns are non-blocking: SettlementEngine consistency, existing position equity shift, and atomic deployment requirement.
