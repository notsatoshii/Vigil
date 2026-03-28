# RECENT SESSIONS
## Chronological log of workstream sessions. Pruned to last 30 by ADVISOR.

---

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
