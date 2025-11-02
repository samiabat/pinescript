# Quick Start Guide

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/samiabat/pinescript.git
   cd pinescript
   ```

2. **Install dependencies**
   ```bash
   pip install pandas numpy matplotlib
   ```

3. **Verify installation**
   ```bash
   python3 test_system.py
   ```

## Usage

### Option 1: Generate Sample Data (for testing)

```bash
python3 generate_sample_data.py
python3 new_trader.py
```

### Option 2: Use Your Own EURUSD Data

1. Place your EURUSD 15-minute data in `EURUSD15.csv` format:
   ```
   2021-10-29 20:15    1.15614 1.15618 1.15599 1.15615 254
   2021-10-29 20:30    1.15615 1.15617 1.15572 1.15573 321
   ```

2. Run the backtest:
   ```bash
   python3 new_trader.py
   ```

## Output Files

After running the backtest, you'll get:

1. **trade_journal.csv** - Detailed log of all trades
2. **equity_curve.png** - Visual chart of account balance over time
3. **Console output** - Performance metrics and statistics

## Configuration

Edit `new_trader.py` to customize:

```python
CSV_PATH = "EURUSD15.csv"           # Your data file
INITIAL_BALANCE = 10000.0            # Starting capital
RISK_PER_TRADE = 0.01                # 1% risk per trade
MAX_TRADES_PER_DAY = 2               # Max trades per day
MIN_FVG_PIPS = 5                     # Min FVG size in pips
```

## Understanding the Strategy

The ICT strategy requires **ALL** of these conditions to align:

1. ✓ Trading during London/NY session (07:00-16:00 UTC)
2. ✓ Clear 1-hour trend (bullish or bearish)
3. ✓ Liquidity sweep detected
4. ✓ Market structure shift confirmed
5. ✓ Fair value gap present
6. ✓ Quality filters passed (no messy candles, good volume)
7. ✓ Daily trade limit not exceeded

## Example Output

```
================================================================================
BACKTEST PERFORMANCE SUMMARY
================================================================================
Total Trades:        45
Winning Trades:      28
Losing Trades:       17
Win Rate:            62.2%
--------------------------------------------------------------------------------
Total P&L:           $1,850.00
Average Win:         $145.30
Average Loss:        -$95.60
Average P&L:         $41.11
Average R:R:         3.52
--------------------------------------------------------------------------------
Starting Balance:    $10,000.00
Ending Balance:      $11,850.00
Total Return:        18.50%
Max Drawdown:        7.25%
================================================================================
```

## Tips for Best Results

1. **Use Real Data**: The strategy works best with actual market data containing real trends and reversals

2. **Longer Timeframes**: Test on at least 1 year of data for statistical significance

3. **Parameter Optimization**: Adjust MIN_FVG_PIPS, TARGET_MIN_R, and other parameters based on your analysis

4. **Session Filtering**: Default is London+NY sessions (07:00-16:00 UTC). Adjust if needed

5. **Risk Management**: Keep RISK_PER_TRADE at 1% or lower for safety

## Troubleshooting

**No trades executed?**
- This is normal with random/poor quality data
- The strategy is intentionally strict
- Try with real EURUSD data or adjust parameters

**Import errors?**
```bash
pip install pandas numpy matplotlib
```

**Data format errors?**
- Ensure CSV has no header
- Format: `YYYY-MM-DD HH:MM    open high low close volume`
- Use spaces as separators

## Support

For issues or questions, please open an issue on GitHub.
