# Critique: VIGIL-DASHBOARD — Complete Dashboard Overhaul (Data Layer)
## Date: 2026-03-29T10:26:00Z
## Plan reviewed: handoffs/plan-vigil-dashboard.md
## Codebase verified against: /home/lever/command/dashboard/server.js (395 lines, modified 04:15 UTC today)

---

### Verdict: APPROVED (with notes)

Six of eight data bugs verified correct in the actual code. One step (upcoming jobs parser) describes code that has already been partially rewritten and needs a different fix. The pipeline/scheduler steps are valid (scheduler-state.json confirmed with expected format).

---

### What Is Good

- Correct identification of all major data accuracy bugs.
- Fixes do not change the WebSocket data shape (backward-compatible with current HTML frontend).
- Companion plan relationship with VIGIL-MISSION-CONTROL is correct: deploy data fixes first.
- Each fix is independent; BUILD can land them incrementally.
- Testing approach is pragmatic (WebSocket connection + manual verification).

---

### Issues Found

**1. [MEDIUM] Step 4 (upcoming jobs parser) is stale. `collectUpcoming()` was already rewritten.**

The plan describes the OLD code that parsed `openclaw cron list` shell output with regex. The ACTUAL code (lines 219-229) reads from a JSON file:

```javascript
const jobsFile = '/home/lever/.openclaw/cron/jobs.json';
const raw = fs.readFileSync(jobsFile, 'utf-8');
const data = JSON.parse(raw);
return (data.jobs || []).filter(j => j.enabled).slice(0, 7).map(j => ({
  name: j.name || j.id,
  next: j.schedule && j.schedule.expr ? j.schedule.expr : 'scheduled'
}));
```

This is already a JSON reader, not a shell parser. The "4m ago shows as pending" bug no longer applies.

**However, a different bug exists:** the code returns `j.schedule.expr` which is a raw cron expression (e.g., `0 */6 * * *`), not a human-readable time like "in 2h". The frontend needs a computed "next run" time, not a cron string.

**Fix for BUILD:** Instead of the plan's shell-parser rewrite, compute the next run time from the cron expression using a library (e.g., `cron-parser`) or read the `nextRunAtMs` field if `jobs.json` includes one. BUILD should check the full structure of `jobs.json` for a pre-computed next-run timestamp.

---

**2. [LOW] Line numbers may have shifted slightly**

server.js was modified at 04:15 UTC today (after the plan was written at 16:50 yesterday), likely from the VIGIL-MISSION-CONTROL build which added `dist/` serving logic. Current file is 395 lines (plan references match approximately). BUILD should verify specific lines before editing.

---

**3. [LOW] `collectSessions()` declares `today` but doesn't use it for session count**

Line 82: `const today = new Date().toISOString().split('T')[0];` is declared but not used in the session count at line 85 (which grep-counts ALL sessions). This confirms the bug and suggests someone intended to filter by date but forgot. The plan's fix correctly uses this date for scoping.

---

### Verified Bugs (all confirmed in actual code)

| Bug | Line | Status |
|-----|------|--------|
| Session count ALL days | 85: `grep -c "Session #"` | Confirmed. Plan fix correct. |
| Gateway errors cumulative | 88: `grep -c "ERROR"` | Confirmed. Plan fix correct. |
| Health check uses Python | 51-52: `python3 -c` | Confirmed. Plan fix correct. |
| Projects hardcoded | 252: `bugsTotal: 12` | Confirmed. Plan fix correct. |
| KANBAN truncated to 5 | 99: `.slice(0, 5)` | Confirmed. Plan fix correct. |
| Upcoming parser | 219-229 | Partially stale (see finding 1). |
| Pipeline from scheduler | N/A | scheduler-state.json exists, format matches plan. |
| Scheduler health | N/A | Valid addition. |

---

### Missing Steps

- Check if `jobs.json` contains a `nextRunAtMs` or `lastRunAtMs` timestamp field. If so, compute "in Xh" from that instead of parsing cron expressions.
- After Step 6 (KANBAN truncation increase), verify the `BLOCKED` section is also included. The plan notes "Blocked items not shown" but Step 6 only increases the slice limit. The `getSection('BLOCKED')` call exists at line 108 but its data may not reach the frontend.

---

### Recommendation

**Send to BUILD** with these notes:

1. **Skip the plan's Step 4 code.** The upcoming jobs parser already reads JSON. Instead, compute human-readable "next run" times from the cron schedule or a pre-computed timestamp in `jobs.json`.
2. Apply Steps 1-3, 5-8 as written; they match the actual code.
3. Restart `vigil-dashboard` service after changes: `sudo systemctl restart vigil-dashboard`.
4. Verify line numbers against the current 395-line server.js before editing.
