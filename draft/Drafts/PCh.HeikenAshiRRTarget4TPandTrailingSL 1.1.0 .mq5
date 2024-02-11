//+------------------------------------------------------------------+
//| MultiPositionTradingWithTargets.mq5                            |
//|                        Refactored by ChatGPT                     |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

// Parametry handlowe
input double riskPercentage = 0.25;
input int lastBars = 20;
input int barsInTrend = 20;
input double rrTarget1 = 0.8;
input double rrTarget2 = 1.25;
input double rrTarget3 = 2;
input double rrTarget4 = 3;
input double trailingStopDistance = 80;
input string StartTime = "09:00";
input string EndTime = "22:59";

// Zmienne globalne
CTrade trade;
int handleHeikenAshi;
int barsTotal;
ulong posTickets[];

//+------------------------------------------------------------------+
//| Inicjalizacja skryptu                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   barsTotal = iBars(_Symbol, PERIOD_CURRENT);
   handleHeikenAshi = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\Heiken_Ashi.ex5");

   return (INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//| Obsługa zdarzenia Tick                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
// Sprawdzenie, czy można handlować w danym czasie
   datetime currentTime = iTime(NULL, 0, 0);
   datetime startTradingTime = StringToTime(StartTime);
   datetime endTradingTime = StringToTime(EndTime);

   if(currentTime < startTradingTime || currentTime > endTradingTime)
     {
      return; // Handel tylko w określonych godzinach
     }

// Aktualizacja formacji HeikenAshi
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   if(barsTotal != bars)
     {
      barsTotal = bars;

      double haOpen[], haClose[], haLow[], haHigh[];
      CopyBuffer(handleHeikenAshi, 0, 1, 1, haOpen);
      CopyBuffer(handleHeikenAshi, 1, 1, 1, haHigh);
      CopyBuffer(handleHeikenAshi, 2, 1, 1, haLow);
      CopyBuffer(handleHeikenAshi, 3, 1, 1, haClose);

      if(AreAllPositionsClosed())   // Check if all positions are closed
        {
         if(ArraySize(posTickets) == 0)
           {
            ArrayResize(posTickets, 1); // Inicjowanie tablicy, jeśli nie została jeszcze zainicjowana
           }
         for(int i = 0; i < ArraySize(posTickets); i++)
           {
            HandleTrailingStopLoss(posTickets[i]);
           }

         if(haOpen[0] < haClose[0] && haLow[0] == haOpen[0] && IsDowntrendFinished())
           {
            OpenBuyPositions();
           }
         else
            if(haOpen[0] > haClose[0] && haHigh[0] == haOpen[0] && IsUptrendFinished())
              {
               OpenSellPositions();
              }
        }
     }
  }


// Funkcja do obsługi Trailing Stop Loss
void HandleTrailingStopLoss(ulong posTicket)
  {
   if(ArraySize(posTickets) == 0 || posTicket <= 0)
     {
      return;  // No positions or invalid ticket
     }

   for(int i = 0; i < ArraySize(posTickets); i++)
     {
      if(posTickets[i] == posTicket)
        {
         if(PositionSelectByTicket(posTicket))
           {
            double currentSL = PositionGetDouble(POSITION_SL);
            double newSL = CalculateNewTrailingSL(currentSL);

            if(newSL != currentSL)
              {
               ModifyTrailingStopLoss(posTicket, newSL);
              }
            break;  // Stop loop once the position is found and handled
           }
        }
     }
  }


// Funkcja modyfikacji Trailing Stop Loss
void ModifyTrailingStopLoss(ulong posTicket, double newSL)
  {
   if(trade.PositionModify(posTicket, newSL, 0))
     {
      Print("Trailing Stop Loss modified for Ticket ", posTicket, ": ", DoubleToString(newSL, _Digits));
     }
  }

// Funkcja zamknięcia zlecenia po numerze
void ClosePositionByTicket(ulong ticket)
  {
   if(PositionSelectByTicket(ticket))
     {
      if(trade.PositionClose(ticket))
        {
         Print("Close position. Ticket: ", ticket);
        }
     }
  }

