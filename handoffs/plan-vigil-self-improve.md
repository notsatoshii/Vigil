# Plan: VIGIL-SELF-IMPROVE — Continuous Self-Improvement Without Master Intervention
## Date: 2026-03-28T17:05:00Z
## Requested by: Master (via Commander)

---

### Problem Statement

Master said: "without me having to say anything. EVER." The system must be completely self-
monitoring and self-improving. Currently it is not.

**What exists:**
- `operate-selfcheck` (hourly OPERATE cron): diagnose and fix Vigil infrastructure
- `overseer` (2-hourly ADVISOR cron): cross-cutting analysis, proposals, brain maintenance
- `improve-weekly-review` (weekly IMPROVE cron): product UX review
- `research-*-scan` (twice daily): knowledge gathering
- `health-check.sh` (4-hourly bash script): service/disk/RAM checks

**What is broken:**
- `operate-selfcheck`: **ERROR** status, timing out at 600s. Cannot diagnose or fix anything.
- `overseer`: **ERROR** status, timing out at 1800s. Produced 2 reports but action items go unexecuted.
- The overseer's own report says: "Zero of five action items completed in 2 hours. The system
  does not act on its own oversight reports. This is a meta-problem."
- There is no closed loop: overseer detects problem, writes it in a report, nobody reads the
  report and acts on it.
- The scheduler treats support tasks (OPERATE, RESEARCH, IMPROVE) as equal priority to
  pipeline tasks (PLAN, CRITIQUE, BUILD, VERIFY), causing priority inversion.
- IMPROVE and RESEARCH only run on schedule, not when idle.

**The fundamental gap:** Detection without action. The overseer can SEE problems but the system
has no mechanism to automatically FIX what it finds.

---

### Root Cause Analysis

#### Why operate-selfcheck times out

The OPERATE CLAUDE.md (lines 100-134) instructs the agent to:
1. Read gateway logs, inbox logs, health check, OpenClaw logs
2. Diagnose root causes
3. Fix issues (edit scripts, restart services)
4. Verify fixes work
5. Log lessons and commit to git

This is too much for a 600s (10 min) session. Reading logs alone can consume minutes. If there
are multiple issues, diagnosis + fix + verify + commit exceeds the timeout easily.

#### Why overseer times out

The ADVISOR CLAUDE.md (lines 59-96) instructs the overseer to:
1. Read ALL shared brain files, recent sessions, VERIFY/SECURE reports, personality log, system logs
2. Analyze across 5 dimensions (technical, strategic, design, operational, system)
3. Write daily brief
4. Propose system improvements
5. Prune and maintain brain files

Reading all shared-brain files + all recent handoffs + analyzing 5 dimensions is a massive
context load. The agent spends most of the 1800s reading files and runs out of time before
producing actionable output.

#### Why action items go unexecuted

The overseer writes action items in OVERSEER_REPORT.md. But:
- Nobody reads OVERSEER_REPORT.md between reports
- The scheduler does not parse action items from the report
- OPERATE does not check the overseer report during self-checks
- There is no dispatch mechanism: "overseer says X is broken" does not become "OPERATE session
  spawned to fix X"

---

### Approach

Five changes, from simplest to most architectural:

**1. Fix the timeouts** — Make operate-selfcheck and overseer complete within their time limits
by narrowing their scope and splitting large tasks.

**2. Create the detection-to-action loop** — When the overseer identifies a problem, it writes
a structured action item that the scheduler can parse and dispatch.

**3. Fix scheduler priority** — Pipeline tasks (advancing bugs through PLAN->CRITIQUE->BUILD->VERIFY)
always take priority over support tasks (OPERATE, RESEARCH, IMPROVE).

**4. Make support tasks fill idle slots** — Instead of running on fixed schedules only, support
tasks dispatch whenever a slot is free and no pipeline work is queued.

**5. Add lightweight continuous monitoring** — A bash watchdog (not a full AI session) that
checks logs every 60 seconds and only spawns an OPERATE session when something is actually wrong.

