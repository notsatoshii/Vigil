# IMPROVE PROPOSALS
## Proactive product improvement suggestions from the IMPROVE workstream.
## Latest proposals at top. Reviewed by ADVISOR during daily cycle.

---

## Session: 2026-04-01 09:00 UTC (Weekly Deep Review)
Reviewed: Markets list, trade panel (Long click), Vault, Positions, mobile (375px)
Browser: Chromium/Puppeteer, 1440x900 desktop + 375x812 mobile
Screenshots: /home/lever/screenshots/improve_weekly_01 through 05
Frontend last commit: 2026-03-28 (no code deployed in 4 days)

**Status of prior proposals #1-#9**: All still OPEN. Zero code changes since initial review session. The product is frozen. All previously reported issues persist unchanged.

**New market count**: 20 markets now visible (up from previous count). Several new markets added without a code deploy, suggesting the oracle/market data layer is working independently. Positive sign.

---

### PROPOSAL #10: Expired Markets Show Active Long/Short Buttons
**Category**: UX / Data Integrity
**Page/Component**: Trade page, market card grid
**Status**: OPEN
**Priority**: Ship now

**Current State**: Two markets appear in the main "20 active markets" list with fully-enabled Long and Short buttons, but their resolution countdown shows "Expired":
- "BTC Above $80k March 2026?" -- RESOLUTION: Expired
- "ETH Above $2600 March 2026?" -- RESOLUTION: Expired

