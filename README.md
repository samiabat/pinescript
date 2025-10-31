# ICT Pine Script Indicator and Strategy

This repository contains two Pine Script v5 files implementing Inner Circle Trader (ICT) concepts for trading on TradingView.

## Files

1. **ict_indicator.pine** - ICT Concepts Indicator
2. **ict_strategy.pine** - ICT Strategy Tester

## Features

### ICT Indicator (`ict_indicator.pine`)

The indicator implements key ICT trading concepts:

#### Core ICT Concepts Implemented

1. **Order Blocks (OB)**
   - Bullish Order Block: Last down candle before a strong upward move
   - Bearish Order Block: Last up candle before a strong downward move
   - Visual representation with filled boxes on the chart

2. **Fair Value Gaps (FVG)**
   - Bullish FVG: Gap between candle[2] high and current candle low (gap up)
   - Bearish FVG: Gap between candle[2] low and current candle high (gap down)
   - Displayed as dashed boxes to differentiate from order blocks

3. **Market Structure Analysis**
   - Higher Highs (HH) detection
   - Lower Lows (LL) detection
   - Market structure shift identification

#### Key Anti-Overlap Features

- **Non-overlapping Zones**: The indicator prevents overlapping order blocks and FVGs
- **Zone Tracking**: Uses custom type arrays to manage active zones
- **Automatic Cleanup**: Removes old zones after a specified number of bars
- **Conflict Prevention**: Ensures buy and sell signals don't appear simultaneously

#### Signal Generation

- **Buy Signals**: Generated when bullish setups are detected with supportive market structure
- **Sell Signals**: Generated when bearish setups are detected with supportive market structure
- **Signal Spacing**: Prevents rapid-fire signals from the same type
- **No Simultaneous Signals**: Logic ensures buy and sell signals never conflict

### ICT Strategy Tester (`ict_strategy.pine`)

The strategy file includes all indicator features plus trade execution logic:

#### Trade Management Features

1. **Trade Limiting**
   - Minimum bars between consecutive trades (configurable, default: 5 bars)
   - Maximum trades per day (configurable, default: 5 trades)
   - Daily counter automatically resets at the start of each new trading day

2. **Risk Management**
   - Configurable stop loss percentage
   - Configurable take profit percentage
   - Automatic position sizing based on equity percentage

3. **Performance Metrics**
   - Real-time display of daily trade count
   - Bars since last trade counter
   - Trade availability status indicator
   - Full TradingView strategy metrics (win rate, profit factor, etc.)

## Usage Instructions

### Loading the Indicator

1. Open TradingView
2. Open the Pine Editor (bottom panel)
3. Create a new indicator
4. Copy the contents of `ict_indicator.pine`
5. Click "Add to Chart"
6. Adjust settings as needed:
   - Order Block Lookback (default: 20)
   - FVG Lookback (default: 3)
   - Market Structure Lookback (default: 10)
   - Display options (show/hide zones and signals)

### Loading the Strategy

1. Open TradingView
2. Open the Pine Editor
3. Create a new strategy
4. Copy the contents of `ict_strategy.pine`
5. Click "Add to Chart"
6. Configure strategy settings:
   - ICT detection parameters (same as indicator)
   - Trade limiting: Min bars between trades, max trades per day
   - Risk management: Stop loss %, Take profit %
7. View performance in the "Strategy Tester" tab

## Configuration Parameters

### ICT Detection Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Order Block Lookback | 20 | Number of bars to look back for order block detection |
| Min Order Block Size | 0.0001 | Minimum size for valid order blocks |
| FVG Lookback | 3 | Number of bars for FVG detection |
| Min FVG Size | 0.0001 | Minimum gap size for valid FVGs |
| Market Structure Lookback | 10 | Bars to analyze for market structure |

### Trade Management (Strategy Only)

| Parameter | Default | Description |
|-----------|---------|-------------|
| Min Bars Between Trades | 5 | Minimum bars required between consecutive trades |
| Max Trades Per Day | 5 | Maximum number of trades allowed per day |
| Stop Loss % | 1.5% | Stop loss percentage from entry |
| Take Profit % | 3.0% | Take profit percentage from entry |

