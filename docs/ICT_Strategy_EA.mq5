//+------------------------------------------------------------------+
//|                                              ICT_Strategy_EA.mq5 |
//|                                    ICT Trading Strategy Expert   |
//|                     Based on Fair Value Gaps and Liquidity Sweeps |
//+------------------------------------------------------------------+
#property copyright "ICT Strategy Implementation"
#property link      "https://github.com/samiabat/pinescript"
#property version   "1.00"
#property strict

//--- Input Parameters
input group "=== Risk Management ==="
input double   InpRiskPercent = 1.5;          // Risk per trade (%)
input int      InpMaxTradesPerDay = 40;       // Max trades per day (matching Python)
input double   InpMaxDailyLoss = 5.0;         // Max daily loss (%)
input double   InpMinBalance = 100.0;         // Minimum balance threshold

input group "=== ICT Parameters ==="
input double   InpMinFVGPips = 2.0;           // Minimum FVG size (pips) - matching Python
input double   InpSweepRejectionPips = 0.5;   // Sweep rejection (pips) - matching Python
input double   InpStopLossBufferPips = 2.0;   // Stop loss buffer (pips)
input double   InpTargetMinR = 3.0;           // Minimum R:R ratio
input double   InpTargetMaxR = 5.0;           // Maximum R:R ratio
input int      InpFVGConfirmCandles = 0;      // FVG confirmation candles (0 = immediate entry)

input group "=== Trading Sessions (UTC) ==="
input int      InpLondonOpenHour = 7;         // London open hour
input int      InpLondonCloseHour = 16;       // London close hour
input int      InpNYOpenHour = 12;            // NY open hour
input int      InpNYCloseHour = 21;           // NY close hour

input group "=== Trend Detection ==="
input int      InpTrendLookback = 32;         // Trend lookback candles
input bool     InpRelaxedMode = true;         // Allow trading without trend

input group "=== Advanced Settings ==="
input int      InpMagicNumber = 12345;        // EA Magic Number
input string   InpTradeComment = "ICT_EA";    // Trade comment
input int      InpSlippage = 30;              // Slippage in points
input bool     InpEnableTrailing = false;     // Enable trailing stop

//--- Global Variables
datetime g_lastBarTime = 0;
int g_tradesOpenedToday = 0;
double g_dailyPnL = 0.0;
datetime g_currentDay = 0;

//--- Structures
struct SweepData
{
   bool     isValid;
   string   type;           // "bull_sweep" or "bear_sweep"
   double   price;
   datetime time;
   int      barIndex;
   string   trend;
};

struct FVGData
{
   bool     isValid;
   string   type;           // "bullish" or "bearish"
   double   top;
   double   bottom;
   int      barIndex;
};

//--- Arrays for storing sweep data
SweepData g_recentSweeps[];
int g_sweepCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("ICT Strategy EA Initialized");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", _Period);
   Print("Risk per trade: ", InpRiskPercent, "%");
   Print("Max trades per day: ", InpMaxTradesPerDay);
   
   // Initialize arrays
   ArrayResize(g_recentSweeps, 0);
   
   // Reset daily counters
   g_tradesOpenedToday = 0;
   g_dailyPnL = 0.0;
   g_currentDay = TimeCurrent();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("ICT Strategy EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   if(!IsNewBar())
      return;
   
   // Update daily counters
   UpdateDailyCounters();
   
   // Check if we have an open position - ONLY ONE POSITION ALLOWED (like Python)
   if(PositionSelect(_Symbol))
   {
      // Position exists, don't look for new entries
      ManageOpenPosition();
      return;
   }
   
   // No position exists, check if we can open new trade
   if(!CanOpenNewTrade())
      return;
   
   // Check for entry signals
   CheckEntrySignals();
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                      |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update daily counters                                            |
//+------------------------------------------------------------------+
void UpdateDailyCounters()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   MqlDateTime savedDay;
   TimeToStruct(g_currentDay, savedDay);
   
   // Check if it's a new day
   if(currentTime.day != savedDay.day)
   {
      g_tradesOpenedToday = 0;
      g_dailyPnL = 0.0;
      g_currentDay = TimeCurrent();
      Print("New trading day started. Counters reset.");
   }
}

