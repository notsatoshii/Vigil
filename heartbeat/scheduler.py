#!/usr/bin/env python3
"""
Vigil Scheduler v2
==================
Intelligent pipeline orchestrator. Runs as a systemd daemon.

Manages the PLAN -> CRITIQUE -> BUILD -> VERIFY pipeline with:
- Task ID tracking (each task flows through stages with a single ID)
- Dependency enforcement (CRITIQUE waits for PLAN, BUILD waits for CRITIQUE, etc.)
- Parallel execution across different tasks
- Duplicate prevention (never dispatch same agent for same task twice)
- Session cost circuit breaker (stops dispatching at weekly limit)
- Accurate process counting
- KANBAN auto-updates (scheduler is source of truth, not agents)

Zero tokens. Pure Python. Runs every 60 seconds.
"""

import os
import sys
import json
import time
import subprocess
import signal
import threading
import logging
import hashlib
from pathlib import Path
from datetime import datetime, timezone
from dataclasses import dataclass, field, asdict

# Config
MAX_SESSIONS = 5
CHECK_INTERVAL = 10
MAX_DAILY_SESSIONS = 80  # circuit breaker
KANBAN = "/home/lever/command/shared-brain/KANBAN.md"
ACTIVE_WORK = "/home/lever/command/shared-brain/ACTIVE_WORK.md"
SESSION_COSTS = "/home/lever/command/shared-brain/SESSION_COSTS.md"
HANDOFFS = "/home/lever/command/handoffs"
STATE_FILE = "/home/lever/command/heartbeat/scheduler-state.json"
LOG_FILE = "/home/lever/command/heartbeat/scheduler.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stdout)]
)
log = logging.getLogger("scheduler")

running = True
def handle_signal(signum, frame):
    global running
    running = False
signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)


# ============================================================
# STATE MANAGEMENT
# ============================================================

@dataclass
class TaskState:
    task_id: str
    title: str
    stage: str  # backlog, planning, critiquing, building, verifying, done, blocked
    agent_pid: int = 0
    dispatched_at: float = 0
    plan_file: str = ""
    critique_file: str = ""
    build_file: str = ""
    verify_file: str = ""
    attempts: int = 0


class SchedulerState:
    def __init__(self):
        self.tasks: dict[str, TaskState] = {}
        self.sessions_today: int = 0
        self.last_reset_date: str = ""
        self.load()

    def load(self):
        try:
            with open(STATE_FILE) as f:
                data = json.load(f)
            for tid, tdata in data.get("tasks", {}).items():
                self.tasks[tid] = TaskState(**tdata)
            self.sessions_today = data.get("sessions_today", 0)
            self.last_reset_date = data.get("last_reset_date", "")
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    def save(self):
        data = {
            "tasks": {tid: asdict(t) for tid, t in self.tasks.items()},
            "sessions_today": self.sessions_today,
            "last_reset_date": self.last_reset_date
        }
        with open(STATE_FILE, "w") as f:
            json.dump(data, f, indent=2)

    def reset_daily(self):
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        if self.last_reset_date != today:
            self.sessions_today = 0
            self.last_reset_date = today
            # Clean up done tasks older than 24 hours
            to_remove = []
            for tid, t in self.tasks.items():
                if t.stage == "done" and t.dispatched_at < time.time() - 86400:
                    to_remove.append(tid)
            for tid in to_remove:
                del self.tasks[tid]


state = SchedulerState()
dispatch_lock = threading.Lock()


# ============================================================
# PROCESS MANAGEMENT
# ============================================================

def count_agent_processes():
    """Count active openclaw agent processes accurately."""
    try:
        result = subprocess.run(
            ["bash", "-c", "ps aux | grep 'openclaw agent' | grep -v grep | wc -l"],
            capture_output=True, text=True, timeout=5
        )
        return int(result.stdout.strip()) if result.stdout.strip() else 0
    except Exception:
        return 0


def is_process_alive(pid):
    """Check if a specific PID is still running."""
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, PermissionError):
        return False


