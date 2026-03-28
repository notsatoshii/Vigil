# Investor Research
## LEVER Protocol -- Key Narrative Points

### Market Opportunity (UPDATED 2026-03-28)

- **$21B+ monthly volume** across prediction markets (up from $1.2B in mid-2025; 17x growth in 8 months)
- **$100B+ notional volume** in 2025; January 2026 set all-time high of $17.2B monthly
- **Kalshi: $22B valuation** ($1B raise from Coatue, March 2026); **Polymarket: ~$20B valuation** (exploring raise)
- **5c(c) Capital**: first dedicated prediction market VC fund ($35M), backed by both Kalshi and Polymarket CEOs, Marc Andreessen, Ribbit Capital, ex-Multicoin. Focus: prediction market infrastructure (NOT exchanges). LEVER fits this thesis perfectly. First close within weeks.
- **268 projects tracked** globally (Prediction Index), but ZERO offer leveraged exposure. LEVER is the only leverage layer.
- **$105-210B addressable market** based on derivatives-to-spot ratios (5-10x on $21B monthly)
- Traditional derivatives offer 20-100x leverage across equities, commodities, currencies -- prediction markets have none
- DEX-to-CEX perps ratio tripled from 6.3% to 18.7%, validating on-chain derivatives demand
- 5 billion-dollar TradFi companies entered prediction markets in last 4 months (FanDuel, DraftKings, Fanatics, Crypto.com, Plus500)
- **Comp multiples**: Kalshi at 14-15x annualized revenue (~$1.5B)
- **Sector tailwinds**: CFTC supportive, ICE invested $2B in Polymarket, 73% of institutional market structure specialists expect prediction data valuable within 2 years (Coalition Greenwich)
- **Demand drivers**: Iran war (Day 28, $464.5M Polymarket geopolitics volume), 2026 midterm elections, geopolitical instability creating structural demand

### What LEVER Does

LEVER does not create new prediction markets. It amplifies existing ones by letting traders open 2-50x leveraged positions on probability movements while referencing established prices from Polymarket.

**Example:** A market trading at 55% probability. Trader opens 10x long with $1,000. If probability rises to 65%, the trader earns roughly $1,800 profit (180% ROI). If it falls to 45%, the position is liquidated.

### Three-Party Ecosystem

1. **Traders** get leveraged exposure to binary outcomes across technology, geopolitics, economics, sports, and finance
2. **Liquidity Providers** deposit USDT into a unified ERC-4626 vault, receive lvUSDT shares, and earn yield from borrow fees, transaction fees, liquidation fees, unmatched funding, and settlement fees
3. **Oracle Infrastructure** pulls real-time prices from Polymarket CLOB orderbooks with smoothing algorithms and multi-source validation

### Revenue Model

All protocol fees follow a deterministic 50/30/20 split:
- 50% to Liquidity Providers (immediate yield via RewardsDistributor)
- 30% to Protocol Treasury (development, operations, growth)
- 20% to Insurance Fund (bad debt protection)

When the insurance fund exceeds 20% of TVL, the split shifts to 50/50/0 (LP and Protocol only).

**LP yield sources:**
- Borrow fees: 2-50 bps/hour, scaling with leverage and time-to-expiration
- Transaction fees: 10 bps on opens/closes
- Liquidation fees: 100 bps on force-closures
- Unmatched funding: compensation for directional OI imbalances
- Settlement fees: 20 bps on resolution payouts
- Projected base yield: 175-400% APY from borrow fees alone (before trader PnL)

### Competitive Advantages

**vs. Ultramarkets (direct competitor, up to 10x):**
- 50x max leverage vs. Ultramarkets' 10x cap
- Continuous time-based risk curves vs. binary pre-resolution auto-close
- Unified ERC-4626 vault (institutional LP standard) vs. simpler LP model
- Oracle-based pricing (references Polymarket) vs. unknown oracle approach
- Deterministic, transparent 50/30/20 fee structure
- Ultramarkets has no disclosed funding; LEVER can move faster with capital

**vs. Limitless Exchange (adjacent, on Base, $10M seed from Coinbase Ventures/1confirmation):**
- Limitless is binary options-style with zero-day expiry; NOT leveraged perpetuals
- Largest prediction market on Base ($500M+ volume); potential integration target
- Risk: if Limitless adds leverage, they become direct competitor with Coinbase backing
- LEVER references external prices (Polymarket); Limitless creates its own markets

**vs. Traditional prediction markets (Polymarket, Kalshi):**
- 2-50x capital efficiency vs. 1x spot only
- Yield generation for LPs (175-400% APY) vs. no yield for liquidity providers
- Diversified market exposure through unified pool vs. per-market liquidity decisions

### Risk Management

- Time-based risk compression: leverage compresses from 30x to 1x as events approach resolution
- Borrow fee "ticking clock" forces positions toward full collateralization by settlement
- Four-tier OI limits: global (60% of TVL), per-market, per-side (70%), per-user (20%)
- Continuous liquidation with partial position support
- Insurance fund with 5% floor, 25% daily cap, and bad debt waterfall
- 48-hour withdrawal queue with utilization-based gates (max 80%)

### Roadmap

| Phase | Timeline | Milestones |
|-------|----------|-----------|
| Testnet | Q1 2026 | Base Sepolia deployment, 10 demo markets, automated oracle/liquidation bots |
| Mainnet Launch | Q2 2026 | Base mainnet, 50+ markets, institutional LP partnerships, $10-50M TVL target |
| Scale | Q3-Q4 2026 | Multi-chain expansion (Arbitrum, Polygon), 200+ markets, $100M+ TVL |
| Long-term | 2027+ | $1B+ TVL, cross-platform integration, institutional adoption as primary leverage provider |

### Technical Foundation

- 16 core smart contracts + 3 libraries on Base (Ethereum L2 by Coinbase)
- Solidity 0.8.24, OpenZeppelin v5.6.1, no proxy/upgrade pattern (immutable deployment)
- ERC-4626 vault standard for institutional LP integration
- Tranche ledger system preserving yield identity across transfers and AMM passage
