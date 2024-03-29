//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

int handleHeikenAshi;
int handleAtr;

int barsTotal;
ulong posTicket;

input group "Time settings"
input int   timeStartHour = 06;
input int   timeStartMin  = 37;
input int   timeEndHour   = 21;
input int   timeEndMin    = 27;
input bool  closePositionOnEndOfDay = true;       //Close posistion on end of the day
input int   closePositionTimeHour = 21;
input int   closePositionTimeMin = 26;



input group "Trade settings"
input double   riskPercentage = 1;                 //Risk percantage of balance
input double   slAdditionalPoints = 12;            //Stop Loss addidtional points
input double   slMaximumAtrRatio = 1;              //Stop loss maximum ATR ratio to enter trade
input bool     capitalProtection = true;           //Capital protection mechanism
input int      accountStartBalance = 25000;        //Account start balance for capital protection mechanism

input group "Early close settings"
input bool     partialClose = true;               //Partial close. If false only TP4
input double   takeProfit1 = 2;                  //Take profit 1 ratio to Stop Loss
input double   takeProfit2 = 3;                  //Take profit 2 ratio to Stop Loss
input double   takeProfit3 = 5;                  //Take profit 3 ratio to Stop Loss
input double   takeProfit4 = 8;                    //Take profit 4 ratio to Stop Loss/Main tp
input bool     breakEven   = false;                //Break even switch
input double   beAdditionalPoints = 20;            //Brake even additional points to cover commisions

input group "Trailing"
input bool     aggresiveTrailing = false ;         //Aggresive trailing at last high(buy) or low(sell)
input group "Trailing stop settings"               //Trailing stop for TP3 & TP4
input bool     trailingStopAtr = true;             //Trailing stop ATR
input double   trailingStopAtrRatio = 1.0;         //Trailing stop ATR distance ratio
input bool     trailingStopDistance = false;       //Trailing stop to lastLow in points
input double   trailingStopPoints = 35;            //Trailing distance to ask/bid

input group "Signal settings"
input int      cbBars = 6;                        //Check number of candles in HA trend
input int      lastBars = 10;                      // last bars for high/low check

double         lastLow = 0.0;
double         lastHigh = 0.0;

ulong          buyTicket = 0;
ulong          sellTicket = 0;

CTrade trade;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   barsTotal = iBars(_Symbol, PERIOD_CURRENT);

   handleHeikenAshi = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\Heiken_Ashi.ex5");
   handleAtr = iATR(_Symbol, PERIOD_CURRENT, 14);

   lastLow = FindLastLow(lastBars);
   lastHigh = FindLastHigh(lastBars);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
// Check if it's time to trade

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

   if(currentTime < startTradingTime || currentTime > endTradingTime) {
      return; // Do not trade outside the specified hours
   }
   double atrValue[];
   CopyBuffer(handleAtr, 0, 1, cbBars, atrValue);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   ask = NormalizeDouble(ask, _Digits);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bid = NormalizeDouble(bid, _Digits);

