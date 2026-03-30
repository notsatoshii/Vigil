# OVERSEER_ACTIONS.md
## Structured action queue written by ADVISOR, dispatched by selfcheck-fast.sh

---

## FORMAT

Each action line uses pipe-delimited format:
```
ACTION|PRIORITY|AGENT|DESCRIPTION
```

- **PRIORITY**: CRITICAL, HIGH, MEDIUM, LOW
  - selfcheck-fast.sh only dispatches HIGH and CRITICAL
- **AGENT**: operate, build, verify, research, improve, plan, advisor
- **DESCRIPTION**: One clear sentence describing what the agent should do

Actions are tracked as dispatched via `/home/lever/command/heartbeat/dispatched-actions.log`.
Once a line appears in dispatched.log it will not be dispatched again.
When an action is resolved, move it to the COMPLETED section below (or delete it).

---

## PENDING ACTIONS



---

## COMPLETED ACTIONS

ACTION|CRITICAL|operate|Manually corrected scheduler-state.json: all 9 lever-bug tasks + vigil-self-improve had verified handoffs but were stuck at "backlog". Updated to "done". vigil-self-improve VERIFY FAIL was stale (bugs already fixed in commit 35d3d42). Scheduler should now pick up new work.

ACTION|HIGH|operate|Killed stale root claude PIDs 1151018 (Mar 22, ~1GB) and 1312428 (Mar 26, ~1.2GB). Both were abandoned SSH sessions. RAM freed: ~2.2GB (23% -> ~11% used).
ACTION|HIGH|operate|Removed ghost tasks support-improve, support-operate, support-research from scheduler-state.json. All had empty plan/build/verify files and 0 attempts.
