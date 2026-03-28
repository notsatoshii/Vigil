# BUILD Handoff: Landing Page Major Visual Overhaul
**Date:** 2026-03-28
**Workstream:** BUILD

## Task
Aggressively improve the LEVER landing page based on the Landing Page Spec v3, focusing on the "Grid Awakens" visual concept and several section-level improvements.

## What Was Done

### 1. Replaced Liquid Drop System with Grid Cell System
- Removed all circular `.drop` elements (border-radius:50%, radial-gradient circles)
- Replaced with `.g-cell` rounded rectangles (border-radius:8px) matching the logo geometry
- Cells exist at varying depths with parallax, varying aspect ratios (slightly rectangular)
- Hero section has floating grid cells with subtle drift animation
- Same visual arc logic preserved but tuned for grid narrative: dormant -> awakening -> ignition -> alive -> void -> recovery -> maximum -> rest

### 2. Why Now Section: Full-Viewport Scroll-Through Stats
- Each stat ($63B, $20B+, $130B+, 0) now occupies nearly a full viewport height
- Stats animate in (scale + fade) when they enter view, and animate out when they leave
- Numbers count up with easeOutExpo when the stat enters the viewport
- Each stat (except the void "0") has a subtle grid background of small rounded squares, some lit in lime
- The "0" stat is special: no grid background, void radial gradient, ivory color (not lime), the entire grid field fades to near-invisible when "0" is centered

### 3. Competitive Edge Section: Grid Clusters
- Each of the three "incomplete" cards now has a visible 4x4 grid cluster at the top
- Card 1 (leverage without liquidity): lime squares with dark gaps, showing disconnection
- Card 2 (liquidity without risk): teal squares with cracks and fading, showing fragility
- Card 3 (risk without leverage): hollow gray outlines only, showing emptiness
- The LEVER card now has a complete 8x3 grid of fully-lit Electric Lime squares with a glow pulse animation
- Updated card text to match spec exactly ("It only works if all three exist.")

### 4. Closing/CTA Section: Maximum Grid Activation
- Added dense grid background behind the entire closing section
- Grid cells include "lit" and "bright" variants with pulse animations
- Grid fades in when section enters viewport
- Enhanced closing box glow (stronger box-shadow)
- Added animated radial gradient pulse behind the section

### 5. Animation Choreography
- Grid field visual arc is carefully tuned across the full scroll:
  - Hero: low intensity, dormant, scattered lime
  - Problem: building intensity
  - Solution: ignition peak
  - Flywheel/LPs: steady active state
  - Markets: alive
  - Why Now: dense, then dramatic void at "0" (grid field opacity drops to near-zero)
  - Recovery after void
  - Edge + Closing: maximum activation
  - Footer: fading to rest
- Void section causes the entire fixed grid field to fade out, creating visceral emptiness

### 6. Text Fixes
- Replaced en-dash in "3-8% APY" with "3 to 8% APY" (no dashes rule)
- Replaced em-dash in "converging -- right now" with comma
- Changed "it's" to "it is" in closing box for consistency
- Fixed "it doesn't" to "it does not" in markets note

## Files Changed
- `/home/claude/lever-landing/index.html` (complete rewrite)
- `/home/claude/lever-landing/index-v4-backup.html` (backup of previous version)

## What Is Left To Do
- The spec calls for a leverage dial in the hero section (two pill-shaped elements). Not implemented yet; the current hero watermark (rotating logo) works but could be replaced.
- The flywheel circuit trace could be enhanced with tiny grid dots along the path instead of dashed lines.
- The LP gauge could be converted from SVG arc to a vertical grid thermometer (stack of square cells filling from bottom).
- Mobile testing needed; responsive rules are in place but not validated on actual devices.
- The spec mentions neumorphic text treatment on "leverage" in the hero headline. Not implemented.

## Decisions Made
- Kept the overall HTML structure and section ordering identical to prevent breakage
- Used CSS grid for the stat background grids and closing grid (performant, no canvas)
- Kept the flywheel SVG circle approach (works well, spec-compliant in spirit)
- Used IntersectionObserver for stat-fullpage visibility (re-triggers on scroll in/out)
- Maintained all existing functionality: waitlist forms, ticker, nav, progress bar, tilt effects

## Issues Found
- None blocking. The page is functional and all improvements are additive.

## Recommendations for Next Session
- Test on live server to validate visual impact
- Consider adding the leverage dial hero visual
- Fine-tune the grid cell density and animation timing after seeing it live
- The closing grid could benefit from a more dynamic pattern (cells lighting up in sequence)
