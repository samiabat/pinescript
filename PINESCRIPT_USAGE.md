# ICT Trading Strategy - Pine Script v5 Indicator

## Overview

This Pine Script v5 indicator implements the complete ICT (Inner Circle Trader) trading strategy as described in the repository's Python and MQL5 implementations. It detects Fair Value Gaps (FVG), Liquidity Sweeps, and Market Structure Shifts (MSS) to generate BUY/SELL signals with visual markers.

**File:** `ICT_Strategy_Indicator.pine`

## Features

### Core ICT Components
- **Liquidity Sweep Detection**: Detects when price sweeps previous highs/lows with rejection
- **Fair Value Gap (FVG)**: Identifies price imbalances with displacement candle validation
- **Market Structure Shift (MSS)**: Confirms trend changes after sweeps
- **Session Filtering**: Only signals during London (07:00-16:00 UTC) and New York (12:00-21:00 UTC) sessions
- **Trend Alignment**: Optional trend filter using recent high/low comparison

### Entry Logic
A signal is generated when ALL of the following conditions are met:
1. Valid liquidity sweep detected (20-bar lookback with rejection confirmation)
2. Market Structure Shift confirmed after the sweep
3. Fair Value Gap detected matching sweep direction (bullish sweep → bullish FVG)
4. Current time is within allowed trading sessions
5. Optional: Trend alignment confirmed (if enabled)
6. Max trades per day limit not exceeded

### Visual Elements
- **FVG Boxes**: Green (bullish) or Red (bearish) transparent boxes showing Fair Value Gaps
- **Sweep Markers**: Triangle markers showing liquidity sweeps (green = bull sweep, red = bear sweep)
- **MSS Markers**: Blue circle markers confirming Market Structure Shift
- **Entry Signals**: Large labels with "ICT BUY" or "ICT SELL" plus the R:R ratio used
- **Entry/SL/TP Lines**: 
  - Blue solid line = Entry price
  - Red dashed line = Stop Loss
  - Green dashed line = Take Profit
- **Dashboard**: Top-right table showing:
  - Trades today count
  - Session status (ACTIVE/CLOSED)
  - Current trend
  - Active sweeps count
  - Max daily loss limit

## Installation

### Method 1: TradingView Pine Editor
1. Open TradingView and go to the Pine Editor (bottom of screen)
2. Click "New" to create a new indicator
3. Copy the entire contents of `ICT_Strategy_Indicator.pine`
4. Paste into the Pine Editor
5. Click "Save" and give it a name (e.g., "ICT Strategy Indicator")
6. Click "Add to Chart"

### Method 2: Import from File
1. Save `ICT_Strategy_Indicator.pine` to your computer
2. In TradingView Pine Editor, click the "..." menu
3. Select "Import"
4. Choose the downloaded file
5. Click "Add to Chart"

## Configuration

### Risk Management
- **Risk per Trade (%)**: Default 1.5% - percentage of account to risk per trade
- **Max Trades per Day**: Default 40 (⚠️ very high, reduce to 5-10 for live trading)
- **Min Balance Threshold**: Display-only parameter (default 100)
- **Max Daily Loss %**: Display-only parameter (default 5%)

### ICT Parameters
- **Minimum FVG Size (pips)**: Default 2.0 - minimum gap size to qualify as FVG
- **Sweep Rejection (pips)**: Default 0.5 - minimum rejection wick size for sweep confirmation
- **Stop Loss Buffer (pips)**: Default 2.0 - buffer added to sweep price for SL placement
- **Displacement Candle Min Size Ratio**: Default 0.5 - displacement candle must be >= 50% of minimum FVG size

### Risk-Reward Settings
- **Minimum R:R**: Default 3.0
- **Maximum R:R**: Default 5.0
- **Use Random R:R**: Default true - randomly selects R:R between min and max (deterministic using bar_index)
- **Fixed R:R**: Default 3.0 - used when random R:R is disabled

### Trading Sessions (UTC)
- **London Open Hour**: Default 7 (7:00 AM UTC)
- **London Close Hour**: Default 16 (4:00 PM UTC)
- **NY Open Hour**: Default 12 (12:00 PM UTC / 8:00 AM NY time)
- **NY Close Hour**: Default 21 (9:00 PM UTC / 5:00 PM NY time)

