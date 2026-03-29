# Critique: LANDING-MOBILE — Fix Mobile Scroll and Side-Scroll Issues
## Date: 2026-03-29T05:15:00Z
## Plan reviewed: handoffs/plan-landing-mobile.md
## Codebase verified against: /home/claude/lever-landing/index.html (78929 bytes, last modified 03:51 UTC)

---

### Verdict: APPROVED

The plan correctly identifies all major overflow sources, proposes targeted CSS fixes that don't change the desktop design, and the line numbers match the actual code. Small corrections noted for BUILD.

---

### What Is Good

- All six overflow sources verified against the actual codebase:
  - `.solution::after` 1400px width (line 261): confirmed
  - `.fw-wheel` 520px at 1024px breakpoint (line 543): confirmed
  - Negative positions `right:-30px` / `left:-30px` (lines 309, 312): confirmed
  - Canvas missing `display: block` (lines 46-53): confirmed
  - `overflow-x: hidden` on html/body (lines 31, 36): confirmed, no `max-width: 100vw`
  - No `contain: paint` anywhere: confirmed
- Fixes are purely defensive CSS, no structural HTML changes, no visual regression on desktop.
- `min()` approach for clamping is clean and graceful degradation.
- Rollback is trivial (single file, git checkout).
- Correct that `npx serve` requires no restart for file changes.

---

### Issues Found

**1. [LOW] JS animation function is `loop` at line 1610, not `animate` at ~1470**

The plan's Step 5 references a function named `animate` at "~line 1470". The actual function is:
```javascript
function loop() {     // line 1610
    update();
    draw();
    requestAnimationFrame(loop);  // line 1613
}
```

BUILD should:
- Use the actual function name `loop`
- Insert the mobile guard at line 1610: `if (window.innerWidth < 769) return;`
- Note: once the rAF chain breaks (mobile return), it won't restart if the user rotates to landscape. For a landing page this is acceptable.

---

**2. [LOW] Step 2 uses `100vw` for flywheel height**

The plan proposes: `.fw-wheel { width:min(520px, 100%); height:min(520px, 100vw); }`

Using `100vw` for height = viewport WIDTH for height. On a 375px phone this gives a 375px square (correct for a circle), but `100vw` includes scrollbar width on some browsers and is semantically confusing. Recommend `min(520px, 100%)` for both width and height for consistency.

---

**3. [LOW] File has been modified since the plan was written**

The plan was written at 16:35 UTC on March 28. The file was last modified at 03:51 UTC on March 29 (possibly by IMPROVE workstream). Line numbers may have shifted slightly. BUILD should verify the specific CSS rules at the referenced lines before editing. Key landmarks:
- `.solution::after` is near line 259 (inside `/* SOLUTION */` comment block)
- `@media(max-width:1024px)` is near line 540
- The canvas IIFE starts near line 1396

---

### Missing Steps

None critical. All overflow sources are addressed.

---

### Edge Cases Not Covered

The plan covers landscape phones, iOS Safari bounce, and reduced motion. No additional edge cases identified.

---

### Simpler Alternative

None. The plan is already minimal (targeted CSS, one JS guard).

---

### Recommendation

**Send to BUILD.** The plan is clean and well-analyzed. BUILD should note:
1. The JS animation function is `loop` (line 1610), not `animate` (~1470).
2. Use `min(520px, 100%)` for flywheel height (not `100vw`).
3. Verify line numbers against the current file (modified after plan was written).
