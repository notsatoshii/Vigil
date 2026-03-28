# Plan: LANDING-DESIGN — Redesign Landing Page to Institutional and Sophisticated
## Date: 2026-03-28T16:40:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

Master called the current landing page grid cells "trash, tacky, not modern, not classy." The
design must look "institutional, sophisticated, and premium" because LEVER is an institutional-
grade leveraged trading platform, not a consumer app.

The current page follows a "Grid Awakens" visual narrative (from the v3 spec) where rounded
rectangles progressively light up in Electric Lime as you scroll. Several grid elements have
already been hidden via `display: none` (lines 115, 452, 467, 474), suggesting the visual
concept was abandoned mid-build. What remains is a halfway state: the spec's narrative structure
without its visual vehicle, dressed in a startup aesthetic.

The page needs to feel like **Paradigm's research page, Circle's product page, or CME Group's
platform announcement** rather than a crypto consumer app.

---

### Design Direction: From "Grid Awakens" to "Precision Black"

The redesign replaces the playful grid narrative with a stripped-back, high-contrast,
typography-driven design. Think: a premium pitch deck on a black canvas.

**Design principles:**
1. **Typography carries weight.** Headlines are the hero, not background patterns.
2. **Lime is punctuation, not paint.** Electric Lime for CTAs, key metrics, and one accent per
   section. Ivory for body text. Gray for secondary labels. That is it.
3. **Generous negative space.** Each section breathes. No visual clutter fighting for attention.
4. **Restraint over flash.** Every visual element earns its place. No decorative gradients,
   no pulsing glows, no cascading animations.
5. **Confidence without explanation.** The product is infrastructure. It does not need to "tell
   a story" with animated grid cells. State the facts. Let them land.

---

### Section-by-Section Redesign

#### Navigation (lines 671-695) — MINOR CHANGES

Keep current structure. Clean up:
- Remove scroll progress bar (line 695, `.scroll-progress`). Institutional sites do not have
  these; they feel like blog posts.
- Reduce logo SVG size slightly (currently dominates on mobile).
- Make nav links uppercase, 11px, tracked-out (letter-spacing: 3px). This is the institutional
  cue: small, confident type.

---

#### Hero (lines 698-719) — MAJOR REWORK

**Current:** Headline in T1 Robit with lime/ivory split. Waitlist box. "Coming soon."

**Redesign:**
- Remove the hidden hero-dial entirely (lines 700-707). Dead code.
- Headline: keep the copy ("The leverage layer for prediction markets.") but render it as ONE
  color (ivory or white), with "leverage layer" in bold weight. Lime only on the "30x" in the
  sub-headline. This reduces the lime saturation from "half the headline" to "one callout."
- Sub-headline: keep "Up to 30x leverage on any outcome. One pool backs every market." Render
  "30x" in lime monospace (JetBrains Mono), rest in system font.
- Remove the water physics canvas animation entirely (lines 1390-1530 JS). Institutional sites
  do not have liquid simulations. It is a tech demo, not a design element. Replace with a
  single, static radial gradient (very subtle, from center) or nothing at all.
- Waitlist box: make it wider, more prominent. Single line: email input + "Join Waitlist" button.
  Clean border (1px rgba lime at 20%), no backdrop blur. Button is solid lime, black text.
- Remove "Coming soon." micro-copy. It undermines confidence. If you need temporal framing, use
  "Launching Q3 2026" in small gray text below the waitlist box.

**Hero CSS target:**
```css
.hero {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 120px 24px 80px;
}
.hero h1 {
  font-family: var(--fh);
  font-size: clamp(40px, 5.5vw, 72px);
  font-weight: 700;
  color: var(--ivory);
  line-height: 1.1;
  letter-spacing: -0.02em;
  margin-bottom: 24px;
}
```

---

#### Problem (lines 724-745) — MODERATE REWORK

**Current:** "Prediction markets are broken." Leverage comparison bars. Two problem cards.

**Redesign:**
- Keep the leverage comparison bars. They are the strongest visual on the page. Clean, data-
  driven, instantly understandable. This IS institutional: letting data make the argument.
- Restyle bars: remove the lime glow/border on the prediction markets bar. Instead, make it
  a muted red or leave it at 1x with a stark "1x" in lime while others are gray. The contrast
  tells the story without decoration.
- Remove the problem cards (`.pc` divs, lines 741-743). They explain what the bars already
  show. Institutional pages do not over-explain. Replace with a single sentence below the bars:
  "Every other asset class has leverage. Prediction markets have 1x." Ivory, 18px, max-width 500px.
