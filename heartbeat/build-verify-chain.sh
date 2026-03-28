#!/bin/bash
# LEVER Command - BUILD -> VERIFY Auto-Chain
# Called after BUILD completes. Sends the handoff to VERIFY.
# If VERIFY fails, sends feedback back to BUILD. Loops until pass or 3 failures.
#
# Usage: bash build-verify-chain.sh <handoff-file>

HANDOFF_FILE="$1"
MAX_FAILURES=3
FAILURE_COUNT=0
LOG="/home/lever/command/heartbeat/build-verify-chain.log"
GATEWAY_TOKEN=$(grep -o '"token": "[^"]*"' ~/.openclaw/openclaw.json | head -1 | cut -d'"' -f4)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ -z "$HANDOFF_FILE" ] || [ ! -f "$HANDOFF_FILE" ]; then
    echo "[$TIMESTAMP] ERROR: No handoff file provided or file not found: $HANDOFF_FILE" >> "$LOG"
    exit 1
fi

echo "[$TIMESTAMP] BUILD -> VERIFY chain started. Handoff: $HANDOFF_FILE" >> "$LOG"

while [ "$FAILURE_COUNT" -lt "$MAX_FAILURES" ]; do
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    ATTEMPT=$((FAILURE_COUNT + 1))
    echo "[$TIMESTAMP] Sending to VERIFY (attempt $ATTEMPT)..." >> "$LOG"

    # Read handoff content
    HANDOFF_CONTENT=$(cat "$HANDOFF_FILE")

    # Send to VERIFY agent
    VERIFY_RESULT=$(openclaw agent \
        --agent verify \
        --message "Review this BUILD handoff. Run all 3 verification passes (functional, visual, data). Write your verdict to /home/lever/command/handoffs/verify-verdict.md. Handoff contents: $HANDOFF_CONTENT" \
        \
        --timeout 1800 \
        --json 2>&1)

    echo "[$TIMESTAMP] VERIFY session completed." >> "$LOG"

    # Check if verdict file exists and parse result
    if [ -f "/home/lever/command/handoffs/verify-verdict.md" ]; then
        VERDICT=$(head -5 /home/lever/command/handoffs/verify-verdict.md | grep -i -o "PASS\|FAIL\|PASS WITH CONCERNS" | head -1)
    else
        VERDICT="FAIL"
        echo "No verdict file produced" > /home/lever/command/handoffs/verify-verdict.md
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [ "$VERDICT" = "PASS" ] || [ "$VERDICT" = "PASS WITH CONCERNS" ]; then
        echo "[$TIMESTAMP] VERIFY passed ($VERDICT). Notifying Master." >> "$LOG"

        # Notify Master via Telegram through OpenClaw
        openclaw agent \
            --agent main \
            --message "BUILD -> VERIFY chain complete. Verdict: $VERDICT. Notify Master on Telegram with a summary of what was built and the verification result." \
            \
            --timeout 120 2>&1 >> "$LOG"

        # Update RECENT_SESSIONS.md
        echo "" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md
        echo "### [$TIMESTAMP] VERIFY | Auto-chain verdict: $VERDICT" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md
        echo "- **Task**: Automated verification of BUILD output" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md
        echo "- **Outcome**: $VERDICT (attempt $ATTEMPT)" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md

        exit 0
    fi

    # FAIL: send feedback back to BUILD
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    echo "[$TIMESTAMP] VERIFY failed (attempt $FAILURE_COUNT/$MAX_FAILURES). Sending feedback to BUILD." >> "$LOG"

    if [ "$FAILURE_COUNT" -lt "$MAX_FAILURES" ]; then
        FEEDBACK=$(cat /home/lever/command/handoffs/verify-verdict.md)

        # Send feedback to BUILD for a fix attempt
        BUILD_RESULT=$(openclaw agent \
            --agent build \
            --message "VERIFY failed your work. Fix these issues and write an updated handoff to /home/lever/command/handoffs/build-handoff.md. VERIFY feedback: $FEEDBACK" \
            \
            --timeout 1800 \
            --json 2>&1)

        echo "[$TIMESTAMP] BUILD fix attempt completed." >> "$LOG"
        HANDOFF_FILE="/home/lever/command/handoffs/build-handoff.md"

        # Clean up old verdict for next round
        rm -f /home/lever/command/handoffs/verify-verdict.md
    fi
done

# Exhausted retries: escalate to Master
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "[$TIMESTAMP] STUCK: VERIFY failed $MAX_FAILURES times. Escalating to Master." >> "$LOG"

LAST_FEEDBACK=$(cat /home/lever/command/handoffs/verify-verdict.md 2>/dev/null || echo "No verdict available")

openclaw agent \
    --agent main \
    --message "BUILD -> VERIFY loop is stuck. Failed $MAX_FAILURES times on the same issue. Tell Master on Telegram what the problem is and ask for guidance. Last VERIFY feedback: $LAST_FEEDBACK" \
    \
    --timeout 120 2>&1 >> "$LOG"

exit 1
