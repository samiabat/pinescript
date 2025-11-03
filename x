//+------------------------------------------------------------------+
//|                                                 ICT_Backtest.mq5 |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input double InitialBalance = 200.0;
input double RiskPerTrade = 0.015;
input int MaxTradesPerDay = 40;
input double MinFvgPips = 2.0;
input double SweepRejectionPips = 0.5;
input double StopLossBufferPips = 2.0;
input double TargetMinR = 3.0;
input double TargetMaxR = 5.0;
input double BaseSpreadPips = 0.6;
input double SlippagePipsBase = 0.3;
input double CommissionPerM = 3.5;
input double MinBalanceThreshold = 100.0;
input long MaxPositionUnits = 10000000;
input bool RelaxedMode = true;

// Session times (UTC, assuming server time is UTC)
datetime LondonOpen = D'00:00:00' + 7*3600;
datetime LondonClose = D'00:00:00' + 16*3600;
datetime NyOpen = D'00:00:00' + 12*3600;
datetime NyClose = D'00:00:00' + 21*3600;

// Structures
struct SweepInfo {
   string type;
   double price;
   int idx;
   string trend;
   int detected;
};

struct FvgInfo {
   string type;
   double bottom;
   double top;
   int idx;
};

struct TradeInfo {
   datetime entry_time;
   double entry_price;
   string direction;
   double stop_loss;
   double take_profit;
   long position_size;
   datetime exit_time;
   double exit_price;
   string result;
   double pnl_pips;
   double pnl_usd;
};

// Globals
MqlRates rates_array[];
TradeInfo trades_array[];
TradeInfo active_trade = {};
double current_balance = InitialBalance;
double initial_balance = InitialBalance;
datetime equity_times[];
double equity_values[];
datetime current_daily_date = 0;
int daily_trade_count = 0;
SweepInfo recent_sweeps[];
int sweeps_count = 0;

// Helper functions
double PipsToPrice(double pips) {
   return pips * 0.0001;
}

double PriceToPips(double price_diff) {
   return price_diff / 0.0001;
}

bool IsTradingSession(datetime dt) {
   MqlDateTime tm_struct;
   TimeToStruct(dt, tm_struct);
   datetime time_of_day = D'00:00:00' + tm_struct.hour * 3600 + tm_struct.min * 60 + tm_struct.sec;
   bool in_london = (time_of_day >= LondonOpen && time_of_day <= LondonClose);
   bool in_ny = (time_of_day >= NyOpen && time_of_day <= NyClose);
   return in_london || in_ny;
}

string Detect1hTrend(int current_idx) {
   int lookback = MathMin(32, current_idx);
   if (lookback < 16) return "neutral";
   double recent_high = 0, recent_low = DBL_MAX;
   double older_high = 0, older_low = DBL_MAX;
   for (int k = current_idx - 8; k < current_idx; k++) {
      recent_high = MathMax(recent_high, rates_array[k].high);
      recent_low = MathMin(recent_low, rates_array[k].low);
   }
   for (int k = current_idx - lookback; k < current_idx - 8; k++) {
      older_high = MathMax(older_high, rates_array[k].high);
      older_low = MathMin(older_low, rates_array[k].low);
   }
   if (recent_high > older_high && recent_low > older_low) return "bullish";
   if (recent_high < older_high && recent_low < older_low) return "bearish";
   return "neutral";
}

SweepInfo DetectLiquiditySweep(int current_idx) {
   SweepInfo null_sweep;
   null_sweep.type = "";
   if (current_idx < 5) return null_sweep;
   MqlRates cur_candle = rates_array[current_idx];
   double prev_max_high = 0, prev_min_low = DBL_MAX;
   for (int k = current_idx - 20; k < current_idx; k++) {
      prev_max_high = MathMax(prev_max_high, rates_array[k].high);
      prev_min_low = MathMin(prev_min_low, rates_array[k].low);
   }
   if (cur_candle.high > prev_max_high && cur_candle.close < cur_candle.high - PipsToPrice(SweepRejectionPips)) {
      SweepInfo s;
      s.type = "bear_sweep";
      s.price = cur_candle.high;
      s.idx = current_idx;
      return s;
   }
   if (cur_candle.low < prev_min_low && cur_candle.close > cur_candle.low + PipsToPrice(SweepRejectionPips)) {
      SweepInfo s;
      s.type = "bull_sweep";
      s.price = cur_candle.low;
      s.idx = current_idx;
      return s;
   }
   return null_sweep;
}

