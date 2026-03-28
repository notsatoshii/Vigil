#!/bin/bash
# Download a file from Telegram Bot API and save to inbox
# Usage: download-telegram-file.sh <file_id> [filename]
#
# Called by Commander when it receives a file attachment via Telegram.

BOT_TOKEN="8541708860:AAGmNKlIeo5Acn6Wssk6HzQR1QfMNX2GXwk"
FILE_ID="$1"
FILENAME="${2:-telegram-file}"
INBOX="/home/lever/command/inbox/incoming"
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)

if [ -z "$FILE_ID" ]; then
    echo "Usage: download-telegram-file.sh <file_id> [filename]"
    exit 1
fi

# Get file path from Telegram API
FILE_INFO=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${FILE_ID}")
FILE_PATH=$(echo "$FILE_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['file_path'])" 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
    echo "ERROR: Could not get file path for file_id: $FILE_ID"
    exit 1
fi

# Download
SAFE_FILENAME=$(echo "$FILENAME" | tr -dc 'a-zA-Z0-9._- ')
DEST="${INBOX}/${TIMESTAMP}-${SAFE_FILENAME}"

curl -s "https://api.telegram.org/file/bot${BOT_TOKEN}/${FILE_PATH}" -o "$DEST"

if [ $? -eq 0 ] && [ -f "$DEST" ]; then
    echo "Downloaded: $DEST"
    exit 0
else
    echo "ERROR: Download failed"
    exit 1
fi
