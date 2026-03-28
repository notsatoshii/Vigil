# PROJECT STATE
## Last Updated: March 28, 2026
## Updated By: Initial seed (Timmy, Phase 0 migration)

---

## LEVER Protocol
- **Status**: Testnet (Base Sepolia)
- **Chain**: Base Sepolia (testnet), targeting Base (mainnet)
- **Contracts**: 16 contracts + 3 libraries deployed. All core contracts verified and working.
- **Recent**: Redeployed LeverVault, ExecutionEngine, SettlementEngine, LiquidationEngine on March 20, 2026 to fix constructor arg and vault pointer issues.
- **Frontend**: React app on port 3000, served via Caddy on port 80
- **Demo mode**: ON by default. 4 demo positions active (SpaceX, US-Iran, FIFA, Fed Rate)
- **TVL**: $502K | **OI**: $4.3K | **Utilization**: 0.86% | **Share Price**: $1.000007
- **Known frontend bugs**: Funding shows $0.00 (getFundingIndex reverts), generic error toasts, high gas on openPosition (~980K)
- **Protected contracts**: ExecutionEngine, LeverageModel, LeverVault, PositionManager, SettlementEngine, LiquidationEngine (do NOT redeploy)

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
- **Status**: Phase 0 (foundation). Directory structure created. Brain files seeded.
- **Server**: Timmy-OpenClaw-16gb (16 GB RAM, 4 cores, 193 GB disk)
- **Dependencies needed**: OpenClaw, Bun, gstack, Scrapling
- **Architecture**: 7 workstreams, OpenClaw gateway, shared brain, heartbeat scheduler

## Infrastructure
- **Server**: 15 GB RAM (6 GB used, 9.6 GB available), 193 GB disk (16% used), 4 cores
- **Active services**: lever-frontend, lever-dashboard, lever-bot, lever-oracle, lever-accrue-keeper
- **Disabled services** (sacred): lever-loop, lever-qa, lever-seeder, lever-watchdog
- **Also disabled**: lever-fee-keeper (FeeRouter has no distributeFees)
- **Web server**: Caddy (port 80 proxying to :3000)
- **Local EVM**: Anvil on port 8545
- **Cron**: Hourly git backup, 30-min agent check, 30-min oracle price update
