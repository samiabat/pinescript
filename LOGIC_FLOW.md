# Implementation Logic Flow

## Signal Generation Flow (No Simultaneous Buy/Sell)

```
┌─────────────────────────────────────────────────────────────┐
│                    SIGNAL DETECTION                          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │  Detect All ICT Setups              │
         │  • Bullish Order Block              │
         │  • Bearish Order Block              │
         │  • Bullish FVG                      │
         │  • Bearish FVG                      │
         └─────────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌────────────────────┐            ┌────────────────────┐
│   BUY SIGNAL?      │            │  SELL SIGNAL?      │
├────────────────────┤            ├────────────────────┤
│ IF:                │            │ IF:                │
│ 1. (BullOB OR      │            │ 1. (BearOB OR      │
│    BullFVG)        │            │    BearFVG)        │
│ AND                │            │ AND                │
│ 2. Structure >= 0  │            │ 2. Structure <= 0  │
│ AND                │            │ AND                │
│ 3. NOT (BearOB OR  │◄───────────┤ 3. NOT (BullOB OR  │
│    BearFVG)        │  MUTUAL    │    BullFVG)        │
│                    │  EXCLUSION │                    │
│ THEN: BUY = TRUE   │            │ THEN: SELL = TRUE  │
└────────────────────┘            └────────────────────┘
         │                                   │
         └─────────────────┬─────────────────┘
                           ▼
              ┌────────────────────────┐
              │   ONLY ONE SIGNAL      │
              │   (OR NONE)            │
              │   CAN BE TRUE          │
              └────────────────────────┘
```

## Zone Overlap Prevention Flow

```
┌─────────────────────────────────────────────────────────────┐
│            NEW ZONE DETECTED                                 │
│  Type: Order Block or FVG                                    │
│  Boundaries: top, bottom                                     │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │   hasOverlap(zones, top, bottom)    │
         └─────────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
    ┌─────────┐                        ┌─────────┐
    │  TRUE   │                        │  FALSE  │
    │ (Overlap│                        │(No Over-│
    │  Found) │                        │  lap)   │
    └─────────┘                        └─────────┘
         │                                   │
         ▼                                   ▼
┌──────────────────┐              ┌───────────────────┐
│  REJECT ZONE     │              │  ADD ZONE         │
│  (Not added to   │              │  1. Check max     │
│   array)         │              │     zones (50)    │
└──────────────────┘              │  2. Remove oldest │
                                  │     if needed     │
                                  │  3. Push new zone │
                                  └───────────────────┘
                                            │
                                            ▼
                                  ┌───────────────────┐
                                  │  ZONE STORED IN   │
                                  │  TRACKING ARRAY   │
                                  │  (activeOB or     │
                                  │   activeFVG)      │
                                  └───────────────────┘

Overlap Check Logic:
  NOT (zone1.top < zone2.bottom OR zone2.top < zone1.bottom)
  
  If this is TRUE → zones overlap
  If this is FALSE → zones do NOT overlap
```

## Trade Limiting Flow (Strategy Only)

```
┌─────────────────────────────────────────────────────────────┐
│                  SIGNAL GENERATED                            │
│            (Buy or Sell from detection)                      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────────┐
         │     canTakeTrade() Function         │
         └─────────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
┌────────────────────┐            ┌────────────────────┐
│  BARS CONDITION    │            │  DAILY CONDITION   │
│                    │            │                    │
│ barsSinceLast =    │            │ dailyTradeCount    │
│ current - last     │            │ < maxPerDay        │
│                    │            │                    │
│ barsSinceLast >=   │            │ Example:           │
│ minBars            │            │ count=3, max=5     │
│                    │            │ → TRUE             │
│ Example:           │            │                    │
│ 7 >= 5 → TRUE      │            │ count=5, max=5     │
└────────────────────┘            │ → FALSE            │
         │                        └────────────────────┘
         └─────────────┬──────────────────┘
                       ▼
              ┌────────────────┐
              │   BOTH TRUE?   │
              └────────────────┘
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
    ┌────────┐                  ┌────────┐
    │  YES   │                  │   NO   │
    └────────┘                  └────────┘
         │                           │
         ▼                           ▼
┌─────────────────┐       ┌──────────────────┐
│  EXECUTE TRADE  │       │  REJECT TRADE    │
│  1. Entry       │       │  (Signal visible │
│  2. Set SL/TP   │       │   but no entry)  │
│  3. Update:     │       └──────────────────┘
│     lastTradeBar│
│     dailyCount++│
└─────────────────┘
```

