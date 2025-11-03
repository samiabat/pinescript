//+------------------------------------------------------------------+
//|                                          ICT_Backtest_Fixed.mq5 |
//|                     Exact Python-to-MQL5 conversion (no stubs)   |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property strict

//--- inputs (same defaults as the Python version)
input double  InitialBalance        = 200.0;
input double  RiskPerTrade          = 0.015;
input int     MaxTradesPerDay       = 40;
input double  MinFvgPips            = 2.0;
input double  SweepRejectionPips    = 0.5;
input double  StopLossBufferPips    = 2.0;
input double  TargetMinR            = 3.0;
input double  TargetMaxR            = 5.0;
input double  BaseSpreadPips        = 0.6;
input double  SlippagePipsBase      = 0.3;
input double  CommissionPerM        = 3.5;
input double  MinBalanceThreshold   = 100.0;
input long    MaxPositionUnits      = 10000000;
input bool    RelaxedMode           = true;

//--- session times (UTC)
datetime LondonOpen  = D'00:00:00' + 7*3600;   // 07:00 UTC
datetime LondonClose = D'00:00:00' + 16*3600;  // 16:00 UTC
datetime NyOpen      = D'00:00:00' + 12*3600;  // 12:00 UTC
datetime NyClose     = D'00:00:00' + 21*3600;  // 21:00 UTC

//--- structures
struct SweepInfo
  {
   string   type;      // "bear_sweep" or "bull_sweep"
   double   price;
   int      idx;
   string   trend;
   int      detected;
  };

struct FvgInfo
  {
   string   type;      // "bullish" or "bearish"
   double   bottom;
   double   top;
   int      idx;
  };

struct TradeInfo
  {
   datetime entry_time;
   double   entry_price;
   string   direction;   // "bullish" / "bearish"
   double   stop_loss;
   double   take_profit;
   long     position_size;
   datetime exit_time;
   double   exit_price;
   string   result;
   double   pnl_pips;
   double   pnl_usd;
  };

//--- globals
MqlRates   rates[];
TradeInfo  trades[];
TradeInfo  active_trade;
double     balance;
double     start_balance;
datetime   equity_dt[];
double     equity_val[];
datetime   cur_day;
int        day_cnt;
SweepInfo  recent_sweeps[];
int        sweeps_cnt;

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
double PipsToPrice(double p)               { return p*0.0001; }
double PriceToPips(double d)               { return d/0.0001; }

bool IsTradingSession(datetime dt)
  {
   MqlDateTime s;
   TimeToStruct(dt,s);
   datetime tod = D'00:00:00'+s.hour*3600+s.min*60+s.sec;
   return (tod>=LondonOpen && tod<=LondonClose) ||
          (tod>=NyOpen     && tod<=NyClose);
  }

string Detect1hTrend(int cur_idx)
  {
   int look=MathMin(32,cur_idx);
   if(look<16) return "neutral";

   double recent_h=0,recent_l=DBL_MAX, older_h=0,older_l=DBL_MAX;
   for(int i=cur_idx-8;i<cur_idx;i++)
     {
      recent_h=MathMax(recent_h,rates[i].high);
      recent_l=MathMin(recent_l,rates[i].low);
     }
   for(int i=cur_idx-look;i<cur_idx-8;i++)
     {
      older_h=MathMax(older_h,rates[i].high);
      older_l=MathMin(older_l,rates[i].low);
     }
   if(recent_h>older_h && recent_l>older_l) return "bullish";
   if(recent_h<older_h && recent_l<older_l) return "bearish";
   return "neutral";
  }

SweepInfo DetectLiquiditySweep(int cur_idx)
  {
   SweepInfo null_sweep; null_sweep.type="";
   if(cur_idx<5) return null_sweep;

   MqlRates cur=rates[cur_idx];
   double max_h=0,min_l=DBL_MAX;
   for(int i=cur_idx-20;i<cur_idx;i++)
     {
      max_h=MathMax(max_h,rates[i].high);
      min_l=MathMin(min_l,rates[i].low);
     }

   if(cur.high>max_h && cur.close<cur.high-PipsToPrice(SweepRejectionPips))
     {
      SweepInfo s; s.type="bear_sweep"; s.price=cur.high; s.idx=cur_idx;
      return s;
     }
   if(cur.low<min_l && cur.close>cur.low+PipsToPrice(SweepRejectionPips))
     {
      SweepInfo s; s.type="bull_sweep"; s.price=cur.low; s.idx=cur_idx;
      return s;
     }
   return null_sweep;
  }

