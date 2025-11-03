# New Features Added

## 1. Look-Ahead Bias Prevention ✓

The backtest system has been verified to **NOT** use any future data:

- All pattern detection functions only use data up to `current_idx`
- FVG detection: Uses candles at `current_idx - 2`, `current_idx - 1`, and `current_idx`
- Sweep detection: Looks back only (never forward)
- MSS confirmation: Checks candles from sweep to current (no future peek)
- Trend detection: Uses historical candles only

**Verification**: Code review confirms no `df.iloc[current_idx + 1]` or similar future references exist.

## 2. Leverage Limits

Added realistic broker leverage constraints:

### Configuration
```python
MAX_LEVERAGE = 30                    # Maximum leverage (realistic broker limit)
USE_LEVERAGE = False                 # Set to True to use leverage
```

### How It Works

**Without Leverage (USE_LEVERAGE = False):**
- Position size limited to balance / current price
- For EURUSD ~1.1: max position = balance / 1.1
- Example: $10,000 balance → max ~9,090 units
- This is the safest mode (1:1, no leverage)

**With Leverage (USE_LEVERAGE = True):**
- Position size limited by MAX_LEVERAGE setting
- Formula: max position = (balance × MAX_LEVERAGE) / current price
- Example: $10,000 balance, 30x leverage → max ~272,727 units
- Leverage is capped at MAX_LEVERAGE (default 30x, typical for forex brokers)

### Safety Features
- Prevents unrealistic leverage (e.g., 100x or 500x)
- Default is NO leverage for safety
- MAX_LEVERAGE = 30 is realistic for most forex brokers
- Position size calculations respect leverage limits before risk-based sizing

## 3. Trade Chart Generation

Automatically generates candlestick charts for each executed trade.

### Configuration
```python
GENERATE_TRADE_CHARTS = True         # Generate candlestick charts for each trade
TRADE_CHARTS_FOLDER = "trade_charts" # Folder to save trade charts
```

### Chart Features

Each chart includes:
- **Candlestick data**: 20 candles before entry + 20 candles after exit
- **Entry marker**: Blue triangle (↑) for long, Purple triangle (↓) for short
- **Exit marker**: Green star (TP), Red star (SL), Orange star (Timeout)
- **Stop Loss line**: Red dashed horizontal line
- **Take Profit line**: Green dashed horizontal line
- **Trade info box**: Shows entry, exit, P&L, direction, result

### File Naming
Charts are saved as: `trade_XXX_direction_result.png`

Examples:
- `trade_001_long_TP.png`
- `trade_002_short_SL.png`
- `trade_003_long_Timeout.png`

### Storage
- All charts saved in `trade_charts/` folder
- Folder created automatically if it doesn't exist
- Added to `.gitignore` to avoid committing large image files

### Example Output
```
Generating trade charts in trade_charts/...
  Generated 10/25 charts...
  Generated 20/25 charts...
Trade charts complete! Saved 25 charts to trade_charts/
```

## Usage

### Standard Mode (No Leverage, No Charts)
```python
USE_LEVERAGE = False
GENERATE_TRADE_CHARTS = False
```

### With Leverage (30x max)
```python
USE_LEVERAGE = True
MAX_LEVERAGE = 30
```

### With Chart Generation
```python
GENERATE_TRADE_CHARTS = True
```

Run the backtest:
```bash
python3 new_trader.py
```

Output will include:
- `trade_journal.csv` - Trade details
- `equity_curve.png` - Equity chart
- `trade_charts/` - Individual trade charts (if enabled)

## Benefits

1. **No Look-Ahead Bias**: Results are realistic and replicable in live trading
2. **Realistic Leverage**: Prevents unrealistic position sizes that would be rejected by brokers
3. **Visual Analysis**: Easy to review each trade setup and outcome with candlestick charts
4. **Trade Review**: Charts help identify good vs bad entries visually
5. **Learning Tool**: See exactly where entries/exits occurred in context

## Technical Details

### Look-Ahead Prevention
- All detection functions use `current_idx` as upper bound
- No access to `df.iloc[idx + 1:]` or future data
- Pattern detection happens "as candles close" in simulation

### Leverage Calculation
- For EURUSD, assumes price around 1.10
- Position value = position_size × current_price
- Leverage = position_value / balance
- Capped at MAX_LEVERAGE

### Chart Performance
- Uses matplotlib for rendering
- High DPI (150) for clarity
- Efficient: ~0.5-1 second per chart
- Progress updates every 10 charts

## Files Changed

1. `new_trader.py`:
   - Added leverage configuration
   - Modified `calculate_position_size()` with leverage limits
   - Added `generate_trade_charts()` function
   - Updated main() to call chart generation

2. `.gitignore`:
   - Added `trade_charts/` to exclude from git

## Verification

All features tested and working:
- ✓ No look-ahead bias (code review)
- ✓ Leverage limits enforced (tested with/without)
- ✓ Charts generated successfully (sample run: 2 trades, 2 charts)
- ✓ Proper file naming and folder creation
- ✓ No errors with 0 trades scenario

## Examples

Check `trade_charts/` folder after running backtest to see:
- Entry/exit points clearly marked
- Price action context (40+ candles)
- SL/TP levels visualized
- Trade outcome at a glance
