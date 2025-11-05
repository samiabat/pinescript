//+------------------------------------------------------------------+
//|                                               PIVOT_CANDLE_SCALPER.mq5
//|  Expert Advisor: PivotCandleScalper
//|  Strategy: Daily Pivot Points + Candlestick reversal (Pin Bar / Engulfing)
//|  Timeframe: designed for M15 (works on any timeframe/symbol incl. XAUUSD)
//|  Author: Generated for user samiabat
//+------------------------------------------------------------------+
#property copyright "PivotCandleScalper"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//------------------------------------------------------------------
// INPUTS (external parameters)
//------------------------------------------------------------------
input double LotSize            = 0.01;      // Fixed lot size (used when RiskPercent == 0)
input double RiskPercent        = 0.5;       // Percent of balance to risk per trade (0 = disabled)
input double StopLossPips       = 15.0;      // (Informational) default SL in pips if needed
input double TakeProfit1Pips    = 20.0;      // TP1 in pips
input double TakeProfit2Pips    = 40.0;      // TP2 in pips
input long   MagicNumber        = 202506;    // Magic number for all EA trades
input double MaxSpread          = 30.0;      // Maximum allowed spread (in points)
input bool   EnableTradingHours = false;     // Restrict trading to server hours?
input int    TradeStartHour     = 0;         // Start hour (0-23)
input int    TradeEndHour       = 23;        // End hour (0-23)

//------------------------------------------------------------------
// GLOBALS
//------------------------------------------------------------------
CTrade trade;
datetime   g_lastProcessedCandle = 0; // to avoid duplicate processing
double     g_point=0.0;
int        g_digits=0;
double     g_pip=0.0;

//------------------------------------------------------------------
// Utility: normalize lot to broker step/min/max
//------------------------------------------------------------------
double NormalizeLotToStep(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minLot <= 0 || stepLot <= 0) return(NormalizeDouble(lot,2));
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   // align to step
   double steps = MathFloor((lot - minLot + 1e-9)/stepLot);
   double res = minLot + steps * stepLot;
   // if rounding caused < min or > max, clamp
   if(res < minLot) res = minLot;
   if(res > maxLot) res = maxLot;
   // round safely
   return(NormalizeDouble(res,8));
}

//------------------------------------------------------------------
// Get previous daily OHLC (previous trading day bar at shift=1)
// returns true on success
//------------------------------------------------------------------
bool GetPreviousDayOHLC(double &H, double &L, double &C)
{
   // CopyRates or CopyHigh/Low/Close can be used. Use CopyRates for robustness.
   MqlRates rates[2];
   int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, rates);
   if(copied < 1)
   {
      // fallback: attempt to read using iHigh/iLow/iClose (should be same)
      H = iHigh(_Symbol, PERIOD_D1, 1);
      L = iLow (_Symbol, PERIOD_D1, 1);
      C = iClose(_Symbol, PERIOD_D1, 1);
      if(H==0 || L==0) return(false);
      return(true);
   }
   H = rates[0].high;
   L = rates[0].low;
   C = rates[0].close;
   return(true);
}

//------------------------------------------------------------------
// Calculate standard daily pivot points from previous day
//------------------------------------------------------------------
void CalculateDailyPivots(double &PP,double &R1,double &R2,double &S1,double &S2)
{
   double H,L,C;
   if(!GetPreviousDayOHLC(H,L,C))
   {
      // If cannot get previous day, attempt to compute using last D1 bar
      H = iHigh(_Symbol, PERIOD_D1, 1);
      L = iLow(_Symbol, PERIOD_D1, 1);
      C = iClose(_Symbol, PERIOD_D1, 1);
   }
   PP = (H + L + C) / 3.0;
   R1 = 2.0 * PP - L;
   S1 = 2.0 * PP - H;
   R2 = PP + (H - L);
   S2 = PP - (H - L);
}

//------------------------------------------------------------------
// Candle helpers (single-line wrappers)
//------------------------------------------------------------------
double COpen(int shift)  { return(iOpen(_Symbol, Period(), shift)); }
double CClose(int shift) { return(iClose(_Symbol, Period(), shift)); }
double CHigh(int shift)  { return(iHigh(_Symbol, Period(), shift)); }
double CLow(int shift)   { return(iLow(_Symbol, Period(), shift)); }

