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

(none yet)

---

## COMPLETED ACTIONS

(none yet)