bool DetectMss(int sweep_idx, int cur_idx, string sweep_type) {
   if (cur_idx <= sweep_idx) return false;
   double min_low = DBL_MAX, max_high = 0;
   for (int k = sweep_idx + 1; k <= cur_idx; k++) {
      min_low = MathMin(min_low, rates_array[k].low);
      max_high = MathMax(max_high, rates_array[k].high);
   }
   if (sweep_type == "bear_sweep") return min_low < rates_array[sweep_idx].low;
   else return max_high > rates_array[sweep_idx].high;
}

FvgInfo DetectFvg(int current_idx) {
   FvgInfo null_fvg;
   null_fvg.type = "";
   if (current_idx < 2) return null_fvg;
   MqlRates c1 = rates_array[current_idx - 2];
   MqlRates c3 = rates_array[current_idx];
   if (c3.low > c1.high && PriceToPips(c3.low - c1.high) >= MinFvgPips) {
      FvgInfo f;
      f.type = "bullish";
      f.bottom = c1.high;
      f.top = c3.low;
      f.idx = current_idx;
      return f;
   }
   if (c3.high < c1.low && PriceToPips(c1.low - c3.high) >= MinFvgPips) {
      FvgInfo f;
      f.type = "bearish";
      f.bottom = c3.high;
      f.top = c1.low;
      f.idx = current_idx;
      return f;
   }
   return null_fvg;
}

double SpreadPips(MqlRates &candle) {
   long vol = candle.tick_volume;
   if (vol > 300) return BaseSpreadPips;
   if (vol > 100) return BaseSpreadPips * 1.5;
   return BaseSpreadPips * 2.5;
}

double SlippagePips(long units) {
   double factor = MathMin((double)units / 1000000.0, 5.0);
   return SlippagePipsBase * (1 + factor);
}

double CommissionUsd(long units) {
   return CommissionPerM * ((double)units / 1000000.0);
}

long CalculatePositionSize(double bal, double sl_pips) {
   if (bal <= 0 || sl_pips <= 0) return 0;
   double risk = bal * RiskPerTrade;
   long size = (long)(risk / (sl_pips * 0.0001));
   return MathMin(size, MaxPositionUnits);
}

bool CheckTradeExit(TradeInfo &trade, MqlRates &candle) {
   long pos = trade.position_size;
   double spr = SpreadPips(candle);
   double slp = SlippagePips(pos);
   double comm = CommissionUsd(pos);

   if (trade.direction == "bullish") {
      if (candle.low <= trade.stop_loss) {
         trade.exit_price = trade.stop_loss - PipsToPrice(slp);
         trade.exit_time = candle.time;
         trade.result = "SL";
         trade.pnl_pips = -PriceToPips(trade.entry_price - trade.exit_price);
         trade.pnl_usd = trade.pnl_pips * 0.0001 * pos - comm;
         return true;
      }
      if (candle.high >= trade.take_profit) {
         trade.exit_price = trade.take_profit - PipsToPrice(slp);
         trade.exit_time = candle.time;
         trade.result = "TP";
         trade.pnl_pips = PriceToPips(trade.take_profit - trade.entry_price);
         trade.pnl_usd = trade.pnl_pips * 0.0001 * pos - comm;
         return true;
      }
   } else {
      if (candle.high >= trade.stop_loss) {
         trade.exit_price = trade.stop_loss + PipsToPrice(slp);
         trade.exit_time = candle.time;
         trade.result = "SL";
         trade.pnl_pips = -PriceToPips(trade.exit_price - trade.entry_price);
         trade.pnl_usd = trade.pnl_pips * 0.0001 * pos - comm;
         return true;
      }
      if (candle.low <= trade.take_profit) {
         trade.exit_price = trade.take_profit + PipsToPrice(slp);
         trade.exit_time = candle.time;
         trade.result = "TP";
         trade.pnl_pips = PriceToPips(trade.entry_price - trade.take_profit);
         trade.pnl_usd = trade.pnl_pips * 0.0001 * pos - comm;
         return true;
      }
   }
   return false;
}

