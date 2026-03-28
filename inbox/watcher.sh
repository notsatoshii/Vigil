#!/bin/bash
# Vigil Inbox Watcher
# Monitors /home/lever/command/inbox/incoming/ for new files.
# When a file arrives, moves it to processing/, spawns a RESEARCH session
# to extract knowledge, then moves to processed/ or failed/.
#
# Runs as a systemd service. Restarts automatically.

INCOMING="/home/lever/command/inbox/incoming"
PROCESSING="/home/lever/command/inbox/processing"
PROCESSED="/home/lever/command/inbox/processed"
FAILED="/home/lever/command/inbox/failed"
LOG="/home/lever/command/inbox/inbox.log"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"
}

process_file() {
    local FILE="$1"
    local BASENAME=$(basename "$FILE")
    local EXT="${BASENAME##*.}"
    local TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)

    log "Processing: $BASENAME (type: $EXT)"

    # Move to processing
    mv "$FILE" "$PROCESSING/$BASENAME" 2>/dev/null
    if [ $? -ne 0 ]; then
        log "ERROR: Could not move $BASENAME to processing"
        return 1
    fi

    # Determine file type and build the extraction message
    case "$EXT" in
        pdf)
            MSG="A PDF file has been uploaded for knowledge ingestion: $PROCESSING/$BASENAME. Read it, summarize the content (3-5 key points), extract entities (people, companies, protocols, concepts, numbers), identify relationships, tag with categories (technical, strategic, financial, legal, design, market), and save a knowledge entry to /home/lever/command/knowledge/sources/${TIMESTAMP}-${BASENAME%.pdf}.json. Update relevant summaries in /home/lever/command/knowledge/summaries/."
            ;;
        png|jpg|jpeg|gif|webp)
            MSG="An image file has been uploaded for knowledge ingestion: $PROCESSING/$BASENAME. View it, describe the content, extract any visible text, identify what it shows (screenshot, diagram, chart, design reference), and save a knowledge entry to /home/lever/command/knowledge/sources/${TIMESTAMP}-${BASENAME%.*}.json. Update relevant summaries if the content is significant."
            ;;
        md|txt|text)
            MSG="A text file has been uploaded for knowledge ingestion: $PROCESSING/$BASENAME. Read it, summarize the content (3-5 key points), extract entities, identify relationships, tag with categories, and save a knowledge entry to /home/lever/command/knowledge/sources/${TIMESTAMP}-${BASENAME%.*}.json. Update relevant summaries."
            ;;
        json)
            MSG="A JSON file has been uploaded for knowledge ingestion: $PROCESSING/$BASENAME. Read it, understand the data structure and content, summarize key information, extract entities, and save a knowledge entry to /home/lever/command/knowledge/sources/${TIMESTAMP}-${BASENAME%.*}.json."
            ;;
        url)
            # .url files contain a URL to fetch
            URL=$(cat "$PROCESSING/$BASENAME" 2>/dev/null | head -1 | tr -d '[:space:]')
            MSG="A URL has been submitted for knowledge ingestion: $URL. Use Scrapling or web fetch to retrieve the content. Summarize it (3-5 key points), extract entities, identify relationships, tag with categories, and save a knowledge entry to /home/lever/command/knowledge/sources/${TIMESTAMP}-${BASENAME%.*}.json. Update relevant summaries."
            ;;
        docx|doc)
            MSG="A document file has been uploaded for knowledge ingestion: $PROCESSING/$BASENAME. Extract the text content, summarize (3-5 key points), extract entities, identify relationships, tag with categories, and save a knowledge entry to /home/lever/command/knowledge/sources/${TIMESTAMP}-${BASENAME%.*}.json."
            ;;
        *)
            MSG="A file has been uploaded for knowledge ingestion: $PROCESSING/$BASENAME (type: $EXT). Read or examine it, summarize the content, extract entities if applicable, and save a knowledge entry to /home/lever/command/knowledge/sources/${TIMESTAMP}-${BASENAME%.*}.json."
            ;;
    esac

    # Spawn RESEARCH session to process
    log "Spawning RESEARCH session for $BASENAME..."
    RESULT=$(openclaw agent --agent research --message "$MSG" --timeout 600 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        # Move to processed
        mv "$PROCESSING/$BASENAME" "$PROCESSED/${TIMESTAMP}-${BASENAME}"
        log "SUCCESS: $BASENAME processed and moved to processed/"

        # Update RECENT_SESSIONS.md
        echo "" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md
        echo "### [$(date -u +%Y-%m-%dT%H:%M:%SZ)] RESEARCH | Inbox ingestion: $BASENAME" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md
        echo "- **Task**: Knowledge ingestion from inbox" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md
        echo "- **Outcome**: SUCCESS" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md
        echo "- **Source**: $BASENAME ($EXT)" >> /home/lever/command/shared-brain/RECENT_SESSIONS.md
    else
        # Move to failed
        mv "$PROCESSING/$BASENAME" "$FAILED/${TIMESTAMP}-${BASENAME}"
        log "FAILED: $BASENAME processing failed (exit $EXIT_CODE). Moved to failed/"
        log "Error output: $(echo "$RESULT" | tail -5)"
    fi
}

# Main loop
log "Inbox watcher started. Monitoring: $INCOMING"

# Process any files that are already in incoming/ (from before the watcher started)
for existing in "$INCOMING"/*; do
    [ -f "$existing" ] && process_file "$existing"
done

# Watch for new files
inotifywait -m -e close_write -e moved_to "$INCOMING" --format '%f' 2>/dev/null | while read -r FILENAME; do
    # Skip hidden files and temp files
    [[ "$FILENAME" == .* ]] && continue
    [[ "$FILENAME" == *".tmp" ]] && continue
    [[ "$FILENAME" == *".part" ]] && continue

    # Small delay to ensure file is fully written (especially for SCP)
    sleep 2

    if [ -f "$INCOMING/$FILENAME" ]; then
        process_file "$INCOMING/$FILENAME"
    fi
done
