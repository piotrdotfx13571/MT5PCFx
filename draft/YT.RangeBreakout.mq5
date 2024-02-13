//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

input group "----- General inputs -----"
input long InpMagicNumber = 12345;     //Magic number
input double InpRiskPercentage = 1.0;  //Risk percantage of balance
input double InpLots = 0.1;            //Lots size if Risk=0
input int InpStopLoss = 120;           //Stop loss    (0 = off)
input int InpTakeProfit = 240;         //Take profit  (0 = off))
input int InpAccStartBalance = 25000;  //Account start balance for capital protection mechanism
input bool InpCapitalProt = false;     //Capital protection mechanism


input group "----- Range inputs -----"
input int InpRangeStart = 122;         //Range start time in minutes
input int InpRangeDuration = 267;      //Range duration in minutes
input int InpRangeClose = 1080;        //Range close time in minutes (-1 = off)

enum BREAKOUT_MODE_ENUM {
   ONE_SIGNAL,                         //One breakout per range
   TWO_SIGNALS                         //High and low breakout
};
input BREAKOUT_MODE_ENUM InpBreakoutMode = ONE_SIGNAL; //breakout mode


input group "----- Day of week filter-----"
input bool InpMonday = true;           //Range on monday
input bool InpTuesday = true;          //Range on tuesday
input bool InpWednsday = true;         //Range on wednsay
input bool InpThursday = true;         //Range on thursday
input bool InpFriday = true;           //Range on friday

struct RANGE_STRUCT {
   datetime start_time;                //Start of the range
   datetime end_time;                  //End of the range
   datetime close_time;                //Close time
   double high;                        //High of the range
   double low;                         //Low of the range
   bool f_entry;                       //Flag if we are inside the range
   bool f_high_breakout;               //Flag if a high breakout occured
   bool f_low_breakout;                //Flag if a low breakout occured

   RANGE_STRUCT()  : start_time(0), end_time(0), close_time(0), high(0), low(DBL_MAX), f_entry(false), f_high_breakout(false), f_low_breakout(false) {};
};

