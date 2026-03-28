# Plan: VIGIL-MISSION-CONTROL — React + Tailwind Mission Control Dashboard
## Date: 2026-03-28T15:20:00Z
## Requested by: Master (via Commander, HIGHEST PRIORITY)

---

### Problem Statement

The current dashboard is a 411-line monolithic HTML file (`mission-control.html`) with inline CSS
and vanilla JS. Master has called it "trash", "not reactive", "data is wrong", and "not mobile-first".
Specific complaints from TIMMY_PERSONALITY.md and session-plan-final-review.md:

1. **Not reactive.** Data refreshes feel sluggish. No visual feedback when things update.
2. **Data is wrong.** `nextJobs` shows agent names not times. Health was wrong. Session counts off.
3. **Not mobile-first.** Master checks on his phone. Current layout breaks on mobile.
4. **No real pipeline visualization.** Pipeline is tiny text in small boxes. Should be "big, bold, animated."
5. **KANBAN not visible enough.** Exists but cramped in a 5-column grid. Cards not readable.
6. **No pulsing alerts.** Attention items do not demand attention. No visual urgency.
7. **Not institutional.** Design looks like a toy, not a mission control for a protocol team.

The backend (`server.js`, 391 lines) is solid. It already collects all necessary data, pushes via
WebSocket, watches files, and handles periodic refreshes. **The backend stays. Only the frontend
is rebuilt.**

---

### Approach

**React + Tailwind + Vite frontend, served by the existing server.js.**

Architecture:
```
/home/lever/command/dashboard/
  server.js              (UNCHANGED, backend stays)
  package.json           (add dev dependencies)
  mission-control.html   (kept as fallback, renamed)
  app/                   (NEW: React app)
    index.html
    main.jsx
    App.jsx
    hooks/
      useVigilSocket.js  (WebSocket hook, auto-reconnect)
    components/
      StatusBar.jsx
      Pipeline.jsx
      KanbanBoard.jsx
      KanbanCard.jsx
      ActivityFeed.jsx
      AttentionPanel.jsx
      ServiceGrid.jsx
      ProjectCards.jsx
      SchedulePanel.jsx
      StatsPanel.jsx
      ContextDrawer.jsx  (mobile sidebar drawer)
    lib/
      colors.js          (workstream palette)
      time.js            (ago(), countdown)
    index.css            (Tailwind directives + custom animations)
  vite.config.js
  tailwind.config.js
  postcss.config.js
```

**Build strategy:**
- `vite build` compiles to `dashboard/dist/`
- `server.js` is updated to serve `dist/` in production (3 lines changed)
- In development: `vite dev` with proxy to `server.js:8080` for WebSocket
- Systemd service (`vigil-dashboard.service`) runs `node server.js` unchanged

**Data shape is preserved.** The WebSocket sends `{type:'update', data:{...}}` with the exact
same structure. React components consume the same JSON. No backend changes needed.

---

### Current Backend Data Shape (from server.js collectAll())

```javascript
{
  timestamp: "ISO string",
  epoch: number,
  system: { health, healthTime, ramUsed, ramTotal, ramPct, diskPct, diskUsed, diskTotal, cpuLoad, uptime },
  services: { frontend: bool, oracle: bool, accrue: bool, gateway: bool, inbox: bool, telegram: bool, dashboard: bool, caddy: bool },
  sessions: { active: number, today: number, pendingApprovals: number, deadLetters: number, gatewayErrors: number },
  knowledge: { sources: number, entities: number },
  kanban: { backlog: string[], planned: string[], inProgress: string[], inReview: string[], done: string[], blocked: string[] },
  intentions: string[],
  advisorSummary: string,
  activity: { handoffs: [{name, time, summary}], sessions: string[] },
  upcoming: [{name, next}],
  projects: { lever: {status, bugsTotal}, landing: {status} }
}
```

Kanban items use `|||` as title/detail separator. This convention stays.

---

### Implementation Steps

**Step 1: Scaffold the Vite + React + Tailwind project**

Inside `/home/lever/command/dashboard/`:

```bash
# Do NOT run create-vite. Scaffold manually to keep it minimal.
npm install --save-dev vite @vitejs/plugin-react react react-dom tailwindcss @tailwindcss/vite
```

Create `vite.config.js`:
```javascript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  root: 'app',
  build: { outDir: '../dist', emptyOutDir: true },
  server: {
    proxy: {
      '/data.json': 'http://localhost:8080',
      '/ws': { target: 'ws://localhost:8080', ws: true }
    }
  }
});
```

Create `app/index.html`, `app/main.jsx`, `app/index.css` (Tailwind directives).

Create `tailwind.config.js` with custom colors:
```javascript
export default {
  content: ['./app/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        vigil: { bg: '#06090f', surface: '#0c1119', border: '#1a2332' },
        ws: { plan: '#a78bfa', critique: '#f472b6', build: '#38bdf8', verify: '#22c55e',
              research: '#fbbf24', operate: '#94a3b8', secure: '#ef4444', ceo: '#e2e8f0',
              advisor: '#c084fc', improve: '#2dd4bf' }
      },
      animation: { breathe: 'breathe 3s ease-in-out infinite', pulse-fast: 'pulse 1.5s ease-in-out infinite' }
    }
  }
};
```

---

**Step 2: Build the WebSocket hook (`hooks/useVigilSocket.js`)**

```javascript
import { useState, useEffect, useRef, useCallback } from 'react';

export function useVigilSocket() {
  const [data, setData] = useState(null);
  const [connected, setConnected] = useState(false);
  const wsRef = useRef(null);
  const reconnectRef = useRef(null);

  const connect = useCallback(() => {
    const ws = new WebSocket('ws://' + location.host);
    wsRef.current = ws;
    ws.onopen = () => setConnected(true);
    ws.onclose = () => {
      setConnected(false);
      reconnectRef.current = setTimeout(connect, 3000);
    };
    ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data);
        if (msg.type === 'update') setData(msg.data);
      } catch {}
    };
  }, []);

  useEffect(() => {
    connect();
    return () => {
      clearTimeout(reconnectRef.current);
      wsRef.current?.close();
    };
  }, [connect]);

  // Fallback polling if WebSocket is down
  useEffect(() => {
    if (connected) return;
    const interval = setInterval(async () => {
      try {
        const r = await fetch('/data.json?' + Date.now());
        setData(await r.json());
      } catch {}
    }, 10000);
    return () => clearInterval(interval);
  }, [connected]);

  return { data, connected };
}
```

This replaces 30 lines of inline WebSocket code with a clean React hook. Auto-reconnect, fallback
polling, and connection state are all encapsulated.

---

**Step 3: Build the utility modules**

`lib/colors.js`: workstream color map (same as current `wsColors` object).

`lib/time.js`: `ago(epoch)` function (same as current), plus `countdown(targetEpoch)` for the
SchedulePanel countdown timers.

---

**Step 4: Build each component**

Components listed in build order (simplest first, building up to complex):

**4a. StatusBar.jsx** (sticky top bar)
- Health orb with breathing animation (green/amber/red)
- "VIGIL" logo
- Workstream activity pills (colored dots, active ones pulse)
- Active session count
- RAM percentage
- WebSocket connection indicator
- "Last update: Xs ago" live counter (useEffect + setInterval)

Port directly from current lines 119-131. Add Tailwind classes instead of inline CSS.
Mobile: shrink to just orb + logo + connection + RAM. Hide pills.

**4b. Pipeline.jsx** (big, bold, animated)
- 4 stages: PLAN, CRITIQUE, BUILD, VERIFY
- Each stage is a tall card (not the current tiny boxes)
- Active stages glow, pulse, show count prominently (2rem+ font)
- Arrows between stages are animated when items are flowing
- Stage colors: plan=purple, critique=pink, build=blue, verify=green
- Empty stages are muted, active stages are vivid with shadow glow
- Support task count shown as a smaller badge below the pipeline

Derive counts from `kanban.inProgress` (same logic as current lines 256-272).

This is the BIGGEST visual change from the current dashboard. Current pipeline is 4 tiny
9px boxes. New pipeline must be the visual centerpiece.