//------------------------------------------------------------------
// Pin bar detection rules
// - Nose/wick >= 2x body size (for direction)
// - Opposite wick <= 30% of total candle range
//------------------------------------------------------------------
bool IsBullishPinBar(int shift)
{
   double open = COpen(shift), close = CClose(shift);
   double high = CHigh(shift), low = CLow(shift);
   double body = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   double totalRange = high - low;
   if(totalRange <= 0.0 || body <= 0.0) return(false);
   // bullish body
   if(close <= open) return(false);
   if(lowerWick < 2.0 * body) return(false); // nose/wick >= 2x body
   if(upperWick > 0.3 * totalRange) return(false); // opposite wick small
   return(true);
}

bool IsBearishPinBar(int shift)
{
   double open = COpen(shift), close = CClose(shift);
   double high = CHigh(shift), low = CLow(shift);
   double body = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   double totalRange = high - low;
   if(totalRange <= 0.0 || body <= 0.0) return(false);
   // bearish body
   if(close >= open) return(false);
   if(upperWick < 2.0 * body) return(false);
   if(lowerWick > 0.3 * totalRange) return(false);
   return(true);
}

//------------------------------------------------------------------
// Engulfing detection: current candle (shift) engulfs previous (shift+1) body
//------------------------------------------------------------------
bool IsBullishEngulfing(int shift)
{
   double curO = COpen(shift), curC = CClose(shift);
   double prevO = COpen(shift+1), prevC = CClose(shift+1);
   // current must be bullish
   if(curC <= curO) return(false);
   double curLowBody = MathMin(curO, curC), curHighBody = MathMax(curO, curC);
   double prevLowBody = MathMin(prevO, prevC), prevHighBody = MathMax(prevO, prevC);
   return(curLowBody <= prevLowBody && curHighBody >= prevHighBody);
}

bool IsBearishEngulfing(int shift)
{
   double curO = COpen(shift), curC = CClose(shift);
   double prevO = COpen(shift+1), prevC = CClose(shift+1);
   if(curC >= curO) return(false);
   double curLowBody = MathMin(curO, curC), curHighBody = MathMax(curO, curC);
   double prevLowBody = MathMin(prevO, prevC), prevHighBody = MathMax(prevO, prevC);
   return(curLowBody <= prevLowBody && curHighBody >= prevHighBody);
}

//------------------------------------------------------------------
// Check whether any open position exists for this symbol & magic
//------------------------------------------------------------------
bool HasOpenPositionByMagic()
{
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      if(!PositionSelectByIndex(i)) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(sym != _Symbol) continue;
      long mag = (long)PositionGetInteger(POSITION_MAGIC);
      if(mag == MagicNumber) return(true);
   }
   return(false);
}

//------------------------------------------------------------------
// Place market order using MqlTradeRequest so we can set magic number
//------------------------------------------------------------------
bool PlaceMarketOrder(bool isBuy, double volume, double price, double sl, double tp, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.price  = price;
   request.sl     = sl;
   request.tp     = tp;
   request.deviation = 20;
   request.type   = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.type_filling = ORDER_FILLING_FOK;
   request.type_time = ORDER_TIME_GTC;
   request.magic = MagicNumber;
   request.comment = comment;

   if(!OrderSend(request,result))
   {
      PrintFormat("OrderSend() returned false, retcode=%d, comment=%s", result.retcode, result.comment);
      return(false);
   }
   if(result.retcode != TRADE_RETCODE_DONE)
   {
      PrintFormat("Market order failed, retcode=%d, comment=%s", result.retcode, result.comment);
      return(false);
   }
   PrintFormat("Market order placed: ticket=%I64u type=%s vol=%.2f price=%.5f sl=%.5f tp=%.5f",
               result.order, isBuy ? "BUY":"SELL", volume, result.price, sl, tp);
   return(true);
}

//------------------------------------------------------------------
// Place pending limit order (to close part of a position later).
// order_type must be ORDER_TYPE_SELL_LIMIT or ORDER_TYPE_BUY_LIMIT
//------------------------------------------------------------------
bool PlacePendingLimit(int order_type, double price, double volume, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = volume;
   request.price  = price;
   request.deviation = 20;
   request.type   = order_type;
   request.type_filling = ORDER_FILLING_IOC;
   request.type_time = ORDER_TIME_GTC;
   request.expiration = 0;
   request.magic = MagicNumber;
   request.comment = comment;

   if(!OrderSend(request,result))
   {
      PrintFormat("Pending OrderSend failed, retcode=%d comment=%s", result.retcode, result.comment);
      return(false);
   }
   // TRADE_RETCODE_DONE or TRADE_RETCODE_PLACED acceptable
   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
   {
      PrintFormat("Pending order not placed: retcode=%d comment=%s", result.retcode, result.comment);
      return(false);
   }
   PrintFormat("Pending order placed: ticket=%I64u type=%d vol=%.2f price=%.5f", result.order, order_type, volume, price);
   return(true);
}

