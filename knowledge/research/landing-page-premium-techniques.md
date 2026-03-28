# Premium Landing Page Techniques Research
## For LEVER Protocol Dark-Mode Leveraged Trading Platform
### Research Date: 2026-03-28

---

## 1. CSS SCROLL-DRIVEN ANIMATIONS (Zero JavaScript)

**The technique:** Native CSS `animation-timeline: scroll()` and `animation-timeline: view()` let you tie any CSS animation to scroll position or element visibility. No JavaScript required. Runs on the browser compositor thread for guaranteed 60fps.

**Browser support:** Chrome 115+, Safari 26+ (shipped 2026), Firefox behind flag.

**Application to LEVER:** This is the backbone for the "grid awakens" concept. Grid cells can fade from dark to Electric Lime as the user scrolls, entirely in CSS.

### Scroll Progress Bar (top of page)

```css
.scroll-progress {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 3px;
  background: #E6FF2B;
  transform-origin: left;
  animation: scaleProgress linear;
  animation-timeline: scroll(root block);
}

@keyframes scaleProgress {
  from { transform: scaleX(0); }
  to { transform: scaleX(1); }
}
```

### Section Fade-In on Scroll (view-based)

```css
.section-reveal {
  opacity: 0;
  transform: translateY(40px);
  animation: fadeUp 0.6s ease both;
  animation-timeline: view();
  animation-range: entry 0% entry 40%;
}

@keyframes fadeUp {
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

### Grid Cell Activation Tied to Scroll

```css
.grid-cell {
  background: #1a1a1a;
  transition: background 0.3s;
  animation: activateCell 1s ease both;
  animation-timeline: view();
  animation-range: entry 10% entry 60%;
}

