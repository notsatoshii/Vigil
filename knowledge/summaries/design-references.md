# Design References
## Auto-generated summary from knowledge graph. Updated on new source ingestion.

## UX and Architecture References (Compiled from 26 RESEARCH scans, 2026-03-28/29)

### Prediction Market UX References
- **Euphoria (MegaETH)**: Tap-based trading for mainstream onboarding. Single gesture = position. Social layer (leaderboards, challenges). "Flappy Bird meets markets." Reference for casual user acquisition.
- **Limitless Exchange (Base)**: $500M+ volume, binary options-style, zero-day expiry. Simple UX drove 25x growth. Reference for how simplicity wins on Base.
- **Walbi**: No-code AI trading agents. Describe strategy in plain language, AI executes. Reference for AI-assisted position creation.
- **PredictQ**: Creator analytics with verified on-chain track records. Reference for transparency and creator tools.
- **Polymarket Maker Rebates**: Daily USDC payouts, proportional to maker volume. Reference for LP rewards display.

### LP Vault UX References
- **Hyperliquid HLP**: Active market-making vault, $380M TVL. Real-time PnL display. Gold standard for perps vault UX.
- **GMX GLP**: Passive LP counterparty vault. "Real yield" narrative. Simple deposit/earn model. Closest analog to LEVER's LeverVault.
- **Morpho Vaults (Base)**: Coinbase app integration drove 1,906% growth. Reference for how institutional-grade vaults can have simple consumer UX.

### Architecture References
- **Predik**: Graduation architecture (parimutuel -> AMM). Solves cold-start problem for new markets.
- **Azuro LiquidityTree**: Unified pool reducing fragmentation across markets (similar to LEVER's unified vault).
- **Inframarkets (Solana)**: Deterministic oracle resolution via proprietary IOS. Reference for oracle design.
- **functionSPACE**: "Oracle as a market" concept. Market-based resolution instead of UMA-style governance.

### Fee Model References
- **Polymarket**: Dynamic probability-based taker fees. Finance 50% maker rebate, others 25%. Geopolitics stays free.
- **Kalshi**: Institutional market makers (SIG) for tight spreads. Traditional exchange fee model.
- **LEVER**: Deterministic 50/30/20 split (LP/Protocol/Insurance). Shifts to 50/50/0 when IFR >= 20%.
