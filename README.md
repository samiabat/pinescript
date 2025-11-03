# Trading Strategies Repository

A collection of trading strategy implementations with Python backtesting and MetaTrader 5 Expert Advisors. This repository prioritizes **realistic** assessments with honest cost modeling.

## 📁 Repository Structure

```
pinescript/
├── README.md                    # This file - project overview
├── README_GOLD_SCALPER.md       # Gold scalper documentation
│
├── ict_trader.py                # ICT strategy (EURUSD 15min)
├── gold_scalper.py              # Gold scalper (XAUUSD 5min)
│
├── Gold_Scalper_EA.mq5          # MT5 EA for Gold scalping
│
├── EURUSD15.csv                 # Historical EURUSD 15-minute data
├── XAUUSD5.csv                  # Historical Gold 5-minute data
│
├── equity_fixed.png             # ICT strategy equity curve
├── gold_scalper_equity.png      # Gold scalper equity curve
│
└── docs/                        # ICT strategy documentation
    ├── README.md                # Documentation overview & quick start
    ├── CODE_REVIEW.md           # Detailed code analysis & realism assessment
    ├── ICT_Strategy_EA.mq5      # MetaTrader 5 Expert Advisor
    └── MT5_TESTING_GUIDE.md     # Complete MT5 testing guide
```

## 🎯 What's Included

### 1. ICT Trading Strategy (EURUSD)

A complete ICT (Inner Circle Trader) strategy implementation featuring:

- **Fair Value Gaps (FVG)** - Identifies price imbalances
- **Liquidity Sweeps** - Detects stop hunts and reversals  
- **Market Structure Shifts (MSS)** - Confirms trend changes
- **Higher Timeframe Bias** - Uses 1H trend filtering
- **Session-Based Trading** - Focuses on London & New York sessions
- **Risk Management** - Position sizing based on account balance

**Backtest Results** (on EURUSD 15-minute data):
- Total Trades: 1,986
- Win Rate: 59.3%
- Return: 513,418.8%
- Max Drawdown: 8.39%

⚠️ **Important**: These results are **unrealistic** for live trading. See [docs/CODE_REVIEW.md](docs/CODE_REVIEW.md) for detailed analysis.

**Files:**
- `ict_trader.py` - Python implementation
- `docs/ICT_Strategy_EA.mq5` - MetaTrader 5 EA
- `EURUSD15.csv` - Historical data
- `docs/` - Complete documentation

---

### 2. Gold Scalping Strategy (XAUUSD) ⭐ NEW!

A **realistic** scalping strategy for Gold with honest cost modeling.

**Strategy Features:**
- Momentum-based entries
- Tight profit targets ($10) and stop losses ($7)
- Proper risk management (1% per trade)
- Realistic costs: spread, slippage, commission

**Backtest Results** (on XAUUSD 5-minute data):
- **Initial Balance**: $10,000
- **Final Balance**: $4,959
- **Net P&L**: -$5,040 (-50.4%)
- **Total Trades**: 457
- **Win Rate**: 39.4%
- **Profit Factor**: 0.77

**⚠️ HONEST ASSESSMENT: This strategy LOSES MONEY**

This is **intentional** and **educational**. It demonstrates:
- Why scalping is difficult with realistic costs
- How spread/slippage/commission impact profitability  
- Why simple momentum strategies often fail
- The importance of honest backtesting

**Files:**
- `gold_scalper.py` - Python implementation
- `Gold_Scalper_EA.mq5` - MetaTrader 5 EA
- `XAUUSD5.csv` - Historical data (100,000 candles)
- `README_GOLD_SCALPER.md` - **Complete documentation** with lessons learned

**See [README_GOLD_SCALPER.md](README_GOLD_SCALPER.md) for:**
- Why the strategy loses money
- What it teaches about trading costs
- How to potentially make it profitable
- Detailed code explanation
- Educational insights

---

## 🚀 Quick Start

### Gold Scalper (Realistic Educational Example)

```bash
# Install dependencies
pip install pandas numpy matplotlib

# Run backtest
python gold_scalper.py

# View results
# - Console output with detailed metrics
# - gold_scalper_equity.png (equity curve)
# - Read README_GOLD_SCALPER.md for interpretation
```