// Funkcja otwarcia 4 zleceń kupna z różnymi celami zysku
void OpenBuyPositions()
  {
   if(!AreAllPositionsClosed())
     {
      Print("Cannot open new Buy positions. Some positions are still open.");
      return;
     }

   double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   entry = NormalizeDouble(entry, _Digits);

   double sl = FindLastLow();

   double tp1 = entry + rrTarget1 * MathAbs(entry - sl);
   double tp2 = entry + rrTarget2 * MathAbs(entry - sl);
   double tp3 = entry + rrTarget3 * MathAbs(entry - sl);
   double tp4 = entry + rrTarget4 * MathAbs(entry - sl);

   double lots = CalculateLots(riskPercentage, entry - sl);

   int initialSize = ArraySize(posTickets);

   for(int i = 1; i <= 4; i++)
     {
      double targetProfit = 0.0;

      switch(i)
        {
         case 1:
            targetProfit = tp1;
            break;
         case 2:
            targetProfit = tp2;
            break;
         case 3:
            targetProfit = tp3;
            break;
         case 4:
            targetProfit = tp4;
            break;
        }

      ulong ticket = trade.Buy(lots, _Symbol, entry, sl, targetProfit);
      if(ticket > 0)
        {
         ArrayResize(posTickets, initialSize + 1);  // Resize the array to accommodate the new position
         posTickets[initialSize] = ticket;
         Print("Buy position ", i, " opened. Ticket: ", posTickets[initialSize]);
         Sleep(3000);
        }
      else
        {
         Print("Failed to open Buy position ", i);
        }
     }
  }

// Funkcja otwarcia 4 zleceń sprzedaży z różnymi celami zysku
void OpenSellPositions()
  {
   if(!AreAllPositionsClosed())
     {
      Print("Cannot open new Sell positions. Some positions are still open.");
      return;
     }

   double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   entry = NormalizeDouble(entry, _Digits);

   double sl = FindLastHigh();

   double tp1 = entry - rrTarget1 * MathAbs(sl - entry);
   double tp2 = entry - rrTarget2 * MathAbs(sl - entry);
   double tp3 = entry - rrTarget3 * MathAbs(sl - entry);
   double tp4 = entry - rrTarget4 * MathAbs(sl - entry);

   double lots = CalculateLots(riskPercentage, sl - entry);

   int initialSize = ArraySize(posTickets);

   for(int i = 1; i <= 4; i++)
     {
      double targetProfit = 0.0;

      switch(i)
        {
         case 1:
            targetProfit = tp1;
            break;
         case 2:
            targetProfit = tp2;
            break;
         case 3:
            targetProfit = tp3;
            break;
         case 4:
            targetProfit = tp4;
            break;
        }

      ulong ticket = trade.Sell(lots, _Symbol, entry, sl, targetProfit);
      if(ticket > 0)
        {
         ArrayResize(posTickets, initialSize + 1);  // Resize the array to accommodate the new position
         posTickets[initialSize] = ticket;
         Print("Sell position ", i, " opened. Ticket: ", posTickets[initialSize]);
        }
      else
        {
         Print("Failed to open Sell position ", i);
        }
     }
  }


// Funkcja znajdująca ostatni najniższy poziom
double FindLastLow()
  {
   return iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, lastBars, 0));
  }

// Funkcja znajdująca ostatni najwyższy poziom
double FindLastHigh()
  {
   return iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, lastBars, 0));
  }

// Funkcja sprawdzająca zakończenie trendu wzrostowego
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

// Funkcja sprawdzająca zakończenie trendu spadkowego
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

// Funkcja obliczająca nowy Trailing Stop Loss
double CalculateNewTrailingSL(double currentSL)
  {
   double newSL;

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
     {
      newSL = MathMax(FindLastLow() - trailingStopDistance * Point(), currentSL);
     }
   else
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         newSL = MathMin(FindLastHigh() + trailingStopDistance * Point(), currentSL);
        }

   return newSL;
  }

// Funkcja obliczająca ilość lotów
double CalculateLots(double riskPercentage, double slDistance)
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

// Funkcja sprawdzająca, czy wszystkie pozycje są zamknięte
// Funkcja sprawdzająca, czy wszystkie pozycje są zamknięte
bool AreAllPositionsClosed()
  {
   for(int i = 0; i < ArraySize(posTickets); i++)
     {
      ulong posTicket = posTickets[i];
      if(PositionSelectByTicket(posTicket))
        {
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY && PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
           {
            return false;  // Zwróć false, jeśli co najmniej jedna pozycja jest otwarta
           }
        }
     }
   return true;  // Zwróć true, jeśli wszystkie pozycje są zamknięte
  }


//+------------------------------------------------------------------+
