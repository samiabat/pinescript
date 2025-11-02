# ICT Smart Money Backtest System

A professional implementation of an Inner Circle Trader (ICT) strategy backtest for EURUSD 15-minute historical data with realistic trading costs and account protection.

## Overview

This backtest system implements a strict ICT smart money strategy with the following key components:

- **Liquidity Sweep Detection**: Identifies when price makes new highs/lows and rejects
- **Market Structure Shift (MSS)**: Confirms reversal of minor market structure
- **Fair Value Gap (FVG)**: Detects 3-candle imbalances for entry zones
- **Higher Timeframe Trend Filter**: Only trades aligned with 1-hour trend bias
- **Discretion Filters**: Avoids messy candles, low liquidity periods, and small FVGs
- **Risk Management**: 1% risk per trade with position sizing based on stop-loss distance
- **No Look-Ahead Bias**: Uses only historical data available at each point in time
- **Realistic Trading Costs**: Includes spread and slippage on every trade
- **Account Blow Protection**: Automatically stops trading if balance falls below minimum threshold
- **Trade Visualization**: Automatic TradingView-style candlestick chart generation for each trade
- **Performance Analytics**: Comprehensive monthly and yearly performance breakdowns

## Requirements

```bash
pip install pandas numpy matplotlib
```

## Configuration

Edit the configuration section in `new_trader.py`:

```python
CSV_PATH = "EURUSD15.csv"           # Your EURUSD 15M data file
INITIAL_BALANCE = 10000.0            # Starting capital ($)
RISK_PER_TRADE = 0.01                # 1% risk per trade

# Trading parameters
MAX_TRADES_PER_DAY = 10                # Maximum trades per day (increased for more opportunities)
MIN_FVG_PIPS = 2                       # Minimum FVG size in pips (reduced for smaller valid FVGs)
STOP_LOSS_BUFFER_PIPS = 2              # Buffer beyond sweep extreme
SWING_LOOKBACK = 2                     # Candles for swing detection (reduced for sensitivity)
SWEEP_REJECTION_PIPS = 1               # Minimum rejection size for sweeps
TARGET_MIN_R = 3.0                     # Minimum risk-reward ratio
TARGET_MAX_R = 5.0                     # Maximum risk-reward ratio

# Realistic trading costs
SPREAD_PIPS = 0.8                      # Typical EURUSD spread (0.5-1.5 pips)
SLIPPAGE_PIPS = 0.5                    # Average slippage on entry/exit
MIN_BALANCE_THRESHOLD = 100.0          # Minimum balance to continue trading (account blow protection)

# Chart generation
GENERATE_TRADE_CHARTS = True          # Generate candlestick charts for each trade
TRADE_CHARTS_FOLDER = "trade_charts"  # Folder to save trade charts

# Debug and relaxed modes
DEBUG = False                         # Set to True to see detailed pattern detection
RELAXED_MODE = True                   # Enabled by default for more trading opportunities
```

### New Features

#### 1. Leverage Control
- **USE_LEVERAGE = False** (default): No leverage, safest mode (1:1 position sizing)
- **USE_LEVERAGE = True**: Enables leverage up to MAX_LEVERAGE (default 30x)
- MAX_LEVERAGE prevents unrealistic position sizes that brokers would reject

#### 2. Trade Chart Generation
- Automatically generates candlestick charts for each trade
- Charts show 20 candles before/after entry with marked entry/exit points
- Includes SL/TP levels and trade info
- Saved to `trade_charts/` folder
- File naming: `trade_001_long_TP.png`, `trade_002_short_SL.png`, etc.

See `NEW_FEATURES.md` for detailed documentation.

### Getting More Trades

If you're getting few or no trades, try these adjustments:

1. **Enable RELAXED_MODE**: Set `RELAXED_MODE = True` to allow entries even when 1H trend is neutral
2. **Reduce MIN_FVG_PIPS**: Lower to 3-4 pips if your data has smaller movements
3. **Increase MAX_TRADES_PER_DAY**: Set to 3 or 4 for more opportunities
4. **Enable DEBUG mode**: Set `DEBUG = True` to see why setups are being rejected

## Data Format

The CSV file should contain EURUSD 15-minute candles with **no header** and the following format:

```
2021-10-29 20:15    1.15614 1.15618 1.15599 1.15615 254
2021-10-29 20:30    1.15615 1.15617 1.15572 1.15573 321
```

Columns: `datetime open high low close volume`

## Usage

```bash
python3 new_trader.py
```

The script will:
1. Load historical data from `EURUSD15.csv`
2. Run the backtest bar-by-bar through the entire dataset
3. Apply all ICT confluence rules strictly
4. Generate output files with results

## Strategy Logic

### Entry Conditions (ALL must be met):

1. **Session Filter**: Only trade during London + NY sessions (07:00-16:00 UTC)
2. **Trend Bias**: 1-hour trend must be clearly bullish or bearish
3. **Liquidity Sweep**: Price must sweep recent high (bearish) or low (bullish)
4. **Market Structure Shift**: Confirmation of structure break after sweep
5. **Fair Value Gap**: Valid FVG must be present (minimum size requirement)
6. **Quality Filters**: 
   - No messy candle clusters
   - Sufficient liquidity (volume)
   - Maximum 2 trades per day

### Position Management:

- **Stop Loss**: Placed beyond sweep extreme + buffer
- **Take Profit**: 3-5× the stop-loss distance
- **Position Size**: Automatically calculated for 1% account risk
- **Exit**: Either TP hit, SL hit, or timeout at end of backtest

## Output

### 1. Trade Journal (`trade_journal.csv`)

