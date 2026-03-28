#!/usr/bin/env python3
"""
Vigil Telegram Gateway
======================
The single point of contact between Telegram and Vigil.

This service:
1. Polls Telegram Bot API for ALL messages (text, files, photos, URLs)
2. Downloads any files/media to the inbox for knowledge ingestion
3. Forwards text messages to OpenClaw gateway for routing to workstreams
4. Sends OpenClaw's responses back to Telegram

OpenClaw's native Telegram channel is DISABLED. This service handles everything.
"""

import os
import sys
import json
import time
import logging
import urllib.request
import urllib.error
import subprocess
import re
import signal
from pathlib import Path
from datetime import datetime, timezone

# Configuration
BOT_TOKEN = "8541708860:AAGmNKlIeo5Acn6Wssk6HzQR1QfMNX2GXwk"
AUTHORIZED_USER_ID = 422985839
INBOX_DIR = "/home/lever/command/inbox/incoming"
STATE_FILE = "/home/lever/command/inbox/telegram-gateway-state.json"
LOG_FILE = "/home/lever/command/inbox/telegram-gateway.log"
API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}"
OPENCLAW_BIN = "openclaw"
MAX_TG_LENGTH = 4000

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

# Graceful shutdown
running = True
def handle_signal(signum, frame):
    global running
    log.info(f"Received signal {signum}, shutting down...")
    running = False

signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)


def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"last_update_id": 0}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


def tg_api(method, params=None, data=None):
    """Call the Telegram Bot API."""
    url = f"{API_BASE}/{method}"
    if params:
        url += "?" + "&".join(f"{k}={v}" for k, v in params.items())
    try:
        if data:
            req = urllib.request.Request(
                url,
                data=json.dumps(data).encode(),
                headers={"Content-Type": "application/json"}
            )
        else:
            req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=35) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.URLError as e:
        log.error(f"TG API error: {method} - {e}")
        return None
    except Exception as e:
        log.error(f"TG API unexpected error: {method} - {e}")
        return None


def send_telegram(chat_id, text):
    """Send a message to Telegram, splitting if too long."""
    chunks = []
    while len(text) > MAX_TG_LENGTH:
        split_at = text.rfind("\n", 0, MAX_TG_LENGTH)
        if split_at == -1:
            split_at = MAX_TG_LENGTH
        chunks.append(text[:split_at])
        text = text[split_at:].lstrip()
    chunks.append(text)

    for chunk in chunks:
        if chunk.strip():
            tg_api("sendMessage", data={
                "chat_id": chat_id,
                "text": chunk,
                "parse_mode": "Markdown"
            })


def send_typing(chat_id):
    """Show typing indicator."""
    tg_api("sendChatAction", data={
        "chat_id": chat_id,
        "action": "typing"
    })


def download_tg_file(file_id, filename):
    """Download a file from Telegram and save to inbox."""
    result = tg_api("getFile", {"file_id": file_id})
    if not result or not result.get("ok"):
        log.error(f"Could not get file path for {file_id}")
        return None

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
        return dest_path
    except Exception as e:
        log.error(f"Download failed: {safe_filename} - {e}")
        return None


def forward_to_openclaw(message_text, chat_id):
    """Forward a message to OpenClaw for routing and get the response.
    Keeps sending typing indicators every 4 seconds while waiting."""
    import threading

    # Typing indicator thread
    typing_active = threading.Event()
    typing_active.set()

    def keep_typing():
        while typing_active.is_set():
            send_typing(chat_id)
            # Telegram typing indicator lasts 5 seconds, refresh every 4
            for _ in range(8):  # 4 seconds in 0.5s increments
                if not typing_active.is_set():
                    return
                time.sleep(0.5)

    typing_thread = threading.Thread(target=keep_typing, daemon=True)
    typing_thread.start()

    try:
        result = subprocess.run(
            [OPENCLAW_BIN, "agent", "--agent", "main",
             "--message", message_text,
             "--timeout", "3600"],
            capture_output=True, text=True, timeout=3660,
            env={**os.environ, "HOME": "/home/lever"}
        )
        response = result.stdout.strip()
        if response:
            return response
        if result.stderr:
            log.error(f"OpenClaw stderr: {result.stderr[-500:]}")
        return None
    except subprocess.TimeoutExpired:
        log.error("OpenClaw agent timed out (60 min)")
        return "Task is taking longer than expected. I am still working on it."
    except Exception as e:
        log.error(f"OpenClaw error: {e}")
        return None
    finally:
        typing_active.clear()
        typing_thread.join(timeout=5)


