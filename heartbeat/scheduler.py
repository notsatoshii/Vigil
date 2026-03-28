#!/usr/bin/env python3
"""
Vigil Scheduler
===============
The brain that keeps the PLAN -> CRITIQUE -> BUILD -> VERIFY pipeline moving.

Runs as a systemd service. Every 60 seconds:
1. Reads KANBAN.md to understand current state
2. Determines what can run in parallel vs what must be sequential
3. Dispatches work via openclaw agent (background processes)
4. Tracks active sessions and their progress
5. Monitors for completion and triggers next stage

Dependencies:
- PLAN -> CRITIQUE (sequential: critique needs the plan)
- CRITIQUE APPROVED -> BUILD (sequential: build needs approved plan)
- BUILD -> VERIFY (sequential: verify needs the build)
- BUT: PLAN(task B) can run IN PARALLEL with BUILD(task A)
- AND: IMPROVE, RESEARCH, OPERATE can run in parallel with everything

This is NOT a Claude session. Zero tokens. Pure Python.
"""

import os
import sys
import json
import time
import subprocess
import signal
import threading
import logging
from pathlib import Path
from datetime import datetime, timezone
from dataclasses import dataclass, field

# Config
MAX_SESSIONS = 5
CHECK_INTERVAL = 60  # seconds
KANBAN = "/home/lever/command/shared-brain/KANBAN.md"
ACTIVE_WORK = "/home/lever/command/shared-brain/ACTIVE_WORK.md"
HANDOFFS = "/home/lever/command/handoffs"
LOG_FILE = "/home/lever/command/heartbeat/scheduler.log"
DISPATCH_LOG = "/home/lever/command/heartbeat/dispatch-history.json"

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger("scheduler")

# Graceful shutdown
running = True
def handle_signal(signum, frame):
    global running
    log.info(f"Signal {signum}, shutting down...")
    running = False
signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)


@dataclass
class ActiveSession:
    agent: str
    task: str
    started: float
    process: subprocess.Popen = None
    task_id: str = ""


# Track what is running
active_sessions: dict = {}  # key -> ActiveSession
session_lock = threading.Lock()


def parse_kanban():
    """Parse KANBAN.md into structured data."""
    sections = {
        "BACKLOG": [], "PLANNED": [], "IN PROGRESS": [],
        "IN REVIEW": [], "DONE (last 10)": [], "BLOCKED": []
    }
    try:
        with open(KANBAN, "r") as f:
            content = f.read()
        current = None
        for line in content.split("\n"):
            for section in sections:
                if line.strip().startswith(f"## {section}"):
                    current = section
                    break
            if line.startswith("---"):
                current = None
            elif current and line.startswith("- "):
                sections[current].append(line[2:].strip())
    except Exception as e:
        log.error(f"Failed to parse KANBAN: {e}")
    return sections