//------------------------------------------------------------------
// Time window check (server time)
//------------------------------------------------------------------
bool IsWithinTradingHours()
{
   if(!EnableTradingHours) return(true);
   int hr = TimeHour(TimeCurrent());
   if(TradeStartHour <= TradeEndHour)
      return(hr >= TradeStartHour && hr <= TradeEndHour);
   else
      // wrap-around
      return(hr >= TradeStartHour || hr <= TradeEndHour);
}

//------------------------------------------------------------------
// Calculate lot size by risk percent (based on SL price distance)
// - If RiskPercent <= 0 -> use fixed LotSize
//------------------------------------------------------------------
double CalculateLotByRisk(double entry, double sl)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(RiskPercent <= 0.0)
      return NormalizeLotToStep(LotSize);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return NormalizeLotToStep(LotSize);

   double slDistance = MathAbs(entry - sl); // in price units
   if(slDistance <= 0.0) return NormalizeLotToStep(LotSize);

   // Try to compute monetary risk per lot using SYMBOL_TRADE_TICK_VALUE and tick size
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize > 0.0 && tickValue > 0.0)
   {
      double ticks = slDistance / tickSize;
      double riskPerLot = ticks * tickValue;
      if(riskPerLot <= 0.0) return NormalizeLotToStep(LotSize);
      double riskMoney = balance * (RiskPercent/100.0);
      double lots = riskMoney / riskPerLot;
      if(lots <= 0.0) return NormalizeLotToStep(LotSize);
      return NormalizeLotToStep(lots);
   }

   // Fallback: approximate using contract size and point value
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contractSize <= 0.0) contractSize = 100000.0; // conservative fallback
   double valuePerPoint = contractSize * g_point;   // value per 1 price point per 1 lot (approx)
   if(valuePerPoint <= 0.0) return NormalizeLotToStep(LotSize);
   double points = slDistance / g_point;
   double riskPerLotApprox = points * valuePerPoint;
   double riskMoney = balance * (RiskPercent/100.0);
   double lots = riskMoney / riskPerLotApprox;
   return NormalizeLotToStep(lots);
}

//------------------------------------------------------------------
// Helper: check proximity of a price to a level within threshold pips
//------------------------------------------------------------------
bool PriceNearLevel(double price, double level, double thresholdPips)
{
   return(MathAbs(price - level) <= thresholdPips * g_pip);
}

