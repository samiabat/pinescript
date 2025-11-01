# ICT Trading Scripts for TradingView

This repository contains two Pine Script v5 files implementing ICT (Inner Circle Trader) concepts for trading:

1. **ict_indicator.pine** - Indicator for visualizing ICT concepts
2. **ict_strategy.pine** - Strategy tester with backtesting capabilities

## Features

### ICT Concepts Implemented

- **Order Blocks (OB)**: Identifies bullish and bearish order blocks - the last opposite candle before a strong directional move
- **Fair Value Gaps (FVG)**: Detects imbalances/gaps in price where the market moved inefficiently
- **Market Structure**: Tracks swing highs and lows to identify bullish/bearish market structure
- **Break of Structure (BOS)**: Identifies when market structure shifts from bullish to bearish or vice versa

### Key Constraints Addressed

✅ **No Overlapping Zones**: Order blocks, FVGs, and other ICT zones are checked for overlaps before plotting
✅ **No Simultaneous Signals**: Buy and sell signals cannot appear at the same price/location
✅ **Trade Cooldown**: Minimum bars between consecutive trades (configurable, default: 5 bars)
✅ **Daily Trade Limit**: Maximum 5 trades per day (configurable)
✅ **Signal Conflict Prevention**: Additional safety checks prevent conflicting signals

## Files

### 1. ict_indicator.pine

The indicator script visualizes ICT concepts on your chart:

**Features:**
- Plots bullish and bearish order blocks as colored boxes
- Displays fair value gaps with distinct colors
- Shows market structure shifts
- Generates buy/sell signals based on ICT logic
- Prevents overlapping zones for visual clarity
- Enforces signal cooldown periods

**Inputs:**
- Order Block Lookback: Number of bars to analyze for OB detection (default: 10)
- FVG Min Size: Minimum gap size as percentage of price (default: 0.0%)
- Swing Detection Length: Bars for swing high/low detection (default: 5)
- Signal Cooldown Periods: Minimum bars between signals (default: 5)
- Toggle options for each visual element

**How to Use:**
1. Copy the contents of `ict_indicator.pine`
2. Open TradingView and create a new indicator
3. Paste the code and save
4. Add the indicator to your chart
5. Adjust settings as needed

### 2. ict_strategy.pine

The strategy script implements trading rules with backtesting:

**Features:**
- Entry signals based on order blocks and market structure
- Automatic stop loss and take profit levels
- Optional trailing stop functionality
- Trade limiting: cooldown between trades + daily maximum
- Performance metrics displayed in table
- Prevents overlapping zones (same logic as indicator)
- Risk management built-in

**Inputs:**
- All indicator settings (OB, FVG, Market Structure)
- **Trade Management:**
  - Minimum Bars Between Trades (default: 5)
  - Max Trades Per Day (default: 5)
- **Risk Management:**
  - Stop Loss % (default: 2%)
  - Take Profit % (default: 4%)
  - Use Trailing Stop (default: false)
  - Trailing Stop % (default: 1.5%)

**How to Use:**
1. Copy the contents of `ict_strategy.pine`
2. Open TradingView and create a new strategy
3. Paste the code and save
4. Add the strategy to your chart
5. Adjust settings and review backtest results in Strategy Tester

## ICT Concepts Explained

### Order Blocks
Order blocks represent institutional buying or selling. They are the last opposite-colored candle before a strong directional move:
- **Bullish OB**: Last bearish candle before strong upward move
- **Bearish OB**: Last bullish candle before strong downward move

Price often returns to these zones for continuation entries.

### Fair Value Gaps (FVG)
FVGs occur when price moves so quickly that it leaves a gap/imbalance:
- **Bullish FVG**: Current low is above the high from 2 bars ago
- **Bearish FVG**: Current high is below the low from 2 bars ago

These gaps often get "filled" as price retraces.

### Market Structure
Market structure determines the overall trend:
- **Bullish Structure**: Higher highs and higher lows
- **Bearish Structure**: Lower highs and lower lows
- **Structure Break**: When this pattern changes, indicating potential reversal

### Trade Logic

**Long Entry:**
1. Market structure is bullish
2. Price touches a bullish order block
3. Cooldown period has elapsed
4. Daily trade limit not exceeded

**Short Entry:**
1. Market structure is bearish
2. Price touches a bearish order block
3. Cooldown period has elapsed
4. Daily trade limit not exceeded

## Trade Constraints

### Consecutive Trade Prevention
The `trade_cooldown` parameter (default: 5 bars) ensures a minimum number of bars between trades. This prevents overtrading in choppy conditions.

### Daily Trade Limit
Maximum 5 trades per day (configurable). This limit resets at the start of each new trading day based on the chart timeframe.

### Signal Conflict Prevention
Multiple layers prevent simultaneous buy/sell signals:
1. Market structure check (can't be bullish and bearish simultaneously)
2. Signal type tracking (last signal type recorded)
3. Explicit conflict check before signal generation

## Zone Overlap Prevention

Both scripts maintain arrays tracking active zones:
- Bullish order blocks
- Bearish order blocks
- Fair value gaps

Before adding a new zone, the script checks if it overlaps with existing zones. If overlap exists, the new zone is not added, preventing visual clutter and logical conflicts.

Old zones (>100 bars old) are automatically cleaned up to maintain performance.

## Customization

### Adjusting Sensitivity
- Increase `ob_length` for more significant order blocks
- Increase `fvg_threshold` to filter smaller gaps
- Adjust `swing_length` for different market structure timeframes

### Risk Management
- Modify `stop_loss_pct` and `take_profit_pct` for your risk tolerance
- Enable trailing stops for trend-following
- Adjust position size in strategy settings

### Trade Frequency
- Increase `trade_cooldown` to reduce trade frequency
- Decrease `max_daily_trades` for more selective trading

## Version Information

- **Pine Script Version**: 5
- **TradingView Compatibility**: All plans (Free, Pro, Pro+, Premium)
- **Recommended Timeframes**: 15m, 1H, 4H, Daily

## Notes

- These scripts are educational implementations of ICT concepts
- Past performance does not guarantee future results
- Always test strategies thoroughly before live trading
- Consider market conditions and adjust parameters accordingly
- The scripts use conservative default settings; optimize for your market

## License

Open source - feel free to modify and adapt for your trading needs.

## Support

For issues or questions, please open an issue in the repository.
