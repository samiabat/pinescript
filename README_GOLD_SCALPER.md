# Gold (XAUUSD) Scalping Strategy - Complete Documentation

## 📌 Overview

This is a **realistic** scalping strategy for trading Gold (XAUUSD) on 5-minute charts. Unlike many backtest-optimized strategies, this implementation prioritizes **honest** results by including realistic trading costs.

## ⚠️ IMPORTANT: Why This Strategy Loses Money

### Backtest Results Summary

- **Initial Balance**: $10,000
- **Final Balance**: $4,959.51
- **Net P&L**: -$5,040.49 (-50.4%)
- **Total Trades**: 457
- **Win Rate**: 39.4%
- **Profit Factor**: 0.77
- **Max Drawdown**: 52.52%

### The Truth About Scalping Gold

**This strategy is INTENTIONALLY realistic and demonstrates why scalping is difficult:**

1. **Realistic Costs Matter**
   - Spread: $0.40 per unit (conservative for gold)
   - Slippage: $0.25 per trade
   - Commission: $7 per lot
   - **Average cost per trade: $7.44**
   
   For a strategy targeting $10 profit with $7 stop loss, costs represent **74% of the profit target**!

2. **Why the Strategy Loses**
   - Win rate (39.4%) is below breakeven point given the costs
   - Average win ($95.34) vs Average loss ($80.15) - not enough edge
   - High trading frequency (457 trades) accumulates costs
   - Gold's volatility makes tight scalping difficult

3. **What Would Be Needed to Be Profitable**
   - Win rate >55% with current parameters
   - OR wider profit targets (less scalping, more swing)
   - OR dramatically lower costs (institutional pricing)
   - OR better entry/exit logic (machine learning, order flow, etc.)

## 📊 Strategy Logic

### Entry Conditions

**Long Entry:**
- 2+ consecutive bullish candles (momentum)
- Price above 20-period SMA (trend filter)
- Current candle body > $0.80 (avoid noise)
- Strong candle (body ratio > 60% of total range)

**Short Entry:**
- 2+ consecutive bearish candles (momentum)
- Price below 20-period SMA (trend filter)
- Current candle body > $0.80 (avoid noise)
- Strong candle (body ratio > 60% of total range)

### Exit Conditions

- **Take Profit**: +$10.00 from entry
- **Stop Loss**: -$7.00 from entry
- **Risk/Reward**: 1.43:1

### Risk Management

- **Risk per Trade**: 1% of account balance
- **Max Trades per Day**: 4
- **Max Daily Loss**: 3% of account
- **Trading Hours**: 08:00 - 19:00 UTC (London + NY sessions)

## 💻 Running the Backtest

### Prerequisites

```bash
pip install pandas numpy matplotlib
```

### Run Backtest

```bash
python gold_scalper.py
```

### Output

The script will:
1. Load XAUUSD5.csv data (100,000 candles)
2. Run the backtest with progress updates
3. Print detailed results
4. Generate equity curve: `gold_scalper_equity.png`

## 📈 Results Interpretation

### What the Results Tell Us

#### ✓ Good Aspects
- **Realistic modeling** - No curve-fitting or optimization
- **Honest cost accounting** - Spread, slippage, commission all included
- **Proper risk management** - Position sizing, daily limits
- **Conservative parameters** - 1% risk per trade

#### ✗ Why It Doesn't Work
- **Cost drag** - $3,402 in costs on 457 trades
- **Win rate too low** - 39.4% not enough to overcome costs
- **Market conditions** - Simple momentum doesn't provide edge in gold
- **Scalping difficulty** - Frequent trading amplifies cost impact

### Key Metrics Explained

| Metric | Value | What It Means |
|--------|-------|---------------|
| Win Rate | 39.4% | Only 4 out of 10 trades win |
| Profit Factor | 0.77 | Loses $1 for every $0.77 won |
| Avg Win/Loss | $95/$80 | Wins slightly bigger than losses |
| Total Costs | $3,402 | 68% of gross losses! |
| Max Drawdown | 52.5% | Lost half the account |

## 🔧 Parameters

### Configurable Settings

