#!/bin/bash
# Vigil - PLAN -> CRITIQUE -> BUILD -> VERIFY Full Pipeline Chain
# Orchestrates the complete task lifecycle.
#
# Usage: bash plan-build-chain.sh <task-name> <task-description>
# Can also be called with just a plan file: bash plan-build-chain.sh --plan <plan-file>

TASK_NAME="$1"
TASK_DESC="$2"
LOG="/home/lever/command/heartbeat/plan-build-chain.log"
HANDOFFS="/home/lever/command/handoffs"
KANBAN="/home/lever/command/shared-brain/KANBAN.md"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
MAX_PLAN_REVISIONS=3
MAX_BUILD_FAILURES=3

log() {
    echo "[$TIMESTAMP] $1" >> "$LOG"
    echo "$1"
}

update_kanban() {
    local task="$1"
    local status="$2"
    # Simple append to the appropriate section
    # OPERATE or ADVISOR will clean this up during maintenance
    sed -i "/^## ${status}$/a - [$(date -u +%Y-%m-%dT%H:%M:%SZ)] ${task}" "$KANBAN"
}

# Handle --plan flag (skip PLAN phase, start from existing plan)
if [ "$1" = "--plan" ]; then
    PLAN_FILE="$2"
    TASK_NAME=$(basename "$PLAN_FILE" .md | sed 's/^plan-//')
    if [ ! -f "$PLAN_FILE" ]; then
        log "ERROR: Plan file not found: $PLAN_FILE"
        exit 1
    fi
    log "Starting from existing plan: $PLAN_FILE"
    # Skip to CRITIQUE phase
    PLAN_REVISION=0
    goto_critique=true
else
    goto_critique=false
    if [ -z "$TASK_NAME" ] || [ -z "$TASK_DESC" ]; then
        echo "Usage: plan-build-chain.sh <task-name> <task-description>"
        echo "   or: plan-build-chain.sh --plan <plan-file>"
        exit 1
    fi
fi

log "=== Pipeline started: $TASK_NAME ==="
update_kanban "$TASK_NAME" "IN PROGRESS"

# ============================================================
# PHASE 1: PLAN
# ============================================================
PLAN_REVISION=0
PLAN_FILE="$HANDOFFS/plan-${TASK_NAME}.md"

if [ "$goto_critique" != "true" ]; then
    log "PHASE 1: PLAN"

    PLAN_RESULT=$(openclaw agent \
        --agent plan \
        --message "Create an implementation plan for: $TASK_DESC. Write the plan to $PLAN_FILE following the plan output format in your CLAUDE.md." \
        --timeout 1800 2>&1)

    if [ ! -f "$PLAN_FILE" ]; then
        log "ERROR: PLAN did not produce a plan file at $PLAN_FILE"
        update_kanban "$TASK_NAME (PLAN FAILED)" "BLOCKED"
        exit 1
    fi

    log "PLAN produced: $PLAN_FILE"
fi

# ============================================================
# PHASE 2: CRITIQUE (with revision loop)
# ============================================================
while [ "$PLAN_REVISION" -lt "$MAX_PLAN_REVISIONS" ]; do
    PLAN_REVISION=$((PLAN_REVISION + 1))
    CRITIQUE_FILE="$HANDOFFS/critique-${TASK_NAME}-v${PLAN_REVISION}.md"

    log "PHASE 2: CRITIQUE (revision $PLAN_REVISION)"

    CRITIQUE_RESULT=$(openclaw agent \
        --agent critique \
        --message "Review this plan: $PLAN_FILE. Write your critique to $CRITIQUE_FILE following the critique output format in your CLAUDE.md. Read the plan file and the actual codebase." \
        --timeout 1800 2>&1)

    # Check verdict
    if [ -f "$CRITIQUE_FILE" ]; then
        VERDICT=$(grep -i "APPROVED\|REVISE\|REJECT" "$CRITIQUE_FILE" | head -1 | grep -o "APPROVED\|REVISE\|REJECT")
    else
        VERDICT="REVISE"
        log "WARNING: CRITIQUE did not produce a file. Assuming REVISE."
    fi

    log "CRITIQUE verdict: $VERDICT"

    if [ "$VERDICT" = "APPROVED" ]; then
        break
    elif [ "$VERDICT" = "REJECT" ]; then
        log "CRITIQUE rejected the plan. Sending back to PLAN for rethinking."
        FEEDBACK=$(cat "$CRITIQUE_FILE" 2>/dev/null)
        PLAN_RESULT=$(openclaw agent \
            --agent plan \
            --message "CRITIQUE rejected your plan. Rethink the approach. Feedback: $FEEDBACK. Write revised plan to $PLAN_FILE." \
            --timeout 1800 2>&1)
    else
        # REVISE
        log "CRITIQUE wants revisions. Sending back to PLAN."
        FEEDBACK=$(cat "$CRITIQUE_FILE" 2>/dev/null)
        PLAN_RESULT=$(openclaw agent \
            --agent plan \
            --message "CRITIQUE wants revisions to your plan. Address these issues and write revised plan to $PLAN_FILE. Feedback: $FEEDBACK" \
            --timeout 1800 2>&1)
    fi
done

