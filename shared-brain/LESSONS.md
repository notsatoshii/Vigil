# LESSONS LEARNED
## Pre-populated from existing system knowledge. Append new lessons at the bottom.

---

### Decimal Precision (CRITICAL, RECURRING)
formatUsdt() adds comma separators. parseFloat() stops at the first comma and silently truncates.
The correct pattern is Number(value)/1e6.
This is the number one recurring bug in the codebase.
Every workstream that touches code must check for this.

### CSP Tag Stripping (RECURRING)
After every frontend build, the CSP meta tag must be stripped from BOTH build/index.html and public/index.html.
Command: `sed -i 's/<meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests"\/>//' build/index.html`
Failure to do this causes mixed content errors in production.

### Role Hash Mismatch
AccountManager uses keccak256("ENGINE") not keccak256("ENGINE_ROLE").
Getting this wrong causes AccessControlUnauthorized reverts.

### Hardcoded Addresses
All contract addresses must come from deploy-env.sh.
Frontend has fallback addresses in src/config/contracts.ts (line ~142) that override deployment JSON if fetch fails.
Hardcoding addresses anywhere else leads to stale references after redeployment.

### Gas Limit on openPosition
openPosition requires ~980K gas. The demo wallet uses gas: 2000000n.
Using simulateContract instead of writeContract causes failures here.

### SettlementEngine Role Requirement
SettlementEngine needs LIQUIDATION_ENGINE_ROLE on the vault for socializeLoss().
Missing this role grant causes settlement to revert silently.

### Constructor Arg Ordering
LiquidationEngine constructor args were scrambled in initial deployment (March 20, 2026).
Always verify getter outputs match expected addresses after deployment.

### Telegram Bot 409 Conflict
Only one bot instance can poll a given Telegram bot token at a time.
Running two instances causes a 409 "terminated by other getUpdates request" error.
This happened on March 24 with lever-bot.

### Frontend Fallback Prices
update-fallback-prices.sh runs every 30 minutes to keep oracle fallback prices fresh.
If this stops, the frontend may show stale prices.

### Disabled Services Are Sacred
lever-loop, lever-qa, lever-seeder, lever-watchdog must NEVER be restarted.
These were disabled for a reason. Restarting them can cause cascading issues.

---

## Lessons Migrated from lever-protocol (2026-03-28)

### Compilation Does Not Mean Working
A contract that compiles has valid syntax. A contract that deploys has bytecode on-chain. Neither means users get correct results. Always verify end-to-end behavior with on-chain calls (`cast call`), not just build output.

### Forge Simulations Can Lie
Forge simulations fork the chain state. Hardcoded addresses pointing at empty code may behave differently in simulation vs broadcast. Always verify with real broadcast transactions before marking something done.

### Scripts Print What You Tell Them
The SeedTVL script once printed "40M TVL achieved" while pointing at a non-existent vault. Never trust script output alone. Always verify the claimed result on-chain independently.

### React SPAs Always Return HTTP 200
A React SPA serves a static HTML shell regardless of whether the app renders correctly. A black screen returns 200. Use headless browser testing (Playwright or Puppeteer) to verify actual rendered content, not curl/HTTP status checks.

### Never Mark Stuck Tasks as Done
Downstream tasks assume previous tasks work. One fake completion cascades into system-wide failures. If a task is stuck after 3 attempts, log the full error and move on without marking it complete.

### Wrong Role for Admin Functions
Oracle smoothing tests were using the KEEPER role instead of ADMIN for `updateSmoothingParams()`. High leverage tests expected 30x but system max was 12x. Always verify which role a function requires and what the actual parameter bounds are before writing tests.

### Funding Rate Engine Requires Index Initialization
`FundingRateEngine.getCurrentFundingRate()` reverted because markets needed funding indices initialized via `initializeMarketIndex()`. Also, the function was called by the wrong name in tests (`getFundingRate` vs `getCurrentFundingRate`). Always check exact function signatures.

### Depth Thresholds Must Match Oracle Scale
Leverage calculations crushed all positions to 1x because depth thresholds were set to 1000x while actual oracle depths were around 1.0. Risk parameters must be calibrated to realistic values for the data they reference.

### OI/TVL Mismatch from Orphaned Positions
After a vault redeployment, 36 orphaned positions remained from the old vault, causing 441% utilization. After any redeployment, force-close or zero out stale positions and OI before the system can function correctly.

### deposit() Without Transfer Inflates Balance
`BoostInsuranceFund.s.sol` called `insurance.deposit()` without first transferring USDT tokens, inflating the internal balance tracker to 5.011e24 while actual balance was 5e12. The correct pattern (used by FeeRouter) is `safeTransfer()` followed by `deposit()`. Always pair accounting updates with actual token transfers.

