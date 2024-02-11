//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

input double   lots = 0.01;
input int      lastBars = 16;

#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

int lastBreakout;

CTrade trade;

int OnInit() {

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {


}

void OnTick() {

   double lastHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(NULL, 0, MODE_HIGH, lastBars, 1));
   lastHigh = NormalizeDouble(lastHigh, _Digits);
   double lastLow = iLow(_Symbol, PERIOD_CURRENT, iLowest(NULL, 0, MODE_LOW, lastBars, 1));
   lastLow = NormalizeDouble(lastLow, _Digits);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(lastBreakout <= 0 && bid > lastHigh) {
      Print(__FUNCTION__, " > Buy Signal...");
      lastBreakout = 1;


      double sl = NormalizeDouble(lastLow, _Digits);

      trade.Buy(lots, _Symbol, 0, sl);

   } else if(lastBreakout >= 0 && bid < lastLow) {
      Print(__FUNCTION__, " > Sell Signal...");
      lastBreakout = -1;

      double sl = NormalizeDouble(lastHigh, _Digits);

      trade.Sell(lots, _Symbol, 0, sl);
   }

   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong posTicket = PositionGetTicket(i);
      CPositionInfo pos;
      if(pos.PositionType() == POSITION_TYPE_BUY) {
         if( lastLow > pos.StopLoss()) {
            trade.PositionModify(pos.Ticket(), lastLow, pos.TakeProfit());
         }
      } else if(pos.PositionType() == POSITION_TYPE_SELL) {
         if(lastLow < pos.StopLoss()) {
            trade.PositionModify(pos.Ticket(), lastHigh, pos.TakeProfit());
         }
      }
   }





//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   Comment("\nlastHigh: ", lastHigh,
           "\nlastLow: ", lastLow);

}
//+------------------------------------------------------------------+