```python
# Risk Management
RISK_PER_TRADE = 0.01       # 1% per trade
MAX_TRADES_PER_DAY = 4      # Maximum 4 trades daily
MAX_DAILY_LOSS = 0.03       # Stop at 3% daily loss

# Entry
MOMENTUM_CANDLES = 2        # Consecutive candles needed
MIN_CANDLE_BODY = 0.80      # Minimum candle body ($)
REQUIRE_STRONG_CANDLE = True

# Exit
PROFIT_TARGET_DOLLARS = 10.0
STOP_LOSS_DOLLARS = 7.0

# Costs
SPREAD_DOLLARS = 0.40
SLIPPAGE_DOLLARS = 0.25
COMMISSION_PER_LOT = 7.0
```

## 🚫 NOT RECOMMENDED FOR LIVE TRADING

**This strategy is provided for EDUCATIONAL purposes to demonstrate:**

1. ✓ How to build a trading strategy properly
2. ✓ How to include realistic costs
3. ✓ How to implement proper risk management
4. ✓ Why backtesting needs to be honest
5. ✗ Why most scalping strategies fail in live trading

## 💡 Lessons Learned

### For Aspiring Traders

1. **Costs Matter More Than You Think**
   - Spread, slippage, commission can kill profitability
   - Scalping amplifies cost impact
   - Always model costs realistically

2. **Win Rate Needs to Match Your R:R**
   - With 1.43:1 R:R, need >55% win rate to break even
   - This strategy only achieves 39.4%
   - Either improve win rate OR increase R:R

3. **Simple Strategies Often Don't Work**
   - Basic momentum/MA crossover is not enough
   - Markets are competitive - need real edge
   - Consider: order flow, market microstructure, machine learning

4. **Gold Characteristics**
   - High volatility makes scalping difficult
   - Wide spreads eat into profits
   - Better suited for swing trading or longer timeframes

### If You Want to Make This Profitable

**Option 1: Reduce Trading Frequency**
- Change to swing trading (4H/Daily charts)
- Wider targets ($50+) and stops ($30+)
- Costs become smaller % of profit

**Option 2: Improve Win Rate**
- Add volume analysis
- Use order flow data
- Implement machine learning
- Add more sophisticated filters

**Option 3: Lower Costs**
- Use ECN broker with tight spreads
- Trade larger size to reduce per-unit commission
- Avoid peak volatility times (wide spreads)

**Option 4: Different Market/Timeframe**
- Try different instruments (EUR/USD has tighter spreads)
- Higher timeframes (H1, H4, Daily)
- Different session (Asian session less volatile)

## 📚 Files in This Project

- `gold_scalper.py` - Main Python backtest script
- `XAUUSD5.csv` - Historical 5-minute gold data
- `gold_scalper_equity.png` - Equity curve chart
- `README_GOLD_SCALPER.md` - This documentation
- `Gold_Scalper_EA.mq5` - MetaTrader 5 Expert Advisor (if created)

## 🔍 Code Structure

### Main Components

1. **Configuration** - All parameters in one place
2. **Data Loading** - CSV import and indicator calculation
3. **Entry Logic** - Momentum-based signal detection
4. **Exit Logic** - Stop loss and take profit management
5. **Position Sizing** - Risk-based lot calculation
6. **Cost Modeling** - Spread, slippage, commission
7. **Backtester** - Main simulation loop
8. **Results Analysis** - Metrics calculation and reporting
9. **Visualization** - Equity curve plotting

### Key Functions

```python
calculate_position_size(balance, stop_dollars)
  └─ Returns position size based on 1% risk

check_momentum_entry(df, idx)
  └─ Detects entry signals

check_exit(trade, candle)
  └─ Checks if trade should close

calculate_costs(position_lots)
  └─ Computes total trading costs
```

## 📖 Understanding the Output

### During Backtest

```
Progress: 0% | Balance: $10,000.00 | Trades: 0
Progress: 10% | Balance: $8,438.52 | Trades: 105
...
```

Shows:
- Progress through data
- Current account balance
- Number of trades executed

### Results Section

#### Account Performance
- Shows P&L, return %, drawdown