### ICT Strategy (EURUSD)

```bash
# Install dependencies
pip install pandas numpy matplotlib

# Run backtest
python ict_trader.py

# View results
# - Console output with performance metrics
# - equity_fixed.png for equity curve
# - Read docs/CODE_REVIEW.md for realistic assessment
```

### MT5 Expert Advisors

**ICT Strategy EA:**
1. Copy `docs/ICT_Strategy_EA.mq5` to MT5's `MQL5/Experts` folder
2. Compile in MetaEditor
3. See [docs/MT5_TESTING_GUIDE.md](docs/MT5_TESTING_GUIDE.md) for testing

**Gold Scalper EA:**
1. Copy `Gold_Scalper_EA.mq5` to MT5's `MQL5/Experts` folder
2. Compile in MetaEditor
3. **WARNING**: This EA loses money - for educational use only!

---

## 📚 Documentation

### Gold Scalper (NEW!)
- **[README_GOLD_SCALPER.md](README_GOLD_SCALPER.md)** - Complete documentation
  - Why it loses money (realistic costs)
  - What it teaches about trading
  - How costs impact profitability
  - Lessons for traders

### ICT Strategy

#### [CODE_REVIEW.md](docs/CODE_REVIEW.md) - Strategy Analysis
- Detailed review of implementation
- Identification of flaws and issues
- Realism assessment of each component
- Critical issues requiring attention
- Recommendations for improvement
- Realistic performance expectations

#### [MT5_TESTING_GUIDE.md](docs/MT5_TESTING_GUIDE.md) - Complete Testing Guide
- Step-by-step backtesting in MT5
- Forward testing procedures (demo)
- Performance analysis methods
- Optimization techniques
- Troubleshooting common issues
- Transition to live trading checklist

#### [docs/README.md](docs/README.md) - Documentation Overview
- Quick start guide
- Parameter explanations
- Implementation workflow
- Pre-live trading checklist
- Common mistakes to avoid

---

## 🎯 Which Strategy Should You Use?

### For Learning About Realistic Trading Costs
→ **Gold Scalper** (`gold_scalper.py`)
- Shows honest, losing results
- Teaches why scalping is hard
- Demonstrates cost impact
- Best for education

### For Learning ICT Concepts
→ **ICT Strategy** (`ict_trader.py`)  
- Implements advanced concepts
- Shows impressive backtest (unrealistic)
- Read CODE_REVIEW.md to understand flaws
- Better for learning strategy development

### For Live Trading
→ **Neither one as-is!**
- Both need significant improvements
- Test extensively on demo first
- Expect much worse live results
- Consider these educational templates

---

## ⚠️ Important Warnings

### About the Gold Scalper

**This strategy INTENTIONALLY loses money** to teach important lessons:

1. **Realistic Costs Matter**
   - Spread, slippage, commission add up fast
   - $7.44 average cost per trade
   - With $10 profit target, costs are 74%!

2. **Why It's Educational**
   - Most strategies online show fake profits
   - This shows the truth about trading difficulty
   - Teaches you to be skeptical of backtests
   - Demonstrates proper cost modeling

3. **What You Learn**
   - How to code a trading strategy
   - How to model costs realistically
   - Why win rate matters for profitability
   - How to evaluate strategy performance

**Read [README_GOLD_SCALPER.md](README_GOLD_SCALPER.md) for complete analysis!**

### About the ICT Strategy

**Python Backtest Shows**: 513,418% return  
**Realistic Expectation**: 10-30% annually (if profitable)

**Python Backtest Shows**: 513,418% return  
**Realistic Expectation**: 10-30% annually (if profitable)

**Why the Difference?**
- Oversimplified cost modeling
- Perfect execution assumptions
- Potential curve-fitting to historical data
- Missing real-world trading frictions

**Read [CODE_REVIEW.md](docs/CODE_REVIEW.md) for full analysis.**

### Before Live Trading

✅ **Do This**:
- Test on demo for minimum 3 months
- Start with small position sizes (0.5% risk)
- Keep detailed trading journal
- Have emergency stop procedures
- Use only risk capital (money you can afford to lose)