//------------------------------------------------------------------
// Main trade decision logic executed on new tick
//------------------------------------------------------------------
void CheckAndEnterTrade()
{
   // trading hours
   if(!IsWithinTradingHours()) return;

   // spread check (in points)
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPoints = (ask - bid) / g_point;
   if(spreadPoints > MaxSpread)
   {
      //PrintFormat("Spread too wide: %.1f > %.1f", spreadPoints, MaxSpread);
      return;
   }

   // only one position per magic
   if(HasOpenPositionByMagic()) return;

   // Use the last closed candle on chart timeframe: shift=1
   int sigShift = 1;
   datetime cTime = iTime(_Symbol, Period(), sigShift);
   if(cTime == 0) return;
   if(cTime == g_lastProcessedCandle) return; // already processed
   g_lastProcessedCandle = cTime;

   // Calculate pivot levels from previous daily
   double PP,R1,R2,S1,S2;
   CalculateDailyPivots(PP,R1,R2,S1,S2);

   // current midpoint price
   double currentPrice = (ask + bid) / 2.0;

   // market bias
   bool bullishBias = currentPrice > PP;
   bool bearishBias = currentPrice < PP;

   // pip conversion already computed in OnInit
   double proximityPips = MathMax(3.0, StopLossPips/2.0);

   // detect patterns on closed candle (shift=1)
   bool bullishPin = IsBullishPinBar(sigShift);
   bool bearishPin = IsBearishPinBar(sigShift);
   bool bullishEng = IsBullishEngulfing(sigShift);
   bool bearishEng = IsBearishEngulfing(sigShift);

   double sigOpen  = COpen(sigShift);
   double sigClose = CClose(sigShift);
   double sigHigh  = CHigh(sigShift);
   double sigLow   = CLow(sigShift);

   // LONG CONDITIONS (bullish bias): bullish pattern at S1 or PP (pullback)
   if(bullishBias)
   {
      bool pattern = bullishPin || bullishEng;
      bool nearS1 = PriceNearLevel(sigClose, S1, proximityPips) || PriceNearLevel(sigLow, S1, proximityPips);
      bool nearPP = PriceNearLevel(sigClose, PP, proximityPips) || PriceNearLevel(sigLow, PP, proximityPips);
      if(pattern && (nearS1 || nearPP))
      {
         double entry = ask; // buy market at ask
         // SL placed below low of signal candle (with small buffer)
         double sl = sigLow - 3.0 * g_point;
         // ensure SL not above entry
         if(sl >= entry) sl = entry - MathMax(10.0 * g_point, g_pip);
         double tp1 = entry + TakeProfit1Pips * g_pip;
         double tp2 = entry + TakeProfit2Pips * g_pip;
         // compute lot
         double lot = CalculateLotByRisk(entry, sl);
         if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         lot = NormalizeLotToStep(lot);
         if(lot <= 0.0) return;
         // Place market buy with SL set (no TP - we will close with pending limits)
         if(!PlaceMarketOrder(true, lot, entry, sl, 0.0, "PCS BUY")) return;
         // Place two SELL_LIMIT pending orders at TP1 and TP2 to take partial profits
         double vol1 = NormalizeDouble(lot/2.0,2);
         double vol2 = lot - vol1;
         if(vol1 < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) vol1 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(vol2 < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) vol2 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         // SELL_LIMITs are above market for closing long positions
         PlacePendingLimit(ORDER_TYPE_SELL_LIMIT, tp1, vol1, "PCS TP1");
         PlacePendingLimit(ORDER_TYPE_SELL_LIMIT, tp2, vol2, "PCS TP2");
      }
   }

   // SHORT CONDITIONS (bearish bias): bearish pattern at R1 or PP
   if(bearishBias)
   {
      bool pattern = bearishPin || bearishEng;
      bool nearR1 = PriceNearLevel(sigClose, R1, proximityPips) || PriceNearLevel(sigHigh, R1, proximityPips);
      bool nearPP = PriceNearLevel(sigClose, PP, proximityPips) || PriceNearLevel(sigHigh, PP, proximityPips);
      if(pattern && (nearR1 || nearPP))
      {
         double entry = bid; // sell market at bid
         double sl = sigHigh + 3.0 * g_point;
         if(sl <= entry) sl = entry + MathMax(10.0 * g_point, g_pip);
         double tp1 = entry - TakeProfit1Pips * g_pip;
         double tp2 = entry - TakeProfit2Pips * g_pip;
         double lot = CalculateLotByRisk(entry, sl);
         if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         lot = NormalizeLotToStep(lot);
         if(lot <= 0.0) return;
         if(!PlaceMarketOrder(false, lot, entry, sl, 0.0, "PCS SELL")) return;
         double vol1 = NormalizeDouble(lot/2.0,2);
         double vol2 = lot - vol1;
         if(vol1 < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) vol1 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(vol2 < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) vol2 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         // BUY_LIMITs are below market for closing short positions
         PlacePendingLimit(ORDER_TYPE_BUY_LIMIT, tp1, vol1, "PCS TP1");
         PlacePendingLimit(ORDER_TYPE_BUY_LIMIT, tp2, vol2, "PCS TP2");
      }
   }
}

//------------------------------------------------------------------
// OnInit: initialize globals
//------------------------------------------------------------------
int OnInit()
{
   // symbol settings
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(g_point <= 0.0) g_point = _Point;
   // pip: common definition - for 5 or 3 digit brokers pip = 10 * point
   if(g_digits == 3 || g_digits == 5) g_pip = g_point * 10.0; else g_pip = g_point;
   // Select symbol if not already
   if(!SymbolInfoInteger(_Symbol, SYMBOL_SELECT))
      SymbolSelect(_Symbol, true);
   PrintFormat("PivotCandleScalper initialized on %s timeframe=%d pip=%.10f point=%.10f digits=%d",
               _Symbol, Period(), g_pip, g_point, g_digits);
   return(INIT_SUCCEEDED);
}

//------------------------------------------------------------------
// OnDeinit
//------------------------------------------------------------------
void OnDeinit(const int reason)
{
   Print("PivotCandleScalper deinitialized.");
}

//------------------------------------------------------------------
// OnTick: primary entry point
//------------------------------------------------------------------
void OnTick()
{
   CheckAndEnterTrade();
}
//+------------------------------------------------------------------+