// OnInit
int OnInit() {
   MqlDateTime start_time, end_time;
   TimeToStruct(D'2021.10.29 20:15:00', start_time);
   TimeToStruct(D'2025.10.31 20:45:00', end_time);
   datetime start_dt = StructToTime(start_time);
   datetime end_dt = StructToTime(end_time);
   int bars_copied = CopyRates("EURUSD", PERIOD_M15, start_dt, end_dt, rates_array);
   if (bars_copied <= 0) {
      Print("Failed to copy rates: ", GetLastError());
      return INIT_FAILED;
   }
   PrintFormat("Loaded %d bars", bars_copied);

   ArrayResize(trades_array, 0, 5000);
   ArrayResize(equity_times, 0, 5000);
   ArrayResize(equity_values, 0, 5000);
   ArrayResize(recent_sweeps, 100);
   sweeps_count = 0;
   active_trade.entry_time = 0;
   current_balance = InitialBalance;
   current_daily_date = 0;
   daily_trade_count = 0;

   int total_bars = ArraySize(rates_array);
   for (int i = 0; i < total_bars; i++) {
      if (i % 5000 == 0) PrintFormat("Progress: %.1f%% (%d/%d)", (double)i / total_bars * 100, i, total_bars);

      if (i % 100 == 0 || i == total_bars - 1) {
         int eq_size = ArraySize(equity_times);
         ArrayResize(equity_times, eq_size + 1, 5000);
         ArrayResize(equity_values, eq_size + 1, 5000);
         equity_times[eq_size] = rates_array[i].time;
         equity_values[eq_size] = current_balance;
      }

      MqlRates current_candle = rates_array[i];

      if (active_trade.entry_time != 0 && CheckTradeExit(active_trade, current_candle)) {
         current_balance += active_trade.pnl_usd;
         int trades_size = ArraySize(trades_array);
         ArrayResize(trades_array, trades_size + 1, 5000);
         trades_array[trades_size] = active_trade;
         PrintFormat("Trade #%d closed: %s | %.1f pips | $%.2f", trades_size + 1, active_trade.result, active_trade.pnl_pips, active_trade.pnl_usd);
         active_trade.entry_time = 0;
         continue;
      }

      if (!IsTradingSession(current_candle.time) || current_balance < MinBalanceThreshold) continue;

      datetime day_date = current_candle.time - (current_candle.time % 86400);
      if (day_date != current_daily_date) {
         current_daily_date = day_date;
         daily_trade_count = 0;
      }
      if (daily_trade_count >= MaxTradesPerDay) continue;

      TradeInfo new_trade = CheckEntry(i);
      if (new_trade.entry_time != 0) {
         active_trade = new_trade;
         daily_trade_count++;
         PrintFormat("Trade #%d opened at %s", ArraySize(trades_array) + 1, TimeToString(new_trade.entry_time));
         PrintFormat("  %s | Entry: %.5f | SL: %.5f (%.1f pips) | TP: %.5f", StringToUpper(new_trade.direction), new_trade.entry_price, new_trade.stop_loss, PriceToPips(MathAbs(new_trade.entry_price - new_trade.stop_loss)), new_trade.take_profit);
      }
   }

   if (active_trade.entry_time != 0) {
      MqlRates last_candle = rates_array[ArraySize(rates_array) - 1];
      active_trade.exit_time = last_candle.time;
      active_trade.exit_price = last_candle.close;
      active_trade.result = "Timeout";
      active_trade.pnl_pips = PriceToPips(
         (active_trade.direction == "bullish") ? (active_trade.exit_price - active_trade.entry_price) : (active_trade.entry_price - active_trade.exit_price)
      );
      active_trade.pnl_usd = active_trade.pnl_pips * 0.0001 * active_trade.position_size;
      current_balance += active_trade.pnl_usd;
      int trades_size = ArraySize(trades_array);
      ArrayResize(trades_array, trades_size + 1, 5000);
      trades_array[trades_size] = active_trade;
   }

   PrintSummary();

   return INIT_SUCCEEDED;
}

