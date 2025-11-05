//+------------------------------------------------------------------+
//|                                        PIVOT_CANDLE_SCALPER.mq5 |
//|                                    Copyright 2025, PivotScalper |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, PivotScalper"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Pivot-based scalping strategy with candlestick pattern confirmation"
#property description "Works on any symbol (forex, metals, indices) and timeframe (optimized for M15)"

//--- Input parameters
input double   LotSize = 0.01;                    // Fixed lot size
input double   RiskPercent = 0.5;                 // Risk percent per trade (0 = use fixed lot)
input double   StopLossPips = 15;                 // Stop Loss in pips
input double   TakeProfit1Pips = 20;              // Take Profit 1 in pips (50% close)
input double   TakeProfit2Pips = 40;              // Take Profit 2 in pips (remaining 50%)
input long     MagicNumber = 202506;              // Magic number for order identification
input double   MaxSpread = 30;                    // Maximum spread in points
input bool     EnableTradingHours = false;        // Enable trading hours restriction
input int      TradeStartHour = 0;                // Trading start hour (0-23)
input int      TradeEndHour = 23;                 // Trading end hour (0-23)

//--- Global variables
double g_PP, g_R1, g_R2, g_S1, g_S2;              // Pivot points
double g_point;                                    // Point value for current symbol
double g_tickSize;                                 // Tick size for current symbol
int g_digits;                                      // Digits for current symbol
double g_pipValue;                                 // Pip value (adjusted for different symbols)
bool g_isMetalOrIndex;                            // Symbol type flag

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize symbol-specific variables
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   //--- Determine pip value based on symbol type
   //--- For most forex pairs: 1 pip = 0.0001 or 0.01 (JPY pairs)
   //--- For metals like XAUUSD: 1 pip = 0.1 or 0.01 depending on broker
   //--- For indices: varies by instrument
   if(g_digits == 5 || g_digits == 3)
      g_pipValue = g_point * 10;  // 5-digit or 3-digit broker
   else if(g_digits == 4 || g_digits == 2)
      g_pipValue = g_point;       // 4-digit or 2-digit broker
   else
      g_pipValue = g_point * 10;  // Default for other instruments
   
   //--- Check if symbol is metal or index (typically has fewer digits or different point structure)
   string symbolName = _Symbol;
   g_isMetalOrIndex = (StringFind(symbolName, "XAU") >= 0 || 
                       StringFind(symbolName, "XAG") >= 0 ||
                       StringFind(symbolName, "GOLD") >= 0 ||
                       StringFind(symbolName, "SILVER") >= 0 ||
                       g_digits <= 2);
   
   //--- Calculate initial pivot points
   CalculatePivotPoints();
   
   Print("═══════════════════════════════════════════════════════════");
   Print("PivotCandleScalper EA initialized successfully");
   Print("Symbol: ", _Symbol);
   Print("Digits: ", g_digits, " | Point: ", g_point, " | Pip Value: ", g_pipValue);
   Print("Initial Pivot Levels:");
   Print("  R2 = ", DoubleToString(g_R2, g_digits));
   Print("  R1 = ", DoubleToString(g_R1, g_digits));
   Print("  PP = ", DoubleToString(g_PP, g_digits));
   Print("  S1 = ", DoubleToString(g_S1, g_digits));
   Print("  S2 = ", DoubleToString(g_S2, g_digits));
   Print("═══════════════════════════════════════════════════════════");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("PivotCandleScalper EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if new bar formed
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime == lastBarTime)
      return;  // Wait for new bar
   
   lastBarTime = currentBarTime;
   
   //--- Recalculate pivot points daily (check if new day started)
   static int lastDay = 0;
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   if(timeStruct.day != lastDay)
   {
      CalculatePivotPoints();
      lastDay = timeStruct.day;
      Print("New day detected. Pivot points recalculated.");
   }
   
   //--- Check trading hours if enabled
   if(EnableTradingHours && !IsTradingHourAllowed())
      return;
   
   //--- Check if position already exists
   if(HasOpenPosition())
      return;
   
   //--- Check spread condition
   double currentSpread = GetCurrentSpread();
   if(currentSpread > MaxSpread)
      return;
   
   //--- Get current price
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentPrice = (ask + bid) / 2;
   
   //--- Determine market bias
   bool bullishBias = currentPrice > g_PP;
   bool bearishBias = currentPrice < g_PP;
   
   //--- Look for trading signals
   if(bullishBias)
   {
      //--- Check for bullish setup at S1 or PP
      if(CheckBullishSetup())
      {
         OpenBuyOrder();
      }
   }
   else if(bearishBias)
   {
      //--- Check for bearish setup at R1 or PP
      if(CheckBearishSetup())
      {
         OpenSellOrder();
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate daily pivot points from previous day                   |
//+------------------------------------------------------------------+
void CalculatePivotPoints()
{
   //--- Get previous daily candle data
   double prevHigh = iHigh(_Symbol, PERIOD_D1, 1);
   double prevLow = iLow(_Symbol, PERIOD_D1, 1);
   double prevClose = iClose(_Symbol, PERIOD_D1, 1);
   
   //--- Calculate pivot point
   g_PP = (prevHigh + prevLow + prevClose) / 3.0;
   
   //--- Calculate resistance levels
   g_R1 = 2 * g_PP - prevLow;
   g_R2 = g_PP + (prevHigh - prevLow);
   
   //--- Calculate support levels
   g_S1 = 2 * g_PP - prevHigh;
   g_S2 = g_PP - (prevHigh - prevLow);
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsTradingHourAllowed()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   int currentHour = timeStruct.hour;
   
   if(TradeStartHour <= TradeEndHour)
   {
      //--- Normal range (e.g., 8 to 17)
      return (currentHour >= TradeStartHour && currentHour <= TradeEndHour);
   }
   else
   {
      //--- Overnight range (e.g., 22 to 6)
      return (currentHour >= TradeStartHour || currentHour <= TradeEndHour);
   }
}

//+------------------------------------------------------------------+
//| Check if there's an open position with our magic number          |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get current spread in points                                     |
//+------------------------------------------------------------------+
double GetCurrentSpread()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / g_point;
}

//+------------------------------------------------------------------+
//| Check for bullish setup (long entry conditions)                  |
//+------------------------------------------------------------------+
bool CheckBullishSetup()
{
   //--- Get completed candle (index 1)
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   //--- Check if price is near S1 or PP
   double tolerance = 5 * g_pipValue;  // 5 pip tolerance
   bool nearS1 = MathAbs(close1 - g_S1) <= tolerance;
   bool nearPP = MathAbs(close1 - g_PP) <= tolerance;
   
   if(!nearS1 && !nearPP)
      return false;
   
   //--- Check for bullish candlestick patterns
   bool isBullishPinBar = IsBullishPinBar(open1, high1, low1, close1);
   bool isBullishEngulfing = IsBullishEngulfing();
   
   return (isBullishPinBar || isBullishEngulfing);
}

//+------------------------------------------------------------------+
//| Check for bearish setup (short entry conditions)                 |
//+------------------------------------------------------------------+
bool CheckBearishSetup()
{
   //--- Get completed candle (index 1)
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   //--- Check if price is near R1 or PP
   double tolerance = 5 * g_pipValue;  // 5 pip tolerance
   bool nearR1 = MathAbs(close1 - g_R1) <= tolerance;
   bool nearPP = MathAbs(close1 - g_PP) <= tolerance;
   
   if(!nearR1 && !nearPP)
      return false;
   
   //--- Check for bearish candlestick patterns
   bool isBearishPinBar = IsBearishPinBar(open1, high1, low1, close1);
   bool isBearishEngulfing = IsBearishEngulfing();
   
   return (isBearishPinBar || isBearishEngulfing);
}

//+------------------------------------------------------------------+
//| Detect bullish pin bar pattern                                   |
//| Criteria: Lower wick >= 2x body, upper wick <= 30% of range     |
//+------------------------------------------------------------------+
bool IsBullishPinBar(double open, double high, double low, double close)
{
   double body = MathAbs(close - open);
   double totalRange = high - low;
   double lowerWick = MathMin(open, close) - low;
   double upperWick = high - MathMax(open, close);
   
   if(totalRange == 0)
      return false;
   
   //--- Bullish pin bar: long lower wick, small upper wick
   bool longLowerWick = lowerWick >= (2 * body);
   bool smallUpperWick = upperWick <= (0.3 * totalRange);
   bool isBullish = close > open;  // Prefer bullish close but not required
   
   return (longLowerWick && smallUpperWick);
}

//+------------------------------------------------------------------+
//| Detect bearish pin bar pattern                                   |
//| Criteria: Upper wick >= 2x body, lower wick <= 30% of range     |
//+------------------------------------------------------------------+
bool IsBearishPinBar(double open, double high, double low, double close)
{
   double body = MathAbs(close - open);
   double totalRange = high - low;
   double lowerWick = MathMin(open, close) - low;
   double upperWick = high - MathMax(open, close);
   
   if(totalRange == 0)
      return false;
   
   //--- Bearish pin bar: long upper wick, small lower wick
   bool longUpperWick = upperWick >= (2 * body);
   bool smallLowerWick = lowerWick <= (0.3 * totalRange);
   bool isBearish = close < open;  // Prefer bearish close but not required
   
   return (longUpperWick && smallLowerWick);
}

//+------------------------------------------------------------------+
//| Detect bullish engulfing pattern                                 |
//| Criteria: Current bullish candle engulfs previous candle's body |
//+------------------------------------------------------------------+
bool IsBullishEngulfing()
{
   //--- Current candle (index 1 - completed)
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   //--- Previous candle (index 2)
   double open2 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   //--- Check if current candle is bullish
   if(close1 <= open1)
      return false;
   
   //--- Check if previous candle is bearish
   if(close2 >= open2)
      return false;
   
   //--- Check if current candle engulfs previous candle's body
   bool engulfs = (open1 < close2) && (close1 > open2);
   
   return engulfs;
}

//+------------------------------------------------------------------+
//| Detect bearish engulfing pattern                                 |
//| Criteria: Current bearish candle engulfs previous candle's body |
//+------------------------------------------------------------------+
bool IsBearishEngulfing()
{
   //--- Current candle (index 1 - completed)
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   //--- Previous candle (index 2)
   double open2 = iOpen(_Symbol, PERIOD_CURRENT, 2);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   
   //--- Check if current candle is bearish
   if(close1 >= open1)
      return false;
   
   //--- Check if previous candle is bullish
   if(close2 <= open2)
      return false;
   
   //--- Check if current candle engulfs previous candle's body
   bool engulfs = (open1 > close2) && (close1 < open2);
   
   return engulfs;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
   if(RiskPercent <= 0)
      return LotSize;  // Use fixed lot size
   
   //--- Get account balance
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   //--- Calculate risk amount in account currency
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   //--- Get tick value
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   //--- Calculate lot size
   double lotSize = riskAmount / (stopLossDistance * tickValue / g_tickSize);
   
   //--- Normalize to lot step
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Open buy order with proper SL/TP                                 |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //--- Get signal candle low for stop loss
   double signalLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   
   //--- Calculate stop loss and take profits
   double stopLoss = signalLow - (2 * g_pipValue);  // Buffer below signal low
   double takeProfit1 = ask + (TakeProfit1Pips * g_pipValue);
   double takeProfit2 = ask + (TakeProfit2Pips * g_pipValue);
   
   //--- Normalize prices
   stopLoss = NormalizeDouble(stopLoss, g_digits);
   takeProfit1 = NormalizeDouble(takeProfit1, g_digits);
   takeProfit2 = NormalizeDouble(takeProfit2, g_digits);
   
   //--- Calculate lot size
   double slDistance = (ask - stopLoss) / g_point;
   double lotSize = CalculateLotSize(slDistance);
   
   //--- We'll open two positions: 50% for TP1, 50% for TP2
   double halfLot = NormalizeDouble(lotSize / 2.0, 2);
   
   //--- Prepare trade request
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   //--- First position (50% at TP1)
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = halfLot;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = stopLoss;
   request.tp = takeProfit1;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "PCS_Buy_TP1";
   
   if(!OrderSend(request, result))
   {
      Print("Buy order TP1 failed. Error: ", GetLastError());
      return;
   }
   
   Print("Buy order TP1 opened successfully. Ticket: ", result.order);
   
   //--- Second position (50% at TP2)
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = halfLot;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = stopLoss;
   request.tp = takeProfit2;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "PCS_Buy_TP2";
   
   if(!OrderSend(request, result))
   {
      Print("Buy order TP2 failed. Error: ", GetLastError());
      return;
   }
   
   Print("Buy order TP2 opened successfully. Ticket: ", result.order);
}

//+------------------------------------------------------------------+
//| Open sell order with proper SL/TP                                |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   //--- Get signal candle high for stop loss
   double signalHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   
   //--- Calculate stop loss and take profits
   double stopLoss = signalHigh + (2 * g_pipValue);  // Buffer above signal high
   double takeProfit1 = bid - (TakeProfit1Pips * g_pipValue);
   double takeProfit2 = bid - (TakeProfit2Pips * g_pipValue);
   
   //--- Normalize prices
   stopLoss = NormalizeDouble(stopLoss, g_digits);
   takeProfit1 = NormalizeDouble(takeProfit1, g_digits);
   takeProfit2 = NormalizeDouble(takeProfit2, g_digits);
   
   //--- Calculate lot size
   double slDistance = (stopLoss - bid) / g_point;
   double lotSize = CalculateLotSize(slDistance);
   
   //--- We'll open two positions: 50% for TP1, 50% for TP2
   double halfLot = NormalizeDouble(lotSize / 2.0, 2);
   
   //--- Prepare trade request
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   //--- First position (50% at TP1)
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = halfLot;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = stopLoss;
   request.tp = takeProfit1;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "PCS_Sell_TP1";
   
   if(!OrderSend(request, result))
   {
      Print("Sell order TP1 failed. Error: ", GetLastError());
      return;
   }
   
   Print("Sell order TP1 opened successfully. Ticket: ", result.order);
   
   //--- Second position (50% at TP2)
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = halfLot;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = stopLoss;
   request.tp = takeProfit2;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "PCS_Sell_TP2";
   
   if(!OrderSend(request, result))
   {
      Print("Sell order TP2 failed. Error: ", GetLastError());
      return;
   }
   
   Print("Sell order TP2 opened successfully. Ticket: ", result.order);
}
//+------------------------------------------------------------------+
