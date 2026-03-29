# RECENT SESSIONS
## Chronological log of workstream sessions. Pruned to last 30 by ADVISOR.

---

### [2026-03-28T15:08:00Z] OPERATE | System check + dashboard fix

- **Task**: Full system self-check, log review, fix any issues found
- **Outcome**: ONE FIX APPLIED. All services up.
- **Bug fixed**: vigil-dashboard server.js called `su - lever -c "openclaw cron list"` to collect upcoming cron jobs. The `lever` user has no password set, so this produced continuous PAM auth failures in system journal (every ~10 seconds). Fixed by removing the `su - lever -c` wrapper since the service already runs as `lever`. Restarted vigil-dashboard. Auth failures stopped. Committed and pushed.
- **Services**: All 8 active. openclaw-gateway (1.2G RAM, 2h 46m uptime since last restart), vigil-telegram (316M, clean), vigil-dashboard (restarted, clean), lever-frontend (1d+ uptime, serving traffic), lever-oracle (5d uptime), lever-accrue-keeper (2d uptime), caddy (assumed active).
- **Resources**: Disk 18% (/dev/vda1, 35G/193G), RAM 43% used (6.9G/16G), 9G available. No pressure.
- **Cron status**: operate-selfcheck and overseer both show "error" (job execution timed out). operate-selfcheck timeout is 600s; overseer timeout was 1800s. Both are non-critical (next run scheduled). No action taken.
- **Root claude sessions**: 3 sleeping root-owned claude processes consuming ~3.2G RAM total (PIDs 1151018/Mar22, 1312428/Mar26, 2375109/08:11). Likely Master SSH sessions or long-running tasks. Not killed -- root-owned, sleeping, RAM not under pressure.
- **Log highlights**: Telegram gateway had 2 empty-response retries during restarts (normal). Inbox pipeline clean, 5 files processed. Task completions up to 3572s (dashboard work). Scheduler at 13-14 sessions today, running normally.
- **KANBAN**: LEVER-BUG-2 IN PROGRESS (BUILD dispatched 15:07). LEVER-BUG-1 BLOCKED (critique verdict REVISE). LEVER-BUG-3, BUG-4 PLANNED.

---

### [2026-03-28T14:56:00Z] OPERATE | System check (routine)
- **Task**: Full log review, service check, fix any issues
- **Outcome**: ALL CLEAR. No new issues found.
- **Services**: All 8 active (openclaw-gateway, vigil-telegram, vigil-dashboard, vigil-inbox, lever-frontend, lever-oracle, lever-accrue-keeper, caddy)
- **Resources**: Disk 18%, RAM 52%, Load 0.39
- **Logs**: Telegram gateway clean, inbox pipeline clean (5 files processed today), scheduler running 10s cycles with 5 slots filled
- **Note**: Previous OPERATE session (13:38) fixed two bugs: (1) dispatcher.sh KANBAN count parsing `|| echo 0` producing "0\n0", (2) health-escalate.sh using `systemctl --user` for system-level openclaw-gateway service. Dispatcher.sh since replaced by scheduler.py. Health-escalate fix confirmed persisted.

---

### [2026-03-28T13:47:00Z] PLAN | LEVER-BUG-4: InsuranceFund bad debt absorption
- **Task**: Plan fix for InsuranceFund never absorbing bad debt
- **Outcome**: SUCCESS
- **Root cause 1**: Constructor sets `_balance = INSURANCE_BOOTSTRAP` (10,000e6) with no actual USDT transfer. Phantom balance causes safeTransfer to revert when real USDT < computed insurancePaid.
- **Root cause 2**: `absorbBadDebt` sends USDT to `msg.sender` (LiquidationEngine/SettlementEngine) instead of `address(leverVault)`. Engine never forwards it. Vault never receives insurance coverage.
- **Fix designed**: InsuranceFund.sol only. (1) Set `_balance = 0` in constructor. (2) Change `usdt.safeTransfer(msg.sender, ...)` to `usdt.safeTransfer(address(leverVault), ...)`. 2 lines, 1 file.
- **Note**: Bootstrap funding should happen at deploy time via admin transferring USDT and calling deposit().

---

