# Technical Landscape

## AI Model Landscape (Updated: 2026-03-28 20:00 UTC)

### GPT-5.4 Released March 5, 2026: Native Computer Use
OpenAI released GPT-5.4 on March 5 with first-class computer use capabilities (75% OSWorld success rate, vs 72.4% human baseline). 1M token context, Tool Search API for large toolsets, GPT-5.4 Pro for max compute. Tied #1 on AI Intelligence Index (57 pts) with Gemini 3.1 Pro. This is the direct competition to Claude Code's agentic capabilities.

### Claude Code March 2026 Feature Burst (v2.1.76)
New features this month: /loop command (recurring background task execution, cron-like), /voice push-to-talk (20 languages, spacebar hold), Computer Use preview for Pro/Max plans (point, click, navigate), 1M context standard, 64K default/128K max output, --bare flag for scripted calls, /effort with "ultrathink" for max compute. Known bug: rate limit drain reported March 26.
**Vigil implication**: /loop could replace some OpenClaw cron jobs. Computer Use could enable visual dashboard verification.

## AI Model Landscape (Scan: 2026-03-28)

### Breaking: Claude Mythos (Capybara) Leaked (March 26-27, 2026)
Anthropic accidentally revealed a new model tier ABOVE Opus called "Mythos" (internal codename: Capybara). Confirmed by Anthropic to Fortune. Key details:
- Dramatically outperforms Opus 4.6 on coding, reasoning, and cybersecurity benchmarks
- New fourth product tier (above Haiku/Sonnet/Opus), expected to be pricier
- Currently piloting with select customers for cybersecurity defense only
- No public release date or API pricing yet
- Leak caused cybersecurity stocks to sell off (model excels at finding vulnerabilities)
- **Vigil implication**: When available, Mythos could significantly upgrade our agent capabilities. Monitor API access closely.

### Current Model Leaderboard (March 2026)
| Model | Provider | Context | Notes |
|-------|----------|---------|-------|
| GPT-5.4 Pro | OpenAI | 1M tokens | Tied #1 on AI Intelligence Index (57 pts). Released March 5. |
| Gemini 3.1 Pro | Google | 1M tokens | Tied #1 on AI Intelligence Index (57 pts). |
| Claude Opus 4.6 | Anthropic | 1M tokens | Powers Vigil. 64K default output, 128K upper bound. |
| Llama 4 | Meta | varies | Best open-source; strong agentic capabilities. |
| Meta Avocado | Meta | TBD | Delayed from March to May+ 2026. May license Gemini. |

### Claude Code Updates (v2.1.76, March 2026)
- **/loop command**: Recurring task execution on intervals (lightweight cron)
- **/voice mode**: Push-to-talk with spacebar, 10+ new languages
- **Computer Use preview**: Point, click, navigate (Pro/Max plans)
- **1M token context window** now standard
- **Max output**: 64K default, 128K upper bound for Opus 4.6/Sonnet 4.6
- **Windows support**: PowerShell tool preview
- **Bug alert**: Users reporting rapid rate limit drain (March 26), suspected bug

### OpenAI Codex (March 27, 2026)
Broad release with first-class plugins, multi-agent workflows, file watching, remote websocket connections. Competing directly with Claude Code's agent capabilities.

---

## DeFi Security Landscape (Scan: 2026-03-28)

### Q1 2026: $137M Lost Across 15 Incidents
| Protocol | Loss | Attack Vector |
|----------|------|---------------|
| Step Finance | $27.3M | TBD |
| Truebit | $26.2M | TBD |
| Resolv Labs | $25M+ | Compromised AWS KMS key (infra, not code) |
| SwapNet | $13.4M | TBD |
| MakinaFi | $4.13M (1,299 ETH) | Smart contract exploit |
| FOOM Cash | $2.3M | Smart contract vulnerability ($1.8M recovered) |

