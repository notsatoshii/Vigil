#!/bin/bash
# Vigil Work Dispatcher
# Runs every 5 minutes via cron. Checks capacity and dispatches work in PARALLEL.
# Does NOT use a Claude Code session. Pure bash. Fires openclaw agent calls in background.
#
# The goal: 5 session slots, all busy, all the time.

KANBAN="/home/lever/command/shared-brain/KANBAN.md"
INTENTIONS="/home/lever/command/shared-brain/INTENTIONS.md"
HANDOFFS="/home/lever/command/handoffs"
LOG="/home/lever/command/heartbeat/dispatcher.log"
MAX_SESSIONS=5
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

log() {
    echo "[$TIMESTAMP] $1" >> "$LOG"
}

# Count active Claude Code sessions (exclude long-running keepers and this script)
count_active() {
    pgrep -f "claude.*code\|openclaw agent" 2>/dev/null | wc -l
}

# Dispatch a task to a workstream (runs in background, non-blocking)
dispatch() {
    local agent="$1"
    local message="$2"
    log "DISPATCH: $agent - ${message:0:80}..."
    su - lever -c "openclaw agent --agent $agent --message '$message' --timeout 3600" >> "$LOG" 2>&1 &
}

# Check what is in each KANBAN stage
backlog_count() {
    grep -c "^- " <(sed -n '/^## BACKLOG/,/^---/p' "$KANBAN") 2>/dev/null; return 0
}

planned_count() {
    grep -c "^- " <(sed -n '/^## PLANNED/,/^---/p' "$KANBAN") 2>/dev/null; return 0
}

in_progress_count() {
    grep -c "^- " <(sed -n '/^## IN PROGRESS/,/^---/p' "$KANBAN") 2>/dev/null; return 0
}

in_review_count() {
    grep -c "^- " <(sed -n '/^## IN REVIEW/,/^---/p' "$KANBAN") 2>/dev/null; return 0
}

# Get the top backlog item
top_backlog() {
    sed -n '/^## BACKLOG/,/^---/p' "$KANBAN" | grep "^- " | head -1 | sed 's/^- //'
}

# Get the top planned item
top_planned() {
    sed -n '/^## PLANNED/,/^---/p' "$KANBAN" | grep "^- " | head -1 | sed 's/^- //'
}

# ============================================================
# MAIN DISPATCHER LOGIC
# ============================================================

ACTIVE=$(count_active)
AVAILABLE=$((MAX_SESSIONS - ACTIVE))

log "=== Dispatcher run: $ACTIVE active, $AVAILABLE slots available ==="

if [ "$AVAILABLE" -le 0 ]; then
    log "All slots full. Nothing to dispatch."
    exit 0
fi

DISPATCHED=0

# RULE 1: If there are items in BACKLOG and nothing being PLANNED, dispatch PLAN
BACKLOG=$(backlog_count)
PLANNED=$(planned_count)
PROGRESS=$(in_progress_count)
REVIEW=$(in_review_count)

log "KANBAN: backlog=$BACKLOG planned=$PLANNED progress=$PROGRESS review=$REVIEW"

# Priority 1: PLAN should always be working on the next thing
if [ "$BACKLOG" -gt 0 ] && [ "$DISPATCHED" -lt "$AVAILABLE" ]; then
    TASK=$(top_backlog)
    if [ -n "$TASK" ]; then
        dispatch "plan" "Plan the implementation for this task from the KANBAN BACKLOG: $TASK. Read the relevant codebase and write a structured plan to /home/lever/command/handoffs/plan-$(date +%Y%m%d-%H%M%S).md. Update KANBAN.md to move this task from BACKLOG to PLANNED."
        DISPATCHED=$((DISPATCHED + 1))
    fi
fi

# Priority 2: If there are PLANNED items, dispatch CRITIQUE
if [ "$PLANNED" -gt 0 ] && [ "$DISPATCHED" -lt "$AVAILABLE" ]; then
    # Find the most recent plan file
    PLAN_FILE=$(ls -t "$HANDOFFS"/plan-*.md 2>/dev/null | head -1)
    if [ -n "$PLAN_FILE" ]; then
        dispatch "critique" "Review this plan: $PLAN_FILE. Write your critique. If APPROVED, update KANBAN.md to reflect approval. If REVISE, send specific feedback."
        DISPATCHED=$((DISPATCHED + 1))
    fi
fi

# Priority 3: If CRITIQUE approved something, dispatch BUILD
# Check for approved plans in handoffs
APPROVED=$(ls -t "$HANDOFFS"/critique-*.md 2>/dev/null | head -1)
if [ -n "$APPROVED" ] && grep -q "APPROVED" "$APPROVED" 2>/dev/null && [ "$DISPATCHED" -lt "$AVAILABLE" ]; then
    PLAN_FILE=$(grep -l "plan" "$HANDOFFS"/plan-*.md 2>/dev/null | head -1)
    dispatch "build" "Implement the approved plan. Check /home/lever/command/handoffs/ for the latest approved plan. Follow it step by step. Write your handoff report. Update KANBAN.md."
    DISPATCHED=$((DISPATCHED + 1))
fi

# Priority 4: If BUILD finished, dispatch VERIFY
LATEST_BUILD=$(ls -t "$HANDOFFS"/build-*.md 2>/dev/null | head -1)
if [ -n "$LATEST_BUILD" ] && [ "$DISPATCHED" -lt "$AVAILABLE" ]; then
    # Only verify if not already verified
    LATEST_VERIFY=$(ls -t "$HANDOFFS"/verify-*.md 2>/dev/null | head -1)
    BUILD_TIME=$(stat -c %Y "$LATEST_BUILD" 2>/dev/null || echo 0)
    VERIFY_TIME=$(stat -c %Y "$LATEST_VERIFY" 2>/dev/null || echo 0)
    if [ "$BUILD_TIME" -gt "$VERIFY_TIME" ]; then
        dispatch "verify" "Review the latest BUILD handoff at $LATEST_BUILD. Run all 3 verification passes. Write your verdict. Update KANBAN.md."
        DISPATCHED=$((DISPATCHED + 1))
    fi
fi

# Priority 5: Fill remaining slots with proactive work
if [ "$DISPATCHED" -lt "$AVAILABLE" ]; then
    # IMPROVE: browse the product
    dispatch "improve" "Do a quick product review. Open the LEVER frontend at http://localhost:3000 in the browser. Check 2-3 pages. Note any issues. Write findings to IMPROVE_PROPOSALS.md. Keep it under 10 minutes."
    DISPATCHED=$((DISPATCHED + 1))
fi

if [ "$DISPATCHED" -lt "$AVAILABLE" ]; then
    # OPERATE: check and fix system issues
    dispatch "operate" "Run a system check. Read all Vigil logs (telegram-gateway.log, inbox.log, health-check.log). Check for errors. Check for dead services. Clean up anything that needs it. Fix issues you find. Commit fixes to git."
    DISPATCHED=$((DISPATCHED + 1))
fi

if [ "$DISPATCHED" -lt "$AVAILABLE" ]; then
    # RESEARCH: update intelligence
    dispatch "research" "Quick intelligence check. Pick one item from your watchlist coverage areas and do a focused scan. Update the knowledge graph with findings. Keep it under 10 minutes."
    DISPATCHED=$((DISPATCHED + 1))
fi

log "Dispatched $DISPATCHED tasks. Done."