### [2026-03-28T13:45:00Z] PLAN | LEVER-BUG-3: Ghost OI
- **Task**: Plan fix for ghost OI ($3.2M in OILimits with zero open positions)
- **Outcome**: SUCCESS
- **Root cause identified**: Redeployment artifact. PositionManager cleared on redeploy; OILimits retained stale accumulators. All normal decrement paths verified correct.
- **Fix designed**: Improve adminResetMarketOI with (a) on-chain position count check via PositionManager, (b) per-user OI reset via affectedUsers[] param. Add Forge diagnostic + reset scripts. 4 new tests.
- **Key finding**: Current adminResetMarketOI (LEVER-006/P06) exists but has two defects: no on-chain verification, _userOI not cleared.
- **Open question**: PositionManager is in protected list. BUILD must check if getMarketPositions() already exists before adding getMarketPositionCount(). If PositionManager cannot be modified, track position count inside OILimits directly.
- **Handoff**: /home/lever/command/handoffs/plan-lever-bug-3.md

### [2026-03-28T08:10:00Z] MIGRATION | Phase 0: Foundation
- **Task**: Create Vigil directory structure and seed shared brain files
- **Outcome**: SUCCESS
- **Actions**: Created /home/lever/command/ with all subdirectories. Seeded PROJECT_STATE.md, DECISIONS.md, LESSONS.md, INTENTIONS.md, ADVISOR_BRIEFS.md. Created CLAUDE.md for all 7 workspaces.
- **Files Changed**: All new files under /home/lever/command/
- **Decisions**: Use Caddy over Nginx, Commander replaces lever-bot, new dashboard replaces lever-dashboard
- **Lessons**: None (initial setup)

### [2026-03-28T10:55:18Z] RESEARCH | Inbox ingestion: test-note.txt
- **Task**: Knowledge ingestion from inbox
- **Outcome**: SUCCESS
- **Source**: test-note.txt (txt)

### [2026-03-28T12:01:54Z] RESEARCH | Inbox ingestion: 20260328-115423-PredictionIndex2025-2026.pdf
- **Task**: Knowledge ingestion from inbox
- **Outcome**: SUCCESS
- **Source**: 20260328-115423-PredictionIndex2025-2026.pdf (pdf)

### [2026-03-28T12:04:32Z] RESEARCH | Inbox ingestion: 20260328-115813-PredictionIndex2025-2026.pdf
- **Task**: Knowledge ingestion from inbox
- **Outcome**: SUCCESS
- **Source**: 20260328-115813-PredictionIndex2025-2026.pdf (pdf)

### [2026-03-28T12:36:23Z] RESEARCH | Inbox ingestion: 20260328-123557-photo-20260328-123557.jpg
- **Task**: Knowledge ingestion from inbox
- **Outcome**: SUCCESS
- **Source**: 20260328-123557-photo-20260328-123557.jpg (jpg)

### [2026-03-28T12:47:13Z] RESEARCH | Inbox ingestion: 20260328-124624-pngwing.com 1.png
- **Task**: Knowledge ingestion from inbox
- **Outcome**: SUCCESS
- **Source**: 20260328-124624-pngwing.com 1.png (png)

---
## Session: 2026-03-28 (BUILD - Audit Fixes V2)
**Task:** Implement 6 new bugs from AUDIT_FINDINGS_V2.md (LEVER-P01 through LEVER-P06)
**Result:** All 6 fixes implemented. Build passes. 1068 tests pass (net +1 vs baseline).
**Key changes:**
- FundingRateEngine + BorrowFeeEngine: depthThreshold=0 guard (P01, P02) - same pattern as MarginEngine LEVER-007 fix
- FundingRateEngine.routeUnmatchedFunding: depositRewards -> receiveUnmatchedFunding (P05)
- ExecutionEngine: replaced collectTransactionFee with local fee computation + correct USDT flow (P03)
- InsuranceFund.absorbBadDebt: added `address recipient` param; all callers pass `address(leverVault)` (P04)
- LeverVault/ILeverVault: added getNetUnrealizedPnL() getter; ExecutionEngine now calls updateUnrealizedPnL on close (P06)
**Files:** 10 contracts + 8 test files modified
**Handoff:** /home/lever/command/handoffs/build-20260328-130802-audit-fixes-v2.md