### Dominant Attack Vectors (2026)
1. **Social engineering / key compromise** has replaced code exploits as #1 vector
2. **Access control** remains #1 by dollar losses ($953.2M in 2024)
3. **Oracle manipulation** is #2: $52M across 37 incidents in 2024
4. **AI-assisted attacks**: GPT-5.3-Codex exploited 72% of vulnerabilities autonomously

### LEVER-Specific Security Risks
- **Key management**: Keeper and oracle bot private keys are the Resolv-equivalent attack surface. Must use HSM or multi-sig.
- **Oracle manipulation**: OracleAdapter uses smoothing but needs circuit breaker for abnormal price movements.
- **Access control**: OpenZeppelin AccessControl with ADMIN/KEEPER/ORACLE/MARKET_MANAGER roles is the correct pattern. Verify completeness.
- **Reentrancy**: LeverVault and ExecutionEngine flows must be guarded.
- **AI exploit tooling**: 72% autonomous exploit rate means AI-assisted fuzzing is essential pre-mainnet.

## Oracle Infrastructure: Secondary Source Assessment (Scan: 2026-03-28)

### Kalshi API (RECOMMENDED secondary oracle)
- **REST API**: `trading-api.kalshi.com/trade-api/v2`, JWT auth
- **WebSocket**: Real-time streaming available
- **FIX protocol**: Also supported
- **Data**: Event metadata, market prices, orderbook, trades, multivariate combos
- **Recent**: Fractional trading (March 9 2026), order group WebSocket updates
- **Effort**: Low-Medium (similar integration pattern to Polymarket CLOB)

### Kalshi on Solana (via DFlow)
- Tokenized thousands of event contracts as SPL tokens (Dec 1, 2025)
- DFlow API: no API key needed for dev, JIT routing, $2M+ builder grants
- Available on Jupiter Exchange
- **EVM support announced "on the way"**: if Kalshi launches on Base, on-chain price feeds become possible

### Dual-Oracle Architecture for LEVER
| Source | Type | Auth | Real-Time | Status |
|--------|------|------|-----------|--------|
| Polymarket CLOB | Primary | Ed25519 | WebSocket (10 instruments) | Integrated |
| Kalshi API | Secondary | JWT | WebSocket available | **TO DO** |
| Kalshi EVM (Base) | Future | On-chain | Native | Monitor (no timeline) |

**Circuit breaker**: Cross-reference Polymarket and Kalshi prices. Trigger halt on >X% divergence between sources. This provides manipulation resistance (attacker must corrupt both platforms simultaneously).

---

## Anthropic Regulatory Status (Updated: 2026-04-02)
- **DOD designated Anthropic as "supply chain risk"** (March 3, 2026) after contract renegotiation breakdown over AI usage restrictions
- **Northern District of California** (Judge Lin, March 26): granted preliminary injunction blocking the designation. Takes effect April 2.
- **April 2 deadline passed**: No confirmed 9th Circuit emergency stay filing found in public reporting. If DOD missed the deadline, the preliminary injunction blocking the Anthropic ban is now IN EFFECT. Anthropic's restrictions on mass surveillance and lethal autonomous warfare remain intact. D.C. Circuit case (FASCSA § 4713) still pending separately.
- **D.C. Circuit**: Separate FASCSA (§4713) designation still pending. D.C. panel has not ruled yet.
- **Vigil impact**: Low direct risk. We use API, not a federal contract. But signals regulatory instability around our model provider. Monitor.

---

## Arbitrum: Multi-Chain Expansion Target (Ingested: 2026-03-30)

Arbitrum One (Chain ID 42161) is LEVER's Q3-Q4 2026 multi-chain expansion target per roadmap.
- **EVM-compatible**: LEVER's Solidity contracts deploy without modification
- **Optimistic rollup L2**: ~10x cost reduction vs Ethereum L1, sub-second blocks
- **L2 TVL share**: 30.86% (second to Base at 46.6%). Combined Base + Arbitrum = 77% of all L2 DeFi TVL.
- **Testnet**: Arbitrum Sepolia (Chain ID 421614), 0.02 Gwei base fee, same Foundry tooling
- **DeFi ecosystem**: GMX (perps, closest LEVER analog), Camelot, deeper than Base for derivatives
- **Deployment**: Same workflow as Base (Remix/Foundry -> Sepolia -> mainnet -> verify on Arbiscan)
- **No Coinbase advantage**: Unlike Base, Arbitrum lacks Coinbase app distribution. But has stronger existing DeFi/derivatives user base.

