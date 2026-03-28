# Plan: LANDING-MOBILE — Fix Mobile Scroll and Side-Scroll Issues
## Date: 2026-03-28T16:35:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

The LEVER landing page at `/home/claude/lever-landing/index.html` has horizontal scrolling
(side-scroll) on mobile devices. Master checks the site on his phone. Horizontal scroll on a
single-page marketing site looks broken and feels cheap. It undermines the "institutional,
sophisticated, premium" design goal.

The page is a single 1579-line HTML file with embedded CSS and JS, served via `npx serve` on
port 3001 at `landing.xmarket.app`.

---

### Root Causes Identified

After reading the full codebase, these are the elements causing or contributing to horizontal
overflow on mobile:

#### 1. `.solution::after` pseudo-element: 1400px wide (lines 259-264)

```css
.solution::after {
  content:''; position:absolute; top:50%; left:50%;
  width:1400px; height:800px; transform:translate(-50%,-50%);
  background:radial-gradient(ellipse, rgba(var(--lime-rgb),.04)...);
}
```

The pseudo-element is 1400px wide. `position: absolute` with `transform: translate(-50%, -50%)`
centers it, but the left half extends 700px past the section's left edge and the right half
700px past the right edge. While `section { overflow: hidden }` (line 59) should contain it,
some mobile browsers handle the paint area of large pseudo-elements inconsistently. The element
is purely decorative (a subtle radial glow) and should be clamped.

#### 2. `.fw-wheel` at 1024px breakpoint: fixed 520px width (line 543)

```css
@media(max-width:1024px) {
  .fw-wheel { width:520px; height:520px; }
}
```

On devices between 768px and 1024px (small tablets, landscape phones), the flywheel is fixed
at 520px. The section has `overflow: hidden`, but if any child (node with `right: -30px`) pokes
out, it could cause layout width calculation to extend past the viewport.

At 768px breakpoint, the flywheel switches to vertical layout (line 564), which is correct.
The gap is between 520px+padding and 768px viewport width.

#### 3. Flywheel nodes at negative positions (lines 295-312)

```css
.fwn:nth-child(3) { top:28%; right:-30px; }
.fwn:nth-child(6) { top:28%; left:-30px; }
```

Nodes 3 and 6 extend 30px beyond the `.fw-wheel` container. The 768px mobile breakpoint
overrides this with `position: relative !important` and resets all insets. But at 769-1024px,
these negative positions are active and the 520px wheel + 30px overflow = 550px, which overflows
on narrow tablets.

#### 4. Canvas element rendering (lines 46-53, 1397-1406)

```css
#liquidCanvas { position:fixed; inset:0; width:100%; height:100%; }
```
```javascript
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
```

Setting `canvas.width` in JS sets the drawing surface resolution, not the CSS size. On high-DPI
devices, the canvas intrinsic size could be larger than the CSS size. While `position: fixed` +
`width: 100%` should contain it, missing `display: block` means the canvas is rendered as inline
(default), which can add unexpected whitespace or layout artifacts.

#### 5. Ticker padding on mobile (lines 622-626)

```css
.ticker-track {
  flex-direction:column; gap:12px; width:100%; padding:0 24px;
  animation-name:ticker-v; animation-duration:30s;
}
```

`width: 100%` with `padding: 0 24px` on a `box-sizing: border-box` element: the padding is
included in 100%, so total width is 100% (correct). But the parent `.ticker-wrap` also lives
inside a section, and the `.wrap` container adds its own padding. If these nest incorrectly,
content can push past the viewport.

#### 6. No `max-width: 100vw` safety net on body/html

While `overflow-x: hidden` is set on both `html` and `body` (lines 31, 36), some mobile
browsers (especially iOS Safari) can still allow bounce-scroll to reveal horizontal overflow.
Adding a hard `max-width: 100vw` as a safety net prevents this.

---

### Approach

Apply targeted CSS fixes to each overflow source. No structural HTML changes needed. The fixes
are all defensive CSS that eliminates overflow without changing the visual design.

---

### Implementation Steps

**Step 1: Clamp the `.solution::after` pseudo-element**

Change lines 259-264:

