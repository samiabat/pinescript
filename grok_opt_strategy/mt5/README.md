# Grok Optimized Strategy - MT5 Expert Advisor

## Overview

This directory contains the MetaTrader 5 Expert Advisor (EA) implementation of the Grok Optimized trading strategy. The EA is designed to automatically execute trades based on the strategy logic from the Python implementation.

## Files

- **GrokOptEA.mq5**: Main Expert Advisor file
- **README.md**: This file (installation and usage guide)

## Installation

### Prerequisites

1. **MetaTrader 5 Platform**
   - Download from: https://www.metatrader5.com/
   - Install on Windows (recommended) or use Wine for Linux/Mac

2. **Active Trading Account**
   - Demo account (recommended for testing)
   - Live account (for production trading)

### Step-by-Step Installation

#### Step 1: Locate MT5 Data Folder

1. Open MetaTrader 5
2. Click **File** → **Open Data Folder**
3. This opens the MT5 data directory

#### Step 2: Copy Expert Advisor

1. Navigate to `MQL5\Experts\` folder in the data directory
2. Create a folder named `GrokOpt` (optional, for organization)
3. Copy `GrokOptEA.mq5` to this location

Path example: `C:\Users\YourName\AppData\Roaming\MetaQuotes\Terminal\[instance_id]\MQL5\Experts\GrokOptEA.mq5`

#### Step 3: Compile the EA

1. Open MetaEditor (Press F4 in MT5 or Tools → MetaQuotes Language Editor)
2. Open `GrokOptEA.mq5` from the Navigator window (File → Open)
3. Click **Compile** button (F7) or Compile → Compile
4. Check for errors in the Errors tab (should show 0 errors, 0 warnings)

#### Step 4: Refresh MT5

1. Return to MT5 main window
2. Right-click in the Navigator window → **Refresh**
3. The EA should now appear under Expert Advisors

## Configuration

### EA Parameters

The Expert Advisor has several configurable parameters:

#### Trading Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| RiskPercent | 2.0 | Risk per trade as percentage of account balance |
| StopLossPips | 50 | Stop loss distance in pips |
| TakeProfitPips | 100 | Take profit distance in pips |
| LotSize | 0.01 | Fixed lot size (0 = automatic calculation) |

#### Strategy Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| FastMA | 10 | Fast moving average period |
| SlowMA | 20 | Slow moving average period |
| RSI_Period | 14 | RSI indicator period |
| RSI_Oversold | 30 | RSI oversold level |
| RSI_Overbought | 70 | RSI overbought level |

**Note**: These are placeholder parameters. Adjust based on your actual `grok_opt.py` strategy logic.

#### Trading Hours

| Parameter | Default | Description |
|-----------|---------|-------------|
| StartHour | 0 | Trading start hour (0-23) |
| EndHour | 23 | Trading end hour (0-23) |
| TradeMonday | true | Enable trading on Monday |
| TradeTuesday | true | Enable trading on Tuesday |
| TradeWednesday | true | Enable trading on Wednesday |
| TradeThursday | true | Enable trading on Thursday |
| TradeFriday | true | Enable trading on Friday |

#### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| MaxDailyLoss | 100.0 | Maximum daily loss in account currency |
| MaxDailyProfit | 200.0 | Maximum daily profit (stops trading when reached) |
| MaxOpenTrades | 1 | Maximum number of concurrent trades |

#### General Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| MagicNumber | 123456 | Unique identifier for EA trades |
| TradeComment | "GrokOpt" | Comment added to trades |
| EnableLogging | true | Enable detailed logging to Experts tab |

## Usage

### Attaching the EA to a Chart

1. Open MT5
2. Open a chart for your desired symbol (e.g., EURUSD)
3. Set your preferred timeframe (e.g., H1, H4, D1)
4. Locate the EA in Navigator → Expert Advisors
5. Drag and drop `GrokOptEA` onto the chart
6. A settings dialog will appear

### Configuring the EA

1. **Common Tab**:
   - ✅ Check "Allow Algo Trading"
   - Set positions: "Only Long", "Only Short", or "Long & Short"

2. **Inputs Tab**:
   - Review and adjust all parameters
   - Recommended to keep defaults for initial testing

3. **Dependencies Tab**:
   - Ensure DLL imports are allowed if needed
   - For this EA, no special DLLs are required

4. Click **OK** to activate the EA

### Verifying EA is Running

1. Check the chart top-right corner for smiley face icon:
   - 😊 Green smiley = EA is running
   - 😐 Gray smiley = EA is disabled
   - ❌ Red cross = Error (check settings)

2. Check the Experts tab (View → Toolbox → Experts):
   - Should show initialization message
   - Monitor for trade signals and execution logs

### Enabling Algo Trading

If EA is not running (gray smiley):

1. Click **Tools** → **Options** → **Expert Advisors**
2. ✅ Check "Allow Algorithmic Trading"
3. Click **OK**
4. Click "Algo Trading" button in toolbar (or press Ctrl+E)

## Backtesting

See the [Backtesting Guide](../docs/backtesting_guide.md) for comprehensive instructions.

### Quick Backtesting Steps

1. Open Strategy Tester (View → Strategy Tester or Ctrl+R)
2. Select `GrokOptEA` from Expert Advisor dropdown
3. Configure test parameters:
   - Symbol: EURUSD (or your choice)
   - Period: M15, H1, H4, or D1
   - Date range: Last 1 year recommended
   - Deposit: 10000 (or your amount)
   - Leverage: Same as your account
4. Click **Inputs** tab to adjust EA parameters
5. Click **Start** to run the backtest
6. Review results in Results, Graph, and Report tabs

## Forward Testing

See the [Forward Testing Guide](../docs/forward_testing_guide.md) for comprehensive instructions.

### Quick Forward Testing Steps

1. Use a **demo account** (highly recommended)
2. Attach EA to chart as described in Usage section
3. Set conservative parameters:
   - Lower risk percentage (e.g., 1%)
   - Smaller lot sizes
4. Monitor for at least 1-2 weeks
5. Review performance daily
6. Only move to live account after consistent demo results

## Customization

### Adapting to Your grok_opt.py Strategy

The current implementation uses a simple MA crossover as a placeholder. To match your Python strategy:

1. Open `GrokOptEA.mq5` in MetaEditor
2. Locate the `GetTradingSignal()` function
3. Replace the placeholder logic with your strategy conditions:
   - Entry signals from `grok_opt.py`
   - Exit conditions
   - Risk management rules
4. Add any required indicators or calculations
5. Recompile the EA (F7)

### Example Customizations

```mql5
// Example: Adding ATR-based stop loss
input int ATR_Period = 14;
input double ATR_Multiplier = 2.0;

