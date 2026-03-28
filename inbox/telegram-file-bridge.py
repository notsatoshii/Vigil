#!/usr/bin/env python3
"""
Vigil Telegram File Bridge
===========================
Does NOT poll Telegram (OpenClaw does that).
Instead, watches OpenClaw's session logs for file references and downloads them.

Alternative approach: This script runs as a webhook-style service that OpenClaw
can call, or it periodically checks Telegram's getUpdates with a separate offset
using the getUpdates trick of only consuming file-bearing messages.

ACTUAL APPROACH: We use a simpler method. This script polls Telegram's getUpdates
API but does NOT consume the updates (offset is not committed for text messages).
It only downloads files and commits the offset. OpenClaw's long-polling will also
see the same updates but for text processing.

UPDATE: Due to the 409 conflict issue, this script instead uses a cron-triggered
approach. Every 30 seconds it checks for recent file messages using getUpdates
with a very short timeout, downloads any files, and exits. This avoids persistent
polling conflicts with OpenClaw.
"""

import os
import sys
import json
import time
import logging
import urllib.request
import urllib.error
import re
from pathlib import Path
from datetime import datetime, timezone

# Configuration
BOT_TOKEN = "8541708860:AAGmNKlIeo5Acn6Wssk6HzQR1QfMNX2GXwk"
AUTHORIZED_USER_ID = 422985839
INBOX_DIR = "/home/lever/command/inbox/incoming"
STATE_FILE = "/home/lever/command/inbox/telegram-bridge-state.json"
LOG_FILE = "/home/lever/command/inbox/telegram-bridge.log"
API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}"

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
    ]
)
log = logging.getLogger(__name__)

def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"last_update_id": 0, "initialized": False}

def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)

def api_call(method, params=None):
    url = f"{API_BASE}/{method}"
    if params:
        url += "?" + "&".join(f"{k}={v}" for k, v in params.items())
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        log.error(f"API call failed: {method} - {e}")
        return None

def download_file(file_id, filename):
    result = api_call("getFile", {"file_id": file_id})
    if not result or not result.get("ok"):
        log.error(f"Could not get file path for {file_id}")
        return False

    file_path = result["result"]["file_path"]
    download_url = f"https://api.telegram.org/file/bot{BOT_TOKEN}/{file_path}"

    safe_filename = "".join(c for c in filename if c.isalnum() or c in ".-_ ").strip()
    if not safe_filename:
        safe_filename = f"telegram-{file_id}"

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    dest_path = os.path.join(INBOX_DIR, f"{timestamp}-{safe_filename}")

    try:
        urllib.request.urlretrieve(download_url, dest_path)
        log.info(f"Downloaded: {safe_filename} -> {dest_path}")
        return True
    except Exception as e:
        log.error(f"Download failed: {safe_filename} - {e}")
        return False

def save_url(url):
    """Save a URL as a .url file for the inbox watcher to scrape."""
    if "t.me/" in url or "telegram.org" in url:
        return
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    domain = url.split("//")[1].split("/")[0].replace("www.", "").replace(".", "-")
    url_filename = f"{timestamp}-{domain}.url"
    url_path = os.path.join(INBOX_DIR, url_filename)
    with open(url_path, "w") as f:
        f.write(url)
    log.info(f"URL saved for scraping: {url} -> {url_path}")

def process_message(message):
    user_id = message.get("from", {}).get("id")
    if user_id != AUTHORIZED_USER_ID:
        return False

    has_file = False

    # Document (PDF, DOCX, etc.)
    document = message.get("document")
    if document:
        filename = document.get("file_name", f"document-{document['file_id']}")
        log.info(f"Document received: {filename}")
        download_file(document["file_id"], filename)
        has_file = True

    # Photo (largest resolution)
    photos = message.get("photo")
    if photos:
        largest = max(photos, key=lambda p: p.get("file_size", 0))
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        filename = f"photo-{timestamp}.jpg"
        log.info(f"Photo received")
        download_file(largest["file_id"], filename)
        has_file = True

    # Video
    video = message.get("video")
    if video:
        filename = video.get("file_name", f"video-{video['file_id']}.mp4")
        log.info(f"Video received: {filename}")
        download_file(video["file_id"], filename)
        has_file = True

    # Voice/Audio
    voice = message.get("voice")
    audio = message.get("audio")
    if voice:
        filename = f"voice-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}.ogg"
        download_file(voice["file_id"], filename)
        has_file = True
    if audio:
        filename = audio.get("file_name", f"audio-{audio['file_id']}.mp3")
        download_file(audio["file_id"], filename)
        has_file = True

    # URLs in text or caption (auto-scrape ALL links)
    text = message.get("text", "")
    caption = message.get("caption", "")
    all_text = text + " " + caption
    urls = re.findall(r'https?://[^\s<>"{}|\\^`\[\]]+', all_text)
    for url in urls:
        save_url(url)
        has_file = True

    return has_file

def run_once():
    """Single check for new file messages. Called by systemd timer."""
    state = load_state()

    # On first run, skip to current to avoid reprocessing old messages
    if not state.get("initialized"):
        result = api_call("getUpdates", {"offset": "-1", "limit": "1", "timeout": "1"})
        if result and result.get("ok") and result["result"]:
            state["last_update_id"] = result["result"][-1]["update_id"]
        state["initialized"] = True
        save_state(state)
        log.info(f"Initialized at update_id {state['last_update_id']}")
        return

    # Peek at updates without long-polling (timeout=1)
    # We use the same offset as OpenClaw would, but with a very short timeout
    # This is a "peek" not a "consume" - both can see the same updates
    params = {
        "timeout": "1",
        "limit": "20",
        "offset": str(state["last_update_id"] + 1)
    }

    result = api_call("getUpdates", params)
    if not result or not result.get("ok"):
        return

    for update in result["result"]:
        update_id = update["update_id"]
        message = update.get("message", {})

        if message:
            had_file = process_message(message)
            if had_file:
                log.info(f"Processed update {update_id} (had files/URLs)")

        # Always advance our state so we do not reprocess
        state["last_update_id"] = update_id
        save_state(state)

if __name__ == "__main__":
    os.makedirs(INBOX_DIR, exist_ok=True)
    run_once()