TradeInfo CheckEntry(int idx) {
   TradeInfo null_trade = {};
   null_trade.entry_time = 0;
   if (idx < 50) return null_trade;

   string trend = Detect1hTrend(idx);
   if (trend == "neutral" && !RelaxedMode) return null_trade;

   SweepInfo sweep = DetectLiquiditySweep(idx);
   if (sweep.type != "") {
      sweep.trend = trend;
      sweep.detected = idx;
      int sweeps_size = sweeps_count;
      if (sweeps_size < ArraySize(recent_sweeps)) {
         recent_sweeps[sweeps_size] = sweep;
         sweeps_count++;
      }
   }

   for (int s = 0; s < sweeps_count; s++) {
      SweepInfo sw = recent_sweeps[s];
      if (idx - sw.detected > 30) {
         recent_sweeps[s] = recent_sweeps[sweeps_count - 1];
         sweeps_count--;
         s--;
         continue;
      }
      if (idx < sw.idx + 1) continue;
      if (trend != "neutral" && sw.trend != trend) continue;
      if (!DetectMss(sw.idx, idx, sw.type)) continue;

      FvgInfo fvg = DetectFvg(idx);
      if (fvg.type == "") continue;

      string expected = (sw.type == "bear_sweep") ? "bearish" : "bullish";
      if (fvg.type != expected) continue;

      // Remove the used sweep
      recent_sweeps[s] = recent_sweeps[sweeps_count - 1];
      sweeps_count--;
      s--;

      return BuildTrade(idx, expected, sw, fvg);
   }
   return null_trade;
}

TradeInfo BuildTrade(int idx, string direction, SweepInfo sweep, FvgInfo fvg) {
   TradeInfo t;
   t.entry_time = rates_array[idx].time;
   double spr = SpreadPips(rates_array[idx]);

   if (direction == "bullish") {
      t.entry_price = fvg.bottom + PipsToPrice(spr);
      t.stop_loss = sweep.price - PipsToPrice(StopLossBufferPips);
      double sl_pips = PriceToPips(t.entry_price - t.stop_loss);
      double rr = TargetMinR + (MathRand()/32767.0) * (TargetMaxR - TargetMinR);
      t.take_profit = t.entry_price + sl_pips * rr * 0.0001;
      t.direction = "bullish";
   } else {
      t.entry_price = fvg.top - PipsToPrice(spr);
      t.stop_loss = sweep.price + PipsToPrice(StopLossBufferPips);
      double sl_pips = PriceToPips(t.stop_loss - t.entry_price);
      double rr = TargetMinR + (MathRand()/32767.0) * (TargetMaxR - TargetMinR);
      t.take_profit = t.entry_price - sl_pips * rr * 0.0001;
      t.direction = "bearish";
   }

   t.position_size = CalculatePositionSize(current_balance, PriceToPips(MathAbs(t.entry_price - t.stop_loss)));
   return t;
}

void PrintSummary() {
   int total = ArraySize(trades_array);
   if (total == 0) {
      Print("No trades generated.");
      return;
   }

   int win_count = 0;
   double total_pnl = 0, sum_win = 0, sum_loss = 0;
   int loss_count = 0;
   for (int i = 0; i < total; i++) {
      total_pnl += trades_array[i].pnl_usd;
      if (trades_array[i].pnl_usd > 0) {
         win_count++;
         sum_win += trades_array[i].pnl_usd;
      } else {
         loss_count++;
         sum_loss += trades_array[i].pnl_usd;
      }
   }
   double win_rate = (double)win_count / total * 100;
   double avg_rr = MathAbs(sum_win / win_count / (sum_loss / loss_count)) ;

   double peak = initial_balance;
   double max_dd = 0;
   int eq_size = ArraySize(equity_values);
   for (int i = 0; i < eq_size; i++) {
      if (equity_values[i] > peak) peak = equity_values[i];
      double dd = (peak - equity_values[i]) / peak * 100;
      if (dd > max_dd) max_dd = dd;
   }

   Print("========================================");
   Print("BACKTEST SUMMARY");
   Print("========================================");
   PrintFormat("Total Trades: %d", total);
   PrintFormat("Win Rate: %.1f%%", win_rate);
   PrintFormat("Avg R:R: %.2f", avg_rr);
   PrintFormat("Total P&L: $%.2f", total_pnl);
   PrintFormat("Return: %.1f%%", (current_balance - initial_balance) / initial_balance * 100);
   PrintFormat("Max Drawdown: %.2f%%", max_dd);
   PrintFormat("Ending Balance: $%.2f", current_balance);
   Print("========================================");
}

// No OnTick needed, backtest runs in OnInit
void OnTick() {
}

// Deinit if needed
void OnDeinit(const int reason) {
   // Clean up if necessary
}