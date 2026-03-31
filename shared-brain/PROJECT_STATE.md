# PROJECT STATE
## Last Updated: March 31, 2026
## Updated By: ADVISOR daily brief

---

## SERVER FILE MAP

All projects and key directories on this server:

| Path | What It Is | Port | Notes |
|------|-----------|------|-------|
| /home/lever/Lever/ | LEVER Protocol (active repo) | n/a | Contracts, tests, frontend, docs. github.com/notsatoshii/Lever |
| /home/lever/Lever/frontend/user-app/ | LEVER trading frontend (React) | 3000 | Served via Caddy on port 80 |
| /home/lever/Lever/contracts/ | Solidity contracts (16 + 3 libs) | n/a | All deployed on Base Sepolia |
| /home/lever/Lever/test/ | Foundry tests (39 files, 864 tests) | n/a | `forge test` to run |
| /home/lever/Lever/scripts/oracle/ | Oracle keeper scripts (Python) | n/a | mock_keeper.py, polymarket_client.py |
| /home/lever/Lever/docs/ | Protocol documentation (11 files) | n/a | Architecture, formulas, contracts, deployment |
| /home/claude/lever-landing/ | XMarket/LEVER landing page | 3001 | Static HTML, served via `npx serve` |
| /home/lever/command/ | Vigil system (this system) | n/a | github.com/notsatoshii/Vigil |
| /home/lever/command/dashboard/ | Vigil dashboard | 8080 | Auto-regenerated every 60s |
| /home/lever/lever-protocol/ | Legacy LEVER repo (DEPRECATED) | n/a | github.com/notsatoshii/Timmy. Do NOT use for new work |
| /home/lever/local-libs/ | Chrome/Chromium binaries | n/a | For Puppeteer/browser testing |
| /home/lever/screenshots/ | QA screenshots (historical) | n/a | From previous QA cycles |
| /home/lever/temp-build/ | Old frontend build artifact | n/a | Can be cleaned up |

## LEVER Protocol
- **Status**: Testnet (Base Sepolia)
- **Repo**: github.com/notsatoshii/Lever (public, BUSL-1.1 license)
- **Local path**: /home/lever/Lever/
- **Legacy repo**: github.com/notsatoshii/Timmy (deprecated, do not use for new work)
- **Chain**: Base Sepolia (testnet), targeting Base (mainnet)
- **Contracts**: 16 contracts + 3 libraries deployed. All core contracts verified and working.
- **Recent**: Redeployed LeverVault, ExecutionEngine, SettlementEngine, LiquidationEngine on March 20, 2026 to fix constructor arg and vault pointer issues.
- **Frontend**: React app at /home/lever/Lever/frontend/user-app/, port 3000, served via Caddy on port 80
- **Demo mode**: ON by default. 4 demo positions active (SpaceX, US-Iran, FIFA, Fed Rate)
- **TVL**: $502K | **OI**: $4.3K | **Utilization**: 0.86% | **Share Price**: $1.000007
- **Known frontend bugs**: Funding shows $0.00 (getFundingIndex reverts), generic error toasts, high gas on openPosition (~980K)
- **BLOCKED**: Keeper wallet empty since March 23 (Day 8). Oracle and accrual stalled. EXECUTION_ENGINE_ROLE grant pending.
- **Protected contracts**: ExecutionEngine, LeverageModel, LeverVault, PositionManager, SettlementEngine, LiquidationEngine (do NOT redeploy)

## Landing Page
- **Status**: Live, being improved
- **Local path**: /home/claude/lever-landing/
- **Port**: 3001 (served via `npx serve`)
- **Spec**: /home/claude/lever-landing/LEVER_Landing_Page_Spec_v3.md
- **Build plan**: /home/claude/lever-landing/LEVER_Landing_Page_Build_Plan.md
- **Design guidelines**: /home/claude/lever-landing/Lever_Guideline.pdf
- **Public URL**: landing.xmarket.app

## XMarket
- **Status**: Live on BNB Chain
- **Tagline**: "Create Markets. Earn From Them."
- **Links**: xmarket.app, landing.xmarket.app, @Xmarketapp, t.me/xMarketCommunity
- **Growth needed**: ~600-840x volume growth to cover burn rate
- **Marketing**: Airaa KOL campaign active, user metrics via Posthog

## Fundraising
- LEVER base case approaches breakeven by month 18, bull case profitability by month 5-6
- "Pump.fun for Prediction Markets" is internal shorthand only, NEVER for public use

## Vigil
- **Status**: Operational. All 8 workstreams configured. Gateway live. Heartbeat active.
- **Repo**: github.com/notsatoshii/Vigil (private)
- **Local path**: /home/lever/command/
- **Server**: Timmy-OpenClaw-16gb (16 GB RAM, 4 cores, 193 GB disk)
- **Gateway**: OpenClaw 2026.3.24 on port 18789
- **Telegram**: @LeverPM_bot, paired to Master (user ID 422985839)
- **Agents**: 9 (Commander + BUILD, VERIFY, SECURE, RESEARCH, OPERATE, CEO, ADVISOR, IMPROVE)
- **Models**: Sonnet 4.6 (all workstreams), Opus 4.6 (ADVISOR only)
- **Max concurrent sessions**: 5

## Infrastructure
- **Server**: 15 GB RAM, 193 GB disk (19% used), 4 cores, no swap
- **Active services**: lever-frontend (:3000), lever-oracle, lever-accrue-keeper, openclaw-gateway (:18789), vigil-dashboard (:8080)
- **Disabled services** (SACRED, never restart): lever-loop, lever-qa, lever-seeder, lever-watchdog
- **Also disabled**: lever-fee-keeper (FeeRouter has no distributeFees), lever-bot (replaced by OpenClaw)
- **Web server**: Caddy (port 80 proxying to :3000)
- **Local EVM**: Anvil on port 8545
- **Landing page**: npx serve on port 3001
- **Backup crons**: Lever repo (:30), Vigil repo (:45), legacy Timmy repo (:00)
- **Health check**: Every 4 hours (bash script)
- **Oracle prices**: Updated every 30 minutes

## Active tmux Sessions
- **landing**: Claude Code working on landing page improvements
- **FE**: Frontend development
- **lever**: Main development session
- Others (build, lever6, overnight, redeploy, NEW): Likely stale, can be cleaned up
