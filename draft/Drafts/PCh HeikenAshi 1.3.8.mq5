#property strict

#include <Trade\Trade.mqh>

input double       lotSize = 0.1;    // Rozmiar pozycji
input int          MagicNumber = 10001;
input double       tpRatio = 1;
input double       slRatio = 1;

// Definicje zmiennych globalnych
double haOpenBuffer[];
double haHighBuffer[];
double haLowBuffer[];
double haCloseBuffer[];
double ExtOBuffer[];
double ExtHBuffer[];
double ExtLBuffer[];
double ExtCBuffer[];

// Funkcja do generowania świec Heiken Ashi
void GenerateHeikenAshi(int start, int count)
{
    ArraySetAsSeries(haOpenBuffer, true);
    ArraySetAsSeries(haHighBuffer, true);
    ArraySetAsSeries(haLowBuffer, true);
    ArraySetAsSeries(haCloseBuffer, true);

    for (int i = start; i < start + count; i++)
    {
        double haOpen = (i == 0) ? iOpen(_Symbol, PERIOD_CURRENT, i) : (haOpenBuffer[i - 1] + haCloseBuffer[i - 1]) / 2.0;
        double haClose = (iOpen(_Symbol, PERIOD_CURRENT, i) + iHigh(_Symbol, PERIOD_CURRENT, i) + iLow(_Symbol, PERIOD_CURRENT, i) + iClose(_Symbol, PERIOD_CURRENT, i)) / 4.0;
        double haHigh = MathMax(iHigh(_Symbol, PERIOD_CURRENT, i), MathMax(haOpen, haClose));
        double haLow = MathMin(iLow(_Symbol, PERIOD_CURRENT, i), MathMin(haOpen, haClose));

        haOpenBuffer[i] = haOpen;
        haHighBuffer[i] = haHigh;
        haLowBuffer[i] = haLow;
        haCloseBuffer[i] = haClose;
    }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &TickVolume[],
                const long &Volume[],
                const int &Spread[])
{
    int limit;
    if (prev_calculated == 0)
    {
        limit = 1;
    }
    else
    {
        limit = prev_calculated - 1;
    }

    GenerateHeikenAshi(limit, rates_total - limit);

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

    double haOpen = haOpenBuffer[start];
    double haClose = haCloseBuffer[start];
    double haLow = haLowBuffer[start];

    if (haLow > haOpen && haLow > haClose)
    {
        double entryPrice = haClose;
        double stopLoss = haLow - (haClose - haLow) * slRatio;
        double takeProfit = haClose + (haClose - haLow) * tpRatio;

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, entryPrice, stopLoss, takeProfit, "Bullish HA");
    }
}