**4c. KanbanBoard.jsx + KanbanCard.jsx** (expandable cards)
- 5 columns: Backlog, Planned, In Progress, In Review, Done
- Plus a "Blocked" section below (full width, red accent)
- Mobile: horizontal scroll on columns, or stack vertically
- Each card: colored left border (by workstream), title, expand/collapse for detail
- Active cards (in progress) have subtle pulse animation
- Card detail panel slides open on click (not display:none toggle)
- Time elapsed shown on active cards ("12m ago")

Parse `|||` separator for title vs detail. Extract workstream name for color coding
(same regex as current lines 289-295).

**4d. ActivityFeed.jsx** (workstream colors)
- Chronological feed, newest first
- Each entry: time ago, workstream badge (colored), description, status icon
- Entries fade in with animation on new data
- Workstream badge uses the full color palette
- Show 15 items max, with a "show more" if needed
- Merge handoffs and sessions the same way current code does (lines 345-380)

**4e. AttentionPanel.jsx** (pulsing alerts)
- Only visible when items exist (pending approvals, failed messages, gateway errors)
- Red/amber border with pulse animation
- Critical items (dead letters) pulse faster
- Each item shows: title, description, suggested action
- Entire panel has a subtle red glow when critical items present
- Sound/vibration hook point for future (not implemented now, just the UI)

Port from current attention logic (lines 328-342) but make it DEMAND attention visually.

**4f. ServiceGrid.jsx** (context panel)
- 2x4 grid of service indicators
- Green dot = running, red dot = down (pulsing red)
- Service name and port
- Down services are visually prominent (not just a red dot)

Port from current lines 317-320.

**4g. StatsPanel.jsx** (trends)
- Sessions today, knowledge sources, knowledge entities
- Large number display
- Trend arrows (up/down/flat) based on comparing current value to a rolling average
  (server.js would need to track history for this; for v1, just show the numbers
  like current, add trend support as a follow-up)

Port from current lines 322-325. Add disk/CPU/RAM gauges.

**4h. ProjectCards.jsx** (context panel)
- LEVER Protocol card: status badge (TESTNET), audit items count, link to repo
- Landing Page card: status badge (ACTIVE)
- Each card is a clean bordered card with project name and metadata

Port from current lines 383-385.

**4i. SchedulePanel.jsx** (countdown timers)
- List of upcoming cron jobs
- Each job shows: name, countdown timer to next run
- Countdown updates every second (useEffect + setInterval)
- When a job is about to fire (< 1 min), the row pulses

Port from current lines 388-390. Add live countdowns.

**4j. ContextDrawer.jsx** (mobile sidebar)
- On desktop (>=1024px): right sidebar, always visible (320px)
- On mobile (<1024px): hidden by default, hamburger button in StatusBar opens it as a
  slide-in drawer from the right
- Contains: ServiceGrid, StatsPanel, ProjectCards, SchedulePanel
- Smooth slide animation

This replaces the current `ctx-col` which just stacks below on mobile.

---

**Step 5: Compose in App.jsx**

```jsx
function App() {
  const { data, connected } = useVigilSocket();
  if (!data) return <LoadingScreen />;

  return (
    <div className="min-h-screen bg-vigil-bg text-slate-200">
      <StatusBar data={data} connected={connected} />
      <div className="max-w-[1400px] mx-auto flex">
        <main className="flex-1 p-4 lg:p-5 space-y-5 lg:border-r border-vigil-border">
          <Pipeline kanban={data.kanban} />
          <AttentionPanel sessions={data.sessions} />
          <KanbanBoard kanban={data.kanban} />
          <ActivityFeed activity={data.activity} />
        </main>
        <ContextDrawer>
          <ServiceGrid services={data.services} />
          <StatsPanel sessions={data.sessions} knowledge={data.knowledge} system={data.system} />
          <ProjectCards projects={data.projects} />
          <SchedulePanel upcoming={data.upcoming} />
        </ContextDrawer>
      </div>
    </div>
  );
}
```

---

**Step 6: Update server.js to serve the built app (3 lines)**

Change the HTTP handler's root path:

```javascript
// In the http.createServer callback:
if (req.url === '/' || req.url === '/index.html') {
  // Try built React app first, fall back to legacy HTML
  const distIndex = path.join(DASHBOARD_DIR, 'dist', 'index.html');
  filePath = fs.existsSync(distIndex) ? distIndex : path.join(DASHBOARD_DIR, 'mission-control.html');
}
// For all other static files, also check dist/:
filePath = path.join(DASHBOARD_DIR, 'dist', req.url.split('?')[0]);
if (!fs.existsSync(filePath)) {
  filePath = path.join(DASHBOARD_DIR, req.url.split('?')[0]); // fallback to root
}
```

This is a graceful migration: if `dist/` exists, serve the React app. If not, serve the old HTML.
No downtime during the transition.

---

**Step 7: Add build scripts to package.json**

```json
{
  "scripts": {
    "start": "node server.js",
    "dev": "vite --config vite.config.js",
    "build": "vite build --config vite.config.js",
    "preview": "vite preview --config vite.config.js"
  }
}
```

---

**Step 8: Build, verify, deploy**

```bash
cd /home/lever/command/dashboard
npm run build       # produces dist/
# server.js auto-serves dist/ on next request (no restart needed if using fs.existsSync)
# But restart to be safe:
sudo systemctl restart vigil-dashboard
```