Both markets are past their resolution date. A user clicking Long or Short on an expired market will get a confusing transaction failure or a silent error (per the existing Proposal #8 pattern). The header counts "20 active markets" which includes these expired ones, making the total misleading.

**Proposed Change**: Filter expired markets from the default market list. Options in order of preference:
1. Remove them from the main list entirely and move to a collapsible "Expired / Resolved" section at the bottom
2. Disable the Long/Short buttons on expired cards and replace with a greyed "Expired" badge
3. Minimum: stop counting them in the "20 active markets" header

The "Expired" resolution label is already computed correctly. Just act on it in the UI.

**User Impact**: Any trader who clicks on an expired market will hit a failure. Particularly bad in demo mode where we are trying to impress users.
**Effort Estimate**: Small (filter/conditional render based on expiry status already available in data)

---

### PROPOSAL #11: OI Capacity Meters Need Visual Progress Bars
**Category**: Data Visualization / UX
**Page/Component**: Trade panel, OI Capacity section
**Status**: OPEN
**Priority**: Next sprint

**Current State**: The trade panel has a useful OI Capacity section showing:
- Global OI: $11,662 / $41,176,897
- Market OI: $550 / $4,117,690
- Side OI: $287 / $2,882,383
- Per-user OI: $0 / $823,538

The data is correct and the concept is good. But it is presented as raw numbers with no visual fill indicator. A trader cannot parse "$11,662 / $41,176,897" quickly -- they need to see that this is essentially 0% filled.

The "Binding Limit" label reads: "Per-user OI -- $823,538 remaining" which sounds like it was copied from an internal API response. It is not user-facing language.

**Proposed Change**:
1. Add a slim progress bar (like a mini fuel gauge) to each OI row. The visual fill immediately communicates capacity. At current utilization (near zero), it tells a positive story: "plenty of room."
2. Rename "Binding Limit" to "Your position limit: $823,538" (plain English)
3. When any OI tier approaches 80% fill, color the bar yellow; 95% red. This is the risk signal traders actually need.

**User Impact**: Any trader evaluating position size. The OI section is already there and conceptually good. Visualizing it takes 30 minutes and makes it genuinely useful.
**Effort Estimate**: Small (add progress bar component to existing rows, rename label)

---

### PROPOSAL #12: Footer RPC Latency Number Reads as Debug Output
**Category**: UI / Polish
**Page/Component**: Footer, all pages
**Status**: OPEN
**Priority**: Backlog

**Current State**: The footer displays a raw millisecond latency figure that changes with every page interaction. Example: "OPERATIONAL | Base Sepolia | Polymarket Oracle | 532ms | v1.0.0-beta | TESTNET". The number fluctuates (284ms on one render, 532ms on the next). For a regular user this is meaningless. For a developer it is a debug printout. In a demo context, a VC watching you click around sees an apparently random number ticking in the footer.

**Proposed Change**: Replace the raw "Nms" number with a qualitative status dot:
- Green dot: under 300ms ("Oracle: Fast")
- Yellow dot: 300-800ms ("Oracle: Slow")
- Red dot: over 800ms or unreachable ("Oracle: Delayed")

Clicking the dot could expand to show the raw figure for technical users. This turns a confusing debug artifact into a meaningful status signal.

**User Impact**: Visible on every page, every user. Low priority because it does not block any workflow, but it is a polish item that would stop the "why is there a random number in the footer" question.
**Effort Estimate**: Small (replace text with conditional badge component)

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

## Sessions: 2026-03-28 16:14 - 2026-04-02 18:22 UTC (Passes 7-109)
Product unchanged across 103 consecutive checks spanning 5+ days. All 9 proposals still OPEN. No code deployed since initial review.

## Session: 2026-03-28 16:00 UTC (Sixth Pass)
Quick verification. Product unchanged. All 9 proposals still OPEN. No new issues.

## Session: 2026-03-28 15:43 UTC (Fifth Pass)
Quick verification only. Product unchanged. All 9 proposals still OPEN.
Header stats still empty. Positions still empty. No new issues.

---

## Session: 2026-03-28 15:14 UTC (Fourth Pass)
Reviewed: Markets, Vault (visual), trade panel, footer
Browser: Chromium/Puppeteer, 1440x900 desktop + screenshots
Confirmed: All 9 proposals still OPEN and unaddressed.
Note: Vault body cards render data fine ($68.6M TVL, $1.0002 share price) while the
header stat bar remains empty. Once #1 is fixed, the vault page will show TVL and
utilization in both the header bar AND the body cards. Recommend deduplicating as
part of that fix so the vault body cards become the single source of truth and the
header adapts (or hides) on the vault tab. Not a separate proposal; just a note for
whoever picks up #1.

---

## Session: 2026-03-28 14:53 UTC (Third Pass)
Reviewed: Markets page, trade panel interaction, Vault, Positions
Browser: Chromium/Puppeteer, 1440x900 desktop + screenshots
Confirmed: Proposals #1-#7 still OPEN and unaddressed.

---

### PROPOSAL #8: "Open Position" Button Gives Zero Feedback on Failure
**Category**: UX
**Page/Component**: Trade panel, order form
**Status**: OPEN
**Priority**: Ship now

**Current State**: Clicking "Open Position" with zero collateral (or any invalid state) simply dismisses the trade panel and returns the user to the market list. No error toast, no inline validation message, no shake animation, nothing. The user has no idea what happened or what they did wrong. Even with collateral entered, if the transaction fails (known high gas issue), the panel closes without explanation.

**Proposed Change**: Add inline validation before submission: "Enter collateral amount" under the input if empty, "Minimum 10 USDT" if too low. If the transaction is attempted and fails, show a toast with a human-readable reason (e.g., "Transaction failed: insufficient gas" rather than a raw revert). The "Open Position" button should be disabled/greyed out when the form is incomplete.

**User Impact**: Every user who tries to trade. Silent failure is the fastest way to lose a new user.
**Effort Estimate**: Small (validation logic + toast on tx error)

---

### PROPOSAL #9: Order Summary Shows "notional" as Placeholder Text
**Category**: UI Bug
**Page/Component**: Trade panel, position summary section
**Status**: OPEN
**Priority**: Ship now

**Current State**: In the order summary below the leverage slider, the row "Price:" displays the literal word "notional" instead of an actual dollar value. This appears to be a label or placeholder that leaked into the rendered output. Combined with "Position Size: 0 USDT" when collateral has not been entered, the summary section reads like a half-finished wireframe rather than a live product.

**Proposed Change**: The "Price" row should show the computed notional position value (collateral x leverage) formatted as a dollar amount, or be hidden entirely when the inputs are empty. If the label is meant to say "Notional Value:", change it to that and put the actual calculated number next to it.

**User Impact**: Anyone opening the trade form. Placeholder text in a live product signals "not ready."
**Effort Estimate**: Small (fix the display binding)

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