## Daily Counter Reset Flow

```
TIME: 23:59 Day 1           00:00 Day 2
         │                        │
         ▼                        ▼
┌─────────────────┐      ┌─────────────────┐
│ Daily Count = 5 │      │ ta.change(time  │
│ (Limit reached) │      │ ('D')) != 0     │
└─────────────────┘      │ → TRUE          │
                         └─────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ dailyTradeCount │
                         │ := 0            │
                         │ (RESET)         │
                         └─────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ Can take up to  │
                         │ 5 new trades    │
                         │ on Day 2        │
                         └─────────────────┘

Note: Uses time('D') which correctly detects daily session changes
```

## Complete Trade Decision Tree

```
                    ┌─────────────────┐
                    │  New Bar Tick   │
                    └─────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Detect ICT      │
                    │ Patterns        │
                    └─────────────────┘
                             │
                ┌────────────┼────────────┐
                ▼                         ▼
         ┌──────────────┐        ┌──────────────┐
         │ Bullish      │        │ Bearish      │
         │ Detected?    │        │ Detected?    │
         └──────────────┘        └──────────────┘
                │                         │
                ▼                         ▼
         ┌──────────────┐        ┌──────────────┐
         │ Market       │        │ Market       │
         │ Structure    │        │ Structure    │
         │ Bullish?     │        │ Bearish?     │
         └──────────────┘        └──────────────┘
                │                         │
                ▼                         ▼
         ┌──────────────┐        ┌──────────────┐
         │ No Bearish   │        │ No Bullish   │
         │ Signals?     │        │ Signals?     │
         └──────────────┘        └──────────────┘
                │                         │
                ▼                         ▼
         ┌──────────────┐        ┌──────────────┐
         │ canTakeTrade │        │ canTakeTrade │
         │ () = TRUE?   │        │ () = TRUE?   │
         └──────────────┘        └──────────────┘
                │                         │
                ▼                         ▼
         ┌──────────────┐        ┌──────────────┐
         │ ENTER LONG   │        │ ENTER SHORT  │
         │ • Calculate  │        │ • Calculate  │
         │   SL/TP      │        │   SL/TP      │
         │ • Place order│        │ • Place order│
         │ • Update     │        │ • Update     │
         │   counters   │        │   counters   │
         └──────────────┘        └──────────────┘

If ANY condition fails → NO TRADE
All conditions must pass → TRADE EXECUTED
```

## Key Implementation Guarantees

### 1. No Overlapping Zones
- **Mechanism**: Coordinate-based overlap detection
- **Check**: Before adding any zone
- **Result**: Clean, non-overlapping visual zones

### 2. No Simultaneous Signals
- **Mechanism**: Mutual exclusion in signal conditions
- **Check**: `not (oppositeSignals)` in each condition
- **Result**: Only buy OR sell OR no signal (never both)

### 3. Trade Spacing
- **Mechanism**: Bar index tracking
- **Check**: Before every trade entry
- **Result**: Minimum bars enforced between consecutive trades

### 4. Daily Limit
- **Mechanism**: Counter with daily reset
- **Check**: Before every trade entry
- **Result**: Maximum trades per day never exceeded

### 5. Zone Memory Management
- **Mechanism**: FIFO queue with max size
- **Check**: On every zone addition
- **Result**: Memory efficient, no overflow

## Testing Validation

All logic flows have been verified through:
✅ Code review (PASSED - no issues)
✅ Logical analysis (documented in VERIFICATION.md)
✅ Edge case consideration
✅ Manual trace-through of key scenarios
✅ Proper variable scoping and state management
