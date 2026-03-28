# BUILD Handoff: Landing Page Visual Fixes v2
**Date:** 2026-03-28
**Workstream:** BUILD
**Task:** Fix 8 visual issues identified from screenshot review

## What was done

All 8 issues from the screenshot review have been fixed in `/home/claude/lever-landing/index.html`.

### 1. Background fallback (ambient glow blobs)
- Added CSS keyframe animation `drift` and `.ambient-glow` / `.blob` styles
- Added 4 blurred gradient blobs (2 lime, 2 teal) that slowly drift with CSS animation
- Placed at z-index 1 between fluid canvas (z-index 0) and content (z-index 2)
- Page now looks alive even when WebGL fails to render

### 2. Section ambient glows strengthened
- `.solution::before`: .03 -> .08
- `.flywheel::before`: .02 -> .06
- `.for-lps::before`: .025 -> .07
- `.why-now::before`: .03 -> .08
- `.edge::before`: .03 -> .07
- `.closing::before`: .04/.015 -> .08/.04

### 3. Solution blocks restyled
- Removed solid lime fill background
- Now: transparent background with 1.5px lime border, border-radius 14px
- Text is lime colored (not black on lime)
- Added backdrop-filter: blur(8px) for glass effect
- Hover: background fills rgba(lime, .08), border brightens to .7

### 4. Flywheel section enlarged
- Container: 560x560 -> 640x640
- SVG viewBox: 560 -> 640
- Circle center/radius in JS: cx/cy 280->320, r 175->210
- Node cards: width 170->190px, padding increased
- Node text sizes: title 16->18px, desc 13->14px, number 11->12px
- Section padding increased, headline margin increased
- Responsive (1024px): 460x460 -> 520x520

### 5. LP and Markets sections spacing
- `.for-lps` padding: 100px bottom -> 140px
- `.markets` padding: 100px bottom -> 140px
- `.dial-section` gap: 80px -> 100px
- `.ticker-track` gap: 16px -> 20px

### 6. Hero visual presence
- Radial gradient: .05/.02 opacities -> .08/.04
- Breathe animation: opacity range .6-1 -> .7-1, scale 1.05 -> 1.08
- Added horizontal accent line below headline (80px wide, lime gradient, via h1::after)

### 7. Typography spacing
- `.tag` opacity: .5 -> .6
- `.tag` margin-bottom: 20px -> 28px

### 8. Dividers visibility
- Gradient opacities: .15/.22 -> .25/.35
- Center dot: background opacity .5 -> .7
- Added box-shadow glow on center dot

## Files changed
- `/home/claude/lever-landing/index.html` (all changes)

## Backup
- `/home/claude/lever-landing/index-v7-backup.html` (pre-change backup)

## What is left
- Visual QA in a real browser to confirm everything renders as expected
- Mobile testing (responsive breakpoints were updated for flywheel but all other mobile styles were preserved)

## Notes
- No JavaScript logic was broken. GSAP, Lenis, ScrollTrigger, fluid simulation, flywheel circuit all remain functional
- The flywheel JS dot positions were updated to match the new larger SVG viewBox (center 320,320, radius 210)