---

### Implementation Steps

**Step 1: Narrow operate-selfcheck scope**

The self-check tries to do everything in one session. Split it into a fast triage (bash) +
targeted fix (AI session only when needed).

New file: `/home/lever/command/heartbeat/selfcheck-fast.sh`

```bash
#!/bin/bash
# Fast self-check (runs in <10s, no AI session needed)
# Only spawns OPERATE session if problems are found

PROBLEMS=""

# Check critical services
for svc in openclaw-gateway vigil-inbox vigil-telegram vigil-dashboard lever-frontend; do
  if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
    PROBLEMS="$PROBLEMS SERVICE_DOWN:$svc"
  fi
done

# Check gateway log for recent errors (last 5 minutes)
RECENT_ERRORS=$(find /home/lever/command/inbox/telegram-gateway.log -mmin -5 -exec grep -c "ERROR" {} \; 2>/dev/null)
if [ "${RECENT_ERRORS:-0}" -gt 5 ]; then
  PROBLEMS="$PROBLEMS GATEWAY_ERRORS:$RECENT_ERRORS"
fi

# Check failed messages
FAILED=$(find /home/lever/command/inbox/failed-messages/ -name '*.json' -mmin -60 2>/dev/null | wc -l)
if [ "$FAILED" -gt 0 ]; then
  PROBLEMS="$PROBLEMS FAILED_MESSAGES:$FAILED"
fi

# Check disk space
DISK_PCT=$(df / --output=pcent | tail -1 | tr -d ' %')
if [ "$DISK_PCT" -gt 85 ]; then
  PROBLEMS="$PROBLEMS DISK_HIGH:${DISK_PCT}%"
fi

# Check RAM
RAM_PCT=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
if [ "$RAM_PCT" -gt 90 ]; then
  PROBLEMS="$PROBLEMS RAM_HIGH:${RAM_PCT}%"
fi

# Check scheduler is running
if ! pgrep -f "scheduler.py" > /dev/null 2>&1; then
  PROBLEMS="$PROBLEMS SCHEDULER_DOWN"
fi

# Check dashboard data freshness
if [ -f /home/lever/command/dashboard/server.js ]; then
  DASH_PID=$(pgrep -f "node.*server.js.*dashboard" 2>/dev/null)
  if [ -z "$DASH_PID" ]; then
    PROBLEMS="$PROBLEMS DASHBOARD_DOWN"
  fi
fi

# Check overseer report for unacted action items
if [ -f /home/lever/command/shared-brain/OVERSEER_REPORT.md ]; then
  OVERDUE=$(grep -c "OVERDUE" /home/lever/command/shared-brain/OVERSEER_REPORT.md 2>/dev/null)
  if [ "${OVERDUE:-0}" -gt 0 ]; then
    PROBLEMS="$PROBLEMS OVERSEER_OVERDUE:$OVERDUE"
  fi
fi

if [ -n "$PROBLEMS" ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) PROBLEMS DETECTED: $PROBLEMS" >> /home/lever/command/heartbeat/selfcheck.log
  # Spawn OPERATE session to fix the problems
  openclaw agent --agent operate --message "SELFCHECK ALERT: $PROBLEMS. Diagnose and fix these issues. Check /home/lever/command/heartbeat/selfcheck.log for history." &
else
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) OK" >> /home/lever/command/heartbeat/selfcheck.log
fi
```

Replace the operate-selfcheck cron with this bash script running every 5 minutes. The script
completes in <10 seconds. It only spawns an AI session when problems are detected, and the
session message tells OPERATE exactly what to fix.

Update the cron:
```
openclaw cron delete <operate-selfcheck-id>
# Replace with a systemd timer or crontab entry:
*/5 * * * * /home/lever/command/heartbeat/selfcheck-fast.sh
```

---

**Step 2: Narrow overseer scope and increase timeout**

The overseer tries to analyze everything in one session. Split into focused phases:

