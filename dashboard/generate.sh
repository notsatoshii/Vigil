#!/bin/bash
# Vigil Dashboard Generator
# Regenerates static HTML every 60 seconds. Served on port 8080.
# No Claude Code session needed. Pure bash + system commands.

OUTPUT="/home/lever/command/dashboard/index.html"
BRAIN="/home/lever/command/shared-brain"
HEALTH="/home/lever/command/heartbeat/last-health-check.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Gather system metrics
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_PCT=$((RAM_USED * 100 / RAM_TOTAL))
DISK_PCT=$(df / --output=pcent | tail -1 | tr -d ' %')
DISK_USED=$(df -h / --output=used | tail -1 | tr -d ' ')
DISK_TOTAL=$(df -h / --output=size | tail -1 | tr -d ' ')
CPU_LOAD=$(cat /proc/loadavg | awk '{print $1}')
UPTIME=$(uptime -p | sed 's/up //')

# Service status
check_service() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

SVC_FRONTEND=$(check_service lever-frontend)
SVC_ORACLE=$(check_service lever-oracle)
SVC_ACCRUE=$(check_service lever-accrue-keeper)
SVC_GATEWAY=$(check_service openclaw-gateway)
SVC_INBOX=$(check_service vigil-inbox)
SVC_TELEGRAM=$(check_service vigil-telegram)
SVC_CADDY=$(check_service caddy)

# Active sessions from OpenClaw
ACTIVE_SESSIONS=$(su - lever -c "openclaw health 2>/dev/null" | grep "Session store" | grep -o '[0-9]* entries' | grep -o '[0-9]*' 2>/dev/null || echo "0")

# Latest health check
if [ -f "$HEALTH" ]; then
    HEALTH_STATUS=$(python3 -c "import json; print(json.load(open('$HEALTH'))['status'])" 2>/dev/null || echo "unknown")
    HEALTH_TIME=$(python3 -c "import json; print(json.load(open('$HEALTH'))['timestamp'])" 2>/dev/null || echo "unknown")
else
    HEALTH_STATUS="no check yet"
    HEALTH_TIME="never"
fi

# Pending approvals
PENDING_COUNT=$(grep -c "^[^#*].*PENDING" "$BRAIN/INTENTIONS.md" 2>/dev/null || echo "0")
ADVISOR_PENDING=$(grep -c "^[^#*].*PENDING" "$BRAIN/ADVISOR_BRIEFS.md" 2>/dev/null || echo "0")
PENDING_COUNT=$(echo "$PENDING_COUNT" | tr -d '[:space:]')
ADVISOR_PENDING=$(echo "$ADVISOR_PENDING" | tr -d '[:space:]')
[ -z "$PENDING_COUNT" ] && PENDING_COUNT=0
[ -z "$ADVISOR_PENDING" ] && ADVISOR_PENDING=0
TOTAL_PENDING=$((PENDING_COUNT + ADVISOR_PENDING))

# Latest advisor brief summary (first item)
ADVISOR_SUMMARY=$(sed -n '/^## Latest Brief/,/^---/{/^## Latest/d;/^---/d;p;}' "$BRAIN/ADVISOR_BRIEFS.md" 2>/dev/null | head -5 | sed 's/</\&lt;/g; s/>/\&gt;/g' || echo "No briefs yet")

# Active intentions
ACTIVE_INTENTIONS=$(sed -n '/^## ACTIVE/,/^---/{/^## ACTIVE/d;/^---/d;/^\*/d;p;}' "$BRAIN/INTENTIONS.md" 2>/dev/null | head -10 | sed 's/</\&lt;/g; s/>/\&gt;/g' || echo "None")

# Recent sessions (last 5)
RECENT=$(tail -30 "$BRAIN/RECENT_SESSIONS.md" 2>/dev/null | grep "^###" | tail -5 | sed 's/^### //; s/</\&lt;/g; s/>/\&gt;/g' || echo "No sessions yet")

# Knowledge graph stats
SOURCES_COUNT=$(find /home/lever/command/knowledge/sources/ -name "*.json" 2>/dev/null | wc -l)
ENTITIES_COUNT=$(find /home/lever/command/knowledge/entities/ -name "*.json" 2>/dev/null | wc -l)

# Cron schedule
CRON_JOBS=$(su - lever -c "openclaw cron list 2>/dev/null" | tail -n +2 | head -10 | sed 's/</\&lt;/g; s/>/\&gt;/g' || echo "No cron jobs")

# Color helper
status_color() {
    if [ "$1" = "running" ] || [ "$1" = "healthy" ]; then echo "#E6FF2B"
    elif [ "$1" = "stopped" ] || [ "$1" = "problems_detected" ]; then echo "#ff4444"
    else echo "#ffaa00"; fi
}

