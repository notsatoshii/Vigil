#!/bin/bash
# Vigil Dashboard - Data Generator
# Outputs JSON to /home/lever/command/dashboard/data.json
# Called every 60 seconds by systemd timer

OUTPUT="/home/lever/command/dashboard/data.json"
BRAIN="/home/lever/command/shared-brain"
HEALTH="/home/lever/command/heartbeat/last-health-check.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EPOCH=$(date +%s)

# System metrics
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_PCT=$((RAM_USED * 100 / RAM_TOTAL))
DISK_PCT=$(df / --output=pcent | tail -1 | tr -d ' %')
DISK_USED=$(df -h / --output=used | tail -1 | tr -d ' ')
DISK_TOTAL=$(df -h / --output=size | tail -1 | tr -d ' ')
CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
UPTIME=$(uptime -p | sed 's/up //')

# Service status
check_svc() {
    systemctl is-active --quiet "$1" 2>/dev/null && echo "1" || echo "0"
}

# Health check
HEALTH_STATUS="unknown"
HEALTH_TIME=""
if [ -f "$HEALTH" ]; then
    HEALTH_STATUS=$(python3 -c "import json; print(json.load(open('$HEALTH'))['status'])" 2>/dev/null || echo "unknown")
    HEALTH_TIME=$(python3 -c "import json; print(json.load(open('$HEALTH'))['timestamp'])" 2>/dev/null || echo "")
fi

# Active sessions
ACTIVE_SESSIONS=$(su - lever -c "openclaw health 2>/dev/null" | grep "Session store" | grep -o '[0-9]* entries' | grep -o '[0-9]*' 2>/dev/null || echo "0")

# Session costs today
TODAY=$(date -u +%Y-%m-%d)
SESSIONS_TODAY=$(grep -c "Session #" "$BRAIN/SESSION_COSTS.md" 2>/dev/null || echo "0")

# Knowledge stats
SOURCES_COUNT=$(find /home/lever/command/knowledge/sources/ -name "*.json" 2>/dev/null | wc -l)
ENTITIES_COUNT=$(find /home/lever/command/knowledge/entities/ -name "*.json" 2>/dev/null | wc -l)

# Recent sessions (last 8)
RECENT_SESSIONS=$(grep "^### " "$BRAIN/RECENT_SESSIONS.md" 2>/dev/null | tail -8 | sed 's/^### //' | while read -r line; do
    printf '"%s",' "$(echo "$line" | sed 's/"/\\"/g')"
done | sed 's/,$//')

# KANBAN items
kanban_section() {
    local section="$1"
    sed -n "/^## ${section}$/,/^## /{/^## ${section}$/d;/^## /d;/^---/d;/^\*/d;/^$/d;p;}" "$BRAIN/KANBAN.md" 2>/dev/null | head -5 | while read -r line; do
        printf '"%s",' "$(echo "$line" | sed 's/^- //;s/"/\\"/g')"
    done | sed 's/,$//'
}

KANBAN_PLANNED=$(kanban_section "PLANNED")
KANBAN_PROGRESS=$(kanban_section "IN PROGRESS")
KANBAN_REVIEW=$(kanban_section "IN REVIEW")
KANBAN_DONE=$(kanban_section "DONE (last 10)")
KANBAN_BLOCKED=$(kanban_section "BLOCKED")

# Pending approvals
PENDING_SECURE=$(grep -c "PENDING MASTER APPROVAL" "$BRAIN/INTENTIONS.md" 2>/dev/null || echo "0")
PENDING_ADVISOR=$(grep -c "PENDING" "$BRAIN/ADVISOR_BRIEFS.md" 2>/dev/null || echo "0")
PENDING_SECURE=$(echo "$PENDING_SECURE" | tr -d '[:space:]')
PENDING_ADVISOR=$(echo "$PENDING_ADVISOR" | tr -d '[:space:]')
[ -z "$PENDING_SECURE" ] && PENDING_SECURE=0
[ -z "$PENDING_ADVISOR" ] && PENDING_ADVISOR=0
TOTAL_PENDING=$((PENDING_SECURE + PENDING_ADVISOR))