Update `/home/lever/command/workspaces/advisor/CLAUDE.md` overseer section to:

```markdown
### Overseer (2-hourly cron)

**Time budget: 20 minutes. Do NOT read everything. Be surgical.**

1. Read ONLY these files (5 minutes max):
   - KANBAN.md (current task state)
   - OVERSEER_REPORT.md (your last report, check if actions were completed)
   - scheduler-state.json (pipeline health)
   - RECENT_SESSIONS.md (last 5 entries only)
   - TIMMY_PERSONALITY.md OBSERVATION LOG (last 5 entries only)

2. Analyze (5 minutes):
   - Are planned tasks advancing to critique/build/verify?
   - Are any tasks stuck (same stage for >2 hours)?
   - Is the scheduler burning slots on support while pipeline work waits?
   - Were previous action items completed?
   - Any new Master frustration events?

3. Write actions to /home/lever/command/shared-brain/OVERSEER_ACTIONS.md (5 minutes):
   For each action item, write one structured line:
   ```
   ACTION|PRIORITY|AGENT|DESCRIPTION
   ```
   Example:
   ```
   ACTION|CRITICAL|operate|Fix scheduler-state.json: BUG-3 plan_file should be plan-lever-bug-3.md
   ACTION|HIGH|scheduler|Dispatch CRITIQUE for BUG-3 and BUG-4 immediately
   ACTION|MEDIUM|build|Pick up IMPROVE Proposal #1 (empty header stats)
   ```

4. Update OVERSEER_REPORT.md (5 minutes):
   - Brief efficiency/quality assessment
   - Top 3 issues only (not 7 sections)
   - Mark completed action items as DONE

**DO NOT:**
- Read all handoff files (only read specific ones if investigating a stuck task)
- Analyze 5 dimensions (focus on pipeline flow and blockers)
- Write long-form proposals (use structured ACTION lines)
- Prune brain files (that is a separate weekly task)
```

Also increase the cron timeout to 2400s (40 min) for safety margin:
```
openclaw cron update <overseer-id> --timeout 2400
```

---

**Step 3: Create OVERSEER_ACTIONS.md and the action dispatcher**

New file: `/home/lever/command/shared-brain/OVERSEER_ACTIONS.md`

```markdown
# OVERSEER ACTIONS
## Structured action items. Read by selfcheck-fast.sh and scheduler.
## Format: ACTION|PRIORITY|AGENT|DESCRIPTION
## DONE items are pruned weekly.

```

The selfcheck-fast.sh script (from Step 1) already checks for OVERDUE items. Extend it to
also read OVERSEER_ACTIONS.md and dispatch the highest-priority undone action:

Add to selfcheck-fast.sh:
```bash
# Check for undispatched overseer actions
if [ -f /home/lever/command/shared-brain/OVERSEER_ACTIONS.md ]; then
  TOP_ACTION=$(grep "^ACTION|CRITICAL\|^ACTION|HIGH" /home/lever/command/shared-brain/OVERSEER_ACTIONS.md | head -1)
  if [ -n "$TOP_ACTION" ]; then
    AGENT=$(echo "$TOP_ACTION" | cut -d'|' -f3)
    DESC=$(echo "$TOP_ACTION" | cut -d'|' -f4)
    if [ "$AGENT" = "operate" ]; then
      # Dispatch OPERATE to handle it
      openclaw agent --agent operate --message "OVERSEER ACTION: $DESC" &
      # Mark as dispatched
      sed -i "s|^$TOP_ACTION|DISPATCHED|$TOP_ACTION|" /home/lever/command/shared-brain/OVERSEER_ACTIONS.md
    fi
  fi
fi
```

This closes the loop: overseer detects problem, writes structured action, selfcheck reads it
and dispatches the right agent.

---

**Step 4: Fix scheduler priority model**

The scheduler (scheduler.py) needs a priority system. Currently it fills slots round-robin
from all available work. It should fill pipeline work first.