bool DetectMss(int sweep_idx,int cur_idx,string sweep_type)
  {
   if(cur_idx<=sweep_idx) return false;
   double min_l=DBL_MAX, max_h=0;
   for(int i=sweep_idx+1;i<=cur_idx;i++)
     {
      min_l=MathMin(min_l,rates[i].low);
      max_h=MathMax(max_h,rates[i].high);
     }
   if(sweep_type=="bear_sweep") return min_l<rates[sweep_idx].low;
   return max_h>rates[sweep_idx].high;
  }

FvgInfo DetectFvg(int cur_idx)
  {
   FvgInfo null_fvg; null_fvg.type="";
   if(cur_idx<2) return null_fvg;

   MqlRates c1=rates[cur_idx-2];
   MqlRates c3=rates[cur_idx];
   if(c3.low>c1.high && PriceToPips(c3.low-c1.high)>=MinFvgPips)
     {
      FvgInfo f; f.type="bullish"; f.bottom=c1.high; f.top=c3.low; f.idx=cur_idx;
      return f;
     }
   if(c3.high<c1.low && PriceToPips(c1.low-c3.high)>=MinFvgPips)
     {
      FvgInfo f; f.type="bearish"; f.bottom=c3.high; f.top=c1.low; f.idx=cur_idx;
      return f;
     }
   return null_fvg;
  }

double SpreadPips(const MqlRates &c)
  {
   long vol=c.tick_volume;
   if(vol>300) return BaseSpreadPips;
   if(vol>100) return BaseSpreadPips*1.5;
   return BaseSpreadPips*2.5;
  }

double SlippagePips(long units)
  {
   double f=MathMin((double)units/1000000.0,5.0);
   return SlippagePipsBase*(1+f);
  }

double CommissionUsd(long units)
  {
   return CommissionPerM*((double)units/1000000.0);
  }

long CalculatePositionSize(double bal,double sl_pips)
  {
   if(bal<=0 || sl_pips<=0) return 0;
   double risk=bal*RiskPerTrade;
   long size=(long)(risk/(sl_pips*0.0001));
   return MathMin(size,MaxPositionUnits);
  }