⚠️ **Note**: Assumes your TradingView chart is set to New York timezone. No timezone conversion is performed by the indicator.

### Trend Filter
- **Enable Trend Alignment**: Default false - when enabled, only takes trades aligned with trend
- **Trend Lookback Bars**: Default 32 - number of bars to analyze for trend detection

### MSS Settings
- **MSS Look-forward Bars**: Default 30 - maximum bars to wait for MSS confirmation after sweep

### Display & Debug
- **Spread (pips)**: Default 0.6 - added to entry price calculations
- **Show FVG Boxes**: Default true
- **Show Sweep Markers**: Default true
- **Show MSS Markers**: Default true
- **Enable Debug Logging**: Default false - prints detection events to Pine Logs

## Usage

### Basic Usage
1. Apply the indicator to a 15-minute chart (recommended, matches Python/MQL5 implementations)
2. Use EURUSD or other major forex pairs
3. Signals appear as large labels with entry/SL/TP lines
4. Monitor the dashboard for trades count and session status

### Understanding Signals

#### BUY Signal (Bullish Setup)
- Triggered after a bullish liquidity sweep (price swept below previous low and rejected up)
- MSS confirms higher high after the sweep
- Bullish FVG detected (gap above price)
- Entry: Bottom of FVG + spread
- SL: Below sweep low - buffer
- TP: Entry + (SL distance × R:R ratio)

#### SELL Signal (Bearish Setup)
- Triggered after a bearish liquidity sweep (price swept above previous high and rejected down)
- MSS confirms lower low after the sweep
- Bearish FVG detected (gap below price)
- Entry: Top of FVG - spread
- SL: Above sweep high + buffer
- TP: Entry - (SL distance × R:R ratio)

### Debug Logging
When enabled, logs will show:
- Sweep detected events with type and price
- Entry signals with all calculated values (entry, SL, TP, R:R)

To view logs:
1. Open Pine Editor
2. Look at the bottom panel for "Pine Logs" tab
3. Logs appear in real-time as the indicator processes bars

## Important Notes

### Repainting Prevention
- All signals use `barstate.isconfirmed` to ensure they only appear after a bar closes
- Sweeps and FVGs are only stored when the bar is confirmed
- Entry signals are only generated on confirmed bars
- This ensures signals don't disappear or change on replay/refresh

### Signal Persistence
- Each sweep can only generate ONE signal (marked as "used" after entry)
- Daily trade counter resets at the start of each new day
- Sweeps older than lookforward window + 10 bars are automatically cleaned up

### Timeframe & Symbol
- **Recommended Timeframe**: 15 minutes (M15)
- **Recommended Symbols**: EURUSD, GBPUSD, XAUUSD (major forex pairs with 4-decimal pip calculation)
- The indicator assumes 4-decimal pricing (pips = 0.0001)
- For JPY pairs or 2-decimal instruments, you may need to adjust pip calculations

### Limitations
- This is an **indicator only** - it does NOT place actual trades
- Signals are for **visual analysis and backtesting** purposes
- Does not include actual position sizing or account management
- Daily PnL tracking is display-only, not calculated from actual trades
- No order execution, slippage, or commission modeling (display values only)

### Differences from Python/MQL5 Versions
- Pine Script cannot execute trades, only visualize signals
- No actual position tracking or equity curve generation
- Daily PnL is not calculated (display parameter only)
- Random R:R uses bar_index for deterministic seeding (not truly random but consistent for backtesting)
- Limited historical sweep storage (arrays cleaned up periodically to avoid memory issues)

## Best Practices

### For Backtesting/Analysis
1. Use TradingView's Strategy Tester if you want performance metrics
2. Review signals manually to understand the strategy
3. Pay attention to signal frequency and quality
4. Check that signals align with your understanding of ICT concepts

### Before Live Trading
1. **Do NOT trade based solely on this indicator**
2. Backtest thoroughly on demo account
3. Reduce `max_trades_per_day` to 5-10 (default 40 is too high)
4. Reduce `risk_percent` to 0.5-1.0% for live trading
5. Enable trend filter for higher quality signals
6. Consider increasing `min_FVG_pips` for major FVGs only
7. Compare signals with Python/MQL5 implementations for consistency

