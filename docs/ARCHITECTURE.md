# Vigil Architecture

## System Overview

Vigil is a message-driven orchestration system. A message arrives (via Telegram, SSH, or browser), gets classified by Commander, and routes to one of eight specialized workstreams. Each workstream runs as an isolated Claude Code session with its own workspace, instructions, and codebase access level.

```
Telegram Message
      |
      v
OpenClaw Gateway (port 18789, always-on systemd service)
      |
      v
Commander (main agent, Sonnet)
      |
      +-- Classifies intent using routing table
      +-- Reads last 3 entries from RECENT_SESSIONS.md for context
      +-- Checks ACTIVE_WORK.md for collisions
      +-- Spawns Claude Code session in target workspace
      |
      v
Workstream Agent (isolated workspace)
      |
      +-- Reads CLAUDE.md (workstream instructions)
      +-- Reads TIMMY_PERSONALITY.md (voice and preferences)
      +-- Reads shared brain files (context)
      +-- Executes task with gstack skills
      +-- Writes results to shared brain
      +-- Reports to Telegram via Commander
```

## Component Architecture

### OpenClaw Gateway

The always-on daemon. Runs as a systemd service under the `lever` user.

- **Process**: Node.js, ~450 MB RAM
- **Port**: 18789 (loopback only)
- **Auth**: Token-based gateway auth
- **Channels**: Telegram (polling mode, @LeverPM_bot)
- **Agent Backend**: claude-cli provider (uses Claude Max subscription via Claude Code CLI)
- **Cron**: Built-in scheduler for Heartbeat tasks
- **Config**: /home/lever/.openclaw/openclaw.json

### Workspace Isolation

Each workstream has its own directory under `/home/lever/command/workspaces/`:

```
workspaces/
  CLAUDE.md              <- Commander (routing, Telegram voice)
  IDENTITY.md            <- Timmy's identity definition
  USER.md                <- Master's profile
  HEARTBEAT.md           <- Proactive task definitions
  build/
    CLAUDE.md            <- BUILD instructions
    .claude/             <- Session history (isolated)
    lever-protocol -> /home/lever/Lever/  (symlink, read-write)
  verify/
    CLAUDE.md            <- VERIFY instructions
    .claude/
    lever-protocol -> /home/lever/Lever/  (symlink, read-only intent)
  secure/
    CLAUDE.md            <- SECURE instructions
    .claude/
    lever-protocol -> /home/lever/Lever/  (symlink, read-only)
  research/
    CLAUDE.md            <- RESEARCH instructions
    .claude/
    (no codebase symlink)
  operate/
    CLAUDE.md            <- OPERATE instructions
    .claude/
    lever-protocol -> /home/lever/Lever/  (symlink, read-only)
  ceo/
    CLAUDE.md            <- CEO instructions
    .claude/
    (no codebase symlink)
  advisor/
    CLAUDE.md            <- ADVISOR instructions
    .claude/
    lever-protocol -> /home/lever/Lever/  (symlink, read-only)
  improve/
    CLAUDE.md            <- IMPROVE instructions
    .claude/
    lever-protocol -> /home/lever/Lever/  (symlink, read-only)
```

### Shared Brain

Central knowledge store at `/home/lever/command/shared-brain/`. All files are markdown. Every workstream reads relevant files at session start and writes updates at session end.

```
shared-brain/
  PROJECT_STATE.md       <- Living project snapshot (updated by ADVISOR)
  DECISIONS.md           <- Decision log with rationale
  LESSONS.md             <- What failed and why (30+ lessons)
  RECENT_SESSIONS.md     <- Last 30 session logs (pruned by ADVISOR)
  ADVISOR_BRIEFS.md      <- Daily briefs and improvement proposals
  INTENTIONS.md          <- Priority queue (ACTIVE, STANDING ORDERS, PENDING APPROVAL, ADVISOR APPROVED)
  ACTIVE_WORK.md         <- What is in flight now (prevents collisions)
  TIMMY_PERSONALITY.md   <- Living personality (observation log at bottom)
  CEO_TRACKER.md         <- Follow-ups, meetings, fundraising pipeline
  CEO_WEEKLY.md          <- Weekly strategic synthesis
  DECISION_JOURNAL.md    <- Decisions with expected outcomes
  STAKEHOLDER_MAP.md     <- Key people and relationships
  IMPROVE_PROPOSALS.md   <- Product improvement suggestions
```

### Knowledge Graph

Flat-file knowledge system at `/home/lever/command/knowledge/`:

```
knowledge/
  sources/               <- One JSON file per ingested source
    {id, filename, date, type, summary, entities, categories, relationships}
  entities/              <- One JSON file per tracked entity
    {name, type, facts[], relationships[], lastUpdated}
  graphs/                <- Relationship adjacency lists (JSON)
  summaries/             <- Human-readable markdown (what workstreams read)
    technical-landscape.md
    competitor-analysis.md
    investor-research.md
    market-intelligence.md
    design-references.md
    regulatory-landscape.md
  watchlists/            <- RESEARCH persistent tracking targets (JSON)
  trends/                <- Time-series data for trend analysis
```

### Heartbeat System

Two layers of scheduled tasks:

**System crontab** (runs regardless of OpenClaw):
- Health check every 4 hours (bash script, zero tokens)
- Git backup every hour (Lever repo and Vigil repo)
- Oracle fallback price updates every 30 minutes

**OpenClaw cron** (managed by the gateway):
- RESEARCH morning/evening scans
- ADVISOR daily brief
- SECURE weekly audit
- CEO weekly brief
- IMPROVE weekly product review

