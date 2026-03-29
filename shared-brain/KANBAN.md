# KANBAN
## Task board for all workstreams. Read by Commander before routing. Updated by every workstream.

---

## BACKLOG
*Tasks accepted but not yet planned. PLAN should always be pulling from here.*



---

## PLANNED
*Plans written and approved by CRITIQUE. Ready for BUILD.*


---

## IN PROGRESS
- [2026-03-29] VIGIL-MISSION-CONTROL: React dashboard built, deployed to :8080. Handoff: handoffs/build-vigil-mission-control.md

---

## IN REVIEW
- [2026-03-29] LEVER-BUG-6: [CRITICAL] FeeRouter called without USDT by Liquidation/Settlement
- [2026-03-29] LEVER-BUG-1: [CRITICAL] PnL formula mismatch (entryPrice vs entryPI) causing 38 winners, 0 losers
- [2026-03-29] VIGIL-SELF-IMPROVE: System must continuously self-improve without Master having to point out every problem. Overseer must be more aggressive.
- [2026-03-29] VIGIL-VERIFY-VISION: VERIFY must use Puppeteer/Chromium to take screenshots and use Claude vision to verify visual/UI changes. Not just code review.
- [2026-03-29] VIGIL-DASHBOARD: Complete dashboard overhaul. Real-time WebSocket, actual reactive data, KANBAN board visible, activity feed, pipeline visualization. Current dashboard is useless.
- [2026-03-29] LANDING-DESIGN: Redesign landing page to be institutional and sophisticated
- [2026-03-29] LANDING-MOBILE: Fix mobile scroll and side-scroll issues on landing page
- [2026-03-29] LEVER-BUG-9: [HIGH] Vault NAV missing unrealized PnL
- [2026-03-29] LEVER-BUG-8: [HIGH] Closing fee FeeType classification fixed. Handoff: handoffs/build-lever-bug-8.md
- [2026-03-29] LEVER-BUG-7: [CRITICAL] Zero liquidations (depthThreshold unset)
- [2026-03-29] LEVER-BUG-4: [CRITICAL] InsuranceFund never absorbs bad debt (no USDT transfer)
- [2026-03-29] LEVER-BUG-3: [CRITICAL] Ghost OI ($3.2M with zero positions)
- [2026-03-29] LEVER-BUG-5: [CRITICAL] InsuranceFund decimal mismatch (WAD bootstrap + USDT deposits)
- [2026-03-28] LEVER-BUG-2: [CRITICAL] $304K unaccounted vault drain

---

## DONE (last 10)
- [2026-03-29] VIGIL-MISSION-CONTROL: [HIGHEST PRIORITY] Build a React + Tailwind mission control dashboard to replace the current static HTML. Vite, WebSocket real-time data, mobile-first. Components: StatusBar, Pipeline (big/bold/animated), KanbanBoard (expandable cards), ActivityFeed (workstream colors), AttentionPanel (pulsing alerts), ServiceGrid, ProjectCards, SchedulePanel (countdown timers), StatsPanel (trends). Backend server.js stays. See /home/lever/command/handoffs/session-plan-final-review.md and TIMMY_PERSONALITY.md for all Master feedback on what is wrong with current dashboard.
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