### PATH Must Be Set for Foundry Tools in Scripts
Health check scripts silently failed all contract calls because `cast` and `forge` were installed in `/home/lever/.foundry/bin/` but not on PATH during script execution. These failures were treated as "passed" tests, masking real issues. Always use full paths or explicitly set PATH in shell scripts that call external tools.

### Curl Cannot Test SPAs
QA scoring gave an artificially low 68/100 because it used curl to test a React SPA. Curl only sees the HTML shell, not JavaScript-rendered content. Replacing curl with Playwright browser automation raised the score to 80/100. Always use browser-based testing for SPAs.

### Oracle Single Point of Failure
Only 1 of 3 oracle price sources (CLOB Midpoint) returned accurate data. The Gamma API fallback returned 0.0 for all markets, and CLOB Orderbook returned static 0.5 due to empty books. If the primary source fails, the oracle provides invalid prices. Always validate that fallback sources actually return correct data, and add monitoring alerts for source failures.

### Env Vars Must Sync After Redeployment
After redeploying ExecutionEngine with a new LeverageModelFixed, the environment variable `LEVERAGE_MODEL` was not updated to match. ExecutionEngine used the correct address internally (immutable), but all scripts referencing `$LEVERAGE_MODEL` pointed to the old address. After any contract redeployment, immediately update `deploy-env.sh` and verify all references.

### Market Timestamp Misconfiguration Kills Leverage
A market with resolution timestamp of 384 (far in the past) caused the M_market adjustment factor to drop to 0.001, capping effective leverage at 1x despite a 19.45x platform ceiling. The math: `19.45 * R_adjusted * 0.001 = ~0.02`, which floors to 1x. Always verify market resolution timestamps are set to realistic future dates when registering markets.

### PnL Calculation: Entry Price Must Be the Execution Price (CRITICAL, from Master)
PnL = direction * (current_PI - entry_execution_price) * size.
The entry price stored on-chain must be the execution price (PI + impact adjustment from ExecutionEngine),
not the raw oracle PI at time of entry. The current PI from the oracle is the correct mark price.
The bug was that the code used raw PI at entry instead of the impact-adjusted execution price,
making every position appear profitable because the spread was not captured in the entry reference.
The whitepaper formula is correct. The implementation was reading the wrong value for entry.

### Health Escalation Script: "Failed to connect to bus: No medium found" (2026-03-28)
The health-escalate.sh cron job ran at 12:00 UTC and found openclaw-gateway down. When it tried
`sudo systemctl restart openclaw-gateway`, both the restart and the status check returned "Failed
to connect to bus: No medium found". This appears to be a transient DBUS environment issue in the
cron context (possibly dbus was momentarily unavailable or the service was in a broken state that
blocked systemctl). The service recovered on its own by the 16:00 health check. This was a
one-time event with no lasting impact. If this recurs, investigate whether DBUS_SYSTEM_BUS_ADDRESS
needs to be explicitly set in the crontab, or whether openclaw-gateway needs a service dependency
on dbus.

## 2026-03-29: systemctl DBUS failure in cron (FIXED)

**Symptom**: `health-escalate.sh` attempted service restarts during an outage (openclaw-gateway down 2026-03-28 12:00 UTC) but failed with "Failed to connect to bus: No medium found".

**Root cause**: Cron runs without a full user session, so DBUS_SYSTEM_BUS_ADDRESS is not set. `systemctl` needs this env var to connect to the system bus.

**Fix**: Added `export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket` at the top of `health-escalate.sh`. Committed in e204c5d.

**Watch for**: If a service goes down and cron tries to restart it, check health-check.log for "Restarting..." lines followed by success rather than DBUS errors.

---
[2026-03-29] CRITICAL BUG FIXED: Critique REVISE loop burned all 80 daily sessions.
Root cause: scheduler.py did not increment task.attempts on CRITIQUE REVISE result.
The 3-attempt circuit breaker only triggered on REJECT and VERIFY FAIL, not REVISE.
Fix: Added task.attempts += 1 on REVISE path. lever-bug-1 burned 20 critique cycles
(sessions #1,9,13,17,21,25,29,33,37,39,41,46,50,54,58,62,66,70,74,78) before the
daily 80-session limit halted all work.
lever-bug-1 is now BLOCKED: critique requires Master to confirm exit formula
(single-impact: raw PI exit vs double-impact: execution price both ends).
See critique-lever-bug-1.md for 3 blocking questions before BUILD can proceed.
