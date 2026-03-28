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
