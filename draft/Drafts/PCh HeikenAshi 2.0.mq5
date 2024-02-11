#include <Trade\Trade.mqh>

int handleHeikenAshi;
int barsTotal;
ulong posTicket;

input double       riskPercentage = 1;
input double       slPoints = 100;

CTrade trade;

int OnInit()
{
   barsTotal = iBars(_Symbol, PERIOD_CURRENT);

   handleHeikenAshi = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\Heiken_Ashi.ex5");
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

}

void OnTick(){
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   if(barsTotal != bars){
      barsTotal= bars;
   
   
      double haOpen [], haClose[];
      CopyBuffer(handleHeikenAshi,0,1,1,haOpen);
      CopyBuffer(handleHeikenAshi,3,1,1,haClose);
  
      if(haOpen[0]< haClose[0]){
      //BUY CANDLE
         if(posTicket > 0){
            if(PositionSelectByTicket(posTicket)){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  if(trade.PositionClose(posTicket)){
                  posTicket=0;
                  }
               }
            }else{
               posTicket = 0;
            }
         }
         //BUY
         if(posTicket <= 0){
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            entry = NormalizeDouble(entry, _Digits);
            
            double sl = entry - slPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);
            
            double lots = calcLots(riskPercentage, entry - sl);
            
            if(trade.Buy(lots, _Symbol, entry, sl)){
               posTicket= trade.ResultOrder();
            }
         }
      }else if(haOpen[0] > haClose[0]){
      //SELL CANDLE
         if(PositionSelectByTicket(posTicket)){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  if(trade.PositionClose(posTicket)){
                  posTicket=0;
                  }
               }
            }else{
               posTicket = 0;
            }
         if( posTicket <= 0){
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            entry = NormalizeDouble(entry, _Digits);
           
            double sl = entry + slPoints * _Point;
            sl = NormalizeDouble(sl, _Digits);
           
            double lots = calcLots(riskPercentage, sl - entry);
            
            if(trade.Sell(lots, _Symbol, entry, sl)){
               posTicket= trade.ResultOrder();
            }
         }  
      }   
   

   Comment("\nHA Open: ", DoubleToString(haOpen[0], _Digits),
         "\nHA Close: ", DoubleToString(haClose[0], _Digits),
         "\nPos Ticket: ", posTicket);
   }
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