### Dashboard

Static HTML page at `/home/lever/command/dashboard/index.html`. Regenerated every 60 seconds by a systemd timer running `dashboard/generate.sh`. Served on port 8080 via `npx serve`.

Shows: system health (RAM, disk, CPU), service status, active sessions, pending approvals, latest ADVISOR brief, active intentions, recent sessions, knowledge graph stats, Heartbeat schedule.

## Data Flow Diagrams

### Task Execution Flow

```
1. Master sends "add referral tracking" via Telegram
2. OpenClaw receives message, passes to Commander (main agent)
3. Commander reads RECENT_SESSIONS.md for context
4. Commander classifies: this is a BUILD task
5. Commander spawns Claude Code session in workspaces/build/
6. BUILD reads its CLAUDE.md, TIMMY_PERSONALITY.md, PROJECT_STATE.md, LESSONS.md
7. BUILD runs gstack /office-hours (interrogates the idea)
8. BUILD runs gstack /plan-eng-review (architects the solution)
9. BUILD implements the code
10. BUILD runs gstack /review (self-review)
11. BUILD writes handoff report to /home/lever/command/handoffs/build-handoff.md
12. BUILD triggers auto-chain script
13. VERIFY session spawns in workspaces/verify/
14. VERIFY reads handoff report
15. VERIFY runs Pass 1: Functional (tests, contract calls)
16. VERIFY runs Pass 2: Visual (browser QA, screenshots)
17. VERIFY runs Pass 3: Data (values match contract state)
18. If PASS: Commander notifies Master on Telegram
19. If FAIL: Feedback goes to BUILD, loop repeats (max 3)
20. Shared brain files updated throughout
```

### Approval Flow (Contract Changes)

```
1. BUILD encounters Solidity change requirement
2. BUILD stops and sends approval request via Telegram
3. Master reviews and replies "approved" or "no"
4. If approved: BUILD proceeds with the change
5. If denied: BUILD finds alternative approach or reports back
```

### SECURE Escalation Flow

```
1. SECURE finds CRITICAL vulnerability during weekly audit
2. SECURE writes report to shared brain
3. SECURE sends immediate Telegram notification
4. SECURE auto-creates draft intention in INTENTIONS.md (PENDING MASTER APPROVAL)
5. Master reviews and /approve or /reject
6. If approved: intention moves to ACTIVE, BUILD picks it up
7. If rejected: intention archived with reason
```

### ADVISOR Daily Cycle

```
1. 6am UTC: OpenClaw cron triggers ADVISOR session (Opus)
2. Phase 1 (Ingest): Read ALL shared brain files, all recent outputs
3. Phase 2 (Analyze): Five dimensions (technical, strategic, design, operational, system)
4. Phase 3 (Brief): Write max 7 items to ADVISOR_BRIEFS.md
5. Phase 4 (Proposals): System improvement suggestions (individually reviewable)
6. Phase 5 (Maintenance): Prune sessions, consolidate decisions, update project state
7. Summary announced to Telegram
```

## Network Topology

```
Internet
    |
    v
Port 80 (Caddy) -> Port 3000 (lever-frontend, React app)
Port 8080 (Vigil Dashboard, static HTML)
Port 8545 (Anvil, local EVM node)
Port 18789 (OpenClaw Gateway, loopback only)
Port 22 (SSH)
```

## Service Inventory

| Service | Type | User | Port | Status |
|---------|------|------|------|--------|
| openclaw-gateway | systemd | lever | 18789 | Active |
| vigil-dashboard | systemd | lever | 8080 | Active |
| vigil-dashboard-gen | systemd timer | root | n/a | Active (every 60s) |
| lever-frontend | systemd | lever | 3000 | Active |
| lever-oracle | systemd | lever | n/a | Active |
| lever-accrue-keeper | systemd | lever | n/a | Active |
| caddy | systemd | root | 80 | Active |

### Sacred Services (never restart)
lever-loop, lever-qa, lever-seeder, lever-watchdog

## File System Layout

```
/home/lever/
  Lever/                   <- LEVER Protocol repo (github.com/notsatoshii/Lever)
  command/                 <- Vigil system (github.com/notsatoshii/Vigil)
    README.md
    HANDOFF.md
    LICENSE
    docs/
      ARCHITECTURE.md      <- This file
      DEPLOYMENT.md
    dashboard/
      generate.sh
      index.html
    gstack/                <- gstack installation (gitignored)
    handoffs/              <- BUILD -> VERIFY handoff reports
    heartbeat/
      health-check.sh
      health-escalate.sh
      build-verify-chain.sh
    inbox/
      incoming/
      processing/
      processed/
      failed/
    knowledge/
    shared-brain/
    venv/                  <- Scrapling Python venv (gitignored)
    workspaces/
  lever-protocol/          <- Legacy repo (deprecated)
  .openclaw/               <- OpenClaw state and config
  .claude/                 <- Claude Code config and skills
    skills/
      gstack -> /home/lever/command/gstack/
```

## Security Model

- OpenClaw gateway binds to loopback only (127.0.0.1:18789). Not accessible from the internet.
- Telegram communication goes through OpenClaw's polling mechanism (outbound only).
- DM pairing required before Telegram users can interact.
- Claude Code sessions run as the `lever` user (not root).
- Deploy keys are per-repo (Lever and Vigil have separate SSH keys).
- Private keys and .env files are gitignored and never committed.
- Contract changes require explicit Master approval via Telegram.
