# Trading Session SAMI Indicator

A TradingView Pine Script indicator that displays trading sessions with colored boxes and labels.

## 📊 Features

- **Asia Session** - Blue colored box (00:00-09:00 UTC)
- **London Session** - Orange colored box (07:00-16:00 UTC)
- **New York Session** - Green colored box (13:00-22:00 UTC / 08:00-17:00 EST)

Each session displays:
- A colored box from the session's high to low
- A label showing the session name
- Real-time lines showing current session high/low while the session is active

## 🚀 How to Use

### Installation in TradingView

1. Open TradingView (https://www.tradingview.com)
2. Click on "Pine Editor" at the bottom of the chart
3. Copy the entire contents of `trading_session_sami.pine`
4. Paste into the Pine Editor
5. Click "Add to Chart"

### Configuration

The indicator includes customizable settings:

#### Session Visibility
- **Show Asia Session** - Toggle Asia session display (default: ON)
- **Show London Session** - Toggle London session display (default: ON)
- **Show New York Session** - Toggle New York session display (default: ON)

#### Colors
- **Asia Color** - Customize Asia session box color (default: Blue with 85% transparency)
- **London Color** - Customize London session box color (default: Orange with 85% transparency)
- **New York Color** - Customize New York session box color (default: Green with 85% transparency)

## ⏰ Session Times

The indicator uses the following session times in UTC:

| Session | UTC Time | New York Time (EST/EDT) |
|---------|----------|-------------------------|
| Asia | 00:00 - 09:00 | 19:00 - 04:00 (previous day) |
| London | 07:00 - 16:00 | 02:00 - 11:00 / 03:00 - 12:00 |
| New York | 13:00 - 22:00 | 08:00 - 17:00 / 09:00 - 18:00 |

**Note**: The times adjust automatically for Daylight Saving Time based on your TradingView timezone settings.

## 📈 How It Works

1. **Session Detection**: The indicator detects when each trading session starts and ends
2. **High/Low Tracking**: During an active session, it tracks the highest high and lowest low
3. **Box Drawing**: When a session ends, it draws a box from the session high to low
4. **Label Display**: A label with the session name is placed at the top-center of each box
5. **Live Updates**: While a session is active, horizontal lines show the current high/low

## 💡 Trading Applications

This indicator is useful for:

- **Session-based trading strategies** - Identify key liquidity zones during different sessions
- **Breakout trading** - Watch for breaks above/below session highs/lows
- **Range trading** - Trade within session ranges
- **Liquidity analysis** - Understand where liquidity was swept during each session
- **ICT concepts** - Identify Asia liquidity, London Open sweeps, and New York session manipulation

## 🎨 Visual Example

```
             ASIA
    ┌─────────────────────┐
    │                     │ ← Asia High (Blue)
    │    Blue Box         │
    │                     │ ← Asia Low
    └─────────────────────┘

              LONDON
    ┌─────────────────────┐
    │                     │ ← London High (Orange)
    │   Orange Box        │
    │                     │ ← London Low
    └─────────────────────┘

            NEW YORK
    ┌─────────────────────┐
    │                     │ ← NY High (Green)
    │    Green Box        │
    │                     │ ← NY Low
    └─────────────────────┘
```

## ⚙️ Technical Details

- **Pine Script Version**: v5
- **Overlay**: Yes (displays on price chart)
- **Max Boxes**: 500
- **Max Labels**: 500

## 📝 Customization Tips

1. **Adjust Transparency**: Change the transparency value in the color settings (0-100) for more/less visible boxes
2. **Session Times**: Edit the session time strings in the code if you need different hours
3. **Box Style**: Modify border width, border color, or background color in the code
4. **Label Position**: Change `label.style_label_down` to `label.style_label_up` to place labels below boxes

## ⚠️ Important Notes

- The indicator works best on timeframes of 1 hour or lower (15min, 30min, 1H recommended)
- Session times are based on UTC and will adjust for your chart's timezone
- Historical boxes are drawn after each session closes
- Maximum of 500 boxes and labels can be displayed (older ones are automatically removed)

## 🔧 Troubleshooting

**Issue**: Boxes not appearing
- **Solution**: Make sure you're viewing a timeframe of 1 hour or lower
- **Solution**: Check that the session toggle is enabled in settings

**Issue**: Wrong session times
- **Solution**: Verify your TradingView timezone settings
- **Solution**: Sessions are defined in UTC; adjust times in the code if needed

**Issue**: Too many boxes cluttering the chart
- **Solution**: Zoom out or use a higher timeframe
- **Solution**: Disable sessions you don't need

## 📖 Version History

### v1.0 - Initial Release
- Asia, London, and New York session boxes
- Customizable colors and visibility
- Session labels
- Real-time high/low lines during active sessions

## 🤝 Contributing

Feel free to suggest improvements or report issues!

## 📜 License

Free to use and modify for personal and commercial trading.

## ⚖️ Disclaimer

This indicator is for informational purposes only. Past session ranges do not guarantee future performance. Always use proper risk management when trading.

---

**Happy Trading! 📈**
