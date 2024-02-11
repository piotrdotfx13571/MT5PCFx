#property strict

#include <Trade\Trade.mqh>

input double       lotSize = 0.1;    // Rozmiar pozycji
input int           MagicNumber = 10001;
input double        tpRatio = 1;
input double        slRatio = 1;

// Definicje zmiennych globalnych
double haOpenBuffer[];
double haHighBuffer[];
double haLowBuffer[];
double haCloseBuffer[];

// Funkcja do generowania świec Heiken Ashi
void GenerateHeikenAshi(int start, int count)
{
    for (int i = start; i >= 0; i--)
    {
        if (i == 0)
        {
            haCloseBuffer[i] = (iOpen(_Symbol, PERIOD_CURRENT, i) + iHigh(_Symbol, PERIOD_CURRENT, i) + iLow(_Symbol, PERIOD_CURRENT, i) + iClose(_Symbol, PERIOD_CURRENT, i)) / 4.0;
            haOpenBuffer[i] = haCloseBuffer[i];
            haHighBuffer[i] = haCloseBuffer[i];
            haLowBuffer[i] = haCloseBuffer[i];
        }
        else
        {
            haCloseBuffer[i] = (iOpen(_Symbol, PERIOD_CURRENT, i) + iHigh(_Symbol, PERIOD_CURRENT, i) + iLow(_Symbol, PERIOD_CURRENT, i) + iClose(_Symbol, PERIOD_CURRENT, i)) / 4.0;
            haOpenBuffer[i] = (haOpenBuffer[i - 1] + haCloseBuffer[i - 1]) / 2.0;
            haHighBuffer[i] = MathMax(iHigh(_Symbol, PERIOD_CURRENT, i), MathMax(haOpenBuffer[i], haCloseBuffer[i]));
            haLowBuffer[i] = MathMin(iLow(_Symbol, PERIOD_CURRENT, i), MathMin(haOpenBuffer[i], haCloseBuffer[i]));
        }
    }
}

//+------------------------------------------------------------------+
//| Heiken Ashi                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &TickVolume[],
                const int &Spread[])
{
    int limit;
    if (prev_calculated == 0)
    {
        ArraySetAsSeries(haOpenBuffer, true);
        ArraySetAsSeries(haHighBuffer, true);
        ArraySetAsSeries(haLowBuffer, true);
        ArraySetAsSeries(haCloseBuffer, true);

        limit = rates_total;
    }
    else
        limit = prev_calculated - 1;

    //--- the main loop of calculations
    for (int i = limit; i < rates_total && !IsStopped(); i++)
    {
        if (i == 0)
        {
            haCloseBuffer[i] = (Open[i] + High[i] + Low[i] + Close[i]) / 4.0;
            haOpenBuffer[i] = haCloseBuffer[i];
            haHighBuffer[i] = haCloseBuffer[i];
            haLowBuffer[i] = haCloseBuffer[i];
        }
        else
        {
            double haOpen = (haOpenBuffer[i - 1] + haCloseBuffer[i - 1]) / 2.0;
            double haClose = (Open[i] + High[i] + Low[i] + Close[i]) / 4.0;
            double haHigh = MathMax(High[i], MathMax(haOpen, haClose));
            double haLow = MathMin(Low[i], MathMin(haOpen, haClose));

            haOpenBuffer[i] = haOpen;
            haHighBuffer[i] = haHigh;
            haLowBuffer[i] = haLow;
            haCloseBuffer[i] = haClose;
        }
    }

    return (rates_total);
}

void OnTick()
{
    CTrade trade;
    trade.SetExpertMagicNumber(MagicNumber);

    if (iBars(_Symbol, PERIOD_CURRENT) < 2)
        return;

    int start = iBars(_Symbol, PERIOD_CURRENT) - 1;
    GenerateHeikenAshi(start, 1);

    double haOpen = haOpenBuffer[0];
    double haClose = haCloseBuffer[0];
    double haLow = haLowBuffer[0];

    if (haLow > haOpen && haLow > haClose)
    {
        double entryPrice = haClose;
        double stopLoss = haLow - (haClose - haLow) * slRatio;
        double takeProfit = haClose + (haClose - haLow) * tpRatio;

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, entryPrice, stopLoss, takeProfit, "Bullish HA");
    }
}
