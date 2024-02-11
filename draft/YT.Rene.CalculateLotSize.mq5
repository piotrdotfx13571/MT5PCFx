#include <Trade/Trade.mqh>

#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
int OnInit()
  {
   
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason){}

void OnTick(){

if(PositionsTotal()==0){
double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  entry = NormalizeDouble(entry, _Digits);
  
  double sl = entry - 280 * _Point;
  sl = NormalizeDouble(sl, _Digits);
  
  double lots = calcLots(1.0, entry - sl);
  
  CTrade trade;
  
  trade.Buy(lots, _Symbol, entry, sl);
  }
}
   
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

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercentage /100;
   double moneyLotStep = (slDistance/tickSize) * tickValue * lotStep;

   if(moneyLotStep == 0)
     {
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
     }
   double lots = MathFloor(riskMoney/ moneyLotStep) * lotStep;
   return lots;
  }