@keyframes activateCell {
  from { background: #1a1a1a; opacity: 0.3; }
  to { background: #E6FF2B; opacity: 1; }
}
```

**Performance:** Excellent. Compositor-thread only. No layout/paint thrashing. Best possible performance for scroll-linked effects.

**Vanilla CSS/JS in single HTML:** Yes, pure CSS. No libraries.

**Fallback:** For Firefox, use IntersectionObserver (see section 5).

---

## 2. GLOW AND DEPTH EFFECTS (CSS Only)

**The technique:** Layered `box-shadow` and `text-shadow` values create realistic, luminous glow effects. On dark backgrounds, this creates the "premium institutional" feel of Bloomberg terminals and trading dashboards.

### Electric Lime Glow on Cards

```css
.card-glow {
  background: rgba(230, 255, 43, 0.03);
  border: 1px solid rgba(230, 255, 43, 0.15);
  border-radius: 16px;
  box-shadow:
    0 0 15px rgba(230, 255, 43, 0.05),
    0 0 45px rgba(230, 255, 43, 0.03),
    inset 0 1px 0 rgba(230, 255, 43, 0.1);
  transition: box-shadow 0.4s ease, border-color 0.4s ease;
}

.card-glow:hover {
  border-color: rgba(230, 255, 43, 0.3);
  box-shadow:
    0 0 20px rgba(230, 255, 43, 0.1),
    0 0 60px rgba(230, 255, 43, 0.05),
    0 0 100px rgba(230, 255, 43, 0.02),
    inset 0 1px 0 rgba(230, 255, 43, 0.15);
}
```

### Headline Text Glow

```css
.headline-glow {
  color: #E6FF2B;
  text-shadow:
    0 0 10px rgba(230, 255, 43, 0.3),
    0 0 40px rgba(230, 255, 43, 0.15),
    0 0 80px rgba(230, 255, 43, 0.05);
}
```

### CTA Button with Glow Pulse

```css
.cta-button {
  background: #E6FF2B;
  color: #000;
  border: none;
  border-radius: 12px;
  padding: 14px 32px;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 0 20px rgba(230, 255, 43, 0.3);
  transition: box-shadow 0.3s ease, transform 0.3s ease;
}

.cta-button:hover {
  transform: translateY(-2px);
  box-shadow:
    0 0 30px rgba(230, 255, 43, 0.4),
    0 0 60px rgba(230, 255, 43, 0.2);
}
```

**Performance:** box-shadow is paint-only (no layout reflow). Transitions on box-shadow are acceptable for hover states. Avoid animating box-shadow continuously with keyframes (use opacity-based alternatives instead).

**Vanilla CSS/JS:** Pure CSS. No libraries.

---

## 3. GLASSMORPHISM ON DARK BACKGROUNDS

**The technique:** `backdrop-filter: blur()` on semi-transparent elements creates frosted-glass depth. On dark backgrounds with colored light sources behind them, this creates a premium layered effect.

### Glass Card for Dark Mode

```css
.glass-card {
  background: rgba(255, 255, 255, 0.04);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
}
```

### Glass Card with Lime Accent

```css
.glass-card-lime {
  background: rgba(230, 255, 43, 0.03);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid rgba(230, 255, 43, 0.1);
  border-radius: 16px;
  position: relative;
}

/* Gradient light source behind the card */
.glass-card-lime::before {
  content: '';
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  background: radial-gradient(
    circle at 30% 30%,
    rgba(230, 255, 43, 0.08) 0%,
    transparent 60%
  );
  z-index: -1;
  pointer-events: none;
}
```

**Performance:** backdrop-filter is GPU-intensive. Limit to 2-3 elements per viewport. Reduce blur to 6-8px on mobile. Never animate elements that have backdrop-filter applied.

**Vanilla CSS/JS:** Pure CSS. ~95% browser support.

---

## 4. WEBGL BACKGROUND EFFECTS (Lightweight)

### Option A: Stripe-Style Mesh Gradient (10kb)

**The technique:** A ~800-line WebGL shader creates animated mesh gradients. Stripe uses this for their hero. The key insight: the WebGL canvas is a simple rectangle; the visual effect comes from GLSL noise functions modulated by sinusoidal mesh distortion.

**Application to LEVER:** Instead of Stripe's rainbow, use Electric Lime (#E6FF2B) and Deep Teal (#0B4650) as the gradient colors on a black canvas. Creates an ambient "living" background behind the hero section.

```html
<canvas id="gradient-canvas" style="position:fixed;top:0;left:0;width:100%;height:100%;z-index:-1;opacity:0.3;"></canvas>
```

**Implementation reference:** GitHub Gist jordienr/64bcf75f8b08641f205bd6a1a0d4ce1d

**Performance:** ~10kb, runs entirely on GPU. 60fps. Minimal CPU impact.

**Can be embedded in single HTML:** Yes. The MiniGL class and Gradient class are vanilla JS. No npm/build required.

### Option B: Vanta.js Preset Effects

**The technique:** Vanta.js provides 12 preset WebGL backgrounds (Waves, Net, Dots, Topology, etc.) with ~3 lines of setup code. Total size ~120kb (mostly three.js).

**Application to LEVER:** The "Net" or "Dots" effect could complement the grid concept. Configure with Electric Lime color on black background.

```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r134/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/vanta/dist/vanta.net.min.js"></script>
<script>
VANTA.NET('#hero-bg', {
  color: 0xE6FF2B,
  backgroundColor: 0x000000,
  points: 8,
  maxDistance: 20,
  spacing: 16
});
</script>
```

**Performance:** Good but heavier than custom WebGL. Use IntersectionObserver to pause when not visible. Avoid on mobile.

### Option C: Custom Canvas Grid Animation (Recommended for LEVER)

**The technique:** A vanilla JS canvas that draws the brand grid pattern and animates cell activation. This is the most on-brand option: the grid IS the visual identity.

```javascript
const canvas = document.getElementById('grid-bg');
const ctx = canvas.getContext('2d');
const CELL_SIZE = 24;
const GAP = 4;
const RADIUS = 6;
const LIME = '#E6FF2B';
const DARK = '#111111';
const TEAL = '#0B4650';

let cells = [];
let scrollY = 0;

function initGrid() {
  const cols = Math.ceil(canvas.width / (CELL_SIZE + GAP));
  const rows = Math.ceil(canvas.height / (CELL_SIZE + GAP));
  cells = [];
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      cells.push({
        x: c * (CELL_SIZE + GAP),
        y: r * (CELL_SIZE + GAP),
        activation: 0, // 0 = dark, 1 = full lime
        targetActivation: 0
      });
    }
  }
}