RANGE_STRUCT range;
MqlTick prevTick, lastTick;
CTrade trade;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   //Chceck user inputs
   if (!CheckInputs()) {
      return INIT_PARAMETERS_INCORRECT;
   }

   //set magicNumber
   trade.SetExpertMagicNumber(InpMagicNumber);

   //Calculate range if params were change
   if(_UninitReason == REASON_PARAMETERS && CountOpenPositions()==0) { //Todo
      CalculateRange();
   }
   
   //Draw objects
   DrawObjects();


   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {

   //delete objects
   ObjectsDeleteAll(NULL, "range");
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   //Get current tick
   prevTick = lastTick;
   SymbolInfoTick(_Symbol, lastTick);

   //Rabne calculation
   if(lastTick.time >= range.start_time && lastTick.time < range.end_time) {
      //set flag
      range.f_entry = true;
      //new high
      if(lastTick.ask > range.high) {
         range.high = lastTick.ask;
         DrawObjects();
      }
      //new low
      if (lastTick.bid < range.low) {
         range.low = lastTick.bid;
         DrawObjects();
      }
   }

   //close positions
   if(InpRangeClose >= 0 && lastTick.time >= range.close_time) {
      if(!ClosePositions()) {
         return ;
      }
   }

   //Calculate new range if...
   if(((InpRangeClose >= 0 && lastTick.time >= range.close_time)                       //close time reached
         || (range.f_high_breakout && range.f_low_breakout)                            //both breakout flags is true
         || (range.end_time == 0)                                                        // range not calculated yet
         || (range.end_time != 0 && lastTick.time > range.end_time && !range.f_entry))   //there was a range calculated but no tick inside
         && CountOpenPositions() == 0) {



      CalculateRange();
   }

//check for breakouts
   CheckBreakouts();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//Check user inputs
bool CheckInputs() {
   if(InpMagicNumber <= 0) {
      Alert("Magic number <=0");
      return false;
   }
   if(InpLots <= 0 || InpLots > 1) {
      Alert("Magic number <=0");
      return false;
   }
   if(InpStopLoss <= 0 || InpStopLoss > 1000) {
      Alert("StopLoss <=0 or stop loss >1000");
      return false;
   }
   if(InpTakeProfit <= 0 || InpTakeProfit > 1000) {
      Alert("Take profit <=0 or take profit > 1000");
      return false;
   }
   if(InpRangeClose < 0 || InpStopLoss == 0) {
      Alert("Close time and stop loss is off");
      return false;
   }
   if(InpRangeStart < 0 || InpRangeStart >= 1440) {
      Alert("Range start < 0 or >= 1440");
      return false;
   }
   if(InpRangeDuration <= 0 || InpRangeDuration >= 1440) {
      Alert("Range duration< 0 or >= 14400");
      return false;
   }
   if(InpRangeClose >= 1440 || (InpRangeStart + InpRangeDuration) % 1440 == InpRangeClose) {
      Alert("Close time >= 14400 or end time == close time");
      return false;
   }
   if(InpMonday + InpTuesday + InpWednsday + InpThursday + InpFriday == 0) {
      Alert("Range is prohibited on all days of the week");
      return false;
   }
   return true;
}

//calculate a new range
void CalculateRange() {
//reset range variables
   range.start_time = 0;
   range.end_time = 0;
   range.close_time = 0;
   range.high = 0;
   range.low = DBL_MAX;
   range.f_entry = false;
   range.f_high_breakout = false;
   range.f_low_breakout = false;

//calculate range start time
   int time_cycle = 86400;
   range.start_time = (lastTick.time - (lastTick.time % time_cycle)) + InpRangeStart * 60;
   for(int i = 0; i < 8; i++) {
      MqlDateTime tmp;
      TimeToStruct(range.start_time, tmp);
      int dow = tmp.day_of_week;
      if(lastTick.time >= range.start_time || dow == 6 || dow == 0 || (dow == 1 && !InpMonday) || (dow == 2 && !InpTuesday) || (dow == 3 && !InpWednsday)
            || (dow == 4 && !InpThursday) || (dow == 5 && !InpFriday)) {
         range.start_time += time_cycle;
      }
   }

   //calculate range end time
   range.end_time = range.start_time + InpRangeDuration * 60;
   for ( int i = 0; i < 2 ; i++) {
      MqlDateTime tmp;
      TimeToStruct(range.end_time, tmp);
      int dow = tmp.day_of_week;
      if (dow == 6 || dow == 0) {
         range.start_time += time_cycle;
      }
   }

   //calculate range close
   if(InpRangeClose >= 0 ) {
      range.close_time = (range.end_time - (range.end_time % time_cycle)) +  InpRangeDuration * 60;
      for ( int i = 0; i < 3 ; i++) {
         MqlDateTime tmp;
         TimeToStruct(range.close_time, tmp);
         int dow = tmp.day_of_week;
         if (range.close_time <= range.end_time || dow == 6 || dow == 0) {
            range.close_time += time_cycle;
         }
      }
   }
//draw objects
   DrawObjects();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//Count all open positions
int CountOpenPositions() {
   int counter = 0;
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) {
         Print("### RB Failed to get position ticket");
         return -1;
      }
      if(!PositionSelectByTicket(ticket)) {
         Print("### RB Failed to select position by ticket");
         return -1;
      }
      ulong magicNumber;
      if(!PositionGetInteger(POSITION_MAGIC, magicNumber)) {
         Print("### RB Failed to get position magicNumber");
         return -1;
      }
      if(InpMagicNumber == magicNumber) {
         counter++;
      }
   }

   return counter;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//Check for breakouts
void CheckBreakouts() {
   //check if we are after the range end
   if(lastTick.time >= range.end_time && range.end_time > 0 && range.f_entry) {

      // check for high breakout
      if(!range.f_high_breakout && lastTick.ask >= range.high) {
         range.f_high_breakout = true;
         if(InpBreakoutMode == ONE_SIGNAL) {
            range.f_low_breakout = true;
         }

         //calculate stop loss and take profit
         double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.bid - ((range.high - range.low) * InpStopLoss * 0.01), _Digits);
         double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.bid + ((range.high - range.low) * InpStopLoss * 0.01), _Digits);
         double lots = InpRiskPercentage > 0 ? calcLots(lastTick.bid - sl) : InpLots;

         //open buy position
         trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lots, lastTick.ask, sl, tp, "### RB BUY");
      }
      // check for low breakout

      if(!range.f_low_breakout && lastTick.bid >= range.low) {
         range.f_low_breakout = true;
         if(InpBreakoutMode == ONE_SIGNAL) {
            range.f_high_breakout = true;
         }

         //calculate stop loss and take profit
         double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.ask + ((range.high - range.low) * InpStopLoss * 0.01), _Digits);
         double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.ask - ((range.high - range.low) * InpStopLoss * 0.01), _Digits);
          double lots = InpRiskPercentage > 0 ? calcLots(sl - lastTick.ask) : InpLots;

         //open sell position
         trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lots, lastTick.bid, sl, tp, "### RB SELL");
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//Close all open positions
bool ClosePositions() {
   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--) {
      if(total != PositionsTotal()) {
         total = PositionsTotal();
         i = total;
         continue;
      }
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 ) {
         Print("### RB Failed to get position ticket");
         return false;
      }
      if (!PositionSelectByTicket(ticket)) {
         Print("### RB Failed to select positions by ticket");
         return false;
      }
      long magicNumber;
      if(!PositionGetInteger(POSITION_MAGIC, magicNumber)) {
         Print("### RB Failed to get position Magic Number");
         return false;
      }
      if(magicNumber == InpMagicNumber) {
         trade.PositionClose(ticket);
         if(trade.ResultRetcode() != TRADE_RETCODE_DONE) {
            Print("### RBFailed to close positions. Result: " + (string)trade.ResultRetcode() + ":" + trade.ResultRetcodeDescription());
            return false;
         }
      }
   }

   return true;
}

