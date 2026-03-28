# VIGIL SYSTEM HANDOFF
## Last Updated: March 28, 2026
## Written by: Initial build session (Timmy/Claude Opus 4.6)

---

## WHAT EXISTS

### Infrastructure
- **Server**: Timmy-OpenClaw-16gb (16 GB RAM, 4 cores, 193 GB disk, Ubuntu Linux)
- **OpenClaw Gateway**: v2026.3.24, running as systemd service under `lever` user, port 18789
- **Telegram**: Connected, polling as @LeverPM_bot, Master paired (user ID 422985839)
- **Caddy**: Port 80, reverse proxy to lever-frontend on :3000
- **Vigil Dashboard**: Port 8080, static HTML regenerated every 60 seconds

### Agents Registered (11 total)
| Agent | Model | Workspace |
|-------|-------|-----------|
| main (Commander) | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/ |
| build | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/build/ |
| verify | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/verify/ |
| secure | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/secure/ |
| research | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/research/ |
| operate | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/operate/ |
| ceo | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/ceo/ |
| advisor | claude-cli/claude-opus-4-6 | /home/lever/command/workspaces/advisor/ |
| plan | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/plan/ |
| critique | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/critique/ |
| improve | claude-cli/claude-sonnet-4-6 | /home/lever/command/workspaces/improve/ |

### Scheduled Jobs (OpenClaw cron)
| Job | Agent | Schedule |
|-----|-------|----------|
| research-morning-scan | research | Daily 8am UTC |
| research-evening-scan | research | Daily 8pm UTC |
| advisor-daily-brief | advisor | Daily 6am UTC |
| secure-weekly-audit | secure | Monday 3am UTC |
| ceo-weekly-brief | ceo | Monday 7am UTC |
| improve-weekly-review | improve | Wednesday 9am UTC |
| operate-vigil-selfcheck | operate | Every 4 hours |

### System Cron (not OpenClaw)
| Schedule | Script | Purpose |
|----------|--------|---------|
| Every 4 hours | heartbeat/health-escalate.sh | Tier 1/2 health check |
| Every hour | /root/backup-lever-new.sh | Git backup to GitHub |
| Every hour | /root/backup-vigil.sh | Vigil repo backup to GitHub |
| Every 30 min | update-fallback-prices.sh | Oracle fallback prices |

### Dependencies Installed
| Tool | Version | Location |
|------|---------|----------|
| OpenClaw | 2026.3.24 | /usr/lib/node_modules/openclaw/ |
| Bun | 1.3.11 | ~/.bun/bin/ |
| gstack | latest | /home/lever/command/gstack/ (symlinked to ~/.claude/skills/) |
| Scrapling | 0.4.2 | /home/lever/command/venv/ |
| Node.js | v22.22.0 | System |
| Python | 3.12.3 | System |

### Services Status
| Service | Status | Notes |
|---------|--------|-------|
| lever-frontend | Running | Port 3000, proxied via Caddy on 80 |
| lever-oracle | Running | Oracle price keeper |
| lever-accrue-keeper | Running | Borrow index accrual |
| openclaw-gateway | Running | Port 18789, Telegram connected |
| vigil-telegram | Running | Telegram bot relay |
| vigil-dashboard | Running | Port 8080, replaces lever-dashboard |
| vigil-dashboard-gen | Timer | Regenerates HTML every 60s |
| lever-bot | Stopped, disabled | Replaced by OpenClaw Commander |
| lever-dashboard | Stopped, disabled | Replaced by Vigil dashboard |

### Disabled Services (SACRED, never restart)
lever-loop, lever-qa, lever-seeder, lever-watchdog

---

## WHAT WORKS

1. OpenClaw gateway receives Telegram messages and responds as Timmy
2. 11 agents registered with isolated workspaces and CLAUDE.md files
3. Health check script runs clean, detects service failures, auto-restarts
4. Dashboard serves on 8080 and auto-regenerates
5. Heartbeat cron jobs scheduled for all recurring workstream tasks
6. Shared brain files seeded with project context
7. Git repo initialized and committed at /home/lever/command/

---

## WHAT HAS BEEN DONE

- Dispatch flow tested: Telegram messages reach Commander, route to workstreams, responses come back
- Vigil Git repo: github.com/notsatoshii/Vigil, pushed, hourly backup cron active
- Lever Git repo: github.com/notsatoshii/Lever, pushed, hourly backup cron active (clean, no AI refs)
- Inbox pipeline: Built and running as systemd service (vigil-inbox). File watcher on incoming/ dir.
- Lever user has full sudo access (no more permission issues)
- All project locations mapped in PROJECT_STATE.md

## WHAT NEEDS TESTING/WORK

