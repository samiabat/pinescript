```PIVOT_CANDLE_SCALPER.mq5
//+------------------------------------------------------------------+
//|                                              PivotCandleScalper.mq5
//|  Expert Advisor: PivotCandleScalper
//|  Strategy: Daily Pivot Points + Candlestick reversal (Pin Bar / Engulfing)
//|  Timeframe: designed for M15 but works on any timeframe/symbol
//|  Author: Assistant (adapted & fixed compilation issues)
//+------------------------------------------------------------------+
#property copyright "PivotCandleScalper"
#property version   "1.01"
#property strict

#include <Trade\Trade.mqh>

//------------------------------------------------------------------
// Expert inputs
//------------------------------------------------------------------
input double LotSize            = 0.01;      // Fixed lot size (ignored if RiskPercent > 0)
input double RiskPercent        = 0.5;       // Percent of account balance to risk (0 = disabled)
input double StopLossPips       = 15.0;      // Default StopLoss in pips (used only as fallback)
input double TakeProfit1Pips    = 20.0;      // TP1 in pips
input double TakeProfit2Pips    = 40.0;      // TP2 in pips
input long   MagicNumber        = 202506;    // Magic number for EA trades
input double MaxSpread          = 30.0;      // Max spread allowed (in points)
input bool   EnableTradingHours = false;     // Restrict trading to certain hours?
input int    TradeStartHour     = 0;         // Trading start hour (server time)
input int    TradeEndHour       = 23;        // Trading end hour (server time)
//------------------------------------------------------------------

CTrade trade;                    // trade object (not required but included)
datetime lastSignalTime = 0;     // to avoid processing same closed candle multiple times

//------------------------- Utility: Lot normalization -------------------------
double NormalizeLot(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(minLot <= 0 || step <= 0) // safety fallback
      return(NormalizeDouble(lot,2));
   // clamp range
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   // quantize to step
   double steps = MathFloor((lot - minLot)/step + 0.5);
   double normalized = minLot + steps * step;
   // final clamp
   if(normalized < minLot) normalized = minLot;
   if(normalized > maxLot) normalized = maxLot;
   // normalize precision
   int digits = 8;
   return(NormalizeDouble(normalized,digits));
}

//------------------------- Previous daily OHLC -------------------------
// Get previous completed daily OHLC (shift=1)
bool GetPreviousDayOHLC(double &prevHigh,double &prevLow,double &prevClose)
{
   double highs[], lows[], closes[];
   // copy 1 bar starting from shift 1 (previous day)
   if(CopyHigh(_Symbol, PERIOD_D1, 1, 1, highs) != 1) return(false);
   if(CopyLow(_Symbol,  PERIOD_D1, 1, 1, lows)  != 1) return(false);
   if(CopyClose(_Symbol, PERIOD_D1, 1, 1, closes) != 1) return(false);
   prevHigh  = highs[0];
   prevLow   = lows[0];
   prevClose = closes[0];
   return(true);
}

//------------------------- Pivot calculation -------------------------
void CalculatePivots(double &PP,double &R1,double &R2,double &S1,double &S2)
{
   double H,L,C;
   if(!GetPreviousDayOHLC(H,L,C))
   {
      // fallback: try to read with iHigh/iLow/iClose (shift 1)
      H = iHigh(_Symbol, PERIOD_D1, 1);
      L = iLow(_Symbol,  PERIOD_D1, 1);
      C = iClose(_Symbol, PERIOD_D1, 1);
   }
   PP = (H + L + C) / 3.0;
   R1 = 2.0 * PP - L;
   S1 = 2.0 * PP - H;
   R2 = PP + (H - L);
   S2 = PP - (H - L);
}

//------------------------- Candle accessors (use _Period) -------------------------
double CandleOpen(int shift)  { return(iOpen(_Symbol, _Period, shift)); }
double CandleClose(int shift) { return(iClose(_Symbol,_Period, shift)); }
double CandleHigh(int shift)  { return(iHigh(_Symbol, _Period, shift)); }
double CandleLow(int shift)   { return(iLow(_Symbol,  _Period, shift)); }

//------------------------- Candlestick patterns -------------------------
// Pin Bar rules:
//  - for bullish pin: close > open, lower wick >= 2x body, opposite wick <= 30% total range
//  - for bearish pin: close < open, upper wick >= 2x body, opposite wick <= 30% total range
bool IsBullishPinBar(int shift)
{
   double open  = CandleOpen(shift);
   double close = CandleClose(shift);
   double high  = CandleHigh(shift);
   double low   = CandleLow(shift);
   double body  = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   double totalRange = high - low;
   if(totalRange <= 0.0 || body <= 0.0) return(false);
   if(close <= open) return(false); // must be bullish candle
   if(lowerWick < 2.0 * body) return(false); // nose >= 2x body
   if(upperWick > 0.3 * totalRange) return(false); // opposite wick small
   return(true);
}

bool IsBearishPinBar(int shift)
{
   double open  = CandleOpen(shift);
   double close = CandleClose(shift);
   double high  = CandleHigh(shift);
   double low   = CandleLow(shift);
   double body  = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   double totalRange = high - low;
   if(totalRange <= 0.0 || body <= 0.0) return(false);
   if(close >= open) return(false); // must be bearish candle
   if(upperWick < 2.0 * body) return(false); // nose >= 2x body
   if(lowerWick > 0.3 * totalRange) return(false);
   return(true);
}

// Engulfing detection: current candle (shift) engulfs previous candle's body (shift+1)
bool IsBullishEngulfing(int shift)
{
   double curO = CandleOpen(shift), curC = CandleClose(shift);
   double prevO = CandleOpen(shift+1), prevC = CandleClose(shift+1);
   if(curC <= curO) return(false); // current must be bullish
   double curLowBody  = MathMin(curO, curC);
   double curHighBody = MathMax(curO, curC);
   double prevLowBody = MathMin(prevO, prevC);
   double prevHighBody= MathMax(prevO, prevC);
   return(curLowBody <= prevLowBody && curHighBody >= prevHighBody);
}

bool IsBearishEngulfing(int shift)
{
   double curO = CandleOpen(shift), curC = CandleClose(shift);
   double prevO = CandleOpen(shift+1), prevC = CandleClose(shift+1);
   if(curC >= curO) return(false); // current must be bearish
   double curLowBody  = MathMin(curO, curC);
   double curHighBody = MathMax(curO, curC);
   double prevLowBody = MathMin(prevO, prevC);
   double prevHighBody= MathMax(prevO, prevC);
   return(curLowBody <= prevLowBody && curHighBody >= prevHighBody);
}

//------------------------- Check if position exists for this symbol & magic -------------------------
bool HasOpenPositionWithMagic()
{
   int total = PositionsTotal();
   for(int i=0;i<total;i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      long mag = (long)PositionGetInteger(POSITION_MAGIC);
      if(sym == _Symbol && mag == MagicNumber) return(true);
   }
   return(false);
}

//------------------------- Send market order helper -------------------------
bool SendMarketOrder(bool isBuy, double volume, double slPrice, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.price  = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.deviation = 10;
   request.type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.type_filling = ORDER_FILLING_FOK;
   request.type_time = ORDER_TIME_GTC;
   request.magic = MagicNumber;
   request.comment = comment;
   if(slPrice > 0.0) request.sl = slPrice;
   // no TP: we'll use pending orders to close partials

   bool ok = OrderSend(request, result);
   if(!ok)
   {
      PrintFormat("OrderSend() returned false, retcode=%d comment=%s", result.retcode, result.comment);
      return(false);
   }
   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_DONE_REMAINDER)
   {
      PrintFormat("Market order not completed. retcode=%d comment=%s", result.retcode, result.comment);
      return(false);
   }
   PrintFormat("Market order placed: ticket=%I64u type=%s vol=%.2f price=%.5f",
               result.order, isBuy ? "BUY" : "SELL", volume, request.price);
   return(true);
}

//------------------------- Send pending limit order helper -------------------------
// order_type must be one of ORDER_TYPE_BUY_LIMIT, ORDER_TYPE_SELL_LIMIT, etc.
bool SendPendingOrder(ENUM_ORDER_TYPE order_type, double price, double volume, datetime expiration, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = volume;
   request.price  = price;
   request.deviation = 10;
   request.type = order_type;
   request.type_time = ORDER_TIME_SPECIFIED;
   request.expiration = expiration;
   request.type_filling = ORDER_FILLING_IOC;
   request.magic = MagicNumber;
   request.comment = comment;

   bool ok = OrderSend(request, result);
   if(!ok)
   {
      PrintFormat("Pending OrderSend() returned false, retcode=%d comment=%s", result.retcode, result.comment);
      return(false);
   }
   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
   {
      PrintFormat("Pending order not placed. retcode=%d comment=%s", result.retcode, result.comment);
      return(false);
   }
   PrintFormat("Pending order placed: ticket=%I64u type=%d vol=%.2f price=%.5f", result.order, (int)order_type, volume, price);
   return(true);
}

//------------------------- Trading hours check -------------------------
bool IsWithinTradingHours()
{
   if(!EnableTradingHours) return(true);
   int hour = TimeHour(TimeCurrent());
   if(TradeStartHour <= TradeEndHour)
      return(hour >= TradeStartHour && hour <= TradeEndHour);
   else
      return(hour >= TradeStartHour || hour <= TradeEndHour); // wrap-around
}

//------------------------- Risk-based lot calculation -------------------------
double CalculateLotByRisk(bool isBuy, double entryPrice, double slPrice)
{
   // If RiskPercent disabled, return fixed LotSize normalized
   if(RiskPercent <= 0.0) return NormalizeLot(LotSize);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return NormalizeLot(LotSize);

   double slDistance = MathAbs(entryPrice - slPrice); // price units
   if(slDistance <= 0.0) return NormalizeLot(LotSize);

   // try to use tick size/value
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double riskMoney = balance * (RiskPercent / 100.0);

   if(tickSize > 0.0 && tickValue > 0.0)
   {
      double ticks = slDistance / tickSize;
      double riskPerLot = ticks * tickValue;
      if(riskPerLot <= 0.0) return NormalizeLot(LotSize);
      double lot = riskMoney / riskPerLot;
      return NormalizeLot(lot);
   }

   // fallback approximate calculation
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(point <= 0.0) point = _Point;
   if(contractSize <= 0.0) contractSize = 100000.0; // typical for FX
   double valuePerPointPerLot = contractSize * point;
   if(valuePerPointPerLot <= 0.0) return NormalizeLot(LotSize);
   double points = slDistance / point;
   double riskPerLot = points * valuePerPointPerLot;
   if(riskPerLot <= 0.0) return NormalizeLot(LotSize);
   double lot = riskMoney / riskPerLot;
   return NormalizeLot(lot);
}

//------------------------- Helper: check if price is near a level (threshold in pips) -------------------------
bool IsPriceNearLevel(double price, double level, double thresholdPips, double pipSize)
{
   double diff = MathAbs(price - level);
   return(diff <= thresholdPips * pipSize);
}

//------------------------- Main trade decision routine -------------------------
void CheckAndTrade()
{
   // respect trading hours setting
   if(!IsWithinTradingHours()) return;

   // check spread
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;
   double spreadPoints = (ask - bid) / point;
   if(spreadPoints > MaxSpread) return; // spread too wide

   // only one position per symbol+magic
   if(HasOpenPositionWithMagic()) return;

   // use the last closed candle (shift=1)
   int signalShift = 1;
   datetime candleCloseTime = iTime(_Symbol, _Period, signalShift);
   if(candleCloseTime == 0) return;
   if(candleCloseTime == lastSignalTime) return; // already processed
   lastSignalTime = candleCloseTime;

   // calculate daily pivots
   double PP,R1,R2,S1,S2;
   CalculatePivots(PP,R1,R2,S1,S2);

   // define bias: current mid price vs PP
   double currentMid = (ask + bid) / 2.0;
   bool bullishBias = currentMid > PP;
   bool bearishBias = currentMid < PP;

   // pipSize: convert input "pips" to price units (handle 3/5 digit vs others)
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pipSize = point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);

   // proximity threshold in pips (how close candle must be to pivot level)
   double proximityPips = MathMax(3.0, StopLossPips/2.0);

   // detect patterns on closed candle (shift=1)
   bool bullishPin = IsBullishPinBar(signalShift);
   bool bearishPin = IsBearishPinBar(signalShift);
   bool bullishEng = IsBullishEngulfing(signalShift);
   bool bearishEng = IsBearishEngulfing(signalShift);

   double sigHigh = CandleHigh(signalShift);
   double sigLow  = CandleLow(signalShift);
   double sigClose= CandleClose(signalShift);

   // ----- LONG logic -----
   if(bullishBias)
   {
      bool pattern = bullishPin || bullishEng;
      bool nearS1 = IsPriceNearLevel(sigClose, S1, proximityPips, pipSize) || IsPriceNearLevel(sigLow, S1, proximityPips, pipSize);
      bool nearPP = IsPriceNearLevel(sigClose, PP, proximityPips, pipSize) || IsPriceNearLevel(sigLow, PP, proximityPips, pipSize);
      if(pattern && (nearS1 || nearPP))
      {
         // Prepare order parameters
         double entry = ask; // market buy will execute at ask
         double sl    = sigLow - 3.0 * point; // SL below signal candle low with buffer
         if(sl <= 0) sl = entry - StopLossPips * pipSize; // fallback
         double tp1   = entry + TakeProfit1Pips * pipSize;
         double tp2   = entry + TakeProfit2Pips * pipSize;

         double lot = CalculateLotByRisk(true, entry, sl);
         double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(lot < minVol) lot = minVol;
         lot = NormalizeLot(lot);
         if(lot <= 0.0) return;

         // place market buy
         if(!SendMarketOrder(true, lot, sl, "PCS BUY")) return;

         // place pending SELL_LIMIT orders to take profits (partial closes)
         double vol1 = NormalizeLot(lot/2.0);
         double vol2 = NormalizeLot(lot - vol1);
         if(vol1 < minVol) vol1 = minVol;
         if(vol2 < minVol) vol2 = minVol;
         datetime exp = TimeCurrent() + 7*24*3600; // 7 days expiration
         // SELL_LIMIT at TP1 and TP2 (above current price)
         SendPendingOrder(ORDER_TYPE_SELL_LIMIT, tp1, vol1, exp, "PCS TP1");
         SendPendingOrder(ORDER_TYPE_SELL_LIMIT, tp2, vol2, exp, "PCS TP2");
      }
   }

   // ----- SHORT logic -----
   if(bearishBias)
   {
      bool pattern = bearishPin || bearishEng;
      bool nearR1 = IsPriceNearLevel(sigClose, R1, proximityPips, pipSize) || IsPriceNearLevel(sigHigh, R1, proximityPips, pipSize);
      bool nearPP = IsPriceNearLevel(sigClose, PP, proximityPips, pipSize) || IsPriceNearLevel(sigHigh, PP, proximityPips, pipSize);
      if(pattern && (nearR1 || nearPP))
      {
         double entry = bid; // market sell at bid
         double sl    = sigHigh + 3.0 * point; // SL above signal candle high
         if(sl <= 0) sl = entry + StopLossPips * pipSize; // fallback
         double tp1   = entry - TakeProfit1Pips * pipSize;
         double tp2   = entry - TakeProfit2Pips * pipSize;

         double lot = CalculateLotByRisk(false, entry, sl);
         double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(lot < minVol) lot = minVol;
         lot = NormalizeLot(lot);
         if(lot <= 0.0) return;

         // place market sell
         if(!SendMarketOrder(false, lot, sl, "PCS SELL")) return;

         // place pending BUY_LIMIT orders to take profits (partial closes)
         double vol1 = NormalizeLot(lot/2.0);
         double vol2 = NormalizeLot(lot - vol1);
         if(vol1 < minVol) vol1 = minVol;
         if(vol2 < minVol) vol2 = minVol;
         datetime exp = TimeCurrent() + 7*24*3600;
         // BUY_LIMIT at TP1 and TP2 (below current price)
         SendPendingOrder(ORDER_TYPE_BUY_LIMIT, tp1, vol1, exp, "PCS TP1");
         SendPendingOrder(ORDER_TYPE_BUY_LIMIT, tp2, vol2, exp, "PCS TP2");
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // ensure symbol selected in MarketWatch
   if(!SymbolInfoInteger(_Symbol, SYMBOL_SELECT))
   {
      if(!SymbolSelect(_Symbol, true))
      {
         PrintFormat("Failed to select symbol %s", _Symbol);
         return(INIT_FAILED);
      }
   }
   PrintFormat("PivotCandleScalper initialized for %s timeframe=%d", _Symbol, _Period);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("PivotCandleScalper stopped.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckAndTrade();
}
//+------------------------------------------------------------------+
```