//Draw chert objects
void DrawObjects() {
   //start
   ObjectDelete(NULL, "range start");
   if (range.start_time > 0) {
      ObjectCreate(NULL, "range start", OBJ_VLINE, 0, range.start_time, 0);
      ObjectSetString(NULL, "range start", OBJPROP_TOOLTIP, "start of the range \n" + TimeToString(range.start_time, TIME_DATE || TIME_MINUTES));
      ObjectSetInteger(NULL, "range start", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range start", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range start", OBJPROP_BACK, true);
   }

   //end time
   ObjectDelete(NULL, "range end");
   if (range.start_time > 0) {
      ObjectCreate(NULL, "range end", OBJ_VLINE, 0, range.end_time, 0);
      ObjectSetString(NULL, "range end", OBJPROP_TOOLTIP, "end of the range \n" + TimeToString(range.end_time, TIME_DATE || TIME_MINUTES));
      ObjectSetInteger(NULL, "range end", OBJPROP_COLOR, clrDarkBlue);
      ObjectSetInteger(NULL, "range end", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range end", OBJPROP_BACK, true);
   }

   //close time
   ObjectDelete(NULL, "range close");
   if (range.close_time > 0) {
      ObjectCreate(NULL, "range close", OBJ_VLINE, 0, range.close_time, 0);
      ObjectSetString(NULL, "range close", OBJPROP_TOOLTIP, "close the range \n" + TimeToString(range.end_time, TIME_DATE || TIME_MINUTES));
      ObjectSetInteger(NULL, "range close", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(NULL, "range close", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range close", OBJPROP_BACK, true);
   }

   //high
   ObjectsDeleteAll(NULL, "range high");
   if (range.high > 0) {
      ObjectCreate(NULL, "range high", OBJ_TREND, 0, range.start_time, range.high, InpRangeClose >= 0 ? range.close_time : INT_MAX, range.high);
      ObjectSetString(NULL, "range high", OBJPROP_TOOLTIP, "high of the range \n" + DoubleToString(range.high, _Digits));
      ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range high", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);

      ObjectCreate(NULL, "range high ", OBJ_TREND, 0, range.start_time, range.high, range.end_time, range.high);
      ObjectSetString(NULL, "range high ", OBJPROP_TOOLTIP, "high of the range \n" + DoubleToString(range.high, _Digits));
      ObjectSetInteger(NULL, "range high ", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range high ", OBJPROP_BACK, true);
      ObjectSetInteger(NULL, "range high ", OBJPROP_STYLE, STYLE_DOT);
   }

//low
   ObjectsDeleteAll(NULL, "range highlow");
   if (range.high < DBL_MAX) {
      ObjectCreate(NULL, "range low", OBJ_TREND, 0, range.start_time, range.low, range.end_time, range.low);
      ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP, "low of the range \n" + DoubleToString(range.low, _Digits));
      ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range low", OBJPROP_WIDTH, 2);
      ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);

      ObjectCreate(NULL, "range low ", OBJ_TREND, 0, range.end_time, range.low, InpRangeClose >= 0 ? range.close_time : INT_MAX, range.low);
      ObjectSetString(NULL, "range low ", OBJPROP_TOOLTIP, "low of the range \n" + DoubleToString(range.low, _Digits));
      ObjectSetInteger(NULL, "range low ", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(NULL, "range low ", OBJPROP_BACK, true);
      ObjectSetInteger(NULL, "range low ", OBJPROP_STYLE, STYLE_DOT);
   }

}

double calcLots(double slDistance) {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if (tickSize == 0 || tickValue == 0 || lotStep == 0) {
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
   }

   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double newInpRiskPercentage = InpRiskPercentage;
   //Reduce the function's return value by 10% for every 1% of initial capital lost
   if(InpCapitalProt && currentBalance < InpAccStartBalance) {
      double lossPercentage = (InpAccStartBalance - currentBalance) / InpAccStartBalance ;
      newInpRiskPercentage = InpRiskPercentage - lossPercentage * 10;
   }
   //double lossPercentage = ((InpAccStartBalance - currentBalance) / InpAccStartBalance * 100);
   //newInpRiskPercentage = lossPercentage < 2 ? 0.50 : 0.33;
   //if ( lossPercentage > 6) {
   //   Print(__FUNCTION__, "### Margin. 6% lost from challenge lost");
   //   return 0;
   //

   double riskMoney = currentBalance * newInpRiskPercentage / 100;
   double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;

   if (moneyLotStep == 0) {
      Print(__FUNCTION__, " > Lotsize cannot be calculated ...");
      return 0;
   }

   double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
   return lots;
}