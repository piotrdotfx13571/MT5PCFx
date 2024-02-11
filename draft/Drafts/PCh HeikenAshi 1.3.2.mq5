#property strict

#include <Trade\Trade.mqh>

input int       lotSize = 0.1;    // Rozmiar pozycji
input int       MagicNumber = 10001;
input double    tpRatio = 1;
input double    slRatio = 1;

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
        haCloseBuffer[i] = (iOpen(_Symbol, PERIOD_CURRENT, i) + iHigh(_Symbol, PERIOD_CURRENT, i) + iLow(_Symbol, PERIOD_CURRENT, i) + iClose(_Symbol, PERIOD_CURRENT, i)) / 4.0;

        if (i == 0)
        {
            haOpenBuffer[i] = (iOpen(_Symbol, PERIOD_CURRENT, i - 1) + iClose(_Symbol, PERIOD_CURRENT, i - 1)) / 2.0;
            haHighBuffer[i] = MathMax(iHigh(_Symbol, PERIOD_CURRENT, i), MathMax(haOpenBuffer[i], haCloseBuffer[i]));
            haLowBuffer[i] = MathMin(iLow(_Symbol, PERIOD_CURRENT, i), MathMin(haOpenBuffer[i], haCloseBuffer[i]));
        }
        else
        {
            haOpenBuffer[i] = (haOpenBuffer[i - 1] + haCloseBuffer[i - 1]) / 2.0;
            haHighBuffer[i] = MathMax(iHigh(_Symbol, PERIOD_CURRENT, i), MathMax(haOpenBuffer[i], haCloseBuffer[i]));
            haLowBuffer[i] = MathMin(iLow(_Symbol, PERIOD_CURRENT, i), MathMin(haOpenBuffer[i], haCloseBuffer[i]));
        }
    }
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
