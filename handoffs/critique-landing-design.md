# Critique: LANDING-DESIGN — Redesign Landing Page to Institutional and Sophisticated
## Date: 2026-03-29T09:52:00Z
## Plan reviewed: handoffs/plan-landing-design.md
## Codebase verified against: /home/claude/lever-landing/index.html (1629 lines, last modified 03:51 UTC)

---

### Verdict: APPROVED (with notes)

The plan is well-structured for a design task: clear direction, section-by-section breakdown, and good identification of what to keep vs remove. Two design decisions are significant enough to warrant Master confirmation before BUILD spends hours executing.

---

### What Is Good

- Correct assessment: several grid elements are already `display:none` (hero-dial line 116, ec-grid-cluster line 453, ec::before line 452), confirming the "abandoned mid-build" diagnosis.
- Strong design principles: "lime is punctuation not paint," "restraint over flash," "confidence without explanation." These are clear guidelines BUILD can apply consistently.
- Good prioritization of what stays: leverage comparison bars, full-viewport stat blocks, and market ticker are correctly identified as the strongest existing elements.
- LANDING-MOBILE dependency noted (now DONE per KANBAN; the mobile overflow sources the redesign removes are already fixed).
- Rollback is trivial: `git checkout -- index.html` plus backup copies v1-v9.
- Step 1 (remove dead elements) is pure cleanup with no visual change; this derisks the rest.

---

### Issues Found

**1. [MEDIUM] Two significant creative decisions should be confirmed with Master before BUILD**

(a) **Removing the liquid physics canvas.** The plan says "institutional sites do not have liquid simulations." This is generally true, but Master has not explicitly said to remove the water animation. He called grid cells "trash," not the canvas. The canvas is a differentiator; removing it makes the page more generic. BUILD should confirm: does Master want the canvas gone, or just the grid cells?

(b) **Replacing the circular flywheel with a numbered list.** The flywheel is a core brand element (it illustrates the product's virtuous cycle). Going from a visual circle to a text list is a fundamental design shift. The plan's typography-only approach is cleaner, but it removes the visual metaphor entirely. Master should confirm the numbered-list direction.

If Master has already given direction on these (e.g., in the session-plan-final-review.md or TIMMY_PERSONALITY.md), BUILD should cite that and proceed. If not, a quick confirmation avoids a rework.

---

**2. [LOW] Open Question 1 (font choice) is unresolved**

The plan notes T1 Robit "has rounded terminals which give it a slightly playful character" and suggests Master may want a more angular font. If BUILD spends hours restyling with T1 Robit and Master later wants a different headline font, the rework is substantial (sizing, spacing, weight all change with the font). The plan defaults to keeping T1 Robit, which is reasonable (it is the brand font), but BUILD should not invest heavily in typography refinement until the font is confirmed.

---

**3. [LOW] Noise overlay removal is a judgment call**

The plan removes `body::after` noise overlay (lines 39-43). Subtle noise textures are actually common on institutional dark-theme sites (prevents the "pure OLED black" flat look). The overlay is at very low opacity and adds depth. BUILD should try with and without, and pick whichever looks more premium. Not a blocker.

---

**4. [LOW] File was modified after the plan was written**

Plan was written at 16:40 UTC March 28. File was last modified at 03:51 UTC March 29 (likely from LANDING-MOBILE work or IMPROVE workstream). Line numbers may have shifted slightly. File is now 1629 lines (plan references 1579). BUILD should use CSS class names and comment landmarks (e.g., `/* ========== SOLUTION ========== */`) to find sections rather than line numbers.

---

### Missing Steps

- Verify that LANDING-MOBILE fixes (already applied) are not regressed by the redesign. The mobile fixes (clamped pseudo-element, flywheel cap, canvas hidden on mobile) may conflict with redesign changes that remove those same elements entirely. If the redesign removes the canvas and flywheel SVG, the mobile fixes for those elements become irrelevant (which is fine, just note it).

---

### Edge Cases Not Covered

- **Waitlist form backend.** The plan resyles the waitlist box but doesn't verify the form submission still works after changes. BUILD should test that the email capture still functions.

---

### Simpler Alternative

If time is short, a "Phase 1 lite" could just do Steps 1 and 6 (remove dead elements + reduce lime saturation). This gets 70% of the institutional improvement with 20% of the effort. The section-by-section restyling (Steps 2-5) can follow as Phase 2.

---

### Revised Effort Estimate

Agreed: **Large** (1-2 days). This is creative work that requires design judgment at every step. BUILD should work iteratively: Step 1 first (pure cleanup), then hero, then flywheel, testing after each.

---

### Recommendation

**Send to BUILD** with these notes:

1. Confirm with Master (or cite existing direction) on: (a) removing the liquid physics canvas, (b) replacing the circular flywheel with a numbered list. These are the two irreversible creative decisions.
2. Work iteratively: Step 1 cleanup first, then one section at a time. Test after each.
3. Use class names and comment landmarks to find sections (line numbers shifted since plan was written).
4. Keep T1 Robit unless Master explicitly requests a font change.
5. LANDING-MOBILE fixes are already applied and will be made irrelevant by the redesign's removal of the same overflow sources. No conflict.