---

## Base DeFi Ecosystem: LP Partners & Integration Targets (Scan: 2026-03-28)

### Key Protocols on Base
| Protocol | TVL | Role for LEVER |
|----------|-----|----------------|
| **Morpho** | $2B+ (1,906% growth via Coinbase) | #1 integration target: lvUSDT as collateral in Morpho V2 lending market |
| **Aerodrome** (merging with Velodrome -> "Aero" Q2 2026) | Dominant Base DEX | lvUSDT/USDT pool for LP token liquidity |
| **Aave** | $27B total (multi-chain) | Long-term: lvUSDT collateral listing |
| **Limitless** | $500M+ volume | Largest prediction market on Base; potential oracle source |

### Integration Roadmap
1. **Launch**: LEVER on Base mainnet with LeverVault (ERC-4626)
2. **Morpho V2**: Propose lvUSDT lending market (LPs borrow against their vault positions)
3. **Aerodrome/Aero**: Create lvUSDT/USDT pool (secondary liquidity for LP exit)
4. **Coinbase App**: Target Coinbase integration for LeverVault deposits (the Morpho playbook: 1,906% growth)

### Institutional Signals
- Apollo Global: agreement for up to 90M MORPHO tokens over 48 months
- JPMorgan: $100M tokenized money market fund on Ethereum
- DeFi vault sector projected to exceed $15B TVL in 2026
- LEVER's ERC-4626 standard positions it perfectly for institutional adoption

---

## LEVER Protocol Architecture and Stack

### What LEVER Is

LEVER Protocol is a synthetic leveraged perpetuals platform built on top of prediction markets. It does not create new markets or run its own price discovery. Instead, it references external prediction market prices (primarily Polymarket) through an oracle pipeline and allows traders to open 2-50x leveraged long/short positions on binary outcomes (elections, sports, economics, geopolitics). A unified LP pool (LeverVault, ERC-4626) acts as counterparty to all trades.

### The 16-Contract Stack

LEVER is built from 16 core contracts plus 3 pure-math libraries, deployed in strict dependency order:

**Libraries (stateless, pure math):**
- FixedPointMath -- 18-decimal fixed-point arithmetic (WAD = 1e18), used by everything
- RiskCurves -- computes R(tau), R_borrow(tau), tau_effective, and all parameter mappings
- ProbabilityIndex -- PI validation, bounds checking, convergence helpers

**Core Contracts (in build-order phases):**

| Phase | Contract | Purpose |
|-------|----------|---------|
| 1 Foundation | OracleAdapter | Full price pipeline: P_raw -> validation -> smoothing -> PI output |
| 1 Foundation | MarketRegistry | Creates/manages markets, stores metadata, source of tau and is_live |
| 1 Foundation | AccountManager | User accounts, collateral deposits/withdrawals |
| 1 Foundation | PositionManager | Pure data store for all position state (no business logic) |
| 2 Risk | LeverageModel | Three-step leverage pipeline: Platform Ceiling -> R(tau) compression -> M_market adjustment |
| 2 Risk | OILimits | Four-tier OI cap system: global, per-market, per-side, per-user |
| 3 Execution | ExecutionEngine | Orchestrates position opens/closes, computes entry/exit via PI + linear impact model |
| 3 Execution | MarginEngine | IM, MM, equity calculation; pincer effect of rising MM + borrow erosion |
| 4 Fees | BorrowFeeEngine | Continuous fee on leveraged positions (1x exempt); the "ticking clock" |
| 4 Fees | FundingRateEngine | Trader-to-trader periodic payments; heavy side pays light side |
| 4 Fees | FeeRouter | Deterministic 50/30/20 split (LP/Protocol/Insurance) |
| 5 LP | LeverVault | ERC-4626 vault with tranche ledger; LP deposits USDT, receives lvUSDT |
| 5 LP | RewardsDistributor | LP yield distribution separate from vault NAV |
| 6 Safety | InsuranceFund | Bad debt absorption; funded by 20% of fees; daily cap 25%, IFR floor 5% |
| 6 Safety | LiquidationEngine | Force-closes positions when equity < MM; partial liquidation support |
| 7 Terminal | SettlementEngine | Binary resolution (PI snaps to 0 or 1); ADL and void handling |

