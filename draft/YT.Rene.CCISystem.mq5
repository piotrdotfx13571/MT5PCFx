//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

input group "Trade settings"
input double inputLots = 0.1;
input double inputTpPoints = 60;
input int partialClosePoints = 40;
input double partialCloseFactor = 0.8;
input double inputSlPoints = 40;
input int BeTriggerPoints = 30;
input int BePufferPoints = 10;

input group "CCI"
input ENUM_TIMEFRAMES cciTimeframe = PERIOD_CURRENT;
input ENUM_APPLIED_PRICE cciAppPrice = PRICE_TYPICAL;
input int cciPeriods = 14;
input double cciBuyLevel = -220;
input double cciSellLevel = 220;

input group "Moving Average Filter"
bool isMaFilter = true;
input ENUM_TIMEFRAMES maTimeframe = PERIOD_H1;
input int maPeriods = 50;
input ENUM_MA_METHOD inputMaMethod = MODE_SMA;
input ENUM_APPLIED_PRICE maAppPrice = PRICE_CLOSE;

int handleCii;
int handleMa;
int barsTotal;

CTrade trade;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   barsTotal = iBars(_Symbol, cciTimeframe);

   handleCii = iCCI(_Symbol, cciTimeframe, cciPeriods, cciAppPrice);
   handleMa = iMA(_Symbol, maTimeframe, maPeriods, 0, inputMaMethod, maAppPrice);


   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("Deinit");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {


   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   ask = NormalizeDouble(ask, _Digits);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bid = NormalizeDouble(bid, _Digits);

   //Position 
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket)) {
         double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double posVolume = PositionGetDouble(POSITION_VOLUME);
         double posTp = PositionGetDouble(POSITION_TP);
         double posSl = PositionGetDouble(POSITION_SL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   //break even stop
         if(posType == POSITION_TYPE_BUY) {
            if (bid > posOpenPrice + BeTriggerPoints * _Point) {
               double sl = posOpenPrice + BePufferPoints * _Point;
               sl = NormalizeDouble(sl, _Digits);

               if(sl > posSl) {
                  if(trade.PositionModify(posTicket, sl, posTp)) {
                     Print("!!! Pos ", posTicket, " was saved at break even points");
                  }
               }
            }
         }else if(posType == POSITION_TYPE_SELL) {
            if (ask> posOpenPrice + BeTriggerPoints * _Point) {
               double sl = posOpenPrice + BePufferPoints * _Point;
               sl = NormalizeDouble(sl, _Digits);

               if(sl > posSl) {
                  if(trade.PositionModify(posTicket, sl, posTp)) {
                     Print("!!! Pos ", posTicket, " was saved at break even points");
                  }
               }
            }
         }

   //partial close
         if(posVolume == inputLots) {
            double lotsToClose = posVolume * partialCloseFactor;
            lotsToClose = NormalizeDouble(lotsToClose, 2);

            if(posType == POSITION_TYPE_BUY) {
               if(bid > posOpenPrice + partialClosePoints * _Point) {
                  if(trade.PositionClosePartial(posTicket, lotsToClose)) {
                     Print("!!! Pos ", posTicket, " has been close partial");
                  }
               }
            } else if(posType == POSITION_TYPE_SELL) {
               if(ask > posOpenPrice + partialClosePoints * _Point) {
                  if(trade.PositionClosePartial(posTicket, lotsToClose)) {
                     Print("!!! Pos ", posTicket, " has been close partial");
                  }
               }
            }
         }
      }
   }

   int bars = iBars(_Symbol, cciTimeframe);

   if(barsTotal < bars) {
      barsTotal = bars;

      double cci[], ma[];
      CopyBuffer(handleCii, 0, 1, 2, cci);
      CopyBuffer(handleMa, 0, 0, 1, ma);

      if(cci[1] < cciBuyLevel && cci[0] > cciBuyLevel) {


         if(isMaFilter && ask > ma[0]) {
            double tp = ask + inputTpPoints * _Point;
            tp = NormalizeDouble(tp, _Digits);

            double sl = ask - inputSlPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);

            trade.Buy(inputLots, _Symbol, ask, sl, tp, "CCI BUY");

         }
      } else if(cci[1] > cciSellLevel && cci[0] < cciSellLevel) {



         if(isMaFilter && bid < ma[0]) {

            double tp = bid - inputTpPoints * _Point;
            tp = NormalizeDouble(tp, _Digits);

            double sl = bid + inputSlPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);

            trade.Sell(inputLots, _Symbol, bid, sl, tp, "CCI SELL");
         }

      }
      Comment("\nCCI[0]: ", cci[0],
              "\nCCI[1]: ", cci[1],
              "\nMA[0]: ", ma[0]);
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