function updateActivations() {
  const pageHeight = document.documentElement.scrollHeight - window.innerHeight;
  const progress = window.scrollY / pageHeight;
  cells.forEach((cell, i) => {
    // Activate cells based on scroll progress with stagger
    const cellProgress = (cell.y / canvas.height);
    const threshold = progress * 1.5;
    cell.targetActivation = cellProgress < threshold ? 1 : 0;
    // Smooth interpolation
    cell.activation += (cell.targetActivation - cell.activation) * 0.05;
  });
}

function drawCell(cell) {
  const alpha = 0.05 + cell.activation * 0.6;
  const r = Math.round(17 + cell.activation * (230 - 17));
  const g = Math.round(17 + cell.activation * (255 - 17));
  const b = Math.round(17 + cell.activation * (43 - 17));
  ctx.fillStyle = `rgba(${r},${g},${b},${alpha})`;
  ctx.beginPath();
  ctx.roundRect(cell.x, cell.y, CELL_SIZE, CELL_SIZE, RADIUS);
  ctx.fill();
}

function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  updateActivations();
  cells.forEach(drawCell);
  requestAnimationFrame(render);
}

window.addEventListener('scroll', () => { scrollY = window.scrollY; }, { passive: true });
window.addEventListener('resize', () => {
  canvas.width = window.innerWidth;
  canvas.height = document.documentElement.scrollHeight;
  initGrid();
});
initGrid();
render();
```

**Performance:** Very light. Canvas 2D is GPU-accelerated. Use `requestAnimationFrame` for paint sync. Pause with IntersectionObserver when not visible.

**Vanilla JS in single HTML:** Yes. Zero dependencies.

---

## 5. INTERSECTION OBSERVER STAGGERED REVEALS

**The technique:** Use IntersectionObserver (not scroll events) to detect when elements enter the viewport, then apply CSS transitions with staggered delays. This is what Stripe uses instead of scroll listeners.

**Why not scroll events:** Scroll events fire constantly and block the main thread. IntersectionObserver is asynchronous, batched, and handled by the browser's rendering pipeline.

### Implementation

```html
<style>
  .reveal {
    opacity: 0;
    transform: translateY(30px);
    transition: opacity 0.6s ease, transform 0.6s ease;
  }
  .reveal.visible {
    opacity: 1;
    transform: translateY(0);
  }
  /* Stagger children */
  .reveal.visible .stagger-child {
    opacity: 1;
    transform: translateY(0);
  }
  .stagger-child {
    opacity: 0;
    transform: translateY(20px);
    transition: opacity 0.5s ease, transform 0.5s ease;
  }
  .stagger-child:nth-child(1) { transition-delay: 0.1s; }
  .stagger-child:nth-child(2) { transition-delay: 0.2s; }
  .stagger-child:nth-child(3) { transition-delay: 0.3s; }
  .stagger-child:nth-child(4) { transition-delay: 0.4s; }
  .stagger-child:nth-child(5) { transition-delay: 0.5s; }
</style>

<script>
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target); // Only animate once
      }
    });
  }, {
    threshold: 0.15,
    rootMargin: '0px 0px -50px 0px'
  });

  document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
</script>
```

### Dynamic Stagger (for grid cells)

```javascript
document.querySelectorAll('.grid-cell').forEach((cell, index) => {
  cell.style.transitionDelay = `${index * 30}ms`;
});
```

**Performance:** Excellent. Zero main-thread cost during scroll. Animation uses only transform + opacity (compositor-only properties).

**Vanilla JS in single HTML:** Yes. No libraries.

---

## 6. PARALLAX DEPTH LAYERS (CSS-Only in 2026)

**The technique:** Use `animation-timeline: scroll(root)` with different animation speeds for different z-layers to create parallax. Zero JavaScript.

### CSS-Only Parallax

```css
.parallax-container {
  overflow: visible;
}

.layer-back {
  animation: parallaxSlow linear;
  animation-timeline: scroll(root);
}

