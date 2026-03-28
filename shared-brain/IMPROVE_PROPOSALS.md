# IMPROVE PROPOSALS
## Proactive product improvement suggestions from the IMPROVE workstream.
## Latest proposals at top. Reviewed by ADVISOR during daily cycle.

---

## Session: 2026-03-28 (Quick Review)
Reviewed: Markets page, Vault page, Positions page, market trade panel
Browser: Chromium/Puppeteer, 1440x900 desktop + 375x812 mobile

---

### PROPOSAL #1: Header Stats Show No Values (Critical Bug)
**Category**: UI / Data
**Page/Component**: Global header stat bar (all pages)
**Status**: OPEN
**Priority**: Ship now

**Current State**: The four stat cards at the top of every page ("TOTAL TVL", "TOTAL VOLUME", "TOTAL OI", "UTILIZATION") render the label and a pulsing "LIVE" badge, but zero actual numbers. The grid container exists and renders, but the value slots are blank. This is the first thing any visitor sees above the fold.

**Proposed Change**: Fix the data binding so the values actually render. Based on PROJECT_STATE.md the values exist ($502K TVL, $4.3K OI, 0.86% utilization). This is likely an RPC call that resolves after the component renders but the value never populates into the DOM. Add a loading skeleton (shimmer) during fetch, and a fallback number from a cached/static last-known value if RPC fails. The LIVE badge should pulse only when the data is actually fresh, not as a permanent decoration on empty slots.

**User Impact**: Every user, every page load. An investor demo with empty TVL stats looks like a broken product.
**Effort Estimate**: Small (a few hours to debug + fix the data binding)

---

### PROPOSAL #2: On-Chain Price vs Oracle Price Confusion
**Category**: UX / Data Visualization
**Page/Component**: Market trade panel (individual market view)
**Status**: OPEN
**Priority**: Next sprint

**Current State**: When a user opens a market (e.g., SpaceX IPO at 99% Polymarket probability), the trade panel shows two prices simultaneously:
- "PROBABILITY: 99.0% / 99.0 cents per contract"
- "ON-CHAIN PI: 49.7 cents / Awaiting keeper update"

These two numbers differ by 2x. There is no explanation of why or which one matters for trading. The recent trades table also shows entries at 49.7 cents, which looks like historical fills at the wrong price.

**Proposed Change**: Either (a) hide the on-chain PI when it is stale ("Awaiting keeper update") and just show the oracle price prominently, or (b) add a clear label like "Oracle Price (trade basis): 99.0¢" and "On-chain index (stale, pending update): 49.7¢ -- updates every N minutes." A small info icon with a tooltip explaining the keeper update cycle would do a lot of work here.

**User Impact**: Traders evaluating entry price, especially new users unfamiliar with the oracle architecture. The current display creates distrust.
**Effort Estimate**: Small (label/tooltip change) to Medium (hide stale data conditionally)

---

### PROPOSAL #3: Vault APY 0.0% Kills the LP Pitch
**Category**: UX / Feature Gap
**Page/Component**: Vault page, header stats
**Status**: OPEN
**Priority**: Next sprint

