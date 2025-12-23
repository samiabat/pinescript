//+------------------------------------------------------------------+
//|                                           Gold_Scalper_EA.mq5    |
//|                                  Gold Momentum Scalping Strategy |
//|                                       Educational Implementation |
//+------------------------------------------------------------------+
#property copyright "Educational Project"
#property link      ""
#property version   "1.00"
#property description "Gold scalping strategy with realistic cost modeling"
#property description "WARNING: This strategy loses money in backtesting"
#property description "For educational purposes only - demonstrates realistic trading"

//+------------------------------------------------------------------+
//| Includes                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- Risk Management
input double   InpRiskPercent = 1.0;          // Risk per trade (%)
input int      InpMaxTradesPerDay = 4;        // Max trades per day
input double   InpMaxDailyLoss = 3.0;         // Max daily loss (%)

//--- Trading Hours (Server Time)
input int      InpTradingStartHour = 8;       // Trading start hour
input int      InpTradingEndHour = 19;        // Trading end hour

//--- Entry Parameters
input int      InpMomentumCandles = 2;        // Momentum candles needed
input double   InpMinCandleBody = 0.80;       // Min candle body ($)
input bool     InpRequireStrongCandle = true; // Require strong candle

//--- Exit Parameters
input double   InpProfitTarget = 10.0;        // Profit target ($)
input double   InpStopLoss = 7.0;             // Stop loss ($)

//--- Indicator Parameters
input int      InpSMAPeriod = 20;             // SMA period

//--- Position Sizing
input double   InpMaxLots = 8.0;              // Maximum lot size

//--- Magic Number
input int      InpMagicNumber = 234567;       // Magic number

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
int            smaHandle;
double         smaBuffer[];
datetime       lastBarTime = 0;
int            tradestoday = 0;
double         dailyPnL = 0.0;
datetime       currentDay = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set magic number
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   //--- Create SMA indicator
   smaHandle = iMA(_Symbol, PERIOD_CURRENT, InpSMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(smaHandle == INVALID_HANDLE)
   {
      Print("Error creating SMA indicator");
      return(INIT_FAILED);
   }
   
   //--- Set array as series
   ArraySetAsSeries(smaBuffer, true);
   
   //--- Print initialization info
   Print("======================================================");
   Print("Gold Scalper EA Initialized");
   Print("Symbol: ", _Symbol);
   Print("Risk per trade: ", InpRiskPercent, "%");
   Print("Profit Target: $", InpProfitTarget);
   Print("Stop Loss: $", InpStopLoss);
   Print("WARNING: This strategy historically loses money");
   Print("For educational/testing purposes only!");
   Print("======================================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handle
   if(smaHandle != INVALID_HANDLE)
      IndicatorRelease(smaHandle);
      
   Print("EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;
   
   //--- Reset daily counters if new day
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   datetime todayDate = StringToTime(IntegerToString(timeStruct.year) + "." + 
                                     IntegerToString(timeStruct.mon) + "." + 
                                     IntegerToString(timeStruct.day));
   
   if(currentDay != todayDate)
   {
      currentDay = todayDate;
      tradestoday = 0;
      dailyPnL = CalculateDailyPnL();
      
      Print("New trading day. Daily P&L: $", NormalizeDouble(dailyPnL, 2));
   }
   
   //--- Update daily P&L
   dailyPnL = CalculateDailyPnL();
   
   //--- Check if we have an open position
   if(PositionSelect(_Symbol))
   {
      //--- Manage existing position
      ManagePosition();
      return;
   }
   
   //--- Check trading conditions
   if(!IsTradingTime())
      return;
      
   //--- Check daily limits
   if(tradestoday >= InpMaxTradesPerDay)
   {
      Comment("Max trades for today reached (", tradestoday, "/", InpMaxTradesPerDay, ")");
      return;
   }
   
   //--- Check daily loss limit
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxDailyLossAmount = accountBalance * (InpMaxDailyLoss / 100.0);
   
   if(dailyPnL < -maxDailyLossAmount)
   {
      Comment("Daily loss limit reached. P&L: $", NormalizeDouble(dailyPnL, 2));
      return;
   }
   
   //--- Copy SMA values
   if(CopyBuffer(smaHandle, 0, 0, 3, smaBuffer) < 3)
      return;
   
   //--- Check for entry signal
   string signal = CheckEntrySignal();
   
   if(signal == "LONG")
   {
      OpenPosition(ORDER_TYPE_BUY);
   }
   else if(signal == "SHORT")
   {
      OpenPosition(ORDER_TYPE_SELL);
   }
   
   //--- Update comment
   UpdateComment();
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                     |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   int currentHour = timeStruct.hour;
   
   return (currentHour >= InpTradingStartHour && currentHour < InpTradingEndHour);
}

//+------------------------------------------------------------------+
//| Check for entry signal                                            |
//+------------------------------------------------------------------+
string CheckEntrySignal()
{
   //--- Get current and previous candles
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, InpMomentumCandles + 1, rates);
   if(copied < InpMomentumCandles + 1)
      return "NONE";
   
   //--- Get current candle info
   double currentOpen = rates[0].open;
   double currentClose = rates[0].close;
   double currentHigh = rates[0].high;
   double currentLow = rates[0].low;
   
   double candleBody = MathAbs(currentClose - currentOpen);
   double candleRange = currentHigh - currentLow;
   
   bool isBullish = currentClose > currentOpen;
   bool isBearish = currentClose < currentOpen;
   
   //--- Check minimum candle body
   if(candleBody < InpMinCandleBody)
      return "NONE";
   
   //--- Check candle strength if required
   if(InpRequireStrongCandle && candleRange > 0)
   {
      double bodyRatio = candleBody / candleRange;
      if(bodyRatio < 0.6)
         return "NONE";
   }
   
   //--- Count momentum candles
   int bullishCount = 0;
   int bearishCount = 0;
   
   for(int i = 0; i <= InpMomentumCandles; i++)
   {
      if(rates[i].close > rates[i].open)
         bullishCount++;
      if(rates[i].close < rates[i].open)
         bearishCount++;
   }
   
   //--- Check trend filter (SMA)
   double currentSMA = smaBuffer[0];
   
   //--- Bullish signal
   if(bullishCount >= InpMomentumCandles && 
      currentClose > currentSMA &&
      isBullish)
   {
      return "LONG";
   }
   
   //--- Bearish signal
   if(bearishCount >= InpMomentumCandles && 
      currentClose < currentSMA &&
      isBearish)
   {
      return "SHORT";
   }
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossDollars)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   
   //--- For gold: $1 move = $100 per lot
   //--- Position size = Risk Amount / (Stop Loss in $ * 100)
   double positionLots = riskAmount / (stopLossDollars * 100.0);
   
   //--- Apply limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(InpMaxLots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   //--- Normalize to lot step
   positionLots = MathFloor(positionLots / lotStep) * lotStep;
   
   //--- Ensure within limits
   positionLots = MathMax(minLot, MathMin(maxLot, positionLots));
   
   return positionLots;
}

