# Plan: VIGIL-DASHBOARD — Complete Dashboard Overhaul (Data Layer)
## Date: 2026-03-28T16:50:00Z
## Requested by: Master (via Commander)
## Companion to: plan-vigil-mission-control.md (frontend React rewrite)

---

### Problem Statement

The Vigil dashboard at `:8080` has two categories of problems:

1. **Frontend presentation:** Cramped layout, tiny pipeline, unreadable KANBAN, not mobile-first.
   This is addressed by **VIGIL-MISSION-CONTROL** (React + Tailwind rewrite).

2. **Data accuracy:** The backend `server.js` collects incorrect, stale, or misleading data.
   Master specifically said "data is wrong." This plan fixes the data layer so that regardless
   of frontend (current HTML or future React), the WebSocket pushes correct information.

**Known data bugs in server.js:**

| Bug | Location | Impact |
|-----|----------|--------|
| Session count includes all days | `collectSessions()` line 85 | Shows 50+ when today's count is 11 |
| Gateway errors are cumulative | `collectSessions()` line 88 | Error count grows forever, never resets |
| Upcoming jobs parser broken | `collectUpcoming()` lines 222-227 | "4m ago" (overdue) shows as "pending" |
| Health check fragile | `collectSystemData()` line 51 | Depends on Python one-liner; fails silently |
| Projects hardcoded | `collectAll()` lines 251-254 | Bug count static at 12, never updates |
| Blocked items not shown | `collectKanban()` line 108 | BLOCKED column collected but not rendered separately |
| No pipeline stage counts from scheduler | `collectKanban()` | Pipeline counts derived from kanban strings, not scheduler state |
| KANBAN items truncated to 5 | `getSection()` line 99 | `.slice(0, 5)` hides backlog items |

---

### Current Code State

**server.js line 85 — session count counts ALL days:**
```javascript
today: shNum(`grep -c "Session #" "${SESSION_COSTS}" 2>/dev/null`),
```

SESSION_COSTS.md has date headers (`## 2026-03-28`) followed by session entries. The grep
counts every "Session #" line across all dates. Should count only today's section.

**server.js line 88 — gateway errors never reset:**
```javascript
gatewayErrors: shNum(`grep -c "ERROR" "${INBOX_LOG}" 2>/dev/null`)
```

Counts all ERROR lines in the entire log. Should count only today's or last 24h.

**server.js lines 222-227 — upcoming jobs parser:**
```javascript
const nextMatch = line.match(/in\s+(\d+[hmd])/);
return { name, next: nextMatch ? nextMatch[0] : 'pending' };
```

The `openclaw cron list` output shows "in 1h" for future jobs but "4m ago" for overdue/running
jobs. The regex only matches "in Xh/Xm/Xd", so overdue jobs show "pending" instead of their
actual status. Also, the column parser (`split(/\s{2,}/)`) is fragile; column widths vary.

**server.js line 51 — health check uses Python:**
```javascript
health: sh("cat " + HEALTH_JSON + " 2>/dev/null | python3 -c \"import json,sys; ...\"")
```

Parsing JSON with Python when the server is Node.js. Should use `JSON.parse` directly.

**server.js lines 251-254 — hardcoded projects:**
```javascript
projects: {
  lever: { status: 'testnet', bugsTotal: 12 },
  landing: { status: 'active' }
}
```

Bug count is static. Should derive from KANBAN.md (count items with "BUG" in the name).

**server.js line 99 — KANBAN truncation:**
```javascript
return match[1].split('\n').filter(l => l.startsWith('- ')).map(l => l.replace(/^- /, '').trim()).slice(0, 5);
```

Backlog has 11 items; only 5 are shown. The frontend should decide truncation, not the API.

---

### Approach

Fix each data collector in server.js to produce accurate, correctly-scoped data. No structural
changes to the WebSocket protocol or data shape (the React frontend depends on the same shape).

---

### Implementation Steps

**Step 1: Fix session count to today only**

Change `collectSessions()` line 85:

FROM:
```javascript
today: shNum(`grep -c "Session #" "${SESSION_COSTS}" 2>/dev/null`),
```

