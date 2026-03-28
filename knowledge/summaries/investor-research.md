# Investor Research
## LEVER Protocol -- Key Narrative Points

### Market Opportunity

- **$13B monthly spot volume** across prediction markets (Polymarket, Kalshi, PredictIt)
- **$65-130B addressable market** based on traditional derivatives-to-spot ratios (5-10x multiplier)
- Prediction markets are the only liquid trading vertical with zero leverage infrastructure
- Traditional derivatives offer 20-100x leverage across equities, commodities, currencies -- prediction markets have none
- Fastest-growing DeFi segment with institutional adoption accelerating

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

**vs. Ultramarkets (direct competitor):**
- Unified liquidity pool (single vault for all markets) vs. per-market fragmented pools
- Oracle-based pricing (references Polymarket) vs. bootstrapping new orderbooks
- Continuous time-based risk curves vs. static risk parameters
- Deterministic, transparent fee structure

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
