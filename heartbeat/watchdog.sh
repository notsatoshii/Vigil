#!/bin/bash
# watchdog.sh - 60-second loop ensuring scheduler and gateway stay alive
# Run via: nohup bash /home/lever/command/heartbeat/watchdog.sh &
# Or via a systemd service.

LOG_FILE="/home/lever/command/heartbeat/watchdog.log"
SCHEDULER_SCRIPT="/home/lever/command/heartbeat/scheduler.py"
SCHEDULER_STATE="/home/lever/command/heartbeat/scheduler-state.json"

# Fix systemctl DBUS in non-interactive sessions
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_FILE"
}

log "watchdog.sh starting (PID $$)"

while true; do

  # -----------------------------------------------------------
  # Check 1: Scheduler running
  # -----------------------------------------------------------
  if ! pgrep -f "scheduler.py" > /dev/null 2>&1; then
    log "WARN: scheduler.py not running. Attempting restart..."
    cd /home/lever/command/heartbeat && nohup python3 "$SCHEDULER_SCRIPT" >> scheduler.log 2>&1 &
    SCHED_PID=$!
    sleep 3
    if pgrep -f "scheduler.py" > /dev/null 2>&1; then
      log "INFO: scheduler.py restarted (PID ${SCHED_PID})"
    else
      log "ERROR: Failed to restart scheduler.py"
    fi
  fi

  # -----------------------------------------------------------
  # Check 2: Gateway responding
  # -----------------------------------------------------------
  if ! systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
    log "WARN: openclaw-gateway not active. Attempting restart..."
    systemctl restart openclaw-gateway 2>> "$LOG_FILE"
    sleep 5
    if systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
      log "INFO: openclaw-gateway restarted successfully"
    else
      log "ERROR: Failed to restart openclaw-gateway. Requires manual intervention."
    fi
  fi

  # -----------------------------------------------------------
  # Check 3: At least one active session (poke scheduler if none)
  # Session count check: touch state file to nudge scheduler
  # Note: this is a lightweight signal, not a guaranteed dispatch trigger.
  # -----------------------------------------------------------
  ACTIVE_SESSIONS=0
  if [ -f "$SCHEDULER_STATE" ]; then
    ACTIVE_SESSIONS=$(python3 -c "
import json, sys
try:
  d = json.load(open('$SCHEDULER_STATE'))
  print(len(d.get('active_sessions', {})))
except:
  print(0)
" 2>/dev/null)
  fi

  if [ "${ACTIVE_SESSIONS:-0}" -eq 0 ]; then
    # Touch the state file to poke the scheduler's mtime watcher (if any)
    touch "$SCHEDULER_STATE" 2>/dev/null
    log "INFO: Zero active sessions detected. Touched scheduler-state.json to poke scheduler."
  fi

  sleep 60

done