The scheduler.py is a Python script. The fix is a priority ordering change in the dispatch logic.

**Priority tiers (BUILD must implement in scheduler.py):**

| Priority | Task Type | When to dispatch |
|----------|-----------|-----------------|
| 1 (highest) | Pipeline advancement (CRITIQUE for planned tasks, BUILD for approved tasks, VERIFY for built tasks) | ALWAYS, before anything else |
| 2 | Pipeline start (PLAN for backlog items) | When no tier-1 work exists |
| 3 | Support tasks (OPERATE, RESEARCH, IMPROVE) | Only when no tier-1 or tier-2 work AND slot is free |
| 4 | Scheduled crons (already handled by openclaw cron) | Separate from slot allocation |

**Implementation in scheduler.py dispatch loop:**

```python
def get_next_task():
    # Tier 1: Advance existing pipeline tasks
    for task in tasks.values():
        if task.stage == 'planned' and task.plan_file:
            return ('critique', task)  # Plan exists, needs critique
        if task.stage == 'approved':
            return ('build', task)     # Critique passed, needs build
        if task.stage == 'built':
            return ('verify', task)    # Build done, needs verify

    # Tier 2: Start new pipeline tasks from KANBAN backlog
    backlog = get_kanban_backlog()
    if backlog:
        return ('plan', backlog[0])

    # Tier 3: Support tasks (only if nothing else to do)
    return ('support', pick_support_task())
```

BUILD must read scheduler.py to understand the current dispatch logic and modify it to follow
this priority model. The key change: iterate existing tasks looking for advancement opportunities
BEFORE starting new work or running support tasks.

---

**Step 5: Make support tasks idle-fill instead of scheduled**

Current state: IMPROVE runs weekly (Wed 9am), RESEARCH runs twice daily (8am/8pm). Master
wants them to run "whenever idle."

**Change:** Remove the weekly/daily cron schedules for IMPROVE and RESEARCH. Instead, have the
scheduler's tier-3 logic cycle through support tasks:

```python
SUPPORT_ROTATION = ['operate', 'improve', 'research', 'secure']
_support_index = 0

def pick_support_task():
    global _support_index
    agent = SUPPORT_ROTATION[_support_index % len(SUPPORT_ROTATION)]
    _support_index += 1
    return agent
```

When no pipeline work is available, the scheduler cycles through support agents. This guarantees:
- IMPROVE runs whenever there is idle capacity (not just Wednesdays)
- RESEARCH runs whenever there is idle capacity (not just 8am/8pm)
- OPERATE gets regular self-checks
- SECURE gets regular audits

Keep the advisor-daily-brief (6am) and ceo-weekly-brief (Mon 7am) on their schedules since
those are time-specific deliverables.

---

**Step 6: Add the watchdog timer**

New file: `/home/lever/command/heartbeat/watchdog.sh`

A 60-second loop that checks if the system is actually working:

```bash
#!/bin/bash
# Watchdog: runs as a systemd service, checks every 60 seconds
# Much lighter than a full self-check; only checks for critical failures

while true; do
  # 1. Is the scheduler running?
  if ! pgrep -f "scheduler.py" > /dev/null 2>&1; then
    echo "$(date -u) WATCHDOG: Scheduler down, restarting" >> /home/lever/command/heartbeat/watchdog.log
    cd /home/lever/command/heartbeat && python3 scheduler.py &
  fi

  # 2. Is the gateway responding?
  if ! pgrep -f "openclaw" > /dev/null 2>&1; then
    echo "$(date -u) WATCHDOG: Gateway down, restarting" >> /home/lever/command/heartbeat/watchdog.log
    sudo systemctl restart openclaw-gateway 2>/dev/null
  fi

  # 3. Are there any active sessions? (Master says zero idle time)
  ACTIVE=$(ps aux | grep 'openclaw agent' | grep -v grep | wc -l)
  if [ "$ACTIVE" -eq 0 ]; then
    echo "$(date -u) WATCHDOG: Zero active sessions, poking scheduler" >> /home/lever/command/heartbeat/watchdog.log
    # Touch the scheduler state to trigger a dispatch cycle
    touch /home/lever/command/heartbeat/scheduler-state.json
  fi

  sleep 60
done
```

