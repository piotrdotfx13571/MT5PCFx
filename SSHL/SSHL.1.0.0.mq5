//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
input group    "Time settings"
input int      timeStartHour = 01;                 //Enter trade time start hour
input int      timeStartMin  = 37;                 //Enter trade time start minute
input int      timeEndHour   = 17;                 //Enter trade time end hour
input int      timeEndMin    = 37;                 //Enter trade time end minute
input bool     closePositionOnEndOfDay = false;    //Close posistion on end of the day
input int      closePositionTimeHour = 19;         //Hour
input int      closePositionTimeMin = 36;          //Min

input group "Trade settings"
input double   RiskPercentage = 1.0;               //Risk percantage of balance
input double   Lots = 0.1;                         //Lots size if Risk=0
input bool     CapitalProtection = false;          //Capital protection mechanism
input int      AccountStartBalance = 25000;        //Account start balance for capital protection mechanism

input int      OrderDistPoints = 250;
input int      TpPoints = 250;
input int      SlPoints = 200;
input int      TslPoints = 25;
input int      TslTriggerPoints = 45;

input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input int      BarsN = 5;
input int      ExpirationHours = 40;

input int      Magic = 1111;


CTrade trade;
ulong buyPos, sellPos;
int totalBars;

bool enterTradeTime = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {

   MqlDateTime structTime;
   TimeCurrent(structTime);
   structTime.sec = 0;

   structTime.hour = timeStartHour;
   structTime.min = timeStartMin;

   datetime startTradingTime = StructToTime(structTime);

   structTime.hour = timeEndHour;
   structTime.min = timeEndMin;
   datetime endTradingTime = StructToTime(structTime);

   datetime currentTime = iTime(NULL, 0, 0);

   // Do not enter trade outside the specified hours
   enterTradeTime = (currentTime < startTradingTime || currentTime > endTradingTime) ? false : true ;

   processPos(buyPos);
   processPos(sellPos);


   int bars = iBars(_Symbol, Timeframe);
   if(totalBars != bars) {
      totalBars = bars;


      if(buyPos <= 0) {
         double high = findHigh();
         if(high > 0) {
            executeBuy(high);
         }
      }
      if(sellPos <= 0 ) {
         double low = findLow();
         if(low > 0 ) {
            executeSell(low);
         }
      }
      Comment("\nHigh: ", findHigh(),
              "\nLow: ", findLow());
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(
   const MqlTradeTransaction&    trans,     // trade transaction structure
   const MqlTradeRequest&        request,   // request structure
   const MqlTradeResult&         result     // response structure
) {

   if(trans.type == TRADE_TRANSACTION_ORDER_ADD) {
      COrderInfo order;
      if(order.Select(trans.order)) {
         if(order.Magic() == Magic) {
            if(order.OrderType() == ORDER_TYPE_BUY_STOP) {
               buyPos = order.Ticket();
            } else if (order.OrderType() == ORDER_TYPE_SELL_STOP) {
               sellPos = order.Ticket();
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void processPos(ulong & posTicket) {
   if(posTicket <= 0) return;
   if(OrderSelect(posTicket)) return;

   CPositionInfo pos;
   if(!pos.SelectByTicket(posTicket)) {
      posTicket = 0;
      return;
   } else {
      if(pos.PositionType() == POSITION_TYPE_BUY) {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         if(bid > pos.PriceOpen() + TslTriggerPoints * _Point) {
            double sl = bid - TslPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);

            if (sl > pos.StopLoss()) {
               trade.PositionModify(pos.Ticket(), sl, pos.TakeProfit());
               Print("### SSHL TrailingStop defined distance for BUY. #", posTicket, " New SL : ", DoubleToString(sl, _Digits));
            }
         }
      } else if (pos.PositionType() == POSITION_TYPE_SELL) {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK) ;

         if(ask < pos.PriceOpen() - TslTriggerPoints * _Point) {
            double sl = ask + TslTriggerPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);
            if(sl < pos.StopLoss() || pos.StopLoss() == 0) {
               trade.PositionModify(pos.Ticket(), sl, pos.TakeProfit());
                Print("### SSHL TrailingStop defined distance for SELL. #", posTicket, " New SL : ", DoubleToString(sl, _Digits));
               
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void executeBuy(double entry) {
   if(enterTradeTime) {
      entry = NormalizeDouble(entry, _Digits);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if (ask > entry - OrderDistPoints * _Point) return;

      double tp = entry + TpPoints * _Point;
      tp = NormalizeDouble(tp, _Digits);

      double sl = entry - SlPoints * _Point;
      sl = NormalizeDouble(sl, _Digits);

      double lots = RiskPercentage > 0 ? calcLots(entry - sl) : Lots;

      datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpirationHours * PeriodSeconds(PERIOD_H1);
      trade.BuyStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, "### SSHL BuyStop" );

      buyPos = trade.ResultOrder();
   }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void executeSell(double entry) {
   if(enterTradeTime) {
      entry = NormalizeDouble(entry, _Digits);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if (ask < entry + OrderDistPoints * _Point) return;

      double tp = entry - TpPoints * _Point;
      tp = NormalizeDouble(tp, _Digits);

      double sl = entry + SlPoints * _Point;
      sl = NormalizeDouble(sl, _Digits);

      double lots = RiskPercentage > 0 ? calcLots(sl - entry) : Lots;

      datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpirationHours * PeriodSeconds(PERIOD_H1);
      trade.SellStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, "### SSHL SellStop" );

      sellPos = trade.ResultOrder();
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double findHigh() {
   double highestHigh = 0;
   for(int i = 0; i < 200; i++) {
      double high = iHigh(_Symbol, Timeframe, i);
      if(i > BarsN && iHighest(_Symbol, Timeframe, MODE_HIGH, BarsN * 2 + 1, i - 5) == i) {
         if (high > highestHigh) {
            return high;
         }
         highestHigh = MathMax(high, highestHigh);
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double findLow() {
   double lowestLow = DBL_MAX;
   for(int i = 0; i < 200; i++) {
      double low = iLow(_Symbol, Timeframe, i);
      if(i > BarsN && iLowest(_Symbol, Timeframe, MODE_LOW, BarsN * 2 + 1, i - 5) == i) {
         if (low > lowestLow) {
            return low;
         }
         lowestLow = MathMin(low, lowestLow);
      }
   }
   return -1;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calcLots(double slDistance) {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if (tickSize == 0 || tickValue == 0 || lotStep == 0) {
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
   }

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double newRiskPercentage = RiskPercentage;
   //Reduce the function's return value by 10% for every 1% of initial capital lost
   if(CapitalProtection && currentBalance < AccountStartBalance) {
      double lossPercentage = (AccountStartBalance - currentBalance) / AccountStartBalance ;
      newRiskPercentage = RiskPercentage - lossPercentage * 10;
   }
   //double lossPercentage = ((AccountStartBalance - currentBalance) / AccountStartBalance * 100);
   //newRiskPercentage = lossPercentage < 2 ? 0.50 : 0.33;
   //if ( lossPercentage > 6) {
   //   Print(__FUNCTION__, "### Margin. 6% lost from challenge lost");
   //   return 0;
   //

   double riskMoney = currentBalance * newRiskPercentage / 100;
   double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;

   if (moneyLotStep == 0) {
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
   }

   double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
   return lots;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