//+------------------------------------------------------------------+
//| Check if we can open a new trade                                 |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   // Check balance
   if(AccountInfoDouble(ACCOUNT_BALANCE) < InpMinBalance)
   {
      Print("Balance below minimum threshold");
      return false;
   }
   
   // Check daily trade limit
   if(g_tradesOpenedToday >= InpMaxTradesPerDay)
   {
      return false;
   }
   
   // Check daily loss limit
   double dailyLossLimit = AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxDailyLoss / 100.0;
   if(g_dailyPnL < -dailyLossLimit)
   {
      Print("Daily loss limit reached: ", g_dailyPnL);
      return false;
   }
   
   // Check trading session
   if(!IsTradingSession())
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if current time is within trading session (ICT Kill Zones) |
//| ENHANCED: More explicit ICT session filtering                    |
//+------------------------------------------------------------------+
bool IsTradingSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentHour = dt.hour;
   int currentMinute = dt.minute;
   
   // ICT Kill Zones (UTC time):
   // London Kill Zone: 07:00-10:00 UTC (most active: 08:00-09:00)
   // New York AM Kill Zone: 12:00-15:00 UTC (most active: 13:30-14:30)
   // New York PM Kill Zone: 18:00-21:00 UTC
   
   // London session (7 AM - 4 PM UTC) - matching Python
   bool inLondon = (currentHour >= InpLondonOpenHour && currentHour < InpLondonCloseHour);
   
   // NY session (12 PM - 9 PM UTC) - matching Python  
   bool inNY = (currentHour >= InpNYOpenHour && currentHour < InpNYCloseHour);
   
   // Optional: Add more restrictive ICT kill zone filtering
   // For better results, consider trading only during high-liquidity periods:
   // bool inLondonKillZone = (currentHour >= 7 && currentHour < 10);
   // bool inNYAMKillZone = (currentHour >= 12 && currentHour < 15);
   // bool inNYPMKillZone = (currentHour >= 18 && currentHour < 21);
   // return (inLondonKillZone || inNYAMKillZone || inNYPMKillZone);
   
   return (inLondon || inNY);
}

//+------------------------------------------------------------------+
//| Detect higher timeframe trend                                    |
//+------------------------------------------------------------------+
string DetectTrend()
{
   int lookback = MathMin(InpTrendLookback, Bars(_Symbol, _Period));
   if(lookback < 16)
      return "neutral";
   
   double recentHigh = 0, recentLow = DBL_MAX;
   double olderHigh = 0, olderLow = DBL_MAX;
   
   // Get recent highs and lows (last 8 bars)
   for(int i = 1; i <= 8; i++)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      if(high > recentHigh) recentHigh = high;
      if(low < recentLow) recentLow = low;
   }
   
   // Get older highs and lows (9-16 bars ago)
   for(int i = 9; i <= 16; i++)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      if(high > olderHigh) olderHigh = high;
      if(low < olderLow) olderLow = low;
   }
   
   // Determine trend
   if(recentHigh > olderHigh && recentLow > olderLow)
      return "bullish";
   else if(recentHigh < olderHigh && recentLow < olderLow)
      return "bearish";
   else
      return "neutral";
}

