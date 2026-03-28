# PLAN: Landing Page Visual Overhaul v2
**Date:** 2026-03-28
**Status:** DRAFT, awaiting critique

## Vision

The page should feel like walking into a private capital desk that happens to be on a spaceship. Institutional confidence meets bleeding-edge web3 energy. The key tension: restrained layout and typography (Stripe, Aave, Linear) combined with a living, reactive fluid background that says "this is not your father's finance."

The fluid IS the metaphor: liquidity filling the pool, capital activating, the product coming alive.

## Research Summary

Studied: Aave, Stripe Connect, Linear, Vercel landing pages. Analyzed GSAP ScrollTrigger, Lenis smooth scroll, WebGL fluid simulations (Pavel Dobryakov, WebGL-Fluid-Enhanced). Read Codrops tutorials on cinematic scroll experiences and 2026 finance design trends.

Key insight from research: the best institutional sites use restraint in layout/typography but ONE standout visual element that makes them memorable. For Stripe, it's the gradient. For Linear, it's the smooth scroll choreography. For us, it's the reactive fluid.

---

## Architecture

### Layer Stack (back to front)
1. **Void Black background** (#000000)
2. **WebGL fluid canvas** (fixed, fullscreen, transparent, z-index 0)
3. **Content sections** (scrollable, z-index 2)
4. **Navigation** (fixed, z-index 100)

### Libraries (loaded via CDN/ESM)
- **GSAP 3.13.0 + ScrollTrigger** (free, CDN) for scroll-linked animations, pinning, scrubbing
- **Lenis** (free, CDN) for buttery smooth scroll
- **webgl-fluid-enhanced** (MIT, ESM import) for reactive fluid background

---

## The Fluid Background

### Concept
A WebGL fluid simulation runs behind all content. The fluid uses LEVER's color palette: primarily Electric Lime (#E6FF2B) with traces of Deep Teal (#0B4650). On void black, the lime fluid creates an organic, bioluminescent feel.

### Scroll-Reactive Behavior
The fluid is NOT just ambient decoration. It responds to the page narrative:

| Scroll Position | Fluid Behavior |
|---|---|
| Hero (0-15%) | Subtle, dormant. One or two faint lime wisps drifting slowly. Low density. The page is waking up. |
| Problem (15-30%) | Fluid gets slightly turbulent. Small splats in Deep Teal. Something is wrong. |
| Solution (30-40%) | IGNITION. Programmatic burst of lime splats from center. The fluid comes alive. This is the "aha" moment. |
| Flywheel (40-55%) | Steady circular motion. Periodic splats that follow the flywheel's rhythm. System in motion. |
| For LPs (55-65%) | Fluid rises from bottom. Filling up. Capital entering the pool. Lime intensity building. |
| Markets (65-75%) | Horizontal drift matching ticker direction. Alive and flowing. |
| Why Now (75-85%) | Dense and active. On the "0" stat: fluid DRAINS. Dissipation cranked up. Everything fades to near-black. Void. |
| Edge + Closing (85-95%) | Maximum activation. Dense lime fluid everywhere. The pool is full. |
| Footer (95-100%) | Fluid slowly dissipates. Returns to dormant. The arc completes. |

### Configuration
```javascript
{
  SIM_RESOLUTION: 128,
  DYE_RESOLUTION: 1024,
  DENSITY_DISSIPATION: 3.5,       // fades relatively quickly for clean look
  VELOCITY_DISSIPATION: 2.0,
  PRESSURE: 0.1,
  COLOR_PALETTE: ['#E6FF2B', '#0B4650'],  // lime + teal only
  BACK_COLOR: { r: 0, g: 0, b: 0 },
  TRANSPARENT: true,
  BLOOM: true,                     // subtle glow
  BLOOM_INTENSITY: 0.15,           // very restrained
  BLOOM_THRESHOLD: 0.4,
  SPLAT_RADIUS: 0.3,
  SPLAT_FORCE: 4000,
  HOVER: true,                     // mouse interaction
  TRIGGER: 'hover'
}
```

### Why This Works
- Fluid simulation is GPU-accelerated, 60fps even on mobile
- The color palette is locked to brand colors only (no rainbow chaos)
- High dissipation means the fluid fades fast, keeping the page clean
- Bloom is barely visible (0.15 intensity), adding depth without neon glow
- Mouse interaction makes it feel alive and responsive
- Programmatic splats tied to scroll create a narrative connection

---

## Animation System (GSAP + Lenis)

### Lenis Smooth Scroll
Wraps the native scroll in interpolated easing. Makes every scroll gesture feel weighted and intentional. This alone transforms the page from "HTML site" to "experience."

```javascript
const lenis = new Lenis({
  duration: 1.4,
  easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
  smoothWheel: true
});
```

### GSAP ScrollTrigger Animations

**Hero parallax layers:**
- Headline moves at 0.8x scroll speed
- Subhead at 0.9x
- CTA at 1.0x (normal)
- Creates depth without any visible background elements

**Why Now stat pinning:**
- Each stat pins to viewport center
- Number scrubs from 0 to target value tied directly to scroll position (not time-based counter)
- Scroll 20% of section height = number at 20% of target
- Feels like YOU are controlling the data
- On "0" stat: the fluid canvas opacity drops to near-zero (CSS transition on canvas element)

**Section entrance choreography:**
- Headlines: translateY(40px) to 0, opacity 0 to 1, duration 1.2s, ease "power3.out"
- Body text: same but 120ms stagger per line
- Cards: same but 100ms stagger per card
- No blur. No scale. Just clean vertical movement and opacity.

**Markets ticker scrub:**
- Horizontal scroll tied to vertical scroll via GSAP scrub
- User scrolls down, ticker moves left proportionally
- Direct causality between input and output

**LP gauge scrub:**
- Thermometer fill tied to scroll position via GSAP scrub
- APY number updates in real-time as scroll progresses
- Feels like dragging a slider

---

## Typography and Spacing Improvements

### Increase whitespace
- Section padding: 140px vertical (up from 110px)
- Between headline and body: 32px (up from 24px)
- Max content width stays at 1200px but hero headline max-width reduced to 800px for tighter line lengths

### Typography refinements
- Hero headline: increase to clamp(48px, 6.5vw, 96px)
- Remove letter-spacing on headlines (let T1 Robit's natural spacing breathe)
- Body text line-height: 1.75 (up from 1.65)
- Stats in Why Now: clamp(120px, 22vw, 280px) with font-weight 700

### Color discipline
- Remove all box-shadow glow effects (already done in v5)
- Lime appears ONLY in: headlines, CTA buttons, accent text, active states, and the fluid
- Cards/containers: borders in rgba(255,255,255,0.06), not lime
- Hover states: border goes to rgba(255,255,255,0.12), NOT lime

---

## Edge Section Redesign

Three cards, clean and simple:
- Thin top border in Steel Gray (2px)
- On scroll-enter (GSAP), border transitions to white at 8% opacity
- Card headline in Soft Ivory (not lime), T1 Robit 700
- Card body in Steel Gray
- No grid clusters, no icons, no decorations

LEVER card below:
- Thin top border in Electric Lime (2px)
- Subtle lime gradient at top: linear-gradient(180deg, rgba(lime, 0.04) 0%, transparent 40%)
- Text in Soft Ivory, "LEVER:" in lime
- No grid of glowing squares

---

## Closing Section

- No background grid or dense effects
- The fluid behind is at maximum activation (handled by scroll-reactive splats)
- Closing box: 1px border in rgba(255,255,255,0.08), generous padding
- CTA: clean, centered, the lime button is the ONLY strong color element in this section
- The contrast between the living fluid behind and the clean, still content in front creates tension

---

## Implementation Order

1. Add CDN/ESM imports (GSAP, Lenis, webgl-fluid-enhanced)
2. Strip old grid system (grid-field, grid-dots, all related JS)
3. Add WebGL fluid canvas and configure
4. Wire scroll-reactive splat system
5. Initialize Lenis smooth scroll
6. Convert all animations from vanilla IntersectionObserver to GSAP ScrollTrigger
7. Implement hero parallax layers
8. Implement Why Now stat pinning with scrub
9. Implement Markets ticker scrub
10. Implement LP gauge scrub
11. Refine typography and spacing
12. Clean up Edge and Closing sections
13. Mobile optimization pass
14. Performance testing

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| WebGL fluid too heavy on mobile | Reduce SIM_RESOLUTION to 64, disable BLOOM on mobile |
| GSAP CDN fails to load | Graceful fallback: page works without animations (opacity defaults to 1) |
| Fluid colors look wrong | Lock palette to exactly 2 colors, high dissipation keeps it clean |
| Smooth scroll conflicts with GSAP | Lenis has native GSAP integration, well-documented |
| Page feels "too dark" without grid | The fluid provides ambient light; sections have subtle radial gradients |

---

## What We Keep (unchanged)
- All content/copy
- HTML section structure
- Waitlist form functionality
- Ticker content
- Flywheel structure
- Nav structure
- Mobile hamburger menu
- Footer
