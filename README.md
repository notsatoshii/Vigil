# Vigil

**Autonomous AI Operations System**

Vigil is an always-on orchestration layer that runs a team of specialized AI workstreams. It receives instructions via Telegram, routes them to the right specialist, executes autonomously, and reports back. Think of it as a virtual operations team that works while you sleep.

Built on [OpenClaw](https://docs.openclaw.ai) + [Claude Code](https://claude.ai/claude-code) + [gstack](https://github.com/garrytan/gstack).

## Architecture

```
Master (Telegram / SSH / Browser)
         |
         v
   OpenClaw Gateway (always-on daemon, Sonnet for routing)
         |
         +-- Classifies intent from Telegram messages
         +-- Reads shared brain for context
         +-- Spawns Claude Code session in the correct workspace
         +-- Collects output, updates brain, reports to Telegram
         +-- Manages task queue (max 5 concurrent sessions)
         +-- Runs Heartbeat cron for proactive/autonomous work
         +-- Processes file uploads into knowledge system
         |
         +------+------+------+------+------+------+------+------+------+------+
         |      |      |      |      |      |      |      |      |      |      |
       BUILD  VERIFY  PLAN CRITIQUE SECURE RESEARCH OPERATE  CEO  ADVISOR IMPROVE
         |      |      |      |      |      |      |      |
    (each is an isolated Claude Code workspace with its own
     CLAUDE.md, session history, codebase access level, and
     gstack skills baked in as automatic behavior)
```

### How Routing Works

Every Telegram message hits Commander (the main agent). Commander classifies intent and routes to the correct workstream:

| Message is about... | Routes to... |
|---|---|
| Building, implementing, fixing, coding, creating features | BUILD |
| Reviewing code, QA, testing, validating work quality | VERIFY |
| Security, auditing, vulnerabilities, threats | SECURE |
| Research, web lookup, market data, competitors | RESEARCH |
| Server health, services, logs, infrastructure | OPERATE |
| Documents, fundraising, marketing, meetings, strategy | CEO |
| New features, significant changes, architecture decisions | PLAN |
| Adversarial review of plans before BUILD starts | CRITIQUE |
| Big picture review, cross-project analysis, system improvement | ADVISOR |
| Product improvements, UX, UI suggestions, feature ideas | IMPROVE |

### Auto-Chaining

The full pipeline is: PLAN -> CRITIQUE -> BUILD -> VERIFY.

When a non-trivial task arrives, Commander routes it to PLAN. PLAN produces a structured implementation plan. CRITIQUE reviews the plan adversarially (APPROVED, REVISE, or REJECT). Once approved, BUILD implements the plan. BUILD finishes, writes a handoff report, exits. Vigil spawns a VERIFY session that independently reviews the work with three verification passes (functional, visual, data). If VERIFY fails with a code bug, it sends feedback straight back to BUILD. If VERIFY identifies a design flaw, it routes back to PLAN for re-architecture. The loop runs until VERIFY passes or escalates after 3 failures.

Simple bug fixes skip PLAN/CRITIQUE and go directly to BUILD.

## The Ten Workstreams

### BUILD
Senior engineer. Implements features, fixes bugs, writes code. Fully autonomous except for Solidity contract changes (requires approval). Uses gstack's office-hours, engineering review, and self-review processes automatically.

### VERIFY
Quality gate. Three mandatory verification passes on every review: (1) functional (tests, contract calls, behavioral correctness), (2) visual (browser QA via Puppeteer/Chromium, screenshots, layout checks), (3) data (on-screen values match contract state, decimal precision, no stale data). Adversarial by design.

### PLAN
Technical architect. Receives non-trivial tasks and produces structured implementation plans. Reads the actual codebase before planning. Maps dependencies, edge cases, ripple effects, and rollback strategies. Every plan specifies exactly what files change, in what order, and why. Plans go to CRITIQUE for adversarial review before BUILD starts.

### CRITIQUE
Adversarial plan reviewer. The quality gate between planning and execution. Assumes every plan has flaws and tries to find them. Evaluates correctness, completeness, consistency, edge cases, ripple effects, simplicity, test coverage, and rollback safety. Verdicts: APPROVED (send to BUILD), REVISE (send back to PLAN with specific feedback), or REJECT (fundamental rethinking needed).

### SECURE
Paranoid security engineer. Weekly automated audits plus on-demand. Analyzes smart contracts (reentrancy, access control, flash loans, oracle manipulation), frontend (XSS, exposed secrets), infrastructure (exposed ports, API security), and economic attacks (MEV, sandwich, sybil). CRITICAL/HIGH findings auto-create draft intentions pending approval.

### RESEARCH
Full-time analyst. Twice-daily market scans. Tracks five domains: prediction market infrastructure (Polymarket, Kalshi, Azuro, competitors), AI and tooling, crypto markets and DeFi, geopolitics and macro economics, industry events. Maintains persistent watchlists, time-series trend data, and contrarian analysis. Full source citations required on every finding.

### OPERATE
Infrastructure reliability engineer. Two-tier monitoring: Tier 1 is a bash health check (every 4 hours, zero tokens). Tier 2 spawns a Claude Code session only when problems are detected. Can autonomously restart active services (max 2 attempts before escalating). Never touches disabled/sacred services.

### CEO
Strategic co-pilot and chief of staff. Handles fundraising, investor comms, meeting prep, follow-ups, design briefs, content creation, Korean-language reports, financial modeling. Maintains decision journal, stakeholder map, and weekly strategic synthesis. Coordinates with RESEARCH for intelligence. Frames decisions with opportunity cost analysis.

### ADVISOR
Board member who sees everything. Runs on Opus (all others use Sonnet). Daily cycle: ingests all workstream outputs, analyzes across five dimensions (technical, strategic, design, operational, system), produces a brief (max 7 items), proposes system improvements. Each proposal individually reviewable. Maintains brain files. The only workstream that evaluates Vigil itself.

### IMPROVE
User advocate. Proactively browses the live product via Puppeteer/Chromium as a real user would. Evaluates UI/design quality, UX flow, data visualization, feature gaps, and competitive positioning. Writes improvement proposals that flow through ADVISOR or Master for approval. Weekly deep reviews plus on-demand.

## Shared Brain

All workstreams read from and write to a shared set of markdown files that serve as institutional memory:

| File | Purpose |
|------|---------|
| PROJECT_STATE.md | Living snapshot of all projects |
| DECISIONS.md | Log of key decisions with rationale |
| LESSONS.md | What failed and why (known bug patterns, process learnings) |
| RECENT_SESSIONS.md | Last 30 workstream sessions (chronological) |
| ADVISOR_BRIEFS.md | Daily briefs and system improvement proposals |
| INTENTIONS.md | Priority queue for autonomous work |
| ACTIVE_WORK.md | What is in flight right now (prevents collisions) |
| TIMMY_PERSONALITY.md | Living personality doc (learns preferences over time) |
| CEO_TRACKER.md | Follow-ups, meetings, fundraising pipeline |
| CEO_WEEKLY.md | Weekly strategic synthesis |
| DECISION_JOURNAL.md | Decisions with expected outcomes (tracked for learning) |
| STAKEHOLDER_MAP.md | Key people and relationships |
| IMPROVE_PROPOSALS.md | Product improvement suggestions |

## Knowledge Graph

Flat-file knowledge system (no database required). Claude Code reads JSON and markdown natively.

```
knowledge/
  sources/        <- JSON per ingested source (PDFs, URLs, documents)
  entities/       <- JSON per entity (people, companies, protocols)
  graphs/         <- Relationship adjacency lists
  summaries/      <- Human-readable markdown (what workstreams actually read)
  watchlists/     <- RESEARCH persistent tracking targets
  trends/         <- Time-series data for trend analysis
```

## Heartbeat Schedule

| Task | Schedule | Agent | Method |
|------|----------|-------|--------|
| Health check | Every 4 hours | OPERATE | Bash script (Tier 1), Claude Code only if issues |
| Morning market scan | 8am UTC daily | RESEARCH | Claude Code + Scrapling |
| Evening market scan | 8pm UTC daily | RESEARCH | Claude Code + Scrapling |
| Daily ADVISOR brief | 6am UTC daily | ADVISOR | Claude Code (Opus) |
| Weekly security audit | Monday 3am UTC | SECURE | Claude Code + Scrapling |
| CEO weekly brief | Monday 7am UTC | CEO | Claude Code |
| IMPROVE product review | Wednesday 9am UTC | IMPROVE | Claude Code + Puppeteer |
| Dashboard regeneration | Every 60 seconds | None | Bash script (systemd timer) |

## Telegram Commands

Commander handles these directly without spawning a workstream:

| Command | Action |
|---------|--------|
| /status | Run health check, return results |
| /brief | Show latest ADVISOR brief |
| /intent add [text] | Add to intentions queue |
| /intent list | Show current intentions |
| /intent done [n] | Mark intention complete |
| /approve [n] | Approve ADVISOR proposal |
| /reject [n] | Reject ADVISOR proposal |
| /queue | Show pending tasks |
| /pause | Pause Heartbeat |
| /resume | Resume Heartbeat |

## Permission Model

### Fully Autonomous
- All non-contract code changes (frontend, scripts, configs)
- Git commits to feature branches
- Service restarts (active services only, max 2 attempts)
- Knowledge graph updates
- Scrapling web intelligence

### Requires Approval (via Telegram)
- Solidity contract changes
- deploy-env.sh or .env modifications
- CLAUDE.md file modifications
- System package installations

### Never Autonomous
- Smart contract deployment
- Private key access
- Database deletion
- Disabled service restarts (lever-loop, lever-qa, lever-seeder, lever-watchdog)
- Permission tier changes

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Gateway | OpenClaw 2026.3.24 |
| AI Sessions | Claude Code (Claude Max 20x subscription) |
| Models | Sonnet 4.6 (all workstreams), Opus 4.6 (ADVISOR only) |
| Skills | gstack (28 slash commands) |
| Web Scraping | Scrapling 0.4.2 + Playwright |
| Browser QA | Puppeteer + Chromium |
| Runtime | Bun 1.3.11 (gstack), Node.js 22 (OpenClaw), Python 3.12 (Scrapling) |
| Messaging | Telegram Bot API |
| Web Server | Caddy (reverse proxy) |
| Dashboard | Static HTML (auto-regenerated, served on port 8080) |
| Process Management | systemd |
| Scheduling | OpenClaw cron + system crontab |

## Personality

Vigil's personality is called Timmy. Timmy is direct, confident, and a smart-ass. He thinks like a founder, has opinions, and pushes back when something does not make sense. The personality is defined in `shared-brain/TIMMY_PERSONALITY.md` and evolves over time as Timmy learns user preferences through an observation log.

Every workstream follows Timmy's voice. Every workstream thinks like a teammate, not a tool.

## License

[Business Source License 1.1](LICENSE)

The Licensed Work is (c) 2026 Diiant Co., Ltd.