# Generate HTML
cat > "$OUTPUT" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="60">
<title>Vigil Command Center</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/fontsource/fonts/bitcount-single-ink:vf@latest/index.css">
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #0a0a0f; color: #c8c8d0; font-family: 'Bitcount Single Ink Variable', 'Bitcount Single Ink', 'JetBrains Mono', monospace; font-size: 14px; padding: 20px; }
.header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #222; padding-bottom: 12px; margin-bottom: 20px; }
.header-left { display: flex; align-items: center; gap: 12px; }
.header-logo img { height: 32px; display: block; filter: drop-shadow(0 0 6px rgba(255,100,0,.4)); }
.header h1 { color: #E6FF2B; font-size: 20px; font-weight: 600; letter-spacing: 3px; }
.header .time { color: #666; font-size: 11px; }
.grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; }
.card { background: #111118; border: 1px solid #1a1a24; border-radius: 4px; padding: 16px; }
.card h2 { color: #888; font-size: 11px; text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 12px; }
.metric { display: flex; justify-content: space-between; padding: 4px 0; border-bottom: 1px solid #1a1a24; }
.metric:last-child { border-bottom: none; }
.metric .label { color: #666; }
.metric .value { font-weight: 600; }
.green { color: #E6FF2B; }
.red { color: #ff4444; }
.yellow { color: #ffaa00; }
.dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 6px; }
.dot.green { background: #E6FF2B; }
.dot.red { background: #ff4444; }
pre { white-space: pre-wrap; word-wrap: break-word; color: #999; font-size: 11px; line-height: 1.6; }
.wide { grid-column: span 2; }
.full { grid-column: span 3; }
.badge { display: inline-block; background: #1a1a24; padding: 2px 8px; border-radius: 3px; font-size: 10px; margin: 2px; }
</style>
</head>
<body>
<div class="header">
<div class="header-left">
<div class="header-logo"><img src="vigil-logo.jpg" alt="Vigil"></div>
<h1>VIGIL</h1>
</div>
<div class="time">Updated: $TIMESTAMP | Uptime: $UPTIME</div>
</div>
<div class="grid">

<div class="card">
<h2>System Health</h2>
<div class="metric"><span class="label">Status</span><span class="value" style="color: $(status_color $HEALTH_STATUS)">$HEALTH_STATUS</span></div>
<div class="metric"><span class="label">RAM</span><span class="value">${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}%)</span></div>
<div class="metric"><span class="label">Disk</span><span class="value">${DISK_USED} / ${DISK_TOTAL} (${DISK_PCT}%)</span></div>
<div class="metric"><span class="label">CPU Load</span><span class="value">$CPU_LOAD</span></div>
<div class="metric"><span class="label">Last Check</span><span class="value" style="font-size:10px">$HEALTH_TIME</span></div>
</div>

<div class="card">
<h2>Services</h2>
<div class="metric"><span class="label"><span class="dot $([ "$SVC_FRONTEND" = "running" ] && echo green || echo red)"></span>lever-frontend</span><span class="value">:3000</span></div>
<div class="metric"><span class="label"><span class="dot $([ "$SVC_ORACLE" = "running" ] && echo green || echo red)"></span>lever-oracle</span><span class="value">keeper</span></div>
<div class="metric"><span class="label"><span class="dot $([ "$SVC_ACCRUE" = "running" ] && echo green || echo red)"></span>lever-accrue</span><span class="value">keeper</span></div>
<div class="metric"><span class="label"><span class="dot $([ "$SVC_GATEWAY" = "running" ] && echo green || echo red)"></span>openclaw-gw</span><span class="value">:18789</span></div>
<div class="metric"><span class="label"><span class="dot $([ "$SVC_INBOX" = "running" ] && echo green || echo red)"></span>vigil-inbox</span><span class="value">watcher</span></div>
<div class="metric"><span class="label"><span class="dot $([ "$SVC_TELEGRAM" = "running" ] && echo green || echo red)"></span>vigil-telegram</span><span class="value">bot</span></div>
<div class="metric"><span class="label"><span class="dot $([ "$SVC_CADDY" = "running" ] && echo green || echo red)"></span>caddy</span><span class="value">:80</span></div>
</div>

<div class="card">
<h2>Workstreams</h2>
<div class="metric"><span class="label">Active Sessions</span><span class="value green">$ACTIVE_SESSIONS</span></div>
<div class="metric"><span class="label">Pending Approvals</span><span class="value">$TOTAL_PENDING</span></div>
<div class="metric"><span class="label">Knowledge Sources</span><span class="value">$SOURCES_COUNT</span></div>
<div class="metric"><span class="label">Knowledge Entities</span><span class="value">$ENTITIES_COUNT</span></div>
</div>

<div class="card wide">
<h2>Active Intentions</h2>
<pre>$ACTIVE_INTENTIONS</pre>
</div>

<div class="card">
<h2>Latest Advisor Brief</h2>
<pre>$ADVISOR_SUMMARY</pre>
</div>

<div class="card full">
<h2>Recent Sessions</h2>
<pre>$RECENT</pre>
</div>

<div class="card full">
<h2>Heartbeat Schedule</h2>
<pre>$CRON_JOBS</pre>
</div>

</div>
</body>
</html>
HTMLEOF

echo "[$TIMESTAMP] Dashboard generated"