**Current State**: The Vault page prominently displays "CURRENT APY: 0.0% / From protocol fees." This is technically accurate for a testnet with minimal activity, but it is the worst possible number to show an LP or an investor in a demo. The header also shows "CURRENT APY LIVE" with no value (same bug as Proposal #1).

**Proposed Change**: Two options (pick one or both):
1. **Short term**: Replace the 0.0% APY display with a projected/target APY range badge. Something like "Target APY: 8-15% at 50% utilization" with a small note that current APY reflects testnet activity only. This is honest and directionally useful.
2. **Medium term**: Add a simple APY simulator -- a slider showing "At X% utilization, estimated APY is Y%." This turns an embarrassing zero into a product feature that explains the yield model.

Additionally, the borrow rate is shown as "0.0200% per hour" in the market panel but there is no summary of this in the Vault page as the yield source. Connecting the dots (borrow fees flow to LPs) would help depositors understand the model.

**User Impact**: LPs considering deposits, investors evaluating the protocol in a demo.
**Effort Estimate**: Small for the label fix, Medium for the APY simulator

---

### PROPOSAL #4: Demo Positions Missing from Positions Tab
**Category**: Feature Gap / Demo UX
**Page/Component**: Positions page
**Status**: OPEN
**Priority**: Ship now (affects demo quality)

**Current State**: The Positions tab shows "No Open Positions / You don't have any active positions yet." But the demo wallet has a balance of $992K USDT and vault shares worth $101K. PROJECT_STATE.md references 4 active demo positions (SpaceX, US-Iran, FIFA, Fed Rate). An empty positions tab in demo mode makes the feature look non-functional.

**Proposed Change**: Either (a) confirm the demo wallet actually has open positions on-chain and fix the data fetch, or (b) if the positions were closed, reopen them as part of the demo setup. Demo mode should always show at least 2-3 populated positions so the Positions tab demonstrates what it can do. The tab is the most important screen for a returning trader and it needs to show value.

**User Impact**: Anyone evaluating the product in demo mode, which is everyone.
**Effort Estimate**: Small if it is a data fetch bug, Medium if demo positions need to be re-seeded

---

### PROPOSAL #5: Mobile First Impression is Bare
**Category**: UI / Responsive Design
**Page/Component**: All pages, 375px viewport
**Status**: OPEN
**Priority**: Backlog

**Current State**: On mobile (375px), the top section shows: the demo wallet address badge, then four empty stat cards, then the nav (Trade / Vault / Positions), then the markets list. The empty stat cards are especially prominent on mobile since they take up significant vertical space before any content appears. The page reads as broken before the user even scrolls.

**Proposed Change**: On mobile, consider collapsing the stat bar into a single scrollable row or removing it entirely until the data loads. The nav tabs could move to a bottom bar (standard mobile UX pattern) to free up vertical space for market cards. Market cards on mobile currently require scrolling within a card to see all info -- consider a more compact mobile card variant.

**User Impact**: Any user on phone or tablet. Critical if any demo is done on mobile.
**Effort Estimate**: Medium (responsive redesign of header stats + bottom nav consideration)

---

## Session: 2026-03-28 (Quick Spot-Check)
Reviewed: Trade/Markets, Vault, Positions pages
Browser: Chromium, 1440x900 desktop
Confirmed: Proposals #1-#5 from the earlier session are still OPEN and unaddressed.

---

### PROPOSAL #6: Positions Empty State Has No Actionable CTA
**Category**: UX
**Page/Component**: Positions page, empty state
**Status**: OPEN
**Priority**: Ship now (tiny effort, meaningful UX improvement)

**Current State**: The empty state reads "No Open Positions. You don't have any active positions yet. Go to Markets to find an opportunity, then open a position from Trading." The phrase "Go to Markets" is plain text; it does nothing. A user who lands on this tab fresh has to manually figure out how to navigate away.

**Proposed Change**: Make "Go to Markets" a button or styled link that routes to the Trade tab. One line of code. The bar-chart-in-a-circle icon is generic; a more evocative empty state image would feel less like a 404 page, but the CTA is the critical fix.

**User Impact**: New users, anyone landing on Positions for the first time.
**Effort Estimate**: Small (30 minutes)

---

### PROPOSAL #7: Market Cards Show No Volume or Liquidity Signal
**Category**: Data Visualization / UX
**Page/Component**: Trade page, market card grid
**Status**: OPEN
**Priority**: Next sprint

**Current State**: Each card shows category, name, probability, resolution countdown, max leverage, and Long/Short buttons. No volume, open interest, liquidity depth, or activity signal. Every market looks identical in terms of tradability, regardless of how much capital sits behind it.

**Proposed Change**: Add a compact stat to each card showing OI or 24h volume for that specific market. Even a relative activity indicator (Low/Medium/High dot) would let a trader filter to markets worth entering. A market with $0 OI and one with $50K OI should not look the same. Polymarket shows volume prominently because it is the primary trust signal for a prediction market.

**User Impact**: Any trader choosing which market to enter. Without this, picking a market is arbitrary.
**Effort Estimate**: Medium (requires per-market OI/volume data on the trade page, may need additional aggregation)

---
