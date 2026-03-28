#!/usr/bin/env python3
"""
Vigil Telegram Gateway v3
=========================
Async, non-blocking Telegram interface for Vigil.

- Immediate acknowledgment for every message
- Background processing via thread pool
- Files auto-download to inbox (local Bot API, no size limit)
- URLs auto-saved for scraping
- Progress pings for long-running tasks
- Multiple messages can be sent without waiting
- Session continuity (messages within 30 min share context)
- Dead letter queue (failed messages saved for retry)
- Session cost tracking (weekly token budget awareness)
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
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from datetime import datetime, timezone

# Configuration
BOT_TOKEN = "8541708860:AAGmNKlIeo5Acn6Wssk6HzQR1QfMNX2GXwk"
AUTHORIZED_USER_ID = 422985839
INBOX_DIR = "/home/lever/command/inbox/incoming"
STATE_FILE = "/home/lever/command/inbox/telegram-gateway-state.json"
LOG_FILE = "/home/lever/command/inbox/telegram-gateway.log"
OPENCLAW_BIN = "openclaw"
MAX_TG_LENGTH = 4000
MAX_WORKERS = 3  # max concurrent tasks
SESSION_WINDOW = 1800  # 30 minutes: messages within this window share context
DEAD_LETTER_DIR = "/home/lever/command/inbox/failed-messages"
SESSION_COST_FILE = "/home/lever/command/shared-brain/SESSION_COSTS.md"

# Local vs Remote API
LOCAL_API = "http://localhost:8081"
REMOTE_API = "https://api.telegram.org"

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

# Thread pool for background task processing
executor = ThreadPoolExecutor(max_workers=MAX_WORKERS, thread_name_prefix="vigil")
active_tasks = {}  # chat_id -> list of futures
task_lock = threading.Lock()

# Session continuity: track recent messages per user for context
user_sessions = {}  # user_id -> {"messages": [...], "last_time": timestamp, "session_id": str}
session_lock = threading.Lock()

# Session cost tracking
session_count_today = 0
session_count_lock = threading.Lock()

# API base detection
API_BASE = None

def detect_api():
    """Check if local Bot API server is running."""
    global API_BASE
    try:
        req = urllib.request.Request(f"{LOCAL_API}/bot{BOT_TOKEN}/getMe")
        with urllib.request.urlopen(req, timeout=2) as resp:
            result = json.loads(resp.read().decode())
            if result.get("ok"):
                API_BASE = f"{LOCAL_API}/bot{BOT_TOKEN}"
                log.info("Using LOCAL Bot API (no file size limit)")
                return
    except Exception:
        pass
    API_BASE = f"{REMOTE_API}/bot{BOT_TOKEN}"
    log.info("Using REMOTE Bot API (20MB file limit)")


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
    except Exception as e:
        log.error(f"TG API error: {method} - {e}")
        return None


def send_telegram(chat_id, text):
    """Send a message, splitting if needed. Falls back to plain text."""
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
            result = tg_api("sendMessage", data={
                "chat_id": chat_id,
                "text": chunk,
                "parse_mode": "Markdown"
            })
            if not result or not result.get("ok"):
                tg_api("sendMessage", data={
                    "chat_id": chat_id,
                    "text": chunk
                })


def send_typing(chat_id):
    try:
        tg_api("sendChatAction", params={
            "chat_id": str(chat_id),
            "action": "typing"
        })
    except Exception:
        pass


def download_tg_file(file_id, filename):
    """Download a file. Uses local copy in local mode, HTTP in remote mode."""
    result = tg_api("getFile", {"file_id": file_id})
    if not result or not result.get("ok"):
        log.error(f"Could not get file path for {file_id}")
        return None

    file_path = result["result"]["file_path"]
    safe_filename = "".join(c for c in filename if c.isalnum() or c in ".-_ ").strip()
    if not safe_filename:
        safe_filename = f"telegram-{file_id}"

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    dest_path = os.path.join(INBOX_DIR, f"{timestamp}-{safe_filename}")

    # Local mode: file_path is absolute
    if file_path.startswith("/"):
        try:
            import shutil
            shutil.copy2(file_path, dest_path)
            log.info(f"Copied (local): {safe_filename} -> {dest_path}")
            return dest_path
        except Exception as e:
            log.error(f"Local copy failed: {safe_filename} - {e}")
            return None

    # Remote mode
    if LOCAL_API in (API_BASE or ""):
        download_url = f"{LOCAL_API}/file/bot{BOT_TOKEN}/{file_path}"
    else:
        download_url = f"{REMOTE_API}/file/bot{BOT_TOKEN}/{file_path}"

    try:
        urllib.request.urlretrieve(download_url, dest_path)
        log.info(f"Downloaded: {safe_filename} -> {dest_path}")
        return dest_path
    except Exception as e:
        log.error(f"Download failed: {safe_filename} - {e}")
        return None


def get_session_context(user_id, new_message):
    """Maintain conversation context within a 30-minute window."""
    with session_lock:
        now = time.time()
        session = user_sessions.get(user_id, {"messages": [], "last_time": 0, "session_id": None})

        # If more than SESSION_WINDOW since last message, start new session
        if now - session["last_time"] > SESSION_WINDOW:
            session = {
                "messages": [],
                "last_time": now,
                "session_id": f"tg-{user_id}-{int(now)}"
            }

        # Add new message to context (keep last 10 messages)
        session["messages"].append(new_message)
        if len(session["messages"]) > 10:
            session["messages"] = session["messages"][-10:]
        session["last_time"] = now

        user_sessions[user_id] = session

        # Build context string from recent messages
        if len(session["messages"]) > 1:
            context_lines = []
            for i, msg in enumerate(session["messages"][:-1]):
                truncated = msg[:200] + "..." if len(msg) > 200 else msg
                context_lines.append(f"  [{i+1}] {truncated}")
            context = "[Recent conversation context (same session):\n" + "\n".join(context_lines) + "]\n\n"
            return context, session["session_id"]

        return "", session["session_id"]


def save_to_dead_letter(message_text, chat_id, error_reason):
    """Save a failed message for later retry."""
    os.makedirs(DEAD_LETTER_DIR, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    dl_file = os.path.join(DEAD_LETTER_DIR, f"{timestamp}-{chat_id}.json")
    try:
        with open(dl_file, "w") as f:
            json.dump({
                "timestamp": timestamp,
                "chat_id": chat_id,
                "message": message_text,
                "error": error_reason,
                "retried": False
            }, f, indent=2)
        log.info(f"Dead letter saved: {dl_file}")
    except Exception as e:
        log.error(f"Failed to save dead letter: {e}")


def track_session_cost():
    """Increment session counter and log costs."""
    global session_count_today
    with session_count_lock:
        session_count_today += 1
        count = session_count_today

    # Log to cost tracking file
    try:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        cost_line = f"[{datetime.now(timezone.utc).strftime('%H:%M:%S')}] Session #{count}\n"

        # Read or create file
        if os.path.exists(SESSION_COST_FILE):
            with open(SESSION_COST_FILE, "r") as f:
                content = f.read()
        else:
            content = "# SESSION COSTS\n## Daily session count for budget awareness.\n\n"

        # Check if today's section exists
        if f"## {today}" not in content:
            content += f"\n## {today}\n"

        content += cost_line

        with open(SESSION_COST_FILE, "w") as f:
            f.write(content)
    except Exception as e:
        log.error(f"Cost tracking error: {e}")


def forward_to_openclaw_background(message_text, chat_id, user_id=None):
    """Process a message through OpenClaw in a background thread.
    Sends typing indicators and progress pings."""

    start_time = time.time()
    progress_sent = False

    # Typing indicator thread
    typing_active = threading.Event()
    typing_active.set()

    def keep_typing():
        nonlocal progress_sent
        elapsed = 0
        while typing_active.is_set():
            send_typing(chat_id)
            time.sleep(4)
            elapsed = time.time() - start_time
            # Send progress ping at 2 minutes
            if elapsed > 120 and not progress_sent:
                send_telegram(chat_id, "Still working on this. Will report back when done.")
                progress_sent = True

    typing_thread = threading.Thread(target=keep_typing, daemon=True)
    typing_thread.start()

    # Track cost
    track_session_cost()

    # Build command with session ID for continuity
    cmd = [OPENCLAW_BIN, "agent", "--agent", "main",
           "--message", message_text, "--timeout", "3600"]

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=3660,
            env={**os.environ, "HOME": "/home/lever"}
        )
        response = result.stdout.strip()

        if response:
            send_telegram(chat_id, response)
        else:
            # Retry once
            log.warning("Empty response from OpenClaw. Retrying...")
            track_session_cost()
            result2 = subprocess.run(
                cmd, capture_output=True, text=True, timeout=3660,
                env={**os.environ, "HOME": "/home/lever"}
            )
            response2 = result2.stdout.strip()
            if response2:
                send_telegram(chat_id, response2)
            else:
                log.error("OpenClaw returned empty on retry")
                save_to_dead_letter(message_text, chat_id, "empty_response_after_retry")
                send_telegram(chat_id,
                    "I hit an issue and could not complete that after retrying. "
                    "Send it again or rephrase and I will try a different approach.")

    except subprocess.TimeoutExpired:
        log.error("OpenClaw timed out (60 min)")
        save_to_dead_letter(message_text, chat_id, "timeout_60min")
        send_telegram(chat_id,
            "That task hit the 60-minute limit. It may need to be broken into smaller pieces.")
    except Exception as e:
        log.error(f"OpenClaw error: {e}")
        save_to_dead_letter(message_text, chat_id, f"exception: {str(e)[:200]}")
        send_telegram(chat_id,
            "Hit a technical issue. Retrying automatically.")
        try:
            track_session_cost()
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=3660,
                env={**os.environ, "HOME": "/home/lever"}
            )
            if result.stdout.strip():
                send_telegram(chat_id, result.stdout.strip())
        except Exception:
            pass
    finally:
        typing_active.clear()
        typing_thread.join(timeout=5)

    elapsed = time.time() - start_time
    log.info(f"Task completed in {elapsed:.0f}s")


def process_message(message):
    """Process a message: download files, acknowledge immediately, route in background."""
    user_id = message.get("from", {}).get("id")
    chat_id = message.get("chat", {}).get("id")

    if user_id != AUTHORIZED_USER_ID:
        return

    text = message.get("text", "")
    caption = message.get("caption", "")
    downloaded_files = []
    failed_files = []
    saved_urls = []

    # === HANDLE FILES (synchronous, fast with local API) ===

    # Document
    document = message.get("document")
    if document:
        filename = document.get("file_name", f"document-{document['file_id']}")
        file_size = document.get("file_size", 0)
        log.info(f"Document received: {filename} ({file_size} bytes)")
        is_local = API_BASE and LOCAL_API in API_BASE
        if not is_local and file_size > 20_000_000:
            failed_files.append(f"{filename} ({file_size // 1_000_000}MB)")
        else:
            path = download_tg_file(document["file_id"], filename)
            if path:
                downloaded_files.append(filename)
            else:
                failed_files.append(filename)

    # Photo
    photos = message.get("photo")
    if photos:
        largest = max(photos, key=lambda p: p.get("file_size", 0))
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        filename = f"photo-{ts}.jpg"
        path = download_tg_file(largest["file_id"], filename)
        if path:
            downloaded_files.append(filename)

    # Video
    video = message.get("video")
    if video:
        filename = video.get("file_name", f"video-{video['file_id']}.mp4")
        path = download_tg_file(video["file_id"], filename)
        if path:
            downloaded_files.append(filename)

    # Voice/Audio
    for media_type in ["voice", "audio"]:
        media = message.get(media_type)
        if media:
            ext = "ogg" if media_type == "voice" else "mp3"
            filename = media.get("file_name",
                f"{media_type}-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}.{ext}")
            path = download_tg_file(media["file_id"], filename)
            if path:
                downloaded_files.append(filename)

    # URLs in text/caption
    all_text = f"{text} {caption}".strip()
    urls = re.findall(r'https?://[^\s<>"{}|\\^`\[\]]+', all_text)
    for url in urls:
        if "t.me/" in url or "telegram.org" in url:
            continue
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        domain = url.split("//")[1].split("/")[0].replace("www.", "").replace(".", "-")
        url_path = os.path.join(INBOX_DIR, f"{ts}-{domain}.url")
        with open(url_path, "w") as f:
            f.write(url)
        saved_urls.append(url)
        log.info(f"URL saved: {url}")

    # === IMMEDIATE ACKNOWLEDGMENT ===

    if downloaded_files:
        file_list = ", ".join(downloaded_files)
        send_telegram(chat_id,
            f"Got it. {file_list} saved to knowledge base. Processing now.")

    if failed_files:
        fail_list = ", ".join(failed_files)
        send_telegram(chat_id,
            f"Could not download: {fail_list}. SCP it instead:\n"
            "`scp \"file\" lever@165.245.186.254:/home/lever/command/inbox/incoming/`")

    if saved_urls and not text.strip():
        send_telegram(chat_id,
            f"Scraping {len(saved_urls)} link{'s' if len(saved_urls) > 1 else ''} into knowledge base.")
        return

    # === HANDLE REPLY CONTEXT ===
    reply_to = message.get("reply_to_message")
    reply_context = ""
    if reply_to:
        reply_text = reply_to.get("text", "")
        reply_from = reply_to.get("from", {}).get("first_name", "")
        if reply_text:
            if len(reply_text) > 1000:
                reply_text = reply_text[:1000] + "..."
            reply_context = f"[Master is replying to this previous message from {reply_from}: \"{reply_text}\"]\n\n"

    # === SESSION CONTEXT (messages within 30 min share context) ===
    session_context, session_id = get_session_context(user_id, all_text)

    # === BUILD THE FORWARD MESSAGE ===

    forward_text = session_context + reply_context + all_text

    if downloaded_files:
        file_list = ", ".join(downloaded_files)
        if forward_text:
            forward_text += f"\n\n[Files saved to knowledge inbox: {file_list}. The inbox watcher will process them automatically.]"
        elif not saved_urls:
            # File only, no text. Just acknowledge, do not bother OpenClaw.
            return

    if not forward_text or not forward_text.strip():
        return

    # === ROUTE TO OPENCLAW IN BACKGROUND ===

    log.info(f"Queuing for OpenClaw: {forward_text[:80]}...")

    with task_lock:
        if chat_id not in active_tasks:
            active_tasks[chat_id] = []
        # Clean up completed futures
        active_tasks[chat_id] = [f for f in active_tasks[chat_id] if not f.done()]
        queue_depth = len(active_tasks[chat_id])

    # Instant acknowledgment (only for text tasks, files already acknowledged above)
    if not downloaded_files and not saved_urls:
        if queue_depth > 0:
            send_telegram(chat_id,
                f"On it. {queue_depth} task{'s' if queue_depth > 1 else ''} ahead of this, queuing.")
        else:
            send_telegram(chat_id, "On it.")

    future = executor.submit(forward_to_openclaw_background, forward_text, chat_id, user_id)

    with task_lock:
        active_tasks[chat_id].append(future)


def main():
    log.info("Vigil Telegram Gateway v2 started")
    log.info(f"Authorized user: {AUTHORIZED_USER_ID}")
    log.info(f"Inbox: {INBOX_DIR}")
    log.info(f"Max concurrent tasks: {MAX_WORKERS}")

    os.makedirs(INBOX_DIR, exist_ok=True)
    detect_api()
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
                "limit": "10",
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

    # Shutdown
    log.info("Shutting down thread pool...")
    executor.shutdown(wait=True, cancel_futures=False)
    log.info("Telegram Gateway stopped")


if __name__ == "__main__":
    main()
