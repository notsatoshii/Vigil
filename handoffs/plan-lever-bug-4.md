# Plan: LEVER-BUG-4 - InsuranceFund Never Absorbs Bad Debt
## Date: 2026-03-28T13:46Z
## Requested by: Master (via Commander)

---

### Problem Statement

InsuranceFund.absorbBadDebt() has two compounding defects that together mean insurance
coverage NEVER reaches the vault:

**Defect 1 -- Phantom bootstrap balance (the "never transfers" part)**
The constructor sets `_balance = INSURANCE_BOOTSTRAP` (10,000e6) but transfers zero
actual USDT into the contract. FeeRouter uses a push-then-notify pattern: it transfers
USDT first, then calls `deposit()`. So real USDT deposits track correctly. But the 10K
phantom creates a persistent gap: `_balance` always overstates actual USDT by 10,000e6.

Result: early in the protocol (or when fees are small), `absorbBadDebt` computes
`insurancePaid` from an inflated `_balance`, tries to `safeTransfer` more USDT than
the contract holds, and REVERTS. Insurance absorbs nothing.

**Defect 2 -- Wrong transfer recipient (the "never covers the vault" part)**
Even if the transfer succeeds, line 186 sends to `msg.sender`:

```solidity
usdt.safeTransfer(msg.sender, insurancePaid);
```

msg.sender is LiquidationEngine or SettlementEngine. Neither engine has any code to
forward that USDT. It sits in the engine contract unused. LeverVault (the LP pool that
actually suffered the shortfall) receives nothing from insurance.

The vault only receives the trader's collateral from `_closeAndSettle`. The bad debt
shortfall -- the portion beyond collateral -- is never covered by insurance. `socializeLoss`
is then called for the remainder, but that is a NAV haircut, not real USDT recovery.

Net effect: insurance accounting says it absorbed bad debt, but the vault never gets the
USDT. The fund bleeds phantom coverage while LPs absorb the full real loss.

---

### Correct Behaviour

Per the whitepaper and ARCHITECTURE.md:
- InsuranceFund holds USDT (funded by 20% of protocol fees via FeeRouter)
- On bad debt: insurance sends USDT directly to LeverVault to partially cover the shortfall
- Remainder is socialized via `leverVault.socializeLoss()` (NAV reduction, no USDT)
- `insurancePaid + socializedAmount = totalBadDebt`

---

### Approach

Two targeted one-line fixes in `InsuranceFund.sol` only. No other contract changes needed.

1. **Constructor**: set `_balance = 0`. The fund starts empty; real USDT only enters via
   FeeRouter deposits. Spec says "bootstrapped at $10,000 at launch" -- this is a deployment
   concern handled by the deploy script (admin transfers 10K USDT and calls deposit), not
   baked into the constructor with phantom accounting.

2. **absorbBadDebt**: change transfer recipient from `msg.sender` to `address(leverVault)`.
   Insurance USDT goes directly to the vault, which is the correct bad-debt absorber.

---

### Implementation Steps

1. **InsuranceFund.sol, constructor (line 94)**:
   Remove: `_balance = INSURANCE_BOOTSTRAP;`
   Add:    `_balance = 0;`

2. **InsuranceFund.sol, absorbBadDebt (line 186)**:
   Remove: `usdt.safeTransfer(msg.sender, insurancePaid);`
   Add:    `usdt.safeTransfer(address(leverVault), insurancePaid);`

That is the complete implementation. Two lines changed, one file.

---

### Files to Modify

- `contracts/InsuranceFund.sol`: two one-line changes (constructor L94, absorbBadDebt L186)

### Files to Create

None.

---

### Dependencies and Ripple Effects

- `LiquidationEngine._handleBadDebt`: calls `absorbBadDebt` and calls `socializeLoss`
  for the remainder. No change needed. The engine correctly ignores the return value
  for the USDT -- insurance now goes directly to vault as intended.

- `SettlementEngine`: same pattern. No change needed.

- `FeeRouter.routeFees` and `collectTransactionFee`: already do push-then-notify
  correctly (`safeTransfer` then `insuranceFund.deposit()`). No change needed.

- `LeverVault.totalAssets()`: will now correctly reflect insurance deposits as they
  arrive when bad debt is absorbed (USDT increases vault balance, which feeds NAV).

- **Deploy script**: when deploying InsuranceFund, the admin should transfer 10,000 USDT
  to the contract and call `deposit(10_000e6)` to bootstrap it properly. This is a
  deployment step, not a contract change.

---

### Edge Cases

- **absorbBadDebt called before any fees deposit**: `_balance = 0`, so `insurancePaid = 0`,
  `remainder = totalBadDebt`. No transfer attempted. Correct.

- **absorbBadDebt pays partial amount**: vault receives some USDT, `socializeLoss` handles
  rest. Both are correct.

- **leverVault address at zero**: constructor already guards against this (ZeroAddress check).

- **safeTransfer to leverVault when vault is paused**: USDT is a standard ERC-20, transfer
  does not depend on vault pause state. Not an issue.

---

### Test Plan

- **test_absorb_bad_debt_transfers_to_vault**: call absorbBadDebt, assert leverVault USDT
  balance increased by insurancePaid.

- **test_absorb_bad_debt_msg_sender_unchanged**: assert LiquidationEngine USDT balance
  did NOT increase after absorbBadDebt.

- **test_zero_bootstrap_balance**: assert `insuranceFund.getBalance() == 0` after
  construction with no deposit.

- **test_deposit_then_absorb**: deposit X USDT via FeeRouter, call absorbBadDebt for
  Y < X, assert vault received correct amount and `getBalance()` decreased by insurancePaid.

- **test_phantom_bootstrap_gone**: pre-existing tests that checked initial balance == 10_000e6
  need to be updated to expect 0.

---

### Effort Estimate

Small -- 2 lines changed in 1 file. Test updates for changed bootstrap expectation.
Under an hour of BUILD time.

---

### Rollback Plan

Both changes are in InsuranceFund.sol, which is NOT in the protected-contracts list. If
something goes wrong, redeploy InsuranceFund and re-grant roles (FEE_ROUTER_ROLE,
LIQUIDATION_ENGINE_ROLE, SETTLEMENT_ENGINE_ROLE) on the new instance. FeeRouter,
LiquidationEngine, and SettlementEngine hold the InsuranceFund address as an immutable,
so they would also need redeployment if InsuranceFund is redeployed.

However, given the change is surgical (2 lines, well-understood), risk of rollback is low.

---

### Open Questions

None. Root cause is clear. Fix is unambiguous.