#### Trade Statistics
- Win rate, profit factor, avg win/loss
- Most important metrics for evaluating strategy

#### Exit Breakdown
- How trades closed (TP vs SL)
- Helps understand strategy behavior

#### Costs
- Total costs paid
- Impact on profitability

#### Realistic Assessment
- Automated evaluation
- Recommendations

## 🎯 Next Steps

### If You Want to Use This Code

1. **Study the Implementation**
   - Understand each component
   - Learn proper backtesting techniques
   - See how costs are modeled

2. **Experiment with Parameters**
   - Try different timeframes
   - Adjust profit/loss targets
   - Test various entry filters

3. **Develop Your Own Strategy**
   - Use this as a template
   - Add your own logic
   - Always include realistic costs!

4. **Forward Test on Demo**
   - If you find profitable parameters
   - Test on demo account for 3+ months
   - Compare demo vs backtest results

5. **Never Skip Demo Testing**
   - Backtest ≠ Live trading
   - Slippage, requotes, spread widening
   - Psychological factors

## 🛡️ Risk Warnings

### ⚠️ CRITICAL DISCLAIMERS ⚠️

- **This strategy LOSES MONEY** in backtest
- **Past performance ≠ Future results**
- **Backtests are NOT representative of live trading**
- **Trading involves substantial risk of loss**
- **Only trade with money you can afford to lose**
- **This is NOT financial advice**
- **Consult a licensed advisor before trading**

### Why Backtest Results Don't Guarantee Live Profits

1. **Market Conditions Change**
   - What worked historically may not work now
   - Markets adapt and evolve

2. **Execution Differences**
   - Real slippage varies
   - Spreads widen during news/volatility
   - Requotes and rejections happen

3. **Psychological Factors**
   - Emotions affect decisions
   - Discipline harder than you think
   - FOMO and fear are real

4. **Unknown Unknowns**
   - Black swan events
   - Broker issues
   - Technology failures

## 📞 Support and Resources

### Learning Resources

- **Trading Costs**: Research spread, slippage, commission for your broker
- **Position Sizing**: Study Van Tharp's work on risk management
- **Market Microstructure**: Understand how markets actually work
- **Order Flow**: Learn about institutional trading

### Tools and Platforms

- **Python**: pandas, numpy, matplotlib for backtesting
- **MetaTrader 5**: For live/demo trading
- **TradingView**: For chart analysis
- **Broker Demo**: Always test before going live

## 🎓 What This Project Teaches

### Technical Skills

✓ Python programming for trading
✓ Data analysis with pandas
✓ Backtesting methodology
✓ Risk management implementation
✓ Cost modeling
✓ Performance metrics calculation

### Trading Concepts

✓ Realistic expectations
✓ Cost impact on profitability
✓ Win rate vs risk/reward relationship
✓ Position sizing
✓ Strategy evaluation
✓ Why most retail traders lose

## 📝 Version History

### v1.0 - Initial Release
- Basic momentum scalping strategy
- Realistic cost modeling
- Comprehensive documentation
- Educational focus on why scalping is hard

## 🙏 Acknowledgments

This project demonstrates **honest backtesting** - showing a losing strategy to educate traders about:
- The importance of realistic cost modeling
- Why scalping is difficult
- What it takes to be profitable
- The need for thorough testing

Most online strategies show unrealistic profits. This project takes the opposite approach: show the truth about trading difficulty.

---

## 🏁 Final Thoughts

If you found this code useful for learning, that's great! If you're disappointed it doesn't make money, that's the point - **most simple strategies don't**.

Real profitable trading requires:
- Deep market understanding
- Significant edge (hard to find)
- Excellent execution
- Strong psychology
- Lots of capital (to handle costs)
- Years of experience

Or you can:
- Invest in index funds
- Focus on your day job
- Treat trading as entertainment, not income

**There are no shortcuts to consistent profitability.**

Good luck, trade safe, and always test on demo first! 🚀

---

*"The market is a device for transferring money from the impatient to the patient." - Warren Buffett*

*"In trading, the objective is not to be right, but to make money." - Unknown*

*"The goal of a successful trader is to make the best trades. Money is secondary." - Alexander Elder*