// In GetTradingSignal or position management:
int atrHandle = iATR(_Symbol, _Period, ATR_Period);
double atr[];
CopyBuffer(atrHandle, 0, 0, 1, atr);
double dynamicSL = atr[0] * ATR_Multiplier;
```

## Monitoring and Maintenance

### Daily Checks

1. ✅ Verify EA is running (green smiley)
2. ✅ Check daily P&L in Journal
3. ✅ Review any error messages
4. ✅ Ensure account balance is sufficient

### Weekly Reviews

1. Analyze trade performance
2. Compare with Python backtest results
3. Adjust parameters if needed
4. Review and update stop losses if manual management is enabled

## Troubleshooting

### EA Not Trading

**Problem**: EA attached but no trades are executed

**Solutions**:
1. Check Algo Trading is enabled (green button)
2. Verify trading hours are within allowed range
3. Check account has sufficient margin
4. Review Experts tab for error messages
5. Ensure symbol is tradable (market is open)

### Compilation Errors

**Problem**: EA won't compile

**Solutions**:
1. Verify MT5 build is up to date (Help → About)
2. Check syntax errors in Errors tab
3. Ensure all required indicators are available
4. Review code for typos or syntax issues

### Trades Not Following Strategy

**Problem**: EA opens trades that don't match expected signals

**Solutions**:
1. Review `GetTradingSignal()` logic
2. Add debug prints to trace signal generation
3. Compare with Python strategy conditions
4. Check timeframe matches expectations

### High Drawdown

**Problem**: Account experiencing large drawdowns

**Solutions**:
1. Reduce risk percentage
2. Increase stop loss distance
3. Limit trading hours to high-probability periods
4. Reduce maximum concurrent trades
5. Review and optimize entry conditions

## Performance Optimization

### Parameter Optimization

1. Use Strategy Tester Optimization
2. Select key parameters to optimize
3. Use genetic algorithm for efficiency
4. Validate results with forward testing
5. Avoid over-optimization (curve fitting)

### Recommended Optimization Parameters

- Risk percent (1.0 - 3.0)
- Stop loss (30 - 100 pips)
- Take profit (50 - 200 pips)
- MA periods (adjust based on timeframe)
- RSI levels (fine-tune oversold/overbought)

## Safety Recommendations

### Before Going Live

1. ✅ Test on demo account for minimum 1 month
2. ✅ Verify win rate matches backtest expectations
3. ✅ Ensure maximum drawdown is acceptable
4. ✅ Test during different market conditions
5. ✅ Have emergency stop procedures in place

### Risk Management

1. Never risk more than 2% per trade
2. Set maximum daily loss limits
3. Monitor total account exposure
4. Keep emergency capital reserve
5. Regularly withdraw profits

## Support Files

- Strategy Analysis: [../docs/strategy_analysis.md](../docs/strategy_analysis.md)
- Backtesting Guide: [../docs/backtesting_guide.md](../docs/backtesting_guide.md)
- Forward Testing Guide: [../docs/forward_testing_guide.md](../docs/forward_testing_guide.md)

## Next Steps

1. Install the EA following the installation guide above
2. Run backtests to validate performance (see [Backtesting Guide](../docs/backtesting_guide.md))
3. Forward test on demo account (see [Forward Testing Guide](../docs/forward_testing_guide.md))
4. Customize `GetTradingSignal()` to match your `grok_opt.py` logic
5. Gradually transition to live trading with conservative settings

## Version History

- **v1.00** (Initial Release)
  - Basic MA crossover with RSI filter
  - Risk management and position sizing
  - Daily profit/loss limits
  - Trading hours control

## License

See main repository license for details.