TO:
```javascript
today: (() => {
  try {
    const content = fs.readFileSync(SESSION_COSTS, 'utf-8');
    const today = new Date().toISOString().split('T')[0];
    const todaySection = content.split(`## ${today}`)[1];
    if (!todaySection) return 0;
    const nextSection = todaySection.indexOf('\n## ');
    const section = nextSection > -1 ? todaySection.substring(0, nextSection) : todaySection;
    return (section.match(/Session #/g) || []).length;
  } catch { return 0; }
})(),
```

This parses SESSION_COSTS.md, finds today's date section, and counts sessions within it only.

---

**Step 2: Fix gateway errors to today only**

Change `collectSessions()` line 88:

FROM:
```javascript
gatewayErrors: shNum(`grep -c "ERROR" "${INBOX_LOG}" 2>/dev/null`)
```

TO:
```javascript
gatewayErrors: (() => {
  const today = new Date().toISOString().split('T')[0];
  return shNum(`grep -c "${today}.*ERROR" "${INBOX_LOG}" 2>/dev/null`);
})(),
```

This counts only ERROR lines that contain today's date. If the log format does not include
dates, fall back to counting lines from the last 24h using `tail` based on line count:
```javascript
gatewayErrors: shNum(`grep -c "ERROR" <(tail -500 "${INBOX_LOG}") 2>/dev/null`)
```

BUILD must check the actual log format to choose the right approach.

---

**Step 3: Fix health check to use native JSON**

Change `collectSystemData()` lines 51-52:

FROM:
```javascript
health: sh("cat " + HEALTH_JSON + " 2>/dev/null | python3 -c \"import json,sys; print(json.load(sys.stdin)['status'])\" 2>/dev/null") || 'unknown',
healthTime: sh("cat " + HEALTH_JSON + " 2>/dev/null | python3 -c \"import json,sys; print(json.load(sys.stdin)['timestamp'])\" 2>/dev/null") || '',
```

TO:
```javascript
...(() => {
  try {
    const hc = JSON.parse(fs.readFileSync(HEALTH_JSON, 'utf-8'));
    return { health: hc.status || 'unknown', healthTime: hc.timestamp || '' };
  } catch { return { health: 'unknown', healthTime: '' }; }
})(),
```

Then spread into the return object. Native JSON.parse is faster, does not depend on Python,
and fails gracefully.

---

**Step 4: Fix upcoming jobs parser**

Rewrite `collectUpcoming()`:

```javascript
function collectUpcoming() {
  try {
    const raw = sh("openclaw cron list 2>/dev/null");
    const lines = raw.split('\n').slice(1).filter(Boolean); // skip header
    return lines.slice(0, 7).map(line => {
      // Parse fixed-width columns by known positions
      // Columns: ID(36) Name(24) Schedule(32) Next(10) Last(10) Status(9) ...
      const name = line.substring(37, 61).trim();
      const next = line.substring(69, 80).trim();
      const status = line.substring(91, 100).trim();
      return { name, next: next || 'unknown', status };
    });
  } catch { return []; }
}
```

Or more robustly, split on 2+ spaces but capture the "Next" column properly:

```javascript
function collectUpcoming() {
  try {
    const raw = sh("openclaw cron list 2>/dev/null");
    const lines = raw.split('\n').filter(Boolean);
    if (lines.length < 2) return [];

    // Parse header to find column positions
    const header = lines[0];
    const nameIdx = header.indexOf('Name');
    const nextIdx = header.indexOf('Next');
    const lastIdx = header.indexOf('Last');
    const statusIdx = header.indexOf('Status');

    return lines.slice(1, 8).map(line => {
      const name = line.substring(nameIdx, nextIdx).trim();
      const next = line.substring(nextIdx, lastIdx).trim();
      const status = line.substring(statusIdx, statusIdx + 10).trim();
      return { name, next, status };
    });
  } catch { return []; }
}
```

This handles variable column widths by parsing the header line for column positions. The `next`
field now correctly shows "4m ago", "in 1h", etc. The frontend can display these as-is.

Add `status` to the data shape so the frontend can show running/error/idle indicators.

---

**Step 5: Fix projects to derive from KANBAN**

Change `collectAll()` lines 251-254:

FROM:
```javascript
projects: {
  lever: { status: 'testnet', bugsTotal: 12 },
  landing: { status: 'active' }
}
```

TO:
```javascript
projects: (() => {
  try {
    const kanban = fs.readFileSync(`${BRAIN}/KANBAN.md`, 'utf-8');
    const leverBugs = (kanban.match(/LEVER-BUG-/g) || []).length;
    return {
      lever: { status: 'testnet', bugsTotal: leverBugs },
      landing: { status: 'active' }
    };
  } catch {
    return { lever: { status: 'testnet', bugsTotal: 0 }, landing: { status: 'active' } };
  }
})()
```

Bug count now dynamically derived from KANBAN.md entries matching "LEVER-BUG-".

---

**Step 6: Remove KANBAN truncation**

Change `getSection()` line 99:

FROM:
```javascript
return match[1].split('\n').filter(l => l.startsWith('- ')).map(l => l.replace(/^- /, '').trim()).slice(0, 5);
```

TO:
```javascript
return match[1].split('\n').filter(l => l.startsWith('- ')).map(l => l.replace(/^- /, '').trim()).slice(0, 20);
```

Increase from 5 to 20 items per column. The frontend decides how many to display (with
"show more" if needed). The API should not hide data from the frontend.

---

**Step 7: Add pipeline stage counts from scheduler state**

Add a new `collectPipeline()` function that reads scheduler-state.json directly and returns
structured pipeline data:

```javascript
function collectPipeline() {
  const stages = { plan: 0, critique: 0, build: 0, verify: 0 };
  const details = { plan: [], critique: [], build: [], verify: [] };

  try {
    const state = JSON.parse(fs.readFileSync('/home/lever/command/heartbeat/scheduler-state.json', 'utf-8'));
    for (const [tid, task] of Object.entries(state.tasks || {})) {
      const stageMap = { planning: 'plan', critiquing: 'critique', building: 'build', verifying: 'verify' };
      const stage = stageMap[task.stage];
      if (stage) {
        stages[stage]++;
        const elapsed = task.dispatched_at ? Math.floor((Date.now()/1000 - task.dispatched_at) / 60) : 0;
        details[stage].push({ id: tid, title: task.title || tid, elapsed });
      }
    }
  } catch {}

  // Also count from live processes
  try {
    const psResult = sh("ps aux | grep 'openclaw agent' | grep -v grep");
    for (const line of psResult.split('\n').filter(Boolean)) {
      const match = line.match(/--agent\s+(plan|critique|build|verify)\b/i);
      if (match) {
        const stage = match[1].toLowerCase();
        if (!details[stage].some(d => d.id === 'live')) {
          // Avoid double-counting with scheduler state
        }
      }
    }
  } catch {}

  return { stages, details };
}
```

Add to `collectAll()`:
```javascript
pipeline: collectPipeline(),
```

This gives the frontend structured data for the pipeline visualization instead of having to
infer stage counts from KANBAN text strings.

---

**Step 8: Add scheduler health to system data**

Add scheduler status to `collectSystemData()`:

```javascript
schedulerRunning: sh("ps aux | grep 'scheduler.py' | grep -v grep | wc -l") > 0,
schedulerLastDispatch: (() => {
  try {
    const state = JSON.parse(fs.readFileSync('/home/lever/command/heartbeat/scheduler-state.json', 'utf-8'));
    let latest = 0;
    for (const task of Object.values(state.tasks || {})) {
      if (task.dispatched_at > latest) latest = task.dispatched_at;
    }
    return latest > 0 ? Math.floor(latest) : 0;
  } catch { return 0; }
})(),
```

The frontend can show "Scheduler: active, last dispatch 3m ago" or "Scheduler: DOWN" if the
process is not running.

---

**Step 9: Test data accuracy**

After each fix, verify the WebSocket data is correct:

```bash
# Connect to WebSocket and capture one update
node -e "
  const ws = new (require('ws'))('ws://localhost:8080');
  ws.on('message', d => { console.log(JSON.parse(d).data.sessions); ws.close(); });
