#include <Trade\Trade.mqh>

int handleHeikenAshi;
int barsTotal;
ulong posTicket;

input double       riskPercentage = 1;
input double       slPoints = 100;
input int          lastBars = 20; //last bars for high/low check

double lastLow = 0.0;
double lastHigh = 0.0;

CTrade trade;

int OnInit(){
   barsTotal = iBars(_Symbol, PERIOD_CURRENT);

   handleHeikenAshi = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\Heiken_Ashi.ex5");
   
   lastLow = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, 0));
   lastHigh = iHigh(NULL, 0, iLowest(NULL, 0, MODE_HIGH, 0));

   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){}

void OnTick(){
   //Last low/high
     // Aktualizacja ostatnich dołka i szczytu

  // Aktualizacja ostatnich dołka i szczytu
   lastLow = FindLastLow();
   lastHigh = FindLastHigh();

   Print("Ostatni dołek: ", lastLow);
   Print("Ostatni szczyt: ", lastHigh);

   //HeikenAshi
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   if(barsTotal != bars){
      barsTotal= bars;
   
   
      double haOpen [], haClose[], haLow[], haHigh[];
      CopyBuffer(handleHeikenAshi,0,1,1,haOpen);
      CopyBuffer(handleHeikenAshi,1,1,1,haHigh);
      CopyBuffer(handleHeikenAshi,2,1,1,haLow);
      CopyBuffer(handleHeikenAshi,3,1,1,haClose);
      
      Print("Bars Total: ", barsTotal);
  
      if(haOpen[0]< haClose[0] && haLow[0]==haOpen[0]){
       Print("Opening Buy Position");
      //BUY CANDLE
         if(posTicket > 0){
            if(PositionSelectByTicket(posTicket)){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  if(trade.PositionClose(posTicket)){
                  Print("Close sell posiition. ");
                  posTicket=0;
                  Sleep(3000);
                  }
               }
            }
            else{
               posTicket = 0;
               Sleep(3000);
            }
         }
         //BUY
         if(posTicket <= 0){
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            entry = NormalizeDouble(entry, _Digits);
            
            
            double sl = FindLastLow();
            
            double lots = calcLots(riskPercentage, entry - sl);
            
            if(trade.Buy(lots, _Symbol, entry, sl)){
               posTicket= trade.ResultOrder();
               Sleep(3000);
            }
         }
      }else if(haOpen[0] > haClose[0] && haHigh[0] == haOpen[0]){
       Print("Opening Sell Position");
      //SELL CANDLE
         if(PositionSelectByTicket(posTicket)){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                  if(trade.PositionClose(posTicket)){
                  posTicket=0;
                  Sleep(3000);
                  }
               }
            }else{
               posTicket = 0;
               Sleep(3000);
            }
         if( posTicket <= 0){
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            entry = NormalizeDouble(entry, _Digits);
           
            double sl = FindLastHigh();
           
            double lots = calcLots(riskPercentage, sl - entry);
            
            if(trade.Sell(lots, _Symbol, entry, sl)){
               posTicket= trade.ResultOrder();
               Sleep(3000);
            }
         } 
            Print("HA Open: ", DoubleToString(haOpen[0], _Digits),
            "HA Close: ", DoubleToString(haClose[0], _Digits),
            "Pos Ticket: ", posTicket);
      }   
   

   Comment("\nHA Open: ", DoubleToString(haOpen[0], _Digits),
         "\nHA Close: ", DoubleToString(haClose[0], _Digits),
         "\nPos Ticket: ", posTicket);
   }
}

//FUNCTIONS
double FindLastLow(){
   double lowestLow = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, lastBars, 0));
   return lowestLow;
}

double FindLastHigh(){
   double highestHigh = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, lastBars, 0));
   return highestHigh;
}

double calcLots(double riskPercentage, double slDistance){
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if (tickSize == 0 || tickValue == 0 || lotStep == 0){
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercentage /100;
   double moneyLotStep = (slDistance/tickSize) * tickValue * lotStep;
   
   if(moneyLotStep == 0){
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
   }
   double lots = MathFloor(riskMoney/ moneyLotStep) * lotStep;
   return lots;
}

