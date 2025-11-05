# ICT Trading Strategy - Pine Script v5 Strategy for Backtesting

## Overview

This is a **Pine Script v5 strategy** (not an indicator) that executes actual trades based on the ICT trading logic. Use this for backtesting in TradingView's Strategy Tester to evaluate performance with historical data.

**File:** `ICT_Strategy.pine`

## Key Differences from Indicator

| Feature | Indicator (ICT_Strategy_Indicator.pine) | Strategy (ICT_Strategy.pine) |
|---------|----------------------------------------|------------------------------|
| Purpose | Visual analysis only | Backtesting with actual orders |
| Execution | No trades executed | Executes trades via `strategy.entry()` |
| Performance | No metrics | Full metrics (win rate, profit, drawdown) |
| Visual | Rich visual display | Minimal visuals, focus on results |
| Use Case | Learning and analysis | Performance evaluation |

## Installation

### Method 1: TradingView Pine Editor
1. Open TradingView and go to the Pine Editor
2. Click "New" → "Strategy"
3. Copy the entire contents of `ICT_Strategy.pine`
4. Paste into the Pine Editor
5. Click "Save" (name it "ICT Trading Strategy")
6. Click "Add to Chart"

### Method 2: Import from File
1. Save `ICT_Strategy.pine` to your computer
2. In TradingView Pine Editor, click "..." menu
3. Select "Import"
4. Choose the downloaded file
5. Click "Add to Chart"

## Strategy Configuration

### Initial Settings
- **Initial Capital**: $10,000 (adjustable in strategy settings)
- **Order Size**: 100% of equity per trade (uses position sizing based on risk %)
- **Commission**: $7 per million (7 per contract)
- **Slippage**: 3 points
- **Pyramiding**: 0 (only one position at a time)

### Key Parameters