Create systemd service: `/etc/systemd/system/vigil-watchdog.service`

```ini
[Unit]
Description=Vigil Watchdog
After=network.target

[Service]
Type=simple
User=lever
ExecStart=/bin/bash /home/lever/command/heartbeat/watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

The watchdog is a 60-second bash loop that costs almost no resources. It ensures the scheduler
and gateway are always running, and pokes the scheduler if sessions drop to zero.

---

### Files to Create

- `/home/lever/command/heartbeat/selfcheck-fast.sh` — fast bash triage (replaces AI cron)
- `/home/lever/command/heartbeat/watchdog.sh` — 60-second bash loop
- `/home/lever/command/shared-brain/OVERSEER_ACTIONS.md` — structured action items
- `/etc/systemd/system/vigil-watchdog.service` — watchdog service

### Files to Modify

- `/home/lever/command/workspaces/advisor/CLAUDE.md` — narrow overseer scope, add time budget
- `/home/lever/command/workspaces/operate/CLAUDE.md` — reference selfcheck-fast.sh, OVERSEER_ACTIONS
- `/home/lever/command/heartbeat/scheduler.py` — priority-based dispatch (tier 1/2/3)

### Cron Changes

- Delete `operate-selfcheck` openclaw cron (replaced by selfcheck-fast.sh as system crontab)
- Update `overseer` timeout to 2400s
- Optionally delete `improve-weekly-review` and `research-*-scan` (replaced by idle-fill in scheduler)

### Files to Read First

- `/home/lever/command/heartbeat/scheduler.py` — full file (understand dispatch logic)
- `/home/lever/command/workspaces/advisor/CLAUDE.md` — full overseer section
- `/home/lever/command/workspaces/operate/CLAUDE.md` — full self-check section
- `/home/lever/command/shared-brain/OVERSEER_REPORT.md` — understand what the overseer produces
- `/home/lever/command/shared-brain/INTENTIONS.md` — Master's standing orders

---

### Dependencies and Ripple Effects

- **Scheduler changes:** Modifying scheduler.py affects all task dispatch. The priority model
  must be tested carefully. A broken scheduler = zero sessions dispatched = total system halt.
  BUILD must test the priority logic with the current scheduler-state.json before deploying.

- **Cron replacement:** Replacing operate-selfcheck with selfcheck-fast.sh means the hourly
  AI session no longer runs automatically. Instead, AI sessions only spawn when problems are
  detected. This saves ~24 AI sessions/day that were timing out anyway.

- **Overseer actions format:** The `ACTION|PRIORITY|AGENT|DESCRIPTION` format is a new convention.
  Both the overseer (ADVISOR) and the selfcheck script must agree on this format. If the format
  changes, both must be updated.

- **Watchdog service:** A new systemd service. Must be enabled: `systemctl enable --now vigil-watchdog`.
  If the watchdog itself fails, systemd restarts it (RestartSec=10).

- **Session budget:** Replacing hourly AI self-checks with on-demand sessions and making support
  tasks idle-fill could increase or decrease total session count depending on system health.
  Monitor SESSION_COSTS.md for the first few days after deployment.

---

### The Closed Loop (How It All Connects)

```
watchdog.sh (every 60s)
  └─ Ensures scheduler and gateway are running
  └─ Pokes scheduler if zero sessions active

selfcheck-fast.sh (every 5 min)
  └─ Checks services, logs, disk, RAM, overseer actions
  └─ If problems: spawns OPERATE session with specific problem description
  └─ If overseer action pending: dispatches the right agent

