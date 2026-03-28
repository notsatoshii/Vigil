#!/bin/bash
# LEVER Command - Health Check Wrapper with Tier 2 Escalation
# Runs the Tier 1 health check. If problems are found, attempts
# autonomous remediation (restart services, max 2 attempts).
# If remediation fails, logs for OPERATE Claude Code session.

LOG_FILE="/home/lever/command/heartbeat/health-check.log"
REPORT_FILE="/home/lever/command/heartbeat/last-health-check.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[$TIMESTAMP] Running health check..." >> "$LOG_FILE"

# Run Tier 1 check
bash /home/lever/command/heartbeat/health-check.sh >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "[$TIMESTAMP] All clear." >> "$LOG_FILE"
    exit 0
fi

echo "[$TIMESTAMP] Problems detected. Attempting autonomous remediation..." >> "$LOG_FILE"

# Parse problems from report
if [ ! -f "$REPORT_FILE" ]; then
    echo "[$TIMESTAMP] ERROR: No report file found." >> "$LOG_FILE"
    exit 1
fi

# Attempt to restart down services (max 2 attempts each)
# NEVER restart disabled services
SACRED_SERVICES="lever-loop lever-qa lever-seeder lever-watchdog"

REMEDIATED=true
while IFS= read -r problem; do
    problem=$(echo "$problem" | tr -d '",' | xargs)
    [ -z "$problem" ] || [ "$problem" = "[" ] || [ "$problem" = "]" ] && continue

    if [[ "$problem" == SERVICE_DOWN:* ]]; then
        SVC="${problem#SERVICE_DOWN:}"

        # Check if sacred
        if echo "$SACRED_SERVICES" | grep -qw "$SVC"; then
            echo "[$TIMESTAMP] SACRED: $SVC is down but must NOT be restarted." >> "$LOG_FILE"
            continue
        fi

        # Attempt restart (max 2 tries)
        # Note: this script runs as root via cron; sudo is not needed and causes
        # "Failed to connect to bus: No medium found" in non-interactive sessions.
        for attempt in 1 2; do
            echo "[$TIMESTAMP] Restarting $SVC (attempt $attempt)..." >> "$LOG_FILE"
            systemctl restart "$SVC" 2>> "$LOG_FILE"
            sleep 3
            if systemctl is-active --quiet "$SVC"; then
                break
            fi
            if [ "$attempt" -eq 2 ]; then
                echo "[$TIMESTAMP] FAILED: Could not restart $SVC after 2 attempts." >> "$LOG_FILE"
                REMEDIATED=false
            fi
        done
    else
        # Non-service problems (disk, RAM, stuck sessions) need OPERATE
        echo "[$TIMESTAMP] Cannot auto-remediate: $problem" >> "$LOG_FILE"
        REMEDIATED=false
    fi
done < <(grep -o '"[^"]*"' "$REPORT_FILE" | grep -E "SERVICE_DOWN|DISK_HIGH|RAM_HIGH|FRONTEND_UNRESPONSIVE|STUCK_SESSIONS")

if [ "$REMEDIATED" = true ]; then
    echo "[$TIMESTAMP] All issues remediated autonomously." >> "$LOG_FILE"
    # Re-run health check to confirm
    bash /home/lever/command/heartbeat/health-check.sh >> "$LOG_FILE" 2>&1
    exit 0
else
    echo "[$TIMESTAMP] Escalation needed. OPERATE session should be spawned." >> "$LOG_FILE"
    # Write escalation marker for OpenClaw/cron to pick up
    echo "$TIMESTAMP" > /home/lever/command/heartbeat/needs-escalation
    exit 1
fi
