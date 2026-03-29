#!/bin/bash
# selfcheck-fast.sh - Fast triage for Vigil system (<10 seconds target)
# Replaces slow AI-based operate-selfcheck cron.
# Checks critical services, logs, disk, RAM, and dispatches OPERATE if needed.
# Also reads OVERSEER_ACTIONS.md and dispatches pending HIGH/CRITICAL actions.

LOG_FILE="/home/lever/command/heartbeat/selfcheck.log"
OVERSEER_ACTIONS="/home/lever/command/shared-brain/OVERSEER_ACTIONS.md"
DISPATCHED_LOG="/home/lever/command/heartbeat/dispatched-actions.log"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PROBLEMS=()

# Fix systemctl DBUS in non-interactive sessions
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket

echo "[$TIMESTAMP] selfcheck-fast starting..." >> "$LOG_FILE"

# ---------------------------------------------------------------
# OPERATE cooldown check: do not pile up sessions
# ---------------------------------------------------------------
if pgrep -f "openclaw.*operate" > /dev/null 2>&1; then
  echo "[$TIMESTAMP] OPERATE already running, skipping" >> "$LOG_FILE"
  exit 0
fi

# ---------------------------------------------------------------
# 1. Critical services
# ---------------------------------------------------------------
CRITICAL_SERVICES=("openclaw-gateway" "vigil-inbox" "vigil-telegram" "vigil-dashboard" "lever-frontend")
for svc in "${CRITICAL_SERVICES[@]}"; do
  if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
    PROBLEMS+=("SERVICE_DOWN:$svc")
  fi
done

# ---------------------------------------------------------------
# 2. Gateway log for recent errors (last 5 minutes)
# ---------------------------------------------------------------
GATEWAY_LOG="/home/lever/command/inbox/telegram-gateway.log"
if [ -f "$GATEWAY_LOG" ]; then
  RECENT_ERRORS=$(awk -v cutoff="$(date -u -d '5 minutes ago' '+%Y-%m-%d %H:%M')" \
    '$0 >= cutoff && /ERROR|CRITICAL|Traceback|Exception/' "$GATEWAY_LOG" 2>/dev/null | wc -l)
  if [ "${RECENT_ERRORS:-0}" -gt 0 ]; then
    PROBLEMS+=("GATEWAY_ERRORS:${RECENT_ERRORS}_in_last_5min")
  fi
fi

# ---------------------------------------------------------------
# 3. Failed messages in inbox
# ---------------------------------------------------------------
FAILED_DIR="/home/lever/command/inbox/failed-messages"
if [ -d "$FAILED_DIR" ]; then
  FAILED_COUNT=$(ls -1 "$FAILED_DIR" 2>/dev/null | wc -l)
  if [ "${FAILED_COUNT:-0}" -gt 0 ]; then
    PROBLEMS+=("FAILED_MESSAGES:${FAILED_COUNT}")
  fi
fi

# ---------------------------------------------------------------
# 4. Disk space (>85%)
# ---------------------------------------------------------------
DISK_PCT=$(df / --output=pcent 2>/dev/null | tail -1 | tr -d ' %')
if [ -n "$DISK_PCT" ] && [ "$DISK_PCT" -ge 85 ]; then
  PROBLEMS+=("DISK_HIGH:${DISK_PCT}%")
fi

# ---------------------------------------------------------------
# 5. RAM usage (>90%)
# ---------------------------------------------------------------
RAM_TOTAL=$(free -m 2>/dev/null | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m 2>/dev/null | awk '/Mem:/ {print $3}')
if [ -n "$RAM_TOTAL" ] && [ "$RAM_TOTAL" -gt 0 ]; then
  RAM_PCT=$((RAM_USED * 100 / RAM_TOTAL))
  if [ "$RAM_PCT" -ge 90 ]; then
    PROBLEMS+=("RAM_HIGH:${RAM_PCT}%")
  fi
fi

# ---------------------------------------------------------------
# 6. Scheduler running
# ---------------------------------------------------------------
if ! pgrep -f "scheduler.py" > /dev/null 2>&1; then
  PROBLEMS+=("SCHEDULER_DOWN")
fi

# ---------------------------------------------------------------
# 7. Dashboard process running
# ---------------------------------------------------------------
if ! systemctl is-active --quiet vigil-dashboard 2>/dev/null; then
  # Already caught above; also check for bare Python/serve process
  if ! pgrep -f "vigil-dashboard\|dashboard.*serve\|generate.*dashboard" > /dev/null 2>&1; then
    # Only add if not already in problems from service check
    if ! echo "${PROBLEMS[*]}" | grep -q "SERVICE_DOWN:vigil-dashboard"; then
      PROBLEMS+=("DASHBOARD_PROCESS_DOWN")
    fi
  fi
fi

# ---------------------------------------------------------------
# Spawn OPERATE if problems found
# ---------------------------------------------------------------
PROBLEM_COUNT=${#PROBLEMS[@]}
if [ "$PROBLEM_COUNT" -gt 0 ]; then
  PROBLEM_STR=$(IFS=", "; echo "${PROBLEMS[*]}")
  MSG="selfcheck-fast detected ${PROBLEM_COUNT} problem(s): ${PROBLEM_STR}. Please diagnose and fix."
  echo "[$TIMESTAMP] Problems found: ${PROBLEM_STR}. Spawning OPERATE." >> "$LOG_FILE"
  openclaw agent --agent operate --message "$MSG" >> "$LOG_FILE" 2>&1 &
else
  echo "[$TIMESTAMP] All clear." >> "$LOG_FILE"
fi

# ---------------------------------------------------------------
# Dispatch pending HIGH/CRITICAL actions from OVERSEER_ACTIONS.md
# ---------------------------------------------------------------
if [ -f "$OVERSEER_ACTIONS" ]; then
  # Read ACTION lines (format: ACTION|PRIORITY|AGENT|DESCRIPTION)
  while IFS= read -r line; do
    # Must start with ACTION|
    [[ "$line" != ACTION\|* ]] && continue

    # Extract priority
    PRIORITY=$(echo "$line" | cut -d'|' -f2)
    if [[ "$PRIORITY" != "HIGH" && "$PRIORITY" != "CRITICAL" ]]; then
      continue
    fi

    # Skip if already dispatched
    if grep -qF "$line" "$DISPATCHED_LOG" 2>/dev/null; then
      continue
    fi

    # Extract agent and description
    AGENT=$(echo "$line" | cut -d'|' -f3 | tr '[:upper:]' '[:lower:]')
    DESCRIPTION=$(echo "$line" | cut -d'|' -f4-)

    # Only dispatch if OPERATE is not already running (re-check in loop)
    if pgrep -f "openclaw.*operate" > /dev/null 2>&1; then
      echo "[$TIMESTAMP] OPERATE already running, skipping overseer action: $line" >> "$LOG_FILE"
      break
    fi

    echo "[$TIMESTAMP] Dispatching $PRIORITY action to $AGENT: $DESCRIPTION" >> "$LOG_FILE"
    openclaw agent --agent "$AGENT" --message "OVERSEER ACTION ($PRIORITY): $DESCRIPTION" >> "$LOG_FILE" 2>&1 &

    # Mark as dispatched using log file (not sed -i, per critique)
    echo "$line" >> "$DISPATCHED_LOG"

    # One dispatch per run to avoid flooding
    break

  done < <(grep "^ACTION|" "$OVERSEER_ACTIONS" 2>/dev/null)
fi

echo "[$TIMESTAMP] selfcheck-fast done. Problems: ${PROBLEM_COUNT}" >> "$LOG_FILE"
exit 0