#### Risk Management (Conservative Defaults)
- **Risk per Trade**: 1.5% (percentage of equity to risk)
- **Max Trades per Day**: 10 (reduced from indicator's 40)
- **Max Daily Loss**: 5.0% (stops trading for the day if reached)

#### ICT Parameters
- **Min FVG Size**: 2.0 pips
- **Sweep Rejection**: 0.5 pips
- **Stop Loss Buffer**: 2.0 pips
- **Displacement Candle Ratio**: 0.5

#### Risk-Reward
- **Min R:R**: 3.0
- **Max R:R**: 5.0
- **Use Random R:R**: false (default - uses fixed 3:1)
- **Fixed R:R**: 3.0

#### Sessions (UTC)
- **London**: 07:00 - 16:00
- **New York**: 12:00 - 21:00

#### Filters
- **Enable Trend Filter**: false (optional confluence)
- **Trend Lookback**: 32 bars

#### MSS Settings
- **Look-forward Bars**: 30

## How to Backtest

### 1. Basic Backtest
1. Add strategy to a 15-minute EURUSD chart
2. Open Strategy Tester (bottom panel)
3. Click "Run"
4. Review results in:
   - **Overview**: Total performance, net profit, win rate
   - **Performance Summary**: Detailed metrics
   - **List of Trades**: Individual trade details

### 2. Adjust Settings for Better Results
Try these adjustments:
- **Enable Trend Filter**: Set to `true` for higher quality signals
- **Increase min_FVG_pips**: Try 3.0 or 5.0 for major FVGs only
- **Reduce max_trades_per_day**: Try 5 for more selective trading
- **Adjust R:R ratio**: Try different fixed values (2.5, 3.5, 4.0)

### 3. Optimization
1. In Strategy Tester, click "Settings" (gear icon)
2. Enable "Optimization"
3. Select parameters to optimize:
   - min_FVG_pips (range: 1.5 to 5.0)
   - rejection_pips (range: 0.3 to 1.5)
   - fixed_RR (range: 2.0 to 5.0)
   - max_trades_per_day (range: 3 to 15)
4. Click "Run Optimization"
5. Review best parameter combinations

**Warning**: Be careful with optimization - it can lead to curve-fitting!

## Strategy Logic

### Entry Conditions (All Must Be True)
1. ✓ Valid liquidity sweep detected
2. ✓ Market Structure Shift confirmed after sweep
3. ✓ Fair Value Gap exists with matching direction
4. ✓ Current time is within trading session
5. ✓ No open positions (one trade at a time)
6. ✓ Max trades per day not exceeded
7. ✓ Daily loss limit not hit
8. ✓ Optional: Trend alignment (if enabled)

### Order Execution
- **Long Entry**: Stop order at FVG bottom + spread
- **Short Entry**: Stop order at FVG top - spread
- **Stop Loss**: At sweep price ± buffer
- **Take Profit**: Entry ± (SL distance × R:R ratio)

### Position Sizing
The strategy uses percentage-based position sizing:
- Risk amount = Account equity × risk_percent / 100
- Position size calculated to risk exact percentage on SL distance
- Adjusted for pip value and contract size

### Exit Rules
- **Stop Loss Hit**: Exit at loss
- **Take Profit Hit**: Exit at profit
- **Daily Loss Limit**: Stops taking new trades for the day

## Understanding Results

### Key Metrics to Watch

#### Performance Metrics
- **Net Profit**: Total profit/loss in currency
- **Gross Profit**: Sum of all winning trades
- **Gross Loss**: Sum of all losing trades
- **Profit Factor**: Gross Profit / Gross Loss (>1.5 is good)

#### Trade Statistics
- **Total Trades**: Number of completed trades
- **Win Rate**: Percentage of winning trades (45-60% is realistic)
- **Average Trade**: Average profit/loss per trade
- **Average Win / Average Loss**: Shows risk-reward efficiency

#### Risk Metrics
- **Max Drawdown**: Largest peak-to-valley decline (lower is better)
- **Max Drawdown %**: Drawdown as percentage of equity
- **Sharpe Ratio**: Risk-adjusted return (>1.0 is good)

### Realistic Expectations

Based on the Python backtest results and known issues:

| Metric | Python (Unrealistic) | Strategy (More Realistic) |
|--------|---------------------|---------------------------|
| Win Rate | 59% | 45-55% |
| Annual Return | 500,000%+ | 10-30% (if profitable) |
| Max Drawdown | 8% | 15-30% |
| Profit Factor | Very high | 1.3-2.0 |

**Why the difference?**
- Strategy includes commission and slippage
- Strategy enforces one position at a time
- Daily loss limits prevent overtrading
- More realistic cost modeling

## Dashboard Display

The strategy includes a real-time dashboard showing:
- **Trades Today**: Number of trades taken today
- **Session**: Whether London/NY session is active
- **Open Trades**: Current open positions (0 or 1)
- **Total Trades**: Lifetime trade count
- **Win Rate**: Overall win percentage
- **Daily PnL**: Today's profit/loss

## Best Practices

### For Accurate Backtesting
1. Use 15-minute timeframe (matches original implementation)
2. Test on EURUSD or GBPUSD (4-decimal pairs)
3. Use sufficient historical data (at least 6 months)
4. Don't over-optimize parameters
5. Test on out-of-sample data
6. Compare results with different time periods

### Parameter Recommendations

#### Conservative (Recommended for Live)
```
risk_percent = 0.5
max_trades_per_day = 5
max_daily_loss_percent = 3.0
min_FVG_pips = 3.0
enable_trend_filter = true
fixed_RR = 3.0
```

#### Moderate
```
risk_percent = 1.0
max_trades_per_day = 8
max_daily_loss_percent = 4.0
min_FVG_pips = 2.5
enable_trend_filter = true
fixed_RR = 3.5
```

#### Aggressive (Testing Only)
```
risk_percent = 1.5
max_trades_per_day = 10
max_daily_loss_percent = 5.0
min_FVG_pips = 2.0
enable_trend_filter = false
fixed_RR = 4.0
```

## Known Limitations

### Strategy Limitations
1. **One Position at a Time**: Unlike the Python version which allowed multiple trades, this enforces one position
2. **No Partial Exits**: Takes full profit/loss at TP/SL
3. **Fixed Position Sizing**: Uses percentage of equity, not dynamic lot sizing
4. **Bar-Based Execution**: Entries/exits happen at bar close, not intra-bar

### TradingView Limitations
1. **Historical Data**: Limited by TradingView's data availability
2. **Calculation Time**: Large datasets may timeout
3. **Optimization**: Can be slow for multiple parameters
4. **Commission Model**: Simplified compared to real broker fees

## Troubleshooting

### No Trades Generated
- Check that you're in a trading session
- Verify data includes both London and NY hours
- Try reducing min_FVG_pips
- Disable trend filter temporarily
- Check Strategy Tester for error messages

### Too Many Trades
- Increase min_FVG_pips
- Enable trend filter
- Reduce max_trades_per_day
- Increase rejection_pips for stricter sweeps

### Poor Performance
- **Expected**: This is normal - the Python results were unrealistic
- Try enabling trend filter
- Increase minimum FVG size
- Reduce risk per trade
- Test on different time periods
- Compare with buy-and-hold benchmark

### Strategy Not Executing
- Ensure you added it as a "Strategy" not "Indicator"
- Check initial capital is sufficient
- Verify commission settings aren't too high
- Look for errors in Strategy Tester panel

## Comparison with Indicator

Use both together for best results:

1. **Indicator** (`ICT_Strategy_Indicator.pine`):
   - Add to chart for visual analysis
   - See FVG boxes, sweep markers, MSS confirmations
   - Learn to recognize patterns manually
   - Understand the logic visually

2. **Strategy** (`ICT_Strategy.pine`):
   - Run in Strategy Tester for backtesting
   - Get quantitative performance metrics
   - Optimize parameters
   - Validate the approach with data

## Forward Testing (After Backtesting)

If backtest results are promising:

1. **Paper Trading**:
   - Use TradingView's "Paper Trading" mode
   - Monitor real-time performance
   - Compare with backtest expectations
   - Run for minimum 3 months

2. **Transition to Live**:
   - Start with micro account
   - Use conservative parameters
   - Risk only 0.5% per trade initially
   - Scale gradually if profitable

## Important Warnings

⚠️ **RISK DISCLOSURE**

- **Past performance does not guarantee future results**
- **Backtesting can be misleading** due to curve-fitting and perfect hindsight
- **Live trading results will differ** from backtest due to slippage, spreads, and execution
- **Start small** and only use risk capital you can afford to lose
- **This is NOT financial advice** - always do your own research
- **Test thoroughly** before risking real money

⚠️ **REALISTIC EXPECTATIONS**

The Python backtest showed 500,000%+ returns, which is **NOT realistic**. Expect:
- Lower win rate (45-55% vs 59%)
- Higher drawdowns (15-30% vs 8%)
- Modest returns if profitable (10-30% annually)
- Periods of losses and drawdowns

See `docs/CODE_REVIEW.md` for detailed analysis of why Python results were inflated.

## Support

For issues or questions:
1. Review this documentation
2. Check `PINESCRIPT_USAGE.md` for indicator usage
3. Read `docs/CODE_REVIEW.md` for strategy analysis
4. Review TradingView's Strategy Testing documentation
5. Compare with Python implementation in `ict_trader.py`

## Version History

**v1.0** - Initial Release
- Complete ICT strategy implementation
- Stop and limit order execution
- Daily loss limits
- Position sizing based on risk percentage
- Real-time performance dashboard
- Conservative default parameters

## License

Same as parent repository. See main README for details.

---

**Ready to Backtest!** Load the strategy into TradingView and run the Strategy Tester to see how it performs on historical data. Remember: good backtest results don't guarantee future profitability - always test on demo before live trading.
