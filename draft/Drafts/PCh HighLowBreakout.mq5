#include <Trade\Trade.mqh>

//Inputs
input int   inpBars = 20; //bars for high/low
input int   inpStopLoss = 200;
input int   inpTakeProfit = 0;
input long  inpMagicNumber= 546872;

double high = 0;        //highest price of the last N bars
double low = 0;         // lowest price of the last N bars

MqlTick currentTick, previousTick;
CTrade trade;


int OnInit(){
   
   
   return(INIT_SUCCEEDED);
}

void OnTick(){
   //get tick
   previousTick =currentTick;
   if(!SymbolInfoTick(_Symbol, currentTick)){
      Print("Failed to get current tick");
      return;
      }
}

//Functions
bool CountOpenPositions(int &cntBuy, int &cntSell){
   cntBuy=0;
   cntSell=0;
   int total = PositionsTotal();
   for(int i=totl -1; i>=0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket <=0){
         Print("Failed to get position ticket");
         return false;
      }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)){
         Print("Failed to get position magicnumber");
         return false;
      }
      if (magic==InpMa)
   }
   
   
   
   
   }

