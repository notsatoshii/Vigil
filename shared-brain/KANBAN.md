# KANBAN
## Task board for all workstreams. Read by Commander before routing. Updated by every workstream.

---

## BACKLOG
*Tasks accepted but not yet planned. PLAN should always be pulling from here.*

- VIGIL-MISSION-CONTROL: [HIGHEST PRIORITY] Build a React + Tailwind mission control dashboard to replace the current static HTML. Vite, WebSocket real-time data, mobile-first. Components: StatusBar, Pipeline (big/bold/animated), KanbanBoard (expandable cards), ActivityFeed (workstream colors), AttentionPanel (pulsing alerts), ServiceGrid, ProjectCards, SchedulePanel (countdown timers), StatsPanel (trends). Backend server.js stays. See /home/lever/command/handoffs/session-plan-final-review.md and TIMMY_PERSONALITY.md for all Master feedback on what is wrong with current dashboard.

- LEVER-BUG-5: [CRITICAL] InsuranceFund decimal mismatch (WAD bootstrap + USDT deposits)
- LEVER-BUG-6: [CRITICAL] FeeRouter called without USDT by Liquidation/Settlement
- LEVER-BUG-7: [CRITICAL] Zero liquidations (depthThreshold unset)
- LEVER-BUG-8: [HIGH] No closing transaction fee (10bps foregone)
- LEVER-BUG-9: [HIGH] Vault NAV missing unrealized PnL
- LANDING-MOBILE: Fix mobile scroll and side-scroll issues on landing page
- LANDING-DESIGN: Redesign landing page to be institutional and sophisticated
- VIGIL-DASHBOARD: Complete dashboard overhaul. Real-time WebSocket, actual reactive data, KANBAN board visible, activity feed, pipeline visualization. Current dashboard is useless.
- VIGIL-VERIFY-VISION: VERIFY must use Puppeteer/Chromium to take screenshots and use Claude vision to verify visual/UI changes. Not just code review.
- VIGIL-SELF-IMPROVE: System must continuously self-improve without Master having to point out every problem. Overseer must be more aggressive.

---

## PLANNED
*Plans written and approved by CRITIQUE. Ready for BUILD.*

- LEVER-BUG-3: [CRITICAL] Ghost OI (stale OI with zero positions) — plan: handoffs/plan-lever-bug-3.md
- LEVER-BUG-4: [CRITICAL] InsuranceFund never absorbs bad debt — plan: handoffs/plan-lever-bug-4.md

---

## IN PROGRESS

---

## IN REVIEW
- [2026-03-28] LEVER-BUG-2: [CRITICAL] $304K unaccounted vault drain

---

## DONE (last 10)
*Completed and verified. Pruned by ADVISOR weekly.*

- [2026-03-28] LEVER-P01: FundingRateEngine depthThreshold=0 guard — VERIFIED PASS
- [2026-03-28] LEVER-P02: BorrowFeeEngine depthThreshold=0 guard — VERIFIED PASS
- [2026-03-28] LEVER-P03: ExecutionEngine direct fee routing — VERIFIED PASS
- [2026-03-28] LEVER-P04: InsuranceFund absorbBadDebt recipient routing — VERIFIED PASS
- [2026-03-28] LEVER-P05: FundingRateEngine routeUnmatchedFunding correct function — VERIFIED PASS
- [2026-03-28] LEVER-P06: updateUnrealizedPnL on close — VERIFIED PASS

---

## BLOCKED
*Cannot proceed. Include reason and who can unblock.*

- LEVER-BUG-1: [CRITICAL] PnL formula mismatch — CRITIQUE verdict: REVISE (3rd review, verified against actual codebase). Three blockers: (1) exit formula diverges from LESSONS.md (double vs single impact, Master must decide), (2) LEVER-P06 makes Phase 2 without Phase 3 unsafe (vault NAV drift), (3) all plan line numbers stale (P03/P04/P06 shifted code). See: handoffs/critique-lever-bug-1.md

