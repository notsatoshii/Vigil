# BUILD Handoff: Landing Page Polish v2

**Date:** 2026-03-28
**Workstream:** BUILD
**File:** /home/claude/lever-landing/index.html
**Backup:** /home/claude/lever-landing/index-v8-backup.html

## Task

Final visual polish pass on the LEVER landing page. Eight specific CSS and HTML refinements.

## What Was Done

1. **Hero ambient glow (stronger):** Increased radial gradient from 1000px to 1400px with higher opacity (.08/.04 to .12/.06). Added a second, larger (2000px), dimmer radial glow behind it for depth. Pulse animation now breathes from scale 0.9 to 1.3 (was 1.0 to 1.08).

2. **Closing box text readability:** Changed font-weight from 700 to 500, line-height from 1.9 to 2.1, added word-spacing: 0.02em. Padding increased to clamp(56px, 7vw, 96px).

3. **Edge cards breathing room:** Gap increased from 16px to 24px. Card padding increased from 40px 30px to 48px 36px. Card paragraph font-size increased from 16px to 17px.

4. **LP APY visual weight:** Font-size changed to clamp(64px, 8vw, 96px). Added text-shadow with subtle lime glow: 0 0 60px rgba(230,255,43,0.15).

5. **Ambient glow blobs opacity:** Lime blobs increased from .07/.05 to .09/.07. Teal blobs increased from .1/.08 to .12/.1.

6. **Hero watermark:** SKIPPED. No `.hero-watermark` element exists in the current file. If a rotating logo watermark is desired, it would need to be added as a new element.

7. **Stat fullpage initial values:** Changed initial text content from "$0B", "$0B+", "$0B+" to "$63B", "$20B+", "$130B+" so numbers display correctly before scroll triggers fire. GSAP ScrollTrigger scrub still overwrites these on scroll.

8. **Divider center dots:** Increased dot size from 5px to 9px (adjusted top offset to -4px to keep centered). Added a second box-shadow layer for subtle lime glow: 0 0 16px rgba(lime, .15).

## Files Changed

- `/home/claude/lever-landing/index.html` (CSS values and 3 HTML text nodes)

## What Is Left

- Hero watermark (rotating logo) does not exist yet. If desired, needs a new HTML element and CSS added.
- No JS was modified; all GSAP, Lenis, and fluid simulation code untouched.

## Notes

- The LP APY font-size was already larger than the requested minimum (was clamp(76px,10vw,120px)). Changed to clamp(64px,8vw,96px) per the spec, which is slightly smaller on very large screens but now has the lime text-shadow for visual weight. If the original size was preferred on desktop, it can be reverted to the previous clamp values.
