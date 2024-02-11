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
void GenerateHeikenAshi()
{
    int limit = iBars(_Symbol, PERIOD_CURRENT);

    ArraySetAsSeries(haOpenBuffer, true);
    ArraySetAsSeries(haHighBuffer, true);
    ArraySetAsSeries(haLowBuffer, true);
    ArraySetAsSeries(haCloseBuffer, true);

    for (int i = 0; i < limit; i++)
    {
        int bufferIndex = limit - i - 1;

        if (bufferIndex < 0 || bufferIndex >= ArraySize(haCloseBuffer))
            continue;

        haCloseBuffer[bufferIndex] = (iOpen(_Symbol, PERIOD_CURRENT, i) + iHigh(_Symbol, PERIOD_CURRENT, i) + iLow(_Symbol, PERIOD_CURRENT, i) + iClose(_Symbol, PERIOD_CURRENT, i)) / 4.0;

        if (i == 0)
        {
            haOpenBuffer[bufferIndex] = haCloseBuffer[bufferIndex];
            haHighBuffer[bufferIndex] = haCloseBuffer[bufferIndex];
            haLowBuffer[bufferIndex] = haCloseBuffer[bufferIndex];
        }
        else
        {
            haOpenBuffer[bufferIndex] = (haOpenBuffer[bufferIndex + 1] + haCloseBuffer[bufferIndex + 1]) / 2.0;
            haHighBuffer[bufferIndex] = MathMax(iHigh(_Symbol, PERIOD_CURRENT, i), MathMax(haOpenBuffer[bufferIndex], haCloseBuffer[bufferIndex]));
            haLowBuffer[bufferIndex] = MathMin(iLow(_Symbol, PERIOD_CURRENT, i), MathMin(haOpenBuffer[bufferIndex], haCloseBuffer[bufferIndex]));
        }
    }
}



void OnTick()
{
    CTrade trade;
    trade.SetExpertMagicNumber(MagicNumber);

    if (iBars(_Symbol, PERIOD_CURRENT) < 2)
        return;

    GenerateHeikenAshi();

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