- Section tag ("The Problem"): keep, but render in small gray uppercase, not lime.

---

#### Solution (lines 750-760) — MODERATE REWORK

**Current:** Three bordered pills ("Leverage." "Every market." "One pool.") with lime borders
and a 1400px wide radial gradient pseudo-element.

**Redesign:**
- Remove the `::after` gradient (lines 259-264). Unnecessary decoration.
- Keep the three words but change rendering: display them as one line on desktop, three lines
  on mobile. Use the headline font at a very large size (clamp 48-80px). No borders, no pills,
  no backdrop blur. Just bold ivory text on black. The words are powerful enough without boxes.
- Below: keep the body copy. Increase line-height to 2.0 for a premium, airy feel.
- The section should feel like a premium slide: one big statement, one short paragraph. Nothing
  else.

---

#### Flywheel (lines 765-781) — MAJOR REWORK

**Current:** Circular SVG layout with 5 nodes positioned absolutely. Circuit-trace dots. Complex
mobile fallback to vertical timeline.

**Redesign:**
- Replace the circular wheel with a simple vertical numbered list. Five steps, each on its own
  line. Number in lime monospace. Title in bold ivory. Description in gray.
- Remove the SVG circuit traces, dot animations, and all absolute positioning (lines 288-312,
  770-772). This is the "tacky" element Master called out.
- The flywheel concept is important (it is the product's core loop), but it should be
  communicated through clean typography, not visual metaphors.
- Layout: centered, max-width 600px. Each step is a row: `01` in lime mono, then title, then
  description indented below.

```
01  LPs seed the pool
    USDT goes in. Liquidity is live.

02  Traders open positions
    Leveraged longs and shorts borrow against the pool.

03  Utilization drives yield
    More positions. Higher utilization. Higher fees.

04  Yield attracts capital
    Higher APY pulls in more LPs.

05  Deeper liquidity
    Bigger pool. Larger positions. More markets.
```

- Keep "No token emissions..." line at bottom. Render as a quiet, confident statement.

---

#### For LPs (lines 786-811) — MODERATE REWORK

**Current:** Thermometer gauge (vertical grid cells), APY display, trust signals.

**Redesign:**
- Remove the thermometer gauge (`.thermo-container`, lines 791-797). Grid cells are out.
- Center the APY number as the section hero: large (clamp 80-140px), lime, JetBrains Mono.
  Just the number. Below it, "Estimated APY" in small gray.
- Below: the trust signals row (50% of fees, ERC-4626, etc.) becomes a clean horizontal list
  with thin separator pipes. No dots, no borders.
  `50% of fees to LPs | ERC-4626 vault | Single deposit backs every market | On-chain verifiable`
- The description paragraph stays but is moved below the trust row.

---

#### Markets (lines 816-843) — MINOR CHANGES

**Current:** Horizontal ticker with market cards, each showing event + probability + action.

**Redesign:**
- The ticker is actually good. It feels like a Bloomberg terminal feed. Keep it.
- Restyle the cards: remove the border-radius rounding (use 4px instead of 12px). Remove
  the lime border accents. Make them flat: dark gray background (not transparent), white text,
  lime only for the probability percentage.
- On mobile, the vertical ticker is fine. Keep it.
- This section can be mostly left alone. It is already the most institutional-feeling section.

---

#### Why Now / Stats (lines 848-884) — KEEP, MINOR POLISH

**Current:** Four full-viewport stat blocks ($63B, $20B+, $130B+, 0).

**Redesign:**
- This is the second strongest section (after the leverage bars). The big numbers on black are
  inherently institutional. Keep them.
- Remove the background grid divs (already hidden via CSS). Remove the stat grid JS.
- Make the "0" stat more impactful: currently uses "void" styling (ivory instead of lime). Keep
  that. Add a subtle line below: "leveraged prediction market platforms exist." Period. Let the
  zero land.
- Ensure the fade-in animation is opacity-only (no transform, no scale). Institutional = still.

---

#### Competitive Edge (lines 889-934) — MAJOR REWORK

**Current:** Three "broken cluster" grid visualizations + one "complete cluster" with explanatory
text. All hidden via CSS already.

**Redesign:**
- The grid clusters are gone. Good.
- Replace with a clean three-column layout (single column on mobile):

| Leveraged Perpetuals | Unified Liquidity | Binary Risk Stack |
|---------------------|-------------------|-------------------|
| Up to 30x on any outcome | One pool backs every market | Purpose-built for binary probability |

- Each column: title in bold ivory, 2-line description in gray. No boxes, no borders, no icons.
- Below the columns: "LEVER is all three." in lime, centered. Full stop. Confidence.

---

#### Closing CTA (lines 939-949) — MODERATE REWORK

**Current:** Long paragraph about "pricing truth" with lime-highlighted phrases. Waitlist box.

**Redesign:**
- Shorten the closing paragraph dramatically. One sentence: "Institutional-grade leverage for
  the markets that price truth." Or even just: "The leverage layer for prediction markets." (echo
  the hero). Avoid philosophical language about "truth" and "soul of the market." Institutional
  buyers do not need poetry; they need product.
