//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

input double lots = 0.01;
input double lotsFactor = 2;
input int tpPoints = 100;
input int slPoints = 100;
input int magicNumber = 1111;

CTrade trade;
bool isTradeAllowed = true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(magicNumber);

   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) {

}
void OnTick() {

   if(isTradeAllowed) {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double tp = ask + tpPoints * _Point;
      double sl = ask - slPoints * _Point;

      ask = NormalizeDouble(ask, _Digits);
      tp = NormalizeDouble(tp, _Digits);
      sl = NormalizeDouble(sl, _Digits);

      if (trade.Buy(lots, _Symbol, ask, sl, tp)) {
         isTradeAllowed = false;
      }
   }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  OnTradeTransaction(
   const MqlTradeTransaction&    trans,     // trade transaction structure
   const MqlTradeRequest&        request,   // request structure
   const MqlTradeResult&         result     // response structure
) {

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      CDealInfo deal;
      deal.Ticket(trans.deal);
      HistorySelect(TimeCurrent() - PeriodSeconds(PERIOD_D1), TimeCurrent() + 10);
      if (deal.Magic() == magicNumber && deal.Symbol() == _Symbol) {
         if(deal.Entry() == DEAL_ENTRY_OUT) {
            Print(__FUNCTION__, " > Closed pos #", trans.position );
            if(deal.Profit() > 0 ) {
               isTradeAllowed = true;
            } else {
               if(deal.Type() == DEAL_TYPE_BUY) {
                  double lots = deal.Volume() * lotsFactor;
                  lots = NormalizeDouble(lots, 2);

                  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double tp = ask + tpPoints * _Point;
                  double sl = ask - slPoints * _Point;

                  ask = NormalizeDouble(ask, _Digits);
                  tp = NormalizeDouble(tp, _Digits);
                  sl = NormalizeDouble(sl, _Digits);

                  trade.Buy(lots, _Symbol, ask, sl, tp );

               } else if (deal.DealType() == DEAL_TYPE_SELL) {
                  double lots = deal.Volume() * lotsFactor;
                  lots = NormalizeDouble(lots, 2);

                  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double tp = bid - tpPoints * _Point;
                  double sl = bid + slPoints * _Point;

                  bid = NormalizeDouble(bid, _Digits);
                  tp = NormalizeDouble(tp, _Digits);
                  sl = NormalizeDouble(sl, _Digits);

                  trade.Sell(lots, _Symbol, bid, sl, tp );

               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