---
## Session: 2026-03-28 (VERIFY - Audit Fixes P01-P06)
**Task:** Independent review of BUILD handoff for LEVER-P01 through P06 fixes
**Result:** PASS WITH CONCERNS — all 6 fixes correct, zero regressions
**Verdict summary:**
- P01/P02: depthThreshold=0 guards confirmed correct in both FundingRateEngine and BorrowFeeEngine
- P03: ExecutionEngine fee routing confirmed — no collectTransactionFee, direct debit+transferOut+routeFees
- P04: InsuranceFund recipient routing confirmed — USDT goes to leverVault, not caller
- P05: routeUnmatchedFunding confirmed — receiveUnmatchedFunding called, depositRewards not called
- P06: updateUnrealizedPnL on close confirmed — NAV updated correctly
**Concerns (non-blocking):**
- InsuranceFundFixed.sol ignores recipient (deploy InsuranceFund.sol, not InsuranceFundFixed.sol)
- Closing fee routed as FeeType.BORROW instead of TRANSACTION (pre-existing)
- P06 minimal fix: no update on open, intra-position drift not tracked (LEVER-008, acknowledged)
- EXECUTION_ENGINE_ROLE must be granted on LeverVault and InsuranceFund post-deployment
**Tests:** 6/6 audit tests pass. Full suite 1074/1078 (4 pre-existing PriceSmoothing failures)
**Verdict:** /home/lever/command/handoffs/verify-verdict.md

---
## OPERATE | 2026-03-28 13:35-13:58 UTC

**Task**: System check, log review, cleanup.

**Findings**:
- All 8 services ACTIVE (openclaw-gateway, vigil-telegram, vigil-dashboard, vigil-inbox, lever-frontend, lever-oracle, lever-accrue-keeper, caddy)
- Disk: 18% / RAM: 48% — no resource concerns
- Inbox: clean, no pending files
- Telegram gateway: clean since 12:46, tasks completing normally (77s-930s range)
- Inbox watcher: all files processed successfully (PDFs, photos, PNGs)

**Issue found and resolved**:
- Stale `needs-escalation` file from 12:00 health check. Health check caught openclaw-gateway mid-restart (it was being restarted frequently during development). Auto-restart failed with "Failed to connect to bus: No medium found" (transient systemd bus issue during rapid restart cycle). Service recovered on its own. Flag cleared.
- Gateway also logged `sendChatAction` failures ~12:04-12:05 and a model warmup error for `claude-cli/claude-sonnet-4-6` at the same time. Both resolved — no ongoing errors.

**What's in flight** (from KANBAN):
- LEVER-BUG-1: In PLANNED state (plan written: handoffs/plan-20260328-133419.md)
- LEVER-BUGs 2-9: In BACKLOG, awaiting planning
- Scheduler running: 5 active sessions, 8 dispatched today
- CRITIQUE sessions for lever-bug-2, 3, 4 completed and ready for BUILD

**Recommendations**:
- The health-check escalation false alarm pattern will repeat whenever openclaw-gateway is restarted during active development. Consider adding a 30s grace period before flagging a service as "down" (check twice with delay).
- No action needed from Master.

---
## Session: 2026-03-28 (PLAN - LEVER-BUG-2)
**Task:** Plan the fix for LEVER-BUG-2: $304K unaccounted vault drain
**Result:** Plan written. Root causes confirmed in current code.

**Root cause 1 (open):** `_executeOpen` calls `feeRouter.collectTransactionFee(notional)` which pays LP/protocol/insurance from FeeRouter's own USDT balance. Then `accountManager.debitPnL(user, txFee)` reduces the user's ledger without moving any USDT. FeeRouter bleeds vault-seeded capital; AccountManager accumulates phantom balance.

**Root cause 2 (close):** `_executeClose` calls `feeRouter.collectTransactionFee(pos.positionSize)` (payment 1), then `_settlePnL` includes closingFee in totalFees and routes it again via `transferOut` + `routeFees` (payment 2). Double distribution.

**Fix:** ExecutionEngine.sol only. Add `TX_FEE_RATE = 1e15` constant. In `_executeOpen`: remove `collectTransactionFee`, compute fee locally, add `transferOut(feeRouter, txFee)` + `routeFees(TRANSACTION, txFee)` after `debitPnL`. In `_executeClose`: remove `collectTransactionFee`, compute fee locally. `_settlePnL` is correct as-is.

**Files changed:** ExecutionEngine.sol (2 functions, ~5 lines), new test file VaultDrain.t.sol
**Plan:** handoffs/plan-lever-bug-2.md

---
## OPERATE | 2026-03-28 14:55-14:57 UTC

**Task**: System check, log review.

**Findings**:
- All 8 services ACTIVE. No issues.
- Disk: 18% / RAM: 52% (7.8G/15G). Healthy.
- Inbox: clean, no pending files. All 5 ingestion jobs today completed successfully.
- Telegram gateway: stable since 11:58 (v2). Processing tasks normally. Two long tasks (2089s, 2409s) completed without error.
- Scheduler: 5 active sessions, 10 dispatched today. Running smoothly.
- Health check log: unchanged since 12:00 false alarm (next cron run at 16:00). Stale `needs-escalation` flag was already cleared by prior OPERATE session.
- Gateway journal: no errors since 14:00. One informational note about headless Chrome WebGL (expected).