- Waitlist box: same as hero (email + button), centered.
- Remove "Coming soon." Replace with "Launching on Base" in gray if needed.

---

#### Footer — MINOR CHANGES

- Keep current structure.
- Ensure footer links are uppercase, small, tracked-out (matching nav).
- Add "Base Sepolia Testnet" badge if testnet is live.

---

### Visual System Summary

| Element | Current | Redesigned |
|---------|---------|-----------|
| Grid cells | Dominant but hidden | Removed entirely |
| Electric Lime | Headlines, borders, fills, glows | CTAs and key metrics only |
| Animations | GSAP ScrollTrigger + canvas physics | Opacity fade-in only |
| Borders/cards | Lime borders, backdrop blur, rounded | Flat, minimal, 1px gray or none |
| Typography | T1 Robit (rounded) + SF Pro | T1 Robit (keep for brand) + SF Pro |
| Background effects | Radial gradients, noise overlay | Black. Nothing else. |
| Decorative elements | Circuit traces, thermometer, dial | None |
| Section spacing | Variable (56px-160px) | Consistent (120px desktop, 80px mobile) |

---

### Implementation Steps

**Step 1: Remove dead visual elements**

Delete from HTML and CSS:
- Hero dial (lines 700-707 HTML, line 115 CSS)
- Liquid physics canvas (all JS from lines 1390-1530, CSS lines 46-53, createElement at ~1397)
- Solution `::after` gradient (CSS lines 259-264)
- Flywheel SVG and dot animations (lines 770-772 HTML, lines 288-312 CSS, related JS)
- Thermometer gauge (lines 791-797 HTML, related CSS)
- Edge grid clusters (already hidden, remove the HTML too: lines 889-920 area)
- Closing grid background (already hidden)
- Stat grid backgrounds (already hidden, remove the HTML and JS)
- Scroll progress bar (line 695 HTML, related CSS)
- Noise overlay (`body::after` at lines 39-43)

This is pure cleanup. No visual change since most elements are already hidden.

**Step 2: Restyle the hero**

- Single color headline (ivory), lime only on "30x" in sub-headline
- Remove canvas background
- Clean waitlist box (wider, prominent, solid lime button)
- Replace "Coming soon." with "Launching Q3 2026" or remove

**Step 3: Restyle the flywheel**

- Replace circular SVG layout with numbered vertical list
- Remove all absolute positioning and animation
- Clean monospace numbers + typography-only layout

**Step 4: Restyle For LPs section**

- Remove thermometer
- Center APY as hero number
- Trust signals as piped horizontal list

**Step 5: Restyle Competitive Edge**

- Three-column text layout (no visualizations)
- "LEVER is all three." closer in lime

**Step 6: Reduce lime saturation globally**

- Section tags: gray instead of lime
- Card borders: 1px rgba(255,255,255,0.06) instead of lime
- Solution blocks: no borders, plain text
- Only lime elements remaining: CTA buttons, key metrics (30x, APY, $63B), hover states

**Step 7: Clean up animations**

- Keep GSAP ScrollTrigger for fade-in-on-scroll (opacity only)
- Remove all scale, translate, and stagger animations
- Remove all `data-anim="scale"`, `data-anim="left"` attributes. Change to `data-anim="fade"`
- Remove canvas animation loop entirely

**Step 8: Polish spacing and typography**

- Consistent section padding: 120px top/bottom desktop, 80px mobile
- Headline sizes: clamp(36px, 5vw, 64px) consistently
- Body text: 17-18px, line-height 1.9-2.0
- Max content width: 680px for text blocks (tighter, more focused reading)

**Step 9: Shorten closing section**

- One sentence + waitlist box. Remove the long paragraph.

**Step 10: Test**

- Desktop 1920px: clean, centered, generous whitespace
- Tablet 768px: single column, same aesthetic
- Mobile 375px: no horizontal scroll (see LANDING-MOBILE plan), readable
- Compare against reference sites (Paradigm.xyz, circle.com, cmegroup.com)