### Parameter Tuning
1. Start with default parameters
2. Adjust one parameter at a time
3. Don't over-optimize (curve-fitting risk)
4. Test on out-of-sample data
5. Be conservative with risk settings

## Troubleshooting

### No Signals Appearing
- Check that you're in a trading session (dashboard shows "ACTIVE")
- Verify `max_trades_per_day` hasn't been exceeded
- Enable debug logging to see if sweeps/FVGs are being detected
- Try reducing `min_FVG_pips` or `rejection_pips` for more sensitivity
- Ensure you're on the correct timeframe (15-minute recommended)

### Too Many Signals
- Increase `min_FVG_pips` (e.g., 3.0 or 5.0)
- Increase `rejection_pips` (e.g., 1.0 or 1.5)
- Enable trend filter
- Reduce `mss_lookforward_bars` for stricter MSS confirmation
- Increase `DISPLACEMENT_CANDLE_MIN_SIZE_RATIO`

### Signals Not Making Sense
- Review ICT concepts (FVG, liquidity sweeps, MSS)
- Check sweep markers to see where sweeps are detected
- Look at FVG boxes to understand gap placement
- Verify session times match your expectations (UTC-based)
- Enable debug logging to trace the logic

### Performance Issues
- Reduce `max_labels_count`, `max_boxes_count`, `max_lines_count` in indicator declaration
- The script auto-cleans old sweeps, but very long historical data may slow down
- Consider using fewer visual elements if needed

## Code Structure

The indicator follows a modular structure:

1. **Inputs Section**: All user-configurable parameters
2. **Helper Functions**: Pip conversion, session check, RR ratio generation
3. **Trend Detection**: Simple trend analysis based on recent vs. older highs/lows
4. **Liquidity Sweep Detection**: 20-bar lookback with rejection confirmation
5. **FVG Detection**: 3-bar pattern with displacement candle validation
6. **MSS Detection**: Checks for structure break after sweep
7. **State Management**: Arrays to track sweeps, daily counters
8. **Main Logic**: Sweep storage and entry signal generation
9. **Visual Display**: Boxes, lines, labels, and dashboard

All function calls are written on **single lines** as required.

## Compliance with Requirements

✅ Pine Script v5 indicator (not a strategy)  
✅ Single-line function calls only  
✅ Liquidity sweep detection (20-bar lookback, rejection threshold)  
✅ FVG detection with displacement candle validation  
✅ MSS detection with configurable look-forward window  
✅ Session filtering (London/NY UTC)  
✅ Optional trend alignment  
✅ Entry/SL/TP calculation and display  
✅ Position filtering (max trades per day, daily tracking)  
✅ Visual elements (FVG boxes, sweep markers, signal labels)  
✅ Debug logging toggle  
✅ All thresholds exposed as inputs  
✅ Non-repainting (uses barstate.isconfirmed)  
✅ Deterministic random R:R (using bar_index seed)  
✅ Dashboard display for monitoring  

## Support & Questions

For issues or questions:
1. Review the Python implementation in `ict_trader.py` for logic reference
2. Check the MQL5 implementation in `docs/ICT_Strategy_EA.mq5` for additional details
3. Read the documentation in `docs/README.md` and `docs/CODE_REVIEW.md`
4. Refer to TradingView's Pine Script v5 documentation for syntax questions

## Disclaimer

⚠️ **IMPORTANT**: This indicator is for educational and analysis purposes only.

- Past performance does not guarantee future results
- Trading involves substantial risk of loss
- This is NOT financial advice
- Always test thoroughly before live trading
- Use only risk capital you can afford to lose
- The backtest results in the repository are NOT representative of live trading

**By using this indicator, you accept full responsibility for your trading decisions.**

## License

Same as the parent repository. See main README for details.

---

**Version**: 1.0  
**Compatible with**: TradingView Pine Script v5  
**Recommended Timeframe**: 15 minutes  
**Recommended Instruments**: EURUSD, GBPUSD, XAUUSD (4-decimal forex pairs)