"
```

Check each field against reality:
- `sessions.today`: compare to manual count of today's entries in SESSION_COSTS.md
- `sessions.gatewayErrors`: compare to `grep -c "ERROR" telegram-gateway.log` (should be today only)
- `upcoming[0].next`: compare to `openclaw cron list` output
- `system.health`: compare to `cat last-health-check.json | jq .status`
- `projects.lever.bugsTotal`: compare to KANBAN.md bug count
- `pipeline.stages`: compare to scheduler-state.json task stages

---

### Files to Modify

- `/home/lever/command/dashboard/server.js`
  - `collectSystemData()` lines 45-61: native JSON for health check, add scheduler status
  - `collectSessions()` lines 81-90: today-only session count, today-only gateway errors
  - `collectKanban()` line 99: increase slice limit from 5 to 20
  - `collectUpcoming()` lines 219-229: rewrite parser with column-position parsing
  - `collectAll()` lines 238-256: dynamic projects, add pipeline data
  - Add `collectPipeline()` function

### Files to Create

None.

### Files to Read First

- `/home/lever/command/dashboard/server.js` — full file
- `/home/lever/command/heartbeat/scheduler-state.json` — scheduler data format
- `/home/lever/command/heartbeat/last-health-check.json` — health data format
- `/home/lever/command/shared-brain/SESSION_COSTS.md` — session log format
- `openclaw cron list` output — column layout

---

### Dependencies and Ripple Effects

- **WebSocket data shape:** Adding `pipeline` and `status` fields to `upcoming` items extends
  the data shape. The current `mission-control.html` ignores unknown fields (it only reads
  what it knows). The future React frontend (VIGIL-MISSION-CONTROL) will consume the new fields.
  No breaking changes.

- **VIGIL-MISSION-CONTROL:** This plan is the backend companion. The React rewrite assumes
  correct data. These fixes should be deployed FIRST so the React frontend starts with
  accurate data from day one.

- **Systemd service:** `vigil-dashboard.service` runs `node server.js`. After editing server.js,
  restart: `sudo systemctl restart vigil-dashboard`.

- **No new dependencies.** All fixes use Node.js built-ins (`fs.readFileSync`, `JSON.parse`).
  No new npm packages needed.

---

### Edge Cases

**SESSION_COSTS.md has no entry for today:** The session count parser returns 0. Correct.

**Scheduler state file missing or malformed:** `collectPipeline()` catches and returns zeros.
The dashboard shows an empty pipeline, which is accurate.

**Health check file stale (old timestamp):** The `healthTime` field lets the frontend show
"Last check: 4h ago" with a warning indicator. The frontend (VIGIL-MISSION-CONTROL) can flag
stale health checks.

**Cron list command fails:** `collectUpcoming()` returns empty array. Dashboard shows "No
scheduled jobs." Correct degradation.

**KANBAN.md format changes:** The section parser uses `## SECTION_NAME` headers. If someone
changes the header format, the parser returns empty arrays. This is a known fragility but
acceptable for an internal tool.

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| `sessions.today` matches manual count | Today-only session counting |
| `sessions.gatewayErrors` is small number | Today-only error counting (not cumulative) |
| `system.health` is "healthy" or "unhealthy" | Native JSON parse works |
| `upcoming[*].next` shows "in 1h", "4m ago" | Correct time parsing for all states |
| `upcoming[*].status` shows running/idle/error | New status field works |
| `projects.lever.bugsTotal` matches KANBAN | Dynamic bug count |
| `pipeline.stages.plan` matches scheduler | Pipeline data from scheduler state |
| `kanban.backlog.length > 5` when KANBAN has >5 | Truncation limit increased |

---

### Effort Estimate

**Small** — 2-3 hours.
- Health check fix: 10 minutes
- Session count fix: 15 minutes
- Gateway errors fix: 10 minutes
- Upcoming jobs parser: 30 minutes (most complex)
- Projects dynamic: 10 minutes
- KANBAN truncation: 5 minutes
- Pipeline data: 30 minutes
- Scheduler health: 15 minutes
- Testing: 30 minutes

---

### Rollback Plan

```bash
cd /home/lever/command/dashboard
git checkout -- server.js
sudo systemctl restart vigil-dashboard
```

The old data collectors work (they are just wrong). Rollback restores the previous behavior.

---

### Open Questions

None. All fixes are straightforward data corrections.

---

### KANBAN Update

Move VIGIL-DASHBOARD to PLANNED. Note: this is the data-layer companion to VIGIL-MISSION-CONTROL
(frontend). Deploy VIGIL-DASHBOARD first, then VIGIL-MISSION-CONTROL.
