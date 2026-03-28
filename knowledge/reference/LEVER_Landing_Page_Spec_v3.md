# LEVER — Landing Page Full Spec v3 (Content + Visuals)
## For Lovable Handoff

---

## BRAND SYSTEM

**Colors:**
- Electric Lime: #E6FF2B — PRIMARY. This is the brand. Dominant presence throughout.
- Void Black: #000000 — Background. The canvas that makes lime pop.
- Deep Teal: #0B4650 — Supporting accent. Used for secondary elements, inactive states, depth.
- Soft Ivory: #F9F7F2 — Primary text color on dark backgrounds.
- Steel Gray: #898A8E — Secondary text, muted labels, inactive states.

**Color hierarchy:** Electric Lime is not an accent — it IS the brand. The page should feel lime-forward. Headlines, active states, key numbers, interactive elements, the grid — lime dominates. Deep Teal and Steel Gray play supporting roles.

**Typography:**
- Headlines: T1 Robit (Bold / Medium) — rounded, playful-technical, matches logo geometry
- Body: SF Pro (Light / Regular / Medium)
- Numbers/data: JetBrains Mono (Bold, tabular figures)

**Logo:** Actual LEVER logomark (Electric Lime rounded icon with two circles) + custom wordmark. SVG assets provided separately.

