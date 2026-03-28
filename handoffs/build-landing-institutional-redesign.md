# BUILD Handoff: Landing Page Institutional Redesign

**Date:** 2026-03-28
**Task:** Master said the grids "look like trash, tacky, not modern, classy, and sophisticated." Redesign for institutional look.

## What Was Done

Complete visual overhaul of the grid system, effects, and animations across the entire landing page. No HTML content was changed. All modifications were CSS and JS only.

### Grid System (biggest change)
- **Removed:** Random floating rounded rectangles (g-cell system) with parallax, drift animations, and scroll-driven opacity/glow arcs
- **Replaced with:** Structured CSS grid lines (60px major grid, 20px subdivision) at very low opacity (0.035 and 0.015), like engineering graph paper
- **Added:** Sparse intersection dots (grid-dot class) that gently brighten (opacity 0.06 to 0.12) as you scroll near them
- No more random positioning, no more blur, no more neon glow

### Effects Removed or Reduced
- All box-shadow glow effects removed from: nav CTA, leverage bars, solution blocks, flywheel nodes, LP APY, trust dots, thermo cells, ticker cards, hero dial pills, divider dots, closing box, closing CTA, follow buttons
- All text-shadow effects removed from: hero h1 lime text, LP APY number, stat numbers, ticker probabilities
- Shimmer animation on leverage bars removed
- Hero pulse animation removed
- Closing pulse animation removed
- Loader pulse glow removed
- Pill glow animation removed
- Grid glow animation (edge complete grid) removed
- cg-pulse animation (closing grid) removed

### Section Ambient Glows (::before radial gradients)
- All reduced by approximately 50% opacity
- solution: 0.08 to 0.04
- flywheel: 0.06 to 0.03
- for-lps: 0.07 to 0.035
- why-now: 0.09 to 0.045
- edge: 0.06 to 0.03
- closing: 0.14 to 0.06, and pulsing animation removed

### Edge Section
- Removed 4x4 pixel-art grid clusters from all three cards
- Replaced red top-border with subtle 2px left-border in gray
- Removed LEVER "complete grid" of glowing squares, replaced with clean card with lime left-border accent
- Removed the edge-box box-shadow and gradient background

### Closing Section
- Removed dense grid background (JS and CSS)
- Removed closing box glow (box-shadow, gradient background)
- Clean border, minimal background

### Why Now Stats
- Removed mini-grid backgrounds behind each stat (both CSS display:none and removed JS that populated them)
- Numbers stand alone, clean typography
- Void "0" simplified: no text-shadow pulsing, lower opacity (0.35)

### Scroll Animations
- Removed blur(4px) from all scroll animations
- Reduced translateY distances (60px to 32px, 25px to 16px, etc.)
- Increased minimum transition duration to 1.2s (was 0.9s)

### 3D Tilt
- Reduced to only problem cards and edge cards (removed from solution blocks, edge box, closing box, flywheel nodes, ticker cards)
- Reduced rotation range from 6deg to 2deg

## Files Changed
- `/home/claude/lever-landing/index.html` (all CSS and JS within this single file)

## Backup
- `/home/claude/lever-landing/index-v5-backup.html`

## What Is Left
- Master review and feedback on the new look
- If Master wants even more restraint, the section ::before radial gradients could be removed entirely
- The flywheel circuit dot animation could be simplified further
- Mobile testing recommended

## Design Philosophy Applied
- Bloomberg/Citadel/Two Sigma aesthetic: quiet confidence, not shouting
- Typography does the work, not effects
- Lime appears flat and precise, never as a glow or neon spread
- Generous dark space replaces visual noise
- Grid lines suggest structure and precision (graph paper, trading terminal)
- Animations are slow (1.2s+) and use only opacity + translateY
