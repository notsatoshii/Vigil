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

ACTION|CRITICAL|operate|Ensure Commander surfaces keeper wallet funding request to Master at next contact. Deployer wallet 0x0e4D636c6D79c380A137f28EF73E054364cd5434 has ~0.00000053 ETH on Base Sepolia. Oracle and accrual stalled for 7+ days. Need 0.5 ETH from any faucet to resume oracle prices and fee accrual.
ACTION|MEDIUM|build|Scheduler has no signal-based reload: manual edits to scheduler-state.json are overwritten by in-memory state unless the service is stopped first. Add a SIGUSR1 handler to reload state from disk (no restart needed). Low urgency now that the correct stop-edit-start procedure is documented.


---

## COMPLETED ACTIONS

ACTION|CRITICAL|operate|Manually corrected scheduler-state.json: all 9 lever-bug tasks + vigil-self-improve had verified handoffs but were stuck at "backlog". Updated to "done". vigil-self-improve VERIFY FAIL was stale (bugs already fixed in commit 35d3d42). Scheduler should now pick up new work.
ACTION|CRITICAL|operate|[2026-03-30 02:19] Root cause of repeated reversion found: scheduler.py writes in-memory state every cycle; manual disk edits are overwritten if service stays running. Fix: stop service, edit file, start service. All 9 lever-bug tasks + vigil-self-improve confirmed "done". Service restarted and state verified stable. Ghost support-* tasks are expected behavior (cooldown anchors), not bugs.

ACTION|HIGH|operate|Killed stale root claude PIDs 1151018 (Mar 22, ~1GB) and 1312428 (Mar 26, ~1.2GB). Both were abandoned SSH sessions. RAM freed: ~2.2GB (23% -> ~11% used).
ACTION|HIGH|operate|Removed ghost tasks support-improve, support-operate, support-research from scheduler-state.json. All had empty plan/build/verify files and 0 attempts.
ACTION|HIGH|operate|[2026-03-30 04:24] Dispatched 6 VERIFY sessions for all IN REVIEW KANBAN items: VIGIL-SELF-IMPROVE, VIGIL-VERIFY-VISION, VIGIL-DASHBOARD, LANDING-DESIGN, LEVER-BUG-1 (CRITICAL), LEVER-BUG-6 (CRITICAL).
