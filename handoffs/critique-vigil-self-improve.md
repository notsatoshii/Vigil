# Critique: VIGIL-SELF-IMPROVE — Continuous Self-Improvement Without Master Intervention
## Date: 2026-03-29T10:46:00Z
## Plan reviewed: handoffs/plan-vigil-self-improve.md
## Codebase verified against: /home/lever/command/heartbeat/scheduler.py (561 lines, modified 09:13 UTC)

---

### Verdict: APPROVED (with notes — Steps 4 and 5 are already implemented)

The plan's architecture is sound: fast bash triage + structured action dispatch + scheduler priority + watchdog. However, the scheduler already implements the priority model (Step 4) and idle-fill support rotation (Step 5). The remaining work (selfcheck-fast, overseer narrowing, action format, watchdog) is valid and needed.

---

### What Is Good

- Correct root cause: detection without action. The overseer writes reports that nobody reads.
- The closed-loop architecture (watchdog -> selfcheck -> overseer -> action dispatch) is well-designed.
- Replacing timeout-prone AI crons with fast bash triage is a significant efficiency gain (~24 sessions/day saved).
- The `OVERSEER_ACTIONS.md` structured format (`ACTION|PRIORITY|AGENT|DESCRIPTION`) bridges the overseer-to-dispatcher gap.
- Open Question 2 (OPERATE cooldown) correctly identifies the session-burn risk.

---

### Issues Found

**1. [HIGH] Steps 4 and 5 are already implemented in scheduler.py. BUILD should skip them.**

The actual scheduler.py (lines 350-477) already has:

**Priority-based dispatch (Step 4 equivalent, lines 363-422):**
1. First: advance pipeline tasks (critique for planned, build for approved, verify for built)
2. Then: start one new PLAN from backlog (only if no PLAN is running)
3. Then: fill idle slots with support (only if `pipeline_work_waiting` is False)

**Idle-fill support rotation (Step 5 equivalent, lines 424-477):**
- IMPROVE, OPERATE, and RESEARCH are dispatched when no pipeline work is waiting
- 2-hour cooldown between support runs (`SUPPORT_COOLDOWN = 7200`)
- Already checks `not pipeline_work_waiting` before dispatching support

The plan's description of the scheduler as "round-robin" is incorrect. The scheduler already implements the exact priority model the plan proposes. BUILD should NOT modify the dispatch logic unless adding new features (like reading OVERSEER_ACTIONS.md for dispatch hints).

---

**2. [MEDIUM] selfcheck-fast.sh should check if OPERATE is already running before spawning**

Open Question 2 flags this but doesn't include it in the script. If selfcheck-fast.sh runs every 5 minutes and each cycle spawns OPERATE, and OPERATE takes 10+ minutes, multiple OPERATE sessions pile up. Add to the script:

```bash
if pgrep -f "openclaw agent.*operate" > /dev/null 2>&1; then
  echo "$(date -u) OPERATE already running, skipping" >> selfcheck.log
  exit 0
fi
```

---

**3. [MEDIUM] The `sed -i` for marking dispatched actions is fragile**

Step 3 uses `sed -i "s|^$TOP_ACTION|DISPATCHED|$TOP_ACTION|"` to mark actions as dispatched. This is brittle: if the action description contains special characters (pipes, slashes, regex metacharacters), the sed command fails or corrupts the file. Use a simpler approach: after dispatching, write the dispatched action to a separate log file and grep -v to exclude already-dispatched items:

```bash
DISPATCHED_LOG="/home/lever/command/heartbeat/dispatched-actions.log"
if ! grep -qF "$TOP_ACTION" "$DISPATCHED_LOG" 2>/dev/null; then
  # dispatch...
  echo "$TOP_ACTION" >> "$DISPATCHED_LOG"
fi
```

---

**4. [LOW] Watchdog check #2 (gateway) uses overly broad process check**

Step 6's watchdog checks `pgrep -f "openclaw"` to detect if the gateway is running. But `openclaw agent` sessions also match `openclaw`. This would never restart the gateway because agent sessions are always running. Use the specific service name:

```bash
if ! systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
```

---

**5. [LOW] Watchdog check #3 (zero sessions) may conflict with scheduler**

The watchdog "pokes scheduler" by touching `scheduler-state.json` when zero sessions are active. But zero sessions is a valid state (e.g., all work is done, or the daily session limit was hit). Touching the state file doesn't trigger a dispatch cycle (the scheduler runs on its own timer). This check is effectively a no-op. Either remove it or have the watchdog call the scheduler's dispatch function directly (which requires more integration).

---

### Missing Steps

- Verify that `openclaw agent --agent operate --message "..."` is the correct CLI syntax for spawning an agent session from bash. BUILD should test this command manually before putting it in selfcheck-fast.sh.
- The ADVISOR CLAUDE.md changes (Step 2) should be tested by running one overseer cycle and timing it. If it still exceeds 2400s with the narrowed scope, further trimming is needed.

---

### Recommendation

**Send to BUILD** with these notes:

1. **Skip Steps 4 and 5.** The scheduler already has priority-based dispatch and idle-fill support with 2-hour cooldown. Do not modify scheduler.py dispatch logic.
2. **Implement Steps 1, 2, 3, and 6** (selfcheck-fast.sh, overseer scope narrowing, OVERSEER_ACTIONS.md, watchdog).
3. Add OPERATE-already-running guard to selfcheck-fast.sh (finding 2).
4. Use a dispatched-actions log file instead of `sed -i` for marking actions (finding 3).
5. Fix the watchdog gateway check to use `systemctl is-active openclaw-gateway` instead of `pgrep openclaw` (finding 4).
6. Test `openclaw agent --agent operate --message "..."` syntax manually before deploying.
