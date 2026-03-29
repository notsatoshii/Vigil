# Critique: VIGIL-MISSION-CONTROL — React + Tailwind Mission Control Dashboard
## Date: 2026-03-29T04:05:00Z
## Plan reviewed: handoffs/plan-vigil-mission-control.md
## Codebase verified against: /home/lever/command/dashboard/ (server.js, mission-control.html, package.json)

---

### Verdict: APPROVED

The plan is thorough, the architecture is clean, and the approach is correct. Backend data shape matches the actual server.js. Rollback is graceful. No blockers. Notes below are guidance for BUILD.

---

### What Is Good

- Correctly preserves the backend (server.js) unchanged except for 3 lines of static file routing.
- Data shape documented in the plan matches the actual `collectAll()` output in server.js.
- WebSocket protocol preserved: `{type:'update', data:{...}}` format confirmed in server.js line 356.
- Graceful rollback: `dist/` presence check with fallback to `mission-control.html`. Zero-downtime.
- Component decomposition is sensible: 11 focused components, each porting specific sections of the current 411-line HTML.
- WebSocket hook with auto-reconnect and fallback polling is well-designed.
- Design principles clearly derived from Master's documented complaints.
- Effort estimate (1-2 days) is realistic for porting existing rendering logic to React.

---

### Issues Found

**1. [MEDIUM] Tailwind v4 configuration differs from the plan's v3-style config**

The plan installs `@tailwindcss/vite` (Tailwind v4 Vite plugin) but writes a `tailwind.config.js` in v3 format. Tailwind v4 uses CSS-based configuration with `@theme` directives, not JS config files.

With `@tailwindcss/vite`, the setup is:
- No `tailwind.config.js` needed
- No `postcss.config.js` needed
- Custom colors and animations go in `app/index.css` using `@theme` blocks:
  ```css
  @import "tailwindcss";
  @theme {
    --color-vigil-bg: #06090f;
    --color-vigil-surface: #0c1119;
    --color-ws-plan: #a78bfa;
    /* etc */
  }
  ```

If BUILD installs `tailwindcss` v4 (the default now) and writes a v3-style config, it won't work. BUILD should either:
- (a) Use Tailwind v4 with CSS `@theme` configuration (recommended)
- (b) Pin Tailwind v3 explicitly: `npm install --save-dev tailwindcss@3 postcss autoprefixer` and use the JS config

Option (a) is simpler. The plan's `postcss.config.js` can be omitted entirely with `@tailwindcss/vite`.

---

**2. [MEDIUM] Existing `index.html` in dashboard root may conflict**

The directory already has both `index.html` and `mission-control.html`. Server.js routes `/` and `/index.html` to `mission-control.html` (line 322-323). The existing `index.html` is not served for the root path.

After the plan's Step 6 change, static file requests for paths not matching `/` will check `dist/` first, then root. A request for `/index.html` would be caught by the explicit route (Step 6) and served from `dist/`. But other Vite-generated assets (JS bundles, CSS) would need to be served from `dist/assets/`. The plan's static file handler change (lines 361-364) handles this.

BUILD should verify that the existing `index.html` in the root does not shadow the `dist/index.html`. Since the explicit route check (lines 355-358) runs first, this should be fine.

---

**3. [LOW] server.js line numbers in the plan are correct**

Verified: HTTP handler is at lines 319-345, WebSocket at 349-359. Plan references match. (Unlike the LEVER bug plans, this one's line numbers are accurate.)

---

**4. [LOW] The `data.json` endpoint path in Vite proxy config**

The plan's `vite.config.js` proxies `/data.json` and `/ws` to `localhost:8080`. The actual WebSocket connection in the hook uses `new WebSocket('ws://' + location.host)`. In dev mode with Vite (port 5173), `location.host` would be `localhost:5173`, so the WebSocket needs to connect to Vite's proxy.

Vite's WebSocket proxy config `'/ws': { target: 'ws://localhost:8080', ws: true }` only proxies paths starting with `/ws`. But the hook connects to `ws://localhost:5173` (root path, no `/ws` prefix). The actual server.js WebSocket server is mounted on the HTTP server itself (line 351: `new WebSocketServer({ server })`), meaning it accepts WebSocket upgrades on any path.

For Vite's proxy to work in dev, either:
- The WebSocket hook should connect to `ws://localhost:5173/ws` (and proxy config catches it)
- Or the Vite proxy should intercept all WebSocket upgrades

BUILD should test the dev proxy setup. In production (served by server.js directly), this is not an issue.

---

### Missing Steps

None critical. The plan is comprehensive for a frontend task.

---

### Edge Cases Not Covered

- **CSP headers**: The plan does not mention Content Security Policy. The current HTML has no CSP. If Caddy (the reverse proxy) adds CSP headers, Vite's inline scripts and styles might be blocked. BUILD should check Caddy config. (Note from LESSONS.md: "CSP meta tag must be stripped from BOTH build/index.html and public/index.html" after frontend builds, though this is for the LEVER frontend, not the dashboard.)

- **Large KANBAN items**: The current KANBAN has items with long descriptions (e.g., VIGIL-MISSION-CONTROL backlog item is ~3 lines). The `|||` separator convention works for title|detail parsing. BUILD should verify with the actual KANBAN content.

---

### Simpler Alternative

None. The plan's approach (React + Tailwind + Vite on top of existing server.js) is already the right balance of modern tooling and minimal disruption.

---

### Revised Effort Estimate

Agreed: **Large** (1-2 days). Pipeline and KanbanBoard components are the creative work. The rest is porting.

---

### Recommendation

**Send to BUILD.** The plan is ready. BUILD should note:

1. Use Tailwind v4 CSS configuration (`@theme` blocks in `index.css`), not the v3-style `tailwind.config.js`. Skip `postcss.config.js`.
2. Test the Vite dev proxy WebSocket connection. The hook's `ws://location.host` may need a path prefix to match the proxy config.
3. Verify the existing `index.html` in dashboard root does not conflict with `dist/index.html` serving.
4. Check Caddy reverse proxy config for CSP headers that might block inline Vite assets.