.layer-mid {
  animation: parallaxMedium linear;
  animation-timeline: scroll(root);
}

.layer-front {
  /* No parallax, moves with scroll normally */
}

@keyframes parallaxSlow {
  from { transform: translateY(0); }
  to { transform: translateY(-200px); }
}

@keyframes parallaxMedium {
  from { transform: translateY(0); }
  to { transform: translateY(-100px); }
}
```

### Application to LEVER Grid

Create three grid layers at different depths:
- **Back layer:** Large, blurred grid cells (ambient), move slowest
- **Mid layer:** Medium cells, moderate parallax
- **Front layer:** Sharp, small cells, no parallax (content layer)

```css
.grid-layer-back .grid-cell {
  width: 48px;
  height: 48px;
  filter: blur(2px);
  opacity: 0.15;
  animation: parallaxSlow linear;
  animation-timeline: scroll(root);
}

.grid-layer-mid .grid-cell {
  width: 32px;
  height: 32px;
  opacity: 0.3;
  animation: parallaxMedium linear;
  animation-timeline: scroll(root);
}

.grid-layer-front .grid-cell {
  width: 24px;
  height: 24px;
  opacity: 0.6;
  /* Stationary */
}
```

**Performance:** Excellent. Transform-only animations on compositor thread.

**Vanilla CSS:** Yes, with animation-timeline support.

**Fallback:** For browsers without animation-timeline, use the classic `transform: translateZ()` with `perspective` on parent:

```css
.parallax-wrapper {
  perspective: 1px;
  height: 100vh;
  overflow-x: hidden;
  overflow-y: auto;
}

.layer-back {
  transform: translateZ(-2px) scale(3);
}

.layer-mid {
  transform: translateZ(-1px) scale(2);
}
```

---

## 7. GSAP SCROLLTRIGGER (If You Want Maximum Control)

**Status in 2026:** GSAP is now completely free for all uses (including commercial) after Webflow acquired GreenSock.

**When to use:** If the CSS scroll-driven animations have browser support gaps you can't accept, or if you need precise scrub-based control (e.g., the "Why Now" section where stats fill the viewport).

### Pin + Scrub for Full-Viewport Stats

```html
<script src="https://cdn.jsdelivr.net/npm/gsap@3/dist/gsap.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/gsap@3/dist/ScrollTrigger.min.js"></script>

<script>
gsap.registerPlugin(ScrollTrigger);

// Pin the Why Now section and scrub through stats
gsap.timeline({
  scrollTrigger: {
    trigger: '.why-now-section',
    start: 'top top',
    end: '+=400%', // 4 viewport-heights of scroll
    pin: true,
    scrub: 1
  }
})
.to('.stat-1', { opacity: 1, scale: 1, duration: 1 })
.to('.stat-1', { opacity: 0, duration: 0.5 }, '+=0.5')
.to('.stat-2', { opacity: 1, scale: 1, duration: 1 })
.to('.stat-2', { opacity: 0, duration: 0.5 }, '+=0.5')
.to('.stat-3', { opacity: 1, scale: 1, duration: 1 })
.to('.stat-3', { opacity: 0, duration: 0.5 }, '+=0.5')
.to('.stat-4', { opacity: 1, scale: 1, duration: 1 });

// Grid cell cascade animation
gsap.utils.toArray('.grid-cell').forEach((cell, i) => {
  gsap.to(cell, {
    backgroundColor: '#E6FF2B',
    opacity: 1,
    scrollTrigger: {
      trigger: cell,
      start: 'top 85%',
      end: 'top 50%',
      scrub: true
    }
  });
});
</script>
```

**Performance:** Excellent. GSAP is heavily optimized. Uses `will-change` and compositor properties internally.

**Single HTML file:** Yes. Two CDN script tags.

**File size:** ~30kb gzipped for gsap + ScrollTrigger.

---

## 8. STRIPE-LEVEL ANIMATION PRINCIPLES

From analyzing Stripe's implementation, these principles make animations feel premium:

### Only Animate Compositor Properties
```css
/* GOOD: compositor-only */
transform: translateX() translateY() scale() rotate();
opacity: 0...1;

