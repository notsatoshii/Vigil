# KANBAN
## Task board for all workstreams. Read by Commander before routing. Updated by every workstream.

---

## BACKLOG
*Tasks accepted but not yet planned. PLAN should always be pulling from here.*

- LEVER-BUG-2: [CRITICAL] $304K unaccounted vault drain
- LEVER-BUG-3: [CRITICAL] Ghost OI ($3.2M with zero positions)
- LEVER-BUG-4: [CRITICAL] InsuranceFund never absorbs bad debt (no USDT transfer)
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

- LEVER-BUG-1: [CRITICAL] PnL formula mismatch — plan: handoffs/plan-20260328-133419.md

---

## IN PROGRESS
*Currently being worked on. Include workstream and start time.*

---

## IN REVIEW
*Completed by BUILD, being reviewed by VERIFY.*

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

