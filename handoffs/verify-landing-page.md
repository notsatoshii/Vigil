# VERIFY: Landing Page Review
**Date:** 2026-03-28
**File reviewed:** /home/claude/lever-landing/index.html

---

## Summary

The landing page is well-structured overall. HTML is valid, CSS is clean, JavaScript is functional, and responsive breakpoints are solid. There are a handful of real issues that need fixing, listed below by severity.

---

## MUST FIX

### 1. Em-dash in title tag (Rule violation)
- **Line 6:** `<title>LEVER — The Leverage Layer for Prediction Markets</title>`
- The `—` character is an em-dash. This violates the absolute "no em-dashes" rule.
- **Fix:** Replace with a colon or hyphen: `LEVER: The Leverage Layer for Prediction Markets`

### 2. Waitlist form has no submit handler
- **Lines 888, 1126:** Both waitlist forms (`<div class="wl-box">`) have email inputs and "Join" buttons, but there is zero JavaScript handling the submit action.
- Clicking "Join" does nothing. No form submission, no API call, no feedback, no validation.
- The buttons are `<button>` elements inside a `<div>`, not inside a `<form>` tag, so there is no native form behavior either.
- **Fix:** Add JS to handle button click: validate email, POST to a backend/service (e.g., Mailchimp, a serverless function), show success/error state.

### 3. Off-brand color: red gradient on edge cards
- **Line 553:** `.ec::before` uses `rgba(255,80,80,.4)` (a red) as the top-edge gradient on all three "Why LEVER" edge cards.
- Red is not in the brand palette (Electric Lime, Void Black, Deep Teal, Soft Ivory, Steel Gray).
- **Fix:** Replace with a brand color. Suggestion: `rgba(var(--lime-rgb),.4)` or `rgba(var(--teal-rgb),.4)`.

### 4. Off-brand color: button hover state
- **Line 252:** `.wl-box button:hover { background:#f0ff60; }`
- `#f0ff60` is a lighter lime but is not the brand Electric Lime `#E6FF2B`. This is a minor deviation, but for strict brand compliance it should either use the brand lime or a defined variant.
- **Fix:** Either keep as intentional hover lightening (acceptable UX pattern) or use a CSS filter/opacity approach on the brand color.

---

## SHOULD FIX

### 5. Docs link goes nowhere
- **Line 1103:** `<a href="#">Docs</a>` in the footer links to `#` (top of page). This will confuse users.
- **Fix:** Either link to actual docs, remove the link, or add a "Coming soon" tooltip.

### 6. Flywheel setInterval never cleared
- **Line 1571:** `setInterval(pulse, 2000)` is started when the flywheel section enters view but is never cleared. It runs forever even when the user scrolls far away. Minor memory/CPU concern.
- **Fix:** Use the IntersectionObserver to also stop the interval when the section leaves view.

### 7. No input validation or type="submit" on waitlist buttons
- The email inputs have `type="email"` (good for mobile keyboards) but the buttons have no `type` attribute. Without a `<form>` wrapper, there is no native validation trigger.
- **Fix:** When adding the submit handler (issue #2), also add basic email validation and visual feedback (loading state, success message, error for invalid email).

---

## MINOR / INFORMATIONAL

### 8. White highlight effects (acceptable)
- Lines 290, 296, 350 use `rgba(255,255,255,...)` for subtle shine/gloss effects on bars and blocks. These are decorative highlights, not brand colors. Acceptable.

### 9. `will-change` usage
- Line 99: `section { will-change:transform; }` is applied to ALL sections on desktop. This is a broad use of `will-change` which promotes every section to its own compositor layer. Could increase memory usage on lower-end machines. Not critical but worth noting.

### 10. Animation performance
- All animations use `transform` and `opacity` (GPU-friendly). Good.
- The grid cell field creates up to 180+20=200 DOM elements dynamically, each with scroll-driven style updates via `requestAnimationFrame`. This is reasonable and well-throttled with the `ticking` pattern.

### 11. Responsive design
- Three breakpoints: 1024px, 768px, 400px. Covers tablet, mobile, and small mobile.
- Mobile: hides noise overlay, stat grids, closing grids (good performance choices).
- Flywheel switches from absolute-positioned wheel to stacked layout on mobile.
- Nav collapses to hamburger menu with proper open/close toggle.
- All looks correct.

### 12. HTML structure
- All tags are properly closed. `<section>` count: 9 open, 9 close. `<div>` count: 130 open, 130 close.
- DOCTYPE, html lang, meta charset, viewport meta all present.
- No broken script or style blocks.

### 13. CSS variables
- All CSS variables are defined in `:root` and consistently used throughout.
- No undefined variable references found.

### 14. JavaScript
- No syntax errors detected.
- All `getElementById` / `querySelector` calls reference existing elements.
- Null checks present (e.g., `if(!fill || !section) return`).
- All IntersectionObservers properly configured.

---

## What was done
- Full read of the 1633-line single-file landing page
- Checked HTML tag balance (sections, divs)
- Searched for em-dashes and en-dashes
- Audited all hex color values and rgba values against brand palette
- Verified all internal anchor links resolve to existing IDs
- Reviewed all JavaScript for syntax, null safety, and event handling
- Checked responsive media queries
- Reviewed animation performance patterns

## What files were changed
- None (this is a review-only session)

## Recommendations for next session
1. Fix the em-dash in the title tag (highest priority, rule violation)
2. Implement waitlist form submission handler
3. Replace the red gradient on edge cards with a brand color
4. Decide on the Docs link (remove or point somewhere)
5. Consider clearing the flywheel interval on scroll-away