/* BAD: triggers layout reflow */
width, height, top, left, margin, padding, font-size
```

### Custom Easing Curves (Not Built-in)
```css
/* Stripe-style custom curves */
--ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
--ease-out-quart: cubic-bezier(0.25, 1, 0.5, 1);
--ease-in-out-quint: cubic-bezier(0.83, 0, 0.17, 1);

.element {
  transition: transform 0.5s var(--ease-out-expo);
}
```

### Use will-change Sparingly
```css
/* Apply only when animation is about to start */
.element.about-to-animate {
  will-change: transform, opacity;
}

/* Remove after animation completes */
.element.done-animating {
  will-change: auto;
}
```

### Keep Durations Short
- Micro-interactions: 150-250ms
- Section reveals: 400-600ms
- Large transitions: 600-800ms max
- Never exceed 1s for any single animation

### Stagger, Never Simultaneous
```css
/* Sequential cascade, not a wall of motion */
.item:nth-child(1) { transition-delay: 0ms; }
.item:nth-child(2) { transition-delay: 60ms; }
.item:nth-child(3) { transition-delay: 120ms; }
.item:nth-child(4) { transition-delay: 180ms; }
```

---

## 9. LINEAR-STYLE DARK MODE BEST PRACTICES

From Linear's redesign approach:

### Color System
```css
:root {
  /* Use dark grays, not pure black (reduces eye strain) */
  --bg-primary: #0a0a0a;     /* Near-black, not #000 */
  --bg-elevated: #141414;     /* Cards, elevated surfaces */
  --bg-hover: #1a1a1a;        /* Hover states */
  --border-subtle: rgba(255, 255, 255, 0.06);
  --border-visible: rgba(255, 255, 255, 0.1);
  --text-primary: #f0f0f0;    /* Not pure white */
  --text-secondary: #888;
  --text-tertiary: #555;
}
```

NOTE: The LEVER spec calls for #000000 (Void Black). This is a brand decision. If it feels too harsh in practice, consider #050505 or #0a0a0a as a minimal concession. The Electric Lime will pop harder against true black, which may be worth the tradeoff.

### Subtle Borders Over Hard Lines
```css
.card {
  border: 1px solid rgba(255, 255, 255, 0.06);
  /* NOT: border: 1px solid #333; */
}
```

### Gradient Overlays for Depth
```css
.section {
  background:
    radial-gradient(ellipse at 50% 0%, rgba(230, 255, 43, 0.03) 0%, transparent 50%),
    #000000;
}
```

---

## 10. INSTITUTIONAL FINANCE DESIGN PATTERNS

From analyzing Bloomberg Terminal, Citadel, Jump Trading, and similar institutional sites:

### Key Characteristics
1. **Data density over white space.** Institutional sites pack information. They respect the viewer's intelligence.
2. **Monospace/tabular numbers.** All financial data uses monospace fonts with tabular figures for alignment.
3. **Muted color palettes with single accent.** One strong color (Bloomberg orange, LEVER lime) against neutrals.
4. **No decorative illustration.** Every visual element conveys data or structure.
5. **Subtle motion, never flashy.** Animations are functional (loading, transitions) not decorative.

### Application to LEVER

```css
/* Tabular numbers for all financial data */
.data-value {
  font-family: 'JetBrains Mono', monospace;
  font-variant-numeric: tabular-nums;
  font-weight: 700;
  color: #E6FF2B;
  letter-spacing: -0.02em;
}

/* Data-dense stat display */
.stat-large {
  font-size: clamp(48px, 10vw, 120px);
  font-weight: 700;
  line-height: 1;
  color: #E6FF2B;
}