### Display Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| Show Order Blocks | true | Display order block zones |
| Show Fair Value Gaps | true | Display FVG zones |
| Show Buy/Sell Signals | true | Display signal labels |
| Bullish Zone Color | Green (80% transparent) | Color for bullish zones |
| Bearish Zone Color | Red (80% transparent) | Color for bearish zones |

## How It Works

### Order Block Detection

Order blocks are identified by finding candles that preceded significant price movements:

- **Bullish OB**: A down candle followed by strong upward momentum (>2x the candle range)
- **Bearish OB**: An up candle followed by strong downward momentum (>2x the candle range)

### Fair Value Gap Detection

FVGs represent price inefficiencies:

- **Bullish FVG**: Current candle's low is above the high of the candle 2 bars ago
- **Bearish FVG**: Current candle's high is below the low of the candle 2 bars ago

### Non-Overlapping Zone Management

The scripts use custom type arrays to track active zones:

1. When a new zone is detected, it checks for overlap with existing zones
2. If no overlap exists, the zone is added to the tracking array
3. Old zones are automatically removed after a configurable number of bars
4. Maximum zone limit prevents memory issues (default: 50 zones)

### Signal Conflict Prevention

Buy and sell signals are mutually exclusive:

1. Detection logic checks for both bullish and bearish setups
2. If both are present, neither signal is generated
3. Market structure must support the signal direction
4. Minimum spacing between same-type signals is enforced

### Trade Limiting Mechanism (Strategy)

The strategy implements multiple layers of trade control:

1. **Consecutive Trade Prevention**:
   - Tracks the bar index of the last trade
   - Requires minimum bars to pass before allowing the next trade
   - Prevents overtrading in choppy markets

2. **Daily Trade Limit**:
   - Counts trades executed each day
   - Resets counter at the start of each new trading day
   - Stops trading once daily limit is reached
   - Visual indicator shows current count and status

## ICT Concepts Explained

### Order Blocks
Order blocks represent areas where institutional traders placed significant orders. These zones often act as support or resistance when price returns to them.

### Fair Value Gaps (FVG)
FVGs are price ranges where little to no trading occurred, creating an imbalance. Price tends to return to fill these gaps.

### Market Structure
Market structure refers to the sequence of higher highs/lows (uptrend) or lower highs/lows (downtrend). Shifts in structure can signal trend changes.

## Best Practices

1. **Timeframe Selection**: Works on all timeframes, but 15m-4H recommended for day trading
2. **Asset Selection**: Best suited for liquid markets (forex majors, indices, crypto)
3. **Parameter Tuning**: Adjust lookback periods based on volatility and timeframe
4. **Trade Limits**: Stricter limits (fewer trades, more spacing) improve win rate
5. **Combine with Other Analysis**: Use with trend analysis and support/resistance

## Backtesting Tips

1. Test on at least 3-6 months of historical data
2. Adjust trade limits based on your trading style
3. Monitor the strategy tester performance metrics
4. Pay attention to drawdown and consecutive losses
5. Test different timeframes to find optimal settings

## Performance Metrics (Strategy)

The strategy provides comprehensive metrics through TradingView's Strategy Tester:

- Total trades and win rate
- Profit factor and Sharpe ratio
- Maximum drawdown
- Average trade duration
- Win/loss ratio
- And many more...

Additionally, an on-chart table displays:
- Current daily trade count
- Bars since last trade
- Trade availability status

## Troubleshooting

**No zones appearing on chart:**
- Reduce minimum size parameters
- Adjust lookback periods
- Check if market has sufficient volatility

**Too many/too few signals:**
- Adjust market structure lookback
- Modify order block detection sensitivity
- Change minimum spacing between signals

**Strategy not taking trades:**
- Check daily trade limit hasn't been reached
- Verify minimum bars between trades setting
- Ensure position size settings are correct

## Limitations

- Scripts use TradingView's maximum box/line limits (500 each)
- Zone overlap prevention may miss some valid setups
- Daily trade reset is based on session changes, not exact UTC time
- Performance depends on clean price data and liquidity

## Version

- Pine Script Version: 5
- Compatible with: TradingView (all plans)

## License

These scripts are provided as-is for educational and trading purposes.

## Disclaimer

Trading involves risk. Past performance does not guarantee future results. These scripts are tools to assist in trading decisions but should not be the sole basis for trading. Always practice proper risk management and consider consulting with a financial advisor.