//Position
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket)) {

         //Close all position on end of the day
         if (closePositionOnEndOfDay) {
            structTime.hour = closePositionTimeHour;
            structTime.min = closePositionTimeHour;
            datetime closePositionTime = StructToTime(structTime);

            if(currentTime >= closePositionTime) {
               if (trade.PositionClose(posTicket, 1)) {
                  Print("### End of the day. Close position #", posTicket);
               }
            }
         }
         double posProfit = PositionGetDouble(POSITION_PROFIT);
         double posEntry = PositionGetDouble(POSITION_PRICE_OPEN);
         double posVolume = PositionGetDouble(POSITION_VOLUME);
         double posTp = PositionGetDouble(POSITION_TP);
         double posSl = PositionGetDouble(POSITION_SL);

         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         double preLots = calcLots(riskPercentage, MathAbs(posEntry - posSl)); //! If was no sl change
         double lotsToClose = NormalizeDouble((preLots * 0.25), 2);

         double buyTp1 = posEntry + takeProfit1 * MathAbs(posEntry - posSl);
         double buyTp2 = posEntry + takeProfit2 * MathAbs(posEntry - posSl);
         double buyTp3 = posEntry + takeProfit3 * MathAbs(posEntry - posSl);

         double sellTp1 = posEntry - takeProfit1 * MathAbs(posEntry - posSl);
         double sellTp2 = posEntry - takeProfit2 * MathAbs(posEntry - posSl);
         double sellTp3 = posEntry - takeProfit3 * MathAbs(posEntry - posSl);


         //partial close
         if(partialClose) {
            if(posProfit > calcTakeProfit(takeProfit1) * 4 && lotsToClose * 4 == posVolume) {
               
               if(trade.PositionClosePartial(posTicket, lotsToClose)) {
                  Print("### TP1 for #", posTicket, " has been partial closed on TP1");
               } else if(posProfit > calcTakeProfit(takeProfit2) * 3 && lotsToClose * 3== posVolume) {
                  
                  
                  if(trade.PositionClosePartial(posTicket, lotsToClose)) {
                     Print("### TP2 for  #", posTicket, " has been partial closed on TP2");
                  } else if(posProfit > calcTakeProfit(takeProfit3)* 2 && lotsToClose * 2 == posVolume) {
                     
                     if(trade.PositionClosePartial(posTicket, lotsToClose)) {
                        Print("### TP3 for #", posTicket, " has been partial closed on TP3");
                     }
                  }
               }
            }
         }



         //partial close
         //if(partialClose) {
         //   if(posType == POSITION_TYPE_BUY && posSl < posEntry) {
         //      if(bid > buyTp3) {
         //         if(trade.PositionClosePartial(posTicket, NormalizeDouble((posVolume * 0.5), 2))) {
         //            Print("### TP3 for BUY #", posTicket, " has been partial closed on TP3: ", buyTp3);
         //         }
         //      } else if (bid > buyTp2 && posVolume / preLots == 0.75) {
         //         if(trade.PositionClosePartial(posTicket, lotsToClose)) {
         //            Print("### TP2 for BUY #", posTicket, " has been partial closed on TP2: ", buyTp2);
         //         }
         //      } else if (bid > buyTp1 && posVolume == preLots) {
         //         if(trade.PositionClosePartial(posTicket, lotsToClose)) {
         //            Print("### TP1 for BUY #", posTicket, " has been partial closed on TP1: ", buyTp1);
         //         }
         //      }
         //   } else if(posType == POSITION_TYPE_SELL && posSl > posEntry) {
         //      if(ask < sellTp3) {
         //         if(trade.PositionClosePartial(posTicket, NormalizeDouble((posVolume * 0.5), 2))) {
         //            Print("### TP3 for SELL #", posTicket, " has been partial closed on TP3: ", sellTp3);
         //         }
         //      } else if (ask < sellTp2 && posVolume / preLots == 0.75) {
         //         if(trade.PositionClosePartial(posTicket, lotsToClose)) {
         //            Print("### TP2 for SELL #", posTicket, " has been partial closed on TP2: ", sellTp2);
         //         }
         //      } else if (ask < sellTp1 && posVolume == preLots) {
         //         if(trade.PositionClosePartial(posTicket, lotsToClose)) {
         //            Print("### TP1 for SELL #", posTicket, " has been partial closed on TP1: ", sellTp1);
         //         }
         //      }
         //   }
         //}

         //break even stop change at TP2 price level
         if(breakEven) {
            if(posType == POSITION_TYPE_BUY) {
               if (bid > buyTp2) {
                  double newSl = posEntry + beAdditionalPoints * _Point;
                  newSl = NormalizeDouble(newSl, _Digits);

                  if(newSl > posSl) {
                     if(trade.PositionModify(posTicket, newSl, posTp)) {
                        Print("### Break Even for BUY. #", posTicket, " bid on TP2 point. Save on Be: ", DoubleToString(newSl, _Digits));
                     }
                  }
               }
            } else if(posType == POSITION_TYPE_SELL) {
               if (ask <  sellTp2) {
                  double newSl = posEntry + beAdditionalPoints * _Point;
                  newSl = NormalizeDouble(newSl, _Digits);

                  if(newSl < posSl) {
                     if(trade.PositionModify(posTicket, newSl, posTp)) {
                        Print("### Break Even for SELL. #", posTicket, " ask on TP2 point. Save on Be: : ", DoubleToString(newSl, _Digits));
                     }
                  }
               }
            }
         }

         //trailingStopAtr change at TP2 price level
         double newSl;
         double level;
         if(trailingStopAtr) {
            if(posType == POSITION_TYPE_BUY && bid > buyTp2) {
               if(level = aggresiveTrailing ? lastHigh : lastLow ) {
                  newSl = MathMax(level - atrValue[cbBars - 1] * trailingStopAtrRatio, posSl);
                  newSl = NormalizeDouble(newSl, _Digits);
               }
               if(newSl > posSl) {
                  if(trade.PositionModify(posTicket, newSl, posTp)) {
                     Print("### TrailingStop ATR for BUY. #", posTicket, " New SL : ", DoubleToString(newSl, _Digits));
                  }

               } else if(posType == POSITION_TYPE_SELL && ask <  sellTp2) {
                  if(level = aggresiveTrailing ? lastLow : lastHigh) {
                     newSl = MathMin(level + atrValue[cbBars - 1] * trailingStopAtrRatio, posSl);
                     newSl = NormalizeDouble(newSl, _Digits);
                  }
                  if(newSl < posSl) {
                     if(trade.PositionModify(posTicket, newSl, posTp)) {
                        Print("### TrailingStop ATR for SELL. #", posTicket, " New SL : ", DoubleToString(newSl, _Digits));
                     }
                  }

               }
            }
         }
         //trailingStopDistance change at TP2 price level
         if(trailingStopDistance) {
            if(posType == POSITION_TYPE_BUY && bid > buyTp2) {
               if(level = aggresiveTrailing ? lastHigh : lastLow ) {
                  newSl = MathMax(lastLow - trailingStopPoints * Point(), posSl);
                  if(newSl > posSl) {
                     if(trade.PositionModify(posTicket, newSl, posTp)) {
                        Print("### TrailingStop defined distance for BUY. #", posTicket, " New SL : ", DoubleToString(newSl, _Digits));
                     }
                  }
               }
            } else if(posType == POSITION_TYPE_SELL && ask <  sellTp2) {
               if(level = aggresiveTrailing ? lastLow : lastHigh) {
                  newSl = MathMin(lastLow + trailingStopPoints * Point(), posSl);

                  if(newSl != posSl) {
                     if(trade.PositionModify(posTicket, newSl, posTp)) {
                        Print("### TrailingStop defined distance for SELL. #", posTicket, " New SL : ", DoubleToString(newSl, _Digits));
                     }
                  }
               }
            }
         }
      }
   }


