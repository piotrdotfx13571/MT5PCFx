//+------------------------------------------------------------------+
//| ClosePositionOnRRTargetWithBarsAndTPAndTrailingSL.mq5          |
//|                        Generated by ChatGPT                      |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

int handleHeikenAshi;
int barsTotal;
ulong posTicket;

input double   riskPercentage = 1;
input int      lastBars = 20; // last bars for high/low check
input int      barsInTrend = 20; //last bars in end of trend check
input double   rrTarget = 4.0; // RR target for TP calculation
input double   trailingStopDistance = 200; // Trailing Stop Loss distance in points
input string   StartTime = "09:00";
input string   EndTime = "22:59";
input double   partialClose_1 = 1.25;
input double   partialClose_2 = 4;


double         partialCloseValues[2];
int            partialCloseCounter = 0;
double         lastLow = 0.0;
double         lastHigh = 0.0;

ulong          buyTicket = 0;
ulong          sellTicket = 0;

CTrade trade;

// Declare a struct to hold position data
struct PositionData
  {
   double            volume;
   int               numberOfPartialClosed;
  };

// Declare a dynamic array to store position data
PositionData positionDataArray[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   barsTotal = iBars(_Symbol, PERIOD_CURRENT);

   handleHeikenAshi = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\Heiken_Ashi.ex5");

   lastLow = FindLastLow();
   lastHigh = FindLastHigh();

// Inicjalizacja tablicy partialCloseValues

   partialCloseValues[0] = partialClose_1;
   partialCloseValues[1] = partialClose_2;

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
// Check if it's time to trade
   datetime currentTime = iTime(NULL, 0, 0);
   datetime startTradingTime = StringToTime(StartTime);
   datetime endTradingTime = StringToTime(EndTime);

   if(currentTime < startTradingTime || currentTime > endTradingTime)
     {
      return; // Do not trade outside the specified hours
     }

// Trailing Stop Loss
   if(buyTicket > 0 || sellTicket > 0)
     {
      ulong posTicket = buyTicket > 0 ? buyTicket : sellTicket;
      if(PositionSelectByTicket(posTicket))
        {
         double currentSL = PositionGetDouble(POSITION_SL);
         double newSL;

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            newSL = MathMax(lastLow - trailingStopDistance * Point(), currentSL);
           }
         else
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               newSL = MathMin(lastHigh + trailingStopDistance * Point(), currentSL);
              }

         if(newSL != currentSL)
           {
            if(trade.PositionModify(posTicket, newSL, 0))
              {
               Print("Trailing Stop Loss modified: ", DoubleToString(newSL, _Digits));
              }
           }

         // Partial close
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double originalPositionSize;

         // Find the corresponding PositionData for the current position
         PositionData currentPosData;
         for(int i = 0; i < ArraySize(positionDataArray); i++)
           {
            if(positionDataArray[i].volume == originalPositionSize)
              {
               currentPosData = positionDataArray[i];
               break;
              }
           }

         // Use currentPosData.volume instead of positionSize in your calculations
         double closeVolume = NormalizeDouble(currentPosData.volume, _Digits) * 0.5;

         for(int i = 0; i < 4; i++)
           {
            double rrValue = partialCloseValues[i];
            bool shouldClose = false;
            double currentRrValue;

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && (currentPrice - entryPrice) / (entryPrice - currentSL) >= rrValue)
              {
               shouldClose = true;
               currentRrValue = (currentPrice - entryPrice) / (entryPrice - currentSL);
              }

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && (entryPrice - currentPrice) / (currentSL - entryPrice) >= rrValue)
              {
               shouldClose = true;
               currentRrValue = (entryPrice - currentPrice) / (currentSL - entryPrice);
              }

            if(shouldClose)
              {
               if(trade.PositionClosePartial(posTicket, closeVolume))
                 {
                  Print("Partial position closed: ", DoubleToString(closeVolume, _Digits));
                 }
               else
                 {
                  int error = trade.ResultRetcode();
                  string errorDescription = trade.ResultRetcodeDescription();
                  Print("Error closing position! Code: ", error, ", Description: ", errorDescription);
                 }
              }
           }
        }
     }

// Last low/high
// Aktualizacja ostatnich dołka i szczytu
   lastLow = FindLastLow();
   lastHigh = FindLastHigh();

