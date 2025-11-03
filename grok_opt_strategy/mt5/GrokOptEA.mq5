//+------------------------------------------------------------------+
//|                                                   GrokOptEA.mq5 |
//|                                  Grok Optimized Trading Strategy |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Grok Optimized Strategy"
#property link      ""
#property version   "1.00"
#property description "Expert Advisor implementation of the Grok Optimized trading strategy"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Trading Parameters ==="
input double   RiskPercent = 2.0;           // Risk per trade (%)
input int      StopLossPips = 50;           // Stop Loss in pips
input int      TakeProfitPips = 100;        // Take Profit in pips
input double   LotSize = 0.01;              // Fixed lot size (0 = auto)

input group "=== Strategy Parameters ==="
input int      FastMA = 10;                 // Fast Moving Average period
input int      SlowMA = 20;                 // Slow Moving Average period
input int      RSI_Period = 14;             // RSI period
input double   RSI_Oversold = 30;           // RSI oversold level
input double   RSI_Overbought = 70;         // RSI overbought level

input group "=== Trading Hours ==="
input int      StartHour = 0;               // Trading start hour
input int      EndHour = 23;                // Trading end hour
input bool     TradeMonday = true;          // Trade on Monday
input bool     TradeTuesday = true;         // Trade on Tuesday
input bool     TradeWednesday = true;       // Trade on Wednesday
input bool     TradeThursday = true;        // Trade on Thursday
input bool     TradeFriday = true;          // Trade on Friday

input group "=== Risk Management ==="
input double   MaxDailyLoss = 100.0;        // Maximum daily loss ($)
input double   MaxDailyProfit = 200.0;      // Maximum daily profit ($)
input int      MaxOpenTrades = 1;           // Maximum open trades

input group "=== General Settings ==="
input int      MagicNumber = 123456;        // Magic number for this EA
input string   TradeComment = "GrokOpt";    // Trade comment
input bool     EnableLogging = true;        // Enable detailed logging

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
double dailyProfit = 0.0;
double dailyLoss = 0.0;
int lastDay = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Grok Optimized EA initialized");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   Print("Risk per trade: ", RiskPercent, "%");
   Print("Stop Loss: ", StopLossPips, " pips");
   Print("Take Profit: ", TakeProfitPips, " pips");
   
   // Validate inputs
   if(RiskPercent <= 0 || RiskPercent > 10)
   {
      Print("Error: Invalid risk percentage. Must be between 0 and 10");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(StopLossPips <= 0 || TakeProfitPips <= 0)
   {
      Print("Error: Stop loss and take profit must be positive");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Grok Optimized EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Reset daily counters
   ResetDailyCounters();
   
   // Check if trading is allowed
   if(!IsTradingAllowed())
      return;
   
   // Check daily limits
   if(dailyLoss >= MaxDailyLoss)
   {
      if(EnableLogging)
         Print("Daily loss limit reached: $", dailyLoss);
      return;
   }
   
   if(dailyProfit >= MaxDailyProfit)
   {
      if(EnableLogging)
         Print("Daily profit target reached: $", dailyProfit);
      return;
   }
   
   // Check maximum open trades
   if(CountOpenTrades() >= MaxOpenTrades)
      return;
   
   // Get trading signals
   int signal = GetTradingSignal();
   
   // Execute trades based on signal
   if(signal == 1) // Buy signal
   {
      OpenBuyTrade();
   }
   else if(signal == -1) // Sell signal
   {
      OpenSellTrade();
   }
   
   // Manage open positions
   ManageOpenTrades();
}

//+------------------------------------------------------------------+
//| Get Trading Signal                                               |
//+------------------------------------------------------------------+
int GetTradingSignal()
{
   // TODO: Implement your actual strategy logic from grok_opt.py
   // This is a placeholder implementation using simple MA crossover
   
   double fastMA[];
   double slowMA[];
   double rsi[];
   
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   ArraySetAsSeries(rsi, true);
   
   // Get Moving Averages
   int fastHandle = iMA(_Symbol, _Period, FastMA, 0, MODE_SMA, PRICE_CLOSE);
   int slowHandle = iMA(_Symbol, _Period, SlowMA, 0, MODE_SMA, PRICE_CLOSE);
   int rsiHandle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
   
   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return 0;
   }
   
   if(CopyBuffer(fastHandle, 0, 0, 3, fastMA) < 3 ||
      CopyBuffer(slowHandle, 0, 0, 3, slowMA) < 3 ||
      CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3)
   {
      Print("Error copying indicator buffers");
      return 0;
   }
   
   // Buy signal: Fast MA crosses above Slow MA and RSI is not overbought
   if(fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2] && rsi[1] < RSI_Overbought)
   {
      return 1;
   }
   
   // Sell signal: Fast MA crosses below Slow MA and RSI is not oversold
   if(fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2] && rsi[1] > RSI_Oversold)
   {
      return -1;
   }
   
   return 0; // No signal
}