//Ticket clearing
   sellTicket = 0;
   buyTicket = 0;
   if(PositionsTotal() != 0) {
      for (int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong posTicket = PositionGetTicket(i);
         if(PositionSelectByTicket(posTicket)) {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(posType == POSITION_TYPE_BUY) {
               buyTicket++;
            } else if (posType == POSITION_TYPE_SELL) {
               sellTicket++;
            }
         }
      }
   }



// HeikenAshi part & Buy and Sell
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   if(barsTotal != bars) {
      barsTotal = bars;

      double haOpen [], haClose[], haLow[], haHigh[];
      CopyBuffer(handleHeikenAshi, 0, 1, cbBars, haOpen);
      CopyBuffer(handleHeikenAshi, 1, 1, cbBars, haHigh);
      CopyBuffer(handleHeikenAshi, 2, 1, cbBars, haLow);
      CopyBuffer(handleHeikenAshi, 3, 1, cbBars, haClose);




      lastLow = FindLastLow(lastBars);
      lastHigh = FindLastHigh(lastBars);

      Comment("\nHA Open: ", DoubleToString(haOpen[cbBars - 1], _Digits),
              "\nHA Close: ", DoubleToString(haClose[cbBars - 1], _Digits),
              "\nHA Low: ", DoubleToString(haLow[cbBars - 1], _Digits),
              "\nHA High: ", DoubleToString(haHigh[cbBars - 1], _Digits),
              "\nBuy lastLow: ", lastLow,
              "\nBuy lastHigh: ", lastHigh,
              "\nBuy Ticket: ", buyTicket,
              "\nSell Ticket: ", sellTicket);

      //Check number of signal candles
      int noWickBullCandlesInRow = 0;
      for (int i = cbBars - 1; i > 0; i--) {
         if (haOpen[i] < haClose[i]) {
            if(haLow[i] == haOpen[i]) {
               noWickBullCandlesInRow++;
            }
         } else {
            break;
         }
      }

      // BUY
      if(noWickBullCandlesInRow == 1) {
         if(buyTicket <= 0) {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            entry = NormalizeDouble(entry, _Digits);

            double sl = lastLow - slAdditionalPoints * _Point;
            if(entry - sl < atrValue[cbBars - 1] * slMaximumAtrRatio) {
               double tp = entry + takeProfit4 * MathAbs(entry - sl);
               double lots = calcLots(riskPercentage, entry - sl);
               Print("### Opening Buy Position");
               if(trade.Buy(lots, _Symbol, entry, sl, tp, "# HANWC Buy" )) {
                  buyTicket = trade.ResultOrder();
               }
            }
         }
      }

      //Check number of signal candles
      int noWickBearCandlesInRow = 0;
      for (int i = cbBars - 1; i > 0; i--) {
         if (haOpen[i] > haClose[i]) {
            if(haHigh[i] == haOpen[i]) {
               noWickBearCandlesInRow++;
            }
         } else {
            break;
         }
      }

      // SELL
      if(noWickBearCandlesInRow == 1) {
         if(sellTicket <= 0) {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            entry = NormalizeDouble(entry, _Digits);

            double sl = lastHigh + slAdditionalPoints * _Point;
            if(sl - entry < atrValue[cbBars - 1] * slMaximumAtrRatio) {
               double tp = entry - takeProfit4 * MathAbs(sl - entry);

               double lots = calcLots(riskPercentage, sl - entry);
               Print("### Opening Sell Position");
               if(trade.Sell(lots, _Symbol, entry, sl, tp, "# HANWC Sell")) {
                  sellTicket = trade.ResultOrder();
               }
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double FindLastLow(int lastBars) {
   double lowestLow = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, lastBars, 0));
   return lowestLow;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double FindLastHigh(int lastBars) {
   double highestHigh = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, lastBars, 0));
   return highestHigh;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calcLots(double riskPercentage, double slDistance) {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if (tickSize == 0 || tickValue == 0 || lotStep == 0) {
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
   }

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double newRiskPercentage = riskPercentage;
   //Reduce the function's return value by 10% for every 1% of initial capital lost
   if(capitalProtection && currentBalance < accountStartBalance) {
      double lossPercentage = (accountStartBalance - currentBalance) / accountStartBalance ;
      newRiskPercentage = riskPercentage - lossPercentage * 10;
   }
   //double lossPercentage = ((accountStartBalance - currentBalance) / accountStartBalance * 100);
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
//|                                                                  |
//+------------------------------------------------------------------+
double calcTakeProfit(double takeProfitRatio ) {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return riskPercentage / 4 * takeProfitRatio * currentBalance/100;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