Contains detailed information for each trade:
- Entry/exit times and prices
- Direction (long/short)
- P&L in pips and USD
- Stop-loss and take-profit distances
- Result (TP/SL/Timeout)
- Position size

### 2. Monthly & Yearly Performance Analysis

**NEW**: Comprehensive time-based performance breakdown:

#### `yearly_performance.csv`
- Total trades per year
- Wins/losses breakdown
- Win rate percentage
- Total P&L for each year

#### `monthly_performance.csv`
- Detailed month-by-month performance
- Trade count per month
- Win rate per month
- Total and average P&L per month

#### `monthly_heatmap_data.csv`
- Pivot table format for visualization
- P&L and trade count by year and month
- Perfect for creating heatmap visualizations

**Console Output Includes:**
- Yearly performance summary with trade stats
- Monthly performance for all months
- Top 5 best performing months
- Top 5 worst performing months
- Complete breakdown showing which months/years were most profitable

### 3. Equity Curve (`equity_curve.png`)

Visual representation of account balance over time showing:
- Account growth/drawdown
- Initial balance reference line
- Complete equity progression

### 4. Trade Charts (`trade_charts/` folder)

**TradingView-Style Visualization** - Each trade gets a professional chart:
- Dark theme matching TradingView appearance
- LONG/SHORT position markers with colored labels
- RED zone for Stop Loss area (semi-transparent rectangle)
- GREEN zone for Take Profit area (semi-transparent rectangle)
- 80+ candles of context (40 before entry, 40 after exit)
- Timestamps on X-axis (15-minute intervals)
- Price values on Y-axis
- Complete trade details in info box with ICT signals checklist
- File naming: `trade_001_long_TP.png`, `trade_002_short_SL.png`, etc.

### 5. Performance Metrics (console output)

```
BACKTEST PERFORMANCE SUMMARY
================================================================================
Total Trades:        50
Winning Trades:      32
Losing Trades:       18
Win Rate:            64.0%
--------------------------------------------------------------------------------
Total P&L:           $2,450.00
Average Win:         $125.50
Average Loss:        -$100.00
Average P&L:         $49.00
Average R:R:         3.85
--------------------------------------------------------------------------------
Starting Balance:    $10,000.00
Ending Balance:      $12,450.00
Total Return:        24.50%
Max Drawdown:        8.35%
================================================================================
```

## Strategy Parameters

### Liquidity Sweep
- Detects new swing highs (bear sweep) or lows (bull sweep)
- Requires 3+ pip rejection from extreme

### Market Structure Shift
- Confirms break of recent structure after sweep
- Minimum 5 pip structure break required

### Fair Value Gap
- 3-candle imbalance pattern
- Minimum gap size: 5 pips (configurable)
- Entry on retrace into FVG zone

### Trend Detection
- Compares recent 8 candles vs older 8 candles
- Higher highs + higher lows = bullish
- Lower highs + lower lows = bearish

## Key Features

✅ **Strict ICT Rules**: No trade unless all conditions align  
✅ **Realistic Execution**: Bar-by-bar simulation with proper fills  
✅ **Risk Management**: Automatic position sizing for consistent 1% risk  
✅ **Session Filtering**: Only trades London + NY sessions  
✅ **Quality Filters**: Avoids low-quality setups  
✅ **Comprehensive Logging**: Full trade journal and metrics  
✅ **Visual Output**: Equity curve chart generation  

## Notes

- The strategy is intentionally strict and may have periods with no trades
- This is expected behavior for quality-focused ICT strategies
- Adjust parameters based on your analysis and backtesting results
- Always validate on multiple years of data before live trading
- Past performance does not guarantee future results

## Troubleshooting

### "No trades executed" even with real data

**This was a known issue that has been FIXED.** The problem was that the strategy checked for sweep, MSS, and FVG all on the same candle, but these patterns occur in sequence. The fix now tracks recent sweeps and checks for MSS/FVG formation on subsequent candles.

**If you still see no trades:**

1. **Enable RELAXED_MODE**: Set `RELAXED_MODE = True` in the configuration
   - This allows trades even when 1H trend is neutral
   - Useful for ranging markets or less trending periods

2. **Reduce MIN_FVG_PIPS**: Lower from 5 to 3 pips
   - Some markets have smaller FVGs
   
3. **Enable DEBUG mode**: Set `DEBUG = True`
   - See exactly which patterns are being detected
   - Understand why setups are being rejected

4. **Check your data format**: Ensure CSV matches the required format:
   ```
   2021-10-29 20:15    1.15614 1.15618 1.15599 1.15615 254
   ```
   - Columns: datetime (space-separated date and time), open, high, low, close, volume
   - No header row
   - Space-separated values

### Low trade frequency

This is normal! ICT strategies are quality-focused and wait for perfect setups. With strict parameters:
- 1 year of 15M data might produce 10-50 trades
- This is intentional for high win-rate, high R:R trades

To increase frequency (at the cost of quality):
- Enable `RELAXED_MODE = True`
- Increase `MAX_TRADES_PER_DAY`
- Reduce `MIN_FVG_PIPS`
- Adjust session times to include more hours

## Customization

You can adjust the strategy by modifying:

1. **Session times**: Change `LONDON_NY_START` and `LONDON_NY_END`
2. **Risk parameters**: Adjust `RISK_PER_TRADE`, `TARGET_MIN_R`, `TARGET_MAX_R`
3. **Quality filters**: Modify `MIN_FVG_PIPS`, `MAX_TRADES_PER_DAY`
4. **Detection sensitivity**: Edit functions in the detection section

## Disclaimer

This is a backtesting tool for educational and analysis purposes only. Trading forex carries substantial risk and may not be suitable for all investors. Past backtested performance is not indicative of future results.

## License

MIT License - Free to use and modify