FROM:
```css
.solution::after {
  content:''; position:absolute; top:50%; left:50%;
  width:1400px; height:800px; transform:translate(-50%,-50%);
  background:radial-gradient(ellipse, rgba(var(--lime-rgb),.04) 0%, rgba(var(--lime-rgb),.01) 35%, transparent 60%);
  pointer-events:none; z-index:0;
}
```

TO:
```css
.solution::after {
  content:''; position:absolute; top:50%; left:50%;
  width:min(1400px, 200vw); height:min(800px, 120vh); transform:translate(-50%,-50%);
  background:radial-gradient(ellipse, rgba(var(--lime-rgb),.04) 0%, rgba(var(--lime-rgb),.01) 35%, transparent 60%);
  pointer-events:none; z-index:0;
}
```

`min(1400px, 200vw)` caps the width at twice the viewport on small screens (a 375px phone gets
750px wide glow instead of 1400px). The gradient is so subtle that the size reduction is
invisible. `200vw` is generous enough to cover the full visible area with the radial gradient.

---

**Step 2: Fix flywheel at 1024px breakpoint**

Add a cap to the flywheel and remove negative positioning at tablet size. Change the 1024px
media query (line 543):

FROM:
```css
@media(max-width:1024px) {
  .fw-wheel { width:520px; height:520px; }
  .fwn { width:160px; padding:20px 14px; }
}
```

TO:
```css
@media(max-width:1024px) {
  .fw-wheel { width:min(520px, 100%); height:min(520px, 100vw); }
  .fwn { width:160px; padding:20px 14px; }
  .fwn:nth-child(3) { right:0; }
  .fwn:nth-child(6) { left:0; }
}
```

`min(520px, 100%)` prevents the wheel from exceeding its container. The negative-position
nodes are brought back to the edge. The visual change is minimal (nodes sit at the edge
instead of 30px past it).

---

**Step 3: Add `display: block` to canvas**

Change line 46-53:

FROM:
```css
#liquidCanvas {
  position: fixed;
  inset: 0;
  z-index: 1;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
```

TO:
```css
#liquidCanvas {
  position: fixed;
  inset: 0;
  z-index: 1;
  width: 100%;
  height: 100%;
  display: block;
  pointer-events: none;
}
```

`display: block` eliminates the inline-element layout quirks. This is standard practice for
canvas elements.

---

**Step 4: Add global overflow safety net**

Add to the top of the CSS (after the `body` rule at line 36):

```css
html, body { max-width: 100vw; }
```

This is a belt-and-suspenders fix. Even if some child element tries to push wider, the root
elements cap at viewport width. Combined with `overflow-x: hidden`, this eliminates bounce-scroll
horizontal overflow on iOS Safari.

---

**Step 5: Disable canvas on small mobile (performance)**

The liquid physics canvas runs a continuous animation with springs/particles. On low-end phones
this is a performance drain and the effect is barely visible on small screens.

Add to the 768px media query (around line 607):

```css
#liquidCanvas { display: none; }
```

And in the JavaScript, guard the animation loop (around line 1470):

```javascript
function animate() {
  if (W < 769) return;  // skip animation on mobile
  // ... rest of animation
  requestAnimationFrame(animate);
}
```

This saves battery and prevents any canvas-related rendering issues on mobile.

---

**Step 6: Fix any remaining overflow sources with containment**

Add `contain: paint` to sections that have large decorative elements:

```css
.solution { contain: paint; }
.flywheel { contain: paint; }
```

`contain: paint` tells the browser that nothing inside this element paints outside its bounds.
This is a stronger guarantee than `overflow: hidden` for paint-only effects like gradients and
pseudo-elements.

---

**Step 7: Test on real devices**

Verify fixes on:
- iPhone 15 (390px viewport): no horizontal scroll, no bounce-reveal
- iPhone SE (375px): no horizontal scroll, flywheel renders as vertical timeline
- iPad Mini (768px): flywheel at edge, no negative nodes visible
- Android phone (360px): no horizontal scroll

Test method: serve locally or deploy to `landing.xmarket.app`, then check on Master's phone.
For automated testing: use Puppeteer with mobile emulation:

```javascript
const page = await browser.newPage();
await page.setViewport({ width: 375, height: 812, isMobile: true, deviceScaleFactor: 3 });
await page.goto('http://localhost:3001');
// Check document width equals viewport width (no overflow)
const docWidth = await page.evaluate(() => document.documentElement.scrollWidth);
const viewWidth = await page.evaluate(() => window.innerWidth);
console.assert(docWidth === viewWidth, `Horizontal overflow: doc=${docWidth}, vp=${viewWidth}`);
```

---

### Files to Modify

- `/home/claude/lever-landing/index.html`
  - Lines 46-53: add `display: block` to canvas
  - Lines 259-264: clamp `.solution::after` width
  - Line 36 area: add `max-width: 100vw` to html/body
  - Lines 543-544: cap `.fw-wheel` and reset negative positions at 1024px
  - Line 607 area: hide canvas on mobile
  - Lines 258, 286: add `contain: paint` to solution and flywheel sections
  - JS section (~line 1470): guard canvas animation for mobile

### Files to Create

None.

### Files to Read First

- `/home/claude/lever-landing/index.html` — full file (it is the entire app)

---

### Dependencies and Ripple Effects

- **No build step.** The landing page is a single HTML file served by `npx serve`. Edit the
  file and the changes are live immediately.

- **Port 3001.** Served via `npx serve` on port 3001. No restart needed for file changes
  (serve watches the directory).

- **CDN/Cache.** If behind Cloudflare or similar, cache may need purging. Check if
  `landing.xmarket.app` has caching enabled.

- **GSAP dependency.** The page uses GSAP (loaded from CDN) for scroll animations. The CSS
  changes do not affect GSAP. The JS change (canvas guard) is independent of GSAP.

- **Visual design unchanged.** All fixes are containment and clamping. The desktop experience
  is identical. The only visible changes are on mobile:
  - Canvas water effect hidden on phones (performance gain)
  - Flywheel nodes sit at container edge instead of 30px past it (barely noticeable)
  - Solution glow is slightly smaller on phones (invisible since it is already at 4% opacity)

---

### Edge Cases

**Landscape phones (667px wide, 375px tall):** The 768px breakpoint is not hit. Content uses
the 1024px breakpoint rules. The flywheel fix (`min(520px, 100%)`) ensures it fits within 667px.
The solution glow is clamped at `min(1400px, 200vw) = 1334px`, well within the section's
`overflow: hidden`.

**iOS Safari bounce scroll:** iOS Safari allows over-scrolling with elastic bounce, which can
briefly reveal horizontal overflow. `max-width: 100vw` + `overflow-x: hidden` on html/body
prevents the content from being wider than the viewport, eliminating the bounce-reveal.

**Reduced motion preference:** The CSS already has `.reduced-motion` rules (line 651). Hiding
the canvas on mobile is consistent with this approach (less motion = better).

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `document.documentElement.scrollWidth === window.innerWidth` at 375px | No horizontal overflow on iPhone |
| `document.documentElement.scrollWidth === window.innerWidth` at 390px | No horizontal overflow on iPhone 15 |
| `document.documentElement.scrollWidth === window.innerWidth` at 768px | No horizontal overflow on iPad |
| Visual check: no horizontal scrollbar visible | User-facing confirmation |
| Canvas not visible at 375px | Performance optimization active |
| Flywheel renders as vertical timeline at 375px | Mobile layout correct |
| Solution section glow visible at 375px | Glow scales down gracefully |
| Desktop at 1920px unchanged | No regression |

---

### Effort Estimate

**Small** — 1-2 hours.
- CSS fixes: 30 minutes (6 targeted changes)
- JS canvas guard: 10 minutes
- Testing on mobile viewports: 30-60 minutes

---

### Rollback Plan

Revert `index.html` to current version. The file is static HTML with no dependencies.
```bash
cd /home/claude/lever-landing
git checkout -- index.html
```

---

### Open Questions

None. The fixes are defensive CSS that eliminate overflow without changing the design. No
Master approval needed for the approach; these are standard mobile web best practices.

---

### KANBAN Update

Move LANDING-MOBILE to PLANNED.