/* Subtle separator lines */
.divider {
  height: 1px;
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(230, 255, 43, 0.15) 50%,
    transparent 100%
  );
}
```

---

## 11. PERFORMANCE CHECKLIST

| Technique | CPU | GPU | Mobile Safe | Single HTML |
|---|---|---|---|---|
| CSS scroll-driven animations | Minimal | Minimal | Yes | Yes |
| box-shadow glow effects | Low | Low | Yes (limit count) | Yes |
| backdrop-filter glass | Low | Medium | Limit to 2-3 | Yes |
| WebGL mesh gradient | Minimal | Medium | Use fallback | Yes |
| Vanta.js backgrounds | Medium | High | No | Yes (CDN) |
| Canvas grid animation | Medium | Low | Reduce cell count | Yes |
| IntersectionObserver reveals | Minimal | Minimal | Yes | Yes |
| CSS parallax layers | Minimal | Minimal | Yes | Yes |
| GSAP ScrollTrigger | Low | Low | Yes | Yes (CDN) |

---

## 12. RECOMMENDED IMPLEMENTATION PRIORITY

For a single-HTML-file implementation of the LEVER landing page:

### Must Have (core experience)
1. **IntersectionObserver staggered reveals** for all sections
2. **CSS glow effects** (box-shadow, text-shadow) for Electric Lime elements
3. **CSS scroll-driven animations** for grid cell activation (with JS fallback)
4. **Custom easing curves** on all transitions
5. **prefers-reduced-motion** media query respect

### Should Have (premium layer)
6. **Canvas grid background** that activates on scroll (the brand visual)
7. **Glassmorphism cards** for problem/solution sections (2-3 max)
8. **CSS parallax** on grid depth layers
9. **Gradient overlays** for subtle section differentiation

### Nice to Have (wow factor)
10. **GSAP ScrollTrigger** for the "Why Now" full-viewport stat scroll-through
11. **WebGL mesh gradient** as hero background (lime + teal on black)
12. **Continuous ticker animation** for Markets section

### Do Not Use
- Heavy 3D libraries (Three.js full, Babylon.js)
- Particle systems beyond the grid concept
- Lottie animations
- Scroll hijacking (users hate it)
- Autoplay video backgrounds

---

## 13. ACCESSIBILITY

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

Always implement this. It is a legal requirement in many jurisdictions and respects users with vestibular disorders.

---

## SOURCES

- [Stripe Mesh Gradient WebGL Gist](https://gist.github.com/jordienr/64bcf75f8b08641f205bd6a1a0d4ce1d)
- [WebGL Gradient Deconstructed](https://alexharri.com/blog/webgl-gradients)
- [Stripe Connect Front-End Experience](https://stripe.com/blog/connect-front-end-experience)
- [CSS Scroll-Driven Animations MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Scroll-driven_animations)
- [Chrome Scroll-Triggered Animations](https://developer.chrome.com/blog/scroll-triggered-animations)
- [CSS-Tricks Parallax with Scroll-Driven CSS](https://css-tricks.com/bringing-back-parallax-with-scroll-driven-css-animations/)
- [Smashing Magazine Scroll-Driven Animations Intro](https://www.smashingmagazine.com/2024/12/introduction-css-scroll-driven-animations/)
- [Codrops Scroll-Driven Animations Practical Intro](https://tympanus.net/codrops/2024/01/17/a-practical-introduction-to-scroll-driven-animations-with-css-scroll-and-view/)
- [GSAP ScrollTrigger Docs](https://gsap.com/docs/v3/Plugins/ScrollTrigger/)
- [Linear UI Redesign](https://linear.app/now/how-we-redesigned-the-linear-ui)
- [Linear-Style Design Trends](https://medium.com/design-bootcamp/the-rise-of-linear-style-design-origins-trends-and-techniques-4fd96aab7646)
- [Glassmorphism Implementation Guide](https://playground.halfaccessible.com/blog/glassmorphism-design-trend-implementation-guide)
- [Vanta.js](https://www.vantajs.com/)
- [VFX-JS WebGL Effects](https://tympanus.net/codrops/2025/01/20/vfx-js-webgl-effects-made-easy/)
- [Builder.io Parallax in 2026](https://www.builder.io/blog/parallax-scrolling-effect)
- [Fintech SaaS Landing Pages](https://designrevision.com/blog/fintech-saas-landing-pages)
- [Stripe Animation Performance (Quora)](https://www.quora.com/What-does-Stripe-do-to-make-all-their-animations-so-performant)