def count_active():
    """Count active openclaw agent processes."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", "openclaw agent"],
            capture_output=True, text=True, timeout=5
        )
        return len(result.stdout.strip().split("\n")) if result.stdout.strip() else 0
    except Exception:
        return 0


def dispatch(agent, message, task_id=""):
    """Dispatch a task to an agent in the background."""
    log.info(f"DISPATCH [{agent}] {task_id or message[:60]}...")

    def run_agent():
        try:
            proc = subprocess.Popen(
                ["su", "-", "lever", "-c",
                 f"openclaw agent --agent {agent} --message '{message}' --timeout 3600"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            key = f"{agent}-{task_id or int(time.time())}"
            with session_lock:
                active_sessions[key] = ActiveSession(
                    agent=agent, task=task_id or message[:80],
                    started=time.time(), process=proc, task_id=task_id
                )
            proc.wait()
            with session_lock:
                if key in active_sessions:
                    del active_sessions[key]
            log.info(f"COMPLETE [{agent}] {task_id or message[:60]}")
        except Exception as e:
            log.error(f"DISPATCH ERROR [{agent}]: {e}")

    t = threading.Thread(target=run_agent, daemon=True)
    t.start()
    return True


def get_available_slots():
    """How many more sessions can we start?"""
    active = count_active()
    with session_lock:
        tracked = len(active_sessions)
    actual = max(active, tracked)
    return max(0, MAX_SESSIONS - actual)


def agent_is_running(agent):
    """Check if a specific agent type is already running."""
    with session_lock:
        return any(s.agent == agent for s in active_sessions.values())


def has_recent_handoff(prefix, within_minutes=30):
    """Check if a handoff file was created recently."""
    try:
        for f in Path(HANDOFFS).glob(f"{prefix}*.md"):
            age = time.time() - f.stat().st_mtime
            if age < within_minutes * 60:
                return True
    except Exception:
        pass
    return False


def scheduler_cycle():
    """One cycle of the scheduler. Decides what to dispatch."""
    kanban = parse_kanban()
    available = get_available_slots()

    if available <= 0:
        log.info(f"All {MAX_SESSIONS} slots full. Waiting.")
        return

    log.info(f"Slots available: {available}. "
             f"KANBAN: backlog={len(kanban['BACKLOG'])}, "
             f"planned={len(kanban['PLANNED'])}, "
             f"progress={len(kanban['IN PROGRESS'])}, "
             f"review={len(kanban['IN REVIEW'])}")

    dispatched = 0

    # ============================================================
    # PIPELINE TASKS (respect dependencies)
    # ============================================================

    # 1. VERIFY: if there is work IN REVIEW and VERIFY is not running
    if kanban["IN REVIEW"] and not agent_is_running("verify") and dispatched < available:
        task = kanban["IN REVIEW"][0]
        latest_build = sorted(Path(HANDOFFS).glob("build-*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
        if latest_build:
            dispatch("verify",
                f"Review the latest BUILD handoff at {latest_build[0]}. "
                f"Run all 3 verification passes. Write verdict. Update KANBAN.md.",
                f"verify-{task[:30]}")
            dispatched += 1

    # 2. BUILD: if there are PLANNED items with approved critiques and BUILD is not running
    if kanban["PLANNED"] and not agent_is_running("build") and dispatched < available:
        task = kanban["PLANNED"][0]
        latest_plan = sorted(Path(HANDOFFS).glob("plan-*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
        if latest_plan:
            dispatch("build",
                f"Implement the approved plan at {latest_plan[0]}. "
                f"Follow it step by step. Write handoff. Update KANBAN.md to IN REVIEW.",
                f"build-{task[:30]}")
            dispatched += 1

    # 3. CRITIQUE: if PLAN just finished (recent plan file) and CRITIQUE not running
    if not agent_is_running("critique") and dispatched < available:
        if has_recent_handoff("plan-", within_minutes=60):
            latest_plan = sorted(Path(HANDOFFS).glob("plan-*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
            if latest_plan:
                # Check it has not been critiqued already
                plan_time = latest_plan[0].stat().st_mtime
                critiques = sorted(Path(HANDOFFS).glob("critique-*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
                critique_time = critiques[0].stat().st_mtime if critiques else 0
                if plan_time > critique_time:
                    dispatch("critique",
                        f"Review this plan: {latest_plan[0]}. Write critique. "
                        f"If APPROVED, update KANBAN.md to move task to PLANNED.",
                        "critique")
                    dispatched += 1

    # 4. PLAN: if BACKLOG has items and PLAN is not running
    if kanban["BACKLOG"] and not agent_is_running("plan") and dispatched < available:
        task = kanban["BACKLOG"][0]
        dispatch("plan",
            f"Plan the implementation for: {task}. "
            f"Read the relevant codebase. Write plan to {HANDOFFS}/plan-{int(time.time())}.md. "
            f"Update KANBAN.md (move from BACKLOG, note that planning is in progress).",
            f"plan-{task[:30]}")
        dispatched += 1

    # ============================================================
    # PARALLEL SUPPORT TASKS (fill remaining slots)
    # ============================================================

    # IMPROVE: if not running and has not run in last 2 hours
    if not agent_is_running("improve") and dispatched < available:
        if not has_recent_handoff("improve-", within_minutes=120):
            dispatch("improve",
                "Quick product review. Open http://localhost:3000 in the browser. "
                "Check 2-3 pages. Note issues. Write to IMPROVE_PROPOSALS.md.",
                "improve-review")
            dispatched += 1

    # OPERATE: if not running
    if not agent_is_running("operate") and dispatched < available:
        if not has_recent_handoff("operate-", within_minutes=60):
            dispatch("operate",
                "System check. Read Vigil logs. Check for errors. "
                "Fix issues. Clean up dead processes. Commit fixes.",
                "operate-check")
            dispatched += 1

    # RESEARCH: if not running and has not run in last 4 hours
    if not agent_is_running("research") and dispatched < available:
        if not has_recent_handoff("research-", within_minutes=240):
            dispatch("research",
                "Quick intelligence scan. Check one coverage area. "
                "Update knowledge graph. Keep it under 10 minutes.",
                "research-scan")
            dispatched += 1

    log.info(f"Dispatched {dispatched} tasks this cycle.")


def update_active_work():
    """Update ACTIVE_WORK.md with current state."""
    try:
        with session_lock:
            lines = []
            for key, session in active_sessions.items():
                elapsed = int(time.time() - session.started)
                minutes = elapsed // 60
                lines.append(f"- {session.agent.upper()}: {session.task} ({minutes}m)")

        content = "# ACTIVE WORK\n"
        content += "## Updated automatically by the scheduler.\n\n"
        content += "---\n\n## Currently Running\n\n"
        if lines:
            content += "\n".join(lines) + "\n"
        else:
            content += "*No active sessions.*\n"

        content += "\n---\n\n## Pipeline Status\n\n"
        kanban = parse_kanban()
        content += f"- Backlog: {len(kanban['BACKLOG'])} tasks\n"
        content += f"- Planned: {len(kanban['PLANNED'])} tasks\n"
        content += f"- In Progress: {len(kanban['IN PROGRESS'])} tasks\n"
        content += f"- In Review: {len(kanban['IN REVIEW'])} tasks\n"
        content += f"- Done: {len(kanban['DONE (last 10)'])} tasks\n"
        content += f"- Blocked: {len(kanban['BLOCKED'])} tasks\n"

        with open(ACTIVE_WORK, "w") as f:
            f.write(content)
    except Exception as e:
        log.error(f"Failed to update ACTIVE_WORK: {e}")


def main():
    log.info("Vigil Scheduler started")
    log.info(f"Max sessions: {MAX_SESSIONS}")
    log.info(f"Check interval: {CHECK_INTERVAL}s")
    log.info(f"KANBAN: {KANBAN}")

    while running:
        try:
            scheduler_cycle()
            update_active_work()
        except Exception as e:
            log.error(f"Scheduler error: {e}")

        # Wait for next cycle
        for _ in range(CHECK_INTERVAL):
            if not running:
                break
            time.sleep(1)

    log.info("Scheduler stopped")


if __name__ == "__main__":
    main()
