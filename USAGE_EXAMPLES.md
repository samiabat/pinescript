# Trading Session SAMI - Usage Examples

## Installation Steps

### Step 1: Copy the Pine Script Code
1. Open the file `trading_session_sami.pine` in this repository
2. Copy all the code (Ctrl+A, Ctrl+C)

### Step 2: Add to TradingView
1. Go to [TradingView](https://www.tradingview.com)
2. Open any chart (recommended: EURUSD, GBPUSD, or any forex pair on 15min-1H timeframe)
3. Click on "Pine Editor" tab at the bottom of the screen
4. Delete any existing code in the editor
5. Paste the copied code (Ctrl+V)
6. Click "Save" and give it a name (e.g., "Trading Session SAMI")
7. Click "Add to Chart"

## Visual Guide

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRADING SESSION SAMI                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Time →                                                        │
│   ┌────────────┐                                               │
│   │    ASIA    │   (Blue Box)                                  │
│   │            │   00:00-09:00 UTC                             │
│   └────────────┘                                               │
│                                                                 │
│        ┌───────────────┐                                       │
│        │    LONDON     │   (Orange Box)                        │
│        │               │   07:00-16:00 UTC                     │
│        └───────────────┘                                       │
│                                                                 │
│              ┌─────────────────┐                               │
│              │    NEW YORK     │   (Green Box)                 │
│              │                 │   13:00-22:00 UTC             │
│              └─────────────────┘                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## What You'll See on Your Chart

### 1. **Session Boxes**
Each trading session is represented by a colored box:
- **Height**: From session HIGH to session LOW
- **Width**: From session start to session end
- **Colors**: 
  - 🔵 Blue = Asia
  - 🟠 Orange = London
  - 🟢 Green = New York

### 2. **Session Labels**
- Text labels appear at the top-center of each box
- Shows session name: "ASIA", "LONDON", or "NEW YORK"
- Easy to identify which session is which

### 3. **Live Session Lines** (During Active Session)
- Horizontal lines show current high/low while session is active
- Disappears when session ends and box is drawn

## Configuration Options

Click on the indicator name on the chart, then click the ⚙️ (gear icon) to access settings:

### Session Visibility
- ☑️ **Show Asia Session** - Toggle Asia session on/off
- ☑️ **Show London Session** - Toggle London session on/off  
- ☑️ **Show New York Session** - Toggle New York session on/off

### Color Customization
- **Asia Color** - Change the blue box color
- **London Color** - Change the orange box color
- **New York Color** - Change the green box color

## Trading Applications

### 1. **Liquidity Sweeps**
Watch for price to:
- Break above Asia high → then reverse (sell opportunity)
- Break below Asia low → then reverse (buy opportunity)

### 2. **Session Breakouts**
- Trade breakouts of London session high/low during New York session
- Use Asia session range as a reference for the day

### 3. **Range Trading**
- Trade within session ranges when price is consolidating
- Session highs/lows act as support/resistance

### 4. **ICT Concepts**
- **Asia Session** = Liquidity pool formation
- **London Session** = Initial sweep and manipulation
- **New York Session** = True directional move

### Example Trading Scenarios

#### Scenario 1: London Open Sweep
```
1. Asia session forms a range (Blue box)
2. London opens and sweeps Asia high (Orange box extends above Blue)
3. Price rejects and reverses down
4. Entry: Short position after rejection
5. Stop: Above London high
6. Target: Asia low or New York session low
```

#### Scenario 2: New York Breakout
```
1. Asia + London form consolidated range
2. New York session breaks above both sessions
3. Entry: Long position on breakout
4. Stop: Below London high
5. Target: 1.5x or 2x the range
```

## Best Practices

### Timeframes
✅ **Recommended**: 15min, 30min, 1H
❌ **Not recommended**: 4H, Daily (sessions overlap too much)

### Instruments
✅ **Best**: Forex pairs (EURUSD, GBPUSD, USDJPY)
✅ **Good**: Gold (XAUUSD), Indices (US30, NAS100)
❌ **Poor**: Crypto (24/7 markets don't follow traditional sessions)

### Session Times Reference

| Your Location | Asia | London | New York |
|---------------|------|--------|----------|
| **UTC/GMT** | 00:00-09:00 | 07:00-16:00 | 13:00-22:00 |
| **EST (New York)** | 19:00-04:00 | 02:00-11:00 | 08:00-17:00 |
| **GMT+1 (London)** | 01:00-10:00 | 08:00-17:00 | 14:00-23:00 |
| **GMT+8 (Singapore)** | 08:00-17:00 | 15:00-00:00 | 21:00-06:00 |

## Troubleshooting

### Problem: No boxes appearing
**Solution**: 
- Check if you're on a timeframe ≤ 1H
- Verify indicator is enabled (checkmark next to name)
- Make sure at least one session toggle is ON in settings

### Problem: Boxes in wrong location
**Solution**:
- Check your chart's timezone setting
- The indicator uses UTC times, TradingView converts automatically
- Go to Chart Settings → Symbol → Timezone

### Problem: Too many boxes cluttering chart
**Solution**:
- Zoom out on the chart to see fewer sessions
- Disable sessions you don't need
- Use the indicator on higher timeframes

### Problem: Labels overlapping
**Solution**:
- Zoom in on the chart
- This is normal on very small timeframes with many sessions
- Consider using 30min or 1H timeframe

## Tips for Maximum Effectiveness

1. **Combine with Price Action**: Use the session boxes with candlestick patterns
2. **Wait for Confirmation**: Don't trade immediately on session open/close
3. **Mark Key Levels**: Note significant session highs/lows for the week
4. **Track Patterns**: Observe which sessions tend to create the most movement
5. **Use with Other Indicators**: Combine with RSI, MACD, or moving averages

## Advanced Usage

### Multi-Timeframe Analysis
1. Keep indicator on 15min chart for precise session ranges
2. Check 1H chart for overall trend direction
3. Enter trades on 15min when aligned with 1H trend

### Session Correlation
- **High correlation pairs**: EURUSD, GBPUSD (both active during London)
- **Session-specific pairs**: 
  - USDJPY (most active during Asia & New York)
  - GBPUSD (most active during London)
  - EURUSD (active during London & New York)

### Weekly Planning
1. On Monday, mark previous week's key session levels
2. Note which sessions created the most volatility
3. Plan your trading schedule around most active sessions

## Performance Checklist

After using the indicator for a few weeks, review:

- [ ] Are you identifying session ranges correctly?
- [ ] Are trades taken at session highs/lows performing well?
- [ ] Which session provides best trading opportunities?
- [ ] Are you waiting for proper confirmation before entry?
- [ ] Are you managing risk properly at session boundaries?

## Example Trade Journal Entry

```
Date: [Date]
Pair: EURUSD
Timeframe: 15min
Session: London
Setup: Asia high liquidity sweep
Entry: 1.0850 (after rejection of Asia high)
Stop: 1.0870 (above London high)
Target: 1.0810 (Asia low)
Risk/Reward: 1:2
Result: [Win/Loss]
Notes: Clean rejection of Asia high at London open, 
       good follow-through during London session
```

## Support & Resources

- **Pine Script Documentation**: https://www.tradingview.com/pine-script-docs/
- **TradingView Community**: https://www.tradingview.com/community/
- **Repository Issues**: [Report bugs or request features](https://github.com/samiabat/pinescript/issues)

## Remember

⚠️ **Trading Risk Warning**
- This indicator is a tool, not a trading system
- Always use proper risk management
- Past performance doesn't guarantee future results
- Never risk more than you can afford to lose

✅ **Best Practices**
- Test on demo account first
- Start with small position sizes
- Keep a trading journal
- Review and adjust strategy regularly

---

**Happy Trading! 📈**

*For technical documentation, see [TRADING_SESSION_SAMI_README.md](TRADING_SESSION_SAMI_README.md)*