//+------------------------------------------------------------------+
//| Detect liquidity sweep                                           |
//| ENHANCED: More thorough validation of sweep conditions           |
//+------------------------------------------------------------------+
SweepData DetectLiquiditySweep()
{
   SweepData sweep;
   sweep.isValid = false;
   
   if(Bars(_Symbol, _Period) < 20)
      return sweep;
   
   double currentHigh = iHigh(_Symbol, _Period, 1);
   double currentLow = iLow(_Symbol, _Period, 1);
   double currentClose = iClose(_Symbol, _Period, 1);
   double currentOpen = iOpen(_Symbol, _Period, 1);
   
   // Find previous highs and lows (20 bars lookback) - matching Python
   double prevHigh = 0;
   double prevLow = DBL_MAX;
   
   for(int i = 2; i <= 21; i++)  // bars 2-21 (matching Python's idx-20:idx which excludes current)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      if(high > prevHigh) prevHigh = high;
      if(low < prevLow) prevLow = low;
   }
   
   double rejectionPips = InpSweepRejectionPips * _Point * 10;
   
   // Bearish sweep: high broken but price rejected (closed below high with rejection)
   // This indicates liquidity grab at the high followed by bearish reversal
   if(currentHigh > prevHigh && currentClose < (currentHigh - rejectionPips))
   {
      // Additional validation: ensure it's a wick rejection, not just a bearish candle
      double wickSize = currentHigh - MathMax(currentOpen, currentClose);
      if(wickSize >= rejectionPips)  // Significant upper wick confirms rejection
      {
         sweep.isValid = true;
         sweep.type = "bear_sweep";
         sweep.price = currentHigh;
         sweep.time = iTime(_Symbol, _Period, 1);
         sweep.barIndex = 1;
         sweep.trend = DetectTrend();
      }
   }
   // Bullish sweep: low broken but price rejected (closed above low with rejection)
   // This indicates liquidity grab at the low followed by bullish reversal
   else if(currentLow < prevLow && currentClose > (currentLow + rejectionPips))
   {
      // Additional validation: ensure it's a wick rejection, not just a bullish candle
      double wickSize = MathMin(currentOpen, currentClose) - currentLow;
      if(wickSize >= rejectionPips)  // Significant lower wick confirms rejection
      {
         sweep.isValid = true;
         sweep.type = "bull_sweep";
         sweep.price = currentLow;
         sweep.time = iTime(_Symbol, _Period, 1);
         sweep.barIndex = 1;
         sweep.trend = DetectTrend();
      }
   }
   
   return sweep;
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gap                                            |
//| FIXED: Now properly validates 3-candle pattern with displacement |
//+------------------------------------------------------------------+
FVGData DetectFVG()
{
   FVGData fvg;
   fvg.isValid = false;
   
   if(Bars(_Symbol, _Period) < 3)
      return fvg;
   
   // Get three candles: c1 (oldest), c2 (middle/displacement), c3 (newest)
   // In MQL5, bar indexing: 0=current, 1=previous, 2=2 bars ago, 3=3 bars ago
   double c1_high = iHigh(_Symbol, _Period, 3);  // Bar 3 (oldest)
   double c1_low = iLow(_Symbol, _Period, 3);
   double c2_high = iHigh(_Symbol, _Period, 2);  // Bar 2 (displacement candle)
   double c2_low = iLow(_Symbol, _Period, 2);
   double c2_open = iOpen(_Symbol, _Period, 2);
   double c2_close = iClose(_Symbol, _Period, 2);
   double c3_high = iHigh(_Symbol, _Period, 1);  // Bar 1 (newest)
   double c3_low = iLow(_Symbol, _Period, 1);
   
   double minGapPips = InpMinFVGPips * _Point * 10;
   
   // Bullish FVG (gap up): c3.low > c1.high (gap exists between candles)
   // Also validate c2 is a strong bullish displacement candle
   if(c3_low > c1_high)
   {
      double gap = c3_low - c1_high;
      if(gap >= minGapPips)
      {
         // Validate displacement candle (c2) - should be bullish and strong
         bool isDisplacementValid = (c2_close > c2_open) && 
                                     (c2_high - c2_low) >= minGapPips * 0.5;  // Candle body significant
         
         if(isDisplacementValid)
         {
            fvg.isValid = true;
            fvg.type = "bullish";
            fvg.bottom = c1_high;
            fvg.top = c3_low;
            fvg.barIndex = 1;
         }
      }
   }
   // Bearish FVG (gap down): c3.high < c1.low (gap exists between candles)
   // Also validate c2 is a strong bearish displacement candle
   else if(c3_high < c1_low)
   {
      double gap = c1_low - c3_high;
      if(gap >= minGapPips)
      {
         // Validate displacement candle (c2) - should be bearish and strong
         bool isDisplacementValid = (c2_close < c2_open) && 
                                     (c2_high - c2_low) >= minGapPips * 0.5;  // Candle body significant
         
         if(isDisplacementValid)
         {
            fvg.isValid = true;
            fvg.type = "bearish";
            fvg.bottom = c3_high;
            fvg.top = c1_low;
            fvg.barIndex = 1;
         }
      }
   }
   
   return fvg;
}

