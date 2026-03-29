# BUILD Handoff Report
## Date: 2026-03-29T10:30:00Z
## Task: Fix Vigil dashboard data layer per approved plan at /home/lever/command/handoffs/plan-vigil-dashboard.md

### Changes Made

**Step 1: Fix session count to today only** (collectSessions)
- Was: `grep -c "Session #"` across entire SESSION_COSTS.md (returned 25+ for today when count should have been 14)
- Fix: Parse SESSION_COSTS.md, split on today's date header, count `Session #` matches within that section only

**Step 2: Fix gateway errors to today only** (collectSessions)
- Was: `grep -c "ERROR"` across entire telegram-gateway.log (cumulative, never resets)
- Fix: Grep for `^YYYY-MM-DD.*\[ERROR\]` to match only today's error lines
- Log format confirmed: `2026-03-29 HH:MM:SS,ms [INFO/ERROR] message`

**Step 3: Fix health check to use native JSON** (collectSystemData)
- Was: Two separate `python3 -c` subprocess calls to read health status and timestamp
- Fix: Single `fs.readFileSync` + `JSON.parse` with spread into return object. No python dependency.

**Step 4: Fix upcoming jobs next-run time** (collectUpcoming)
- Was: Returned raw cron expression string (e.g. "0 8 * * *") as the `next` field
- Fix: Compute human-readable time from `job.state.nextRunAtMs` timestamp. Returns "in 21h", "3m overdue", etc.
- Added `status` field (idle/error) based on `lastRunStatus` and `consecutiveErrors`

**Step 5: Fix projects to derive from KANBAN** (collectAll)
- Was: Hardcoded `bugsTotal: 12`
- Fix: Count `LEVER-BUG-` occurrences in KANBAN.md dynamically. Currently returns 9.

**Step 6: Remove KANBAN truncation** (getSection)
- Was: `.slice(0, 5)` hiding backlog items beyond the 5th
- Fix: `.slice(0, 20)` so the frontend decides how many items to show

**Step 7: Add pipeline stage counts from scheduler state** (new collectPipeline)
- New function reads scheduler-state.json and maps task stages to plan/critique/build/verify counts
- Returns `{ stages: {plan, critique, build, verify}, details: [...] }`
- Added to collectAll() as `pipeline` field

**Step 8: Add scheduler health to system data** (collectSystemData)
- Added `schedulerRunning` (boolean, from ps aux grep for scheduler.py)
- Added `schedulerLastDispatch` (unix timestamp, max dispatched_at across all scheduler tasks)

### Files Modified

- `/home/lever/command/dashboard/server.js`

### Tests Run

- HTTP GET /data.json: verified all 8 fields are correct
  - `sessions.today`: 14 (matches manual count of today's section in SESSION_COSTS.md)
  - `sessions.gatewayErrors`: 10 (today-only, no longer cumulative)
  - `system.health`: "healthy" (native JSON.parse working)
  - `system.schedulerRunning`: true
  - `system.schedulerLastDispatch`: 1774780941 (valid unix timestamp)
  - `upcoming[0].next`: "in 21h" (human-readable, not raw cron expression)
  - `pipeline.stages`: {"plan":0,"critique":1,"build":1,"verify":1} (matches scheduler-state.json)
  - `projects.lever.bugsTotal`: 9 (derived from KANBAN.md LEVER-BUG- count)

### Known Risks

- `gatewayErrors` grep uses date prefix matching. If the gateway log format ever changes (e.g. timestamps removed), errors will show 0. Acceptable for an internal dashboard.
- `schedulerRunning` checks for "scheduler.py" in ps output. If the scheduler process name changes, this will show false when it is running.
- LEVER-BUG- count in KANBAN.md counts every occurrence (including in DONE section), so the number reflects total bug count tracked ever, not open bugs only. The plan spec said "count LEVER-BUG- in KANBAN" so this matches the spec.

### Contract Changes

- None

### Build/Deploy Actions

- Service restarted: `sudo systemctl restart vigil-dashboard`
- Confirmed active after restart
