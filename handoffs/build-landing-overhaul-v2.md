# BUILD Handoff: Landing Page Visual Overhaul v2
**Date:** 2026-03-28
**Status:** COMPLETE

## Task
Major visual overhaul of the LEVER landing page. Strip old grid system and vanilla parallax. Replace with WebGL fluid simulation, GSAP ScrollTrigger animations, and Lenis smooth scroll. Make the page feel alive, reactive, and institutional.

## What Was Done

### Libraries Added (via CDN/ESM)
- GSAP 3.13.0 + ScrollTrigger (CDN)
- Lenis 1.1.18 smooth scroll (CDN)
- webgl-fluid-enhanced (ESM import map)

### Stripped
- All `.grid-field`, `.grid-dot`, grid generation JS
- Old vanilla `requestAnimationFrame` scroll handler (the master scroll controller)
- Old `IntersectionObserver` animation triggers (replaced with GSAP ScrollTrigger)
- Old `[data-anim]` CSS transitions (GSAP handles all entrance animations now)
- Box-shadow glow effects
- `backdrop-filter:blur(4px)` on ticker cards
- Old letter-spacing overrides on headlines
- Closing box inner border and inset box-shadow
- `scroll-behavior:smooth` from HTML (Lenis handles this)

### Added
1. **WebGL fluid canvas** (fixed, fullscreen, z-index 0, transparent)
   - Color palette locked to Electric Lime + Deep Teal
   - BLOOM enabled on desktop, disabled on mobile
   - SIM_RESOLUTION 128 desktop / 64 mobile
   - Mouse hover interaction enabled
   - Click passthrough to content beneath via event forwarding

2. **Scroll-reactive fluid splats** tied to GSAP ScrollTrigger zones:
   - Hero: subtle splats on load (1.2s and 2.4s delay)
   - Problem: small teal turbulence splats
   - Solution: BIG lime burst from center (ignition moment)
   - Flywheel: periodic ambient splats on 2s interval while in viewport
   - For LPs: splats rising from bottom edge
   - Markets: horizontal splats matching ticker direction
   - Edge + Closing: maximum activation, dense lime splats
   - Cooldown system prevents splat spam

3. **Lenis smooth scroll** with GSAP ticker integration

4. **GSAP ScrollTrigger animations:**
   - All `[data-anim]` elements use GSAP `from()` with ScrollTrigger
   - Hero parallax layers (h1 at -80px, sub at -40px, ctas at -20px, opacity fade)
   - Why Now stat scrub (numbers count with scroll position, not time)
   - Markets ticker scrub on desktop (horizontal scroll tied to vertical)
   - LP gauge scrub via ScrollTrigger
   - Void stat drama (vignette, fluid opacity drain)
   - Nav scroll state via ScrollTrigger
   - Scroll progress bar via GSAP scrub
   - Solution blocks choreography via GSAP

5. **Typography and spacing:**
   - Hero headline: clamp(48px, 6.5vw, 96px)
   - Section padding: 140px vertical
   - Body line-height: 1.75
   - Removed letter-spacing overrides on headlines

6. **Edge section redesign:**
   - Cards: thin top border in Steel Gray (2px), no left border
   - Card headlines in Soft Ivory (not lime)
   - LEVER card: lime top border, subtle gradient background
   - Grid clusters remain hidden via display:none

7. **Closing section:**
   - Clean 1px white border at 8% opacity
   - No inner border, no inset box-shadow
   - Fluid behind provides visual energy

8. **Graceful fallback:** `[data-anim] { opacity: 1; }` default so content is visible if GSAP fails

## Files Changed
- `/home/claude/lever-landing/index.html` (full overhaul)
- `/home/claude/lever-landing/index-v6-backup.html` (backup of previous version)

## What Is Left
- Performance testing on actual mobile devices
- Verify webgl-fluid-enhanced ESM import loads correctly in production (CDN dependency)
- Consider adding a fallback static gradient if WebGL context creation fails
- The `<title>` tag contains an em-dash from the original; could be changed to a colon if desired
- Potential tuning of fluid dissipation values after seeing it live
- The flywheel periodic splat interval (2s) may need adjustment based on feel

## Decisions Made
- Kept CSS ticker animation on mobile (vertical), only GSAP scrub on desktop
- Used event forwarding on canvas for click passthrough rather than z-index tricks
- Set default `[data-anim] { opacity: 1 }` for graceful degradation
- Removed closing box inner border per plan (cleaner look)
- Edge card headlines changed from lime to ivory per plan spec

## Issues Found
- None blocking. The webgl-fluid-enhanced library loads via ESM import map from esm.run, which is a third-party CDN. If that CDN is down, the fluid won't load but the page will still function.

## Recommendations
- VERIFY session should test: (1) fluid loads and responds to mouse, (2) scroll animations fire correctly, (3) mobile performance is acceptable, (4) all links and forms still work, (5) no content was lost
