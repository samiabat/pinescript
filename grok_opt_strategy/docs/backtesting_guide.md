# MT5 Backtesting Guide - Grok Optimized Strategy

## Overview

This guide provides a comprehensive, step-by-step process for backtesting the Grok Optimized trading strategy in MetaTrader 5. Backtesting allows you to validate strategy performance using historical data before risking real capital.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Understanding Backtesting](#understanding-backtesting)
3. [Step-by-Step Backtesting Process](#step-by-step-backtesting-process)
4. [Analyzing Results](#analyzing-results)
5. [Optimization](#optimization)
6. [Best Practices](#best-practices)
7. [Common Issues](#common-issues)

## Prerequisites

### Required Setup

- ✅ MetaTrader 5 installed
- ✅ GrokOptEA.mq5 compiled and available
- ✅ Historical data downloaded for testing symbols
- ✅ Basic understanding of trading concepts

### Download Historical Data

Before backtesting, ensure you have sufficient historical data:

1. Open MT5
2. Click **Tools** → **Options** → **Charts**
3. Set "Max bars in chart" to at least 100,000
4. Click **OK**
5. Open a chart for your test symbol (e.g., EURUSD)
6. Scroll back to load historical data
7. MT5 will automatically download missing data

Alternatively, download data through Strategy Tester:
1. Open Strategy Tester (Ctrl+R)
2. Select symbol and period
3. Check "Use date" and set wide date range
4. Click "Download" if data is missing

## Understanding Backtesting

### What is Backtesting?

Backtesting simulates trading strategy execution on historical market data to evaluate:
- **Performance**: Win rate, profit factor, drawdown
- **Reliability**: Consistency across different periods
- **Risk**: Maximum drawdown and risk exposure
- **Optimization**: Best parameter settings

### Types of Backtests in MT5

1. **Every tick** (Most accurate, slowest)
   - Uses all available tick data
   - Best for final validation
   - Recommended for live trading preparation

2. **1 minute OHLC** (Good balance)
   - Uses 1-minute bars
   - Faster than every tick
   - Good for initial testing

3. **Open prices only** (Fast, less accurate)
   - Uses only bar open prices
   - Quick parameter screening
   - Not recommended for final validation

### Modeling Quality

- **90%+**: Excellent data quality
- **70-89%**: Good data quality
- **Below 70%**: Poor data, consider re-downloading

## Step-by-Step Backtesting Process

### Step 1: Open Strategy Tester

1. In MT5, click **View** → **Strategy Tester**
   - Or press **Ctrl+R**
   - Or click the Strategy Tester icon in toolbar

The Strategy Tester window opens at the bottom of the screen.

### Step 2: Configure Test Settings

#### Settings Tab

**Expert Advisor**
- Select: `GrokOptEA`

**Symbol**
- Choose your trading pair (e.g., EURUSD, GBPUSD)
- Recommendation: Start with major pairs (better data quality)

**Period**
- Select timeframe: M15, M30, H1, H4, or D1
- Should match your trading strategy timeframe
- Recommendation: H1 for day trading, H4 for swing trading

**Date Range**
- Check "Use date"
- Start date: At least 1 year back recommended
- End date: Recent date (or current)
- Longer period = more reliable results
- Recommendation: Test at least 1-2 years

**Deposit**
- Initial deposit amount (e.g., 10,000)
- Should match your intended trading capital
- Affects position sizing if using percentage-based risk

**Leverage**
- Set to match your actual trading account
- Common values: 1:100, 1:200, 1:500
- Higher leverage = higher risk

**Execution**
- Select: **Every tick based on real ticks** (most accurate)
- Alternative: **1 minute OHLC** (faster, less accurate)

**Optimization**
- Leave unchecked for single backtest
- Check for parameter optimization (explained later)

### Step 3: Configure EA Parameters

Click the **Inputs** tab to adjust Expert Advisor parameters:

#### Recommended Test Parameters

```
Trading Parameters:
- RiskPercent: 2.0 (conservative)
- StopLossPips: 50
- TakeProfitPips: 100
- LotSize: 0.0 (automatic calculation)

Strategy Parameters:
- FastMA: 10
- SlowMA: 20
- RSI_Period: 14
- RSI_Oversold: 30
- RSI_Overbought: 70

Trading Hours:
- StartHour: 0
- EndHour: 23
- Trade all weekdays: true

Risk Management:
- MaxDailyLoss: 100.0
- MaxDailyProfit: 200.0
- MaxOpenTrades: 1

General Settings:
- MagicNumber: 123456
- TradeComment: "BacktestGrokOpt"
- EnableLogging: true
```

### Step 4: Start Backtest

1. Review all settings
2. Click the **Start** button
3. Wait for completion (progress bar shows status)
4. Processing time varies by:
   - Date range length
   - Modeling mode (every tick vs 1 min)
   - Computer performance

### Step 5: Review Results

Once complete, review the following tabs:

#### Results Tab

Shows all trades executed during backtest:
- Date and time
- Trade type (Buy/Sell)
- Volume (lot size)
- Entry price
- Stop loss / Take profit
- Exit price
- Profit/Loss
- Balance after trade

**What to look for**:
- ✅ Consistent trade sizes
- ✅ Trades match expected logic
- ❌ Unusual patterns or errors

#### Graph Tab

Visual representation of:
- **Green line**: Balance (account total)
- **Blue line**: Equity (balance + open P&L)
- **Yellow line**: Drawdown

**What to look for**:
- ✅ Steady upward trend
- ✅ Equity closely follows balance
- ❌ Large drawdown spikes
- ❌ Flat or declining balance

#### Report Tab

Detailed statistics and metrics (see Analyzing Results below).

#### Journal Tab

Shows EA log messages:
- Initialization messages
- Trade execution logs
- Errors or warnings

**What to look for**:
- ✅ Clean initialization
- ✅ Expected trade signals
- ❌ Errors or warnings

## Analyzing Results

### Key Performance Metrics

#### Overall Performance

| Metric | What it Means | Good Value |
|--------|---------------|------------|
| **Total Net Profit** | Total profit/loss | Positive |
| **Profit Factor** | Gross profit ÷ Gross loss | > 1.5 |
| **Expected Payoff** | Average profit per trade | Positive |
| **Absolute Drawdown** | Largest balance decline from start | < 20% of deposit |
| **Maximal Drawdown** | Largest peak-to-trough decline | < 30% |
| **Recovery Factor** | Net profit ÷ Max drawdown | > 2.0 |

#### Trade Statistics

| Metric | What it Means | Good Value |
|--------|---------------|------------|
| **Total Trades** | Number of trades executed | > 30 (statistical significance) |
| **Win Rate** | % of winning trades | > 50% |
| **Average Win** | Average profit per win | > Average loss |
| **Average Loss** | Average loss per losing trade | Consistent, not growing |
| **Largest Win** | Biggest single profit | Not outlier-dependent |
| **Largest Loss** | Biggest single loss | Within acceptable risk |
| **Consecutive Wins** | Max wins in a row | - |
| **Consecutive Losses** | Max losses in a row | < 10 |

#### Risk Metrics

| Metric | What it Means | Good Value |
|--------|---------------|------------|
| **Sharpe Ratio** | Risk-adjusted return | > 1.0 |
| **Risk/Reward Ratio** | Avg win ÷ Avg loss | > 1.5 |
| **Margin Level** | Account equity ÷ Margin | Always > 100% |

### Interpreting Results

#### Excellent Performance
- Profit Factor: > 2.0
- Win Rate: > 60%
- Max Drawdown: < 15%
- Recovery Factor: > 3.0
- Consistent equity curve

#### Good Performance
- Profit Factor: 1.5 - 2.0
- Win Rate: 50-60%
- Max Drawdown: 15-25%
- Recovery Factor: 2.0 - 3.0
- Mostly steady equity curve

#### Poor Performance
- Profit Factor: < 1.5
- Win Rate: < 50%
- Max Drawdown: > 25%
- Recovery Factor: < 2.0
- Erratic equity curve

#### Red Flags
- ❌ Few trades (< 30) - insufficient data
- ❌ Profit depends on 1-2 large wins
- ❌ Long losing streaks (> 10 consecutive losses)
- ❌ Increasing average loss over time
- ❌ High drawdown relative to profit

## Optimization

### When to Optimize

Optimize when:
- Initial backtest shows promise but needs improvement
- You want to find best parameter combinations
- Testing strategy across multiple symbols/timeframes

### How to Optimize

#### Step 1: Select Parameters to Optimize

1. In Strategy Tester, check **Optimization**
2. Click **Inputs** tab
3. Check the box next to parameters to optimize
4. Set Start, Step, and Stop values for each

Example optimization setup:
```
RiskPercent: Start=1.0, Step=0.5, Stop=3.0
StopLossPips: Start=30, Step=10, Stop=100
TakeProfitPips: Start=50, Step=25, Stop=200
FastMA: Start=5, Step=5, Stop=20
SlowMA: Start=15, Step=5, Stop=40
```

#### Step 2: Select Optimization Criterion

Click **Settings** tab:
- **Balance Drawdown**: Minimize drawdown (safe)
- **Balance + Profit Factor**: Balance profit and safety (recommended)
- **Complex Criterion**: Custom formula
- **Maximum Balance**: Maximize profit (risky)

#### Step 3: Select Optimization Method

- **Slow Complete Algorithm**: Tests all combinations (thorough but slow)
- **Fast Genetic Algorithm**: Tests subset (faster, good enough)
- Recommendation: Use Genetic Algorithm for speed

#### Step 4: Run Optimization

1. Click **Start**
2. Monitor progress in Optimization Results tab
3. Review top performing parameter sets
4. Select best combination (balance profit and drawdown)

#### Step 5: Validate Optimized Parameters

**Critical**: Test optimized parameters on out-of-sample data:
1. Run new backtest with optimized parameters
2. Use different date range than optimization
3. Verify performance remains good
4. Beware of over-optimization (curve fitting)

### Avoiding Over-Optimization

**Warning Signs**:
- Parameters are too specific (e.g., MA=13.7)
- Performance degrades significantly on different periods
- Equity curve is too smooth (unrealistic)

**Prevention**:
- Keep parameters rounded (e.g., MA=10, 15, 20, not 13.7)
- Use walk-forward analysis
- Test on multiple symbols/timeframes
- Require minimum trade count (> 50)

## Best Practices

### 1. Multiple Timeframe Testing

Test on different timeframes:
```
- M15: Scalping/intraday
- H1: Day trading
- H4: Swing trading
- D1: Position trading
```

Choose timeframe that best matches strategy logic.

### 2. Multiple Symbol Testing

Test on various pairs:
```
Major Pairs: EURUSD, GBPUSD, USDJPY
Minor Pairs: EURGBP, AUDUSD, NZDUSD
Exotics: USDMXN, USDZAR (if relevant)
```

Good strategies work across multiple symbols.

### 3. Out-of-Sample Testing

**Training Period**: First 70% of data (optimize here)
**Testing Period**: Last 30% of data (validate here)

Example:
- Optimization: 2021-01-01 to 2023-06-30
- Validation: 2023-07-01 to 2024-12-31

### 4. Walk-Forward Analysis

Advanced validation method:
1. Divide data into segments (e.g., 6 months each)
2. Optimize on first segment
3. Test on next segment
4. Roll forward, repeat
5. Aggregate all out-of-sample results

### 5. Different Market Conditions

Test across:
- Trending markets
- Ranging markets
- High volatility periods
- Low volatility periods
- Different years/seasons

### 6. Record Keeping

Document all backtests:
```
Date: 2024-01-15
Symbol: EURUSD
Timeframe: H1
Period: 2022-01-01 to 2023-12-31
Parameters: [list all settings]
Results:
  - Total trades: 156
  - Win rate: 58%
  - Profit factor: 1.87
  - Max drawdown: 18%
  - Net profit: $2,340
Notes: [observations]
```

## Common Issues

### Issue 1: No Trades Executed

**Possible Causes**:
- Strategy conditions never met
- Trading hours restrictions
- Insufficient margin
- Data quality issues

**Solutions**:
1. Check strategy logic in code
2. Review trading hours settings
3. Ensure sufficient deposit
4. Verify data download

### Issue 2: Unrealistic Results

**Symptoms**:
- 100% win rate
- No losing trades
- Too smooth equity curve

**Causes**:
- Look-ahead bias in code
- Using future data
- Incorrect indicator calculations

**Solutions**:
1. Review code for logic errors
2. Ensure indicators use historical data only
3. Test on different periods
4. Recompile EA

### Issue 3: Model Quality Low

**Problem**: Modeling quality < 70%

**Solutions**:
1. Re-download historical data
2. Use different data source
3. Test on shorter period with good data
4. Switch from "Every tick" to "1 minute OHLC"

### Issue 4: Different Results on Re-run

**Problem**: Same backtest gives different results

**Causes**:
- Using random elements in code
- Data updates between runs
- Variable spread modeling

**Solutions**:
1. Remove random elements from code
2. Use fixed spread if available
3. Lock data download period

## Next Steps

After successful backtesting:

1. ✅ Document your best parameter configuration
2. ✅ Proceed to [Forward Testing](forward_testing_guide.md)
3. ✅ Test on demo account for at least 1 month
4. ✅ Monitor real-time performance vs backtest
5. ✅ Only then consider live trading

## Checklist Before Moving to Forward Testing

- [ ] Backtest shows positive net profit
- [ ] Profit factor > 1.5
- [ ] Win rate > 45%
- [ ] Maximum drawdown < 30%
- [ ] Minimum 50 trades executed
- [ ] Results validated on out-of-sample data
- [ ] Tested on multiple symbols (if applicable)
- [ ] No warning signs or red flags
- [ ] Parameters are not over-optimized
- [ ] Strategy logic matches Python implementation

## Additional Resources

- [MT5 Strategy Tester Official Guide](https://www.metatrader5.com/en/terminal/help/algotrading/testing)
- [Forward Testing Guide](forward_testing_guide.md)
- [MT5 README](../mt5/README.md)
- [Strategy Analysis](strategy_analysis.md)

---

**Remember**: Past performance does not guarantee future results. Always forward test on demo before live trading.