❌ **Don't Do This**:
- Jump straight to live trading
- Expect backtest returns in live trading
- Risk more than 1-2% per trade
- Trade without understanding the code
- Ignore warning signs during drawdown

## 📊 Strategy Overview

### Core Concepts

1. **Fair Value Gap (FVG)**
   - Price gap between candles indicating imbalance
   - Entry zone when price returns to gap

2. **Liquidity Sweep**
   - Price briefly breaks high/low to grab liquidity
   - Followed by reversal (rejection)

3. **Market Structure Shift (MSS)**
   - Break of recent structure confirms trend change
   - Required before entry

4. **Session Filtering**
   - Only trade during London (7:00-16:00 UTC) and NY (12:00-21:00 UTC)
   - Avoids low liquidity periods

### Entry Logic

```
1. Detect Liquidity Sweep
2. Confirm Market Structure Shift
3. Identify Fair Value Gap in sweep direction
4. Optional: Check higher timeframe trend alignment
5. Enter at FVG with stop below/above sweep
6. Target 3:1 to 5:1 risk-reward ratio
```

### Risk Management

- **Position Sizing**: Based on % of account balance
- **Stop Loss**: Below/above liquidity sweep with buffer
- **Take Profit**: 3-5x stop loss distance
- **Daily Limits**: Max trades per day, max daily loss
- **Session Filter**: Only trade during liquid sessions

## 🔧 Configuration

### Key Parameters

#### Python (`ict_trader.py`)
```python
INITIAL_BALANCE = 200.0
RISK_PER_TRADE = 0.015        # 1.5%
MAX_TRADES_PER_DAY = 40       # ⚠️ DANGEROUS! For backtest only. Use 5-10 for live!
MIN_FVG_PIPS = 2.0
TARGET_MIN_R = 3.0
TARGET_MAX_R = 5.0
```

⚠️ **Warning**: The Python version has `MAX_TRADES_PER_DAY = 40` which is extremely high and unsuitable for live trading. This is for backtesting demonstration only. The MT5 EA uses a safer default of 10, but even this should be reduced to 5 or less for live trading.

#### MT5 EA (`ICT_Strategy_EA.mq5`)
```cpp
InpRiskPercent = 1.5          // Risk per trade %
InpMaxTradesPerDay = 10       // Max trades per day
InpMaxDailyLoss = 5.0         // Max daily loss %
InpMinFVGPips = 3.0           // Minimum FVG size
InpTargetMinR = 3.0           // Min R:R
InpTargetMaxR = 5.0           // Max R:R
InpFVGConfirmCandles = 1      // Wait candles after FVG
```

**Recommended for Live Trading**:
- Risk per trade: 0.5-1%
- Max trades per day: 3-5
- Max daily loss: 3-5%
- FVG confirmation: 1-2 candles

## 📈 Performance Analysis

### Python Backtest Metrics

| Metric | Value | Realistic? |
|--------|-------|------------|
| Total Trades | 1,986 | ⚠️ Too many |
| Win Rate | 59.3% | ⚠️ Optimistic |
| Avg R:R | 2.93:1 | ✅ Good |
| Total Return | 513,418% | ❌ Unrealistic |
| Max Drawdown | 8.39% | ❌ Too low |

### Realistic Expectations

| Metric | Live Trading |
|--------|--------------|
| Win Rate | 45-55% |
| Profit Factor | 1.5-2.5 |
| Annual Return | 10-30% |
| Max Drawdown | 15-25% |

**See [CODE_REVIEW.md](docs/CODE_REVIEW.md) for detailed analysis.**

## 📚 Documentation

All documentation is in the `docs/` folder:

### Must-Read Documents

1. **[docs/README.md](docs/README.md)** - Start here
   - Documentation overview
   - Quick start guide
   - Implementation workflow
   - Pre-live trading checklist

2. **[docs/CODE_REVIEW.md](docs/CODE_REVIEW.md)** - Critical reading
   - Detailed code analysis
   - Identification of flaws
   - Realistic vs unrealistic assessment
   - Recommendations for improvement

