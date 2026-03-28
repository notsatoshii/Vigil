#!/bin/bash
# LEVER Command - Tier 1 Health Check
# Runs every 4 hours via cron. No Claude Code session needed.
# If problems are detected, exits with code 1 and logs the issue.
# A wrapper script checks the exit code and spawns OPERATE if needed.

REPORT_FILE="/home/lever/command/heartbeat/last-health-check.json"
PROBLEMS=()
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Check active services
ACTIVE_SERVICES=("lever-frontend" "lever-oracle" "lever-accrue-keeper")
for svc in "${ACTIVE_SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
        PROBLEMS+=("SERVICE_DOWN:$svc")
    fi
done

# Check OpenClaw gateway
if ! systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
    PROBLEMS+=("SERVICE_DOWN:openclaw-gateway")
fi

# Check disk usage
DISK_PCT=$(df / --output=pcent | tail -1 | tr -d ' %')
if [ "$DISK_PCT" -ge 85 ]; then
    PROBLEMS+=("DISK_HIGH:${DISK_PCT}%")
fi

# Check RAM usage
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_PCT=$((RAM_USED * 100 / RAM_TOTAL))
if [ "$RAM_PCT" -ge 90 ]; then
    PROBLEMS+=("RAM_HIGH:${RAM_PCT}%")
fi

# Check if frontend is responding
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000 2>/dev/null)
if [ "$HTTP_CODE" != "200" ]; then
    PROBLEMS+=("FRONTEND_UNRESPONSIVE:HTTP_${HTTP_CODE}")
fi

# Check for stuck Claude Code sessions (running > 6 hours)
# Exclude openclaw gateway and node processes (those are supposed to run long)
STUCK_SESSIONS=0
for pid in $(pgrep -f "claude-code" 2>/dev/null); do
    # Skip gateway-related processes
    CMDLINE=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
    echo "$CMDLINE" | grep -q "openclaw\|gateway" && continue
    ELAPSED=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$ELAPSED" ] && [ "$ELAPSED" -ge 21600 ]; then
        STUCK_SESSIONS=$((STUCK_SESSIONS + 1))
    fi
done
if [ "$STUCK_SESSIONS" -gt 0 ]; then
    PROBLEMS+=("STUCK_SESSIONS:${STUCK_SESSIONS}")
fi

# Build report
PROBLEM_COUNT=${#PROBLEMS[@]}
if [ "$PROBLEM_COUNT" -eq 0 ]; then
    STATUS="healthy"
else
    STATUS="problems_detected"
fi

PROBLEM_JSON="[]"
if [ "$PROBLEM_COUNT" -gt 0 ]; then
    PROBLEM_JSON="["
    for i in "${!PROBLEMS[@]}"; do
        [ "$i" -gt 0 ] && PROBLEM_JSON+=","
        PROBLEM_JSON+="\"${PROBLEMS[$i]}\""
    done
    PROBLEM_JSON+="]"
fi

cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "status": "$STATUS",
  "problems": $PROBLEM_JSON,
  "disk_percent": $DISK_PCT,
  "ram_percent": $RAM_PCT,
  "ram_used_mb": $RAM_USED,
  "ram_total_mb": $RAM_TOTAL,
  "frontend_http": "$HTTP_CODE",
  "stuck_sessions": $STUCK_SESSIONS
}
EOF

echo "[$TIMESTAMP] Health check: $STATUS (${PROBLEM_COUNT} problems)"

if [ "$PROBLEM_COUNT" -gt 0 ]; then
    echo "Problems: ${PROBLEMS[*]}"
    exit 1
fi

exit 0
