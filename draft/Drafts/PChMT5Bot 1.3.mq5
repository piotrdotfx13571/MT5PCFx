#include <Trade\Trade.mqh>

// Define input parameters
input double   loot = 0.01;
input int      MagicNumber=10001;
input double      RiskPercentage = 1;
input string   StartTime = "05:00";
input string   EndTime = "13:30";
input double   tpRatio = 1;
input double   slRatio = 1;

#define OP_BUY 0           //Buy 
#define OP_SELL 1          //Sell 
#define OP_BUYLIMIT 2      //Pending order of BUY LIMIT type 
#define OP_SELLLIMIT 3     //Pending order of SELL LIMIT type 
#define OP_BUYSTOP 4       //Pending order of BUY STOP type 
#define OP_SELLSTOP 5      //Pending order of SELL STOP type 

// Define global variables
double riskPerTrade;
datetime lastTradeTime = 0;

// Define function to check if a candle is bullish engulfing
bool isBullishEngulfing(int index) {
    return (iClose(NULL, 0, index + 2) < iOpen(NULL, 0, index + 3)) && // First candle is bearish
           (iClose(NULL, 0, index + 1) < iOpen(NULL, 0, index + 2)) && // Second candle is bearish
           (iClose(NULL, 0, index + 1) < iOpen(NULL, 0, index + 1)) && // Third candle is bearish
           (iClose(NULL, 0, index) > iHigh(NULL, 0, index + 2));        // Fourth candle closes higher
}

// Define function to check if a candle is bearish engulfing
bool isBearishEngulfing(int index) {
    return (iClose(NULL, 0, index + 2) > iOpen(NULL, 0, index + 3)) && // First candle is bullish
           (iClose(NULL, 0, index + 1) > iOpen(NULL, 0, index + 2)) && // Second candle is bullish
           (iClose(NULL, 0, index + 1) > iOpen(NULL, 0, index + 1)) && // Third candle is bullish
           (iClose(NULL, 0, index) < iLow(NULL, 0, index + 2));        // Fourth candle closes lower
}

// Define function to calculate risk per trade based on account balance
//void calculateRisk() {
//    double freeMargin = (Symbol(), ORDER_TYPE).freemargin;
//    riskPerTrade = freeMargin * RiskPercentage / 100.0;
//}

// Define OnTick function
void OnTick() {
   CTrade trade;
   trade.SetExpertMagicNumber(MagicNumber);
   double Ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double Bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
    // Check if it's time to trade
    datetime currentTime = iTime(NULL, 0, 0);
    datetime startTradingTime = StringToTime(StartTime);
    datetime endTradingTime = StringToTime(EndTime);

    if (currentTime < startTradingTime || currentTime > endTradingTime) {
        return; // Do not trade outside the specified hours
    }

    // Check for new candle
 //   if (lastTradeTime != iTime(NULL, 0, 0)) {
        // Calculate risk per trade
       //aa calculateRisk();

        // Check for bullish engulfing
        if (isBullishEngulfing(0)) {
            // Place Buy order at current market price
            double candleClose =iClose(NULL, 0, 0);
            double candleLow = iLow(NULL, 0, 0);
            
            double entryPrice = candleClose;
            
            double stopLoss = candleLow - (candleClose - candleLow)* slRatio;
            double takeProfit = candleClose + 2 * (candleClose - candleLow) * tpRatio;
            
            // Place Buy order
            trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, loot, entryPrice, stopLoss, takeProfit, "Bullish Engulfing");
//            OrderSend(Symbol(), OP_BUY, 1, entryPrice, 3, stopLoss, takeProfit, "Bullish Engulfing", 0, 0, Green);
       //     lastTradeTime = iTime(NULL, 0, 0);
        }

        // Check for bearish engulfing
        if (isBearishEngulfing(0)) {
            // Place Sell order at current market price
            double candleClose =iClose(NULL, 0, 0);
            double candleHigh = iHigh(NULL, 0, 0);
            
            double entryPrice = candleClose;
            
            double stopLoss = candleHigh + (candleHigh - candleClose)* slRatio;
            double takeProfit = entryPrice - 2 * (candleHigh - candleClose) * tpRatio;

            // Place Sell order
                  trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, loot, entryPrice, stopLoss, takeProfit, "Bearish Engulfing");
        //    OrderSend(Symbol(), OP_BUY, 1, entryPrice, 3, stopLoss, takeProfit, "Bearish Engulfing", 0, 0, Red);
       //     lastTradeTime = iTime(NULL, 0, 0);
   //     }
    }
}
