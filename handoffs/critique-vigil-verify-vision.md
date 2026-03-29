# Critique: VIGIL-VERIFY-VISION — Browser Screenshots + Claude Vision for VERIFY
## Date: 2026-03-29T10:34:00Z
## Plan reviewed: handoffs/plan-vigil-verify-vision.md
## Infrastructure verified against actual system

---

### Verdict: APPROVED

All infrastructure claims verified. The plan bridges a real gap (CLAUDE.md says "use browser" but provides no actionable commands). The screenshot scripts are straightforward and all dependencies exist.

---

### What Is Good

- Correct root cause: VERIFY's CLAUDE.md gives instructions without tooling. Agents need copy-paste shell commands, not vague directives.
- All infrastructure verified:
  - Puppeteer Chrome: `/home/lever/.cache/puppeteer/chrome/linux-146.0.7680.76/chrome-linux64/chrome` (272MB, exists)
  - Standalone Chrome: `/home/lever/local-libs/standalone-chrome/chrome` (270MB, exists)
  - puppeteer-core: installed at `/home/lever/command/gstack/node_modules/`
- Two scripts (full-page + section-specific) cover the main use cases.
- The `console.log` capture and OVERFLOW detection are useful additions beyond simple screenshots.
- CLAUDE.md update with concrete commands is the right approach (agents execute commands, not interpret prose).
- Vision pipeline is confirmed: Claude Code's Read tool renders images to the model.

---

### Issues Found

**1. [MEDIUM] `page.waitForTimeout(2000)` is deprecated in modern Puppeteer**

Puppeteer deprecated `page.waitForTimeout()`. Use `await new Promise(r => setTimeout(r, 2000))` or `await page.evaluate(() => new Promise(r => setTimeout(r, 2000)))` instead. Depending on the installed puppeteer-core version, the deprecated method may still work but could log warnings.

---

**2. [LOW] The `cd /home/lever/command/gstack &&` prefix is fragile**

The scripts use `require('puppeteer-core')` which resolves relative to `process.cwd()` or `node_modules` in the module search path. The `cd gstack &&` prefix works but is easy to forget. A more robust approach: add the gstack `node_modules` path explicitly at the top of each script:

```javascript
module.paths.unshift('/home/lever/command/gstack/node_modules');
```

This makes the script work from any directory.

---

**3. [LOW] Full-page screenshots of long pages can be very large**

The landing page (1629 lines of HTML, many full-viewport sections) will produce a full-page PNG of 10-20MB. Claude Code can handle this, but it consumes context. The plan mentions this and provides the `-fold.png` (viewport-only) alternative, which is good. The CLAUDE.md instructions should recommend reading the `-fold.png` files first and only the full-page if needed.

---

### Missing Steps

None critical. The plan covers scripts, CLAUDE.md update, environment setup, and end-to-end testing.

---

### Recommendation

**Send to BUILD.** The plan is clear and all dependencies are verified. BUILD should note:

1. Replace `page.waitForTimeout(2000)` with a non-deprecated delay method.
2. Consider adding `module.paths.unshift(...)` to make scripts work from any directory.
3. In the CLAUDE.md update, recommend `-fold.png` screenshots first (smaller, faster to analyze).