//+------------------------------------------------------------------+
//| Open a position                                                   |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double lotSize = CalculatePositionSize(InpStopLoss);
   
   if(lotSize < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("Calculated lot size too small: ", lotSize);
      return;
   }
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl, tp;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - InpStopLoss;
      tp = price + InpProfitTarget;
   }
   else
   {
      sl = price + InpStopLoss;
      tp = price - InpProfitTarget;
   }
   
   //--- Send order
   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
      result = trade.Buy(lotSize, _Symbol, price, sl, tp, "Gold Scalper");
   else
      result = trade.Sell(lotSize, _Symbol, price, sl, tp, "Gold Scalper");
   
   if(result)
   {
      tradestoday++;
      Print("Position opened: ", EnumToString(orderType), 
            " | Lots: ", lotSize, 
            " | Price: ", price,
            " | SL: ", sl,
            " | TP: ", tp);
   }
   else
   {
      Print("Failed to open position. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Manage existing position                                          |
//+------------------------------------------------------------------+
void ManagePosition()
{
   //--- Position is managed by SL/TP
   //--- Could add trailing stop or other management here
}

//+------------------------------------------------------------------+
//| Calculate daily P&L                                               |
//+------------------------------------------------------------------+
double CalculateDailyPnL()
{
   double pnl = 0.0;
   
   //--- Get history for today
   datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);
   datetime todayEnd = TimeCurrent();
   
   HistorySelect(todayStart, todayEnd);
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
         {
            pnl += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            pnl += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            pnl += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         }
      }
   }
   
   return pnl;
}

//+------------------------------------------------------------------+
//| Update chart comment                                              |
//+------------------------------------------------------------------+
void UpdateComment()
{
   string comment = "\n";
   comment += "======================================\n";
   comment += "    GOLD SCALPER EA\n";
   comment += "======================================\n";
   comment += "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   comment += "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   comment += "Daily P&L: $" + DoubleToString(dailyPnL, 2) + "\n";
   comment += "Trades Today: " + IntegerToString(tradestoday) + "/" + IntegerToString(InpMaxTradesPerDay) + "\n";
   comment += "--------------------------------------\n";
   
   if(PositionSelect(_Symbol))
   {
      comment += "POSITION OPEN\n";
      comment += "Type: " + EnumToString((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)) + "\n";
      comment += "Lots: " + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) + "\n";
      comment += "Entry: " + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 2) + "\n";
      comment += "Profit: $" + DoubleToString(PositionGetDouble(POSITION_PROFIT), 2) + "\n";
   }
   else
   {
      comment += "No open position\n";
      if(!IsTradingTime())
         comment += "Outside trading hours\n";
      if(tradestoday >= InpMaxTradesPerDay)
         comment += "Max trades reached\n";
   }
   
   comment += "--------------------------------------\n";
   comment += "⚠️ WARNING: Educational EA\n";
   comment += "This strategy loses money\n";
   comment += "in backtesting!\n";
   comment += "======================================\n";
   
   Comment(comment);
}

//+------------------------------------------------------------------+