bool CheckTradeExit(TradeInfo &t,const MqlRates &c)
  {
   long   pos=t.position_size;
   double spr=SpreadPips(c);
   double slp=SlippagePips(pos);
   double comm=CommissionUsd(pos);

   if(t.direction=="bullish")
     {
      if(c.low<=t.stop_loss)
        {
         t.exit_price = t.stop_loss - PipsToPrice(slp);
         t.exit_time  = c.time;
         t.result     = "SL";
         t.pnl_pips   = -PriceToPips(t.entry_price-t.exit_price);
         t.pnl_usd    = t.pnl_pips*0.0001*pos-comm;
         return true;
        }
      if(c.high>=t.take_profit)
        {
         t.exit_price = t.take_profit - PipsToPrice(slp);
         t.exit_time  = c.time;
         t.result     = "TP";
         t.pnl_pips   = PriceToPips(t.take_profit-t.entry_price);
         t.pnl_usd    = t.pnl_pips*0.0001*pos-comm;
         return true;
        }
     }
   else // bearish
     {
      if(c.high>=t.stop_loss)
        {
         t.exit_price = t.stop_loss + PipsToPrice(slp);
         t.exit_time  = c.time;
         t.result     = "SL";
         t.pnl_pips   = -PriceToPips(t.exit_price-t.entry_price);
         t.pnl_usd    = t.pnl_pips*0.0001*pos-comm;
         return true;
        }
      if(c.low<=t.take_profit)
        {
         t.exit_price = t.take_profit + PipsToPrice(slp);
         t.exit_time  = c.time;
         t.result     = "TP";
         t.pnl_pips   = PriceToPips(t.entry_price-t.take_profit);
         t.pnl_usd    = t.pnl_pips*0.0001*pos-comm;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Entry logic – all confluence required                           |
//+------------------------------------------------------------------+
TradeInfo CheckEntry(int idx)
  {
   TradeInfo null_trade; null_trade.entry_time=0;
   if(idx<50) return null_trade;

   string trend=Detect1hTrend(idx);
   if(trend=="neutral" && !RelaxedMode) return null_trade;

   //--- 1) sweep detection
   SweepInfo sweep=DetectLiquiditySweep(idx);
   if(sweep.type!="")
     {
      sweep.trend   =trend;
      sweep.detected=idx;
      // keep only last 30 candles
      if(sweeps_cnt<ArraySize(recent_sweeps))
        {
         recent_sweeps[sweeps_cnt]=sweep;
         sweeps_cnt++;
        }
     }

   //--- 2) scan recent sweeps
   for(int s=0;s<sweeps_cnt;s++)
     {
      SweepInfo sw=recent_sweeps[s];
      if(idx-sw.detected>30) { recent_sweeps[s]=recent_sweeps[--sweeps_cnt]; s--; continue; }
      if(idx<sw.idx+1) continue;
      if(trend!="neutral" && sw.trend!=trend) continue;
      if(!DetectMss(sw.idx,idx,sw.type)) continue;

      //--- 3) FVG on current bar
      FvgInfo fvg=DetectFvg(idx);
      if(fvg.type=="") continue;

      //--- 4) direction match
      string expected=(sw.type=="bear_sweep")?"bearish":"bullish";
      if(fvg.type!=expected) continue;

      //--- remove used sweep
      recent_sweeps[s]=recent_sweeps[--sweeps_cnt];
      s--;

      return BuildTrade(idx,expected,sw,fvg);
     }
   return null_trade;
  }

TradeInfo BuildTrade(int idx,string direction,const SweepInfo &sw,const FvgInfo &fvg)
  {
   TradeInfo t;
   t.entry_time=rates[idx].time;
   double spr=SpreadPips(rates[idx]);

   if(direction=="bullish")
     {
      t.entry_price = fvg.bottom + PipsToPrice(spr);
      t.stop_loss   = sw.price   - PipsToPrice(StopLossBufferPips);
      double sl_pips=PriceToPips(t.entry_price-t.stop_loss);
      double rr=TargetMinR+(MathRand()/32767.0)*(TargetMaxR-TargetMinR);
      t.take_profit = t.entry_price + sl_pips*rr*0.0001;
      t.direction   = "bullish";
     }
   else
     {
      t.entry_price = fvg.top    - PipsToPrice(spr);
      t.stop_loss   = sw.price   + PipsToPrice(StopLossBufferPips);
      double sl_pips=PriceToPips(t.stop_loss-t.entry_price);
      double rr=TargetMinR+(MathRand()/32767.0)*(TargetMaxR-TargetMinR);
      t.take_profit = t.entry_price - sl_pips*rr*0.0001;
      t.direction   = "bearish";
     }

   t.position_size=CalculatePositionSize(balance,
                     PriceToPips(MathAbs(t.entry_price-t.stop_loss)));
   return t;
  }

//+------------------------------------------------------------------+
//| Summary printing                                                 |
//+------------------------------------------------------------------+
void PrintSummary()
  {
   int total=ArraySize(trades);
   if(total==0){ Print("No trades generated."); return; }

   int win=0; double sum_win=0,sum_loss=0;
   for(int i=0;i<total;i++)
     {
      if(trades[i].pnl_usd>0){ win++; sum_win+=trades[i].pnl_usd; }
      else sum_loss+=trades[i].pnl_usd;
     }
   double win_rate=win*100.0/total;
   double avg_rr = (win>0 && (total-win)>0) ? MathAbs(sum_win/win / (sum_loss/(total-win))) : 0;

   double peak=start_balance, max_dd=0;
   for(int i=0;i<ArraySize(equity_val);i++)
     {
      if(equity_val[i]>peak) peak=equity_val[i];
      double dd=(peak-equity_val[i])/peak*100;
      if(dd>max_dd) max_dd=dd;
     }

   Print("========================================");
   Print("BACKTEST SUMMARY");
   Print("========================================");
   PrintFormat("Total Trades     : %d",total);
   PrintFormat("Win Rate         : %.1f%%",win_rate);
   PrintFormat("Avg R:R          : %.2f",avg_rr);
   PrintFormat("Total P&L        : $%.2f",balance-start_balance);
   PrintFormat("Return           : %.1f%%",(balance/start_balance-1)*100);
   PrintFormat("Max Drawdown     : %.2f%%",max_dd);
   PrintFormat("Ending Balance   : $%.2f",balance);
   Print("========================================");
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- load 15-minute EURUSD data (exact range from Python)
   datetime from = D'2021.10.29 20:15:00';
   datetime to   = D'2025.10.31 20:45:00';
   int copied = CopyRates("EURUSD",PERIOD_M15,from,to,rates);
   if(copied<=0){ Print("CopyRates failed: ",GetLastError()); return INIT_FAILED; }
   PrintFormat("Loaded %d bars",copied);

   //--- allocate arrays
   ArrayResize(trades,0,5000);
   ArrayResize(equity_dt,0,5000);
   ArrayResize(equity_val,0,5000);
   ArrayResize(recent_sweeps,100);
   sweeps_cnt=0;
   ZeroMemory(active_trade);
   balance=start_balance=InitialBalance;
   cur_day=0; day_cnt=0;

   //--- main back-test loop
   int total_bars=ArraySize(rates);
   for(int i=0;i<total_bars;i++)
     {
      if(i%5000==0) PrintFormat("Progress: %.1f%% (%d/%d)",i*100.0/total_bars,i,total_bars);

      // equity snapshot
      if(i%100==0 || i==total_bars-1)
        {
         int sz=ArraySize(equity_dt);
         ArrayResize(equity_dt,sz+1,5000);
         ArrayResize(equity_val,sz+1,5000);
         equity_dt[sz]=rates[i].time;
         equity_val[sz]=balance;
        }

      // close active trade
      if(active_trade.entry_time!=0 && CheckTradeExit(active_trade,rates[i]))
        {
         balance+=active_trade.pnl_usd;
         int sz=ArraySize(trades);
         ArrayResize(trades,sz+1,5000);
         trades[sz]=active_trade;
         PrintFormat("Trade #%d closed: %s | %.1f pips | $%.2f",
                     sz+1,active_trade.result,active_trade.pnl_pips,active_trade.pnl_usd);
         ZeroMemory(active_trade);
         continue;
        }

      // session & balance filters
      if(!IsTradingSession(rates[i].time) || balance<MinBalanceThreshold) continue;

      datetime day = rates[i].time - (rates[i].time%86400);
      if(day!=cur_day){ cur_day=day; day_cnt=0; }
      if(day_cnt>=MaxTradesPerDay) continue;

      // try to open
      TradeInfo nt=CheckEntry(i);
      if(nt.entry_time!=0)
        {
         active_trade=nt;
         day_cnt++;
         PrintFormat("\nTrade #%d opened at %s",ArraySize(trades)+1,TimeToString(nt.entry_time));
         PrintFormat("  %s | Entry: %.5f | SL: %.5f (%.1f p) | TP: %.5f",
                     StringToUpper(nt.direction),nt.entry_price,nt.stop_loss,
                     PriceToPips(MathAbs(nt.entry_price-nt.stop_loss)),nt.take_profit);
        }
     }

   //--- close any remaining trade at last bar
   if(active_trade.entry_time!=0)
     {
      MqlRates last=rates[total_bars-1];
      active_trade.exit_time=last.time;
      active_trade.exit_price=last.close;
      active_trade.result="Timeout";
      active_trade.pnl_pips=PriceToPips(
         (active_trade.direction=="bullish")?
         (active_trade.exit_price-active_trade.entry_price):
         (active_trade.entry_price-active_trade.exit_price));
      active_trade.pnl_usd=active_trade.pnl_pips*0.0001*active_trade.position_size;
      balance+=active_trade.pnl_usd;
      int sz=ArraySize(trades);
      ArrayResize(trades,sz+1,5000);
      trades[sz]=active_trade;
     }

   PrintSummary();
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+