### Key Design Principles

1. **PI is the single source of truth.** Every component uses the Probability Index for pricing. No secondary feeds.
2. **Unified LP pool.** One vault backs all markets. No per-market fragmentation.
3. **Continuous risk functions, not phase tables.** Everything is a smooth function of tau_effective (time to resolution).
4. **Two risk curves.** R(tau) with tau_ref=24h for mechanical constraints; R_borrow(tau) with tau_ref=168h for borrow fees.
5. **Leverage compresses to 1x at resolution.** Borrow fees force full collateralization by settlement.
6. **Deterministic fee split.** 50% LP / 30% Protocol / 20% Insurance (shifts to 50/50/0 when IFR >= 20%).
7. **Funding is separate from protocol fees.** Matched = trader-to-trader (zero-sum). Unmatched = trader-to-LP.
8. **No cross-margining.** Each position is independently margined.
9. **Immutable deployment.** No proxies in v1. If a fix is needed, redeploy the contract.
10. **Execution uses linear impact, not a vAMM.** Entry price = PI * (1 +/- impact), capped at 5%.

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Smart Contracts | Solidity 0.8.24, optimizer 200 runs |
| Dependencies | OpenZeppelin v5.6.1, solmate, forge-std |
| Chain | Base Sepolia (testnet, chain ID 84532); Base mainnet target |
| Tooling | Foundry (forge, cast, anvil) |
| Frontend | React (react-app-rewired), wagmi for wallet integration |
| Web Server | Caddy (reverse proxy + TLS) |
| Backend Services | Node.js v22, Python 3.12 |
| Oracle | Polymarket CLOB Midpoint API (primary), keeper bot for on-chain updates |
| Testing | Forge unit/fuzz tests, Playwright for SPA verification |
| Infrastructure | Ubuntu Linux, 16 GB RAM, systemd services |
| Access Control | OpenZeppelin AccessControl (roles: ADMIN, KEEPER, ORACLE, MARKET_MANAGER) |

### Key Constants

- BASE_BORROW_RATE: 0.02%/hour (2 bps)
- BASE_MAX_LEVERAGE: 30x
- TVL_MATURITY: $50M
- GLOBAL_OI_RATIO: 60% of TVL
- TX_FEE: 0.10% (10 bps)
- WITHDRAWAL_COOLDOWN: 48 hours
- MAX_IMPACT: 5%
- BASE_MM_RATE: 2.5% of notional
- INSURANCE_DAILY_CAP: 25% of insurance balance
- INSURANCE_FLOOR_IFR: 5% of TVL

### Data Flow Summary

External prediction markets (Polymarket, Kalshi) provide raw probabilities -> OracleAdapter validates, smooths, and outputs PI -> PI feeds into ExecutionEngine, MarginEngine, LiquidationEngine, FundingRateEngine, BorrowFeeEngine, SettlementEngine, and LeverageModel -> Fees flow through FeeRouter with 50/30/20 split -> LeverVault (LP), Protocol Treasury, and InsuranceFund receive their shares -> RewardsDistributor handles LP yield claims separately from vault NAV.

USDT moves between contracts only on discrete events (position open/close, deposit/withdrawal, fee routing). Continuous accrual is handled via index-based accounting that settles on state changes. NAV is tracked incrementally in O(1) per operation using per-market running notional totals.