# Get actual pending items text
PENDING_ITEMS=$(sed -n '/^## PENDING MASTER APPROVAL/,/^---/{/^## PENDING/d;/^---/d;/^\*/d;/^$/d;p;}' "$BRAIN/INTENTIONS.md" 2>/dev/null | head -5 | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|$//;s/|/\\n/g')

# Active intentions
INTENTIONS=$(sed -n '/^## ACTIVE/,/^---/{/^## ACTIVE/d;/^---/d;/^\*/d;/^$/d;p;}' "$BRAIN/INTENTIONS.md" 2>/dev/null | head -5 | while read -r line; do
    printf '"%s",' "$(echo "$line" | sed 's/"/\\"/g')"
done | sed 's/,$//')

# Latest advisor brief summary (first few lines after "## Latest Brief")
ADVISOR_SUMMARY=$(sed -n '/^## Latest Brief/,/^---/{/^## Latest/d;/^---/d;/^\*/d;p;}' "$BRAIN/ADVISOR_BRIEFS.md" 2>/dev/null | head -5 | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|$//;s/|/\\n/g')

# Upcoming cron jobs with actual next-run times
NEXT_JOBS=$(su - lever -c "openclaw cron list 2>/dev/null" | tail -n +2 | head -7 | while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $2}')
    next_time=$(echo "$line" | grep -oP 'in \K[0-9]+[hmd]' || echo "pending")
    [ -n "$name" ] && printf '{"name":"%s","next":"in %s"},' "$name" "$next_time"
done | sed 's/,$//')

# Recent handoffs (last 5) with clean summaries
RECENT_HANDOFFS=$(ls -t /home/lever/command/handoffs/*.md 2>/dev/null | head -5 | while read -r f; do
    name=$(basename "$f" .md)
    mtime=$(stat -c %Y "$f" 2>/dev/null || echo "0")
    # Get the first line that has actual content (skip headers and metadata)
    summary=$(grep -m1 "^[A-Z]" "$f" 2>/dev/null | sed 's/"/\\"/g' | cut -c1-80)
    [ -z "$summary" ] && summary=$(sed -n '3p' "$f" 2>/dev/null | sed 's/[#*]//g;s/"/\\"/g' | cut -c1-80)
    printf '{"name":"%s","time":%s,"summary":"%s"},' "$name" "$mtime" "$summary"
done | sed 's/,$//')

# Dead letter count
DEAD_LETTERS=$(find /home/lever/command/inbox/failed-messages/ -name "*.json" 2>/dev/null | wc -l)

# Gateway errors today
GW_ERRORS=$(grep -c "ERROR" /home/lever/command/inbox/telegram-gateway.log 2>/dev/null || echo "0")

# Project status
LEVER_BUGS_TOTAL=12
LEVER_BUGS_REMAINING=$(grep -c "CRITICAL\|HIGH\|MEDIUM" /home/lever/command/knowledge/reference/SESSION_HANDOFF_20260323.md 2>/dev/null || echo "0")

# Write JSON
cat > "$OUTPUT" << JSONEOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "system": {
    "health": "$HEALTH_STATUS",
    "healthTime": "$HEALTH_TIME",
    "ramUsed": $RAM_USED,
    "ramTotal": $RAM_TOTAL,
    "ramPct": $RAM_PCT,
    "diskPct": $DISK_PCT,
    "diskUsed": "$DISK_USED",
    "diskTotal": "$DISK_TOTAL",
    "cpuLoad": "$CPU_LOAD",
    "uptime": "$UPTIME"
  },
  "services": {
    "leverFrontend": $(check_svc lever-frontend),
    "leverOracle": $(check_svc lever-oracle),
    "leverAccrue": $(check_svc lever-accrue-keeper),
    "openclawGateway": $(check_svc openclaw-gateway),
    "vigilInbox": $(check_svc vigil-inbox),
    "vigilTelegram": $(check_svc vigil-telegram),
    "vigilDashboard": $(check_svc vigil-dashboard),
    "caddy": $(check_svc caddy)
  },
  "sessions": {
    "active": $ACTIVE_SESSIONS,
    "today": $SESSIONS_TODAY,
    "pendingApprovals": $TOTAL_PENDING,
    "pendingItems": "$PENDING_ITEMS",
    "deadLetters": $DEAD_LETTERS,
    "gatewayErrors": $GW_ERRORS
  },
  "knowledge": {
    "sources": $SOURCES_COUNT,
    "entities": $ENTITIES_COUNT
  },
  "kanban": {
    "planned": [$KANBAN_PLANNED],
    "inProgress": [$KANBAN_PROGRESS],
    "inReview": [$KANBAN_REVIEW],
    "done": [$KANBAN_DONE],
    "blocked": [$KANBAN_BLOCKED]
  },
  "intentions": [$INTENTIONS],
  "advisorSummary": "$ADVISOR_SUMMARY",
  "recentSessions": [$RECENT_SESSIONS],
  "recentHandoffs": [$RECENT_HANDOFFS],
  "nextJobs": [$NEXT_JOBS],
  "projects": {
    "lever": {
      "status": "testnet",
      "bugsTotal": $LEVER_BUGS_TOTAL,
      "bugsRemaining": $LEVER_BUGS_REMAINING
    }
  }
}
JSONEOF
