# ICT Smart Money Backtest System

A professional implementation of an Inner Circle Trader (ICT) strategy backtest for EURUSD 15-minute historical data.

## Overview

This backtest system implements a strict ICT smart money strategy with the following key components:

- **Liquidity Sweep Detection**: Identifies when price makes new highs/lows and rejects
- **Market Structure Shift (MSS)**: Confirms reversal of minor market structure
- **Fair Value Gap (FVG)**: Detects 3-candle imbalances for entry zones
- **Higher Timeframe Trend Filter**: Only trades aligned with 1-hour trend bias
- **Discretion Filters**: Avoids messy candles, low liquidity periods, and small FVGs
- **Risk Management**: 1% risk per trade with position sizing based on stop-loss distance

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
MAX_TRADES_PER_DAY = 2               # Maximum trades per day
MIN_FVG_PIPS = 5                     # Minimum FVG size in pips
STOP_LOSS_BUFFER_PIPS = 2            # Buffer beyond sweep extreme
TARGET_MIN_R = 3.0                   # Minimum risk-reward ratio
TARGET_MAX_R = 5.0                   # Maximum risk-reward ratio
```

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

### 2. Equity Curve (`equity_curve.png`)

Visual representation of account balance over time showing:
- Account growth/drawdown
- Initial balance reference line
- Complete equity progression

### 3. Performance Metrics (console output)

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