3. **[docs/MT5_TESTING_GUIDE.md](docs/MT5_TESTING_GUIDE.md)** - Essential for MT5
   - Complete backtesting guide
   - Forward testing procedures
   - Optimization techniques
   - Troubleshooting

### Additional Files

4. **[docs/ICT_Strategy_EA.mq5](docs/ICT_Strategy_EA.mq5)** - MT5 Expert Advisor
   - Production-ready MQL5 code
   - Copy to MT5 Experts folder
   - Compile and use per guide

## 🛠️ Development Setup

### Python Environment

```bash
# Create virtual environment (optional)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install pandas numpy matplotlib

# Run backtest
python ict_trader.py
```

### MT5 Development

1. Install MetaTrader 5
2. Open MetaEditor (F4 in MT5)
3. Copy EA file to MQL5/Experts folder
4. Compile in MetaEditor
5. Use Strategy Tester for backtesting

## 🤝 Contributing

This is an educational project. Contributions welcome:

- Bug fixes
- Performance improvements
- Documentation enhancements
- Additional risk controls
- Testing on different instruments

**Please**:
- Test changes thoroughly
- Update documentation
- Follow existing code style
- Don't optimize for backtest returns

## 📖 Learning Resources

### ICT Concepts
- YouTube: Search "Inner Circle Trader" for original lessons
- Focus on: Fair Value Gaps, Order Blocks, Liquidity concepts

### MT5/MQL5
- Official Documentation: https://www.mql5.com/en/docs
- Forum: https://www.mql5.com/en/forum
- Articles: https://www.mql5.com/en/articles

### Trading & Risk Management
- "Trading in the Zone" - Mark Douglas
- "Trade Your Way to Financial Freedom" - Van K. Tharp
- "The New Trading for a Living" - Dr. Alexander Elder

## ⚖️ Disclaimer

**IMPORTANT RISK DISCLOSURE**

- Trading involves substantial risk of loss
- Past performance does not guarantee future results
- The backtest results shown are **NOT** representative of live trading
- You could lose all of your invested capital
- This is **NOT** financial advice
- Consult a licensed financial advisor before trading
- Use at your own risk

**CODE PROVIDED "AS IS" WITHOUT WARRANTY**

By using this code, you:
- Accept full responsibility for your trading decisions
- Understand the risks involved
- Will test thoroughly before live trading
- Will only trade with risk capital (money you can afford to lose)

## 📞 Support

### Technical Issues
- Check [MT5_TESTING_GUIDE.md](docs/MT5_TESTING_GUIDE.md) troubleshooting section
- MT5 Forum: https://www.mql5.com/en/forum
- Broker support for account/platform issues

### Strategy Questions
- Review [CODE_REVIEW.md](docs/CODE_REVIEW.md)
- Study original ICT materials
- Community forums (use caution with advice)

## 📝 Version History

### v1.0 - Initial Release
- Python ICT strategy implementation
- MT5 Expert Advisor
- Comprehensive documentation
- Code review and analysis
- Complete testing guides

## 🏁 Next Steps

1. **Understand the Strategy**
   - Read [docs/CODE_REVIEW.md](docs/CODE_REVIEW.md)
   - Study the Python implementation
   - Learn ICT concepts

2. **Backtest in MT5**
   - Follow [docs/MT5_TESTING_GUIDE.md](docs/MT5_TESTING_GUIDE.md)
   - Run with conservative parameters
   - Analyze results critically

3. **Forward Test on Demo**
   - Minimum 3 months
   - Keep detailed records
   - Compare with backtest

4. **Evaluate Results**
   - Use checklist in docs/README.md
   - Be honest about performance
   - Decide: continue, adjust, or abandon

5. **Live Trading** (only if demo successful)
   - Start small (micro account)
   - 0.5% risk per trade
   - Scale gradually
   - Monitor closely

**Remember**: The goal is sustainable profitability, not getting rich quick.

**Trade safe, test thoroughly, and protect your capital! 🚀📈**

---

*For detailed documentation, see the [docs/](docs/) folder.*

*For questions about realism and expected performance, read [CODE_REVIEW.md](docs/CODE_REVIEW.md) first.*