### Priority 1: Timmy repo archival
- Archive github.com/notsatoshii/Timmy on GitHub
- Stop the hourly backup cron for the old repo
- Low risk, just cleanup

### Priority 2: Knowledge graph seeding
- RESEARCH needs to run its first scan and populate watchlists
- Initial competitor data, market data, and trend baselines
- First evening scan fires at 8pm UTC tonight

### Priority 3: Telegram file upload handling
- OpenClaw should pass files sent via Telegram to the inbox pipeline
- Needs testing: send a PDF or image to Timmy on Telegram

### Priority 4: Hardening through use
- Run real tasks through each workstream
- Tune timeouts, permissions, and CLAUDE.md instructions based on results
- Build session memory over time

### Priority 5: PLAN and CRITIQUE pipeline testing
- Run a non-trivial task through the full PLAN -> CRITIQUE -> BUILD -> VERIFY pipeline
- Verify handoff files pass correctly between stages
- Tune CLAUDE.md instructions based on results

### Priority 6: Cross-workstream memory
- Session memory files need to start accumulating
- First few sessions build the muscle

---

## KEY DESIGN DECISIONS MADE

1. **Fully autonomous BUILD -> VERIFY loop.** Only contract changes need Master approval.
2. **SECURE creates draft intentions** for CRITICAL/HIGH findings, pending Master approval.
3. **RESEARCH does not auto-create intentions.** Findings go in briefs. ADVISOR is the funnel.
4. **CEO output lands in shared brain.** Master decides timing.
5. **Caddy over Nginx.** Already installed, simpler.
6. **Commander replaced lever-bot.** Same Telegram token, new code.
7. **Flat file knowledge graph.** No database. Claude reads JSON/markdown natively. RAG layer deferred until scale requires it.
8. **5 concurrent sessions** (up from spec's 3). RAM allows it.
9. **Timmy is a smart-ass.** Dry humor, direct, confident. Personality evolves via TIMMY_PERSONALITY.md observation log.
10. **All workstreams are "teammates who think."** Each has a tailored TEAMMATE MINDSET section.
11. **IMPROVE is a core workstream.** Proactively explores the product via browser and proposes improvements.

---

## FILE STRUCTURE

```
/home/lever/command/
  HANDOFF.md              <- this file
  .gitignore
  dashboard/
    generate.sh           <- regenerates index.html every 60s
    index.html            <- static dashboard
  gstack/                 <- (gitignored) gstack installation
  handoffs/               <- BUILD -> VERIFY handoff reports
  heartbeat/
    health-check.sh       <- Tier 1 health check
    health-escalate.sh    <- Tier 2 escalation wrapper
    build-verify-chain.sh <- BUILD -> VERIFY auto-chain
    last-health-check.json
  inbox/
    incoming/             <- drop files here for ingestion
    processing/
    processed/
    failed/
  knowledge/
    sources/              <- JSON per ingested source
    entities/             <- JSON per entity
    graphs/               <- relationship adjacency lists
    summaries/            <- human-readable markdown summaries
    watchlists/           <- RESEARCH persistent tracking
    trends/               <- RESEARCH time-series data
  shared-brain/
    ACTIVE_WORK.md
    ADVISOR_BRIEFS.md
    CEO_TRACKER.md
    CEO_WEEKLY.md
    DECISIONS.md
    DECISION_JOURNAL.md
    IMPROVE_PROPOSALS.md
    INTENTIONS.md
    LESSONS.md
    PROJECT_STATE.md
    RECENT_SESSIONS.md
    STAKEHOLDER_MAP.md
    TIMMY_PERSONALITY.md
  venv/                   <- (gitignored) Scrapling Python venv
  workspaces/
    CLAUDE.md             <- Commander
    IDENTITY.md, USER.md, HEARTBEAT.md
    build/CLAUDE.md       <- BUILD workstream
    verify/CLAUDE.md      <- VERIFY workstream
    secure/CLAUDE.md      <- SECURE workstream
    research/CLAUDE.md    <- RESEARCH workstream
    operate/CLAUDE.md     <- OPERATE workstream
    ceo/CLAUDE.md         <- CEO workstream
    advisor/CLAUDE.md     <- ADVISOR workstream
    improve/CLAUDE.md     <- IMPROVE workstream
    plan/CLAUDE.md        <- PLAN workstream
    critique/CLAUDE.md    <- CRITIQUE workstream
```

---

## HOW TO RESUME WORK

1. SSH into the server as `lever` user
2. Read this file and shared-brain/PROJECT_STATE.md
3. Check `openclaw health` to verify gateway is running
4. Check `openclaw cron list` to see scheduled jobs
5. Check shared-brain/ACTIVE_WORK.md for what is in flight
6. Pick up from the "WHAT NEEDS TESTING/WORK" section above