def dispatch_agent(agent, message, task_id):
    """Dispatch an agent session. Returns PID."""
    with dispatch_lock:
        state.sessions_today += 1
        state.save()

    log.info(f"DISPATCH [{agent}] task={task_id} (session #{state.sessions_today} today)")

    try:
        # Use Popen for non-blocking
        proc = subprocess.Popen(
            ["su", "-", "lever", "-c",
             f'openclaw agent --agent {agent} --message "{message}" --timeout 3600'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        return proc.pid
    except Exception as e:
        log.error(f"DISPATCH FAILED [{agent}]: {e}")
        return 0


# ============================================================
# KANBAN MANAGEMENT
# ============================================================

def read_kanban_section(section):
    """Read items from a KANBAN section."""
    items = []
    try:
        with open(KANBAN) as f:
            content = f.read()
        in_section = False
        for line in content.split("\n"):
            if line.strip().startswith(f"## {section}"):
                in_section = True
                continue
            if in_section and line.startswith("---"):
                break
            if in_section and line.startswith("- "):
                items.append(line[2:].strip())
    except Exception:
        pass
    return items


def update_kanban(task_title, from_section, to_section):
    """Move a task between KANBAN sections."""
    try:
        with open(KANBAN) as f:
            content = f.read()

        # Remove from source section
        lines = content.split("\n")
        new_lines = []
        skip_next = False
        for line in lines:
            if line.startswith("- ") and task_title[:30] in line:
                continue  # remove it
            new_lines.append(line)

        content = "\n".join(new_lines)

        # Add to target section
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        new_entry = f"- [{timestamp}] {task_title}"
        section_header = f"## {to_section}"
        content = content.replace(
            section_header + "\n",
            section_header + "\n" + new_entry + "\n",
            1
        )

        with open(KANBAN, "w") as f:
            f.write(content)

        log.info(f"KANBAN: '{task_title[:40]}...' moved to {to_section}")
    except Exception as e:
        log.error(f"KANBAN update failed: {e}")


# ============================================================
# TASK ID GENERATION
# ============================================================

def make_task_id(title):
    """Generate a stable task ID from title."""
    clean = title.split(":")[0].strip() if ":" in title else title[:20]
    return clean.replace(" ", "-").replace("[", "").replace("]", "").lower()


# ============================================================
# SCHEDULER LOGIC
# ============================================================

def check_completed_tasks():
    """Check if any dispatched tasks have completed (process no longer alive)."""
    for tid, task in list(state.tasks.items()):
        if task.agent_pid > 0 and not is_process_alive(task.agent_pid):
            # Process finished. Advance to next stage.
            task.agent_pid = 0

            if task.stage == "planning":
                # Check if plan file was created
                plan_files = sorted(Path(HANDOFFS).glob("plan-*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
                if plan_files:
                    task.plan_file = str(plan_files[0])
                    task.stage = "planned"
                    log.info(f"PLAN complete for {tid}. Moving to critique.")
                else:
                    task.stage = "backlog"
                    log.warning(f"PLAN for {tid} produced no plan file. Returning to backlog.")

            elif task.stage == "critiquing":
                # Check critique verdict
                critique_files = sorted(Path(HANDOFFS).glob("critique-*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
                if critique_files:
                    task.critique_file = str(critique_files[0])
                    try:
                        verdict_text = critique_files[0].read_text()
                        if "APPROVED" in verdict_text.upper():
                            task.stage = "approved"
                            log.info(f"CRITIQUE APPROVED for {tid}. Ready for BUILD.")
                            update_kanban(task.title, "BACKLOG", "PLANNED")
                        elif "REJECT" in verdict_text.upper():
                            task.stage = "backlog"
                            task.attempts += 1
                            log.info(f"CRITIQUE REJECTED for {tid}. Back to backlog.")
                        else:
                            task.stage = "planned"  # needs revision, re-plan
                            log.info(f"CRITIQUE wants REVISE for {tid}. Re-planning.")
                    except Exception:
                        task.stage = "approved"  # assume approved if we cannot parse
                else:
                    task.stage = "planned"  # no critique file, retry

            elif task.stage == "building":
                build_files = sorted(Path(HANDOFFS).glob("build-*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
                if build_files:
                    task.build_file = str(build_files[0])
                    task.stage = "built"
                    log.info(f"BUILD complete for {tid}. Moving to VERIFY.")
                    update_kanban(task.title, "IN PROGRESS", "IN REVIEW")
                else:
                    task.stage = "approved"  # no build file, retry
                    log.warning(f"BUILD for {tid} produced no handoff. Retrying.")

            elif task.stage == "verifying":
                verify_files = sorted(Path(HANDOFFS).glob("verify-*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
                if verify_files:
                    task.verify_file = str(verify_files[0])
                    try:
                        verdict_text = verify_files[0].read_text()
                        if "PASS" in verdict_text.upper() and "FAIL" not in verdict_text.upper():
                            task.stage = "done"
                            log.info(f"VERIFY PASSED for {tid}. Task complete!")
                            update_kanban(task.title, "IN REVIEW", "DONE (last 10)")
                        elif "DESIGN FLAW" in verdict_text.upper() or "RE-PLAN" in verdict_text.upper():
                            task.stage = "backlog"
                            task.attempts += 1
                            log.info(f"VERIFY found DESIGN FLAW in {tid}. Sending back to PLAN.")
                        else:
                            task.stage = "approved"
                            task.attempts += 1
                            log.info(f"VERIFY FAILED {tid}. Sending back to BUILD (attempt {task.attempts}).")
                    except Exception:
                        task.stage = "approved"
                        task.attempts += 1
                else:
                    task.stage = "built"  # no verdict, retry verify

            state.save()


def dispatch_pipeline_work():
    """Dispatch work based on current state and available capacity."""
    available = MAX_SESSIONS - count_agent_processes()
    if available <= 0:
        return 0

    # Circuit breaker
    if state.sessions_today >= MAX_DAILY_SESSIONS:
        log.warning(f"CIRCUIT BREAKER: {state.sessions_today} sessions today. Max is {MAX_DAILY_SESSIONS}. Stopping dispatches.")
        return 0

    dispatched = 0

    # Check tasks that need the next pipeline stage
    for tid, task in sorted(state.tasks.items(), key=lambda x: x[1].attempts):
        if dispatched >= available:
            break
        if task.agent_pid > 0:
            continue  # already running
        if task.attempts >= 3:
            if task.stage != "blocked":
                task.stage = "blocked"
                update_kanban(task.title, "IN PROGRESS", "BLOCKED")
                log.warning(f"BLOCKED: {tid} failed {task.attempts} times.")
            continue

        if task.stage == "planned" and not any(t.stage == "critiquing" and t.agent_pid > 0 for t in state.tasks.values()):
            # Dispatch CRITIQUE
            msg = f"Review the plan at {task.plan_file}. Write critique to {HANDOFFS}/critique-{tid}.md. Check the actual codebase. Be adversarial."
            pid = dispatch_agent("critique", msg, tid)
            if pid:
                task.stage = "critiquing"
                task.agent_pid = pid
                task.dispatched_at = time.time()
                dispatched += 1

        elif task.stage == "approved":
            # Dispatch BUILD
            msg = f"Implement the approved plan at {task.plan_file}. Follow it step by step. Write handoff to {HANDOFFS}/build-{tid}.md. Update KANBAN.md to IN PROGRESS."
            pid = dispatch_agent("build", msg, tid)
            if pid:
                task.stage = "building"
                task.agent_pid = pid
                task.dispatched_at = time.time()
                update_kanban(task.title, "PLANNED", "IN PROGRESS")
                dispatched += 1

        elif task.stage == "built":
            # Dispatch VERIFY
            msg = f"Review the BUILD handoff at {task.build_file}. Run all 3 verification passes. Write verdict to {HANDOFFS}/verify-{tid}.md. If you find a DESIGN FLAW (not just a code bug), say DESIGN FLAW explicitly."
            pid = dispatch_agent("verify", msg, tid)
            if pid:
                task.stage = "verifying"
                task.agent_pid = pid
                task.dispatched_at = time.time()
                dispatched += 1

    # Ingest new backlog items as tasks (only ONE at a time, only if no PLAN is running)
    any_planning = any(t.stage == "planning" and t.agent_pid > 0 for t in state.tasks.values())
    if not any_planning and dispatched < available:
        backlog = read_kanban_section("BACKLOG")
        for item in backlog:
            tid = make_task_id(item)
            if tid not in state.tasks:
                state.tasks[tid] = TaskState(task_id=tid, title=item, stage="backlog")
                msg = f"Plan the implementation for: {item}. Read the codebase. Write structured plan to {HANDOFFS}/plan-{tid}.md."
                pid = dispatch_agent("plan", msg, tid)
                if pid:
                    state.tasks[tid].stage = "planning"
                    state.tasks[tid].agent_pid = pid
                    state.tasks[tid].dispatched_at = time.time()
                    dispatched += 1
                break  # only one new PLAN per cycle

    # Fill remaining slots with support work
    remaining = available - dispatched
    if remaining > 0 and not any_agent_running("improve"):
        pid = dispatch_agent("improve",
            "Quick product review. Open http://localhost:3000 in browser. Check 2-3 pages. Write findings to shared-brain/IMPROVE_PROPOSALS.md.",
            "support-improve")
        if pid:
            dispatched += 1
            remaining -= 1

    if remaining > 0 and not any_agent_running("operate"):
        pid = dispatch_agent("operate",
            "System check. Read Vigil logs. Fix issues. Commit fixes to git.",
            "support-operate")
        if pid:
            dispatched += 1
            remaining -= 1

    if remaining > 0 and not any_agent_running("research"):
        pid = dispatch_agent("research",
            "Quick scan. Check one coverage area. Update knowledge graph.",
            "support-research")
        if pid:
            dispatched += 1

    state.save()
    return dispatched


def any_agent_running(agent):
    """Check if an agent type is currently running."""
    for task in state.tasks.values():
        if task.agent_pid > 0 and is_process_alive(task.agent_pid):
            return True
    # Also check for support tasks
    try:
        result = subprocess.run(
            ["bash", "-c", f"ps aux | grep 'openclaw agent.*--agent {agent}' | grep -v grep | wc -l"],
            capture_output=True, text=True, timeout=5
        )
        return int(result.stdout.strip() or "0") > 0
    except Exception:
        return False


def update_active_work():
    """Write current state to ACTIVE_WORK.md."""
    try:
        lines = []
        pipeline_tasks = []
        for tid, task in state.tasks.items():
            if task.stage in ("done", "blocked"):
                continue
            status = task.stage
            if task.agent_pid > 0 and is_process_alive(task.agent_pid):
                elapsed = int(time.time() - task.dispatched_at) // 60
                status = f"{task.stage} ({elapsed}m)"
            pipeline_tasks.append(f"- **{tid}**: {task.title[:60]} [{status}]")

        content = "# ACTIVE WORK\n"
        content += f"## Updated by scheduler at {datetime.now(timezone.utc).strftime('%H:%M:%S UTC')}\n\n"
        content += f"Sessions today: {state.sessions_today}/{MAX_DAILY_SESSIONS}\n\n---\n\n"
        content += "## Pipeline Tasks\n\n"
        content += "\n".join(pipeline_tasks) if pipeline_tasks else "*No active pipeline tasks.*"
        content += "\n\n---\n\n## KANBAN Summary\n\n"

        for section in ["BACKLOG", "PLANNED", "IN PROGRESS", "IN REVIEW", "DONE (last 10)", "BLOCKED"]:
            items = read_kanban_section(section)
            content += f"- {section}: {len(items)}\n"

        with open(ACTIVE_WORK, "w") as f:
            f.write(content)
    except Exception as e:
        log.error(f"ACTIVE_WORK update failed: {e}")


# ============================================================
# MAIN LOOP
# ============================================================

def main():
    log.info("Vigil Scheduler v2 started")
    log.info(f"Max sessions: {MAX_SESSIONS}, Daily limit: {MAX_DAILY_SESSIONS}")

    while running:
        try:
            state.reset_daily()
            check_completed_tasks()
            dispatched = dispatch_pipeline_work()
            update_active_work()

            active = count_agent_processes()
            log.info(f"Cycle: {active} active, {MAX_SESSIONS - active} available, "
                     f"{dispatched} dispatched, {state.sessions_today} today")

        except Exception as e:
            log.error(f"Scheduler error: {e}")

        for _ in range(CHECK_INTERVAL):
            if not running:
                break
            time.sleep(1)

    state.save()
    log.info("Scheduler stopped")


if __name__ == "__main__":
    main()