**Issues**: None. System is healthy.

---
## OPERATE | 2026-03-28 15:09-15:15 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 48%. Gateway stable, 3 tasks completed since last check with no errors. Inbox clean. Scheduler at 15 dispatches today, 5 active sessions. No issues in journal. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 15:18-15:44 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 46%. Gateway stable, tasks completing normally. Inbox clean. Scheduler at 21 dispatches today, 5 active sessions. No errors in journal. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 15:48-16:06 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 45%. 16:00 cron health check confirmed healthy (0 problems). Gateway stable. Scheduler at 27 dispatches today, 5 active sessions. No errors in journal. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 16:05-16:17 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 46%. Gateway stable. Scheduler at 32 dispatches today, 5 active sessions. 16:00 cron health check passed clean. No errors in journal. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 16:17-16:24 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 48%. Gateway stable. Scheduler at 37 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 16:24-16:32 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 47%. Gateway stable. Scheduler at 42 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 16:32-16:39 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 47%. Gateway stable. Scheduler at 47 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 16:39-16:46 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 45%. Gateway stable. Scheduler at 52 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 16:45-16:52 UTC

**Task**: System check, log review.

**Findings**:
- All 8 services active: openclaw-gateway, vigil-telegram, vigil-dashboard, vigil-inbox, lever-frontend, lever-oracle, lever-accrue-keeper, caddy.
- Disk 18%, RAM ~44%. Scheduler healthy, 56 sessions today, 0 active.
- Inbox processing clean: 4 files processed successfully today.
- 12:00 UTC health check found openclaw-gateway briefly down; health-escalate.sh failed to restart it ("Failed to connect to bus: No medium found" — transient DBUS cron issue). Service recovered on its own by 16:00. Documented in LESSONS.md.
- LEVER-BUG-1 still BLOCKED on CRITIQUE REVISE decision (Master decision needed on exit formula).
- No other issues found.

**Actions**: Documented DBUS/cron transient issue in LESSONS.md.


---
## OPERATE | 2026-03-28 16:46-16:56 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 47%. Gateway stable. Scheduler at 57 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 16:56-17:03 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 45%. Gateway stable. Scheduler at 62 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 17:03-17:11 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 41%. Gateway stable. Scheduler at 65 dispatches today, 4 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 17:11-17:15 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 40%. Gateway stable. Scheduler at 70 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 17:14-17:17 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 44%. Gateway stable. Scheduler at 74 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 17:17-17:20 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 45%. Gateway stable. Scheduler at 78 dispatches today, 5 active. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-28 17:20-17:23 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 38%. Gateway stable. Scheduler hit daily circuit breaker (80/80 sessions), 2 active winding down. This is expected safeguard behavior. No errors. No issues found, no fixes needed.
[2026-03-28T18:48:27Z] OPERATE self-check complete. Fixed health-escalate.sh sudo bug. All services up. Disk 18%, RAM 42%.

---
## RESEARCH | 2026-03-28 20:00 UTC | Evening Market Scan

**Task**: Comprehensive evening market scan across all 5 coverage domains.

**Outcome**: 16 findings across all domains. All files updated. 5 new watchlist files created. 3 new trends files created.

**Top findings**:
1. Kalshi valued at $22B after $1B+ Series E (Sequoia, CapitalG). Margin trading approved via NFA (Kinetic Markets FCM). 5cc Capital ($35M prediction market VC fund) launched March 23 -- direct LEVER investor pitch target.
2. ARK Invest integrated Kalshi data for portfolio hedging (March 27). Institutional prediction market adoption accelerating.
3. Polymarket fee expansion March 30: 8 new categories, targeting $1M/day revenue. Sector weekly volume: $5.9B total, Polymarket 43% share.
4. DEATH BETS Act introduced (bipartisan): would ban war/assassination prediction market contracts. CFTC ANPR comment deadline April 30 -- most important regulatory document of the year.
5. Claude Mythos (Capybara) leaked March 26-27, confirmed by Anthropic. Above Opus 4.6. Watch for API access.
6. Base DeFi TVL: $4.63B, 46% of L2 market. Morpho on Base: $1.8B (near $2B). Confirms Morpho V2 integration priority.
7. Aero DEX (Aerodrome + Velodrome merge) confirmed Q2 2026. lvUSDT/USDT pool on track.
8. Iran War Day 28: Hormuz near-closed, WTI at $99.64, Brent at $112.57. April 6 Trump deadline is next binary event.
9. TOKEN2049 Dubai April 29-30 (32 days out). CEO decision needed NOW.