// HeikenAshi
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   if(barsTotal != bars)
     {
      barsTotal = bars;

      double haOpen [], haClose[], haLow[], haHigh[];
      CopyBuffer(handleHeikenAshi, 0, 1, 1, haOpen);
      CopyBuffer(handleHeikenAshi, 1, 1, 1, haHigh);
      CopyBuffer(handleHeikenAshi, 2, 1, 1, haLow);
      CopyBuffer(handleHeikenAshi, 3, 1, 1, haClose);

      Print("Bars Total: ", barsTotal);

      if(haOpen[0]< haClose[0] && haLow[0]==haOpen[0] && IsDowntrendFinished())
        {
         Print("Opening Buy Position");

         // BUY CANDLE
         if(sellTicket > 0)
           {
            if(PositionSelectByTicket(sellTicket))
              {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                 {
                  if(trade.PositionClose(sellTicket))
                    {
                     Print("Close sell position. ");
                     sellTicket = 0;
                    }
                 }
              }
            else
              {
               sellTicket = 0;
              }
           }

         // BUY
         if(buyTicket <= 0)
           {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            entry = NormalizeDouble(entry, _Digits);

            double sl = FindLastLow();
            double tp = entry + rrTarget * MathAbs(entry - sl);

            double lots = calcLots(riskPercentage, entry - sl);

            if(trade.Buy(lots, _Symbol, entry, sl, tp))
              {
               PositionData positionData;
               positionData.volume = lots;
               positionData.numberOfPartialClosed = 0;
               ArrayResize(positionDataArray, ArraySize(positionDataArray) + 1);
               positionDataArray[ArraySize(positionDataArray) - 1] = positionData;
              }
           }
        }
      else
         if(haOpen[0] > haClose[0] && haHigh[0] == haOpen[0] && IsUptrendFinished())
           {
            Print("Opening Sell Position");

            // BUY CANDLE
            if(buyTicket > 0)
              {
               if(PositionSelectByTicket(buyTicket))
                 {
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                    {
                     if(trade.PositionClose(buyTicket))
                       {
                        buyTicket = 0;
                       }
                    }
                 }
               else
                 {
                  buyTicket = 0;
                 }
              }

            // SELL
            if(sellTicket <= 0)
              {
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               entry = NormalizeDouble(entry, _Digits);

               double sl = FindLastHigh();
               double tp = entry - rrTarget * MathAbs(sl - entry);

               double lots = calcLots(riskPercentage, sl - entry);

               if(trade.Sell(lots, _Symbol, entry, sl, tp))
                 {
                  sellTicket = trade.ResultOrder();

                  PositionData positionData;
                  positionData.volume = lots;
                  positionData.numberOfPartialClosed = 0;
                  ArrayResize(positionDataArray, ArraySize(positionDataArray) + 1);
                  positionDataArray[ArraySize(positionDataArray) - 1] = positionData;
                 }
              }
            Print("HA Open: ", DoubleToString(haOpen[0], _Digits),
                  "HA Close: ", DoubleToString(haClose[0], _Digits),
                  "Buy Ticket: ", buyTicket,
                  "Sell Ticket: ", sellTicket);
           }

      Comment("\nHA Open: ", DoubleToString(haOpen[0], _Digits),
              "\nHA Close: ", DoubleToString(haClose[0], _Digits),
              "\nBuy Ticket: ", buyTicket,
              "\nSell Ticket: ", sellTicket);
     }
  }



// FUNCTIONS
double FindLastLow()
  {
   double lowestLow = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, lastBars, 0));
   return lowestLow;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double FindLastHigh()
  {
   double highestHigh = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, lastBars, 0));
   return highestHigh;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsUptrendFinished()
  {
   for(int i = 1; i <= barsInTrend; i++)
     {
      if(iClose(NULL, 0, i) < iOpen(NULL, 0, i))
        {
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDowntrendFinished()
  {
   for(int i = 1; i <= barsInTrend; i++)
     {
      if(iClose(NULL, 0, i) > iOpen(NULL, 0, i))
        {
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calcLots(double riskPercentage, double slDistance)
  {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickSize == 0 || tickValue == 0 || lotStep == 0)
     {
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
     }

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercentage / 100;
   double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;

   if(moneyLotStep == 0)
     {
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
     }
   double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
   return lots;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyTrailingStop(ulong ticket, double level, int positionType)
  {
   if(PositionSelectByTicket(ticket))
     {
      double currentSL = PositionGetDouble(POSITION_SL);
      double newSL;

      if(positionType == POSITION_TYPE_BUY)
        {
         newSL = MathMax(level - trailingStopDistance * Point(), currentSL);
        }
      else
         if(positionType == POSITION_TYPE_SELL)
           {
            newSL = MathMin(level + trailingStopDistance * Point(), currentSL);
           }

      if(newSL != currentSL)
        {
         if(trade.PositionModify(ticket, newSL, 0))
           {
            Print("Trailing Stop Loss modified: ", DoubleToString(newSL, _Digits));
           }
        }
     }
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