//+------------------------------------------------------------------+
//| Open Buy Trade                                                   |
//+------------------------------------------------------------------+
void OpenBuyTrade()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = price - StopLossPips * _Point * 10;
   double tp = price + TakeProfitPips * _Point * 10;
   double lots = CalculateLotSize(StopLossPips);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lots;
   request.type = ORDER_TYPE_BUY;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   
   if(OrderSend(request, result))
   {
      if(EnableLogging)
         Print("Buy order opened: ", result.order, " at ", price);
   }
   else
   {
      Print("Error opening buy order: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Open Sell Trade                                                  |
//+------------------------------------------------------------------+
void OpenSellTrade()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = price + StopLossPips * _Point * 10;
   double tp = price - TakeProfitPips * _Point * 10;
   double lots = CalculateLotSize(StopLossPips);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lots;
   request.type = ORDER_TYPE_SELL;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   
   if(OrderSend(request, result))
   {
      if(EnableLogging)
         Print("Sell order opened: ", result.order, " at ", price);
   }
   else
   {
      Print("Error opening sell order: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on risk                                |
//+------------------------------------------------------------------+
double CalculateLotSize(int stopLossPips)
{
   if(LotSize > 0)
      return LotSize;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double lotSize = riskAmount / (stopLossPips * 10 * tickValue / tickSize);
   
   // Round to valid lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Count Open Trades                                                |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Manage Open Trades                                               |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   // TODO: Implement trailing stop, partial close, or other management logic
   // This can be customized based on your strategy needs
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   // Check trading hours
   if(time.hour < StartHour || time.hour > EndHour)
      return false;
   
   // Check trading days
   switch(time.day_of_week)
   {
      case 1: if(!TradeMonday) return false; break;
      case 2: if(!TradeTuesday) return false; break;
      case 3: if(!TradeWednesday) return false; break;
      case 4: if(!TradeThursday) return false; break;
      case 5: if(!TradeFriday) return false; break;
      default: return false; // Weekend
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Reset Daily Counters                                             |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   if(time.day != lastDay)
   {
      lastDay = time.day;
      dailyProfit = 0.0;
      dailyLoss = 0.0;
      
      if(EnableLogging)
         Print("Daily counters reset for new trading day");
   }
   
   // Calculate current daily P&L
   CalculateDailyPnL();
}

//+------------------------------------------------------------------+
//| Calculate Daily P&L                                              |
//+------------------------------------------------------------------+
void CalculateDailyPnL()
{
   double profit = 0.0;
   double loss = 0.0;
   
   MqlDateTime today;
   TimeToStruct(TimeCurrent(), today);
   
   // Check history
   HistorySelect(StringToTime(IntegerToString(today.year) + "." + 
                              IntegerToString(today.mon) + "." + 
                              IntegerToString(today.day)), TimeCurrent());
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber)
         {
            double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(dealProfit > 0)
               profit += dealProfit;
            else
               loss += MathAbs(dealProfit);
         }
      }
   }
   
   dailyProfit = profit;
   dailyLoss = loss;
}
//+------------------------------------------------------------------+
