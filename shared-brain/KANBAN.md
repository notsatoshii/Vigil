# KANBAN
## Task board for all workstreams. Read by Commander before routing. Updated by every workstream.

---

## BACKLOG
*Tasks accepted but not yet planned.*

- LEVER-AUDIT: Complete remaining 6 critical bugs from March 23 audit (PnL formula, ghost OI, vault drain, InsuranceFund decimals, FeeRouter calls, zero liquidations)
- LEVER-AUDIT-HIGH: Fix 2 HIGH bugs (closing TX fee, vault NAV missing unrealized PnL)
- LANDING-MOBILE: Fix mobile scroll and side-scroll issues on landing page
- LANDING-DESIGN: Make landing page institutional and sophisticated (not tacky grids)
- RESEARCH-WATCHLISTS: Create initial watchlist JSON files for all 5 categories
- RESEARCH-TRENDS: Seed initial time-series data for competitor volumes and DeFi TVL
- SECURE-CONTRACTS: Full security audit of all 16 contracts (rotate through one at a time)
- IMPROVE-FULL-REVIEW: Complete browser-based product review of LEVER frontend
- IMPROVE-LANDING-REVIEW: Browser-based review of landing page on mobile and desktop
- CEO-INVESTOR-DECK: Update investor pitch deck with new Prediction Index data ($100B volume, $8B Polymarket valuation)
- OPERATE-CLEANUP: Clean up dead services (lever-dispatcher, lever-worker), stale tmux sessions
- KNOWLEDGE-GAPS: Identify gaps in knowledge graph and assign RESEARCH to fill them

---

## PLANNED
*Plans written and approved by CRITIQUE. Ready for BUILD.*

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