if [ "$VERDICT" != "APPROVED" ]; then
    log "ERROR: Plan not approved after $MAX_PLAN_REVISIONS revisions. Escalating to Master."
    update_kanban "$TASK_NAME (PLAN STUCK)" "BLOCKED"
    # Notify via Telegram gateway
    openclaw agent --agent main --message "The plan for '$TASK_NAME' could not pass CRITIQUE after $MAX_PLAN_REVISIONS revisions. Master needs to weigh in." --timeout 120 2>&1
    exit 1
fi

# ============================================================
# PHASE 3: BUILD (with failure loop)
# ============================================================
BUILD_FAILURE=0

while [ "$BUILD_FAILURE" -lt "$MAX_BUILD_FAILURES" ]; do
    BUILD_ATTEMPT=$((BUILD_FAILURE + 1))
    BUILD_HANDOFF="$HANDOFFS/build-$(date +%Y%m%d-%H%M%S)-${TASK_NAME}.md"

    log "PHASE 3: BUILD (attempt $BUILD_ATTEMPT)"

    BUILD_RESULT=$(openclaw agent \
        --agent build \
        --message "Implement the approved plan at $PLAN_FILE. Follow it step by step. Write your handoff report to $BUILD_HANDOFF." \
        --timeout 3600 2>&1)

    if [ ! -f "$BUILD_HANDOFF" ]; then
        log "WARNING: BUILD did not produce a handoff file. Creating stub."
        echo "# BUILD Handoff (auto-generated stub)" > "$BUILD_HANDOFF"
        echo "BUILD completed but did not write a handoff." >> "$BUILD_HANDOFF"
    fi

    log "BUILD produced: $BUILD_HANDOFF"
    update_kanban "$TASK_NAME" "IN REVIEW"

    # ============================================================
    # PHASE 4: VERIFY
    # ============================================================
    VERIFY_VERDICT_FILE="$HANDOFFS/verify-$(date +%Y%m%d-%H%M%S)-${TASK_NAME}.md"

    log "PHASE 4: VERIFY"

    VERIFY_RESULT=$(openclaw agent \
        --agent verify \
        --message "Review this BUILD handoff: $BUILD_HANDOFF. Run all 3 verification passes (functional, visual, data). Write your verdict to $VERIFY_VERDICT_FILE." \
        --timeout 1800 2>&1)

    # Check verdict
    if [ -f "$VERIFY_VERDICT_FILE" ]; then
        VERIFY_VERDICT=$(grep -i "PASS\|FAIL" "$VERIFY_VERDICT_FILE" | head -1 | grep -o "PASS\|FAIL" | head -1)
    else
        VERIFY_VERDICT="FAIL"
        log "WARNING: VERIFY did not produce a verdict file."
    fi

    log "VERIFY verdict: $VERIFY_VERDICT"

    if [ "$VERIFY_VERDICT" = "PASS" ]; then
        log "=== Pipeline complete: $TASK_NAME PASSED ==="
        update_kanban "$TASK_NAME (VERIFIED)" "DONE (last 10)"

        # Notify Master
        openclaw agent --agent main --message "Pipeline complete for '$TASK_NAME'. PLAN approved, BUILD implemented, VERIFY passed. The work is done." --timeout 120 2>&1
        exit 0
    fi

    # FAIL: check if it is a design flaw or code bug
    VERIFY_FEEDBACK=$(cat "$VERIFY_VERDICT_FILE" 2>/dev/null)
    IS_DESIGN_FLAW=$(echo "$VERIFY_FEEDBACK" | grep -i "design flaw\|wrong approach\|architecture\|restructure\|re-plan" | head -1)

    if [ -n "$IS_DESIGN_FLAW" ]; then
        log "VERIFY identified a design flaw. Sending back to PLAN."
        PLAN_RESULT=$(openclaw agent \
            --agent plan \
            --message "VERIFY found a design flaw in the implementation of '$TASK_NAME'. Re-plan. Feedback: $VERIFY_FEEDBACK" \
            --timeout 1800 2>&1)
        # Reset and go through CRITIQUE again
        PLAN_REVISION=0
        BUILD_FAILURE=0
        continue
    fi

    # Code bug: send back to BUILD
    BUILD_FAILURE=$((BUILD_FAILURE + 1))
    log "VERIFY found code bugs (attempt $BUILD_FAILURE/$MAX_BUILD_FAILURES). Sending back to BUILD."

    if [ "$BUILD_FAILURE" -lt "$MAX_BUILD_FAILURES" ]; then
        BUILD_RESULT=$(openclaw agent \
            --agent build \
            --message "VERIFY failed your work on '$TASK_NAME'. Fix these issues: $VERIFY_FEEDBACK. Write updated handoff to $BUILD_HANDOFF." \
            --timeout 3600 2>&1)
    fi
done

# Exhausted retries
log "ERROR: BUILD failed $MAX_BUILD_FAILURES times. Escalating to Master."
update_kanban "$TASK_NAME (STUCK)" "BLOCKED"
openclaw agent --agent main --message "Pipeline stuck on '$TASK_NAME'. BUILD failed VERIFY $MAX_BUILD_FAILURES times. Master needs to intervene." --timeout 120 2>&1
exit 1
