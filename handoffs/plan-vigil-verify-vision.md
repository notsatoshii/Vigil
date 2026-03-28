# Plan: VIGIL-VERIFY-VISION — Browser Screenshots + Claude Vision for VERIFY
## Date: 2026-03-28T16:55:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

VERIFY's CLAUDE.md says "Open the browser via Puppeteer/Chromium and look at it like a user"
(Pass 2, line 82). But no VERIFY session has ever actually launched a browser, taken screenshots,
or used vision to evaluate visual output. The session-plan-final-review.md explicitly flags this:

> "VERIFY Does Not Use Browser Testing. VERIFY's CLAUDE.md says 'use Chromium browser' but no
> verification session has actually launched Puppeteer. Screenshots are not being taken. Claude
> vision is not being used to evaluate visual output."

> "Root cause: Writing instructions in CLAUDE.md does not make it happen. The agent needs
> explicit tooling setup."

The infrastructure EXISTS but is not connected:
- Chrome binary: `/home/lever/local-libs/standalone-chrome/chrome` (336MB, fully installed)
- Puppeteer cache: `/home/lever/.cache/puppeteer/chrome/linux-146.0.7680.76/`
- puppeteer-core: installed in `/home/lever/command/gstack/node_modules/`
- gstack browser CLI: Playwright-based with `screenshot` command
- Working screenshot script: `/home/claude/lever-landing/screenshot.js`
- 56 historical QA screenshots in `/home/lever/screenshots/`

The gap is that VERIFY's CLAUDE.md gives vague instructions ("open the browser") instead of
concrete, copy-paste shell commands that the agent can execute.

---

### Root Cause Analysis

Claude Code agents execute tasks by running shell commands and reading files. For VERIFY to
take and analyze screenshots, it needs:

1. **A shell command that takes a screenshot** (saves a PNG file)
2. **A file read that triggers vision** (Claude Code's Read tool renders images visually)

Step 1 requires a working Puppeteer command with the correct Chrome binary path. Step 2 is
already built into Claude Code (the Read tool displays images to the model).

The CLAUDE.md currently says WHAT to do but not HOW. The agent sees "take screenshots" and
either skips it (no actionable command) or tries ad-hoc Puppeteer scripts that fail because
the Chrome path is not specified.

---

### Approach

Three deliverables:

**A. Screenshot helper script** — a standalone Node.js script at a known path that VERIFY
can call with one command. Takes screenshots at multiple viewports and saves to a predictable
location.

**B. CLAUDE.md update** — replace vague Pass 2 instructions with concrete shell commands
that the VERIFY agent copies and runs.

**C. Environment setup** — set `PUPPETEER_EXECUTABLE_PATH` in the system so Puppeteer
finds Chrome without per-command configuration.

---

### Implementation Steps

**Step 1: Create the screenshot helper script**

New file: `/home/lever/command/tools/screenshot.js`

```javascript
#!/usr/bin/env node
/**
 * Visual QA Screenshot Tool
 * Usage: node /home/lever/command/tools/screenshot.js <url> [output-dir]
 *
 * Takes screenshots at 3 viewports:
 *   - desktop (1920x1080)
 *   - tablet (768x1024)
 *   - mobile (375x812)
 *
 * Saves to output-dir (default: /tmp/verify-screenshots/)
 * Files: desktop.png, tablet.png, mobile.png, console.log
 */

const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const CHROME_PATH = '/home/lever/.cache/puppeteer/chrome/linux-146.0.7680.76/chrome-linux64/chrome';
const FALLBACK_CHROME = '/home/lever/local-libs/standalone-chrome/chrome';

const url = process.argv[2];
const outDir = process.argv[3] || '/tmp/verify-screenshots';

if (!url) {
  console.error('Usage: node screenshot.js <url> [output-dir]');
  process.exit(1);
}

fs.mkdirSync(outDir, { recursive: true });

const viewports = [
  { name: 'desktop', width: 1920, height: 1080 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'mobile', width: 375, height: 812, isMobile: true, deviceScaleFactor: 2 }
];

(async () => {
  const execPath = fs.existsSync(CHROME_PATH) ? CHROME_PATH : FALLBACK_CHROME;

  const browser = await puppeteer.launch({
    executablePath: execPath,
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu', '--disable-dev-shm-usage']
  });

  const consoleLog = [];

  for (const vp of viewports) {
    const page = await browser.newPage();
    await page.setViewport(vp);
    page.on('console', msg => consoleLog.push(`[${vp.name}] ${msg.type()}: ${msg.text()}`));
    page.on('pageerror', err => consoleLog.push(`[${vp.name}] ERROR: ${err.message}`));

    try {
      await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 });
      await page.waitForTimeout(2000); // let animations settle

      // Full page screenshot
      await page.screenshot({
        path: path.join(outDir, `${vp.name}.png`),
        fullPage: true
      });

      // Viewport-only screenshot (above the fold)
      await page.screenshot({
        path: path.join(outDir, `${vp.name}-fold.png`),
        fullPage: false
      });

      // Check for horizontal overflow
      const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
      const clientWidth = await page.evaluate(() => document.documentElement.clientWidth);
      if (scrollWidth > clientWidth) {
        consoleLog.push(`[${vp.name}] OVERFLOW: scrollWidth=${scrollWidth} > clientWidth=${clientWidth}`);
      }
    } catch (err) {
      consoleLog.push(`[${vp.name}] NAVIGATION FAILED: ${err.message}`);
    }

    await page.close();
  }

  // Save console log
  fs.writeFileSync(path.join(outDir, 'console.log'), consoleLog.join('\n'));

  await browser.close();

  console.log(`Screenshots saved to ${outDir}/`);
  console.log(`  desktop.png, desktop-fold.png`);
  console.log(`  tablet.png, tablet-fold.png`);
  console.log(`  mobile.png, mobile-fold.png`);
  console.log(`  console.log (${consoleLog.length} entries)`);
  if (consoleLog.some(l => l.includes('OVERFLOW'))) {
    console.log('  WARNING: Horizontal overflow detected!');
  }
})();
```

This script:
- Uses puppeteer-core (already installed in gstack)
- Finds Chrome binary at known paths (no env var needed)
- Takes 6 screenshots (full-page + above-fold for 3 viewports)
- Captures console errors and horizontal overflow
- Saves to `/tmp/verify-screenshots/` by default

**Test the script:**
```bash
cd /home/lever/command/gstack
node /home/lever/command/tools/screenshot.js http://localhost:3000
ls /tmp/verify-screenshots/
```

---

**Step 2: Create a section-specific screenshot script**

New file: `/home/lever/command/tools/screenshot-section.js`

For landing page and multi-section pages, take per-section screenshots:

```javascript
#!/usr/bin/env node
/**
 * Section Screenshot Tool
 * Usage: node screenshot-section.js <url> <css-selector> [output-path]
 *
 * Screenshots a specific element/section. Useful for comparing before/after.
 */

const puppeteer = require('puppeteer-core');
const fs = require('fs');

const CHROME_PATH = '/home/lever/.cache/puppeteer/chrome/linux-146.0.7680.76/chrome-linux64/chrome';
const FALLBACK_CHROME = '/home/lever/local-libs/standalone-chrome/chrome';

const [,, url, selector, outPath] = process.argv;

if (!url || !selector) {
  console.error('Usage: node screenshot-section.js <url> <selector> [output.png]');
  process.exit(1);
}

(async () => {
  const execPath = fs.existsSync(CHROME_PATH) ? CHROME_PATH : FALLBACK_CHROME;
  const browser = await puppeteer.launch({
    executablePath: execPath,
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });
  await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 });
  await page.waitForTimeout(1000);

  const el = await page.$(selector);
  if (el) {
    await el.screenshot({ path: outPath || '/tmp/section-screenshot.png' });
    console.log(`Saved: ${outPath || '/tmp/section-screenshot.png'}`);
  } else {
    console.error(`Selector "${selector}" not found on page`);
    process.exit(1);
  }

  await browser.close();
})();
```

---

**Step 3: Update VERIFY's CLAUDE.md with actionable commands**

Replace Pass 2 (lines 81-89) with concrete instructions:

```markdown
#### Pass 2: Visual/Design Verification
Open the browser and look at affected pages like a user.

**How to take screenshots:**
```bash
# Full page at all viewports (desktop, tablet, mobile):
cd /home/lever/command/gstack && node /home/lever/command/tools/screenshot.js http://localhost:3000 /tmp/verify-screenshots

# Specific section:
cd /home/lever/command/gstack && node /home/lever/command/tools/screenshot-section.js http://localhost:3000 ".hero" /tmp/hero.png

# Landing page:
cd /home/lever/command/gstack && node /home/lever/command/tools/screenshot.js http://localhost:3001 /tmp/verify-landing
```

**How to review screenshots visually:**
After taking screenshots, READ the PNG files. Claude Code renders images visually.
```
Read /tmp/verify-screenshots/desktop-fold.png
Read /tmp/verify-screenshots/mobile-fold.png
```

Review for:
- Layout broken (elements overlapping, misaligned, cut off)
- Mobile horizontal scroll (check console.log for OVERFLOW warnings)
- Design consistency (spacing, alignment, color accuracy)
- Text readability (contrast, font size, line length)
- Empty states (blank sections, $0.00, missing data)
- Console errors (check /tmp/verify-screenshots/console.log)

**For the LEVER trading frontend** (localhost:3000):
- Navigate to each page: Markets, Trading, Vault, Positions
- Check that market data loads (not showing $0.00 or blank)
- Check that position cards render correctly
- Verify mobile layout does not side-scroll

**For the landing page** (localhost:3001):
- Check hero, problem, solution, flywheel, for-lps, markets, why-now, edge, closing, footer
- Verify no horizontal scroll on mobile (375px viewport)
- Verify lime accent usage matches brand guidelines

**If screenshots fail:** Check console.log output. Common issues:
- Chrome not found: verify `/home/lever/.cache/puppeteer/chrome/linux-146.0.7680.76/chrome-linux64/chrome` exists
- Page timeout: the service may be down. Check `systemctl status lever-frontend`.
- Navigation error: wrong URL or port.
```

---

**Step 4: Add screenshot to the verdict template**

Update VERIFY's output format (CLAUDE.md line 120-124) to include screenshot evidence:

```markdown
### Output

Structured verdict report with screenshot evidence:
- **PASS**: Code clean, tests pass, browser QA clean. Attach desktop + mobile screenshots.
- **FAIL**: Specific issues with screenshots showing the problem. Back to BUILD.
- **PASS WITH CONCERNS**: Works but has visual or non-blocking issues. Screenshots attached.

Include in every verdict:
- Desktop screenshot path (or "N/A - no frontend changes")
- Mobile screenshot path
- Console error count
- Horizontal overflow: yes/no
```

---

**Step 5: Set PUPPETEER_EXECUTABLE_PATH system-wide (optional, belt-and-suspenders)**

Add to `/home/lever/.bashrc` or `/home/lever/.profile`:

```bash
export PUPPETEER_EXECUTABLE_PATH="/home/lever/.cache/puppeteer/chrome/linux-146.0.7680.76/chrome-linux64/chrome"
```

This allows ANY Puppeteer script to find Chrome without hardcoded paths. The screenshot scripts
already have hardcoded paths as fallback, so this is optional but good practice.

---

**Step 6: Test the full flow end-to-end**

Simulate a VERIFY session:

```bash
# 1. Take screenshots of the frontend
cd /home/lever/command/gstack
node /home/lever/command/tools/screenshot.js http://localhost:3000 /tmp/verify-test

# 2. Verify files exist
ls -la /tmp/verify-test/

# 3. Check console log
cat /tmp/verify-test/console.log

# 4. Check for overflow
grep OVERFLOW /tmp/verify-test/console.log

# 5. Read a screenshot (in a Claude Code session, this displays the image)
# The agent would: Read /tmp/verify-test/mobile-fold.png
```

If all steps succeed, the tooling is ready. The next VERIFY session that includes frontend
changes should use these commands.

---

### Files to Create

- `/home/lever/command/tools/screenshot.js` — multi-viewport screenshot tool
- `/home/lever/command/tools/screenshot-section.js` — element-specific screenshot tool

### Files to Modify

- `/home/lever/command/workspaces/verify/CLAUDE.md`
  - Lines 81-89: replace Pass 2 with concrete commands
  - Lines 120-124: add screenshot evidence to verdict template

### Files to Read First

- `/home/lever/command/workspaces/verify/CLAUDE.md` — current VERIFY instructions
- `/home/lever/command/gstack/BROWSER.md` — gstack browser capabilities (alternative to Puppeteer)
- `/home/claude/lever-landing/screenshot.js` — existing working Puppeteer script (reference)

---

### Dependencies and Ripple Effects

- **puppeteer-core:** Already installed at `/home/lever/command/gstack/node_modules/puppeteer-core/`.
  The screenshot scripts use `require('puppeteer-core')` and must be run from a directory where
  this module is resolvable. The scripts use `cd /home/lever/command/gstack &&` prefix to ensure
  the module is found.

- **Chrome binary:** Two paths available. The script tries the Puppeteer cache first, falls back
  to standalone-chrome. Both are installed and verified.

- **Disk space for screenshots:** Full-page screenshots are 1-5MB each. 6 screenshots per run =
  ~20MB. `/tmp/` is cleaned on reboot. For persistent screenshots, save to
  `/home/lever/screenshots/verify-[date]/`.

- **No new npm installs needed.** All dependencies exist.

- **VERIFY agent model:** VERIFY runs on Sonnet. Sonnet supports vision (image input). When the
  agent uses the Read tool on a PNG file, the image is rendered visually and the model can
  analyze it. No special configuration needed.

- **Other workstreams:** Only VERIFY is affected. No changes to BUILD, PLAN, or other agents.

- **Scheduler:** No changes. VERIFY sessions are dispatched the same way. The CLAUDE.md update
  means future VERIFY sessions will automatically include browser QA.

---

### Edge Cases

**Frontend service down:** If `lever-frontend` is not running, `page.goto(localhost:3000)` will
timeout. The script captures the error in console.log. VERIFY should check service status before
attempting screenshots:
```bash
systemctl is-active lever-frontend && node /home/lever/command/tools/screenshot.js http://localhost:3000
```

**Non-frontend changes:** For pure contract or backend changes, Pass 2 is still required but
the screenshots will show "no visual changes." VERIFY should note "No frontend changes; browser
QA confirms no regression" in the verdict.

**Large pages (many sections):** Full-page screenshots of the landing page can be 10MB+. This
is fine for Claude Code's Read tool (it handles large images). But if file size is a concern,
use the `*-fold.png` (above-the-fold viewport-only) screenshots.

**Headless rendering differences:** Headless Chrome renders slightly differently from headed
Chrome (fonts, anti-aliasing). This is acceptable for QA purposes. The screenshots are for
catching layout breaks, not pixel-perfect comparison.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `node screenshot.js http://localhost:3000` succeeds | Chrome launches, page loads, screenshots saved |
| `node screenshot.js http://localhost:3001` succeeds | Landing page screenshotted |
| 6 PNG files created in output dir | All viewports captured |
| console.log contains no OVERFLOW | No horizontal scroll on tested pages |
| Read tool on PNG displays image | Vision pipeline works in Claude Code |
| VERIFY CLAUDE.md has actionable commands | Agent can copy-paste and execute |

---

### Effort Estimate

**Small** — 1-2 hours.
- Screenshot scripts: 30 minutes (mostly adapting existing screenshot.js)
- CLAUDE.md update: 30 minutes
- End-to-end test: 30 minutes
- Environment setup: 10 minutes

---

### Rollback Plan

Delete the screenshot scripts. Revert CLAUDE.md changes. VERIFY goes back to code-only review
(which is what it does now). No system impact.

---

### Open Questions

1. **gstack vs. Puppeteer:** gstack provides a Playwright-based browser CLI that is already
   running as a daemon. It may be simpler for VERIFY to use `gstack screenshot` commands
   instead of Puppeteer scripts. However, Puppeteer scripts are self-contained and do not
   depend on a running daemon. The plan uses Puppeteer for reliability. If gstack is preferred,
   the CLAUDE.md commands can be swapped to gstack equivalents.

2. **Screenshot storage:** Should VERIFY screenshots be saved permanently (for audit trail) or
   in `/tmp/` (cleaned on reboot)? The plan uses `/tmp/` for simplicity. If permanent storage
   is needed, save to `/home/lever/screenshots/verify-[date]-[task]/`.

---

### KANBAN Update

Move VIGIL-VERIFY-VISION to PLANNED.