Verify on desktop and mobile (Master's phone). Check:
- WebSocket connects and updates flow
- Pipeline shows active stages prominently
- KANBAN cards expand on click
- Activity feed shows colored workstream badges
- Attention panel pulses when items exist
- Mobile layout is usable (drawer works, pipeline stacks)

---

### Files to Modify

- `dashboard/server.js` — 3 lines: serve `dist/` directory with fallback (lines 322-331)
- `dashboard/package.json` — add devDependencies and build scripts

### Files to Create

```
dashboard/vite.config.js
dashboard/tailwind.config.js
dashboard/postcss.config.js
dashboard/app/index.html
dashboard/app/index.css
dashboard/app/main.jsx
dashboard/app/App.jsx
dashboard/app/hooks/useVigilSocket.js
dashboard/app/lib/colors.js
dashboard/app/lib/time.js
dashboard/app/components/StatusBar.jsx
dashboard/app/components/Pipeline.jsx
dashboard/app/components/KanbanBoard.jsx
dashboard/app/components/KanbanCard.jsx
dashboard/app/components/ActivityFeed.jsx
dashboard/app/components/AttentionPanel.jsx
dashboard/app/components/ServiceGrid.jsx
dashboard/app/components/StatsPanel.jsx
dashboard/app/components/ProjectCards.jsx
dashboard/app/components/SchedulePanel.jsx
dashboard/app/components/ContextDrawer.jsx
```

### Files to Rename (preserve, do not delete)

- `dashboard/mission-control.html` — kept as fallback and reference

### Files to Read First (BUILD must read all of these)

- `dashboard/server.js` — full file (understand data shape, WebSocket protocol, HTTP handler)
- `dashboard/mission-control.html` — full file (understand current rendering logic to port)
- `shared-brain/TIMMY_PERSONALITY.md` lines 80-99 (observation log with Master's complaints)
- `handoffs/session-plan-final-review.md` — full file (honest assessment of what is wrong)

---

### Dependencies and Ripple Effects

- **Systemd service:** `vigil-dashboard.service` runs `node server.js`. No change needed.
  The service does NOT run `npm run dev`. Vite is dev-only.

- **Port 8080:** No change. Server.js still listens on 8080. Vite dev server uses a different
  port (5173 by default) and proxies WebSocket/API to 8080.

- **WebSocket protocol:** Unchanged. Same `{type:'update', data:{...}}` messages.

- **`/data.json` endpoint:** Unchanged. React app uses WebSocket primarily, falls back to polling.

- **OPERATE self-checks:** OPERATE monitors the dashboard at `:8080`. After the React build,
  the page still loads at the same URL. OPERATE does not need changes.

- **Disk space:** `node_modules` will grow with React/Vite/Tailwind devDependencies. Current
  disk usage is 16%. React devDeps add ~150MB. Not a concern on 193GB disk.

- **No other dashboards affected:** The `lever-dashboard.service` at
  `/home/lever/lever-protocol/control-plane/dashboard.py` is separate and unrelated.

---

### Design Principles (from Master's feedback)

1. **Institutional, not toy.** Dark theme, clean typography, minimal borders. Think Bloomberg
   terminal, not consumer SaaS. The color palette is already good (dark with accent colors).
   Keep it.

2. **Pipeline is the hero.** The first thing you see after the status bar. Tall cards, bold
   numbers, animated transitions. When a BUILD session is running, you should FEEL it.

3. **Mobile-first.** Every component must work on a phone screen. Pipeline stacks vertically.
   KANBAN scrolls horizontally. Context panel becomes a drawer. Touch targets are 44px minimum.

4. **Real-time feel.** Data updates should cause subtle animations (fade, slide). Not full
   re-renders. React's diffing handles this naturally, but add CSS transitions on data change.

5. **Demand attention when needed.** AttentionPanel pulsing red glow when critical items exist.
   Dead letters = maximum urgency. Pending approvals = moderate urgency. Gateway errors = low.

6. **Information density on desktop, focus on mobile.** Desktop shows everything at once
   (two-column). Mobile shows pipeline + attention + kanban, with context in a drawer.

---

### Edge Cases

- **No data on initial load:** Show a loading skeleton (pulsing gray boxes) until first
  WebSocket message arrives. Do NOT show a blank page.

- **WebSocket disconnect:** Show red connection indicator in StatusBar. Fall back to polling
  `/data.json` every 10 seconds. When reconnected, show green indicator with brief flash.

- **Empty KANBAN columns:** Show a muted empty state, not nothing. "No items" in dim text.

- **Very long KANBAN items:** Truncate at 2 lines in collapsed state. Full text in expanded.
  Word-break for long unspaced strings (like file paths).

- **Many activity entries:** Virtualize the list if >50 items (unlikely, but defensive). For
  v1, just slice to 20.

- **Server.js not running (dev mode):** Vite proxy returns 502. Show "Backend offline" message
  in the UI instead of silently failing.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `npm run build` succeeds | Vite compiles without errors |
| Load `:8080` on desktop | All components render, WebSocket connects |
| Load `:8080` on mobile (phone) | Responsive layout, drawer works, pipeline stacks |
| Kill and restart a service | ServiceGrid updates in <5 seconds |
| Add a KANBAN item to KANBAN.md | KanbanBoard updates via file watch |
| Click a KANBAN card | Detail panel expands/collapses smoothly |
| Disconnect WebSocket (kill server) | Red indicator, fallback polling activates |
| Reconnect WebSocket | Green indicator, data resumes |
| Pipeline with 0 active stages | All stages muted, no animation |
| Pipeline with 2 BUILD sessions | BUILD stage glows, shows "2" prominently |
| AttentionPanel with 0 items | Section hidden entirely |
| AttentionPanel with dead letters | Red glow, pulsing animation |

VERIFY must use Puppeteer/Chromium to screenshot the dashboard on both desktop (1920x1080)
and mobile (375x812) viewports and visually confirm the layout.

---

### Effort Estimate

**Large** — 1-2 days.
- Scaffold + tooling: 30 minutes
- WebSocket hook + utilities: 30 minutes
- 11 components: 4-6 hours (Pipeline and KanbanBoard are the complex ones)
- Server.js update: 15 minutes
- Build + deploy: 15 minutes
- Testing + mobile fixes: 1-2 hours

The component code is mostly porting existing rendering logic from `mission-control.html` into
JSX with Tailwind classes. The data shape is unchanged. The main creative work is the Pipeline
visualization and the mobile drawer.

---

### Rollback Plan

`server.js` falls back to `mission-control.html` if `dist/` does not exist. To rollback:

```bash
rm -rf /home/lever/command/dashboard/dist/
sudo systemctl restart vigil-dashboard
```

The old HTML file is preserved. Zero-downtime rollback.

---

### Open Questions

None. The task is clear, the data shape is known, the design direction is specified, and Master's
feedback is documented. BUILD should execute.

---

### KANBAN Update

Move VIGIL-MISSION-CONTROL to PLANNED.