//+------------------------------------------------------------------+
//| Detect Market Structure Shift                                    |
//| FIXED: Now properly checks AFTER sweep for structure break       |
//| Python logic: candles.iloc[1:]['low'].min() < candles.iloc[0]['low'] |
//+------------------------------------------------------------------+
bool DetectMSS(SweepData &sweep, int currentBar)
{
   if(!sweep.isValid)
      return false;
   
   // MSS means price broke structure AFTER the sweep
   // We need to check bars from the sweep bar up to current bar
   // In MQL5: sweep.barIndex is the sweep bar (e.g., bar 5)
   //          currentBar is current bar (typically bar 1)
   //          We check bars BETWEEN sweep and current (bars 4, 3, 2, 1)
   
   if(currentBar >= sweep.barIndex)
      return false;  // No candles after sweep yet
   
   // For bearish sweep, check if price made lower low AFTER the sweep
   // This confirms bearish structure shift
   if(sweep.type == "bear_sweep")
   {
      double sweepLow = iLow(_Symbol, _Period, sweep.barIndex);
      // Check all bars AFTER the sweep (smaller index = more recent)
      for(int i = sweep.barIndex - 1; i >= currentBar; i--)
      {
         if(iLow(_Symbol, _Period, i) < sweepLow)
            return true;  // Found lower low - structure shifted bearish
      }
   }
   // For bullish sweep, check if price made higher high AFTER the sweep
   // This confirms bullish structure shift
   else if(sweep.type == "bull_sweep")
   {
      double sweepHigh = iHigh(_Symbol, _Period, sweep.barIndex);
      // Check all bars AFTER the sweep (smaller index = more recent)
      for(int i = sweep.barIndex - 1; i >= currentBar; i--)
      {
         if(iHigh(_Symbol, _Period, i) > sweepHigh)
            return true;  // Found higher high - structure shifted bullish
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for entry signals                                          |
//| ENHANCED: Enforces all ICT confluences before entry             |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   // Detect new sweep
   SweepData newSweep = DetectLiquiditySweep();
   if(newSweep.isValid)
   {
      // Add to recent sweeps
      AddSweep(newSweep);
      Print("Liquidity sweep detected: ", newSweep.type, " at ", newSweep.price);
   }
   
   // Clean old sweeps (older than 30 bars)
   CleanOldSweeps(30);
   
   // Check existing sweeps for entry - REQUIRES ALL CONFLUENCES
   for(int i = 0; i < g_sweepCount; i++)
   {
      if(!g_recentSweeps[i].isValid)
         continue;
      
      // === CONFLUENCE 1: Trend Alignment (if not in relaxed mode) ===
      string trend = DetectTrend();
      if(!InpRelaxedMode && trend != "neutral" && g_recentSweeps[i].trend != trend)
      {
         // Trend doesn't match sweep - skip this sweep
         continue;
      }
      
      // === CONFLUENCE 2: Market Structure Shift (MSS) ===
      // CRITICAL: Must have break of structure after sweep
      if(!DetectMSS(g_recentSweeps[i], 1))
      {
         // No MSS confirmed yet - skip this sweep
         continue;
      }
      
      // === CONFLUENCE 3: Fair Value Gap (FVG) ===
      // Must have valid FVG with proper displacement candle
      FVGData fvg = DetectFVG();
      if(!fvg.isValid)
      {
         // No valid FVG - skip this sweep
         continue;
      }
      
      // === CONFLUENCE 4: FVG Type Must Match Sweep Direction ===
      // Bullish sweep requires bullish FVG, bearish sweep requires bearish FVG
      string expectedFVG = (g_recentSweeps[i].type == "bull_sweep") ? "bullish" : "bearish";
      if(fvg.type != expectedFVG)
      {
         // FVG type mismatch - skip this sweep
         continue;
      }
      
      // === CONFLUENCE 5: Session Validation (already checked in CanOpenNewTrade) ===
      // Trading session check is done before calling this function
      
      // === ALL CONFLUENCES MET ===
      // 1. ✓ Liquidity Sweep detected
      // 2. ✓ Trend alignment (or relaxed mode)
      // 3. ✓ Market Structure Shift confirmed
      // 4. ✓ Fair Value Gap identified with displacement validation
      // 5. ✓ FVG direction matches sweep direction
      // 6. ✓ Trading session validated
      
      Print("=== ENTRY SIGNAL CONFIRMED ===");
      Print("All ICT confluences met:");
      Print("  - Liquidity Sweep: ", g_recentSweeps[i].type);
      Print("  - MSS: Confirmed");
      Print("  - FVG Type: ", fvg.type);
      Print("  - Trend: ", trend);
      Print("  - Session: Active");
      
      // Open trade with all confluences confirmed
      OpenTrade(expectedFVG, g_recentSweeps[i], fvg);
      
      // Mark sweep as used
      g_recentSweeps[i].isValid = false;
      
      break; // Only one trade per tick
   }
}

//+------------------------------------------------------------------+
//| Add sweep to array                                               |
//+------------------------------------------------------------------+
void AddSweep(SweepData &sweep)
{
   ArrayResize(g_recentSweeps, g_sweepCount + 1);
   g_recentSweeps[g_sweepCount] = sweep;
   g_sweepCount++;
}

//+------------------------------------------------------------------+
//| Clean old sweeps                                                 |
//+------------------------------------------------------------------+
void CleanOldSweeps(int maxBars)
{
   int validCount = 0;
   SweepData tempSweeps[];
   ArrayResize(tempSweeps, g_sweepCount);
   
   datetime currentTime = iTime(_Symbol, _Period, 0);
   
   for(int i = 0; i < g_sweepCount; i++)
   {
      // Calculate bar difference
      int barDiff = Bars(_Symbol, _Period, g_recentSweeps[i].time, currentTime);
      
      if(g_recentSweeps[i].isValid && barDiff <= maxBars)
      {
         tempSweeps[validCount] = g_recentSweeps[i];
         validCount++;
      }
   }
   
   // Update array
   ArrayResize(g_recentSweeps, validCount);
   for(int i = 0; i < validCount; i++)
   {
      g_recentSweeps[i] = tempSweeps[i];
   }
   g_sweepCount = validCount;
}

//+------------------------------------------------------------------+
//| Open a trade                                                      |
//+------------------------------------------------------------------+
void OpenTrade(string direction, SweepData &sweep, FVGData &fvg)
{
   double entry, stopLoss, takeProfit;
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double bufferPips = InpStopLossBufferPips * _Point * 10;
   
   // Calculate entry, SL, and TP
   if(direction == "bullish")
   {
      entry = fvg.bottom + spread;
      stopLoss = sweep.price - bufferPips;
      double slPips = (entry - stopLoss) / (_Point * 10);
      double rr = MathRandomUniform(InpTargetMinR, InpTargetMaxR);
      takeProfit = entry + (slPips * rr * _Point * 10);
   }
   else // bearish
   {
      entry = fvg.top - spread;
      stopLoss = sweep.price + bufferPips;
      double slPips = (stopLoss - entry) / (_Point * 10);
      double rr = MathRandomUniform(InpTargetMinR, InpTargetMaxR);
      takeProfit = entry - (slPips * rr * _Point * 10);
   }
   
   // Calculate position size
   double slPips = MathAbs(entry - stopLoss) / (_Point * 10);
   double lotSize = CalculatePositionSize(slPips);
   
   if(lotSize < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("Calculated lot size too small: ", lotSize);
      return;
   }
   
   // Prepare trade request - USE PENDING ORDER like Python simulation
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // Use LIMIT order to enter at FVG level (matching Python's entry logic)
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = lotSize;
   
   // For bullish, BUY_LIMIT below market; for bearish, SELL_LIMIT above market
   // But since FVG bottom/top might be near current price, we use BUY_STOP/SELL_STOP
   // Actually, let's check if price needs to come back to FVG or is already there
   double currentPrice = (direction == "bullish") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Check if we should use LIMIT (price needs to come to us) or STOP (price needs to continue)
   if(direction == "bullish")
   {
      // Bullish: enter at FVG bottom
      if(entry < currentPrice)
         request.type = ORDER_TYPE_BUY_LIMIT;  // Price needs to come down to FVG
      else
         request.type = ORDER_TYPE_BUY_STOP;   // Price already below, needs to come up
   }
   else
   {
      // Bearish: enter at FVG top
      if(entry > currentPrice)
         request.type = ORDER_TYPE_SELL_LIMIT;  // Price needs to come up to FVG
      else
         request.type = ORDER_TYPE_SELL_STOP;   // Price already above, needs to come down
   }
   
   request.price = entry;  // Enter at FVG level, not market
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = InpSlippage;
   request.magic = InpMagicNumber;
   request.comment = InpTradeComment;
   request.type_time = ORDER_TIME_GTC;  // Good till cancelled
   request.type_filling = ORDER_FILLING_FOK;  // Fill or kill
   
   // Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
      {
         Print("Order placed successfully: ", direction);
         Print("Entry price: ", entry, ", SL: ", stopLoss, ", TP: ", takeProfit);
         Print("Lot size: ", lotSize, ", SL pips: ", slPips);
         Print("Order type: ", EnumToString(request.type));
         g_tradesOpenedToday++;
      }
      else
      {
         Print("Order failed. Retcode: ", result.retcode, ", ", result.comment);
      }
   }
   else
   {
      Print("OrderSend failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                            |
//+------------------------------------------------------------------+
double CalculatePositionSize(double slPips)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * InpRiskPercent / 100.0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   // Calculate pip value per lot
   double pipValue = tickValue / tickSize * _Point;
   
   // Calculate lot size based on risk and SL in pips
   double lotSize = riskAmount / (slPips * pipValue / _Point);
   
   // Round to symbol lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Ensure within limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Manage open position                                             |
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
   // This function can be expanded to add trailing stop, breakeven, etc.
   if(InpEnableTrailing)
   {
      // Implement trailing stop logic here
   }
}

//+------------------------------------------------------------------+
//| Generate random number in range                                  |
//+------------------------------------------------------------------+
double MathRandomUniform(double min, double max)
{
   return min + (max - min) * ((double)MathRand() / 32767.0);
}
//+------------------------------------------------------------------+
