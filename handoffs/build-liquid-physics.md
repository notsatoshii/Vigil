# BUILD Handoff: Liquid Physics Background + Loader Overhaul

**Date:** 2026-03-28
**Workstream:** BUILD
**File changed:** /home/claude/lever-landing/index.html
**Backup:** /home/claude/lever-landing/index-v9-backup.html

## Task

Major overhaul of the landing page background system and loader animation.

## What Was Done

### 1. Spinning Logo Loader
- Replaced the old `loader-pulse` animation (scale + opacity breathing) with a `loader-spin` animation
- The LEVER logo SVG in the page loader now rotates 360 degrees on a 1.2s ease-in-out infinite loop
- Set explicit width/height of 60px on the SVG

### 2. Removed Broken WebGL Fluid System
- Removed the `<canvas id="fluidCanvas">` element from the HTML body
- Removed the `canvas#fluidCanvas` CSS block (fixed position, z-index 0)
- Removed the `<script type="importmap">` block that imported webgl-fluid-enhanced from esm.run
- Removed the entire `<script type="module">` block (~140 lines) containing the webGLFluid initialization, pointer event passthrough, scroll-reactive splat system, and flywheel ambient splats
- Updated the void stat drama section to reference `liquidCanvas` instead of `fluidCanvas`
- Updated the library comment header to remove "WebGL Fluid" reference

### 3. Built Custom Liquid Physics Background (Canvas 2D)
- Created a new `<script>` block (placed before `</body>`, after GSAP scripts) implementing a spring-based 2D water surface
- The canvas is dynamically created and inserted as the first child of `<body>`
- CSS: `#liquidCanvas` is fixed position, `inset: 0`, `z-index: 1`, `pointer-events: none`
- Physics system: ~216 springs across viewport width (one per ~7px), Hooke's law with damping, 4-pass wave propagation per frame
- Water level rises from 95% viewport (barely visible at bottom) to 40% viewport as user scrolls from top to bottom
- Mouse interaction creates splashes when cursor is within 150px of the water surface
- Ambient sine waves keep the surface alive even without interaction
- Gradient fill: Electric Lime (#E6FF2B) at surface (0.12 opacity) fading to Deep Teal (#0B4650) at bottom (0.03 opacity)
- Bright lime meniscus line (0.2 opacity) drawn along the wave surface
- Smooth interpolation (0.03 lerp factor) toward target water level

## Decisions Made

- The liquid canvas sits at z-index 1 (between background at 0 and content at 2), with pointer-events: none so all clicks pass through
- Opacity values are deliberately low (0.03 to 0.12) for a subtle ambient effect, not a prominent foreground feature
- The animation loop starts 500ms after page load to avoid competing with the loader

## Screenshots

- `/tmp/liquid-test.png` (hero view, top of page)
- `/tmp/liquid-scrolled.png` (scrolled to position 5000, markets section)

## Issues Found

- None. The page renders cleanly with no console errors from the removed WebGL system.

## What Is Left

- Nothing required. The liquid background is functional and subtle.
- Optional: could add touch event support for mobile splash interaction
- Optional: could reduce spring count on mobile for performance (currently handled by the same density)
