//+------------------------------------------------------------------+
//|                                                  ICT_Strategy.mq5 |
//|                                 Converted from Python by Grok AI |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Converted from Python by Grok AI"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

// Config parameters as inputs
input double RiskPerTrade = 0.015;
input int MaxTradesPerDay = 40;
input double MinFvgPips = 2.0;
input double SweepRejectionPips = 0.5;
input double StopLossBufferPips = 2.0;
input double TargetMinR = 3.0;
input double TargetMaxR = 5.0;
input double BaseSpreadPips = 0.6;
input double CommissionPerM = 7; // Not used in EA, broker handles
input double MinBalanceThreshold = 100.0;
input long MaxPositionUnits = 1000000;
input bool RelaxedMode = true;

// Constants
const int LOOKBACK = 100; // For copying rates

// Structures
struct SweepStruct {
   string type;
   double price;
   int idx;
   string trend;
   int detected;
};

struct FvgStruct {
   string type;
   double bottom;
   double top;
   int idx;
};

SweepStruct recent_sweeps[];

// Global variables
static datetime last_bar_time = 0;
static int daily_trade_count = 0;
static datetime current_day = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   if (_Period != PERIOD_M15 || StringFind(_Symbol, "EURUSD") < 0) {
      Print("This EA is designed for EURUSD M15 only.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   MathSrand((uint)TimeCurrent());
   ArrayResize(recent_sweeps, 0);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if (current_bar_time == last_bar_time) return;
   last_bar_time = current_bar_time;

   // Check trading session
   if (!IsTradingSession(TimeCurrent())) return;

   // Daily trade count reset
   datetime day = TimeCurrent() - (TimeCurrent() % 86400);
   if (day != current_day) {
      current_day = day;
      daily_trade_count = 0;
   }

   // Copy rates
   MqlRates rates[];
   int copied = CopyRates(_Symbol, _Period, 0, LOOKBACK, rates);
   if (copied < 50) return;
   // rates[0] is oldest, rates[copied-1] is newest

   int count = copied;
   int idx = count - 1; // Newest bar

   // Calculate trend
   string trend = Detect1hTrend(rates, count, idx);

   // Remove old sweeps
   for (int j = ArraySize(recent_sweeps) - 1; j >= 0; j--) {
      if (idx - recent_sweeps[j].detected > 30) {
         ArrayRemove(recent_sweeps, j, 1);
      }
   }

   // If neutral and not relaxed, skip detection and entry
   if (trend == "neutral" && !RelaxedMode) return;

   // Detect sweep
   SweepStruct sweep;
   if (DetectLiquiditySweep(rates, count, idx, sweep)) {
      sweep.trend = trend;
      sweep.detected = idx;
      int size = ArraySize(recent_sweeps);
      ArrayResize(recent_sweeps, size + 1);
      recent_sweeps[size] = sweep;
   }

   // Check balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (balance < MinBalanceThreshold) return;

   // Check if already has position or pending
   if (HasPositionOrPending()) return;

   // Check if max trades per day reached
   if (daily_trade_count >= MaxTradesPerDay) return;

   // Check for entry
   for (int j = 0; j < ArraySize(recent_sweeps); j++) {
      SweepStruct sw = recent_sweeps[j];
      if (idx < sw.idx + 1) continue;
      if (trend != "neutral" && sw.trend != trend) continue;
      if (!DetectMss(rates, sw.idx, idx, sw.type)) continue;

      FvgStruct fvg;
      if (!DetectFvg(rates, count, idx, fvg)) continue;
      if (idx - fvg.idx < 0) continue; // FVG_CONFIRMATION_CANDLES = 0

      string expected = (sw.type == "bull_sweep") ? "bullish" : "bearish";
      if (fvg.type != expected) continue;

      // Remove the used sweep
      ArrayRemove(recent_sweeps, j, 1);
      j--; // Adjust index

      // Build and place pending order
      double spr = GetSpreadPips(rates[idx]);
      double entry, sl, tp, sl_pips;
      string direction = expected;

      if (direction == "bullish") {
         entry = fvg.bottom + PipsToPrice(spr);
         sl = sw.price - PipsToPrice(StopLossBufferPips);
         sl_pips = PriceToPips(entry - sl);
         double rr = (double)MathRand() / 32767.0 * (TargetMaxR - TargetMinR) + TargetMinR;
         tp = entry + PipsToPrice(sl_pips * rr);
      } else {
         entry = fvg.top - PipsToPrice(spr);
         sl = sw.price + PipsToPrice(StopLossBufferPips);
         sl_pips = PriceToPips(sl - entry);
         double rr = (double)MathRand() / 32767.0 * (TargetMaxR - TargetMinR) + TargetMinR;
         tp = entry - PipsToPrice(sl_pips * rr);
      }

      double size = CalculatePositionSize(balance, sl_pips);
      double lots = NormalizeDouble(size / 100000.0, 2);
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if (lots < min_lot) continue;

      // Place pending order
      MQLTradeRequest request = {0};
      MQLTradeResult result = {0};
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = lots;
      request.sl = NormalizeDouble(sl, _Digits);
      request.tp = NormalizeDouble(tp, _Digits);
      request.price = NormalizeDouble(entry, _Digits);
      request.deviation = 3;

      if (direction == "bullish") {
         request.type = ORDER_TYPE_BUY_LIMIT;
      } else {
         request.type = ORDER_TYPE_SELL_LIMIT;
      }

      if (!OrderSend(request, result)) {
         Print("OrderSend failed: ", GetLastError());
      } else {
         Print("Pending order placed: Ticket=", result.order, " Direction=", direction, " Entry=", entry, " SL=", sl, " TP=", tp);
         daily_trade_count++;
         break; // Only one trade per bar
      }
   }
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
bool IsTradingSession(datetime dt) {
   MqlDateTime tm;
   TimeToStruct(dt, tm);
   if ((tm.hour >= 7 && tm.hour < 16) || (tm.hour >= 12 && tm.hour < 21)) return true;
   return false;
}

string Detect1hTrend(MqlRates &data[], int count, int idx) {
   int look = MathMin(32, idx);
   if (look < 16) return "neutral";
   int start_sub = idx - look + 1;

   double recent_h = 0;
   double recent_l = DBL_MAX;
   int recent_start = MathMax(idx - 7, 0);
   for (int k = recent_start; k <= idx; k++) {
      recent_h = MathMax(recent_h, data[k].high);
      recent_l = MathMin(recent_l, data[k].low);
   }

   double older_h = 0;
   double older_l = DBL_MAX;
   int older_end = MathMin(start_sub + 7, idx);
   for (int k = start_sub; k <= older_end; k++) {
      older_h = MathMax(older_h, data[k].high);
      older_l = MathMin(older_l, data[k].low);
   }

   if (recent_h > older_h && recent_l > older_l) return "bullish";
   if (recent_h < older_h && recent_l < older_l) return "bearish";
   return "neutral";
}

bool DetectLiquiditySweep(MqlRates &data[], int count, int idx, SweepStruct &sweep) {
   if (idx < 5) return false;
   MqlRates &cur = data[idx];
   double prev_h_max = 0;
   double prev_l_min = DBL_MAX;
   int prev_start = MathMax(idx - 20, 0);
   for (int k = prev_start; k < idx; k++) {
      prev_h_max = MathMax(prev_h_max, data[k].high);
      prev_l_min = MathMin(prev_l_min, data[k].low);
   }

   if (cur.high > prev_h_max && cur.close < cur.high - PipsToPrice(SweepRejectionPips)) {
      sweep.type = "bear_sweep";
      sweep.price = cur.high;
      sweep.idx = idx;
      return true;
   }
   if (cur.low < prev_l_min && cur.close > cur.low + PipsToPrice(SweepRejectionPips)) {
      sweep.type = "bull_sweep";
      sweep.price = cur.low;
      sweep.idx = idx;
      return true;
   }
   return false;
}

bool DetectMss(MqlRates &data[], int sweep_idx, int cur_idx, string sweep_type) {
   if (cur_idx <= sweep_idx) return false;
   if (sweep_type == "bear_sweep") {
      double min_low = DBL_MAX;
      for (int k = sweep_idx + 1; k <= cur_idx; k++) {
         min_low = MathMin(min_low, data[k].low);
      }
      return min_low < data[sweep_idx].low;
   } else {
      double max_high = 0;
      for (int k = sweep_idx + 1; k <= cur_idx; k++) {
         max_high = MathMax(max_high, data[k].high);
      }
      return max_high > data[sweep_idx].high;
   }
}

bool DetectFvg(MqlRates &data[], int count, int idx, FvgStruct &fvg) {
   if (idx < 2) return false;
   MqlRates &c1 = data[idx - 2];
   MqlRates &c3 = data[idx];
   if (c3.low > c1.high) {
      double gap = c3.low - c1.high;
      if (PriceToPips(gap) >= MinFvgPips) {
         fvg.type = "bullish";
         fvg.bottom = c1.high;
         fvg.top = c3.low;
         fvg.idx = idx;
         return true;
      }
   }
   if (c3.high < c1.low) {
      double gap = c1.low - c3.high;
      if (PriceToPips(gap) >= MinFvgPips) {
         fvg.type = "bearish";
         fvg.bottom = c3.high;
         fvg.top = c1.low;
         fvg.idx = idx;
         return true;
      }
   }
   return false;
}

double GetSpreadPips(MqlRates &candle) {
   long vol = candle.tick_volume;
   if (vol > 300) return BaseSpreadPips;
   if (vol > 100) return BaseSpreadPips * 1.5;
   return BaseSpreadPips * 2.5;
}

double CalculatePositionSize(double balance, double sl_pips) {
   if (balance <= 0 || sl_pips <= 0) return 0;
   double risk = balance * RiskPerTrade;
   double size = risk / (sl_pips * 0.0001);
   return MathMin(size, (double)MaxPositionUnits);
}

bool HasPositionOrPending() {
   int total_pos = PositionsTotal();
   for (int i = 0; i < total_pos; i++) {
      if (PositionGetTicket(i) && PositionGetString(POSITION_SYMBOL) == _Symbol) return true;
   }
   int total_ord = OrdersTotal();
   for (int i = 0; i < total_ord; i++) {
      if (OrderGetTicket(i) && OrderGetString(ORDER_SYMBOL) == _Symbol) return true;
   }
   return false;
}

double PipsToPrice(double p) {
   return p * 0.0001;
}

double PriceToPips(double d) {
   return d / 0.0001;
}