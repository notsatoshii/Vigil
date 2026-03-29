# BUILD Handoff Report
## Date: 2026-03-29
## Task: VIGIL-VERIFY-VISION - Screenshot tools + VERIFY CLAUDE.md update

### Changes Made

- `/home/lever/command/tools/screenshot.js`: New Puppeteer script. Takes a URL + optional output dir. Screenshots at 3 viewports (desktop 1920x1080, tablet 768x1024, mobile 375x812). Produces fold (above-the-fold clip) and full-page PNGs for each viewport, plus a console.log file capturing all JS console output and page errors. Uses module.paths.unshift for portable puppeteer-core resolution. Uses `await new Promise(r => setTimeout(r, 2000))` instead of deprecated waitForTimeout. Chrome path is hardcoded primary with fallback + env var as last resort.

- `/home/lever/command/tools/screenshot-section.js`: New Puppeteer script. Takes URL + CSS selector + optional output path. Screenshots just the matching element. Logs element dimensions. Same Chrome/Puppeteer setup as screenshot.js.

- `/home/lever/command/workspaces/verify/CLAUDE.md`: Updated Pass 2 (Visual/Design Verification) with concrete copy-paste shell commands for screenshot.js, screenshot-section.js, PNG review via Read tool, and console.log grep patterns. Updated verdict template to require screenshot evidence block (desktop fold, mobile fold, console error count, overflow check).

- `/home/lever/.bashrc`: Attempted to add PUPPETEER_EXECUTABLE_PATH export. BLOCKED by sandbox permission on sensitive file. Non-blocking: scripts hardcode the Chrome path and fall back gracefully without the env var.

### Files Modified
- /home/lever/command/tools/screenshot.js (new)
- /home/lever/command/tools/screenshot-section.js (new)
- /home/lever/command/workspaces/verify/CLAUDE.md (updated Pass 2 + verdict template)

### Tests Run
- screenshot.js against http://localhost:3001: PASS
  - Produced: desktop-fold.png, desktop-full.png, tablet-fold.png, tablet-full.png, mobile-fold.png, mobile-full.png, console.log
  - Exit code: 0
- screenshot-section.js against http://localhost:3001 "body": PASS
  - Produced: body-section.png (1920x12002 element)
  - Exit code: 0

### Known Risks
- .bashrc PUPPETEER_EXECUTABLE_PATH export was not added (sandbox blocked). Scripts use hardcoded path as primary so this is not a functional issue. If Chrome moves, update the CHROME_PRIMARY constant in both scripts.
- puppeteer-core is at /home/lever/command/gstack/node_modules/. If gstack is ever moved or cleaned, both scripts will break.

### Contract Changes
- None

### Build/Deploy Actions
- mkdir -p /home/lever/command/tools
- chmod +x on both scripts
- Verified Chrome at: /home/lever/.cache/puppeteer/chrome/linux-146.0.7680.76/chrome-linux64/chrome
