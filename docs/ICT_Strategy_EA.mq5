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
input int      InpMaxTradesPerDay = 10;       // Max trades per day
input double   InpMaxDailyLoss = 5.0;         // Max daily loss (%)
input double   InpMinBalance = 100.0;         // Minimum balance threshold

input group "=== ICT Parameters ==="
input double   InpMinFVGPips = 3.0;           // Minimum FVG size (pips)
input double   InpSweepRejectionPips = 1.0;   // Sweep rejection (pips)
input double   InpStopLossBufferPips = 2.0;   // Stop loss buffer (pips)
input double   InpTargetMinR = 3.0;           // Minimum R:R ratio
input double   InpTargetMaxR = 5.0;           // Maximum R:R ratio
input int      InpFVGConfirmCandles = 1;      // FVG confirmation candles

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
   
   // Check if we have an open position
   if(PositionSelect(_Symbol))
   {
      ManageOpenPosition();
      return;
   }
   
   // Check if we can open new trade
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
//| Check if current time is within trading session                  |
//+------------------------------------------------------------------+
bool IsTradingSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentHour = dt.hour;
   
   // London session
   bool inLondon = (currentHour >= InpLondonOpenHour && currentHour < InpLondonCloseHour);
   
   // NY session
   bool inNY = (currentHour >= InpNYOpenHour && currentHour < InpNYCloseHour);
   
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
   
   // Find previous highs and lows (20 bars lookback)
   double prevHigh = 0;
   double prevLow = DBL_MAX;
   
   for(int i = 2; i <= 20; i++)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      if(high > prevHigh) prevHigh = high;
      if(low < prevLow) prevLow = low;
   }
   
   double rejectionPips = InpSweepRejectionPips * _Point * 10;
   
   // Bearish sweep (high broken but rejected)
   if(currentHigh > prevHigh && currentClose < (currentHigh - rejectionPips))
   {
      sweep.isValid = true;
      sweep.type = "bear_sweep";
      sweep.price = currentHigh;
      sweep.time = iTime(_Symbol, _Period, 1);
      sweep.barIndex = 1;
      sweep.trend = DetectTrend();
   }
   // Bullish sweep (low broken but rejected)
   else if(currentLow < prevLow && currentClose > (currentLow + rejectionPips))
   {
      sweep.isValid = true;
      sweep.type = "bull_sweep";
      sweep.price = currentLow;
      sweep.time = iTime(_Symbol, _Period, 1);
      sweep.barIndex = 1;
      sweep.trend = DetectTrend();
   }
   
   return sweep;
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gap                                            |
//+------------------------------------------------------------------+
FVGData DetectFVG()
{
   FVGData fvg;
   fvg.isValid = false;
   
   if(Bars(_Symbol, _Period) < 3)
      return fvg;
   
   // Get three candles
   double c1_high = iHigh(_Symbol, _Period, 3);
   double c1_low = iLow(_Symbol, _Period, 3);
   double c3_high = iHigh(_Symbol, _Period, 1);
   double c3_low = iLow(_Symbol, _Period, 1);
   
   double minGapPips = InpMinFVGPips * _Point * 10;
   
   // Bullish FVG (gap up)
   if(c3_low > c1_high)
   {
      double gap = c3_low - c1_high;
      if(gap >= minGapPips)
      {
         fvg.isValid = true;
         fvg.type = "bullish";
         fvg.bottom = c1_high;
         fvg.top = c3_low;
         fvg.barIndex = 1;
      }
   }
   // Bearish FVG (gap down)
   else if(c3_high < c1_low)
   {
      double gap = c1_low - c3_high;
      if(gap >= minGapPips)
      {
         fvg.isValid = true;
         fvg.type = "bearish";
         fvg.bottom = c3_high;
         fvg.top = c1_low;
         fvg.barIndex = 1;
      }
   }
   
   return fvg;
}

//+------------------------------------------------------------------+
//| Detect Market Structure Shift                                    |
//+------------------------------------------------------------------+
bool DetectMSS(SweepData &sweep, int currentBar)
{
   if(!sweep.isValid)
      return false;
   
   // For bearish sweep, check if price made lower low
   if(sweep.type == "bear_sweep")
   {
      double sweepLow = iLow(_Symbol, _Period, sweep.barIndex);
      for(int i = sweep.barIndex - 1; i >= currentBar; i--)
      {
         if(iLow(_Symbol, _Period, i) < sweepLow)
            return true;
      }
   }
   // For bullish sweep, check if price made higher high
   else if(sweep.type == "bull_sweep")
   {
      double sweepHigh = iHigh(_Symbol, _Period, sweep.barIndex);
      for(int i = sweep.barIndex - 1; i >= currentBar; i--)
      {
         if(iHigh(_Symbol, _Period, i) > sweepHigh)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for entry signals                                          |
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
   
   // Check existing sweeps for entry
   for(int i = 0; i < g_sweepCount; i++)
   {
      if(!g_recentSweeps[i].isValid)
         continue;
      
      string trend = DetectTrend();
      
      // Skip if trend doesn't match (unless relaxed mode)
      if(!InpRelaxedMode && trend != "neutral" && g_recentSweeps[i].trend != trend)
         continue;
      
      // Check for MSS
      if(!DetectMSS(g_recentSweeps[i], 1))
         continue;
      
      // Check for FVG
      FVGData fvg = DetectFVG();
      if(!fvg.isValid)
         continue;
      
      // Check FVG confirmation
      if(InpFVGConfirmCandles > 0 && fvg.barIndex < InpFVGConfirmCandles)
         continue;
      
      // Check if FVG type matches sweep type
      string expectedFVG = (g_recentSweeps[i].type == "bull_sweep") ? "bullish" : "bearish";
      if(fvg.type != expectedFVG)
         continue;
      
      // Valid entry signal found
      Print("Entry signal found: ", expectedFVG, " after ", g_recentSweeps[i].type);
      
      // Open trade
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
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = (direction == "bullish") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = (direction == "bullish") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = InpSlippage;
   request.magic = InpMagicNumber;
   request.comment = InpTradeComment;
   
   // Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         Print("Trade opened successfully: ", direction);
         Print("Entry: ", request.price, ", SL: ", stopLoss, ", TP: ", takeProfit);
         Print("Lot size: ", lotSize, ", SL pips: ", slPips);
         g_tradesOpenedToday++;
      }
      else
      {
         Print("Trade failed. Retcode: ", result.retcode, ", ", result.comment);
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
   
   double slDistance = slPips * _Point * 10;
   double pipValue = tickValue / tickSize * _Point;
   
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