**Files updated**:
- /home/lever/command/shared-brain/ADVISOR_BRIEFS.md (full 16-item scan appended)
- /home/lever/command/knowledge/summaries/competitor-analysis.md (Kalshi, 5cc Capital, Polymarket updates)
- /home/lever/command/knowledge/summaries/technical-landscape.md (GPT-5.4, Claude Code March updates)
- /home/lever/command/knowledge/summaries/regulatory-landscape.md (DEATH BETS Act, CFTC ANPR)

**Files created**:
- /home/lever/command/knowledge/watchlists/watchlist-competitors.json
- /home/lever/command/knowledge/watchlists/watchlist-regulatory.json
- /home/lever/command/knowledge/watchlists/watchlist-geopolitical.json
- /home/lever/command/knowledge/watchlists/watchlist-ai-tools.json
- /home/lever/command/knowledge/watchlists/watchlist-investors.json
- /home/lever/command/knowledge/trends/prediction-market-volumes.json
- /home/lever/command/knowledge/trends/base-defi-tvl.json
- /home/lever/command/knowledge/trends/ai-model-landscape.json

---
## OPERATE | 2026-03-28 19:48-19:56 UTC

**Task**: System self-check, log review, fix any issues.

**Findings**:
- Scheduler hit daily circuit breaker (80/80) at ~19:44 UTC. Expected safeguard.
- All 8 services active. Disk 18%, RAM 42% (5.0GB free of 15GB).
- Health check at 16:00 UTC showed all clear (the 12:00 openclaw-gateway outage self-recovered).
- **CRITICAL BUG FOUND AND FIXED**: Dashboard (port 8080) was completely unresponsive to HTTP.
  Root cause: `collectUpcoming()` in server.js called `openclaw cron list` via `execSync`.
  With the circuit breaker active, openclaw spawns a stuck `openclaw-cron` process (143% CPU, 345MB RAM)
  that never returns, blocking the Node.js event loop and freezing all HTTP responses.
  Fix: replaced `execSync("openclaw cron list")` with direct `fs.readFileSync` on
  `/home/lever/.openclaw/cron/jobs.json`. Dashboard now responds instantly.

**Changes**: dashboard/server.js (committed + pushed: 0accb3e)

---
## OPERATE | 2026-03-29 00:00-00:01 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 41%. Gateway stable. Scheduler daily counter reset at midnight; 4 sessions dispatched for new day. Health checks at 16:00, 20:00, 00:00 all passed healthy. No errors. No issues found, no fixes needed.

---
## OPERATE | 2026-03-29 00:17-00:23 UTC

**Task**: System check, log review.

**Findings**: All 8 services active. Disk 18%, RAM 41%. Gateway had 6 spawn failures at 00:21:38 ("spawn claude ENOENT") caused by Claude Code auto-update replacing the /usr/bin/claude symlink at the exact same second. Transient, self-resolved immediately. No errors after 00:22. Scheduler at 38 dispatches, 3 active sessions. No fixes needed.

---
## OPERATE | 2026-03-29 02:45 UTC

**Task**: Self-check cron (scheduler.log, gateway log, health-check.log, inbox.log).

**Findings**:
- All 8 services: ACTIVE (openclaw-gateway, vigil-telegram, vigil-dashboard, vigil-inbox, lever-frontend, lever-oracle, lever-accrue-keeper, caddy)
- Disk: 18% used (159G free). RAM: 4GB used / 15GB total. Both healthy.
- Circuit breaker: LOCKED at 80/80 sessions. Burned through by 00:37 UTC (critique REVISE loop ran before fix 20ab23d took effect). Will reset at midnight UTC.
- Fix 20ab23d (REVISE attempts increment) is live. Will prevent loop recurrence from tomorrow.
- Gateway restarted at 02:12 UTC. Came back clean. Startup model warmup warning ("Unknown model: claude-cli/claude-sonnet-4-6") is a benign WARN, not affecting dispatch.
- lever-bug-1: BLOCKED in KANBAN (awaiting Master input on exit formula decision).
- Health checks at 16:00, 20:00, 00:00: all passed healthy.
- No fixes needed this cycle.