**Page background:** Void Black (#000000) throughout.

---

## THE VISUAL CONCEPT: THE GRID AWAKENS

The brand guidelines (page 1) show a distinctive grid pattern — clusters of rounded squares with selective Electric Lime highlights. This grid becomes the connective tissue across the entire page.

**The concept:** The page starts with the grid dark and dormant. As the visitor scrolls, grid squares selectively light up in Electric Lime — corresponding to the story being told. By the time they reach the bottom, the grid is fully alive. The page itself is a visual metaphor for LEVER: activating dormant capital.

**Grid construction:**
- Individual grid cells are rounded rectangles (matching the logo's rounded geometry and T1 Robit's rounded character)
- Cells exist at varying depths — some large and blurred (ambient background), some mid-ground, some small and sharp. This creates parallax depth without particles or gradients.
- Default state: dark gray squares on Void Black, barely visible
- Active state: Electric Lime fill — the primary activation color
- Secondary state: Deep Teal fill — represents idle, potential, or supporting elements
- Broken/disconnected state: Steel Gray with gaps — represents what's wrong in the problem section

**The grid is the layout system.** Cards, containers, interactive elements, even the CTA input — everything lives inside grid cells. The rounded-rectangle vocabulary of the logo becomes the UI vocabulary of the entire page.

**Animation principles:**
- Grid squares transition from dark → Electric Lime on scroll (the page "awakens")
- Staggered cascade animations — squares light up in sequence, not all at once
- Hover states: grid cells glow brighter, lift slightly
- The overall arc: dormant → awakening → ignition → fully alive → invitation

**Why this works for Lovable:** The grid is just divs with border-radius, background-color transitions, and opacity animations. No complex SVG paths, no trigonometry, no canvas rendering. Highly buildable.

---

## NAVIGATION

**Left:** LEVER logomark (Electric Lime icon) + wordmark (Soft Ivory).

**Center links:** How It Works · For LPs · Markets — SF Pro Regular, Soft Ivory. Electric Lime on hover.

**Right:** "Join Waitlist" button — Electric Lime fill, Void Black text. Rounded rectangle matching grid cell geometry. Glow on hover.

**Far right (subtle):** "Investors" — Steel Gray text link, no button treatment. Links to mailto:ec@lever.markets.

---

## SECTION 1 — HERO

**Content:**

Headline: "The leverage layer for prediction markets."
Subhead: "Up to 30× leverage on any outcome. One pool backs every market."
CTAs: [Join Waitlist] + [Follow @leverpm → https://x.com/leverpm]
Micro-copy: "Coming soon."

**Visual direction:**

Background grid: barely visible — dark gray squares on Void Black, mostly in corners and edges. A few squares glow Electric Lime, scattered. The page feels like it's waking up.

Headline in T1 Robit Bold. "The leverage layer" in Electric Lime. "for prediction markets." in Soft Ivory. The word "leverage" is slightly larger, with a subtle inset neumorphic treatment on the text itself (pressed into the surface). The rounded character of T1 Robit makes this feel tactile, not flat.

Subhead in SF Pro Regular, Steel Gray.

Hero visual: The leverage dial mirrors the logo's geometry. Two pill-shaped elements (echoing the icon's two circles) — one representing position, one representing multiplier. The dial track is a rounded rectangle matching logo proportions. Electric Lime fill on the active portion, Deep Teal on the inactive. As it animates, the lime portion grows. The dial feels like the logo came to life.

Waitlist input is built into a grid cell — a large rounded rectangle that IS one of the grid squares, just bigger and interactive. Email field + "Join" button inside a single Electric Lime-bordered grid cell. The grid pattern IS the UI.

"Follow @leverpm" sits beside it as a ghost button — Electric Lime border, no fill, Electric Lime text + X icon.

"Coming soon." in SF Pro Light, Steel Gray. Small. Below.

---

## SECTION 2 — THE PROBLEM

**Content:**

Headline: "Prediction markets are broken."
Subhead: "$63B in volume. $20B+ valuations. And three structural problems no one has solved."

Leverage comparison:
- Stocks → 4×
- Futures → 20×
- Forex → 50×
- Crypto perps → 100×
- Prediction markets → 1×

Transition: "Some are trying to fix this. But leverage alone doesn't solve it."

Card 1 — "Liquidity is trapped."
Every market has its own isolated pool. Capital sitting idle in one can't back another. New markets launch empty.

Card 2 — "No way to manage risk."
Market makers can't hedge. So they pull back. Spreads widen. Books thin out. Everyone suffers.

**Visual direction:**

Grid squares appear — but in Steel Gray. Active but broken. Some are fragmented, misaligned, split with gaps. Visually represents fragmentation without a word.

Headline in T1 Robit Bold, Electric Lime. Big. Confrontational. (Lime, not ivory — this is a bold statement, the brand color owns it.)

Subhead in SF Pro Medium, Soft Ivory. Dollar figures in Electric Lime.

Leverage comparison uses the grid squares themselves:
- Stocks: 4 lit squares (Electric Lime)
- Futures: 20 lit squares
- Forex: 50 lit squares
- Crypto perps: 100 squares — a dense cluster glowing Electric Lime
- Prediction markets: 1 square. Single. Alone. Surrounded by darkness.

That single glowing square IS the argument. Every visitor immediately feels the gap.

Transition line in SF Pro Regular, Soft Ivory. Scroll-triggered fade in.

Problem cards rendered as grid clusters with broken connections. Squares exist but pathways between them are severed. Card headlines in Electric Lime (T1 Robit Medium). Body in SF Pro Light, Soft Ivory. Deep Teal fills on the squares themselves — they feel cold, disconnected, idle.

---

## SECTION 3 — THE SOLUTION

**Content:**

Headline: "Leverage. Every market. One pool."

Body: "LPs deposit USDT into a single pool. Traders borrow against that pool to open leveraged long or short positions on any prediction market outcome. Every trade and every open position generates fees that flow back to LPs."

**Visual direction:**

The grid ignites. A cluster of squares in the center cascades from dark to Electric Lime, radiating outward. This is the visual peak moment of the page.

Each word of the headline is inside its own grid square — large, Electric Lime fill with Void Black text (inverted from the rest of the page). Three squares. Connected. The grid squares that were broken in the problem section are now linked and whole.

"Leverage." — grid square 1, Electric Lime fill, Void Black text.
"Every market." — grid square 2, Electric Lime fill, Void Black text.
"One pool." — grid square 3, Electric Lime fill, Void Black text.

These three connected squares become an iconic visual moment. They echo the logo's geometry and the grid system simultaneously.

Body text in SF Pro Regular, Soft Ivory. Sits below in a single wide grid cell. Max width ~600px.

---

## SECTION 4 — THE FLYWHEEL

**Content:**

Headline: "Liquidity creates yield. Yield creates liquidity."

Five-node cycle:
1. LPs seed the pool — "USDT goes in. Liquidity is live."
2. Traders open positions — "Leveraged longs and shorts borrow against the pool."
3. Utilization drives yield — "More positions. Higher utilization. Higher fees."
4. Yield attracts capital — "Higher APY pulls in more LPs."
5. Deeper liquidity attracts traders — "Bigger pool. Larger positions. More markets."

Below: "No token emissions. No incentive farming. Every fee comes from real trading activity."

**Visual direction:**

Headline in T1 Robit Bold, Electric Lime.

Five nodes ARE grid squares, arranged in a circular/pentagon pattern, connected by Electric Lime pathways — lines made of tiny grid dots like a circuit trace.

Animation: pathway illuminates square by square from node to node — like electricity flowing through a circuit board. The current/active node flips to Electric Lime fill. Only one node is fully lime at a time — it moves around the cycle.

Default node state: Deep Teal fill, Electric Lime border. Active node state: Electric Lime fill, Void Black text. The pulse of lime moving through the circuit IS the flywheel made visible.

Node text in T1 Robit Medium. Description in SF Pro Light, Steel Gray.

Bottom line in SF Pro Regular, Steel Gray.

**Mobile layout:** Five squares stack vertically with Electric Lime circuit trace running down the left side connecting them. Same visual language, different arrangement.

---

## SECTION 5 — FOR LPs

**Content:**

Headline: "Deposit USDT. Earn yield from every trade."

Interactive gauge: utilization 20% → 70%, APY updates live.

Yield math (for implementation):
- Formula: APY = (175.2% × U × M_util × 50%) × 1.3
- M_util = 1 / (1 - U)^0.5
- 20% util → ~25% APY
- 30% → ~41%
- 40% → ~59%
- 50% → ~81%
- 60% → ~108%
- 70% → ~146%

Below: "Yield scales with utilization. More trading activity means higher returns — no emissions, no incentive farming."

Trust signals: "50% of fees to LPs · ERC-4626 vault · Single deposit backs every market · On-chain verifiable"

**Visual direction:**

Headline in T1 Robit Bold, Electric Lime.

The gauge is a vertical stack of grid squares that fill from bottom to top — a thermometer made of the brand's grid cells. At 20% utilization, bottom few squares glow Electric Lime. As the visitor interacts (drag or scroll-linked), more squares fill upward. Deep Teal squares represent unfilled/idle capital. Electric Lime squares represent active, fee-generating utilization. The visitor watches idle capital become productive.

APY number displays beside the gauge in JetBrains Mono Bold, Electric Lime. Big — 72px+. Updates live as the gauge fills.

The grid-as-gauge is on-brand, distinctive, and highly buildable (just squares changing color based on a value).

Below text in SF Pro Regular, Steel Gray.

Trust signals in a horizontal line. SF Pro Light, Steel Gray. Separated by Electric Lime dots (not Deep Teal — lime is the brand).

---

## SECTION 6 — MARKETS

**Content:**

Headline: "If there's a prediction market for it, you can lever it."

Example markets:
- "Fed cuts rates in June" — 72% → Go 10× short
- "Bitcoin above $100K by July" — 58% → Go 15× long
- "FDA approves [drug]" — 34% → Go 5× long
- "France wins World Cup" — 12% → Go 20× long

Note: "Markets sourced via oracle feeds from leading prediction market platforms. LEVER adds leverage on top — it doesn't compete for order flow."

**Visual direction:**

Headline in T1 Robit Bold, Electric Lime.

Horizontal scrolling ticker — continuous, auto-scrolling, like a Bloomberg terminal. Each event is inside a grid cell (rounded rectangle matching logo geometry). The ticker never stops moving, creating liveness.

Inside each cell: Event name in T1 Robit Medium, Soft Ivory. Probability in JetBrains Mono Bold, Electric Lime, large. Trade direction in SF Pro Medium, Deep Teal.

On hover: cell expands slightly, Electric Lime glow intensifies, trade suggestion reveals. Each one is a micro-interaction.

Continuous scroll communicates "infinite markets" better than four static cards.

Note below in SF Pro Light, Steel Gray.

---

## SECTION 7 — WHY NOW

**Content:**

Headline: "Four forces are converging — right now."

Stats:
- $63B — Prediction market volume in 2025. Up 400× in two years.
- $20B+ — Kalshi and Polymarket valuations. NYSE's parent ICE invested $2B.
- $130B+ — Capital in stablecoins earning 3–8% APY. Searching for real yield.
- 0 — Derivatives venues for prediction market hedgers.

Closing: "Sophisticated capital has arrived at prediction markets. The infrastructure to serve it hasn't."

**Visual direction:**

Not four stat blocks in a row. Each number fills nearly the full viewport. The visitor scrolls THROUGH them.

Scroll → **$63B** fills the screen. JetBrains Mono Bold, Electric Lime, massive. Grid squares in the background are dense, alive. Context line in Soft Ivory below.

Scroll → **$20B+** takes over. Grid shifts pattern.

Scroll → **$130B+** takes over. Grid squares pulse gently — idle capital searching.

Scroll → **0** — everything changes. The grid squares disappear. Screen goes near-empty. Just the zero, centered, in Soft Ivory (NOT lime — the absence of the brand color IS the point). "Derivatives venues for prediction market hedgers." in Steel Gray below. The sudden loss of lime creates a visceral void.

Then the grid comes back as they scroll to the closing line. Squares re-illuminate in Electric Lime. "Sophisticated capital has arrived at prediction markets. The infrastructure to serve it hasn't." SF Pro Medium, Soft Ivory.

---

## SECTION 8 — COMPETITIVE EDGE

**Content:**

Headline: "Every protocol solves one. None solve all three."

Card 1 — "No leverage. No serious capital."

Card 2 — "Fragmented liquidity. No deep markets."

Card 3 — "No hedging. No market makers."

LEVER: "LEVER is all three. Leveraged perpetuals. Unified liquidity. A risk stack built for binary outcomes."

**Visual direction:**

Headline in T1 Robit Bold, Electric Lime.

Three grid clusters, each visibly incomplete:

Cluster 1 — Grid mostly assembled but with a dark gap where pool squares should be. The leverage squares glow Electric Lime but are isolated, unconnected. Feels unstable.

Cluster 2 — Pool squares glow Deep Teal but are crumbling/fragmenting at edges. Squares breaking apart. Feels fragile.

Cluster 3 — Grid outline visible in Steel Gray but hollow inside. Nothing to power. Feels empty.

Card text: headlines in Electric Lime (T1 Robit Medium), body in SF Pro Regular, Soft Ivory.

Below them: one complete grid cluster. All squares lit Electric Lime. Fully connected. No gaps. Dense. Alive. It's the most complete grid on the page.

"LEVER:" in T1 Robit Bold, Electric Lime. Rest in Soft Ivory. The complete grid IS LEVER's visual identity.

No competitor names anywhere.

---

## SECTION 9 — WAITLIST CTA / CLOSING STATEMENT

**Content:**

Closing statement: "Prediction markets have proven they can price truth. $120B in volume. $20B+ valuations. 264 projects and counting. The asset class is here. But it's running on infrastructure built for retail bets, not institutional capital. No leverage. No unified liquidity. No derivatives layer. Every mature financial market in history developed these tools. Prediction markets are next. LEVER is the institutional-grade infrastructure that brings real capital to the truth layer."

CTA: "Join the waitlist."
Email input + submit button
Secondary: "Follow @leverpm" → https://x.com/leverpm
Micro-copy: "Coming soon."

**Visual direction:**

The grid is now fully alive. More Electric Lime squares than at any point on the page. Dense, pulsing gently, covering the background. The page has reached full activation — this is the climax.

Closing statement sits in a large, centered grid cell — the biggest single cell on the page. Electric Lime border, subtle Electric Lime glow emanating from it. The container itself feels important and premium.

Text in T1 Robit Bold, Soft Ivory. Key phrases highlighted in Electric Lime: "price truth" · "institutional-grade infrastructure" · "truth layer." Two or three highlights max.

"Join the waitlist." in SF Pro Medium, Electric Lime.

Waitlist input mirrors the hero — lives inside a rounded grid cell. Email field with Electric Lime border on focus. Submit button: Electric Lime fill, Void Black text, T1 Robit Bold, "Join."

"Follow @leverpm" — ghost button, Electric Lime border, Electric Lime text + X icon.

"Coming soon." in SF Pro Light, Steel Gray.

---

## SECTION 10 — FOOTER

**Content:**

Logo: LEVER logomark + wordmark
Links: How It Works · For LPs · Markets · Docs (when live)
Social: X/Twitter → https://x.com/leverpm
Investor: "For investors: ec@lever.markets"
Legal: "© 2026 LEVER Protocol. This is not financial advice. Trading involves risk."

**Visual direction:**

The grid fades back to dormant — dark squares, minimal lime. The energy returns to where it started. The page's visual arc is complete: dormant → awakening → ignition → alive → rest.

Separated by a 1px line in Steel Gray.

Left: LEVER logomark (Electric Lime) + wordmark (Soft Ivory).
Center: links in SF Pro Regular, Steel Gray. Electric Lime on hover.
Right: X/Twitter icon in Steel Gray, Electric Lime on hover.
Investor: "For investors: ec@lever.markets" — SF Pro Light, Steel Gray. No button. Just text.
Legal: SF Pro Light, Steel Gray, smaller.

---

## CONTENT PRINCIPLES

1. **No fake data.** No fabricated trading volumes, user counts, TVL, or testimonials. Pre-product company. Credibility from thesis strength, not invented metrics.
2. **No "DeFi" in headlines.** Sparingly in body text only when technically necessary.
3. **No "Polymarket" by name above the fold.** Can appear in body context. LEVER's positioning is platform-agnostic.
4. **Institutional tone.** Confident, precise, not hype-driven.
5. **Trader-first, investor-accessible.** 90% serves traders/LPs. Investor access one click away.
6. **One CTA per section maximum.** Waitlist is the primary conversion.
7. **Electric Lime is the brand.** It should be the dominant visual force, not an accent. Deep Teal and Steel Gray support — they don't compete.

---

## RESPONSIVE NOTES

- Grid system scales naturally — reduce columns, maintain rounded-rectangle vocabulary
- Market ticker: horizontal scroll on desktop, vertical stack on mobile
- Flywheel: circular layout desktop, vertical stack with left-side circuit trace on mobile
- LP gauge: vertical grid thermometer works on all screen sizes
- Why Now stats: full-viewport scroll-through works on both desktop and mobile
- Nav: collapses to hamburger on mobile, "Join Waitlist" button persists as sticky CTA
- Competitive edge clusters: side by side on desktop, stacked on mobile

---

## VISUAL ARC SUMMARY

| Section | Grid State | Lime Intensity |
|---|---|---|
| Hero | Dormant, few scattered lime squares | Low — waking up |
| Problem | Steel Gray, broken/fragmented squares | Medium — something's wrong |
| Solution | Ignition — cascade from center outward | High — breakthrough |
| Flywheel | Circuit traces pulsing between nodes | Medium-high — system in motion |
| For LPs | Gauge filling from idle to active | Building — capital activating |
| Markets | Ticker cells scrolling | Steady — alive and active |
| Why Now | Dense and pulsing, then void on "0" | Peak → void → recovery |
| Competitive Edge | Broken clusters → complete cluster | Incomplete → whole |
| CTA/Closing | Fully alive, dense, maximum coverage | Maximum — full activation |
| Footer | Fading back to dormant | Low — rest |