---

### Files to Modify

- `/home/claude/lever-landing/index.html` — the entire file (CSS + HTML + JS)

### Files to Create

None. The redesign is CSS/HTML changes within the existing file.

### Files to Read First

- `/home/claude/lever-landing/index.html` — full file
- `/home/lever/command/knowledge/reference/Lever_Guideline.pdf` — brand colors and typography
- `/home/lever/command/shared-brain/TIMMY_PERSONALITY.md` lines 91-92 (Master's design feedback)

---

### Dependencies and Ripple Effects

- **LANDING-MOBILE plan:** The mobile scroll fixes from that plan should be applied FIRST or
  simultaneously. The redesign removes several overflow sources (canvas, 1400px pseudo-element,
  flywheel absolute positioning), which also fixes mobile scroll. The two plans are complementary.

- **GSAP CDN dependency:** Keep GSAP for simple opacity fade-ins. It is already loaded and
  the ScrollTrigger is well-integrated. Removing it would require rewriting the animation
  system. Instead, simplify what it animates.

- **Font loading:** T1 Robit and JetBrains Mono stay. No new font dependencies.

- **No build step.** Edit the HTML file directly. Changes are live immediately on port 3001.

---

### What Stays (not touched)

- Leverage comparison bars (Problem section) — strongest visual, data-driven
- Full-viewport stat blocks (Why Now section) — inherently institutional
- Market ticker (Markets section) — Bloomberg-like feed
- Navigation structure — clean and functional
- Copy content — the words are good; only the visual treatment changes
- Color palette — lime, black, ivory, gray per brand guidelines
- Font families — T1 Robit, SF Pro, JetBrains Mono per brand guidelines

### What Goes

- Liquid physics canvas (water animation)
- All grid cell visualizations (already mostly hidden)
- Flywheel circular SVG + circuit traces
- Thermometer gauge
- Solution bordered pills and gradient
- Noise overlay
- Scroll progress bar
- Competitive edge grid clusters
- All scale/translate animations (replaced with opacity-only)
- "Coming soon." micro-copy

---

### Edge Cases

**Font loading failure:** If T1 Robit fails to load, Space Grotesk (fallback) is a clean
geometric sans. The institutional feel is preserved. No visual crisis.

**GSAP CDN failure:** The `[data-anim] { opacity: 1 }` rule (line 56) ensures all content
is visible even without GSAP. The page works as static HTML. This is already in place.

**Screen readers:** All removed visual elements are decorative. Content structure and semantic
HTML are preserved. Accessibility improves (less visual noise, simpler DOM).

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| Desktop 1920px screenshot | Clean, centered, generous whitespace |
| Mobile 375px screenshot | No horizontal scroll, readable, institutional feel |
| No lime overload | Count lime elements per section: max 1-2 per section |
| Leverage bars still work | Animated fill on scroll, correct values |
| Stat blocks still work | Full-viewport, big numbers, fade on scroll |
| Ticker still scrolls | Horizontal on desktop, vertical on mobile |
| Waitlist form submits | Email input + button functional |
| Load time | Should IMPROVE (less JS, no canvas, fewer animations) |

---

### Effort Estimate

**Large** — 1-2 days.
- Step 1 (remove dead elements): 1-2 hours (careful deletion, test after each removal)
- Steps 2-5 (restyle sections): 4-6 hours (the creative work)
- Steps 6-8 (global polish): 2 hours
- Step 9 (closing): 30 minutes
- Step 10 (testing): 1-2 hours

---

### Rollback Plan

```bash
cd /home/claude/lever-landing
git checkout -- index.html
```

The file is version-controlled and backup copies exist (index-v1 through v9).

---

### Open Questions

1. **T1 Robit vs. a more serious font:** T1 Robit has rounded terminals (matching the logo
   geometry) which gives it a slightly playful character. Master may want a more angular
   geometric sans for headlines (like Suisse Intl, Graphik, or Untitled Sans). This is a
   typography decision that should be confirmed before BUILD spends hours re-styling. The plan
   defaults to keeping T1 Robit since it is the brand font per the guidelines.

2. **Closing copy tone:** The current closing section has philosophical language about "truth"
   and "soul of the market." This plan replaces it with a single institutional line. If Master
   prefers the longer version, BUILD should keep it but restyle it (remove lime highlights,
   reduce font size, add more breathing room).

---

### KANBAN Update

Move LANDING-DESIGN to PLANNED.