def process_message(message):
    """Process a single Telegram message."""
    user_id = message.get("from", {}).get("id")
    chat_id = message.get("chat", {}).get("id")

    if user_id != AUTHORIZED_USER_ID:
        log.info(f"Ignoring message from unauthorized user {user_id}")
        return

    text = message.get("text", "")
    caption = message.get("caption", "")
    downloaded_files = []

    # Handle document (PDF, DOCX, etc.)
    document = message.get("document")
    if document:
        filename = document.get("file_name", f"document-{document['file_id']}")
        log.info(f"Document received: {filename}")
        path = download_tg_file(document["file_id"], filename)
        if path:
            downloaded_files.append(filename)

    # Handle photo
    photos = message.get("photo")
    if photos:
        largest = max(photos, key=lambda p: p.get("file_size", 0))
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        filename = f"photo-{ts}.jpg"
        path = download_tg_file(largest["file_id"], filename)
        if path:
            downloaded_files.append(filename)

    # Handle video
    video = message.get("video")
    if video:
        filename = video.get("file_name", f"video-{video['file_id']}.mp4")
        path = download_tg_file(video["file_id"], filename)
        if path:
            downloaded_files.append(filename)

    # Handle voice/audio
    for media_type in ["voice", "audio"]:
        media = message.get(media_type)
        if media:
            ext = "ogg" if media_type == "voice" else "mp3"
            filename = media.get("file_name",
                f"{media_type}-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}.{ext}")
            path = download_tg_file(media["file_id"], filename)
            if path:
                downloaded_files.append(filename)

    # Handle URLs in text/caption (auto-scrape all links)
    all_text = f"{text} {caption}".strip()
    urls = re.findall(r'https?://[^\s<>"{}|\\^`\[\]]+', all_text)
    saved_urls = []
    for url in urls:
        if "t.me/" in url or "telegram.org" in url:
            continue
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        domain = url.split("//")[1].split("/")[0].replace("www.", "").replace(".", "-")
        url_filename = f"{ts}-{domain}.url"
        url_path = os.path.join(INBOX_DIR, url_filename)
        with open(url_path, "w") as f:
            f.write(url)
        saved_urls.append(url)
        log.info(f"URL saved: {url}")

    # Build the message to forward to OpenClaw
    forward_text = all_text

    if downloaded_files:
        file_list = ", ".join(downloaded_files)
        if forward_text:
            forward_text += f"\n\n[Files received and saved to knowledge inbox: {file_list}]"
        else:
            forward_text = f"I just sent you these files (already saved to knowledge inbox for processing): {file_list}"

    if saved_urls:
        url_list = ", ".join(saved_urls)
        if not forward_text or forward_text == f"[Files received and saved to knowledge inbox: {', '.join(downloaded_files)}]":
            forward_text = f"I just sent you these links (already saved for scraping): {url_list}"

    # If there is nothing to forward (empty message, sticker, etc.), skip
    if not forward_text or not forward_text.strip():
        if downloaded_files or saved_urls:
            send_telegram(chat_id,
                f"Got it. {'Files' if downloaded_files else 'Links'} saved to knowledge inbox. Processing now.")
        return

    # Show typing and forward to OpenClaw
    send_typing(chat_id)

    # Notify about files immediately (don't make Master wait for the full response)
    if downloaded_files:
        send_telegram(chat_id,
            f"Files received: {', '.join(downloaded_files)}. Saved to knowledge inbox for processing.")

    if saved_urls and not text.strip():
        send_telegram(chat_id,
            f"Links queued for scraping: {', '.join(saved_urls)}")
        return

    # Forward to OpenClaw for routing
    log.info(f"Forwarding to OpenClaw: {forward_text[:100]}...")
    response = forward_to_openclaw(forward_text, chat_id)

    if response:
        send_telegram(chat_id, response)
    else:
        # Only send error if there was text to process (not just files)
        if text.strip() and not downloaded_files:
            send_telegram(chat_id,
                "Something went wrong processing that. Check the logs.")


def main():
    """Main polling loop."""
    log.info("Vigil Telegram Gateway started")
    log.info(f"Authorized user: {AUTHORIZED_USER_ID}")
    log.info(f"Inbox: {INBOX_DIR}")

    os.makedirs(INBOX_DIR, exist_ok=True)
    state = load_state()

    # Skip to current on first run
    if state["last_update_id"] == 0:
        result = tg_api("getUpdates", {"offset": "-1", "limit": "1", "timeout": "1"})
        if result and result.get("ok") and result["result"]:
            state["last_update_id"] = result["result"][-1]["update_id"]
            save_state(state)
            log.info(f"Initialized at update_id {state['last_update_id']}")

    while running:
        try:
            params = {
                "timeout": "30",
                "limit": "5",
                "offset": str(state["last_update_id"] + 1)
            }

            result = tg_api("getUpdates", params)

            if result and result.get("ok"):
                for update in result["result"]:
                    update_id = update["update_id"]
                    message = update.get("message")

                    if message:
                        process_message(message)

                    state["last_update_id"] = update_id
                    save_state(state)

        except Exception as e:
            log.error(f"Main loop error: {e}")
            time.sleep(5)

    log.info("Telegram Gateway stopped")


if __name__ == "__main__":
    main()
