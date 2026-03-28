# VIGIL SYSTEM HANDOFF
## Last Updated: March 28, 2026 14:00 UTC
## Status: OPERATIONAL. System should be running autonomously.

---

## WHAT IS RUNNING

### Services (all should be active)
| Service | Port | Purpose |
|---------|------|---------|
| openclaw-gateway | 18789 | Agent orchestration |
| vigil-telegram | n/a | Telegram file/message gateway |
| vigil-dashboard | 8080 | Mission control (Node.js WebSocket) |
| vigil-inbox | n/a | File watcher for knowledge ingestion |
| vigil-scheduler | n/a | Pipeline orchestrator (Python daemon) |
| telegram-bot-api | 8081 | Local Telegram API (no file size limit) |
| lever-frontend | 3000 | LEVER Protocol frontend |
| lever-oracle | n/a | Oracle price keeper |
| lever-accrue-keeper | n/a | Borrow index accrual |
| caddy | 80 | Reverse proxy |

### Scheduled Jobs
| Job | Schedule | Agent |
|-----|----------|-------|
| overseer | Every 2h | advisor (Opus) |
| operate-selfcheck | Every 1h | operate |
| research-morning-scan | 8am UTC | research |
| research-evening-scan | 8pm UTC | research |
| advisor-daily-brief | 6am UTC | advisor |
| secure-weekly-audit | Mon 3am UTC | secure |
| ceo-weekly-brief | Mon 7am UTC | ceo |
| improve-weekly-review | Wed 9am UTC | improve |

### Continuous: Scheduler (vigil-scheduler)
Runs every 60 seconds. Manages PLAN -> CRITIQUE -> BUILD -> VERIFY pipeline.
Reads KANBAN.md backlog, dispatches work, tracks task IDs, enforces dependencies.
State file: /home/lever/command/heartbeat/scheduler-state.json

## WHAT NEEDS CONTINUOUS IMPROVEMENT

These items are in the KANBAN backlog. The scheduler should be pulling them
through the pipeline. If you are reading this and they are still in backlog,
something is stuck. Fix it.

1. VIGIL-DASHBOARD: Real-time mission control with reactive data, visible KANBAN, pipeline viz
2. VIGIL-VERIFY-VISION: VERIFY must use Puppeteer screenshots + Claude vision
3. VIGIL-SELF-IMPROVE: System must self-improve without Master intervention
4. LEVER critical bugs (BUG-1 through BUG-9)
5. Landing page mobile and design improvements

## KEY FILES

- Scheduler: /home/lever/command/heartbeat/scheduler.py
- Scheduler state: /home/lever/command/heartbeat/scheduler-state.json
- Telegram gateway: /home/lever/command/inbox/telegram-gateway.py
- Dashboard server: /home/lever/command/dashboard/server.js
- Dashboard HTML: /home/lever/command/dashboard/mission-control.html
- Dashboard data: /home/lever/command/dashboard/generate-data.sh -> data.json
- All CLAUDE.md: /home/lever/command/workspaces/*/CLAUDE.md
- Shared brain: /home/lever/command/shared-brain/
- Knowledge: /home/lever/command/knowledge/

## HOW TO RESUME

1. Check: systemctl status vigil-scheduler vigil-telegram vigil-dashboard openclaw-gateway
2. Read: shared-brain/ACTIVE_WORK.md (scheduler updates this automatically)
3. Read: shared-brain/KANBAN.md (what is in each pipeline stage)
4. Read: shared-brain/OVERSEER_REPORT.md (latest efficiency/quality report)
5. Read: heartbeat/scheduler.log (what the scheduler is doing)
6. Fix whatever is broken. Do not ask Master. Just fix it.