overseer (every 2h, ADVISOR cron)
  └─ Reads KANBAN, scheduler state, recent sessions
  └─ Identifies stuck tasks, priority inversions, unacted issues
  └─ Writes structured ACTION lines to OVERSEER_ACTIONS.md
  └─ Next selfcheck-fast.sh cycle picks up and dispatches

scheduler.py (every 10s)
  └─ Tier 1: Advance pipeline (critique planned, build approved, verify built)
  └─ Tier 2: Start new pipeline (plan backlog items)
  └─ Tier 3: Fill idle slots with support (operate, improve, research, secure)

Result: problems are detected within 5 minutes, dispatched within 10 minutes,
and fixed within 30 minutes. No Master intervention needed.
```

---

### Edge Cases

**All systems healthy, no pipeline work:** Scheduler fills all 5 slots with support tasks
(tier 3 rotation). IMPROVE reviews the product, RESEARCH gathers intelligence, OPERATE checks
infrastructure, SECURE audits contracts. Zero idle time achieved.

**Multiple problems detected simultaneously:** selfcheck-fast.sh concatenates all problems into
one OPERATE session message. OPERATE triages and fixes in priority order within one session.

**Overseer produces too many actions:** selfcheck-fast.sh dispatches only the top action per
cycle (every 5 min). With 12 cycles/hour, up to 12 actions can be dispatched per hour. If
actions pile up, the overseer should prioritize harder in its next report.

**Scheduler down:** Watchdog detects within 60 seconds and restarts it. Sessions resume within
the next scheduler cycle (10 seconds after restart).

**Watchdog itself fails:** systemd RestartSec=10 restarts it. If systemd is down, everything
is down (OS-level failure, not a Vigil problem).

---

### Test Plan

| Test | What it verifies |
|------|-----------------|
| selfcheck-fast.sh runs in <10s | Fast enough for 5-min cron |
| selfcheck-fast.sh detects a stopped service | Spawns OPERATE with correct message |
| selfcheck-fast.sh reads OVERSEER_ACTIONS.md | Dispatches pending actions |
| overseer completes within 2400s | Timeout no longer reached |
| overseer writes structured ACTION lines | Parseable by selfcheck-fast.sh |
| scheduler dispatches critique before support | Priority tier 1 > tier 3 |
| scheduler fills idle slots with support rotation | Zero idle time when no pipeline work |
| watchdog restarts dead scheduler | Recovery within 60 seconds |
| Full loop: overseer detects → action written → selfcheck dispatches → OPERATE fixes | End-to-end closed loop |

---

### Effort Estimate

**Large** — 1-2 days.
- selfcheck-fast.sh: 1 hour
- watchdog.sh + service: 30 minutes
- OVERSEER_ACTIONS.md + format: 15 minutes
- CLAUDE.md updates (advisor, operate): 1 hour
- scheduler.py priority model: 2-3 hours (most complex, highest risk)
- Cron changes: 30 minutes
- Testing: 2 hours

---

### Rollback Plan

**selfcheck-fast.sh:** Disable the crontab entry. Re-enable the openclaw operate-selfcheck cron
(it will timeout again, but the system returns to its previous state).

**scheduler.py priority model:** `git checkout -- heartbeat/scheduler.py`. Scheduler reverts to
round-robin dispatch.

**watchdog:** `systemctl stop vigil-watchdog && systemctl disable vigil-watchdog`.

---

### Open Questions

1. **Scheduler.py structure:** BUILD must read the full scheduler.py to understand its dispatch
   loop before implementing the priority model. The plan describes the desired behavior but not
   the exact code change, because the scheduler's internal structure has not been fully read.

2. **OPERATE session budget:** On-demand OPERATE sessions (spawned by selfcheck) have no hard
   cap. If the system is unhealthy and selfcheck spawns OPERATE every 5 minutes, it could burn
   through session budget fast. Consider a cooldown: selfcheck should not spawn OPERATE if an
   OPERATE session is already running (check `ps aux | grep 'openclaw agent.*operate'`).

---

### KANBAN Update

Move VIGIL-SELF-IMPROVE to PLANNED.
