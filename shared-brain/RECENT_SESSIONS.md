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
