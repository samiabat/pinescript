# ICT Smart Money Backtest for Gold (XAUUSD)

This is a specialized version of the ICT backtest system optimized for Gold (XAUUSD) trading.

## Key Differences from EURUSD Version

### 1. Pip Value
- **Gold**: 1 pip = $0.10 per unit (0.01 lot)
- **EURUSD**: 1 pip = $0.0001 per unit

### 2. Volatility Parameters
Gold is more volatile than EURUSD, so parameters are adjusted:

- `MIN_FVG_PIPS = 50` (vs 5 for EURUSD) - Gold moves in larger swings
- `STOP_LOSS_BUFFER_PIPS = 20` (vs 2 for EURUSD) - More breathing room

### 3. Data File
- Place your `XAUUSD15.csv` file in the parent directory
- Format: Same as EURUSD - no header, space-separated: `date time open high low close volume`

## Configuration

```python
CSV_PATH = "XAUUSD15.csv"            # Your Gold data file
INITIAL_BALANCE = 10000.0            # Starting capital
RISK_PER_TRADE = 0.01                # 1% risk per trade

# Gold-specific parameters
MIN_FVG_PIPS = 50                    # Minimum FVG size in pips
STOP_LOSS_BUFFER_PIPS = 20           # Buffer beyond sweep extreme
```

## Usage

```bash
cd gold_trader
python3 gold_trader.py
```

## Expected Performance

With real 4-year Gold data and `RELAXED_MODE = True`, the system should achieve:
- High profitability (similar to EURUSD 6000%+ potential)
- Position sizing automatically accounts for Gold's pip value
- Charts saved to `trade_charts/` folder

## Outputs

- `trade_journal.csv` - All trade details
- `equity_curve.png` - Account balance over time
- `trade_charts/` - Individual trade visualizations

## Notes

- Gold trades during London + NY sessions (07:00-16:00 UTC)
- Max 2 trades per day
- Strict ICT rules: Liquidity Sweep + MSS + FVG required
- No look-ahead bias
- Deterministic results (no randomness)
